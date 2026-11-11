import 'package:flutter_test/flutter_test.dart';
import 'package:vazscan/obd/ecu_january.dart';

void main() {
  test('версии с точками распознаются целиком: 5.1.1 не путается с 5.1', () {
    expect(detectJanuary('Январь 5.1.1', null)?.version, '5.1.1');
    expect(detectJanuary('Январь 5.1', null)?.version, '5.1');
    expect(detectJanuary('Январь-4.1', null)?.version, '4.1');
    expect(detectJanuary('Январь-4', null)?.version, '4');
  });

  test('запятая в номере версии тоже работает', () {
    expect(detectJanuary('Январь 7,2', null)?.name, 'Январь 7.2');
  });

  test('латиница и ID калибровки', () {
    expect(detectJanuary(null, 'JANUARY 7.2 2112')?.version, '7.2');
    expect(detectJanuary('ECU', 'Yanvar 5.1')?.version, '5.1');
  });

  test('версия без номера или не из таблицы', () {
    final noVer = detectJanuary('Январь', null);
    expect(noVer?.name, 'Январь (версия не определена)');
    expect(noVer?.version, isNull);
    final unknown = detectJanuary('Январь 9.9', null);
    expect(unknown?.name, 'Январь 9.9');
    expect(unknown?.version, isNull);
  });

  test('чужой блок не распознаётся', () {
    expect(detectJanuary('Bosch ME7.9.7', '1234'), isNull);
    expect(detectJanuary(null, null), isNull);
  });

  test('к каждому распознанному блоку добавляется подсказка по протоколу', () {
    expect(detectJanuary('Январь 5.1', null)?.notes.any((n) => n.contains('ISO 9141-2')), isTrue);
  });
}
