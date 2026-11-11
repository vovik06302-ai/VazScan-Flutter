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

/// Блок отвечает только после ATKW0 и ATIB10, как старые блоки K-линии.
class KwTransport implements ObdTransport {
  final List<String> sent = [];

  @override
  Future<void> open() async {}

  @override
  Future<void> close() async {}

  @override
  Future<String> send(String cmd, {int timeoutMs = 3000}) async {
    final c = cmd.replaceAll(' ', '').toUpperCase();
    sent.add(c);
    if (c == 'ATI') return 'ELM327 v2.1\r>';
    if (c == 'ATDP') return 'ISO 9141-2\r>';
    if (c == 'ATRV') return '13.2V\r>';
    if (c.startsWith('AT')) return 'OK\r>';
    final ready = sent.contains('ATKW0') && sent.contains('ATIB10');
    if (ready && c == '0105') return '41 05 5A\r>';
    return 'BUS INIT: ...ERROR\r>';
  }
}

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

  test('вариант ISO 9141-2 с ATKW0 и ATIB10 находит блок, который не отвечает на обычную инициализацию', () async {
    final tr = KwTransport();
    final c = ObdClient(tr);
    final ai = await c.initialize();
    expect(ai.ecuResponds, isTrue);
    expect(c.usedIsoVariant, isTrue);
    expect(tr.sent.contains('ATKW0'), isTrue);
    expect(ai.notes.any((n) => n.contains('ATKW0')), isTrue);
  });
}
