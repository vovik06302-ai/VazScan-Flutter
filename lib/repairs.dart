/// Запись в журнале ремонтов: что сделали и какие коды этим устранили
class RepairEntry {
  final int id;
  final String title;
  final String note;
  final List<String> codes;
  const RepairEntry(this.id, this.title, this.note, this.codes);

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'note': note, 'codes': codes};

  factory RepairEntry.fromJson(Map<String, dynamic> j) => RepairEntry(
        j['id'] as int,
        j['title'] as String,
        (j['note'] ?? '') as String,
        ((j['codes'] ?? []) as List).map((e) => e.toString()).toList(),
      );
}
