import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';
import 'connect_screen.dart';
import 'errors_screen.dart';
import 'history_screen.dart';
import 'live_screen.dart';
import 'scan_screen.dart';

class HomeShell extends StatefulWidget {
  final AppState app;
  const HomeShell({super.key, required this.app});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return Scaffold(
      appBar: AppBar(
        title: Text('VAZ Scan ${app.version}', style: const TextStyle(fontWeight: FontWeight.bold)),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(gradient: LinearGradient(colors: [vazTeal, vazViolet])),
        ),
      ),
      body: IndexedStack(
        index: tab,
        children: [
          ConnectScreen(app: app),
          ScanScreen(app: app),
          ErrorsScreen(app: app),
          LiveScreen(app: app),
          HistoryScreen(app: app),
        ],
      ),
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
