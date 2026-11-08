import 'dart:convert';
import 'package:http/http.dart' as http;

class VehicleInfo {
  final String? vin;
  final String? make;
  final String? model;
  final int? year;
  final String? engine;
  final String? country;
  final double? odometerKm;
  final String? ecuName;
  final String? calibrationId;
  final List<String> notes;
  const VehicleInfo({
    this.vin,
    this.make,
    this.model,
    this.year,
    this.engine,
    this.country,
    this.odometerKm,
    this.ecuName,
    this.calibrationId,
    this.notes = const [],
  });

  String get displayName {
    final s = [make, model, year?.toString()].whereType<String>().join(' ');
    return s.isEmpty ? 'Автомобиль' : s;
  }
}

class VinDecoder {
  static const _wmi3 = {
    'XTA': 'Lada (ВАЗ)', 'XTT': 'Lada (ВАЗ)', 'XTH': 'Lada (ВАЗ)', 'X9F': 'Lada (ВАЗ)',
    'XW8': 'Volkswagen (Россия)', 'KL1': 'Daewoo/Chevrolet', 'KLA': 'Daewoo',
    'WVW': 'Volkswagen', 'WVG': 'Volkswagen', 'WAU': 'Audi', 'TRU': 'Audi',
    'WBA': 'BMW', 'WBS': 'BMW M', 'WDD': 'Mercedes-Benz', 'WDB': 'Mercedes-Benz',
    'JTD': 'Toyota', 'JTE': 'Toyota', 'JTM': 'Toyota', 'SB1': 'Toyota', 'MR0': 'Toyota',
    'JHM': 'Honda', 'JHL': 'Honda', '1HG': 'Honda',
    'JMZ': 'Mazda', 'JM1': 'Mazda', 'JN1': 'Nissan', 'JN8': 'Nissan', 'SJN': 'Nissan',
    'JS3': 'Suzuki', 'JF1': 'Subaru',
    'KMH': 'Hyundai', 'KMF': 'Hyundai', 'TMA': 'Hyundai', 'Z94': 'Hyundai',
    'KNA': 'Kia', 'U5Y': 'Kia',
    'TMB': 'Skoda', 'TMP': 'Skoda', 'VSS': 'SEAT',
    'VF1': 'Renault', 'VF3': 'Peugeot', 'VF7': 'Citroën', 'UU1': 'Dacia',
    '1G1': 'Chevrolet', '1GC': 'Chevrolet', '1FA': 'Ford', '1FT': 'Ford', 'WF0': 'Ford',
    'YV1': 'Volvo', 'SAL': 'Land Rover', 'SAJ': 'Jaguar',
    'ZFA': 'Fiat', 'ZAR': 'Alfa Romeo', 'ZFF': 'Ferrari',
    'LSV': 'SAIC/Volkswagen (Китай)', 'LVV': 'Chery', 'LFV': 'FAW-VW',
  };

  static const _wmi2 = {
    'JT': 'Toyota', 'JH': 'Honda', 'JN': 'Nissan', 'JM': 'Mazda', 'KM': 'Hyundai',
    'WV': 'Volkswagen', 'WA': 'Audi', 'WB': 'BMW', 'WD': 'Mercedes-Benz',
    'VF': 'Франция', 'TM': 'Skoda', 'ZF': 'Fiat', 'YV': 'Volvo', 'SA': 'Land Rover/Jaguar',
    '1G': 'General Motors', '1F': 'Ford',
  };

  static const _lada = {
    '2101': '2101', '2105': '2105', '2107': '2107', '2108': '2108', '2109': '2109',
    '2110': '2110', '2111': '2111', '2112': '2112', '2113': '2113', '2114': '2114',
    '2115': '2115', '2123': 'Niva 2123', '2170': 'Priora 2170', '2172': 'Kalina 2172',
    '2190': 'Granta 2190',
  };

  static const _regions = {
    '1': 'США', '4': 'США', '5': 'США', '2': 'Канада', '3': 'Мексика', 'J': 'Япония',
    'K': 'Корея', 'L': 'Китай', 'T': 'Европа', 'V': 'Европа', 'W': 'Германия',
    'X': 'Россия', 'Y': 'Скандинавия/Финляндия', 'Z': 'Италия', 'S': 'Великобритания',
  };

  static String? wmi(String vin) => _wmi3[vin.substring(0, 3)] ?? _wmi2[vin.substring(0, 2)];

  static int? yearFromVin(String vin) {
    final c = vin[9];
    if (RegExp(r'[1-9]').hasMatch(c)) return 2000 + int.parse(c);
    final idx = 'ABCDEFGHJKLMNPRSTVWXY'.indexOf(c);
    if (idx < 0) return null;
    final y = 2010 + idx;
    return y > 2027 ? y - 30 : y;
  }

  static String? _str(Map<String, dynamic>? m, String k) {
    final v = m?[k];
    if (v == null) return null;
    final s = v.toString().trim();
    return (s.isEmpty || s == 'null' || s == 'Not Applicable') ? null : s;
  }

  static Future<Map<String, dynamic>?> _online(String vin) async {
    try {
      final r = await http
          .get(Uri.parse('https://vpic.nhtsa.dot.gov/api/vehicles/decodevinvaluesextended/$vin?format=json'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      return (j['Results'] as List).first as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<VehicleInfo> build(String? vin, double? odometerKm, String? ecu, String? cal) async {
    final notes = <String>[];
    final v = (vin != null && vin.length == 17 && !vin.contains(RegExp('[IOQ]'))) ? vin : null;
    if (vin != null && v == null) notes.add('VIN прочитан не полностью, данные по нему могут быть неточными');

    final localMake = v == null ? null : wmi(v);
    final localYear = v == null ? null : yearFromVin(v);
    final localModel = (v != null && ['XTA', 'XTT', 'XTH', 'X9F'].contains(v.substring(0, 3)))
        ? _lada[v.substring(3, 7)]
        : null;
    final on = v == null ? null : await _online(v);
    if (v != null && on == null) notes.add('Нет интернета: модель и двигатель по базе VIN не определены');

    final make = _str(on, 'Make') ?? localMake;
    final model = _str(on, 'Model') ?? localModel;
    final year = int.tryParse(_str(on, 'ModelYear') ?? '') ?? localYear;
    String? engine;
    if (on != null) {
      final parts = [
        if (_str(on, 'DisplacementL') != null) '${_str(on, 'DisplacementL')} л',
        if (_str(on, 'EngineCylinders') != null) '${_str(on, 'EngineCylinders')} цил.',
        if (_str(on, 'FuelTypePrimary') != null) _str(on, 'FuelTypePrimary')!,
      ];
      engine = parts.isEmpty ? null : parts.join(', ');
    }
    final country = v == null ? null : _regions[v[0]];

    if (odometerKm == null) notes.add('ЭБУ не передаёт пробег по стандарту OBD-II. Для многих машин до ~2008 года это нормально');
    if (ecu == null) notes.add('ЭБУ не назвал себя: этот запрос поддерживают не все блоки');

    return VehicleInfo(
      vin: v ?? vin,
      make: make,
      model: model,
      year: year,
      engine: engine,
      country: country,
      odometerKm: odometerKm,
      ecuName: ecu,
      calibrationId: cal,
      notes: notes,
    );
  }
}
