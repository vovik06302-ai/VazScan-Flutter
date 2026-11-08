/// Пункт обслуживания с напоминанием по пробегу
class ServiceItem {
  final String name;
  final int intervalKm;
  final double? lastKm;
  const ServiceItem(this.name, this.intervalKm, {this.lastKm});

  ServiceItem withLast(double km) => ServiceItem(name, intervalKm, lastKm: km);

  /// Сколько км до следующего ТО; отрицательно - просрочено; null - ТО ещё не отмечалось
  double? remaining(double currentKm) {
    final l = lastKm;
    return l == null ? null : l + intervalKm - currentKm;
  }

  Map<String, dynamic> toJson() => {'name': name, 'interval': intervalKm, 'last': lastKm};

  factory ServiceItem.fromJson(Map<String, dynamic> j) => ServiceItem(
        j['name'] as String,
        j['interval'] as int,
        lastKm: (j['last'] as num?)?.toDouble(),
      );
}

const List<ServiceItem> defaultServices = [
  ServiceItem('Масло и масляный фильтр', 10000),
  ServiceItem('Свечи зажигания', 30000),
  ServiceItem('Воздушный фильтр', 15000),
  ServiceItem('Ремень ГРМ', 60000),
];
