import 'package:flutter/material.dart';

const vazCyan = Color(0xFF26C6DA);
const vazTeal = Color(0xFF00897B);
const vazViolet = Color(0xFF7E57C2);
const vazAmber = Color(0xFFFFB300);
const okColor = Color(0xFF43A047);
const warnColor = Color(0xFFFFA726);
const alarmColor = Color(0xFFEF5350);
const infoColor = Color(0xFF42A5F5);

/// Цвет второстепенного текста. Меняется вместе с темой (см. AppState.setPalette).
Color dimText = const Color(0xFF9FB3C8);

Color levelColor(int level) => level >= 2 ? alarmColor : (level == 1 ? warnColor : okColor);

Color sevColor(int sev) => sev >= 3 ? alarmColor : (sev == 2 ? warnColor : infoColor);

/// Набор цветов фона и текста
class Palette {
  final String id;
  final String name;
  final bool dark;
  final Color bg;
  final Color surface;
  final Color nav;
  final Color text;
  final Color dim;
  const Palette({
    required this.id,
    required this.name,
    required this.dark,
    required this.bg,
    required this.surface,
    required this.nav,
    required this.text,
    required this.dim,
  });
}

const List<Palette> palettes = [
  Palette(id: 'night', name: 'Ночная', dark: true, bg: Color(0xFF0D1B2A), surface: Color(0xFF16263A),
      nav: Color(0xFF112238), text: Color(0xFFE3F2FD), dim: Color(0xFF9FB3C8)),
  Palette(id: 'day', name: 'Дневная', dark: false, bg: Color(0xFFF2F7FA), surface: Color(0xFFFFFFFF),
      nav: Color(0xFFFFFFFF), text: Color(0xFF102A3A), dim: Color(0xFF546E7A)),
  Palette(id: 'contrast', name: 'Контраст', dark: true, bg: Color(0xFF000000), surface: Color(0xFF111111),
      nav: Color(0xFF000000), text: Color(0xFFFFFFFF), dim: Color(0xFFBDBDBD)),
  Palette(id: 'sport', name: 'Спорт', dark: true, bg: Color(0xFF0A0A0A), surface: Color(0xFF1A1A1A),
      nav: Color(0xFF111111), text: Color(0xFFF5F5F5), dim: Color(0xFF9E9E9E)),
];

const List<Color> accentColors = [
  Color(0xFF26C6DA), Color(0xFF1E88E5), Color(0xFF7E57C2),
  Color(0xFFFFB300), Color(0xFFEF5350), Color(0xFF66BB6A),
];

const List<String> accentNames = ['Бирюза', 'Океан', 'Фиолет', 'Янтарь', 'Красный', 'Зелёный'];

ThemeData vazTheme(Palette p, Color accent) {
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: p.dark ? Brightness.dark : Brightness.light,
  ).copyWith(
    primary: accent,
    surface: p.surface,
    onSurface: p.text,
    onSurfaceVariant: p.dim,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    cardTheme: CardTheme(
      color: p.surface,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.nav,
      indicatorColor: accent.withOpacity(0.25),
    ),
  );
}
