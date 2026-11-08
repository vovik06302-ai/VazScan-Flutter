class AdapterInfo {
  final String version;
  final String protocol;
  final double? voltage;
  final bool ecuResponds;
  final bool isCan;
  final List<String> notes;
  const AdapterInfo({
    this.version = '',
    this.protocol = '',
    this.voltage,
    this.ecuResponds = false,
    this.isCan = false,
    this.notes = const [],
  });
}

class ReadyItem {
  final String name;
  final bool complete;
  const ReadyItem(this.name, this.complete);
}

class Readiness {
  final bool milOn;
  final int dtcCount;
  final List<ReadyItem> items;
  const Readiness(this.milOn, this.dtcCount, this.items);
}

class FreezeFrame {
  final String? dtc;
  final Map<int, double> values;
  const FreezeFrame(this.dtc, this.values);
}

/** severity: 1 - информация, 2 - внимание, 3 - серьёзно */
class Finding {
  final int severity;
  final String title;
  final String details;
  final List<String> actions;
  const Finding(this.severity, this.title, this.details, this.actions);
}

class Analysis {
  final int score;
  final String verdict;
  final List<Finding> findings;
  const Analysis(this.score, this.verdict, this.findings);
}

/** level: 1 - внимание, 2 - тревога */
class Alarm {
  final int level;
  final String name;
  final String text;
  const Alarm(this.level, this.name, this.text);
}

class ScanResult {
  final DateTime time;
  final String vehicle;
  final List<String> stored;
  final List<String> pending;
  final List<String> permanent;
  final Readiness? readiness;
  final FreezeFrame? freeze;
  final Analysis analysis;
  final String text;
  const ScanResult({
    required this.time,
    required this.vehicle,
    required this.stored,
    required this.pending,
    required this.permanent,
    required this.readiness,
    required this.freeze,
    required this.analysis,
    required this.text,
  });
}
