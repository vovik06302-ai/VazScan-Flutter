import 'package:flutter_test/flutter_test.dart';
import 'package:vazscan/fuel.dart';

void main() {
  test('расход из ДМРВ: 3 г/с воздуха и 90 км/ч дают около 1.1 л/100 км', () {
    final f = FuelTracker();
    final t0 = DateTime(2026, 1, 1, 12);
    f.update(3.0, 90, null, t0);
    f.update(3.0, 90, null, t0.add(const Duration(seconds: 5)));
    expect(f.instant, closeTo(1.0958, 0.01));
    expect(f.avgPer100, closeTo(1.0958, 0.01));
  });

  test('на стоянке мгновенный расход не считается', () {
    final f = FuelTracker();
    final t0 = DateTime(2026, 1, 1, 12);
    f.update(3.0, 0, null, t0);
    f.update(3.0, 0, null, t0.add(const Duration(seconds: 1)));
    expect(f.instant, isNull);
    expect(f.lph, isNotNull);
  });

  test('заправка уточняет поправку по фактическим литрам', () {
    final f = FuelTracker(estSinceRefill: 10);
    expect(f.refuel(12), isTrue);
    expect(f.factor, closeTo(1.2, 0.001));
    expect(f.estSinceRefill, 0);
  });

  test('заправка при малом пробеге не меняет поправку', () {
    final f = FuelTracker(estSinceRefill: 1);
    expect(f.refuel(12), isFalse);
    expect(f.factor, 1.0);
  });
}
