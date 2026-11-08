import 'dart:math';
import 'package:flutter/material.dart';
import '../diag/analysis.dart';
import '../diag/dtc.dart';
import '../diag/report.dart';
import '../obd/models.dart';
import '../obd/pids.dart';
import '../obd/vehicle.dart';
import '../theme.dart';

class Panel extends StatelessWidget {
  final Widget child;
  const Panel({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(12), child: child));
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: vazCyan)),
      );
}

class Dot extends StatelessWidget {
  final Color color;
  const Dot({super.key, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class AlarmBanner extends StatelessWidget {
  final List<Alarm> alarms;
  final bool live;
  const AlarmBanner({super.key, required this.alarms, required this.live});

  @override
  Widget build(BuildContext context) {
    if (!live) {
      return const Panel(child: Text('Опрос остановлен. Нажмите «Запустить опрос», чтобы видеть состояние в реальном времени.'));
    }
    if (alarms.isEmpty) {
      return Card(
        color: okColor.withOpacity(0.15),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Всё в норме', style: TextStyle(color: okColor, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      );
    }
    return Column(children: [
      for (final a in alarms)
        Card(
          color: levelColor(a.level).withOpacity(0.15),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${a.level >= 2 ? 'ТРЕВОГА' : 'ВНИМАНИЕ'}: ${a.name}',
                  style: TextStyle(color: levelColor(a.level), fontWeight: FontWeight.bold)),
              Text(a.text, style: const TextStyle(fontSize: 13)),
            ]),
          ),
        ),
    ]);
  }
}

class GaugeDial extends StatelessWidget {
  final String title;
  final String unit;
  final double? value;
  final double min;
  final double max;
  final int dec;
  final Color color;
  const GaugeDial({
    super.key,
    required this.title,
    required this.unit,
    required this.value,
    required this.min,
    required this.max,
    required this.dec,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final v = value;
    final frac = v == null ? 0.0 : ((v - min) / (max - min)).clamp(0.0, 1.0).toDouble();
    return Column(children: [
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
      AspectRatio(
        aspectRatio: 1.1,
        child: CustomPaint(painter: _DialPainter(frac, color, v != null)),
      ),
      Text(
        v == null ? '—' : v.toStringAsFixed(dec),
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: v == null ? Colors.grey : color),
      ),
      Text(unit, style: const TextStyle(fontSize: 12, color: dimText)),
    ]);
  }
}

class _DialPainter extends CustomPainter {
  final double frac;
  final Color color;
  final bool hasValue;
  _DialPainter(this.frac, this.color, this.hasValue);

  double _rad(double deg) => deg * pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final d = min(size.width, size.height);
    final stroke = d * 0.07;
    final c = Offset(size.width / 2, size.height / 2);
    final r = d / 2 - stroke;
    final rect = Rect.fromCircle(center: c, radius: r);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF2E4A66);
    canvas.drawArc(rect, _rad(135), _rad(270), false, track);
    if (hasValue) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawArc(rect, _rad(135), _rad(270 * frac), false, arc);
    }
    final tick = Paint()
      ..color = dimText
      ..strokeWidth = 2;
    for (var i = 0; i <= 8; i++) {
      final a = _rad(135 + 270 * i / 8);
      final dir = Offset(cos(a), sin(a));
      canvas.drawLine(c + dir * (r + stroke * 0.6), c + dir * (r + stroke * 0.95), tick);
    }
    final na = _rad(135 + 270 * frac);
    final dirN = Offset(cos(na), sin(na));
    final needle = Paint()
      ..color = Colors.white
      ..strokeWidth = d * 0.015
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c, c + dirN * (r - stroke * 0.8), needle);
    canvas.drawCircle(c, d * 0.035, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.frac != frac || old.color != color || old.hasValue != hasValue;
}

class ScopeView extends StatelessWidget {
  final String title;
  final List<double> data;
  final double min;
  final double max;
  final int level;
  final String valueText;
  const ScopeView({
    super.key,
    required this.title,
    required this.data,
    required this.min,
    required this.max,
    required this.level,
    required this.valueText,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF0B1410),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(title, style: const TextStyle(color: dimText, fontSize: 13))),
            Text(valueText, style: TextStyle(color: levelColor(level), fontWeight: FontWeight.bold, fontSize: 18)),
          ]),
          SizedBox(
            height: 120,
            child: CustomPaint(painter: _ScopePainter(data, min, max, levelColor(level))),
          ),
        ]),
      ),
    );
  }
}

class _ScopePainter extends CustomPainter {
  final List<double> data;
  final double min;
  final double max;
  final Color color;
  _ScopePainter(this.data, this.min, this.max, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0x3300E676)
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (var i = 1; i <= 9; i++) {
      final x = size.width * i / 10;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    if (min < 0 && max > 0) {
      final y = size.height * (1 - (0 - min) / (max - min));
      canvas.drawLine(Offset(0, y), Offset(size.width, y),
          Paint()
            ..color = const Color(0x8800E676)
            ..strokeWidth = 2);
    }
    if (data.length >= 2) {
      const n = 60;
      final path = Path();
      for (var i = 0; i < data.length; i++) {
        final x = size.width * (n - 1 - (data.length - 1 - i)) / (n - 1);
        final frac = ((data[i] - min) / (max - min)).clamp(0.0, 1.0).toDouble();
        final y = size.height * (1 - frac);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScopePainter old) => true;
}

class PidTile extends StatelessWidget {
  final PidDef def;
  final double? value;
  final int level;
  const PidTile({super.key, required this.def, required this.value, required this.level});

  @override
  Widget build(BuildContext context) {
    final color = value == null ? Colors.grey : levelColor(level);
    return Card(
      color: level > 0 ? color.withOpacity(0.12) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color, width: level > 0 ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(def.name, style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(value == null ? '—' : fmtPid(def, value!),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(width: 4),
            Text(def.unit, style: const TextStyle(fontSize: 12, color: dimText)),
          ]),
        ]),
      ),
    );
  }
}

class DtcTile extends StatelessWidget {
  final String code;
  final String kind;
  final FreezeFrame? freeze;
  const DtcTile({super.key, required this.code, required this.kind, required this.freeze});

  @override
  Widget build(BuildContext context) {
    final info = DtcDb.lookup(code);
    return Card(
      child: ExpansionTile(
        leading: Dot(color: sevColor(info.severity)),
        title: Text('$code  ${info.title}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(kind, style: const TextStyle(color: dimText, fontSize: 12)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Что было в момент ошибки', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final l in FaultContext.explain(code, freeze)) Text('• $l'),
          const SizedBox(height: 8),
          const Text('Возможные причины', style: TextStyle(fontWeight: FontWeight.bold)),
          for (var i = 0; i < info.causes.length; i++) Text('${i + 1}. ${info.causes[i]}'),
          const SizedBox(height: 8),
          const Text('Что делать', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final s in info.steps) Text('• $s'),
        ],
      ),
    );
  }
}

class FindingTile extends StatelessWidget {
  final Finding x;
  const FindingTile({super.key, required this.x});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Dot(color: sevColor(x.severity)),
            const SizedBox(width: 8),
            Expanded(child: Text(x.title, style: const TextStyle(fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 4),
          Text(x.details),
          for (final a in x.actions) Text('• $a'),
        ]),
      ),
    );
  }
}

class ScoreRing extends StatelessWidget {
  final int score;
  final String verdict;
  const ScoreRing({super.key, required this.score, required this.verdict});

  @override
  Widget build(BuildContext context) {
    final col = score >= 85 ? okColor : (score >= 60 ? warnColor : alarmColor);
    return Panel(
      child: Row(children: [
        SizedBox(
          width: 96,
          height: 96,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 8,
              color: col,
              backgroundColor: const Color(0xFF2E4A66),
            ),
            Text('$score', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: col)),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(child: Text(verdict, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: col))),
      ]),
    );
  }
}

class VehicleCardW extends StatelessWidget {
  final VehicleInfo v;
  const VehicleCardW({super.key, required this.v});

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v.displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: vazCyan)),
        if (v.engine != null) Text('Двигатель: ${v.engine}'),
        if (v.country != null) Text('Страна производства: ${v.country}'),
        Text('Пробег: ${v.odometerKm == null ? 'ЭБУ не передаёт' : '${v.odometerKm!.toStringAsFixed(0)} км'}'),
        if (v.vin != null) Text('VIN: ${v.vin}'),
        Text('ЭБУ: ${v.ecuName ?? 'не определён'}'),
        if (v.calibrationId != null) Text('Калибровка: ${v.calibrationId}'),
        for (final n in v.notes) Text(n, style: const TextStyle(color: warnColor, fontSize: 12)),
      ]),
    );
  }
}

class CoverageCardW extends StatelessWidget {
  final Set<int> sup;
  final List<String> stored;
  const CoverageCardW({super.key, required this.sup, required this.stored});

  Color _col(int state) {
    switch (state) {
      case 3:
        return alarmColor;
      case 0:
        return okColor;
      case 1:
        return warnColor;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Что видит адаптер', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const Text('Зелёный — читается, оранжевый — частично, серый — стандарт не передаёт, красный — ошибка',
            style: TextStyle(fontSize: 12, color: dimText)),
        for (final c in coverageList(sup, stored))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name, style: TextStyle(color: _col(c.state), fontWeight: FontWeight.bold)),
              Text(c.note, style: const TextStyle(fontSize: 12)),
            ]),
          ),
      ]),
    );
  }
}

class ReadinessPanel extends StatelessWidget {
  final Readiness r;
  const ReadinessPanel({super.key, required this.r});

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(r.milOn ? 'Лампа Check Engine: ГОРИТ' : 'Лампа Check Engine: не горит',
            style: TextStyle(fontWeight: FontWeight.bold, color: r.milOn ? alarmColor : okColor)),
        Text('Кодов по данным ЭБУ: ${r.dtcCount}'),
        if (r.items.isNotEmpty) ...[
          const SizedBox(height: 6),
          const Text('Готовность систем', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final i in r.items)
            Text('${i.complete ? '✓' : '✗'} ${i.name}',
                style: TextStyle(color: i.complete ? okColor : warnColor, fontSize: 14)),
        ],
      ]),
    );
  }
}

class FreezeCard extends StatelessWidget {
  final FreezeFrame f;
  const FreezeCard({super.key, required this.f});

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Стоп-кадр${f.dtc != null ? ' (код ${f.dtc})' : ''}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const Text('Состояние двигателя в момент появления ошибки', style: TextStyle(fontSize: 12, color: dimText)),
        for (final e in f.values.entries)
          if (pidById[e.key] != null)
            Text('${pidById[e.key]!.name}: ${fmtPid(pidById[e.key]!, e.value)} ${pidById[e.key]!.unit}'),
      ]),
    );
  }
}
