enum VerificationStatus {
  inGameVerified,
  multiSourceVerified,
  community,
  guideBased,
  conflicting,
  outdated,
  unknown,
}

enum TraitScalingRule { unknown, linearBetweenThresholds }

enum TraitActivation { inactive, partial, full, overallocated, unknown }

class OreTrait {
  const OreTrait({
    required this.id,
    required this.name,
    required this.activationThreshold,
    this.fullThreshold,
    this.scalingRule = TraitScalingRule.unknown,
    this.effectType,
    this.trigger,
    this.procChance,
    this.damageMultiplier,
    this.flatDamage,
    this.radius,
    this.cooldownSeconds,
    this.durationSeconds,
    this.stackingRule,
    this.statModifier,
  });

  final String id;
  final String name;
  final double? activationThreshold;
  final double? fullThreshold;
  final TraitScalingRule scalingRule;
  final String? effectType;
  final String? trigger;
  final double? procChance;
  final double? damageMultiplier;
  final double? flatDamage;
  final double? radius;
  final double? cooldownSeconds;
  final double? durationSeconds;
  final String? stackingRule;
  final double? statModifier;
}

class OreDefinition {
  const OreDefinition({
    required this.id,
    required this.name,
    this.multiplier,
    this.rarity,
    this.price,
    this.verificationStatus = VerificationStatus.unknown,
    this.source,
    this.observedAt,
    this.gameVersion,
    this.confidence,
    this.traits = const [],
  });

  final String id;
  final String name;
  final double? multiplier;
  final String? rarity;
  final double? price;
  final VerificationStatus verificationStatus;
  final String? source;
  final DateTime? observedAt;
  final String? gameVersion;
  final double? confidence;
  final List<OreTrait> traits;
}

class OreAmount {
  const OreAmount({required this.ore, required this.quantity});

  final OreDefinition ore;
  final int quantity;
}

class TraitEstimate {
  const TraitEstimate({
    required this.trait,
    required this.oreName,
    required this.share,
    required this.activation,
    required this.strength,
  });

  final OreTrait trait;
  final String oreName;
  final double share;
  final TraitActivation activation;

  /// Null means the game's strength scaling curve has not been established.
  final double? strength;
}

class FormulaDefinition {
  const FormulaDefinition({
    required this.id,
    required this.name,
    required this.version,
    required this.source,
    required this.verificationStatus,
    required this.description,
    this.parameters = const {},
  });

  final String id;
  final String name;
  final String version;
  final String source;
  final VerificationStatus verificationStatus;
  final String description;
  final Map<String, double> parameters;
}

class TraitFormulaPolicy {
  const TraitFormulaPolicy({required this.formula});
  final FormulaDefinition formula;
}

class ProbabilityEntry {
  const ProbabilityEntry(this.resultId, this.probability);
  final String resultId;
  final double probability;
}

enum ProbabilityTableStatus {
  valid,
  roundingSuspected,
  underflow,
  overflow,
  invalid,
}

class ProbabilityTableValidation {
  const ProbabilityTableValidation({
    required this.status,
    required this.sourceSum,
    required this.entries,
    required this.missingResults,
    required this.issues,
  });

  final ProbabilityTableStatus status;
  final double sourceSum;
  final List<ProbabilityEntry> entries;
  final List<String> missingResults;
  final List<String> issues;

  Map<String, double> get normalizedPreview {
    if (sourceSum <= 0 || !sourceSum.isFinite) return const {};
    return Map.unmodifiable({
      for (final entry in entries)
        entry.resultId: entry.probability / sourceSum,
    });
  }
}

enum ProbabilityNormalizationPolicy { preserveSource, normalizedEstimate }

class ProbabilityEstimate {
  const ProbabilityEstimate({
    required this.sourceSum,
    required this.probabilities,
    required this.normalized,
    required this.status,
    required this.warnings,
  });
  final double sourceSum;
  final Map<String, double> probabilities;
  final bool normalized;
  final ProbabilityTableStatus status;
  final List<String> warnings;
}

class WeaponVariant {
  const WeaponVariant({
    required this.id,
    required this.name,
    this.baseDamage,
    this.attackIntervalSeconds,
    this.dataConfidence = 0,
  });
  final String id;
  final String name;
  final double? baseDamage;
  final double? attackIntervalSeconds;
  final double dataConfidence;
}

class DpsInput {
  const DpsInput({
    required this.weapon,
    this.oreMultiplier,
    this.criticalChance,
    this.criticalDamageExtra,
    this.expectedProcDps,
    this.procDataKnown = false,
    this.inputDataConfidence = 0,
    this.formulaConfidence = 1,
  });
  final WeaponVariant weapon;
  final double? oreMultiplier;
  final double? criticalChance;
  final double? criticalDamageExtra;
  final double? expectedProcDps;
  final bool procDataKnown;
  final double inputDataConfidence;
  final double formulaConfidence;
}

class DpsEstimate {
  const DpsEstimate({
    required this.baseDamage,
    required this.multiplierContribution,
    required this.attackIntervalSeconds,
    required this.attacksPerSecond,
    required this.rawDps,
    required this.criticalContribution,
    required this.expectedProcContribution,
    required this.knownContributionDps,
    required this.estimatedTotalDps,
    required this.unknownContributions,
    required this.inputDataConfidence,
    required this.formulaConfidence,
    required this.finalConfidence,
  });
  final double? baseDamage;
  final double? multiplierContribution;
  final double? attackIntervalSeconds;
  final double? attacksPerSecond;
  final double? rawDps;
  final double? criticalContribution;
  final double? expectedProcContribution;
  final double? knownContributionDps;
  final double? estimatedTotalDps;
  final List<String> unknownContributions;
  final double inputDataConfidence;
  final double formulaConfidence;
  final double finalConfidence;
}

enum OptimizerObjective { maxMultiplier, maxRawDps, maxExpectedDps, maxEffects }

class OptimizerOre {
  const OptimizerOre({
    required this.id,
    required this.name,
    this.maxPerRecipe = 51,
    this.multiplier,
    this.dataConfidence = 0,
    this.effectTags = const {},
    this.effectActivationThresholds = const {},
  });
  final String id;
  final String name;
  /// Search bound for this recipe, not a quantity owned by a player.
  final int maxPerRecipe;
  final double? multiplier;
  final double dataConfidence;
  final Set<String> effectTags;
  final Map<String, double> effectActivationThresholds;
}

class OptimizerConstraints {
  const OptimizerConstraints({
    this.requiredOres = const {},
    this.forbiddenOres = const {},
    this.minTotalOres = 3,
    this.maxTotalOres = 51,
    this.maxOreTypes = 4,
    this.targetEffects = const {},
    this.maxEvaluations = 50000,
  });
  final Set<String> requiredOres;
  final Set<String> forbiddenOres;
  final int minTotalOres;
  final int maxTotalOres;
  final int maxOreTypes;
  final Set<String> targetEffects;
  final int maxEvaluations;
}

class OptimizerRecipe {
  const OptimizerRecipe({
    required this.recipe,
    required this.score,
    required this.multiplier,
    required this.warnings,
    required this.confidence,
    required this.whyThisResult,
    this.dataCertainty = 0,
    this.formulaCertainty = 0,
    this.probabilityCertainty = 0,
    this.snapshotId,
    this.rankable = true,
  });
  final Map<String, int> recipe;
  final double score;
  final double? multiplier;
  final List<String> warnings;
  final double confidence;
  final String whyThisResult;
  final double dataCertainty;
  final double formulaCertainty;
  final double probabilityCertainty;
  final String? snapshotId;
  final bool rankable;
}

class ForgeEstimate {
  const ForgeEstimate({
    required this.totalOres,
    required this.composition,
    required this.weightedMultiplier,
    required this.traits,
    required this.weaponClassProbabilities,
    required this.armorClassProbabilities,
    required this.qualityMultiplier,
  });

  final int totalOres;
  final Map<String, double> composition;

  /// Null means at least one selected ore has no resolved multiplier.
  final double? weightedMultiplier;
  final List<TraitEstimate> traits;

  /// Null means no verified table/function was supplied.
  final Map<String, double>? weaponClassProbabilities;
  final Map<String, double>? armorClassProbabilities;

  /// Null means no verified craft quality has been supplied.
  final double? qualityMultiplier;
}
