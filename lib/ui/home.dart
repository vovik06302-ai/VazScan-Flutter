import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_state.dart';
import '../theme.dart';
import 'connect_screen.dart';
import 'errors_screen.dart';
import 'history_screen.dart';
import 'live_screen.dart';
import 'scan_screen.dart';

const _disclaimerText =
    'VAZ Scan помогает диагностировать автомобиль, но не заменяет специалиста.\n\n'
    '• Рекомендации по устранению ориентировочные. Решения о ремонте принимает специалист.\n'
    '• Если тревога красная, НЕ ЕЗДИТЕ. Остановитесь в безопасном месте и проверьте причину.\n'
    '• Приложение не управляет автомобилем. Единственное изменение ЭБУ: сброс ошибок по вашей команде.\n'
    '• Сброс ошибок стирает стоп-кадр. Сохраните отчёт до сброса.\n'
    '• Данные могут быть неверными при плохом адаптере или нестабильной связи.';

class HomeShell extends StatefulWidget {
  final AppState app;
  const HomeShell({super.key, required this.app});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _disclaimer());
  }

  Future<void> _disclaimer() async {
    final p = await SharedPreferences.getInstance();
    if (p.getBool('ack_v1') == true || !mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Важно'),
        content: const SingleChildScrollView(child: Text(_disclaimerText)),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Понятно'))],
      ),
    );
    await p.setBool('ack_v1', true);
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return Scaffold(
      appBar: AppBar(
        title: Text('VAZ Scan ${app.version}', style: const TextStyle(fontWeight: FontWeight.bold)),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(gradient: LinearGradient(colors: [app.accentColor, app.accentDark])),
        ),
      ),
      body: Column(children: [
        if (app.error != null)
          Container(
            width: double.infinity,
            color: alarmColor.withOpacity(0.2),
            padding: const EdgeInsets.all(8),
            child: Text(app.error!, style: const TextStyle(color: alarmColor, fontWeight: FontWeight.bold)),
          ),
        Expanded(
          child: IndexedStack(
            index: tab,
            children: [
              ConnectScreen(app: app),
              ScanScreen(app: app),
              ErrorsScreen(app: app),
              LiveScreen(app: app),
              HistoryScreen(app: app),
            ],
          ),
        ),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.bluetooth), label: 'Связь'),
          NavigationDestination(icon: Icon(Icons.fact_check), label: 'Диагностика'),
          NavigationDestination(icon: Icon(Icons.warning_amber), label: 'Ошибки'),
          NavigationDestination(icon: Icon(Icons.speed), label: 'Датчики'),
          NavigationDestination(icon: Icon(Icons.history), label: 'История'),
        ],
      ),
    );
  }
}
