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
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => MaterialApp(
        title: 'VAZ Scan',
        debugShowCheckedModeBanner: false,
        theme: vazTheme(app.palette, app.accentColor),
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(app.bigText ? 1.3 : 1.0)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: HomeShell(app: app),
      ),
    );
  }
}
