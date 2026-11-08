import '../obd/models.dart';
import '../obd/pids.dart';
import 'analysis.dart';
import 'dtc.dart';

String fmtDate(DateTime t) {
  String p(int v) => v.toString().padLeft(2, '0');
  return '${p(t.day)}.${p(t.month)}.${t.year} ${p(t.hour)}:${p(t.minute)}';
}

String buildReport({
  required String title,
  required DateTime time,
  required String vehicle,
  String? vin,
  double? odometerKm,
  AdapterInfo? adapter,
  required List<String> stored,
  required List<String> pending,
  required List<String> permanent,
  Readiness? readiness,
  FreezeFrame? freeze,
  List<Map<int, double>> snaps = const [],
  List<double> lambda = const [],
  Analysis? analysis,
}) {
  final sb = StringBuffer();
  sb.writeln('=== $title ===');
  sb.writeln('Дата: ${fmtDate(time)}');
  sb.writeln('Автомобиль: $vehicle');
  if (vin != null && vin.isNotEmpty) sb.writeln('VIN: $vin');
  if (odometerKm != null) sb.writeln('Пробег: ${odometerKm.toStringAsFixed(0)} км');
  if (adapter != null) sb.writeln('Адаптер: ${adapter.version}, протокол: ${adapter.protocol}');
  if (analysis != null) {
    sb.writeln();
    sb.writeln('ИТОГ: ${analysis.verdict} (оценка ${analysis.score} из 100)');
  }
  if (readiness != null) {
    sb.writeln('Лампа Check Engine: ${readiness.milOn ? 'ГОРИТ' : 'не горит'}');
  }
  if (analysis != null && analysis.findings.isNotEmpty) {
    sb.writeln();
    sb.writeln('--- ВЫВОДЫ ---');
    for (final x in analysis.findings) {
      sb.writeln('[${sevText(x.severity)}] ${x.title}');
      sb.writeln('   ${x.details}');
      for (final a in x.actions) {
        sb.writeln('   • $a');
      }
    }
  }

  void block(String head, List<String> codes) {
    sb.writeln();
    sb.writeln('--- $head ---');
    if (codes.isEmpty) {
      sb.writeln('нет');
      return;
    }
    for (final c in codes) {
      final d = DtcDb.lookup(c);
      sb.writeln('${d.code} [${sevText(d.severity)}] ${d.title}');
      for (var i = 0; i < d.causes.length; i++) {
        sb.writeln('   ${i + 1}. ${d.causes[i]}');
      }
      for (final s in d.steps) {
        sb.writeln('   • $s');
      }
      for (final l in FaultContext.explain(c, freeze)) {
        sb.writeln('   Момент ошибки: $l');
      }
    }
  }

  block('СОХРАНЁННЫЕ ОШИБКИ', stored);
  block('ОЖИДАЮЩИЕ ОШИБКИ', pending);
  if (permanent.isNotEmpty) block('ПОСТОЯННЫЕ ОШИБКИ', permanent);

  if (freeze != null) {
    sb.writeln();
    sb.writeln('--- СТОП-КАДР${freeze.dtc != null ? ' (${freeze.dtc})' : ''} ---');
    freeze.values.forEach((pid, v) {
      final d = pidById[pid];
      if (d != null) sb.writeln('${d.name}: ${fmtPid(d, v)} ${d.unit}');
    });
  }

  if (readiness != null && readiness.items.isNotEmpty) {
    sb.writeln();
    sb.writeln('--- ГОТОВНОСТЬ СИСТЕМ ---');
    for (final i in readiness.items) {
      sb.writeln('${i.name}: ${i.complete ? 'готово' : 'не завершено'}');
    }
  }

  if (snaps.isNotEmpty) {
    sb.writeln();
    sb.writeln('--- ЖИВЫЕ ДАННЫЕ (среднее, мин-макс) ---');
    for (final pid in scanList) {
      final l = snaps.map((s) => s[pid]).whereType<double>().toList();
      if (l.isEmpty) continue;
      final d = pidById[pid];
      if (d == null) continue;
      final avg = l.reduce((a, b) => a + b) / l.length;
      sb.writeln('${d.name}: ${fmtPid(d, avg)} ${d.unit} (${fmtPid(d, l.reduce((a, b) => a < b ? a : b))} - ${fmtPid(d, l.reduce((a, b) => a > b ? a : b))})');
    }
  }
  if (lambda.length >= 5) {
    final avg = lambda.reduce((a, b) => a + b) / lambda.length;
    sb.writeln('Лямбда-зонд 1: среднее ${avg.toStringAsFixed(2)} В, размах ${lambda.reduce((a, b) => a < b ? a : b).toStringAsFixed(2)} - ${lambda.reduce((a, b) => a > b ? a : b).toStringAsFixed(2)} В (${lambda.length} замеров)');
  }
  sb.writeln();
  sb.writeln('Отчёт создан программой VAZ Scan. Рекомендации ориентировочные: окончательный вывод даёт осмотр и проверка узлов.');
  return sb.toString();
}
