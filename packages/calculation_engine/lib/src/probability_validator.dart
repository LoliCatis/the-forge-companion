import 'models.dart';

class ProbabilityTableValidator {
  const ProbabilityTableValidator({this.roundingTolerance = 0.005});

  final double roundingTolerance;

  ProbabilityTableValidation validate(
    List<ProbabilityEntry> entries, {
    Set<String> expectedResults = const {},
    Set<String> impossibleResults = const {},
  }) {
    final issues = <String>[];
    final seen = <String>{};
    var invalid = false;
    var sum = 0.0;
    for (final entry in entries) {
      if (!seen.add(entry.resultId)) {
        issues.add('Duplicate result: ${entry.resultId}');
        invalid = true;
      }
      if (!entry.probability.isFinite || entry.probability < 0) {
        issues.add('Negative or non-finite probability: ${entry.resultId}');
        invalid = true;
      } else if (entry.probability > 1) {
        issues.add('Probability exceeds 1: ${entry.resultId}');
        invalid = true;
      }
      if (impossibleResults.contains(entry.resultId) && entry.probability > 0) {
        issues.add(
          'Impossible result has positive probability: ${entry.resultId}',
        );
        invalid = true;
      }
      if (entry.probability.isFinite) sum += entry.probability;
    }
    final missing = expectedResults.difference(seen).toList()..sort();
    if (missing.isNotEmpty) {
      issues.add('Missing results: ${missing.join(', ')}');
      invalid = true;
    }
    final status = invalid
        ? ProbabilityTableStatus.invalid
        : sum > 1 + roundingTolerance
        ? ProbabilityTableStatus.overflow
        : sum < 1 - roundingTolerance
        ? ProbabilityTableStatus.underflow
        : (sum - 1).abs() > 1e-9
        ? ProbabilityTableStatus.roundingSuspected
        : ProbabilityTableStatus.valid;
    if (status == ProbabilityTableStatus.underflow) {
      issues.add(
        'Source probability sum is below 1: ${sum.toStringAsFixed(6)}',
      );
    } else if (status == ProbabilityTableStatus.overflow) {
      issues.add(
        'Source probability sum is above 1: ${sum.toStringAsFixed(6)}',
      );
    } else if (status == ProbabilityTableStatus.roundingSuspected) {
      issues.add('Probability sum differs slightly from 1; rounding suspected');
    }
    return ProbabilityTableValidation(
      status: status,
      sourceSum: sum,
      entries: List.unmodifiable(entries),
      missingResults: List.unmodifiable(missing),
      issues: List.unmodifiable(issues),
    );
  }

  ProbabilityEstimate estimate(
    ProbabilityTableValidation validation, {
    ProbabilityNormalizationPolicy policy =
        ProbabilityNormalizationPolicy.preserveSource,
  }) {
    final shouldNormalize =
        policy == ProbabilityNormalizationPolicy.normalizedEstimate &&
        validation.sourceSum > 0 &&
        validation.status != ProbabilityTableStatus.invalid;
    final values = <String, double>{};
    for (final entry in validation.entries) {
      values[entry.resultId] = shouldNormalize
          ? entry.probability / validation.sourceSum
          : entry.probability;
    }
    return ProbabilityEstimate(
      sourceSum: validation.sourceSum,
      probabilities: Map.unmodifiable(values),
      normalized: shouldNormalize,
      status: validation.status,
      warnings: List.unmodifiable([
        ...validation.issues,
        if (shouldNormalize)
          'Normalized for estimate; source probability sum: ${validation.sourceSum.toStringAsFixed(6)}',
      ]),
    );
  }
}
