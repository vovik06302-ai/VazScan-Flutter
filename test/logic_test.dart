import 'package:flutter_test/flutter_test.dart';
import 'package:vazscan/app_state.dart';
import 'package:vazscan/compare.dart';
import 'package:vazscan/diag/analysis.dart';
import 'package:vazscan/diag/dtc.dart';
import 'package:vazscan/obd/obd_client.dart';
import 'package:vazscan/obd/vehicle.dart';

void main() {
  test('коды ошибок декодируются из двух байт', () {
    expect(decodeDtc(0x01, 0x71), 'P0171');
    expect(decodeDtc(0x43, 0x00), 'C0300');
  });

  test('известный код имеет описание, неизвестный - общее', () {
    expect(DtcDb.lookup('P0171').title, contains('бедная'));
    expect(DtcDb.lookup('P0261').severity, 2);
    expect(DtcDb.lookup('P1234').title, contains('P1234'));
  });

  test('тревога по температуре ОЖ', () {
    expect(evalAlarm(0x05, 110, true)?.level, 2);
    expect(evalAlarm(0x05, 90, true), isNull);
  });

  test('без живых данных оценка 98 и вывод', () {
    final a = analyze(stored: [], pending: [], permanent: [], snaps: [], lambda: [], readiness: null);
    expect(a.score, 98);
    expect(a.findings.first.title, 'Живые данные не получены');
  });

  test('сохранённая ошибка сильно снижает оценку', () {
    final a = analyze(stored: ['P0300'], pending: [], permanent: [], snaps: [], lambda: [], readiness: null);
    expect(a.score, lessThan(85));
    expect(a.verdict, isNot('Хорошее состояние'));
  });

  test('сравнение отчётов находит пропавшие и новые ошибки', () {
    final before = SavedReport(1, 'a', 80, 't', codes: ['P0171', 'P0300'], findings: ['x']);
    final after = SavedReport(2, 'b', 90, 't', codes: ['P0300', 'P0420'], findings: ['y']);
    final c = compareReports(before, after);
    expect(c.before, 80);
    expect(c.after, 90);
    expect(c.removedCodes, ['P0171']);
    expect(c.addedCodes, ['P0420']);
    expect(c.fixedProblems, ['x']);
    expect(c.newProblems, ['y']);
  });

  test('VIN: марка и год по коду завода', () {
    const vin = 'XTA21120081234567';
    expect(VinDecoder.wmi(vin), 'Lada (ВАЗ)');
    expect(VinDecoder.yearFromVin(vin), 2008);
    expect(VinDecoder.yearFromVin('XTA21120061234567'), 2006);
  });
}
