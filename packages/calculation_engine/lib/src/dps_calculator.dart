import 'dart:math' as math;

import 'models.dart';

class DpsCalculator {
  const DpsCalculator();

  DpsEstimate calculate(DpsInput input) {
    final weapon = input.weapon;
    final damage = weapon.baseDamage;
    final multiplier = input.oreMultiplier;
    final interval = weapon.attackIntervalSeconds;
    final scaledDamage = damage == null || multiplier == null
        ? null
        : damage * multiplier;
    final attacksPerSecond = interval == null || interval <= 0
        ? null
        : 1 / interval;
    final rawDps = scaledDamage == null || attacksPerSecond == null
        ? null
        : scaledDamage * attacksPerSecond;

    double? critContribution;
    final unknown = <String>[];
    if (rawDps == null) {
      if (damage == null) unknown.add('weapon base damage');
      if (multiplier == null) unknown.add('ore multiplier');
      if (interval == null || interval <= 0) unknown.add('attack interval');
    } else if (input.criticalChance == null ||
        input.criticalDamageExtra == null) {
      unknown.add('critical contribution');
    } else {
      critContribution =
          rawDps * input.criticalChance! * input.criticalDamageExtra!;
    }
    final proc = input.procDataKnown ? input.expectedProcDps : null;
    if (!input.procDataKnown || input.expectedProcDps == null) {
      unknown.add('trait proc contribution');
    }
    final knownTotal = rawDps == null
        ? null
        : rawDps + (critContribution ?? 0) + (proc ?? 0);
    final canEstimateTotal = rawDps != null && unknown.isEmpty;
    final formulaConfidence = input.formulaConfidence.clamp(0.0, 1.0);
    final dataConfidence = math.min(
      input.inputDataConfidence.clamp(0.0, 1.0),
      weapon.dataConfidence.clamp(0.0, 1.0),
    );
    return DpsEstimate(
      baseDamage: damage,
      multiplierContribution: multiplier,
      attackIntervalSeconds: interval,
      attacksPerSecond: attacksPerSecond,
      rawDps: rawDps,
      criticalContribution: critContribution,
      expectedProcContribution: proc,
      knownContributionDps: knownTotal,
      estimatedTotalDps: canEstimateTotal ? knownTotal : null,
      unknownContributions: List.unmodifiable(unknown),
      inputDataConfidence: dataConfidence,
      formulaConfidence: formulaConfidence,
      finalConfidence: dataConfidence * formulaConfidence,
    );
  }
}
