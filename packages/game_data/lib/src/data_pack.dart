import 'dart:convert';

import 'package:calculation_engine/calculation_engine.dart';
import 'package:crypto/crypto.dart';

class DataPackManifest {
  const DataPackManifest({
    required this.packId,
    required this.schemaVersion,
    required this.dataVersion,
    required this.createdAt,
    required this.rulesetVersion,
    required this.sourceIds,
    required this.contentHashes,
    this.gameVersion,
    this.gameUpdateLabel,
    this.notes,
  });

  final String packId;
  final int schemaVersion;
  final String dataVersion;
  final DateTime createdAt;
  final String rulesetVersion;
  final List<String> sourceIds;
  final Map<String, String> contentHashes;
  final String? gameVersion;
  final String? gameUpdateLabel;
  final String? notes;

  factory DataPackManifest.fromMap(Map<String, Object?> map) {
    return DataPackManifest(
      packId: _requiredString(map, 'packId'),
      schemaVersion: _requiredInt(map, 'schemaVersion'),
      dataVersion: _requiredString(map, 'dataVersion'),
      createdAt: DateTime.parse(_requiredString(map, 'createdAt')),
      gameVersion: map['gameVersion'] as String?,
      gameUpdateLabel: map['gameUpdateLabel'] as String?,
      rulesetVersion: _requiredString(map, 'rulesetVersion'),
      sourceIds: _stringList(map['sources'], 'sources'),
      contentHashes: _stringMap(map['contentHashes'], 'contentHashes'),
      notes: map['notes'] as String?,
    );
  }
}

class DataPackBundle {
  const DataPackBundle(this.files);

  /// File names are pack-relative paths, for example `ores.json`.
  final Map<String, String> files;

  ValidatedDataPack validate() {
    final manifestContent = files['manifest.json'];
    if (manifestContent == null) {
      throw const FormatException('Data pack is missing manifest.json');
    }
    final manifest = DataPackManifest.fromMap(_decodeMap(manifestContent));
    if (manifest.schemaVersion != 1) {
      throw UnsupportedError(
        'Unsupported data pack schema ${manifest.schemaVersion}',
      );
    }
    const requiredFiles = {
      'sources.json',
      'ores.json',
      'weapons.json',
      'traits.json',
      'probabilities.json',
      'evidence.json',
      'observations.json',
    };
    if (!manifest.contentHashes.keys.toSet().containsAll(requiredFiles)) {
      throw const FormatException('Manifest must hash every pack content file');
    }
    for (final fileName in requiredFiles) {
      final content = files[fileName];
      if (content == null) throw FormatException('Missing $fileName');
      final actual = sha256.convert(utf8.encode(content)).toString();
      final expected = manifest.contentHashes[fileName]!.toLowerCase();
      if (actual != expected) {
        throw FormatException('Content hash mismatch for $fileName');
      }
    }

    final sources = _decodeList(
      files['sources.json']!,
    ).map(DataPackSource.fromMap).toList();
    final ores = _decodeList(
      files['ores.json']!,
    ).map(DataPackOre.fromMap).toList();
    final weaponMap = _decodeMap(files['weapons.json']!);
    final weaponClasses = _decodeList(
      jsonEncode(weaponMap['classes']),
    ).map(DataPackWeaponClass.fromMap).toList();
    final weapons = _decodeList(
      jsonEncode(weaponMap['variants']),
    ).map(DataPackWeaponVariant.fromMap).toList();
    final traits = _decodeList(
      files['traits.json']!,
    ).map(DataPackTrait.fromMap).toList();
    final evidence = _decodeList(
      files['evidence.json']!,
    ).map(DataPackEvidence.fromMap).toList();
    final observations = _decodeList(
      files['observations.json']!,
    ).map(DataPackObservation.fromMap).toList();
    final probabilities = _decodeList(
      files['probabilities.json']!,
    ).map(DataPackProbabilityTable.fromMap).toList();
    final sourceIds = sources.map((source) => source.id).toSet();
    final manifestSourceIds = manifest.sourceIds.toSet();
    if (!sourceIds.containsAll(manifestSourceIds)) {
      throw const FormatException('Manifest refers to a missing source');
    }
    _ensureUnique(sources.map((e) => e.id), 'source');
    _ensureUnique(ores.map((e) => e.id), 'ore');
    _ensureUnique(weaponClasses.map((e) => e.id), 'weapon class');
    _ensureUnique(weapons.map((e) => e.id), 'weapon variant');
    _ensureUnique(traits.map((e) => e.id), 'trait');
    _ensureUnique(evidence.map((e) => e.id), 'evidence');
    _ensureUnique(observations.map((e) => e.id), 'observation');
    _ensureUnique(probabilities.map((e) => e.id), 'probability table');
    final classIds = weaponClasses.map((e) => e.id).toSet();
    if (weapons.any((weapon) => !classIds.contains(weapon.classId))) {
      throw const FormatException('Weapon variant references an unknown class');
    }
    if (ores.any(
      (ore) => ore.sourceId != null && !sourceIds.contains(ore.sourceId),
    )) {
      throw const FormatException('Ore references an unknown source');
    }
    if (weapons.any(
      (weapon) =>
          weapon.sourceId != null && !sourceIds.contains(weapon.sourceId),
    )) {
      throw const FormatException('Weapon references an unknown source');
    }
    final evidenceIds = evidence.map((e) => e.id).toSet();
    if (observations.any((o) => !sourceIds.contains(o.sourceId))) {
      throw const FormatException('Observation references an unknown source');
    }
    if (observations.any(
      (o) => o.evidenceId != null && !evidenceIds.contains(o.evidenceId),
    )) {
      throw const FormatException('Observation references unknown evidence');
    }
    final sourceById = {for (final source in sources) source.id: source};
    final evidenceById = {for (final item in evidence) item.id: item};
    for (final observation in observations.where(
      (item) => item.verificationStatus == 'IN_GAME_VERIFIED',
    )) {
      final source = sourceById[observation.sourceId];
      final item = evidenceById[observation.evidenceId];
      if (source?.type != 'IN_GAME_MANUAL' ||
          item == null ||
          !{'SCREENSHOT', 'MANUAL_TRANSCRIPTION'}.contains(item.type) ||
          observation.gameVersion == null ||
          observation.reviewState != 'USER_CONFIRMED') {
        throw const FormatException(
          'IN_GAME_VERIFIED requires in-game source, reviewed evidence and game context',
        );
      }
    }
    final validator = const ProbabilityTableValidator();
    final validation = <String, ProbabilityTableValidation>{};
    for (final table in probabilities) {
      if (table.sourceId != null && !sourceIds.contains(table.sourceId)) {
        throw FormatException(
          'Probability table ${table.id} has unknown source',
        );
      }
      final result = validator.validate(
        table.entries,
        expectedResults: table.expectedResults.toSet(),
        impossibleResults: table.impossibleResults.toSet(),
      );
      validation[table.id] = result;
    }
    return ValidatedDataPack(
      manifest: manifest,
      sources: List.unmodifiable(sources),
      ores: List.unmodifiable(ores),
      weaponClasses: List.unmodifiable(weaponClasses),
      weapons: List.unmodifiable(weapons),
      traits: List.unmodifiable(traits),
      probabilities: List.unmodifiable(probabilities),
      probabilityValidations: Map.unmodifiable(validation),
      evidence: List.unmodifiable(evidence),
      observations: List.unmodifiable(observations),
      rawFiles: Map.unmodifiable(files),
    );
  }
}

class ValidatedDataPack {
  const ValidatedDataPack({
    required this.manifest,
    required this.sources,
    required this.ores,
    required this.weaponClasses,
    required this.weapons,
    required this.traits,
    required this.probabilities,
    required this.probabilityValidations,
    required this.evidence,
    required this.observations,
    required this.rawFiles,
  });
  final DataPackManifest manifest;
  final List<DataPackSource> sources;
  final List<DataPackOre> ores;
  final List<DataPackWeaponClass> weaponClasses;
  final List<DataPackWeaponVariant> weapons;
  final List<DataPackTrait> traits;
  final List<DataPackProbabilityTable> probabilities;
  final Map<String, ProbabilityTableValidation> probabilityValidations;
  final List<DataPackEvidence> evidence;
  final List<DataPackObservation> observations;
  final Map<String, String> rawFiles;
}

class DataPackSource {
  const DataPackSource({
    required this.id,
    required this.name,
    required this.type,
    required this.verificationStatus,
    this.url,
    this.accessedAt,
    this.notes,
  });
  final String id, name, type, verificationStatus;
  final String? url, notes;
  final DateTime? accessedAt;
  factory DataPackSource.fromMap(Map<String, Object?> m) => DataPackSource(
    id: _requiredString(m, 'id'),
    name: _requiredString(m, 'name'),
    type: _requiredString(m, 'type'),
    verificationStatus: (m['verificationStatus'] as String?) ?? 'COMMUNITY',
    url: m['url'] as String?,
    accessedAt: m['accessedAt'] == null
        ? null
        : DateTime.parse(m['accessedAt']! as String),
    notes: m['notes'] as String?,
  );
}

class DataPackOre {
  const DataPackOre({
    required this.id,
    required this.name,
    this.rarity,
    this.multiplier,
    this.sourceId,
    this.verificationStatus = 'UNKNOWN',
    this.confidence = 0,
  });
  final String id, name, verificationStatus;
  final String? rarity, sourceId;
  final double? multiplier;
  final double confidence;
  factory DataPackOre.fromMap(Map<String, Object?> m) => DataPackOre(
    id: _requiredString(m, 'id'),
    name: _requiredString(m, 'name'),
    rarity: m['rarity'] as String?,
    multiplier: _number(m['multiplier']),
    sourceId: m['sourceId'] as String?,
    verificationStatus: (m['verificationStatus'] as String?) ?? 'UNKNOWN',
    confidence: _number(m['confidence']) ?? 0,
  );
}

class DataPackWeaponClass {
  const DataPackWeaponClass({
    required this.id,
    required this.name,
    this.forgeAvailable = true,
    this.verificationStatus = 'UNKNOWN',
  });
  final String id, name, verificationStatus;
  final bool forgeAvailable;
  factory DataPackWeaponClass.fromMap(Map<String, Object?> m) =>
      DataPackWeaponClass(
        id: _requiredString(m, 'id'),
        name: _requiredString(m, 'name'),
        forgeAvailable: (m['forgeAvailable'] as bool?) ?? true,
        verificationStatus: (m['verificationStatus'] as String?) ?? 'UNKNOWN',
      );
}

class DataPackWeaponVariant {
  const DataPackWeaponVariant({
    required this.id,
    required this.name,
    required this.classId,
    this.baseDamage,
    this.attackIntervalSeconds,
    this.range,
    this.variantWeight,
    this.rarity,
    this.forgeAvailability,
    this.sourceId,
    this.verificationStatus = 'UNKNOWN',
    this.confidence = 0,
  });
  final String id, name, classId, verificationStatus;
  final double? baseDamage, attackIntervalSeconds, range, variantWeight;
  final double confidence;
  final String? rarity, forgeAvailability, sourceId;
  factory DataPackWeaponVariant.fromMap(Map<String, Object?> m) =>
      DataPackWeaponVariant(
        id: _requiredString(m, 'id'),
        name: _requiredString(m, 'name'),
        classId: _requiredString(m, 'classId'),
        baseDamage: _number(m['baseDamage']),
        attackIntervalSeconds: _number(m['attackIntervalSeconds']),
        range: _number(m['range']),
        variantWeight: _number(m['variantWeight']),
        rarity: m['rarity'] as String?,
        forgeAvailability: m['forgeAvailability'] as String?,
        sourceId: m['sourceId'] as String?,
        verificationStatus: (m['verificationStatus'] as String?) ?? 'UNKNOWN',
        confidence: _number(m['confidence']) ?? 0,
      );
}

class DataPackTrait {
  const DataPackTrait({
    required this.id,
    required this.name,
    required this.oreId,
    this.effectType,
    this.activationThreshold,
    this.fullThreshold,
    this.procChance,
    this.damageMultiplier,
    this.flatDamage,
    this.durationSeconds,
    this.cooldownSeconds,
    this.radius,
    this.trigger,
    this.statModifier,
    this.verificationStatus = 'UNKNOWN',
    this.sourceId,
  });
  final String id, name, oreId, verificationStatus;
  final String? effectType, trigger, sourceId;
  final double? activationThreshold,
      fullThreshold,
      procChance,
      damageMultiplier,
      flatDamage,
      durationSeconds,
      cooldownSeconds,
      radius,
      statModifier;
  factory DataPackTrait.fromMap(Map<String, Object?> m) => DataPackTrait(
    id: _requiredString(m, 'id'),
    name: _requiredString(m, 'name'),
    oreId: _requiredString(m, 'oreId'),
    effectType: m['effectType'] as String?,
    activationThreshold: _number(m['activationThreshold']),
    fullThreshold: _number(m['fullThreshold']),
    procChance: _number(m['procChance']),
    damageMultiplier: _number(m['damageMultiplier']),
    flatDamage: _number(m['flatDamage']),
    durationSeconds: _number(m['durationSeconds']),
    cooldownSeconds: _number(m['cooldownSeconds']),
    radius: _number(m['radius']),
    trigger: m['trigger'] as String?,
    statModifier: _number(m['statModifier']),
    verificationStatus: (m['verificationStatus'] as String?) ?? 'UNKNOWN',
    sourceId: m['sourceId'] as String?,
  );
}

class DataPackProbabilityTable {
  const DataPackProbabilityTable({
    required this.id,
    required this.craftType,
    required this.totalOres,
    required this.entries,
    this.expectedResults = const [],
    this.impossibleResults = const [],
    this.sourceId,
    this.verificationStatus = 'UNKNOWN',
    this.gameContext,
    this.notes,
    this.normalizationPolicy = ProbabilityNormalizationPolicy.preserveSource,
  });
  final String id, craftType, verificationStatus;
  final int totalOres;
  final List<ProbabilityEntry> entries;
  final List<String> expectedResults, impossibleResults;
  final String? sourceId, gameContext, notes;
  final ProbabilityNormalizationPolicy normalizationPolicy;
  factory DataPackProbabilityTable.fromMap(Map<String, Object?> m) {
    final entries = (m['entries'] as List<Object?>? ?? [])
        .map((row) {
          final entry = Map<String, Object?>.from(row! as Map);
          return ProbabilityEntry(
            _requiredString(entry, 'resultId'),
            _requiredNumber(entry['probability']),
          );
        })
        .toList(growable: false);
    final policy = m['normalizationPolicy'] == 'normalizedEstimate'
        ? ProbabilityNormalizationPolicy.normalizedEstimate
        : ProbabilityNormalizationPolicy.preserveSource;
    return DataPackProbabilityTable(
      id: _requiredString(m, 'id'),
      craftType: _requiredString(m, 'craftType'),
      totalOres: _requiredInt(m, 'totalOres'),
      entries: entries,
      expectedResults: _stringList(
        m['expectedResults'] ?? const [],
        'expectedResults',
      ),
      impossibleResults: _stringList(
        m['impossibleResults'] ?? const [],
        'impossibleResults',
      ),
      sourceId: m['sourceId'] as String?,
      verificationStatus: (m['verificationStatus'] as String?) ?? 'UNKNOWN',
      gameContext: m['gameContext'] as String?,
      notes: m['notes'] as String?,
      normalizationPolicy: policy,
    );
  }
}

class DataPackEvidence {
  const DataPackEvidence({
    required this.id,
    required this.type,
    required this.reference,
    this.capturedAt,
    this.checksum,
    this.notes,
  });
  final String id, type, reference;
  final DateTime? capturedAt;
  final String? checksum, notes;
  factory DataPackEvidence.fromMap(Map<String, Object?> m) => DataPackEvidence(
    id: _requiredString(m, 'id'),
    type: _requiredString(m, 'type'),
    reference: _requiredString(m, 'reference'),
    capturedAt: m['capturedAt'] == null
        ? null
        : DateTime.parse(m['capturedAt']! as String),
    checksum: m['checksum'] as String?,
    notes: m['notes'] as String?,
  );
}

class DataPackObservation {
  const DataPackObservation({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.fieldName,
    required this.value,
    required this.sourceId,
    required this.observedAt,
    required this.verificationStatus,
    this.confidence,
    this.gameVersion,
    this.evidenceId,
    this.notes,
    this.reviewState = 'ENTERED',
  });
  final String id,
      entityType,
      entityId,
      fieldName,
      sourceId,
      verificationStatus;
  final Object? value;
  final DateTime observedAt;
  final double? confidence;
  final String? gameVersion, evidenceId, notes;
  final String reviewState;
  factory DataPackObservation.fromMap(Map<String, Object?> m) =>
      DataPackObservation(
        id: _requiredString(m, 'id'),
        entityType: _requiredString(m, 'entityType'),
        entityId: _requiredString(m, 'entityId'),
        fieldName: _requiredString(m, 'fieldName'),
        value: m['value'],
        sourceId: _requiredString(m, 'sourceId'),
        observedAt: DateTime.parse(_requiredString(m, 'observedAt')),
        verificationStatus: _requiredString(m, 'verificationStatus'),
        confidence: _number(m['confidence']),
        gameVersion: m['gameVersion'] as String?,
        evidenceId: m['evidenceId'] as String?,
        notes: m['notes'] as String?,
        reviewState: (m['reviewState'] as String?) ?? 'ENTERED',
      );
}

Map<String, Object?> _decodeMap(String content) =>
    Map<String, Object?>.from(jsonDecode(content) as Map);
List<Map<String, Object?>> _decodeList(String content) =>
    (jsonDecode(content) as List)
        .map((value) => Map<String, Object?>.from(value as Map))
        .toList();
String _requiredString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String || value.isEmpty)
    throw FormatException('Missing string field $key');
  return value;
}

int _requiredInt(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! int) throw FormatException('Missing integer field $key');
  return value;
}

double _requiredNumber(Object? value) {
  final parsed = _number(value);
  if (parsed == null || !parsed.isFinite)
    throw const FormatException('Invalid number');
  return parsed;
}

double? _number(Object? value) => value is num ? value.toDouble() : null;
List<String> _stringList(Object? value, String key) {
  if (value is! List) throw FormatException('Missing list field $key');
  return value.cast<String>();
}

Map<String, String> _stringMap(Object? value, String key) {
  if (value is! Map) throw FormatException('Missing map field $key');
  return value.map((key, value) => MapEntry(key as String, value as String));
}

void _ensureUnique(Iterable<String> values, String type) {
  final list = values.toList();
  if (list.toSet().length != list.length)
    throw FormatException('Duplicate $type ID');
}
