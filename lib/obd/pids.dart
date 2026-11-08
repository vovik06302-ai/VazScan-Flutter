class PidDef {
  final int pid;
  final String name;
  final String unit;
  final int bytes;
  final double min;
  final double max;
  final double Function(List<int> d) calc;
  const PidDef(this.pid, this.name, this.unit, this.bytes, this.min, this.max, this.calc);
}

final List<PidDef> allPids = [
  PidDef(0x04, 'Нагрузка двигателя', '%', 1, 0, 100, (d) => d[0] * 100 / 255),
  PidDef(0x05, 'Температура охлаждающей жидкости', '°C', 1, -40, 130, (d) => d[0] - 40.0),
  PidDef(0x06, 'Коррекция топлива кратковр. (STFT)', '%', 1, -25, 25, (d) => (d[0] - 128) * 100 / 128),
  PidDef(0x07, 'Коррекция топлива долговр. (LTFT)', '%', 1, -25, 25, (d) => (d[0] - 128) * 100 / 128),
  PidDef(0x0A, 'Давление топлива', 'кПа', 1, 0, 765, (d) => d[0] * 3.0),
  PidDef(0x0B, 'Давление во впуске (MAP)', 'кПа', 1, 0, 255, (d) => d[0].toDouble()),
  PidDef(0x0C, 'Обороты двигателя', 'об/мин', 2, 0, 7000, (d) => (d[0] * 256 + d[1]) / 4),
  PidDef(0x0D, 'Скорость', 'км/ч', 1, 0, 255, (d) => d[0].toDouble()),
  PidDef(0x0E, 'Угол опережения зажигания', '°', 1, -64, 63, (d) => d[0] / 2 - 64),
  PidDef(0x0F, 'Температура воздуха на впуске', '°C', 1, -40, 215, (d) => d[0] - 40.0),
  PidDef(0x10, 'Расход воздуха (ДМРВ)', 'г/с', 2, 0, 655, (d) => (d[0] * 256 + d[1]) / 100),
  PidDef(0x11, 'Положение дросселя', '%', 1, 0, 100, (d) => d[0] * 100 / 255),
  PidDef(0x14, 'Лямбда-зонд 1 (до катализатора)', 'В', 2, 0, 1.3, (d) => d[0] / 200),
  PidDef(0x15, 'Лямбда-зонд 2 (после катализатора)', 'В', 2, 0, 1.3, (d) => d[0] / 200),
  PidDef(0x1F, 'Время работы двигателя', 'с', 2, 0, 65535, (d) => (d[0] * 256 + d[1]).toDouble()),
  PidDef(0x21, 'Пробег с горящей лампой', 'км', 2, 0, 65535, (d) => (d[0] * 256 + d[1]).toDouble()),
  PidDef(0x2E, 'Продувка адсорбера (EVAP)', '%', 1, 0, 100, (d) => d[0] * 100 / 255),
  PidDef(0x2F, 'Уровень топлива', '%', 1, 0, 100, (d) => d[0] * 100 / 255),
  PidDef(0x31, 'Пробег с момента сброса ошибок', 'км', 2, 0, 65535, (d) => (d[0] * 256 + d[1]).toDouble()),
  PidDef(0x33, 'Атмосферное давление', 'кПа', 1, 0, 255, (d) => d[0].toDouble()),
  PidDef(0x42, 'Напряжение бортсети (ЭБУ)', 'В', 2, 8, 16, (d) => (d[0] * 256 + d[1]) / 1000),
  PidDef(0x45, 'Положение дросселя относительное', '%', 1, 0, 100, (d) => d[0] * 100 / 255),
  PidDef(0x46, 'Температура наружного воздуха', '°C', 1, -40, 215, (d) => d[0] - 40.0),
  PidDef(0x49, 'Педаль газа', '%', 1, 0, 100, (d) => d[0] * 100 / 255),
];

final Map<int, PidDef> pidById = {for (final p in allPids) p.pid: p};

String pidName(int pid) => pidById[pid]?.name ?? 'PID ${pid.toRadixString(16).toUpperCase()}';

/// Параметры, которые опрашиваются при полной диагностике
const List<int> scanList = [0x05, 0x0C, 0x0D, 0x04, 0x11, 0x10, 0x0B, 0x0E, 0x0F, 0x06, 0x07, 0x42];

String fmtPid(PidDef d, double v) {
  if (d.max >= 1000) return v.toStringAsFixed(0);
  if (d.unit == 'В') return v.toStringAsFixed(2);
  return v.toStringAsFixed(1);
}
