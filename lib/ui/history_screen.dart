import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import '../app_state.dart';
import '../compare.dart';
import '../diag/report.dart';
import '../pdf_export.dart';
import '../repairs.dart';
import '../theme.dart';
import 'widgets.dart';

class HistoryScreen extends StatefulWidget {
  final AppState app;
  const HistoryScreen({super.key, required this.app});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final Set<int> _sel = {};
  String? _filter;

  AppState get app => widget.app;

  List<SavedReport> get _visible =>
      _filter == null ? app.reports : app.reports.where((r) => r.vehicle == _filter).toList();

  void _toggle(SavedReport r) {
    setState(() {
      if (_sel.contains(r.id)) {
        _sel.remove(r.id);
      } else {
        if (_sel.length >= 2) _sel.clear();
        _sel.add(r.id);
      }
    });
  }

  (double, double) _range(List<double> d) {
    var a = d.first;
    var b = d.first;
    for (final v in d) {
      a = min(a, v);
      b = max(b, v);
    }
    if (b - a < 0.01) b = a + 0.01;
    return (a, b);
  }

  void _open(BuildContext context, SavedReport r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(r.title),
        content: SizedBox(
          width: double.maxFinite,
          height: 480,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SelectableText(r.text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              for (final e in r.traces.entries) ...[
                const SizedBox(height: 10),
                Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(
                  height: 110,
                  child: ScopeView(
                    title: '',
                    data: e.value,
                    min: _range(e.value).$1,
                    max: _range(e.value).$2,
                    level: 0,
                    valueText: e.value.last.toStringAsFixed(2),
                  ),
                ),
              ],
            ]),
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
            onPressed: () async {
              final path = await buildPdf(r);
              await OpenFilex.open(path, type: 'application/pdf');
            },
            child: const Text('PDF'),
          ),
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: r.text)),
            child: const Text('Копировать'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
        ],
      ),
    );
  }

  Widget _block(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        if (items.isEmpty) const Text('нет', style: TextStyle(color: dimText)),
        for (final i in items) Text('• $i'),
      ]),
    );
  }

  void _compare() {
    final list = app.reports.where((r) => _sel.contains(r.id)).toList()..sort((a, b) => a.id.compareTo(b.id));
    if (list.length != 2) return;
    final a = list[0];
    final b = list[1];
    final c = compareReports(a, b);
    final delta = c.after - c.before;
    final scoreText = (c.before < 0 || c.after < 0)
        ? 'Оценка недоступна для одного из отчётов'
        : 'Оценка: ${c.before} → ${c.after} (${delta >= 0 ? '+' : ''}$delta)';
    final odoText = (a.odometerKm != null && b.odometerKm != null)
        ? 'Пробег: ${a.odometerKm!.toStringAsFixed(0)} → ${b.odometerKm!.toStringAsFixed(0)} км'
        : null;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сравнение'),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Было: ${fmtDate(DateTime.fromMillisecondsSinceEpoch(a.id))}'),
            Text('Стало: ${fmtDate(DateTime.fromMillisecondsSinceEpoch(b.id))}'),
            if (odoText != null) Text(odoText),
            const SizedBox(height: 8),
            Text(scoreText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            _block('Пропали ошибки', c.removedCodes),
            _block('Появились ошибки', c.addedCodes),
            _block('Устранённые проблемы', c.fixedProblems),
            _block('Новые проблемы', c.newProblems),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть'))],
      ),
    );
  }

  void _addRepair() {
    final title = TextEditingController();
    final note = TextEditingController();
    final codes = TextEditingController(text: app.stored.join(', '));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый ремонт'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Что сделали, например «Заменил ДМРВ»')),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'Комментарий')),
            TextField(controller: codes, decoration: const InputDecoration(labelText: 'Коды, которые устранили (через запятую)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              final t = title.text.trim();
              if (t.isNotEmpty) {
                final cs = codes.text.split(',').map((e) => e.trim().toUpperCase()).where((e) => e.isNotEmpty).toList();
                app.addRepair(t, note.text.trim(), cs);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    final vehicles = app.reports.map((r) => r.vehicle).toSet().toList();
    if (vehicles.length < 2) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 6, children: [
      ChoiceChip(
        label: const Text('Все'),
        selected: _filter == null,
        onSelected: (_) => setState(() => _filter = null),
      ),
      for (final v in vehicles)
        ChoiceChip(
          label: Text(v.isEmpty ? 'Без авто' : v),
          selected: _filter == v,
          onSelected: (_) => setState(() => _filter = v),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final list = _visible;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(children: [
          const Expanded(child: SectionTitle('Журнал ремонтов')),
          IconButton(onPressed: _addRepair, icon: const Icon(Icons.add_circle, color: vazCyan)),
        ]),
        if (app.repairs.isEmpty)
          const Panel(child: Text('Записей нет. Нажмите «+», чтобы записать ремонт и коды, которые он устранил.')),
        for (final RepairEntry r in app.repairs)
          Card(
            child: ListTile(
              title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text([
                fmtDate(DateTime.fromMillisecondsSinceEpoch(r.id)),
                if (r.codes.isNotEmpty) 'коды: ${r.codes.join(', ')}',
                if (r.note.isNotEmpty) r.note,
              ].join('\n')),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => app.deleteRepair(r),
              ),
            ),
          ),
        const SectionTitle('Диагностики'),
        _filters(),
        const SizedBox(height: 8),
        if (_sel.length == 2)
          FilledButton.icon(
            onPressed: _compare,
            icon: const Icon(Icons.compare_arrows),
            label: const Text('Сравнить выбранные'),
          ),
        if (_sel.isNotEmpty && _sel.length < 2)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text('Отметьте ещё одну диагностику, чтобы сравнить.', style: TextStyle(color: dimText, fontSize: 12)),
          ),
        if (list.isEmpty)
          const Panel(child: Text('История пуста. Отчёты появятся после диагностики.')),
        for (final r in list)
          Card(
            child: ListTile(
              leading: Checkbox(
                value: _sel.contains(r.id),
                onChanged: r.score >= 0 ? (_) => _toggle(r) : null,
              ),
              title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text([
                fmtDate(DateTime.fromMillisecondsSinceEpoch(r.id)),
                if (r.vehicle.isNotEmpty) r.vehicle,
                if (r.odometerKm != null) '${r.odometerKm!.toStringAsFixed(0)} км',
              ].join('\n')),
              isThreeLine: true,
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
