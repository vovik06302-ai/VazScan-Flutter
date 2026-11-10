import 'package:flutter_test/flutter_test.dart';
import 'package:vazscan/obd/obd_client.dart';

void main() {
  test('названия протоколов', () {
    expect(protoName('3'), 'ISO 9141-2');
    expect(protoName('4'), 'KWP 5 бод');
    expect(protoName('x'), 'Авто');
  });
  test('список начинается с авто', () {
    expect(obdProtocols.first.code, '0');
  });
}
