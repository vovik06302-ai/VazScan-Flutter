import 'package:flutter/material.dart';
import '../app_state.dart';
import '../service.dart';
import '../theme.dart';
import 'widgets.dart';

class ConnectScreen extends StatefulWidget {
  final AppState app;
  const ConnectScreen({super.key, required this.app});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _cmd = TextEditingController();
  final _token = TextEditingController();

  @override
  void dispose() {
    _cmd.dispose();
    _token.dispose();
    super.dispose();
  }

  void _send() {
    final t = _cmd.text;
    if (t.trim().isEmpty) return;
    widget.app.sendRaw(t);
    _cmd.clear();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final ad = app.adapter;
    if (_token.text.isEmpty && app.token.isNotEmpty) _token.text = app.token;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Dot(color: app.connected ? (ad?.ecuResponds == true ? okColor : warnColor) : Colors.grey),
              const SizedBox(width: 8),
              Expanded(child: Text(app.status, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            ]),
            if (app.busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
            if (app.demo)
              const Text('ДЕМО-РЕЖИМ: данные имитируются', style: TextStyle(color: warnColor, fontWeight: FontWeight.bold)),
            if (ad != null) ...[
              Text('Адаптер: ${ad.version}'),
              Text('Протокол: ${ad.protocol}'),
              if (ad.voltage != null) Text('Напряжение: ${ad.voltage!.toStringAsFixed(1)} В'),
              for (final n in ad.notes) Text(n, style: const TextStyle(color: warnColor, fontSize: 12)),
            ],
            if (app.error != null) Text(app.error!, style: const TextStyle(color: alarmColor)),
          ]),
        ),
        if (app.vehicleInfo != null) ...[
          const SizedBox(height: 8),
          VehicleCardW(v: app.vehicleInfo!),
        ],
        const SectionTitle('Проверка адаптера'),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            OutlinedButton(
              onPressed: (app.connected && !app.checkingAdapter && !app.scanning && !app.working) ? app.checkAdapter : null,
              child: Text(app.checkingAdapter ? 'Проверка… около 10 секунд' : 'Проверить связь с адаптером'),
            ),
            if (app.adapterCheck != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: SelectableText(app.adapterCheck!)),
          ]),
        ),
        const SectionTitle('Напоминания по ТО'),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (app.vehicleInfo?.odometerKm == null)
              const Text('Пробег пока не получен: остаток покажется, когда ЭБУ его передаст.',
                  style: TextStyle(color: dimText, fontSize: 12)),
            for (var i = 0; i < app.services.length; i++) _serviceRow(app, i),
          ]),
        ),
        const SectionTitle('Адаптер ELM327'),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: app.busy ? null : app.refreshDevices,
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Найти адаптер'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: app.busy ? null : app.connectDemo,
              icon: const Icon(Icons.science),
              label: const Text('Демо'),
            ),
          ),
        ]),
        if (app.info != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(app.info!)),
        for (final d in app.devices)
          Card(
            child: ListTile(
              leading: const Icon(Icons.bluetooth),
              title: Text(d.name),
              subtitle: Text(d.address),
              trailing: FilledButton(
                onPressed: app.busy ? null : () => app.connectBt(d),
                child: const Text('Подключить'),
              ),
            ),
          ),
        if (app.connected) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: app.disconnect,
            icon: const Icon(Icons.link_off),
            label: const Text('Отключиться'),
          ),
        ],
        const SectionTitle('Обновление приложения'),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(app.updateStatus.isEmpty ? 'Текущая версия: ${app.version}' : app.updateStatus),
            if (app.updateBusy)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(value: app.updateProgress > 0 ? app.updateProgress : null),
              ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: app.updateBusy ? null : app.checkUpdate,
                  child: const Text('Проверить'),
                ),
              ),
              if (app.update != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: app.updateBusy ? null : app.installUpdate,
                    child: Text('Установить ${app.update!.tag}'),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: _token,
              decoration: const InputDecoration(
                labelText: 'Токен GitHub (нужен, если репозиторий приватный)',
                isDense: true,
              ),
              onSubmitted: (v) => app.setToken(v),
            ),
          ]),
        ),
        const SectionTitle('Терминал (для опытных)'),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _cmd,
              decoration: const InputDecoration(hintText: 'Команда, например 0100'),
              onSubmitted: (_) => _send(),
            ),
          ),
          IconButton(onPressed: app.connected ? _send : null, icon: const Icon(Icons.send)),
        ]),
        Container(
          height: 180,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFF0B1410), borderRadius: BorderRadius.circular(10)),
          child: ListView(
            reverse: true,
            children: [
              for (final l in app.terminal.reversed)
                Text(l, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFFB2EBF2))),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _serviceRow(AppState app, int i) {
  final s = app.services[i];
  final km = app.vehicleInfo?.odometerKm;
  final rem = km == null ? null : s.remaining(km);
  final String text;
  if (s.lastKm == null) {
    text = 'ещё не отмечалось, интервал ${s.intervalKm} км';
  } else if (rem == null) {
    text = 'интервал ${s.intervalKm} км';
  } else if (rem >= 0) {
    text = 'осталось ${rem.toStringAsFixed(0)} км';
  } else {
    text = 'просрочено на ${(-rem).toStringAsFixed(0)} км';
  }
  final Color? color = rem == null ? null : (rem < 0 ? alarmColor : (rem < 1000 ? warnColor : null));
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(text, style: TextStyle(color: color ?? dimText, fontSize: 13)),
        ]),
      ),
      TextButton(
        onPressed: km == null ? null : () => app.markServiceDone(i),
        child: const Text('Сделано'),
      ),
    ]),
  );
}
