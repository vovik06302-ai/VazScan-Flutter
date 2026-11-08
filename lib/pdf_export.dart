import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'app_state.dart';
import 'diag/report.dart';

/// Системный шрифт Android с кириллицей (Roboto). Без него русский текст в PDF не выведется.
Future<pw.Font?> _loadFont() async {
  for (final p in ['/system/fonts/Roboto-Regular.ttf', '/system/fonts/DroidSans.ttf']) {
    final f = File(p);
    if (await f.exists()) {
      final bytes = await f.readAsBytes();
      return pw.Font.ttf(bytes.buffer.asByteData());
    }
  }
  return null;
}

/// Сохраняет отчёт в PDF и возвращает путь к файлу
Future<String> buildPdf(SavedReport r) async {
  final font = await _loadFont();
  final doc = pw.Document(
    theme: font == null ? null : pw.ThemeData.withFont(base: font, bold: font),
  );
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    build: (ctx) => [
      pw.Text(r.title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.Text('Дата: ${fmtDate(DateTime.fromMillisecondsSinceEpoch(r.id))}'),
      if (r.vehicle.isNotEmpty) pw.Text('Автомобиль: ${r.vehicle}'),
      if (r.odometerKm != null) pw.Text('Пробег: ${r.odometerKm!.toStringAsFixed(0)} км'),
      if (r.score >= 0)
        pw.Text('Оценка: ${r.score} из 100', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 10),
      pw.Text(r.text, style: pw.TextStyle(fontSize: 8)),
      for (final e in r.traces.entries) ...[
        pw.SizedBox(height: 10),
        pw.Text(e.key, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(
          height: 90,
          width: 480,
          child: pw.CustomPaint(painter: (canvas, size) => _trace(canvas, size, e.value)),
        ),
      ],
    ],
  ));
  final bytes = await doc.save();
  final tmp = await getTemporaryDirectory();
  final f = File('${tmp.path}/VazScan-${r.id}.pdf');
  await f.writeAsBytes(bytes);
  return f.path;
}

void _trace(PdfGraphics canvas, PdfPoint size, List<double> d) {
  if (d.length < 2) return;
  var mn = d.first;
  var mx = d.first;
  for (final v in d) {
    if (v < mn) mn = v;
    if (v > mx) mx = v;
  }
  final span = (mx - mn) == 0 ? 1.0 : (mx - mn);
  canvas.setStrokeColor(PdfColors.blue);
  canvas.setLineWidth(1.2);
  for (var i = 0; i < d.length; i++) {
    final x = size.x * i / (d.length - 1);
    final y = size.y * (d[i] - mn) / span;
    if (i == 0) {
      canvas.moveTo(x, y);
    } else {
      canvas.lineTo(x, y);
    }
  }
  canvas.strokePath();
}
