import 'dart:convert';
import 'dart:typed_data';

class OreRecord {
  const OreRecord({
    required this.id,
    required this.name,
    this.rarity,
    this.multiplier,
    this.price,
    required this.source,
    required this.verificationStatus,
    this.sourceUrl,
    this.observedAt,
    this.gameVersion,
    this.confidence,
    this.traits = const [],
  });

  final String id;
  final String name;
  final String? rarity;
  final double? multiplier;
  final double? price;
  final String source;
  final String verificationStatus;
  final String? sourceUrl;
  final DateTime? observedAt;
  final String? gameVersion;
  final double? confidence;
  final List<OreTraitRecord> traits;

  factory OreRecord.fromMap(Map<String, Object?> row) => OreRecord(
    id: row['id']! as String,
    name: row['name']! as String,
    rarity: row['rarity'] as String?,
    multiplier: (row['multiplier'] as num?)?.toDouble(),
    price: (row['price'] as num?)?.toDouble(),
    source: row['source']! as String,
    sourceUrl: row['source_url'] as String?,
    observedAt: row['observed_at'] == null
        ? null
        : DateTime.tryParse(row['observed_at']! as String),
    gameVersion: row['game_version'] as String?,
    confidence: (row['confidence'] as num?)?.toDouble(),
    verificationStatus: row['verification_status']! as String,
    traits: const [],
  );
}

class DataSourceRecord {
  const DataSourceRecord({
    required this.id,
    required this.name,
    required this.sourceType,
    this.url,
    this.license,
  });
  final String id;
  final String name;
  final String sourceType;
  final String? url;
  final String? license;
}

class FieldObservation {
  const FieldObservation({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.fieldName,
    required this.value,
    required this.sourceId,
    required this.observedAt,
    required this.verificationStatus,
    this.gameVersion,
    this.confidence,
    this.evidenceReference,
    this.evidenceId,
    this.notes,
    this.reviewState = 'ENTERED',
    this.verificationSessionId,
  });
  final String id;
  final String entityType;
  final String entityId;
  final String fieldName;
  final Object? value;
  final String sourceId;
  final DateTime observedAt;
  final String? gameVersion;
  final double? confidence;
  final String verificationStatus;
  final String? evidenceReference;
  final String? evidenceId;
  final String? notes;
  final String reviewState;
  final String? verificationSessionId;

  factory FieldObservation.fromMap(Map<String, Object?> row) =>
      FieldObservation(
        id: row['id']! as String,
        entityType: row['entity_type']! as String,
        entityId: row['entity_id']! as String,
        fieldName: row['field_name']! as String,
        value: row['value_json'] == null
            ? null
            : jsonDecode(row['value_json']! as String),
        sourceId: row['source_id']! as String,
        observedAt: DateTime.parse(row['observed_at']! as String),
        gameVersion: row['game_version'] as String?,
        confidence: (row['confidence'] as num?)?.toDouble(),
        verificationStatus: row['verification_status']! as String,
        evidenceReference: row['evidence_ref'] as String?,
        evidenceId: row['evidence_id'] as String?,
        notes: row['notes'] as String?,
        reviewState: (row['review_state'] as String?) ?? 'ENTERED',
        verificationSessionId: row['verification_session_id'] as String?,
      );
}

enum EvidenceType {
  screenshot,
  manualTranscription,
  webSource,
  datasetReference,
  experiment,
}

class EvidenceRecord {
  const EvidenceRecord({
    required this.id,
    required this.type,
    required this.reference,
    this.capturedAt,
    this.checksum,
    this.notes,
    this.originalFilename,
    this.importedAt,
    this.width,
    this.height,
    this.sessionId,
    this.parentEvidenceId,
  });
  final String id;
  final EvidenceType type;
  final String reference;
  final DateTime? capturedAt;
  final String? checksum;
  final String? notes;
  final String? originalFilename;
  final DateTime? importedAt;
  final int? width;
  final int? height;
  final String? sessionId;
  final String? parentEvidenceId;
}

class VerificationSession {
  const VerificationSession({
    required this.id,
    required this.gameUpdateLabel,
    required this.sessionDate,
    required this.checkType,
    required this.createdAt,
    this.worldLocation,
    this.notes,
    this.officialGameVersion,
    this.observedLiveAt,
  });
  final String id;
  final String gameUpdateLabel;
  final DateTime sessionDate;
  final String checkType;
  final DateTime createdAt;
  final String? worldLocation;
  final String? notes;
  final String? officialGameVersion;
  final DateTime? observedLiveAt;
}

class RepositoryIntakeData {
  const RepositoryIntakeData({
    required this.manifest,
    required this.session,
    required this.sources,
    required this.entities,
    required this.observations,
    required this.evidence,
    required this.evidenceBytes,
    required this.repositoryPath,
  });
  final Map<String, Object?> manifest;
  final VerificationSession session;
  final List<Map<String, Object?>> sources;
  final List<Map<String, Object?>> entities;
  final List<Map<String, Object?>> observations;
  final List<Map<String, Object?>> evidence;
  final Map<String, Uint8List> evidenceBytes;
  final String repositoryPath;
}

class RepositoryIntakeResult {
  const RepositoryIntakeResult({
    required this.imported,
    required this.evidenceCount,
    required this.observationCount,
    required this.createdOreCount,
    required this.mergedOreCount,
    required this.sessionId,
  });
  final bool imported;
  final int evidenceCount;
  final int observationCount;
  final int createdOreCount;
  final int mergedOreCount;
  final String sessionId;
}

class VerificationTarget {
  const VerificationTarget({
    required this.id,
    required this.sessionId,
    required this.entityType,
    required this.entityId,
    required this.fieldName,
    required this.priority,
    required this.createdAt,
  });
  final String id;
  final String sessionId;
  final String entityType;
  final String entityId;
  final String fieldName;
  final int priority;
  final DateTime createdAt;
}

class VerifiedCandidateDiff {
  const VerifiedCandidateDiff({
    required this.candidateValues,
    required this.added,
    required this.changed,
    required this.conflicts,
    required this.removed,
  });
  final Map<String, Object?> candidateValues;
  final List<String> added;
  final List<String> changed;
  final List<String> conflicts;
  final List<String> removed;
}

class VerifiedCandidatePack {
  const VerifiedCandidatePack({
    required this.schemaVersion,
    required this.sourceDataVersion,
    required this.fieldValues,
    required this.diff,
    this.verifiedObservations = const [],
  });
  final int schemaVersion;
  final String? sourceDataVersion;
  final Map<String, Object?> fieldValues;
  final VerifiedCandidateDiff diff;
  final List<Map<String, Object?>> verifiedObservations;
}

class VerificationMetrics {
  const VerificationMetrics({
    required this.gameVerified,
    required this.userConfirmed,
    required this.communityOnly,
    required this.conflicts,
    required this.pendingReview,
    required this.domainVerified,
    required this.domainTotal,
  });
  final int gameVerified;
  final int userConfirmed;
  final int communityOnly;
  final int conflicts;
  final int pendingReview;
  final Map<String, int> domainVerified;
  final Map<String, int> domainTotal;
}

class WeaponClassRecord {
  const WeaponClassRecord({
    required this.id,
    required this.name,
    required this.forgeAvailable,
    required this.verificationStatus,
  });
  final String id;
  final String name;
  final bool forgeAvailable;
  final String verificationStatus;
}

class WeaponVariantRecord {
  const WeaponVariantRecord({
    required this.id,
    required this.name,
    required this.classId,
    required this.verificationStatus,
    this.baseDamage,
    this.attackIntervalSeconds,
    this.range,
    this.variantWeight,
    this.rarity,
    this.forgeAvailability,
    this.confidence,
  });
  final String id;
  final String name;
  final String classId;
  final String verificationStatus;
  final double? baseDamage;
  final double? attackIntervalSeconds;
  final double? range;
  final double? variantWeight;
  final String? rarity;
  final String? forgeAvailability;
  final double? confidence;
}

class ProbabilityTableRecord {
  const ProbabilityTableRecord({
    required this.id,
    required this.craftType,
    required this.totalOres,
    required this.entries,
    required this.status,
    required this.sourceSum,
    required this.verificationStatus,
    this.gameContext,
    this.notes,
    this.sourceId,
    this.normalizedForEstimate = false,
  });
  final String id;
  final String craftType;
  final int totalOres;
  final Map<String, double> entries;
  final String status;
  final double sourceSum;
  final String verificationStatus;
  final String? gameContext;
  final String? notes;
  final String? sourceId;
  final bool normalizedForEstimate;
}

class CalculationSnapshot {
  const CalculationSnapshot({
    required this.id,
    required this.catalogVersion,
    required this.rulesetVersion,
    required this.recipe,
    required this.resolvedObservationIds,
    required this.formulaIds,
    required this.assumptions,
    required this.resolvedInputs,
    required this.calculationResult,
    required this.dataCertainty,
    required this.formulaCertainty,
    required this.probabilityCertainty,
    required this.createdAt,
  });
  final String id;
  final String catalogVersion;
  final String rulesetVersion;
  final Map<String, int> recipe;
  final List<String> resolvedObservationIds;
  final List<String> formulaIds;
  final Map<String, Object?> assumptions;

  /// Values required to reproduce the result, frozen at calculation time.
  final Map<String, Object?> resolvedInputs;
  final Map<String, Object?> calculationResult;
  final double dataCertainty;
  final double formulaCertainty;
  final double probabilityCertainty;
  final DateTime createdAt;
}

class ExperimentRecord {
  const ExperimentRecord({
    required this.id,
    required this.name,
    required this.craftType,
    required this.createdAt,
    this.notes,
  });
  final String id;
  final String name;
  final String craftType;
  final DateTime createdAt;
  final String? notes;
}

class ExperimentRunRecord {
  const ExperimentRunRecord({
    required this.id,
    required this.experimentId,
    required this.sampleSize,
    required this.recipe,
    required this.createdAt,
    this.gameVersion,
    this.notes,
  });
  final String id;
  final String experimentId;
  final int sampleSize;
  final Map<String, int> recipe;
  final DateTime createdAt;
  final String? gameVersion;
  final String? notes;
}

class OutcomeCount {
  const OutcomeCount({required this.resultId, required this.count});
  final String resultId;
  final int count;
}

class ExperimentSummary {
  const ExperimentSummary({
    required this.sampleSize,
    required this.outcomes,
    required this.isEvidenceOnly,
    required this.message,
  });
  final int sampleSize;
  final Map<String, int> outcomes;
  final bool isEvidenceOnly;
  final String message;
}

class ResolvedField {
  const ResolvedField({
    required this.preferred,
    required this.alternatives,
    required this.conflicting,
    this.policy = DataPolicy.bestAvailable,
    this.incomplete = false,
    this.usedFallback = false,
  });
  final FieldObservation? preferred;
  final List<FieldObservation> alternatives;
  final bool conflicting;
  final DataPolicy policy;
  final bool incomplete;
  final bool usedFallback;
}

/// Governs whether calculations may fall back to community observations.
enum DataPolicy { bestAvailable, verifiedPreferred, verifiedOnly }

class DataHealthIssue {
  const DataHealthIssue({
    required this.entityType,
    required this.entityId,
    required this.fieldName,
    required this.status,
    required this.message,
  });
  final String entityType;
  final String entityId;
  final String fieldName;
  final String status;
  final String message;

  String get category => switch (entityType.toUpperCase()) {
    'ORE' => 'Ores',
    'WEAPON' || 'WEAPON_VARIANT' || 'WEAPON_CLASS' => 'Weapons',
    'TRAIT' => 'Traits',
    'PROBABILITY_TABLE' => 'Probabilities',
    'FORMULA' => 'Formulas',
    _ => 'Other',
  };

  String get severity => switch (status.toUpperCase()) {
    'INVALID' || 'OVERFLOW' => 'Critical',
    'SUPERSEDED' => 'Resolved',
    'CONFLICTING' => 'Conflict',
    'OUTDATED' || 'STALE_VERIFIED' => 'Stale',
    'COMMUNITY' ||
    'GUIDE_LISTED' ||
    'GUIDE_BASED' ||
    'NEEDS_VERIFICATION' => 'Needs Verification',
    _ => 'Unknown',
  };
}

class OreTraitRecord {
  const OreTraitRecord({
    required this.id,
    required this.oreId,
    required this.name,
    this.effectType,
    this.activationThreshold,
    this.fullThreshold,
    this.procChance,
    this.damageMultiplier,
    this.flatDamage,
    this.durationSeconds,
    this.cooldownSeconds,
    this.radius,
    this.stackingRule,
    this.trigger,
    this.statModifier,
    this.scalingRule = 'UNKNOWN',
  });
  final String id;
  final String oreId;
  final String name;
  final String? effectType;
  final double? activationThreshold;
  final double? fullThreshold;
  final double? procChance;
  final double? damageMultiplier;
  final double? flatDamage;
  final double? durationSeconds;
  final double? cooldownSeconds;
  final double? radius;
  final String? stackingRule;
  final String? trigger;
  final double? statModifier;
  final String scalingRule;
}

class SavedBuildRecord {
  const SavedBuildRecord({
    required this.id,
    required this.name,
    required this.recipe,
    required this.createdAt,
  });
  final String id;
  final String name;
  final Map<String, int> recipe;
  final DateTime createdAt;
}

class InventoryRecord {
  const InventoryRecord({
    required this.oreId,
    required this.oreName,
    required this.quantity,
    required this.protectedQuantity,
    required this.verificationStatus,
    this.multiplier,
    this.rarity,
    this.confidence,
    this.effectTags = const {},
    this.effectActivationThresholds = const {},
  });

  final String oreId;
  final String oreName;
  final int quantity;
  final int protectedQuantity;
  final String verificationStatus;
  final double? multiplier;
  final String? rarity;
  final double? confidence;
  final Set<String> effectTags;
  final Map<String, double> effectActivationThresholds;

  factory InventoryRecord.fromMap(Map<String, Object?> row) => InventoryRecord(
    oreId: row['ore_id']! as String,
    oreName: row['ore_name']! as String,
    quantity: row['quantity']! as int,
    protectedQuantity: row['protected_quantity']! as int,
    multiplier: (row['multiplier'] as num?)?.toDouble(),
    rarity: row['rarity'] as String?,
    confidence: (row['confidence'] as num?)?.toDouble(),
    effectTags: ((row['effect_tags'] as String?) ?? '')
        .split('|')
        .where((tag) => tag.isNotEmpty)
        .toSet(),
    effectActivationThresholds: {
      for (final part in ((row['effect_thresholds'] as String?) ?? '').split(
        '|',
      ))
        if (part.contains(':') && double.tryParse(part.split(':').last) != null)
          part.substring(0, part.lastIndexOf(':')): double.parse(
            part.substring(part.lastIndexOf(':') + 1),
          ),
    },
    verificationStatus: row['verification_status']! as String,
  );
}
