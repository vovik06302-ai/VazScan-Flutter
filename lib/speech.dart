import 'package:flutter_tts/flutter_tts.dart';
import 'diag/dtc.dart';
import 'obd/models.dart';

/// Голос на встроенном синтезаторе. Работает без интернета, если установлен русский голос.
class Speaker {
  final FlutterTts _tts = FlutterTts();
  bool enabled = true;

  Future<void> init() async {
    try {
      await _tts.setLanguage('ru-RU');
      await _tts.setSpeechRate(0.5);
    } catch (_) {}
  }

  /// Есть ли русский голос на телефоне. Без него приложение молчит.
  Future<bool> russianReady() async {
    try {
      final r = await _tts.isLanguageAvailable('ru-RU');
      return r == true || r == 1;
    } catch (_) {
      return false;
    }
  }

  void say(String text) {
    if (!enabled) return;
    _tts.speak(text);
  }
}

String _spell(String code) => code.split('').join(' ');

/// Фраза с итогом диагностики
String phraseFor(ScanResult r) {
  final out = <String>[];
  out.add('Диагностика завершена. ${r.analysis.verdict}. Оценка ${r.analysis.score} из 100.');
  final codes = {...r.stored, ...r.pending}.toList();
  if (codes.isEmpty) {
    out.add('Ошибок не найдено.');
  } else {
    out.add('Найдено ошибок: ${codes.length}.');
    for (final c in codes.take(3)) {
      out.add('Код ${_spell(c)}. ${DtcDb.lookup(c).title}.');
    }
    if (codes.length > 3) out.add('И ещё ${codes.length - 3}. Подробности на экране.');
  }
  for (final f in r.analysis.findings.take(2)) {
    out.add('${f.title}.');
  }
  return out.join(' ');
}
