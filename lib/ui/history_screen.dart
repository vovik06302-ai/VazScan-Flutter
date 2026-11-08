import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../diag/report.dart';
import '../theme.dart';
import 'widgets.dart';

class HistoryScreen extends StatelessWidget {
  final AppState app;
  const HistoryScreen({super.key, required this.app});

  void _open(BuildContext context, SavedReport r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(r.title),
        content: SizedBox(
          width: double.maxFinite,
          height: 420,
          child: SingleChildScrollView(
            child: SelectableText(r.text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              app.deleteReport(r);
              Navigator.pop(ctx);
            },
            child: const Text('Удалить'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: r.text));
            },
            child: const Text('Копировать'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (app.reports.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: const [Panel(child: Text('История пуста. Отчёты появятся после диагностики.'))],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final r in app.reports)
          Card(
            child: ListTile(
              title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(fmtDate(DateTime.fromMillisecondsSinceEpoch(r.id))),
              trailing: r.score >= 0
                  ? Text(
                      '${r.score}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: r.score >= 85 ? okColor : (r.score >= 60 ? warnColor : alarmColor),
                      ),
                    )
                  : null,
              onTap: () => _open(context, r),
            ),
          ),
      ],
    );
  }
}
