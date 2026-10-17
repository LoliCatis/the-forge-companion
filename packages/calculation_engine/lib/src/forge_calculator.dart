import 'models.dart';

class ForgeCalculator {
  const ForgeCalculator();

  ForgeEstimate calculate(
    List<OreAmount> selection, {
    Map<int, Map<String, double>>? weaponOddsByOreCount,
    Map<int, Map<String, double>>? armorOddsByOreCount,
    double? qualityMultiplier,
    TraitFormulaPolicy? traitFormulaPolicy,
  }) {
    final valid = selection.where((entry) => entry.quantity > 0).toList();
    final total = valid.fold<int>(0, (sum, entry) => sum + entry.quantity);
    final shares = <String, double>{};
    for (final entry in valid) {
      shares[entry.ore.id] = entry.quantity / (total == 0 ? 1 : total);
    }

    final allMultipliersKnown = valid.every(
      (entry) => entry.ore.multiplier != null,
    );
    final weightedMultiplier = total == 0 || !allMultipliersKnown
        ? null
        : valid.fold<double>(
                0,
                (sum, entry) => sum + entry.ore.multiplier! * entry.quantity,
              ) /
              total;

    final traitEstimates = <TraitEstimate>[];
    for (final entry in valid) {
      final share = entry.quantity / total;
      for (final trait in entry.ore.traits) {
        final threshold = trait.activationThreshold;
        final fullThreshold = trait.fullThreshold;
        final activation = threshold == null
            ? TraitActivation.unknown
            : share >= threshold
            ? fullThreshold == null
                  ? TraitActivation.partial
                  : share > fullThreshold
                  ? TraitActivation.overallocated
                  : share >= fullThreshold
                  ? TraitActivation.full
                  : TraitActivation.partial
            : TraitActivation.inactive;
        double? strength;
        final formulaId = traitFormulaPolicy?.formula.id;
        if (activation != TraitActivation.inactive &&
            activation != TraitActivation.unknown &&
            threshold != null &&
            fullThreshold != null &&
            fullThreshold > threshold) {
          if (formulaId == 'traitScaling.linear.v1' ||
              (formulaId == null &&
                  trait.scalingRule ==
                      TraitScalingRule.linearBetweenThresholds)) {
            strength = ((share - threshold) / (fullThreshold - threshold))
                .clamp(0.0, 1.0);
          }
        }
        traitEstimates.add(
          TraitEstimate(
            trait: trait,
            oreName: entry.ore.name,
            share: share,
            activation: activation,
            strength: strength,
          ),
        );
      }
    }

    return ForgeEstimate(
      totalOres: total,
      composition: shares,
      weightedMultiplier: weightedMultiplier,
      traits: traitEstimates,
      weaponClassProbabilities: _lookupOdds(weaponOddsByOreCount, total),
      armorClassProbabilities: _lookupOdds(armorOddsByOreCount, total),
      qualityMultiplier: qualityMultiplier,
    );
  }

  Map<String, double>? _lookupOdds(
    Map<int, Map<String, double>>? table,
    int total,
  ) {
    if (table == null || total == 0) return null;
    return table[total] == null ? null : Map.unmodifiable(table[total]!);
  }
}
