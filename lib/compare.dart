import 'app_state.dart';

/// Результат сравнения двух диагностик: было (before) и стало (after)
class CompareResult {
  final int before;
  final int after;
  final List<String> removedCodes;
  final List<String> addedCodes;
  final List<String> fixedProblems;
  final List<String> newProblems;
  const CompareResult(this.before, this.after, this.removedCodes, this.addedCodes, this.fixedProblems, this.newProblems);
}

CompareResult compareReports(SavedReport before, SavedReport after) {
  final bc = before.codes.toSet();
  final ac = after.codes.toSet();
  final bf = before.findings.toSet();
  final af = after.findings.toSet();
  return CompareResult(
    before.score,
    after.score,
    bc.difference(ac).toList(),
    ac.difference(bc).toList(),
    bf.difference(af).toList(),
    af.difference(bf).toList(),
  );
}
