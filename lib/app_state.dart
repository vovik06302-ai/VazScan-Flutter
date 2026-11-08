import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'diag/analysis.dart';
import 'diag/dtc.dart';
import 'diag/report.dart';
import 'obd/models.dart';
import 'obd/obd_client.dart';
import 'obd/pids.dart';
import 'obd/transport.dart';
import 'obd/vehicle.dart';
import 'repairs.dart';
import 'service.dart';
import 'speech.dart';
import 'updater.dart';

List<String> _strList(dynamic v) => v == null ? const [] : (v as List).map((e) => e.toString()).toList();

Map<String, List<double>> _traces(dynamic v) {
  if (v == null) return {};
  final m = v as Map<String, dynamic>;
  return m.map((k, e) => MapEntry(k, (e as List).map((x) => (x as num).toDouble()).toList()));
}

class SavedReport {
  final int id;
  final String title;
  final int score;
  final String text;
  final List<String> codes;
  final List<String> findings;
  final String vehicle;
  final double? odometerKm;
  final Map<String, List<double>> traces;
  SavedReport(
    this.id,
    this.title,
    this.score,
    this.text, {
    this.codes = const [],
    this.findings = const [],
    this.vehicle = '',
    this.odometerKm,
    this.traces = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'score': score,
        'text': text,
        'codes': codes,
        'findings': findings,
        'vehicle': vehicle,
        'odometerKm': odometerKm,
        'traces': traces,
      };

  factory SavedReport.fromJson(Map<String, dynamic> j) => SavedReport(
        j['id'] as int,
        j['title'] as String,
        j['score'] as int,
        j['text'] as String,
        codes: _strList(j['codes']),
        findings: _strList(j['findings']),
        vehicle: (j['vehicle'] ?? '') as String,
        odometerKm: (j['odometerKm'] as num?)?.toDouble(),
        traces: _traces(j['traces']),
      );
}

/// Всё состояние приложения. Экраны перерисовываются при notifyListeners().
class AppState extends ChangeNotifier {
  String version = '';
  bool connected = false;
  bool busy = false;
  bool scanning = false;
  bool working = false;
  bool liveOn = false;
  bool demo = false;
  bool voice = true;
  String status = 'Не подключено';
  String? error;
  String? info;

  AdapterInfo? adapter;
  Set<int> supported = {};
  String? vin;
  VehicleInfo? vehicleInfo;
  String vehicle = 'Автомобиль не определён';

  List<BtDevice> devices = [];
  final List<String> terminal = [];

  String scanStage = '';
  double scanProgress = 0;
  ScanResult? result;

  List<String> stored = [];
  List<String> pending = [];
  List<String> permanent = [];
  Readiness? readiness;
  FreezeFrame? freeze;
  bool errorsRead = false;

  Map<int, double> live = {};
  final Map<int, List<double>> hist = {};

  List<SavedReport> reports = [];
  List<RepairEntry> repairs = [];
  bool bigText = false;
  List<ServiceItem> services = List<ServiceItem>.from(defaultServices);
  bool checkingAdapter = false;
  bool voiceReady = true;
  String? adapterCheck;
  File? _repairFile;

  String token = '';
  String updateStatus = '';
  UpdateInfo? update;
  bool updateBusy = false;
  double updateProgress = 0;

  ObdClient? _client;
  final Speaker _speaker = Speaker();
  final Set<String> _spoken = {};
  Directory? _reportsDir;

  AppState() {
    _init();
  }

  Future<void> _init() async {
    final pi = await PackageInfo.fromPlatform();
    version = pi.version;
    await _speaker.init();
    voiceReady = await _speaker.russianReady();
    final base = await getApplicationDocumentsDirectory();
    _reportsDir = Directory('${base.path}/reports')..createSync(recursive: true);
    _repairFile = File('${base.path}/repairs.json');
    _loadRepairs();
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('gh_token') ?? '';
    bigText = prefs.getBool('bigText') ?? false;
    final sv = prefs.getString('services');
    if (sv != null) {
      try {
        services = (jsonDecode(sv) as List).map((e) => ServiceItem.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    _loadReports();
    notifyListeners();
  }

  // ---------- история ----------

  void _loadReports() {
    final dir = _reportsDir;
    if (dir == null) return;
    final list = <SavedReport>[];
    for (final f in dir.listSync()) {
      if (f is File && f.path.endsWith('.json')) {
        try {
          list.add(SavedReport.fromJson(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>));
        } catch (_) {}
      }
    }
    list.sort((a, b) => b.id.compareTo(a.id));
    reports = list;
  }

  Future<void> _saveReport(SavedReport r) async {
    final dir = _reportsDir;
    if (dir != null) {
      await File('${dir.path}/${r.id}.json').writeAsString(jsonEncode(r.toJson()));
    }
    reports = [r, ...reports];
    notifyListeners();
  }

  Future<void> deleteReport(SavedReport r) async {
    final dir = _reportsDir;
    if (dir != null) {
      final f = File('${dir.path}/${r.id}.json');
      if (await f.exists()) await f.delete();
    }
    reports = reports.where((x) => x.id != r.id).toList();
    notifyListeners();
  }

  void _loadRepairs() {
    final f = _repairFile;
    if (f == null || !f.existsSync()) return;
    try {
      repairs = (jsonDecode(f.readAsStringSync()) as List)
          .map((e) => RepairEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}
  }

  Future<void> _saveRepairs() async {
    final f = _repairFile;
    if (f != null) await f.writeAsString(jsonEncode(repairs.map((r) => r.toJson()).toList()));
  }

  Future<void> addRepair(String title, String note, List<String> codes) async {
    repairs = [RepairEntry(DateTime.now().millisecondsSinceEpoch, title, note, codes), ...repairs];
    await _saveRepairs();
    notifyListeners();
  }

  Future<void> deleteRepair(RepairEntry r) async {
    repairs = repairs.where((x) => x.id != r.id).toList();
    await _saveRepairs();
    notifyListeners();
  }

  // ---------- подключение ----------

  void _log(String line) {
    terminal.add(line);
    if (terminal.length > 400) terminal.removeAt(0);
    notifyListeners();
  }

  Future<void> refreshDevices() async {
    try {
      await Permission.bluetoothConnect.request();
      devices = await BtTransport.paired();
      info = devices.isEmpty ? 'Нет сопряжённых устройств. Сначала сопрягите адаптер в настройках Bluetooth.' : null;
    } catch (e) {
      error = 'Bluetooth: $e';
    }
    notifyListeners();
  }

  Future<void> connectBt(BtDevice d) => _connect(() => BtTransport(d.address), false);

  Future<void> connectDemo() => _connect(() => DemoTransport(), true);

  Future<void> _connect(ObdTransport Function() factory, bool isDemo) async {
    if (busy) return;
    await disconnect();
    busy = true;
    status = 'Подключение…';
    error = null;
    info = null;
    notifyListeners();
    try {
      final t = factory();
      await t.open();
      final c = ObdClient(t)..onLog = _log;
      status = 'Инициализация адаптера (поиск ЭБУ может занять до минуты)…';
      notifyListeners();
      final ai = await c.initialize();
      _client = c;
      adapter = ai;
      demo = isDemo;
      connected = true;
      status = ai.ecuResponds ? 'Подключено к ЭБУ' : 'Адаптер подключён, ЭБУ не отвечает';
      if (ai.ecuResponds) {
        supported = await c.supportedPids();
        vin = await c.readVin();
        final odo = await c.readOdometer();
        final ecu = await c.readMode09Text(0x0A);
        final cal = await c.readMode09Text(0x04);
        vehicleInfo = await VinDecoder.build(vin, odo, ecu, cal);
        vehicle = vehicleInfo!.displayName;
      }
    } catch (e) {
      error = 'Ошибка подключения: $e';
      status = 'Не подключено';
      connected = false;
      _client = null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    liveOn = false;
    try {
      await _client?.close();
    } catch (_) {}
    _client = null;
    connected = false;
    adapter = null;
    supported = {};
    vin = null;
    vehicleInfo = null;
    vehicle = 'Автомобиль не определён';
    demo = false;
    status = 'Не подключено';
    notifyListeners();
  }

  void _lost(Object e) {
    error = 'Связь потеряна: $e';
    connected = false;
    status = 'Связь потеряна';
    liveOn = false;
    notifyListeners();
  }

  Future<void> sendRaw(String cmd) async {
    final c = _client;
    if (c == null) {
      info = 'Нет подключения';
      notifyListeners();
      return;
    }
    try {
      await c.raw(cmd.trim().toUpperCase(), timeoutMs: 8000);
    } catch (e) {
      _lost(e);
    }
  }

  // ---------- голос ----------

  void setVoice(bool on) {
    voice = on;
    _speaker.enabled = on;
    notifyListeners();
  }

  void speakResult() {
    final r = result;
    if (r != null) _speaker.say(phraseFor(r));
  }

  void _speakNewAlarms() {
    final now = alarmsFor(live, hist).where((a) => a.level == 2).toList();
    for (final a in now) {
      if (_spoken.add(a.name)) {
        _speaker.say('Тревога. ${a.name}. ${a.text}');
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
      }
    }
    _spoken.removeWhere((n) => !now.any((a) => a.name == n));
  }

  // ---------- живые данные ----------

  List<int> get dashPids => supported.where((p) => pidById.containsKey(p)).toList()..sort();

  Future<void> startLive() async {
    final c = _client;
    if (c == null || liveOn || scanning || working || dashPids.isEmpty) return;
    liveOn = true;
    notifyListeners();
    final pids = dashPids;
    var empty = 0;
    while (liveOn && connected) {
      final m = <int, double>{};
      try {
        for (final p in pids) {
          if (!liveOn) break;
          final v = await c.readValue(pidById[p]!);
          if (v != null) m[p] = v;
        }
      } catch (e) {
        _lost(e);
        break;
      }
      if (m.isEmpty) {
        empty++;
        if (empty >= 8) {
          _lost('адаптер не отвечает на запросы опроса');
          break;
        }
      } else {
        empty = 0;
      }
      live = {...live, ...m};
      m.forEach((p, v) {
        final h = hist[p] ?? <double>[];
        hist[p] = [...(h.length >= 59 ? h.sublist(h.length - 59) : h), v];
      });
      _speakNewAlarms();
      notifyListeners();
    }
    liveOn = false;
    notifyListeners();
  }

  void stopLive() {
    liveOn = false;
    notifyListeners();
  }

  // ---------- ошибки ----------

  Future<void> _ioTask(Future<void> Function(ObdClient c) task) async {
    final c = _client;
    if (c == null || scanning || working) return;
    liveOn = false;
    working = true;
    info = null;
    notifyListeners();
    try {
      await task(c);
    } catch (e) {
      _lost(e);
    } finally {
      working = false;
      notifyListeners();
    }
  }

  Future<void> _readErrorsNow(ObdClient c) async {
    stored = await c.readDtcs('03') ?? [];
    pending = await c.readDtcs('07') ?? [];
    permanent = await c.readDtcs('0A') ?? [];
    readiness = await c.readReadiness();
    freeze = (stored.isNotEmpty || pending.isNotEmpty) ? await c.readFreezeFrame() : null;
    errorsRead = true;
  }

  Future<void> readErrors() => _ioTask(_readErrorsNow);

  Future<void> clearErrors() => _ioTask((c) async {
        if (stored.isNotEmpty || pending.isNotEmpty) {
          final now = DateTime.now();
          final text = buildReport(
            title: 'Ошибки перед сбросом',
            time: now,
            vehicle: vehicle,
            vin: vin,
            odometerKm: vehicleInfo?.odometerKm,
            adapter: adapter,
            stored: stored,
            pending: pending,
            permanent: permanent,
            readiness: readiness,
            freeze: freeze,
          );
          await _saveReport(SavedReport(now.millisecondsSinceEpoch, 'Ошибки перед сбросом', -1, text));
        }
        final ok = await c.clearDtcs();
        info = ok
            ? 'Ошибки сброшены. Запустите двигатель и проверьте, вернулись ли они. Если вернулись, причина не устранена.'
            : 'ЭБУ не подтвердил сброс (при выключенном зажигании или на старых блоках сброс может не поддерживаться).';
        await _readErrorsNow(c);
      });

  // ---------- полная диагностика ----------

  void _stage(String text, double p) {
    scanStage = text;
    scanProgress = p;
    notifyListeners();
  }

  Future<void> runScan() async {
    final c = _client;
    if (c == null || scanning || working) return;
    liveOn = false;
    scanning = true;
    scanProgress = 0;
    result = null;
    error = null;
    notifyListeners();
    try {
      _stage('Проверка связи и напряжения', 0.05);
      final volt = await c.readVoltage();
      _stage('Определение поддерживаемых датчиков', 0.12);
      final sup = await c.supportedPids();
      supported = sup;
      _stage('Лампа Check Engine и готовность систем', 0.2);
      final rd = await c.readReadiness();
      _stage('Чтение кодов ошибок', 0.3);
      final st = await c.readDtcs('03') ?? [];
      final pe = await c.readDtcs('07') ?? [];
      final pm = await c.readDtcs('0A') ?? [];
      _stage('Стоп-кадр неисправности', 0.4);
      final ff = (st.isNotEmpty || pe.isNotEmpty) ? await c.readFreezeFrame() : null;

      _stage('Живые данные (двигатель должен работать)', 0.5);
      final pids = scanList.where((p) => sup.contains(p)).toList();
      final snaps = <Map<int, double>>[];
      final t0 = DateTime.now();
      while (pids.isNotEmpty && DateTime.now().difference(t0).inMilliseconds < 12000) {
        final m = <int, double>{};
        for (final p in pids) {
          final v = await c.readValue(pidById[p]!);
          if (v != null) m[p] = v;
        }
        if (m.isNotEmpty) snaps.add(m);
        scanProgress = 0.5 + 0.3 * min(1.0, DateTime.now().difference(t0).inMilliseconds / 12000);
        notifyListeners();
      }

      _stage('Анализ лямбда-зонда', 0.8);
      final lam = <double>[];
      if (sup.contains(0x14)) {
        final t1 = DateTime.now();
        while (DateTime.now().difference(t1).inMilliseconds < 12000) {
          final v = await c.readValue(pidById[0x14]!);
          if (v != null) lam.add(v);
          scanProgress = 0.8 + 0.15 * min(1.0, DateTime.now().difference(t1).inMilliseconds / 12000);
          notifyListeners();
        }
      }

      _stage('Анализ результатов', 0.96);
      final analysis = analyze(
        stored: st,
        pending: pe,
        permanent: pm,
        readiness: rd,
        snaps: snaps,
        lambda: lam,
        adapterVolt: volt,
      );
      final now = DateTime.now();
      final text = buildReport(
        title: 'Полная диагностика',
        time: now,
        vehicle: vehicle,
        vin: vin,
        odometerKm: vehicleInfo?.odometerKm,
        adapter: adapter,
        stored: st,
        pending: pe,
        permanent: pm,
        readiness: rd,
        freeze: ff,
        snaps: snaps,
        lambda: lam,
        analysis: analysis,
      );
      final res = ScanResult(
        time: now,
        vehicle: vehicle,
        stored: st,
        pending: pe,
        permanent: pm,
        readiness: rd,
        freeze: ff,
        analysis: analysis,
        text: text,
      );
      result = res;
      stored = st;
      pending = pe;
      permanent = pm;
      readiness = rd;
      freeze = ff;
      errorsRead = true;
      final traces = <String, List<double>>{};
      for (final p in [0x14, 0x06, 0x07]) {
        final h = hist[p];
        if (h != null && h.isNotEmpty) traces[pidName(p)] = List<double>.from(h);
      }
      await _saveReport(SavedReport(now.millisecondsSinceEpoch, 'Полная диагностика', analysis.score, text,
          codes: [...st, ...pe],
          findings: analysis.findings.map((f) => f.title).toList(),
          vehicle: vehicle,
          odometerKm: vehicleInfo?.odometerKm,
          traces: traces));
      _stage('Готово', 1);
      if (voice) _speaker.say(phraseFor(res));
      if (analysis.findings.any((f) => f.severity == 3)) {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
      }
    } catch (e) {
      _lost(e);
    } finally {
      scanning = false;
      notifyListeners();
    }
  }

  // ---------- настройки и обслуживание ----------

  void setBigText(bool v) {
    bigText = v;
    SharedPreferences.getInstance().then((p) => p.setBool('bigText', v));
    notifyListeners();
  }

  Future<void> markServiceDone(int i) async {
    final km = vehicleInfo?.odometerKm;
    if (km == null) {
      info = 'Пробег неизвестен: отметьте ТО, когда ЭБУ передаст пробег';
      notifyListeners();
      return;
    }
    services = List<ServiceItem>.from(services)..[i] = services[i].withLast(km);
    final p = await SharedPreferences.getInstance();
    await p.setString('services', jsonEncode(services.map((x) => x.toJson()).toList()));
    notifyListeners();
  }

  /// 20 запросов к адаптеру: удачные ответы, время ответа, напряжение
  Future<void> checkAdapter() async {
    final c = _client;
    if (c == null || checkingAdapter || scanning || working) return;
    liveOn = false;
    checkingAdapter = true;
    adapterCheck = null;
    notifyListeners();
    final times = <int>[];
    var bad = 0;
    try {
      for (var i = 0; i < 20; i++) {
        final sw = Stopwatch()..start();
        final r = await c.raw('0100', timeoutMs: 3000);
        sw.stop();
        if (r.contains('4100')) {
          times.add(sw.elapsedMilliseconds);
        } else {
          bad++;
        }
      }
      final volt = await c.readVoltage();
      final avg = times.isEmpty ? 0 : times.reduce((a, b) => a + b) ~/ times.length;
      final mx = times.isEmpty ? 0 : times.reduce((a, b) => a > b ? a : b);
      final stable = bad <= 2 && avg < 400;
      adapterCheck = [
        'Версия адаптера: ${adapter?.version ?? '—'}',
        'Удачных ответов: ${times.length} из 20, без ответа: $bad',
        'Среднее время ответа: $avg мс, максимум: $mx мс',
        if (volt != null) 'Напряжение на разъёме: ${volt.toStringAsFixed(1)} В',
        stable
            ? 'Связь стабильная. Можно диагностировать и смотреть датчики.'
            : 'Связь нестабильная: проверьте адаптер, плотность его вставки и Bluetooth-соединение.',
        'Строку версии клоны часто подделывают, поэтому судите по стабильности связи.',
      ].join('\n');
    } catch (e) {
      adapterCheck = 'Проверка прервана: $e';
    } finally {
      checkingAdapter = false;
      notifyListeners();
    }
  }

  // ---------- обновление ----------

  Future<void> setToken(String v) async {
    token = v.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gh_token', token);
    notifyListeners();
  }

  int get currentBuild => int.tryParse(version.split('.').last) ?? 0;

  Future<void> checkUpdate() async {
    if (updateBusy) return;
    updateBusy = true;
    updateStatus = 'Проверка обновлений…';
    update = null;
    notifyListeners();
    try {
      final u = await Updater.latest(token.isEmpty ? null : token);
      if (u == null) {
        updateStatus = 'Не удалось определить версию последнего релиза';
      } else if (u.code <= currentBuild) {
        updateStatus = 'Установлена последняя версия ($version)';
      } else {
        update = u;
        updateStatus = 'Доступна новая версия ${u.tag}';
      }
    } catch (e) {
      updateStatus = 'Ошибка проверки: $e';
    } finally {
      updateBusy = false;
      notifyListeners();
    }
  }

  Future<void> installUpdate() async {
    final u = update;
    if (u == null || updateBusy) return;
    updateBusy = true;
    updateProgress = 0;
    updateStatus = 'Загрузка ${u.tag}…';
    notifyListeners();
    try {
      final f = await Updater.download(u, token.isEmpty ? null : token, (p) {
        updateProgress = p;
        notifyListeners();
      });
      updateStatus = 'Загружено. Подтвердите установку.';
      await Updater.install(f);
    } catch (e) {
      updateStatus = 'Ошибка загрузки: $e';
    } finally {
      updateBusy = false;
      notifyListeners();
    }
  }
}
