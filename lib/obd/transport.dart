import 'dart:math';
import 'package:flutter/services.dart';

/// Любой канал связи с адаптером. Позже сюда добавятся USB, Wi-Fi или BLE для оригинального сканера.
abstract class ObdTransport {
  Future<void> open();
  Future<void> close();
  Future<String> send(String cmd, {int timeoutMs = 3000});
}

class BtDevice {
  final String name;
  final String address;
  const BtDevice(this.name, this.address);
}

/// Bluetooth SPP через нативный канал (см. MainActivity.kt)
class BtTransport implements ObdTransport {
  static const _ch = MethodChannel('vazscan/bt');
  final String address;
  BtTransport(this.address);

  static Future<List<BtDevice>> paired() async {
    final list = (await _ch.invokeListMethod<dynamic>('paired')) ?? const [];
    return list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return BtDevice(m['name'] as String, m['address'] as String);
    }).toList();
  }

  @override
  Future<void> open() async {
    await _ch.invokeMethod('connect', {'address': address});
  }

  @override
  Future<void> close() async {
    await _ch.invokeMethod('disconnect');
  }

  @override
  Future<String> send(String cmd, {int timeoutMs = 3000}) async {
    final r = await _ch.invokeMethod<String>('send', {'cmd': cmd, 'timeout': timeoutMs});
    return r ?? '';
  }
}

/// Имитация ВАЗ 2112 для проверки без автомобиля
class DemoTransport implements ObdTransport {
  static const _sup = {
    0x01, 0x03, 0x04, 0x05, 0x06, 0x07, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10, 0x11,
    0x13, 0x14, 0x15, 0x1C, 0x1F, 0x20, 0x21, 0x2E, 0x40, 0x42,
  };
  final _r = Random();
  bool _open = false;
  bool _cleared = false;
  int _tick = 0;
  int _lam = 0;

  @override
  Future<void> open() async {
    await Future.delayed(const Duration(milliseconds: 700));
    _open = true;
  }

  @override
  Future<void> close() async {
    _open = false;
  }

  @override
  Future<String> send(String cmd, {int timeoutMs = 3000}) async {
    if (!_open) throw Exception('Нет соединения');
    await Future.delayed(const Duration(milliseconds: 60));
    _tick++;
    final c = cmd.trim().toUpperCase().replaceAll(' ', '');
    if (c == 'ATZ') return '\rELM327 v1.5\r';
    if (c == 'ATI') return 'ELM327 v1.5\r';
    if (c == 'ATDP') return 'AUTO, ISO 9141-2\r';
    if (c == 'ATRV') return '14.0V\r';
    if (c.startsWith('AT')) return 'OK\r';
    if (c == '0100') return 'SEARCHING...\r4100${_mask(0)}\r';
    if (c == '0120') return '4120${_mask(0x20)}\r';
    if (c == '0140') return '4140${_mask(0x40)}\r';
    if (c == '0160' || c == '0180' || c == '01A0' || c == '01C0') return 'NO DATA\r';
    if (c == '0101') return '${_cleared ? '410100076100' : '410182076101'}\r';
    if (c == '03') return '${_cleared ? '43000000000000' : '43017101350000'}\r';
    if (c == '07') return '${_cleared ? '47000000000000' : '47030000000000'}\r';
    if (c == '0A') return 'NO DATA\r';
    if (c == '04') {
      _cleared = true;
      return '44\r';
    }
    if (c == '0902') return '490201${_hex('XTA21120081234567')}\r';
    if (c == '090A') return '490A01${_hex('ECU-DEMO')}\r';
    if (c == '0904') return 'NO DATA\r';
    if (c == '020200') return _cleared ? 'NO DATA\r' : '4202000171\r';
    if (c.length == 6 && c.startsWith('02') && c.endsWith('00')) {
      final pid = int.parse(c.substring(2, 4), radix: 16);
      final d = _cleared ? null : _pidData(pid);
      return d == null ? 'NO DATA\r' : '42${_p2(pid)}00$d\r';
    }
    if (c.length == 4 && c.startsWith('01')) {
      final pid = int.parse(c.substring(2, 4), radix: 16);
      final d = _pidData(pid);
      return d == null ? 'NO DATA\r' : '41${_p2(pid)}$d\r';
    }
    return '?\r';
  }

  String _mask(int base) {
    var m = 0;
    for (var i = 1; i <= 32; i++) {
      if (_sup.contains(base + i)) m |= 1 << (32 - i);
    }
    return m.toRadixString(16).toUpperCase().padLeft(8, '0');
  }

  double _gauss() {
    final u1 = _r.nextDouble() + 1e-9;
    final u2 = _r.nextDouble();
    return sqrt(-2 * log(u1)) * cos(2 * pi * u2);
  }

  String _clampHex(num v, int max, int digits) {
    final x = v.round();
    final c = x < 0 ? 0 : (x > max ? max : x);
    return c.toRadixString(16).toUpperCase().padLeft(digits, '0');
  }

  String _b1(num v) => _clampHex(v, 255, 2);
  String _b2(num v) => _clampHex(v, 65535, 4);
  String _p2(int v) => v.toRadixString(16).toUpperCase().padLeft(2, '0');
  String _hex(String s) => s.codeUnits.map(_p2).join();

  String? _pidData(int pid) {
    final n = _gauss();
    switch (pid) {
      case 0x04:
        return _b1((28 + n) * 255 / 100);
      case 0x05:
        return _b1(129);
      case 0x06:
        return _b1(128 + (6 + n * 2) * 128 / 100);
      case 0x07:
        return _b1(128 + 14 * 128 / 100);
      case 0x0B:
        return _b1(36 + n);
      case 0x0C:
        return _b2((830 + n * 12) * 4);
      case 0x0D:
        return _b1(0);
      case 0x0E:
        return _b1((14 + n * 0.5 + 64) * 2);
      case 0x0F:
        return _b1(67);
      case 0x10:
        return _b2((2.9 + n * 0.05) * 100);
      case 0x11:
        return _b1(0.8 * 255 / 100);
      case 0x14:
        _lam++;
        return '${_b1((0.45 + 0.35 * sin(_lam * 0.9) + n * 0.02) * 200)}FF';
      case 0x15:
        return '${_b1((0.65 + n * 0.02) * 200)}FF';
      case 0x1F:
        return _b2(1260 + _tick);
      case 0x21:
        return _b2(42);
      case 0x2E:
        return _b1(0);
      case 0x42:
        return _b2((14.02 + n * 0.03) * 1000);
      case 0xA6:
        return (123456 * 10).toRadixString(16).toUpperCase().padLeft(8, '0');
      default:
        return null;
    }
  }
}
