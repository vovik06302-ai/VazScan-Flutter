import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';
import 'widgets.dart';

class FuelPanel extends StatelessWidget {
  final AppState app;
  const FuelPanel({super.key, required this.app});

  void _refuelDialog(BuildContext context) {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Заправка'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Сколько литров залили? По этой заправке уточним расчёт расхода.'),
          TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Литров'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(c.text.replaceAll(',', '.'));
              Navigator.pop(ctx);
              if (v == null) return;
              final ok = app.refuel(v);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ok
                    ? 'Расчёт уточнён по заправке'
                    : 'Мало данных с прошлой заправки. Нужно проехать больше.'),
              ));
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Widget _big(String label, String value, String unit) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: dimText, fontSize: 12)),
      Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
      Text(unit, style: TextStyle(color: dimText, fontSize: 12)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final f = app.fuel;
    final inst = f.instant;
    final lph = f.lph;
    final avg = f.avgPer100;
    final nowValue = inst != null
        ? inst.toStringAsFixed(1)
        : (lph != null ? lph.toStringAsFixed(1) : '—');
    final nowUnit = inst != null ? 'л/100 км' : (lph != null ? 'л/ч (стоим)' : '');
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Расход топлива', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _big('Сейчас', nowValue, nowUnit)),
          Expanded(
            child: _big('Средний за поездку', avg == null ? '—' : avg.toStringAsFixed(1),
                avg == null ? 'нужно больше километров' : 'л/100 км'),
          ),
        ]),
        const SizedBox(height: 8),
        Text('Поездка: ${f.tripKm.toStringAsFixed(1)} км, ${f.tripLiters.toStringAsFixed(2)} л',
            style: const TextStyle(fontSize: 13)),
        Text('Поправка по заправкам: ×${f.factor.toStringAsFixed(2)}', style: TextStyle(color: dimText, fontSize: 12)),
        Text('Оценка по датчику воздуха: погрешность около 10–15 %. Точнее станет после заправки с указанием литров.',
            style: TextStyle(color: dimText, fontSize: 11)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton(onPressed: app.resetFuelTrip, child: const Text('Новая поездка')),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(onPressed: () => _refuelDialog(context), child: const Text('Заправка')),
          ),
        ]),
      ]),
    );
  }
}
