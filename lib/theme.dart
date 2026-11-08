import 'package:flutter/material.dart';

const vazCyan = Color(0xFF26C6DA);
const vazTeal = Color(0xFF00897B);
const vazViolet = Color(0xFF7E57C2);
const vazAmber = Color(0xFFFFB300);
const okColor = Color(0xFF43A047);
const warnColor = Color(0xFFFFA726);
const alarmColor = Color(0xFFEF5350);
const infoColor = Color(0xFF42A5F5);
const dimText = Color(0xFF9FB3C8);

Color levelColor(int level) => level >= 2 ? alarmColor : (level == 1 ? warnColor : okColor);

Color sevColor(int sev) => sev >= 3 ? alarmColor : (sev == 2 ? warnColor : infoColor);

ThemeData vazTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: vazCyan, brightness: Brightness.dark).copyWith(
    primary: vazCyan,
    secondary: vazViolet,
    tertiary: vazAmber,
    surface: const Color(0xFF16263A),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF0D1B2A),
    cardTheme: CardTheme(
      color: const Color(0xFF16263A),
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    navigationBarTheme: const NavigationBarThemeData(backgroundColor: Color(0xFF112238)),
  );
}
