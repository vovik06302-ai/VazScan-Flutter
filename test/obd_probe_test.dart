import 'package:flutter_test/flutter_test.dart';
import 'package:vazscan/obd/obd_client.dart';
import 'package:vazscan/obd/transport.dart';

/// Адаптер-заглушка: отвечает только на заданные команды, остальные - NO DATA.
class FakeTransport implements ObdTransport {
  final Map<String, String> replies;
  FakeTransport(this.replies);

  @override
  Future<void> open() async {}

  @override
  Future<void> close() async {}

  @override
  Future<String> send(String cmd, {int timeoutMs = 3000}) async {
    final c = cmd.replaceAll(' ', '').toUpperCase();
    return replies[c] ?? 'NO DATA\r>';
  }
}

final _base = <String, String>{
  'ATI': 'ELM327 v1.5\r>',
  'ATDP': 'ISO 9141-2\r>',
  'ATRV': '12.4V\r>',
};

void main() {
  test('ЭБУ, который молчит на 0100, но отвечает на 0105, считается подключённым', () async {
    final c = ObdClient(FakeTransport({..._base, '0105': '41 05 5A\r>'}));
    final ai = await c.initialize(protocol: '3');
    expect(ai.ecuResponds, isTrue);
    expect(c.probeHit, '0105');
    expect(ai.notes.any((n) => n.contains('0105')), isTrue);
  });

  test('автоподбор находит ЭБУ, отвечающий на VIN-запрос 0902', () async {
    final c = ObdClient(FakeTransport({..._base, '0902': '49 02 01 00 00 00 01\r>'}));
    final ai = await c.initialize();
    expect(ai.ecuResponds, isTrue);
    expect(c.probeHit, '0902');
  });

  test('если ЭБУ не отвечает ни на что, связь честно помечается как неудачная', () async {
    final c = ObdClient(FakeTransport({..._base}));
    final ai = await c.initialize();
    expect(ai.ecuResponds, isFalse);
    expect(ai.notes.any((n) => n.contains('ни на один запрос')), isTrue);
  });

  test('ответ адаптера с ошибкой (BUS INIT) не принимается за ответ ЭБУ', () async {
    final c = ObdClient(FakeTransport({..._base, '0100': 'BUS INIT: ERROR\r>'}));
    final ai = await c.initialize(protocol: '3');
    expect(ai.ecuResponds, isFalse);
  });
}
