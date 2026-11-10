import 'models.dart';
import 'pids.dart';
import 'transport.dart';

List<int> toInts(String h) {
  final out = <int>[];
  for (var i = 0; i + 1 < h.length; i += 2) {
    out.add(int.parse(h.substring(i, i + 2), radix: 16));
  }
  return out;
}

String hex2(int v) => v.toRadixString(16).toUpperCase().padLeft(2, '0');

/// Код неисправности из двух байт (P0171 и т. д.)
String decodeDtc(int a, int b) {
  const types = ['P', 'C', 'B', 'U'];
  final t = types[(a >> 6) & 3];
  final d1 = (a >> 4) & 3;
  final d2 = (a & 0xF).toRadixString(16).toUpperCase();
  final d3 = ((b >> 4) & 0xF).toRadixString(16).toUpperCase();
  final d4 = (b & 0xF).toRadixString(16).toUpperCase();
  return '$t$d1$d2$d3$d4';
}

/// Протоколы ELM327, которые можно выбрать вручную.
class ObdProto {
  final String code; // цифра для ATSP
  final String name;
  final String hint;
  const ObdProto(this.code, this.name, this.hint);
}

const obdProtocols = <ObdProto>[
  ObdProto('0', 'Авто', 'Адаптер сам перебирает протоколы'),
  ObdProto('3', 'ISO 9141-2', 'K-линия: Январь 5.1, 7.2, часть Bosch'),
  ObdProto('4', 'KWP 5 бод', 'K-линия, медленная инициализация: Bosch MP7.0, M7.9.7'),
  ObdProto('5', 'KWP быстрый', 'K-линия, быстрая инициализация'),
  ObdProto('6', 'CAN 11/500', 'Новые блоки (Гранта, Веста и т. п.)'),
];

String protoName(String code) {
  for (final p in obdProtocols) {
    if (p.code == code) return p.name;
  }
  return 'Авто';
}

class ObdClient {
  final ObdTransport t;
  void Function(String)? onLog;
  bool isCan = false;

  ObdClient(this.t);

  Future<void> close() => t.close();

  Future<String> raw(String cmd, {int timeoutMs = 3000}) async {
    onLog?.call('> $cmd');
    try {
      final r = await t.send(cmd, timeoutMs: timeoutMs);
      final shown = r.replaceAll('\r', ' ').replaceAll('\n', ' ').trim();
      onLog?.call(shown.isEmpty ? '(пусто)' : shown);
      return r;
    } catch (e) {
      onLog?.call('! $e');
      rethrow;
    }
  }

  Future<List<String>> lines(String cmd, {int timeoutMs = 3000}) async {
    final r = await raw(cmd, timeoutMs: timeoutMs);
    return r.split(RegExp(r'[\r\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  /// Только строки из HEX-данных (ответы ЭБУ)
  Future<List<String>> hexLines(String cmd, {int timeoutMs = 4000}) async {
    final out = <String>[];
    final hexRe = RegExp(r'^[0-9A-F]+$');
    for (final line in await lines(cmd, timeoutMs: timeoutMs)) {
      final l = line.replaceAll(' ', '').toUpperCase().replaceFirst(RegExp(r'^[0-9A-F]:'), '');
      if (l.isEmpty || l.length.isOdd || !hexRe.hasMatch(l)) continue;
      out.add(l);
    }
    return out;
  }

  Future<bool> _probe(int timeoutMs) async {
    final hs = await hexLines('0100', timeoutMs: timeoutMs);
    return hs.any((l) => l.startsWith('4100'));
  }

  Future<double?> readVoltage() async {
    try {
      final l = await lines('ATRV');
      if (l.isEmpty) return null;
      return double.tryParse(l.first.toUpperCase().replaceAll('V', '').trim());
    } catch (_) {
      return null;
    }
  }

  Future<AdapterInfo> initialize({String protocol = '0'}) async {
    final notes = <String>[];
    await raw('ATZ', timeoutMs: 7000);
    final ati = await lines('ATI');
    final version = ati.where((l) => l.toUpperCase().contains('ELM')).isNotEmpty
        ? ati.firstWhere((l) => l.toUpperCase().contains('ELM'))
        : (ati.isNotEmpty ? ati.first : 'неизвестно');
    for (final c in ['ATE0', 'ATL0', 'ATS0', 'ATH0', 'ATAT1']) {
      await lines(c);
    }
    var ok = false;
    final manual = protocol != '0';
    if (manual) {
      // Ручной выбор: только этот протокол, без перебора.
      await lines('ATSP$protocol');
      if (protocol != '6') await lines('ATST64'); // K-линия: ждём ответ ЭБУ до 400 мс
      ok = await _probe(30000);
    } else {
      await lines('ATSP0');
      ok = await _probe(25000);
      if (!ok) {
        // Старые блоки ВАЗ (K-line) иногда не находятся в авто-режиме
        for (final p in ['3', '5', '4']) {
          await lines('ATSP$p');
          if (await _probe(15000)) {
            ok = true;
            break;
          }
        }
      }
      if (!ok) await lines('ATSP0');
    }

    final dp = await lines('ATDP');
    final proto = (dp.isNotEmpty ? dp.first : '?').replaceFirst('AUTO, ', '');
    isCan = proto.toUpperCase().contains('CAN');
    final volt = await readVoltage();

    if (version.toUpperCase().contains('V2.1') || version.toUpperCase().contains('V2.2')) {
      notes.add('Адаптер сообщает версию $version. Дешёвые клоны ELM327 иногда нестабильны на некоторых протоколах.');
    }
    if (volt != null && volt < 11.0) {
      notes.add('Напряжение на разъёме OBD низкое (${volt.toStringAsFixed(1)} В). Включите зажигание, проверьте аккумулятор.');
    }
    if (!ok && manual) {
      notes.add('ЭБУ не ответил по протоколу ${protoName(protocol)}. Выберите другой протокол. Если не отвечает ни один, проверьте, что в адаптере разведена K-линия (контакт 7 разъёма OBD).');
    } else if (!ok) {
      notes.add('ЭБУ не ответил. Включите зажигание и проверьте, что адаптер вставлен до упора. Старые блоки Январь 5.1 / 7.2 поддерживают OBD-II частично.');
    }
    return AdapterInfo(
      version: version,
      protocol: proto,
      voltage: volt,
      ecuResponds: ok,
      isCan: isCan,
      notes: notes,
    );
  }

  Future<List<int>?> readPid(int pid) async {
    final prefix = '41${hex2(pid)}';
    final hs = await hexLines('01${hex2(pid)}');
    for (final l in hs) {
      if (l.startsWith(prefix)) return toInts(l.substring(prefix.length));
    }
    return null;
  }

  Future<double?> readValue(PidDef def) async {
    final d = await readPid(def.pid);
    if (d == null || d.length < def.bytes) return null;
    return def.calc(d);
  }

  Future<Set<int>> supportedPids() async {
    final set = <int>{};
    var base = 0;
    while (base <= 0xC0) {
      final d = await readPid(base);
      if (d == null || d.length < 4) break;
      final mask = (d[0] << 24) | (d[1] << 16) | (d[2] << 8) | d[3];
      for (var i = 1; i <= 32; i++) {
        if ((mask & (1 << (32 - i))) != 0) set.add(base + i);
      }
      if (!set.contains(base + 0x20)) break;
      base += 0x20;
    }
    return set;
  }

  Future<Readiness?> readReadiness() async {
    final d = await readPid(0x01);
    if (d == null || d.length < 4) return null;
    final a = d[0];
    final b = d[1];
    final c = d[2];
    final dd = d[3];
    final items = <ReadyItem>[];
    void cont(String name, int supBit, int incBit) {
      if ((b & (1 << supBit)) != 0) items.add(ReadyItem(name, (b & (1 << incBit)) == 0));
    }

    cont('Пропуски зажигания', 0, 4);
    cont('Топливная система', 1, 5);
    cont('Комплектующие (компоненты)', 2, 6);
    const names = [
      'Катализатор', 'Подогрев катализатора', 'Система улавливания паров (EVAP)', 'Вторичный воздух',
      'Кондиционер', 'Лямбда-зонд', 'Подогрев лямбда-зонда', 'Рециркуляция (EGR)',
    ];
    for (var i = 0; i < names.length; i++) {
      if ((c & (1 << i)) != 0) items.add(ReadyItem(names[i], (dd & (1 << i)) == 0));
    }
    return Readiness((a & 0x80) != 0, a & 0x7F, items);
  }

  /// mode: '03' сохранённые, '07' ожидающие, '0A' постоянные. null - режим не поддерживается.
  Future<List<String>?> readDtcs(String mode) async {
    final resp = hex2(int.parse(mode, radix: 16) + 0x40);
    final hs = await hexLines(mode, timeoutMs: 6000);
    final frames = hs.where((l) => l.startsWith(resp)).toList();
    if (frames.isEmpty) return null;
    final bytes = <int>[];
    if (isCan) {
      final rest = hs.where((l) => !l.startsWith(resp)).join();
      final b = toInts(frames.first + rest);
      for (var i = 2; i < b.length; i++) {
        bytes.add(b[i]);
      }
    } else {
      for (final f in frames) {
        final b = toInts(f);
        for (var i = 1; i < b.length; i++) {
          bytes.add(b[i]);
        }
      }
    }
    final out = <String>{};
    var i = 0;
    while (i + 1 < bytes.length) {
      if (bytes[i] != 0 || bytes[i + 1] != 0) out.add(decodeDtc(bytes[i], bytes[i + 1]));
      i += 2;
    }
    return out.toList();
  }

  Future<FreezeFrame?> readFreezeFrame() async {
    final hs = await hexLines('020200');
    final line = hs.where((l) => l.startsWith('4202')).toList();
    String? dtc;
    if (line.isNotEmpty) {
      final d = toInts(line.first.substring(4));
      if (d.length >= 3) {
        dtc = decodeDtc(d[1], d[2]);
        if (dtc == 'P0000') dtc = null;
      }
    }
    final vals = <int, double>{};
    for (final pid in const [0x04, 0x05, 0x06, 0x07, 0x0B, 0x0C, 0x0D, 0x0F, 0x11]) {
      final def = pidById[pid];
      if (def == null) continue;
      final prefix = '42${hex2(pid)}';
      final l = (await hexLines('02${hex2(pid)}00')).where((x) => x.startsWith(prefix)).toList();
      if (l.isEmpty) continue;
      final data = toInts(l.first.substring(prefix.length));
      if (data.length >= def.bytes + 1) {
        vals[pid] = def.calc(data.sublist(1, 1 + def.bytes));
      }
    }
    if (dtc == null && vals.isEmpty) return null;
    return FreezeFrame(dtc, vals);
  }

  Future<bool> clearDtcs() async {
    final hs = await hexLines('04', timeoutMs: 6000);
    return hs.any((l) => l.startsWith('44'));
  }

  Future<String?> readVin() async {
    try {
      final sb = StringBuffer();
      final hs = await hexLines('0902', timeoutMs: 6000);
      for (final h in hs.where((l) => l.startsWith('4902'))) {
        final b = toInts(h);
        for (var i = 3; i < b.length; i++) {
          if (b[i] >= 0x30 && b[i] <= 0x5A) sb.writeCharCode(b[i]);
        }
      }
      return sb.length == 17 ? sb.toString() : null;
    } catch (_) {
      return null;
    }
  }

  /// Пробег из стандартного PID 01 A6 (одометр), км. null - ЭБУ не отдаёт.
  Future<double?> readOdometer() async {
    try {
      final d = await readPid(0xA6);
      if (d == null || d.length < 4) return null;
      final v = (d[0] << 24) | (d[1] << 16) | (d[2] << 8) | d[3];
      return v / 10.0;
    } catch (_) {
      return null;
    }
  }

  /// Текст из Mode 09 (0A - имя ЭБУ, 04 - ID калибровки)
  Future<String?> readMode09Text(int pid) async {
    try {
      final header = '49${hex2(pid)}';
      final sb = StringBuffer();
      for (final line in await hexLines('09${hex2(pid)}', timeoutMs: 5000)) {
        final bytes = toInts(line.startsWith(header) ? line.substring(6) : line.substring(2));
        for (final b in bytes) {
          if (b >= 0x20 && b <= 0x7E) sb.writeCharCode(b);
        }
      }
      final s = sb.toString().trim();
      return s.isEmpty ? null : s;
    } catch (_) {
      return null;
    }
  }
}
