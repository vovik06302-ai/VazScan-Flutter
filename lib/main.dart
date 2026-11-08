import 'package:flutter/material.dart';
import 'app_state.dart';
import 'theme.dart';
import 'ui/home.dart';

final AppState app = AppState();

void main() {
  runApp(const VazApp());
}

class VazApp extends StatelessWidget {
  const VazApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VAZ Scan',
      debugShowCheckedModeBanner: false,
      theme: vazTheme(),
      home: ListenableBuilder(
        listenable: app,
        builder: (context, _) => HomeShell(app: app),
      ),
    );
  }
}
