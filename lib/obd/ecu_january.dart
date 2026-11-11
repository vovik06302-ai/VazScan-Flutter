/// Блоки управления семейства «Январь» (российские ЭБУ для ВАЗ и не только).
/// Список версий можно дополнять: распознавание работает по этой таблице.
class JanuaryVersion {
  final String version; // как записано в названии блока: '5.1', '5.1.1' и т. п.
  final String name;
  const JanuaryVersion(this.version, this.name);
}

const januaryVersions = <JanuaryVersion>[
  JanuaryVersion('2', 'Январь 2'),
  JanuaryVersion('4', 'Январь 4'),
  JanuaryVersion('4.1', 'Январь 4.1'),
  JanuaryVersion('5.1', 'Январь 5.1'),
  JanuaryVersion('5.1.1', 'Январь 5.1.1'),
  JanuaryVersion('7.2', 'Январь 7.2'),
];

/// Результат распознавания блока «Январь».
class JanuaryMatch {
  final String name; // 'Январь 5.1.1' или 'Январь (версия не определена)'
  final String? version; // null, если версия не названа или не в таблице
  final List<String> notes;
  const JanuaryMatch(this.name, this.version, this.notes);
}

/// Ищет в названии ЭБУ (Mode 09 0A) или ID калибровки (Mode 09 04)
/// слово «Январь» и номер версии рядом с ним.
final _januaryRe = RegExp(r'(январ[ьяеиюу]|yanvar|january)\D{0,6}(\d+(?:[.,]\d+){0,2})?');

const _protocolNote =
    'Блоки «Январь» работают по K-линии. Если связь нестабильна, выберите протокол ISO 9141-2 (3) в настройках.';

/// Возвращает null, если блок не похож на «Январь».
JanuaryMatch? detectJanuary(String? ecuName, String? calibrationId) {
  final text = '${ecuName ?? ''} ${calibrationId ?? ''}'.toLowerCase();
  final m = _januaryRe.firstMatch(text);
  if (m == null) return null;

  final raw = m.group(2)?.replaceAll(',', '.');
  if (raw == null) {
    return const JanuaryMatch(
      'Январь (версия не определена)',
      null,
      ['Блок не назвал версию Январь. Сверьте наклейку на блоке.', _protocolNote],
    );
  }
  for (final v in januaryVersions) {
    if (v.version == raw) {
      return JanuaryMatch(v.name, v.version, [_protocolNote]);
    }
  }
  return JanuaryMatch(
    'Январь $raw',
    null,
    ['Версия $raw нет в списке известных. Сверьте наклейку на блоке.', _protocolNote],
  );
}
