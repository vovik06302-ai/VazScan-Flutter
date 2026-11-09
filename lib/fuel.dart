/// Расход топлива по данным ЭБУ: прямой расход (PID 5E) или расход воздуха (ДМРВ).
class FuelTracker {
  static const double afr = 14.7;       // соотношение воздух/топливо для бензина
  static const double density = 745;    // г/л, плотность бензина
  static const double maxStepSec = 10;  // больший разрыв между замерами не учитываем

  /// Поправка по заправкам: фактически залитое / расчётное
  double factor;
  double estSinceRefill;   // расчётные литры с последней заправки (без поправки)
  double kmSinceRefill;
  double tripLiters = 0;   // литры за поездку (с поправкой)
  double tripKm = 0;
  double? instant;         // л/100 км сейчас; null, если стоим или нет данных
  double? lph;             // л/ч сейчас
  DateTime? _last;

  FuelTracker({this.factor = 1.0, this.estSinceRefill = 0, this.kmSinceRefill = 0});

  void update(double? maf, double? speed, double? rateLh, DateTime now) {
    final last = _last;
    _last = now;
    if (last == null) return;
    final dtSec = now.difference(last).inMilliseconds / 1000.0;
    if (dtSec <= 0 || dtSec > maxStepSec) return;
    final h = rateLh ?? (maf == null ? null : maf * 3600 / (afr * density));
    lph = h;
    instant = (h != null && speed != null && speed >= 5) ? h / speed * 100 : null;
    final dtH = dtSec / 3600;
    if (h != null) {
      final est = h * dtH;
      estSinceRefill += est;
      tripLiters += est * factor;
    }
    if (speed != null) {
      final km = speed * dtH;
      kmSinceRefill += km;
      tripKm += km;
    }
  }

  /// Средний расход за поездку; null, пока мало километров
  double? get avgPer100 => tripKm >= 0.1 ? tripLiters / tripKm * 100 : null;

  void resetTrip() {
    tripLiters = 0;
    tripKm = 0;
    instant = null;
    lph = null;
    _last = null;
  }

  /// Заправка: поправка = залитое / расчётное за период. false, если данных мало.
  bool refuel(double addedLiters) {
    if (addedLiters <= 0 || estSinceRefill < 3) return false;
    factor = (addedLiters / estSinceRefill).clamp(0.6, 1.6).toDouble();
    estSinceRefill = 0;
    kmSinceRefill = 0;
    return true;
  }
}
