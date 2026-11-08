import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../theme.dart';
import 'widgets.dart';

class ScanScreen extends StatelessWidget {
  final AppState app;
  const ScanScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final r = app.result;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        FilledButton.icon(
          onPressed: (app.connected && !app.scanning && !app.working) ? app.runScan : null,
          icon: const Icon(Icons.play_circle),
          label: Text(app.scanning ? 'Идёт диагностика…' : 'Полная диагностика'),
        ),
        if (!app.connected)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Сначала подключитесь на вкладке «Связь». Заведите двигатель и прогрейте его.'),
          ),
        if (app.scanning)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Panel(
              child: Column(children: [
                LinearProgressIndicator(value: app.scanProgress),
                const SizedBox(height: 6),
                Text(app.scanStage),
              ]),
            ),
          ),
        const SizedBox(height: 8),
        Panel(
          child: Row(children: [
            const Expanded(child: Text('Голосовые подсказки')),
            Switch(value: app.voice, onChanged: app.setVoice),
            OutlinedButton(
              onPressed: r == null ? null : app.speakResult,
              child: const Text('Озвучить'),
            ),
          ]),
        ),
        if (!app.voiceReady && app.voice)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Русский голос не найден на телефоне. Настройки → Синтез речи → Google → '
                'Установка голосовых данных → Русский.', style: TextStyle(color: warnColor, fontSize: 12)),
          ),
        if (r != null) ...[
          const SizedBox(height: 8),
          ScoreRing(score: r.analysis.score, verdict: r.analysis.verdict),
          if (r.readiness != null) ...[
            const SizedBox(height: 8),
            ReadinessPanel(r: r.readiness!),
          ],
          const SectionTitle('Выводы'),
          if (r.analysis.findings.isEmpty)
            const Panel(child: Text('Отклонений не найдено.', style: TextStyle(color: okColor))),
          for (final x in r.analysis.findings) FindingTile(x: x),
          if (r.stored.isNotEmpty) ...[
            const SectionTitle('Сохранённые ошибки'),
            for (final c in r.stored) DtcTile(code: c, kind: 'сохранённая', freeze: r.freeze),
          ],
          if (r.pending.isNotEmpty) ...[
            const SectionTitle('Ожидающие ошибки'),
            for (final c in r.pending) DtcTile(code: c, kind: 'ожидающая', freeze: r.freeze),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: r.text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Отчёт скопирован. Вставьте его в мессенджер')),
              );
            },
            icon: const Icon(Icons.share),
            label: const Text('Скопировать отчёт'),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Отчёт сохранён во вкладке «История».', style: TextStyle(fontSize: 12, color: dimText)),
          ),
        ],
      ],
    );
  }
}
