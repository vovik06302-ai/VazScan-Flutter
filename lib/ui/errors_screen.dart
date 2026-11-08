import 'package:flutter/material.dart';
import '../app_state.dart';
import 'widgets.dart';

class ErrorsScreen extends StatelessWidget {
  final AppState app;
  const ErrorsScreen({super.key, required this.app});

  void _confirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сбросить ошибки?'),
        content: const Text(
            'Текущие ошибки будут сохранены в историю. После сброса обнулятся готовность систем и адаптации ЭБУ. Если причина не устранена, ошибка вернётся.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              app.clearErrors();
            },
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = app.working || app.scanning;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(children: [
          Expanded(
            child: FilledButton(
              onPressed: (app.connected && !busy) ? () => app.readErrors() : null,
              child: const Text('Прочитать'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: (app.connected && app.errorsRead && !busy) ? () => _confirm(context) : null,
              child: const Text('Сбросить'),
            ),
          ),
        ]),
        if (app.working) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
        if (app.info != null) Padding(padding: const EdgeInsets.only(top: 8), child: Panel(child: Text(app.info!))),
        if (!app.connected) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Нет подключения к адаптеру.')),
        if (app.errorsRead) ...[
          if (app.readiness != null) ...[
            const SizedBox(height: 8),
            ReadinessPanel(r: app.readiness!),
          ],
          if (app.stored.isEmpty && app.pending.isEmpty && app.permanent.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Panel(child: Text('Ошибок нет', style: TextStyle(color: Color(0xFF43A047)))),
            ),
          if (app.stored.isNotEmpty) ...[
            const SectionTitle('Сохранённые ошибки'),
            for (final c in app.stored) DtcTile(code: c, kind: 'сохранённая', freeze: app.freeze),
          ],
          if (app.pending.isNotEmpty) ...[
            const SectionTitle('Ожидающие ошибки'),
            for (final c in app.pending) DtcTile(code: c, kind: 'ожидающая', freeze: app.freeze),
          ],
          if (app.permanent.isNotEmpty) ...[
            const SectionTitle('Постоянные ошибки'),
            for (final c in app.permanent) DtcTile(code: c, kind: 'постоянная', freeze: app.freeze),
          ],
          if (app.freeze != null) ...[
            const SizedBox(height: 8),
            FreezeCard(f: app.freeze!),
          ],
        ],
      ],
    );
  }
}
