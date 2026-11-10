import 'package:flutter/material.dart';
import '../app_state.dart';
import '../diag/analysis.dart';
import '../obd/models.dart';
import '../obd/pids.dart';
import '../theme.dart';
import 'widgets.dart';
import 'fuel_panel.dart';

class _G {
  final int pid;
  final String title;
  final String unit;
  final double min;
  final double max;
  final int dec;
  const _G(this.pid, this.title, this.unit, this.min, this.max, this.dec);
}

class _S {
  final int pid;
  final String title;
  final double min;
  final double max;
  final int dec;
  const _S(this.pid, this.title, this.min, this.max, this.dec);
}

const _gauges = [
  _G(0x0C, 'Обороты', 'об/мин', 0, 7000, 0),
  _G(0x05, 'Температура ОЖ', '°C', 40, 130, 0),
  _G(0x42, 'Напряжение бортсети / генератор', 'В', 10, 16, 1),
  _G(0x04, 'Нагрузка', '%', 0, 100, 0),
  _G(0x0B, 'Давление во впуске', 'кПа', 20, 110, 0),
  _G(0x11, 'Положение дросселя', '%', 0, 100, 0),
];

const _scopes = [
  _S(0x14, 'Лямбда-зонд 1 (осциллограмма)', 0, 1, 2),
  _S(0x06, 'Коррекция топлива кратковременная, %', -25, 25, 1),
  _S(0x07, 'Коррекция топлива долговременная, %', -25, 25, 1),
];

class LiveScreen extends StatelessWidget {
  final AppState app;
  const LiveScreen({super.key, required this.app});

  Widget _gaugeCell(_G g, bool running) {
    final v = app.live[g.pid];
    final lvl = v == null ? 0 : levelFor(g.pid, v, running);
    return Panel(
      child: buildGauge(
        style: app.gaugeStyle,
        glow: app.palette.glow,
        title: g.title,
        unit: g.unit,
        value: v,
        min: g.min,
        max: g.max,
        dec: g.dec,
        color: v == null ? Colors.grey : levelColor(lvl),
      ),
    );
  }

  Widget _scopeCell(_S s, bool running, List<Alarm> alarms) {
    final data = app.hist[s.pid] ?? const <double>[];
    final last = data.isEmpty ? null : data.last;
    final int lvl;
    if (s.pid == 0x14) {
      lvl = alarms.any((a) => a.name == 'Лямбда-зонд 1') ? 2 : 0;
    } else {
      lvl = last == null ? 0 : levelFor(s.pid, last, running);
    }
    return ScopeView(
      title: s.title,
      data: data,
      min: s.min,
      max: s.max,
      level: lvl,
      valueText: last == null ? '—' : last.toStringAsFixed(s.dec),
    );
  }

  Widget _tile(PidDef d, bool running) {
    final v = app.live[d.pid];
    return PidTile(def: d, value: v, level: v == null ? 0 : levelFor(d.pid, v, running));
  }

  @override
  Widget build(BuildContext context) {
    final running = (app.live[0x0C] ?? 0) > 400;
    final alarms = [...alarmsFor(app.live, app.hist), ...dtcAlarms(app.stored)]
      ..sort((a, b) => b.level.compareTo(a.level));
    final tiles = allPids.where((p) => app.supported.contains(p.pid)).toList();
    final canStart = app.connected && !app.scanning && !app.working && (app.liveOn || app.dashPids.isNotEmpty);
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        Row(children: [
          Expanded(child: Text('Крупный шрифт')),
          Switch(value: app.bigText, onChanged: app.setBigText),
        ]),
        FilledButton.icon(
          onPressed: canStart
              ? () {
                  if (app.liveOn) {
                    app.stopLive();
                  } else {
                    app.startLive();
                  }
                }
              : null,
          icon: Icon(app.liveOn ? Icons.stop : Icons.play_arrow),
          label: Text(app.liveOn ? 'Остановить' : 'Запустить опрос'),
        ),
        if (!app.connected) Padding(padding: EdgeInsets.only(top: 8), child: Text('Нет подключения к адаптеру.')),
        SizedBox(height: 8),
        AlarmBanner(alarms: alarms, live: app.liveOn || app.live.isNotEmpty),
        SizedBox(height: 8),
        FuelPanel(app: app),
        const SizedBox(height: 8),
        CoverageCardW(sup: app.supported, stored: app.stored),
        SectionTitle('Приборы'),
        for (var i = 0; i < _gauges.length; i += 2)
          Row(children: [
            Expanded(child: _gaugeCell(_gauges[i], running)),
            SizedBox(width: 8),
            Expanded(child: i + 1 < _gauges.length ? _gaugeCell(_gauges[i + 1], running) : SizedBox()),
          ]),
        SectionTitle('Осциллографы'),
        for (final s in _scopes)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: _scopeCell(s, running, alarms)),
        SectionTitle('Все параметры'),
        if (tiles.isEmpty && app.connected)
          Panel(child: Text('ЭБУ не сообщил ни об одном поддерживаемом параметре.')),
        for (var i = 0; i < tiles.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Expanded(child: _tile(tiles[i], running)),
              SizedBox(width: 8),
              Expanded(child: i + 1 < tiles.length ? _tile(tiles[i + 1], running) : SizedBox()),
            ]),
          ),
        SizedBox(height: 12),
        Text(
          'Обновление около 1–2 раз в секунду: ограничение ELM327 по Bluetooth. Для быстрых осциллограмм нужен профессиональный сканер.',
          style: TextStyle(fontSize: 11, color: dimText),
        ),
      ],
    );
  }
}
