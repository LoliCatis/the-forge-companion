import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:calculation_engine/calculation_engine.dart';

import 'models.dart';
import 'data_resolver.dart';
import 'game_data_store.dart';
import 'data_pack.dart';

class GameDatabase implements GameDataStore {
  GameDatabase._(this._db);

  final Database _db;

  static Future<GameDatabase> open(
    String path,
  ) async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 7,
        onCreate: (db, version) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.execute('''
            CREATE TABLE data_sources (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              source_type TEXT NOT NULL,
              url TEXT,
              license TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE ores (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL UNIQUE,
              rarity TEXT,
              multiplier REAL,
              price REAL,
              source TEXT NOT NULL,
              source_url TEXT,
              observed_at TEXT,
              game_version TEXT,
              confidence REAL,
              verification_status TEXT NOT NULL DEFAULT 'UNKNOWN'
            )
          ''');
          await db.execute('''
            CREATE TABLE ore_traits (
              id TEXT PRIMARY KEY,
              ore_id TEXT NOT NULL REFERENCES ores(id) ON DELETE CASCADE,
              effect_type TEXT,
              name TEXT NOT NULL,
              activation_threshold REAL,
              full_threshold REAL,
              proc_chance REAL,
              damage_multiplier REAL,
              radius REAL,
              cooldown_seconds REAL,
              duration_seconds REAL,
              flat_damage REAL,
              trigger TEXT,
              stat_modifier REAL,
              stacking_rule TEXT,
              scaling_rule TEXT NOT NULL DEFAULT 'UNKNOWN'
            )
          ''');
          await db.execute('''
            CREATE TABLE inventory (
              ore_id TEXT PRIMARY KEY REFERENCES ores(id) ON DELETE CASCADE,
              quantity INTEGER NOT NULL DEFAULT 0 CHECK(quantity >= 0),
              protected_quantity INTEGER NOT NULL DEFAULT 0 CHECK(protected_quantity >= 0 AND protected_quantity <= quantity)
            )
          ''');
          await db.execute('''
            CREATE TABLE observations (
              id TEXT PRIMARY KEY,
              entity_type TEXT NOT NULL,
              entity_id TEXT NOT NULL,
              field_name TEXT NOT NULL,
              value_json TEXT,
              source_id TEXT REFERENCES data_sources(id),
              observed_at TEXT NOT NULL,
              game_version TEXT,
              confidence REAL,
              verification_status TEXT NOT NULL,
              evidence_ref TEXT,
              evidence_id TEXT,
              review_state TEXT NOT NULL DEFAULT 'ENTERED',
              verification_session_id TEXT,
              notes TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE resolved_fields (
              entity_type TEXT NOT NULL,
              entity_id TEXT NOT NULL,
              field_name TEXT NOT NULL,
              preferred_observation_id TEXT REFERENCES observations(id),
              PRIMARY KEY(entity_type, entity_id, field_name)
            )
          ''');
          await db.execute('''
            CREATE TABLE game_versions (
              id TEXT PRIMARY KEY,
              label TEXT NOT NULL,
              observed_at TEXT,
              source_id TEXT REFERENCES data_sources(id)
            )
          ''');
          await db.execute('''
            CREATE TABLE weapons (
              id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE,
              weapon_class TEXT, base_damage REAL, attack_interval REAL,
              source TEXT, observed_at TEXT, game_version TEXT,
              confidence REAL, verification_status TEXT NOT NULL DEFAULT 'UNKNOWN'
            )
          ''');
          await db.execute('''
            CREATE TABLE armor (
              id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE,
              armor_class TEXT, base_defense REAL, source TEXT,
              observed_at TEXT, game_version TEXT, confidence REAL,
              verification_status TEXT NOT NULL DEFAULT 'UNKNOWN'
            )
          ''');
          await db.execute('''
            CREATE TABLE forge_probabilities (
              id TEXT PRIMARY KEY, craft_type TEXT NOT NULL,
              total_ores INTEGER NOT NULL, result_class TEXT NOT NULL,
              probability REAL NOT NULL, source TEXT NOT NULL,
              observed_at TEXT, game_version TEXT, confidence REAL,
              verification_status TEXT NOT NULL DEFAULT 'UNKNOWN'
            )
          ''');
          await db.execute('''
            CREATE TABLE recipes (
              id TEXT PRIMARY KEY, name TEXT NOT NULL,
              recipe_json TEXT NOT NULL, source TEXT,
              observed_at TEXT, game_version TEXT,
              confidence REAL, verification_status TEXT NOT NULL DEFAULT 'UNKNOWN'
            )
          ''');
          await db.execute('''
            CREATE TABLE rocks (
              id TEXT PRIMARY KEY, name TEXT NOT NULL,
              location_id TEXT, multiplier REAL, source TEXT,
              observed_at TEXT, game_version TEXT, confidence REAL,
              verification_status TEXT NOT NULL DEFAULT 'UNKNOWN'
            )
          ''');
          await db.execute('''
            CREATE TABLE locations (
              id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE,
              world TEXT, source TEXT, observed_at TEXT,
              game_version TEXT, confidence REAL,
              verification_status TEXT NOT NULL DEFAULT 'UNKNOWN'
            )
          ''');
          await db.execute('''
            CREATE TABLE saved_builds (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              recipe_json TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE probability_table_diagnostics (
              id TEXT PRIMARY KEY,
              source_id TEXT REFERENCES data_sources(id),
              craft_type TEXT NOT NULL,
              total_ores INTEGER NOT NULL,
              source_sum REAL NOT NULL,
              status TEXT NOT NULL,
              notes TEXT
            )
          ''');
          await _createMilestoneTables(db);
          await _createVerificationTables(db);
          await db.execute(
            'ALTER TABLE verification_sessions ADD COLUMN official_game_version TEXT',
          );
          await db.execute(
            'ALTER TABLE verification_sessions ADD COLUMN observed_live_at TEXT',
          );
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              'ALTER TABLE inventory ADD COLUMN protected_quantity INTEGER NOT NULL DEFAULT 0 CHECK(protected_quantity >= 0 AND protected_quantity <= quantity)',
            );
            await db.execute('ALTER TABLE observations ADD COLUMN notes TEXT');
            await db.execute('''
              CREATE TABLE resolved_fields (
                entity_type TEXT NOT NULL,
                entity_id TEXT NOT NULL,
                field_name TEXT NOT NULL,
                preferred_observation_id TEXT REFERENCES observations(id),
                PRIMARY KEY(entity_type, entity_id, field_name)
              )
            ''');
          }
          if (oldVersion < 3) {
            await db.execute(
              'ALTER TABLE ore_traits ADD COLUMN flat_damage REAL',
            );
            await db.execute('ALTER TABLE ore_traits ADD COLUMN trigger TEXT');
            await db.execute(
              'ALTER TABLE ore_traits ADD COLUMN stat_modifier REAL',
            );
            await db.execute('''
              CREATE TABLE saved_builds (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                recipe_json TEXT NOT NULL,
                created_at TEXT NOT NULL
              )
            ''');
          }
          if (oldVersion < 4) {
            await db.execute('''
              CREATE TABLE probability_table_diagnostics (
                id TEXT PRIMARY KEY,
                source_id TEXT REFERENCES data_sources(id),
                craft_type TEXT NOT NULL,
                total_ores INTEGER NOT NULL,
                source_sum REAL NOT NULL,
                status TEXT NOT NULL,
                notes TEXT
              )
            ''');
          }
          if (oldVersion < 5) {
            await db.execute(
              'ALTER TABLE observations ADD COLUMN evidence_id TEXT',
            );
            await db.execute(
              "ALTER TABLE observations ADD COLUMN review_state TEXT NOT NULL DEFAULT 'ENTERED'",
            );
            await _createMilestoneTables(db);
          }
          if (oldVersion < 6) {
            await db.execute(
              'ALTER TABLE observations ADD COLUMN verification_session_id TEXT',
            );
            await db.execute(
              'ALTER TABLE evidence ADD COLUMN original_filename TEXT',
            );
            await db.execute(
              'ALTER TABLE evidence ADD COLUMN imported_at TEXT',
            );
            await db.execute('ALTER TABLE evidence ADD COLUMN width INTEGER');
            await db.execute('ALTER TABLE evidence ADD COLUMN height INTEGER');
            await db.execute('ALTER TABLE evidence ADD COLUMN session_id TEXT');
            await db.execute(
              'ALTER TABLE evidence ADD COLUMN parent_evidence_id TEXT',
            );
            await _createVerificationTables(db);
          }
          if (oldVersion < 7) {
            await db.execute(
              'ALTER TABLE verification_sessions ADD COLUMN official_game_version TEXT',
            );
            await db.execute(
              'ALTER TABLE verification_sessions ADD COLUMN observed_live_at TEXT',
            );
            await _createRepositoryIntakeTable(db);
          }
        },
      ),
    );
    return GameDatabase._(db);
  }

  Future<List<OreTraitRecord>> getOreTraits(String oreId) async {
    final rows = await _db.query(
      'ore_traits',
      where: 'ore_id = ?',
      whereArgs: [oreId],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows
        .map(
          (row) => OreTraitRecord(
            id: row['id']! as String,
            oreId: row['ore_id']! as String,
            name: row['name']! as String,
            effectType: row['effect_type'] as String?,
            activationThreshold: (row['activation_threshold'] as num?)
                ?.toDouble(),
            fullThreshold: (row['full_threshold'] as num?)?.toDouble(),
            procChance: (row['proc_chance'] as num?)?.toDouble(),
            damageMultiplier: (row['damage_multiplier'] as num?)?.toDouble(),
            flatDamage: (row['flat_damage'] as num?)?.toDouble(),
            durationSeconds: (row['duration_seconds'] as num?)?.toDouble(),
            cooldownSeconds: (row['cooldown_seconds'] as num?)?.toDouble(),
            radius: (row['radius'] as num?)?.toDouble(),
            stackingRule: row['stacking_rule'] as String?,
            trigger: row['trigger'] as String?,
            statModifier: (row['stat_modifier'] as num?)?.toDouble(),
            scalingRule: row['scaling_rule']! as String,
          ),
        )
        .toList(growable: false);
  }

  Future<DataSourceRecord?> getDataSource(String id) async {
    final rows = await _db.query(
      'data_sources',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return DataSourceRecord(
      id: row['id']! as String,
      name: row['name']! as String,
      sourceType: row['source_type']! as String,
      url: row['url'] as String?,
      license: row['license'] as String?,
    );
  }

  Future<ResolvedField> resolveField({
    required String entityType,
    required String entityId,
    required String fieldName,
    DataPolicy policy = DataPolicy.bestAvailable,
  }) async {
    var observations = await getObservations(
      entityType: entityType,
      entityId: entityId,
      fieldName: fieldName,
    );
    final latestSession = await _db.query(
      'verification_sessions',
      columns: ['game_update_label', 'official_game_version'],
      orderBy: 'session_date DESC, created_at DESC',
      limit: 1,
    );
    final currentLabel = latestSession.isEmpty
        ? null
        : (latestSession.single['official_game_version'] as String? ??
              ((latestSession.single['game_update_label'] as String).startsWith(
                        'Unknown official update',
                      ) ||
                      (latestSession.single['game_update_label'] as String)
                          .startsWith('Unspecified update')
                  ? null
                  : latestSession.single['game_update_label'] as String));
    if (currentLabel != null) {
      observations = observations
          .map((observation) {
            if (observation.verificationStatus != 'IN_GAME_VERIFIED' ||
                observation.gameVersion == currentLabel)
              return observation;
            return FieldObservation(
              id: observation.id,
              entityType: observation.entityType,
              entityId: observation.entityId,
              fieldName: observation.fieldName,
              value: observation.value,
              sourceId: observation.sourceId,
              observedAt: observation.observedAt,
              gameVersion: observation.gameVersion,
              confidence: observation.confidence,
              verificationStatus: 'STALE_VERIFIED',
              evidenceReference: observation.evidenceReference,
              evidenceId: observation.evidenceId,
              notes: observation.notes,
              reviewState: observation.reviewState,
              verificationSessionId: observation.verificationSessionId,
            );
          })
          .toList(growable: false);
    }
    final resolved = DataResolver().resolve(observations, policy: policy);
    if (policy != DataPolicy.bestAvailable) return resolved;
    final preferredId = await getPreferredObservationId(
      entityType: entityType,
      entityId: entityId,
      fieldName: fieldName,
    );
    if (preferredId == null) return resolved;
    final preferred = observations
        .where((o) => o.id == preferredId)
        .firstOrNull;
    if (preferred == null) return resolved;
    return ResolvedField(
      preferred: preferred,
      alternatives: List.unmodifiable(
        observations.where((o) => o.id != preferredId),
      ),
      conflicting: resolved.conflicting,
    );
  }

  Future<void> addObservation(FieldObservation observation) async {
    if (observation.verificationStatus == 'IN_GAME_VERIFIED' ||
        observation.verificationStatus == 'USER_CONFIRMED_CAPTURE' ||
        observation.reviewState != 'ENTERED') {
      throw StateError(
        'Observation intake starts at ENTERED; confirmation states are controlled by the review workflow',
      );
    }
    await _db.insert('observations', {
      'id': observation.id,
      'entity_type': observation.entityType,
      'entity_id': observation.entityId,
      'field_name': observation.fieldName,
      'value_json': jsonEncode(observation.value),
      'source_id': observation.sourceId,
      'observed_at': observation.observedAt.toIso8601String(),
      'game_version': observation.gameVersion,
      'confidence': observation.confidence,
      'verification_status': observation.verificationStatus,
      'evidence_ref': observation.evidenceReference,
      'evidence_id': observation.evidenceId,
      'review_state': observation.reviewState,
      'verification_session_id': observation.verificationSessionId,
      'notes': observation.notes,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<FieldObservation>> getObservations({
    required String entityType,
    required String entityId,
    required String fieldName,
  }) async {
    final rows = await _db.query(
      'observations',
      where: 'entity_type = ? AND entity_id = ? AND field_name = ?',
      whereArgs: [entityType, entityId, fieldName],
      orderBy: 'observed_at DESC',
    );
    return rows.map(FieldObservation.fromMap).toList(growable: false);
  }

  Future<void> setPreferredObservation({
    required String entityType,
    required String entityId,
    required String fieldName,
    required String observationId,
  }) async {
    final matching = await _db.query(
      'observations',
      columns: ['id'],
      where: 'id = ? AND entity_type = ? AND entity_id = ? AND field_name = ?',
      whereArgs: [observationId, entityType, entityId, fieldName],
    );
    if (matching.isEmpty)
      throw ArgumentError('Observation does not match field');
    await _db.insert('resolved_fields', {
      'entity_type': entityType,
      'entity_id': entityId,
      'field_name': fieldName,
      'preferred_observation_id': observationId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final observationRows = await _db.query(
      'observations',
      where: 'entity_type = ? AND entity_id = ? AND field_name = ?',
      whereArgs: [entityType, entityId, fieldName],
    );
    final selected = observationRows
        .where((row) => row['id'] == observationId)
        .firstOrNull;
    if (entityType == 'ORE' && selected != null) {
      final distinct = observationRows.map((row) => row['value_json']).toSet();
      final value = jsonDecode(selected['value_json']! as String);
      final fieldColumn = switch (fieldName) {
        'multiplier' => 'multiplier',
        'price' => 'price',
        _ => null,
      };
      if (fieldColumn != null) {
        await _db.update(
          'ores',
          {
            fieldColumn: value,
            'verification_status': distinct.length > 1
                ? 'CONFLICTING'
                : selected['verification_status'],
            'confidence': selected['confidence'],
          },
          where: 'id = ?',
          whereArgs: [entityId],
        );
      }
    }
    if (entityType == 'WEAPON_VARIANT') {
      if (selected == null) return;
      final distinct = observationRows.map((row) => row['value_json']).toSet();
      final value = jsonDecode(selected['value_json']! as String);
      final column = switch (fieldName) {
        'base_damage' => 'base_damage',
        'attack_interval' || 'attack_interval_seconds' => 'attack_interval',
        'range' => 'range_value',
        'variant_weight' || 'variant_probability' => 'variant_weight',
        _ => null,
      };
      if (column != null) {
        final packs = await _db.query(
          'pack_weapon_variants',
          columns: ['pack_id'],
          where: 'variant_id = ?',
          whereArgs: [entityId],
        );
        for (final pack in packs) {
          await _db.update(
            'pack_weapon_variants',
            {
              column: value,
              'verification_status': distinct.length > 1
                  ? 'CONFLICTING'
                  : selected['verification_status'],
            },
            where: 'pack_id = ? AND variant_id = ?',
            whereArgs: [pack['pack_id'], entityId],
          );
        }
      }
    }
  }

  Future<String?> getPreferredObservationId({
    required String entityType,
    required String entityId,
    required String fieldName,
  }) async {
    final rows = await _db.query(
      'resolved_fields',
      columns: ['preferred_observation_id'],
      where: 'entity_type = ? AND entity_id = ? AND field_name = ?',
      whereArgs: [entityType, entityId, fieldName],
    );
    return rows.isEmpty
        ? null
        : rows.single['preferred_observation_id'] as String?;
  }

  Future<List<DataHealthIssue>> getDataHealthIssues() async {
    final issues = <DataHealthIssue>[];
    final latestSession = await _db.query(
      'verification_sessions',
      columns: ['game_update_label', 'official_game_version'],
      orderBy: 'session_date DESC, created_at DESC',
      limit: 1,
    );
    final currentLabel = latestSession.isEmpty
        ? null
        : (latestSession.single['official_game_version'] as String? ??
              ((latestSession.single['game_update_label'] as String).startsWith(
                        'Unknown official update',
                      ) ||
                      (latestSession.single['game_update_label'] as String)
                          .startsWith('Unspecified update')
                  ? null
                  : latestSession.single['game_update_label'] as String));
    if (currentLabel != null) {
      final stale = await _db.query(
        'observations',
        where:
            "verification_status = 'IN_GAME_VERIFIED' AND (game_version IS NULL OR game_version != ?)",
        whereArgs: [currentLabel],
      );
      for (final row in stale) {
        issues.add(
          DataHealthIssue(
            entityType: row['entity_type']! as String,
            entityId: row['entity_id']! as String,
            fieldName: row['field_name']! as String,
            status: 'STALE_VERIFIED',
            message:
                'Verified for ${row['game_version'] ?? 'unknown update'} at ${row['observed_at']}; current session context is $currentLabel. Original observation is preserved.',
          ),
        );
      }
    }
    final rows = await _db.rawQuery(
      '''
      SELECT entity_type, entity_id, field_name, COUNT(*) AS observations,
             COUNT(DISTINCT value_json) AS distinct_values,
             COUNT(DISTINCT CASE WHEN verification_status = 'IN_GAME_VERIFIED'
               AND (? IS NULL OR game_version = ?) THEN value_json END) AS current_verified_values
      FROM observations
      GROUP BY entity_type, entity_id, field_name
      HAVING COUNT(DISTINCT value_json) > 1
      ''',
      [currentLabel, currentLabel],
    );
    for (final row in rows) {
      issues.add(
        DataHealthIssue(
          entityType: row['entity_type']! as String,
          entityId: row['entity_id']! as String,
          fieldName: row['field_name']! as String,
          status: row['current_verified_values'] == 1
              ? 'SUPERSEDED'
              : 'CONFLICTING',
          message: row['current_verified_values'] == 1
              ? 'A current in-game verified value supersedes older alternatives; all ${row['observations']} observations remain in history.'
              : '${row['distinct_values']} different values from ${row['observations']} observations',
        ),
      );
    }
    final diagnostics = await _db.query('probability_table_diagnostics');
    for (final row in diagnostics) {
      issues.add(
        DataHealthIssue(
          entityType: 'PROBABILITY_TABLE',
          entityId: '${row['craft_type']}-count-${row['total_ores']}',
          fieldName: 'sum',
          status: row['status']! as String,
          message:
              'Source probability sum ${row['source_sum']}; ${row['notes']}',
        ),
      );
    }
    final unknowns = await _db.query('ores', columns: ['id', 'name']);
    for (final row in unknowns) {
      final resolved = await resolveField(
        entityType: 'ORE',
        entityId: row['id']! as String,
        fieldName: 'multiplier',
      );
      if (resolved.preferred != null || resolved.conflicting) continue;
      issues.add(
        DataHealthIssue(
          entityType: 'ORE',
          entityId: row['id']! as String,
          fieldName: 'multiplier',
          status: 'UNKNOWN',
          message: '${row['name']} multiplier has no resolved value',
        ),
      );
    }
    final unknownTraitFields = await _db.rawQuery('''
      SELECT t.id, t.name, t.ore_id, o.name AS ore_name,
             t.activation_threshold, t.full_threshold, t.proc_chance,
             t.damage_multiplier, t.flat_damage, t.duration_seconds,
             t.cooldown_seconds, t.radius, t.trigger, t.stat_modifier
      FROM ore_traits t JOIN ores o ON o.id = t.ore_id
    ''');
    const traitFields = <String, String>{
      'activation_threshold': 'activation threshold',
      'full_threshold': 'full activation threshold',
      'proc_chance': 'proc chance',
      'damage_multiplier': 'damage multiplier',
      'flat_damage': 'flat damage',
      'duration_seconds': 'duration',
      'cooldown_seconds': 'cooldown',
      'radius': 'radius',
      'trigger': 'trigger',
      'stat_modifier': 'stat modifier',
    };
    for (final row in unknownTraitFields) {
      for (final entry in traitFields.entries) {
        if (row[entry.key] == null) {
          issues.add(
            DataHealthIssue(
              entityType: 'TRAIT',
              entityId: row['id']! as String,
              fieldName: entry.key,
              status: 'UNKNOWN',
              message:
                  '${row['ore_name']} · ${row['name']} ${entry.value} is not established',
            ),
          );
        }
      }
    }
    final activePack = await _db.query(
      'data_packs',
      columns: ['pack_id'],
      where: 'active = 1',
      limit: 1,
    );
    if (activePack.isNotEmpty) {
      final packId = activePack.single['pack_id']! as String;
      final weapons = await _db.query(
        'pack_weapon_variants',
        where: 'pack_id = ?',
        whereArgs: [packId],
      );
      for (final weapon in weapons) {
        final id = weapon['variant_id']! as String;
        final name = weapon['name']! as String;
        for (final field in const [
          'base_damage',
          'attack_interval',
          'range_value',
          'variant_weight',
        ]) {
          if (weapon[field] == null) {
            issues.add(
              DataHealthIssue(
                entityType: 'WEAPON_VARIANT',
                entityId: id,
                fieldName: field,
                status: 'UNKNOWN',
                message: '$name $field is not established in this pack',
              ),
            );
          } else if (weapon['verification_status'] != 'IN_GAME_VERIFIED') {
            issues.add(
              DataHealthIssue(
                entityType: 'WEAPON_VARIANT',
                entityId: id,
                fieldName: field,
                status: weapon['verification_status']! as String,
                message:
                    '$name $field is a candidate value without in-game evidence',
              ),
            );
          }
        }
      }
      final probabilityTables = await _db.query(
        'pack_probability_tables',
        where: 'pack_id = ?',
        whereArgs: [packId],
      );
      for (final table in probabilityTables) {
        final validationStatus = table['validation_status']! as String;
        final verificationStatus = table['verification_status']! as String;
        issues.add(
          DataHealthIssue(
            entityType: 'PROBABILITY_TABLE',
            entityId: table['table_id']! as String,
            fieldName: 'probability',
            status:
                validationStatus == 'INVALID' ||
                    validationStatus == 'UNDERFLOW' ||
                    validationStatus == 'OVERFLOW'
                ? validationStatus
                : (verificationStatus == 'IN_GAME_VERIFIED'
                      ? validationStatus
                      : 'NEEDS_VERIFICATION'),
            message:
                '${table['craft_type']} · raw sum ${table['raw_sum']}; source status $verificationStatus. ${table['notes'] ?? ''}',
          ),
        );
      }
    }
    return issues;
  }

  Future<List<OreRecord>> searchOres(
    String query, {
    DataPolicy policy = DataPolicy.bestAvailable,
  }) async {
    final rows = await _db.rawQuery(
      '''
      SELECT ores.*, COALESCE(inventory.quantity, 0) AS inventory_quantity
      FROM ores LEFT JOIN inventory ON inventory.ore_id = ores.id
      WHERE lower(ores.name) LIKE ? ORDER BY ores.name COLLATE NOCASE
    ''',
      ['%${query.toLowerCase()}%'],
    );
    final result = <OreRecord>[];
    for (final row in rows) {
      final ore = OreRecord.fromMap(row);
      final multiplier = await resolveField(
        entityType: 'ORE', entityId: ore.id, fieldName: 'multiplier', policy: policy,
      );
      final rarity = await resolveField(
        entityType: 'ORE', entityId: ore.id, fieldName: 'rarity', policy: policy,
      );
      final price = await resolveField(
        entityType: 'ORE', entityId: ore.id, fieldName: 'price', policy: policy,
      );
      final displayedTraits = await resolveField(
        entityType: 'ORE',
        entityId: ore.id,
        fieldName: 'displayed_trait',
        policy: policy,
      );
      final traits = displayedTraits.preferred?.value == null
          ? const <OreTraitRecord>[]
          : _resolvedOreTraits(ore.id, displayedTraits.preferred!.value);
      final conflict = multiplier.conflicting || rarity.conflicting ||
          price.conflicting || displayedTraits.conflicting;
      final status = conflict ? 'CONFLICTING' :
          (multiplier.preferred?.verificationStatus ?? 'UNKNOWN');
      result.add(
        OreRecord(
          id: ore.id,
          name: ore.name,
          rarity: rarity.preferred?.value?.toString(),
          multiplier: (multiplier.preferred?.value as num?)?.toDouble(),
          price: (price.preferred?.value as num?)?.toDouble(),
          source: multiplier.preferred?.sourceId ?? ore.source,
          sourceUrl: ore.sourceUrl,
          observedAt: ore.observedAt,
          gameVersion: ore.gameVersion,
          confidence: multiplier.preferred?.confidence,
          verificationStatus: status,
          traits: traits,
        ),
      );
    }
    return List.unmodifiable(result);
  }

  List<OreTraitRecord> _resolvedOreTraits(String oreId, Object? value) {
    final values = value is List ? value : [value];
    return List.unmodifiable(values.where((item) => item != null).map((item) {
      final map = item is Map ? item : const <Object?, Object?>{};
      final name = item is String
          ? item
          : (map['name'] ?? map['trait'] ?? map['effect'])?.toString() ?? 'Unknown';
      final threshold = map['activationThreshold'] ?? map['activation_threshold'];
      return OreTraitRecord(
        id: 'resolved:$oreId:$name',
        oreId: oreId,
        name: name,
        effectType: (map['effectType'] ?? map['effect_type'])?.toString(),
        activationThreshold: (threshold as num?)?.toDouble(),
      );
    }));
  }

  Future<void> upsertDataSource(DataSourceRecord source) async {
    await _db.insert('data_sources', {
      'id': source.id,
      'name': source.name,
      'source_type': source.sourceType,
      'url': source.url,
      'license': source.license,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> upsertOre(OreRecord ore) async {
    await _db.rawInsert(
      '''
      INSERT INTO ores (id, name, rarity, multiplier, price, source, source_url,
                        observed_at, game_version, confidence, verification_status)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name=excluded.name, rarity=excluded.rarity, multiplier=excluded.multiplier,
        price=excluded.price, source=excluded.source, source_url=excluded.source_url,
        observed_at=excluded.observed_at, game_version=excluded.game_version,
        confidence=excluded.confidence, verification_status=excluded.verification_status
    ''',
      [
        ore.id,
        ore.name,
        ore.rarity,
        ore.multiplier,
        ore.price,
        ore.source,
        ore.sourceUrl,
        ore.observedAt?.toIso8601String(),
        ore.gameVersion,
        ore.confidence,
        ore.verificationStatus,
      ],
    );
  }

  Future<List<InventoryRecord>> getInventory({
    DataPolicy policy = DataPolicy.bestAvailable,
  }) async {
    final rows = await _db.rawQuery('''
      SELECT ores.id AS ore_id, ores.name AS ore_name, ores.multiplier,
             ores.rarity, ores.confidence,
             GROUP_CONCAT(ore_traits.effect_type, '|') AS effect_tags,
             GROUP_CONCAT(ore_traits.effect_type || ':' || ore_traits.activation_threshold, '|') AS effect_thresholds,
             ores.verification_status, COALESCE(inventory.quantity, 0) AS quantity,
             COALESCE(inventory.protected_quantity, 0) AS protected_quantity
      FROM ores LEFT JOIN inventory ON inventory.ore_id = ores.id
      LEFT JOIN ore_traits ON ore_traits.ore_id = ores.id
      GROUP BY ores.id
      ORDER BY ores.name COLLATE NOCASE
    ''');
    final resolvedOres = {
      for (final ore in await searchOres('', policy: policy)) ore.id: ore,
    };
    return rows.map((row) {
      final inventory = InventoryRecord.fromMap(row);
      final ore = resolvedOres[inventory.oreId];
      if (ore == null) return inventory;
      return InventoryRecord(
        oreId: inventory.oreId,
        oreName: inventory.oreName,
        quantity: inventory.quantity,
        protectedQuantity: inventory.protectedQuantity,
        verificationStatus: ore.verificationStatus,
        multiplier: ore.multiplier,
        rarity: ore.rarity,
        confidence: ore.confidence,
        effectTags: ore.traits
            .map((trait) => trait.effectType ?? trait.name)
            .toSet(),
        effectActivationThresholds: {
          for (final trait in ore.traits)
            if (trait.activationThreshold != null)
              (trait.effectType ?? trait.name): trait.activationThreshold!,
        },
      );
    }).toList(growable: false);
  }

  Future<void> setInventoryQuantity(
    String oreId,
    int quantity, {
    int protectedQuantity = 0,
  }) async {
    if (quantity < 0) throw ArgumentError.value(quantity, 'quantity');
    if (protectedQuantity < 0 || protectedQuantity > quantity) {
      throw ArgumentError.value(protectedQuantity, 'protectedQuantity');
    }
    await _db.insert('inventory', {
      'ore_id': oreId,
      'quantity': quantity,
      'protected_quantity': protectedQuantity,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> setProtectedQuantity(String oreId, int protectedQuantity) async {
    final rows = await _db.query(
      'inventory',
      columns: ['quantity'],
      where: 'ore_id = ?',
      whereArgs: [oreId],
    );
    if (rows.isEmpty) {
      if (protectedQuantity != 0) {
        throw ArgumentError('Set the inventory quantity before protecting it');
      }
      return;
    }
    final quantity = rows.single['quantity']! as int;
    if (protectedQuantity < 0 || protectedQuantity > quantity) {
      throw ArgumentError.value(protectedQuantity, 'protectedQuantity');
    }
    await _db.update(
      'inventory',
      {'protected_quantity': protectedQuantity},
      where: 'ore_id = ?',
      whereArgs: [oreId],
    );
  }

  Future<int> countByVerificationStatus(String status) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS count FROM ores WHERE verification_status = ?',
      [status],
    );
    return result.single['count']! as int;
  }

  Future<int> countObservationsByVerificationStatus(String status) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS count FROM observations WHERE verification_status = ?',
      [status],
    );
    return result.single['count']! as int;
  }

  Future<int> countAllOres() async =>
      (await _db.rawQuery(
            'SELECT COUNT(*) AS count FROM ores',
          )).single['count']!
          as int;

  Future<int> totalInventoryCount() async {
    final result = await _db.rawQuery(
      'SELECT COALESCE(SUM(quantity), 0) AS total FROM inventory',
    );
    return result.single['total']! as int;
  }

  Future<void> saveBuild(SavedBuildRecord build) async {
    await _db.insert('saved_builds', {
      'id': build.id,
      'name': build.name,
      'recipe_json': jsonEncode(build.recipe),
      'created_at': build.createdAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SavedBuildRecord>> getSavedBuilds() async {
    final rows = await _db.query('saved_builds', orderBy: 'created_at DESC');
    return rows
        .map(
          (row) => SavedBuildRecord(
            id: row['id']! as String,
            name: row['name']! as String,
            recipe:
                (jsonDecode(row['recipe_json']! as String)
                        as Map<String, dynamic>)
                    .map((key, value) => MapEntry(key, value as int)),
            createdAt: DateTime.parse(row['created_at']! as String),
          ),
        )
        .toList(growable: false);
  }

  Future<void> deleteBuild(String id) async {
    await _db.delete('saved_builds', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> importDataPack(ValidatedDataPack pack) async {
    await _db.transaction((txn) async {
      final duplicate = await txn.query(
        'data_packs',
        where: 'pack_id = ? OR data_version = ?',
        whereArgs: [pack.manifest.packId, pack.manifest.dataVersion],
      );
      if (duplicate.isNotEmpty) {
        throw StateError('Data pack version is already installed');
      }
      await txn.insert('data_packs', {
        'pack_id': pack.manifest.packId,
        'schema_version': pack.manifest.schemaVersion,
        'data_version': pack.manifest.dataVersion,
        'created_at': pack.manifest.createdAt.toIso8601String(),
        'game_version': pack.manifest.gameVersion,
        'game_update_label': pack.manifest.gameUpdateLabel,
        'ruleset_version': pack.manifest.rulesetVersion,
        'manifest_json': pack.rawFiles['manifest.json'],
        'active': 0,
      });
      for (final source in pack.sources) {
        await txn.insert('data_sources', {
          'id': source.id,
          'name': source.name,
          'source_type': source.type,
          'url': source.url,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final evidence in pack.evidence) {
        await txn.insert('evidence', {
          'id': evidence.id,
          'type': evidence.type,
          'reference': evidence.reference,
          'captured_at': evidence.capturedAt?.toIso8601String(),
          'checksum': evidence.checksum,
          'notes': evidence.notes,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final ore in pack.ores) {
        final json = {
          'id': ore.id,
          'name': ore.name,
          'rarity': ore.rarity,
          'multiplier': ore.multiplier,
          'sourceId': ore.sourceId,
          'verificationStatus': ore.verificationStatus,
          'confidence': ore.confidence,
        };
        await txn.insert('pack_ores', {
          'pack_id': pack.manifest.packId,
          'ore_id': ore.id,
          'name': ore.name,
          'multiplier': ore.multiplier,
          'verification_status': ore.verificationStatus,
          'payload_json': jsonEncode(json),
        });
      }
      for (final weaponClass in pack.weaponClasses) {
        await txn.insert('pack_weapon_classes', {
          'pack_id': pack.manifest.packId,
          'class_id': weaponClass.id,
          'name': weaponClass.name,
          'forge_available': weaponClass.forgeAvailable ? 1 : 0,
          'verification_status': weaponClass.verificationStatus,
          'payload_json': jsonEncode({
            'id': weaponClass.id,
            'name': weaponClass.name,
            'forgeAvailable': weaponClass.forgeAvailable,
            'verificationStatus': weaponClass.verificationStatus,
          }),
        });
      }
      for (final weapon in pack.weapons) {
        final fieldValues = <String, Object?>{};
        var hasConflict = false;
        for (final field in const [
          'base_damage',
          'attack_interval',
          'range',
          'variant_weight',
        ]) {
          final fieldObservations = pack.observations
              .where(
                (observation) =>
                    observation.entityType == 'WEAPON_VARIANT' &&
                    observation.entityId == weapon.id &&
                    observation.fieldName == field,
              )
              .toList();
          final values = fieldObservations
              .map((observation) => jsonEncode(observation.value))
              .toSet();
          if (values.length > 1) {
            hasConflict = true;
            fieldValues[field] = null;
          } else if (fieldObservations.isNotEmpty) {
            fieldValues[field] = _numberFromObservation(
              fieldObservations.first.value,
            );
          } else {
            fieldValues[field] = switch (field) {
              'base_damage' => weapon.baseDamage,
              'attack_interval' => weapon.attackIntervalSeconds,
              'range' => weapon.range,
              'variant_weight' => weapon.variantWeight,
              _ => null,
            };
          }
        }
        final weaponStatus = hasConflict
            ? 'CONFLICTING'
            : weapon.verificationStatus;
        await txn.insert('pack_weapon_variants', {
          'pack_id': pack.manifest.packId,
          'variant_id': weapon.id,
          'class_id': weapon.classId,
          'name': weapon.name,
          'base_damage': fieldValues['base_damage'],
          'attack_interval': fieldValues['attack_interval'],
          'range_value': fieldValues['range'],
          'variant_weight': fieldValues['variant_weight'],
          'verification_status': weaponStatus,
          'payload_json': jsonEncode({
            'id': weapon.id,
            'name': weapon.name,
            'classId': weapon.classId,
            'rarity': weapon.rarity,
            'forgeAvailability': weapon.forgeAvailability,
            'confidence': weapon.confidence,
          }),
        });
      }
      final oreIds = pack.ores.map((ore) => ore.id).toSet();
      for (final trait in pack.traits) {
        if (!oreIds.contains(trait.oreId)) {
          throw StateError('Trait ${trait.id} references an unknown ore');
        }
        await txn.insert('pack_traits', {
          'pack_id': pack.manifest.packId,
          'trait_id': trait.id,
          'ore_id': trait.oreId,
          'name': trait.name,
          'payload_json': jsonEncode({
            'id': trait.id,
            'name': trait.name,
            'oreId': trait.oreId,
            'effectType': trait.effectType,
            'activationThreshold': trait.activationThreshold,
            'fullThreshold': trait.fullThreshold,
            'procChance': trait.procChance,
            'verificationStatus': trait.verificationStatus,
          }),
        });
      }
      for (final table in pack.probabilities) {
        final validation = pack.probabilityValidations[table.id]!;
        final allowNormalization =
            table.normalizationPolicy ==
                ProbabilityNormalizationPolicy.normalizedEstimate &&
            (validation.status == ProbabilityTableStatus.valid ||
                validation.status == ProbabilityTableStatus.roundingSuspected);
        final estimate = const ProbabilityTableValidator().estimate(
          validation,
          policy: allowNormalization
              ? ProbabilityNormalizationPolicy.normalizedEstimate
              : ProbabilityNormalizationPolicy.preserveSource,
        );
        final diagnostics = [
          if (table.notes != null) table.notes!,
          ...validation.issues,
          if (estimate.normalized)
            'Normalized for estimate under explicit pack policy; source sum ${validation.sourceSum}',
        ].join('\n');
        await txn.insert('pack_probability_tables', {
          'pack_id': pack.manifest.packId,
          'table_id': table.id,
          'craft_type': table.craftType,
          'total_ores': table.totalOres,
          'raw_sum': validation.sourceSum,
          'validation_status': validation.status.name.toUpperCase(),
          'verification_status': table.verificationStatus,
          'source_id': table.sourceId,
          'game_context': table.gameContext,
          'notes': diagnostics,
          'payload_json': jsonEncode({
            'normalizationPolicy': table.normalizationPolicy.name,
            'normalizedForEstimate': estimate.normalized,
            'sourceSum': validation.sourceSum,
            'issues': validation.issues,
          }),
        });
        for (final entry in table.entries) {
          await txn.insert('pack_probability_entries', {
            'pack_id': pack.manifest.packId,
            'table_id': table.id,
            'result_id': entry.resultId,
            'probability': entry.probability,
          });
        }
        await txn.insert('probability_table_diagnostics', {
          'id': '${pack.manifest.packId}-${table.id}',
          'source_id': table.sourceId,
          'craft_type': table.craftType,
          'total_ores': table.totalOres,
          'source_sum': validation.sourceSum,
          'status': validation.status.name.toUpperCase(),
          'notes': diagnostics,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final observation in pack.observations) {
        if (observation.verificationStatus == 'IN_GAME_VERIFIED') {
          final evidence = pack.evidence
              .where((item) => item.id == observation.evidenceId)
              .firstOrNull;
          final source = pack.sources
              .where((item) => item.id == observation.sourceId)
              .firstOrNull;
          if (evidence == null ||
              observation.gameVersion == null ||
              observation.reviewState != 'USER_CONFIRMED' ||
              source?.type != 'IN_GAME_MANUAL' ||
              !{'SCREENSHOT', 'MANUAL_TRANSCRIPTION'}.contains(evidence.type)) {
            throw StateError(
              'IN_GAME_VERIFIED requires in-game evidence and game context',
            );
          }
        }
        await txn.insert('pack_observations', {
          'pack_id': pack.manifest.packId,
          'observation_id': observation.id,
          'entity_type': observation.entityType,
          'entity_id': observation.entityId,
          'field_name': observation.fieldName,
          'value_json': jsonEncode(observation.value),
          'source_id': observation.sourceId,
          'observed_at': observation.observedAt.toIso8601String(),
          'game_version': observation.gameVersion,
          'confidence': observation.confidence,
          'verification_status': observation.verificationStatus,
          'evidence_id': observation.evidenceId,
          'notes': observation.notes,
        });
        await txn.insert('observations', {
          'id': '${pack.manifest.packId}:${observation.id}',
          'entity_type': observation.entityType,
          'entity_id': observation.entityId,
          'field_name': observation.fieldName,
          'value_json': jsonEncode(observation.value),
          'source_id': observation.sourceId,
          'observed_at': observation.observedAt.toIso8601String(),
          'game_version': observation.gameVersion,
          'confidence': observation.confidence,
          'verification_status': observation.verificationStatus,
          'evidence_ref': null,
          'evidence_id': observation.evidenceId,
          'review_state': observation.reviewState,
          'notes': observation.notes,
        });
      }
      for (final ore in pack.ores) {
        final observations = pack.observations
            .where(
              (o) =>
                  o.entityType == 'ORE' &&
                  o.entityId == ore.id &&
                  o.fieldName == 'multiplier',
            )
            .toList();
        final distinctValues = observations
            .map((o) => jsonEncode(o.value))
            .toSet();
        final conflict = distinctValues.length > 1;
        final value = conflict
            ? null
            : (_numberFromObservation(observations.firstOrNull?.value) ??
                  ore.multiplier);
        final status = conflict
            ? 'CONFLICTING'
            : (observations.firstOrNull?.verificationStatus ??
                  ore.verificationStatus);
        final source = pack.sources
            .where((s) => s.id == ore.sourceId)
            .firstOrNull;
        await txn.rawInsert(
          '''
          INSERT INTO ores (id, name, rarity, multiplier, price, source, source_url, observed_at, game_version, confidence, verification_status)
          VALUES (?, ?, ?, ?, NULL, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET name=excluded.name, rarity=excluded.rarity,
            multiplier=excluded.multiplier, source=excluded.source, source_url=excluded.source_url,
            observed_at=excluded.observed_at, game_version=excluded.game_version,
            confidence=excluded.confidence, verification_status=excluded.verification_status
        ''',
          [
            ore.id,
            ore.name,
            ore.rarity,
            value,
            source?.name ?? 'Data pack ${pack.manifest.dataVersion}',
            source?.url,
            observations.firstOrNull?.observedAt.toIso8601String(),
            pack.manifest.gameVersion,
            observations.firstOrNull?.confidence ?? ore.confidence,
            status,
          ],
        );
      }
      for (final trait in pack.traits) {
        await txn.delete('ore_traits', where: 'id = ?', whereArgs: [trait.id]);
        await txn.insert('ore_traits', {
          'id': trait.id,
          'ore_id': trait.oreId,
          'effect_type': trait.effectType,
          'name': trait.name,
          'activation_threshold': trait.activationThreshold,
          'full_threshold': trait.fullThreshold,
          'proc_chance': trait.procChance,
          'damage_multiplier': trait.damageMultiplier,
          'flat_damage': trait.flatDamage,
          'duration_seconds': trait.durationSeconds,
          'cooldown_seconds': trait.cooldownSeconds,
          'radius': trait.radius,
          'trigger': trait.trigger,
          'stat_modifier': trait.statModifier,
          'stacking_rule': null,
          'scaling_rule': 'UNKNOWN',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await txn.update('data_packs', {'active': 0});
      await txn.update(
        'data_packs',
        {'active': 1},
        where: 'pack_id = ?',
        whereArgs: [pack.manifest.packId],
      );
    });
  }

  @override
  Future<String?> getActiveDataVersion() async {
    final rows = await _db.query(
      'data_packs',
      columns: ['data_version'],
      where: 'active = 1',
      limit: 1,
    );
    return rows.firstOrNull?['data_version'] as String?;
  }

  @override
  Future<String?> getActiveRulesetVersion() async {
    final rows = await _db.query(
      'data_packs',
      columns: ['ruleset_version'],
      where: 'active = 1',
      limit: 1,
    );
    return rows.firstOrNull?['ruleset_version'] as String?;
  }

  Future<String?> _activePackId() async {
    final rows = await _db.query(
      'data_packs',
      columns: ['pack_id'],
      where: 'active = 1',
      limit: 1,
    );
    return rows.firstOrNull?['pack_id'] as String?;
  }

  @override
  Future<List<WeaponClassRecord>> getWeaponClasses() async {
    final packId = await _activePackId();
    if (packId == null) return const [];
    final rows = await _db.query(
      'pack_weapon_classes',
      where: 'pack_id = ?',
      whereArgs: [packId],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows
        .map(
          (row) => WeaponClassRecord(
            id: row['class_id']! as String,
            name: row['name']! as String,
            forgeAvailable: row['forge_available'] == 1,
            verificationStatus: row['verification_status']! as String,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<WeaponVariantRecord>> getWeaponVariants({String? classId}) async {
    final packId = await _activePackId();
    if (packId == null) return const [];
    final rows = await _db.query(
      'pack_weapon_variants',
      where: classId == null ? 'pack_id = ?' : 'pack_id = ? AND class_id = ?',
      whereArgs: classId == null ? [packId] : [packId, classId],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows
        .map((row) {
          final payload =
              jsonDecode(row['payload_json']! as String)
                  as Map<String, dynamic>;
          return WeaponVariantRecord(
            id: row['variant_id']! as String,
            name: row['name']! as String,
            classId: row['class_id']! as String,
            baseDamage: (row['base_damage'] as num?)?.toDouble(),
            attackIntervalSeconds: (row['attack_interval'] as num?)?.toDouble(),
            range: (row['range_value'] as num?)?.toDouble(),
            variantWeight: (row['variant_weight'] as num?)?.toDouble(),
            rarity: payload['rarity'] as String?,
            forgeAvailability: payload['forgeAvailability'] as String?,
            confidence: (payload['confidence'] as num?)?.toDouble(),
            verificationStatus: row['verification_status']! as String,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<ProbabilityTableRecord?> getProbabilityTable(String id) async {
    final packId = await _activePackId();
    if (packId == null) return null;
    final rows = await _db.query(
      'pack_probability_tables',
      where: 'pack_id = ? AND table_id = ?',
      whereArgs: [packId, id],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    final entries = await _db.query(
      'pack_probability_entries',
      where: 'pack_id = ? AND table_id = ?',
      whereArgs: [packId, id],
    );
    final payload =
        jsonDecode(row['payload_json']! as String) as Map<String, dynamic>;
    return ProbabilityTableRecord(
      id: id,
      craftType: row['craft_type']! as String,
      totalOres: row['total_ores']! as int,
      entries: Map.unmodifiable({
        for (final item in entries)
          item['result_id']! as String: (item['probability']! as num)
              .toDouble(),
      }),
      status: row['validation_status']! as String,
      sourceSum: (row['raw_sum']! as num).toDouble(),
      verificationStatus: row['verification_status']! as String,
      sourceId: row['source_id'] as String?,
      gameContext: row['game_context'] as String?,
      notes: row['notes'] as String?,
      normalizedForEstimate: payload['normalizedForEstimate'] == true,
    );
  }

  @override
  Future<void> saveCalculationSnapshot(CalculationSnapshot snapshot) async {
    await _db.insert('calculation_snapshots', {
      'id': snapshot.id,
      'catalog_version': snapshot.catalogVersion,
      'ruleset_version': snapshot.rulesetVersion,
      'recipe_json': jsonEncode(snapshot.recipe),
      'observation_ids_json': jsonEncode(snapshot.resolvedObservationIds),
      'formula_ids_json': jsonEncode(snapshot.formulaIds),
      'assumptions_json': jsonEncode(snapshot.assumptions),
      'resolved_inputs_json': jsonEncode(snapshot.resolvedInputs),
      'result_json': jsonEncode(snapshot.calculationResult),
      'data_certainty': snapshot.dataCertainty,
      'formula_certainty': snapshot.formulaCertainty,
      'probability_certainty': snapshot.probabilityCertainty,
      'created_at': snapshot.createdAt.toIso8601String(),
    });
  }

  @override
  Future<CalculationSnapshot?> getCalculationSnapshot(String id) async {
    final rows = await _db.query(
      'calculation_snapshots',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    Map<String, Object?> readMap(String field) =>
        Map<String, Object?>.from(jsonDecode(row[field]! as String) as Map);
    return CalculationSnapshot(
      id: id,
      catalogVersion: row['catalog_version']! as String,
      rulesetVersion: row['ruleset_version']! as String,
      recipe: Map<String, int>.from(
        (jsonDecode(row['recipe_json']! as String) as Map).map(
          (key, value) => MapEntry(key as String, value as int),
        ),
      ),
      resolvedObservationIds: List<String>.from(
        jsonDecode(row['observation_ids_json']! as String) as List,
      ),
      formulaIds: List<String>.from(
        jsonDecode(row['formula_ids_json']! as String) as List,
      ),
      assumptions: readMap('assumptions_json'),
      resolvedInputs: readMap('resolved_inputs_json'),
      calculationResult: readMap('result_json'),
      dataCertainty: (row['data_certainty']! as num).toDouble(),
      formulaCertainty: (row['formula_certainty']! as num).toDouble(),
      probabilityCertainty: (row['probability_certainty']! as num).toDouble(),
      createdAt: DateTime.parse(row['created_at']! as String),
    );
  }

  @override
  Future<void> saveEvidence(EvidenceRecord evidence) async {
    if (evidence.checksum != null &&
        await getEvidenceByChecksum(evidence.checksum!) != null) {
      throw StateError('Evidence with this checksum already exists');
    }
    await _db.insert('evidence', {
      'id': evidence.id,
      'type': _evidenceTypeName(evidence.type),
      'reference': evidence.reference,
      'captured_at': evidence.capturedAt?.toIso8601String(),
      'checksum': evidence.checksum,
      'notes': evidence.notes,
      'original_filename': evidence.originalFilename,
      'imported_at': evidence.importedAt?.toIso8601String(),
      'width': evidence.width,
      'height': evidence.height,
      'session_id': evidence.sessionId,
      'parent_evidence_id': evidence.parentEvidenceId,
    });
  }

  @override
  Future<List<EvidenceRecord>> getEvidence() async {
    final rows = await _db.query('evidence', orderBy: 'captured_at DESC');
    return rows.map(_evidenceFromRow).toList(growable: false);
  }

  @override
  Future<void> createVerificationSession(VerificationSession session) async {
    await _db.insert('verification_sessions', {
      'id': session.id,
      'game_update_label': session.gameUpdateLabel,
      'session_date': session.sessionDate.toIso8601String(),
      'world_location': session.worldLocation,
      'check_type': session.checkType,
      'notes': session.notes,
      'official_game_version': session.officialGameVersion,
      'observed_live_at': session.observedLiveAt?.toIso8601String(),
      'created_at': session.createdAt.toIso8601String(),
    });
  }

  @override
  Future<RepositoryIntakeResult> importRepositoryIntake(
    RepositoryIntakeData intake, {
    required Directory evidenceDirectory,
  }) async {
    final datasetId = intake.manifest['datasetId'] as String;
    final manifestHash = sha256
        .convert(utf8.encode(jsonEncode(intake.manifest)))
        .toString();
    final previous = await _db.query(
      'repository_intakes',
      where: 'dataset_id = ?',
      whereArgs: [datasetId],
    );
    if (previous.isNotEmpty) {
      final row = previous.single;
      if (row['manifest_hash'] != manifestHash) {
        throw StateError(
          'Dataset ID already imported with different manifest content',
        );
      }
      return RepositoryIntakeResult(
        imported: false,
        evidenceCount: row['evidence_count']! as int,
        observationCount: row['observation_count']! as int,
        createdOreCount: row['created_ore_count']! as int,
        mergedOreCount: row['merged_ore_count']! as int,
        sessionId: row['session_id']! as String,
      );
    }
    final copiedPaths = <String>[];
    final evidencePaths = <String, String>{};
    final sessionFolder = p.join(
      evidenceDirectory.path,
      'repository-intake',
      datasetId,
    );
    try {
      await Directory(sessionFolder).create(recursive: true);
      for (final item in intake.evidence) {
        final id = item['id']! as String;
        final relative = item['reference']! as String;
        final bytes = intake.evidenceBytes[id]!;
        final existing = await getEvidenceByChecksum(
          item['checksum']! as String,
        );
        if (existing != null)
          throw StateError('Duplicate evidence already exists: ${existing.id}');
        final destination = p.join(sessionFolder, p.basename(relative));
        await File(destination).writeAsBytes(bytes, flush: true);
        copiedPaths.add(destination);
        evidencePaths[id] = destination;
      }
      var createdOres = 0;
      var mergedOres = 0;
      await _db.transaction((txn) async {
        final datasetCollision = await txn.query(
          'repository_intakes',
          where: 'dataset_id = ?',
          whereArgs: [datasetId],
        );
        if (datasetCollision.isNotEmpty)
          throw StateError('Repository intake was imported concurrently');
        final sessionCollision = await txn.query(
          'verification_sessions',
          where: 'id = ?',
          whereArgs: [intake.session.id],
        );
        if (sessionCollision.isNotEmpty)
          throw StateError('Verification session ID already exists');
        for (final source in intake.sources) {
          final id = source['id']! as String;
          final existing = await txn.query(
            'data_sources',
            where: 'id = ?',
            whereArgs: [id],
          );
          if (existing.isNotEmpty &&
              existing.single['source_type'] != source['type']) {
            throw StateError(
              'Source ID $id already exists with a different type',
            );
          }
          await txn.insert('data_sources', {
            'id': id,
            'name': source['name'] ?? id,
            'source_type': source['type'] ?? 'IN_GAME_MANUAL',
            'url': null,
            'license': null,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        await txn.insert('verification_sessions', {
          'id': intake.session.id,
          'game_update_label': intake.session.gameUpdateLabel,
          'official_game_version': intake.session.officialGameVersion,
          'observed_live_at': intake.session.observedLiveAt?.toIso8601String(),
          'session_date': intake.session.sessionDate.toIso8601String(),
          'world_location': intake.session.worldLocation,
          'check_type': intake.session.checkType,
          'notes': intake.session.notes,
          'created_at': intake.session.createdAt.toIso8601String(),
        });
        final entityMap = <String, String>{};
        for (final entity in intake.entities) {
          final id = entity['id']! as String;
          final name = entity['name']! as String;
          var found = await txn.query('ores', where: 'id = ?', whereArgs: [id]);
          if (found.isEmpty) {
            found = await txn.query(
              'ores',
              where: 'lower(name) = lower(?)',
              whereArgs: [name],
            );
          }
          if (found.isNotEmpty) {
            final resolvedId = found.first['id']! as String;
            entityMap[id] = resolvedId;
            mergedOres++;
          } else {
            await txn.insert('ores', {
              'id': id,
              'name': name,
              'rarity': null,
              'multiplier': null,
              'price': null,
              'source': 'Repository in-game intake · pending review',
              'source_url': null,
              'observed_at': intake.session.observedLiveAt?.toIso8601String(),
              'game_version': intake.session.officialGameVersion,
              'confidence': null,
              'verification_status': 'UNKNOWN',
            });
            entityMap[id] = id;
            createdOres++;
          }
        }
        for (final item in intake.evidence) {
          final id = item['id']! as String;
          final checksum = item['checksum']! as String;
          final duplicateId = await txn.query(
            'evidence',
            where: 'id = ?',
            whereArgs: [id],
          );
          final duplicateHash = await txn.query(
            'evidence',
            where: 'checksum = ?',
            whereArgs: [checksum],
          );
          if (duplicateId.isNotEmpty || duplicateHash.isNotEmpty)
            throw StateError('Duplicate evidence ID or checksum: $id');
          await txn.insert('evidence', {
            'id': id,
            'type': 'SCREENSHOT',
            'reference': evidencePaths[id],
            'captured_at': item['capturedAt'],
            'checksum': checksum,
            'notes': item['notes'],
            'original_filename': p.basename(item['reference']! as String),
            'imported_at': DateTime.now().toUtc().toIso8601String(),
            'width': item['width'],
            'height': item['height'],
            'session_id': intake.session.id,
            'parent_evidence_id': null,
          });
        }
        for (final observation in intake.observations) {
          final id = observation['id']! as String;
          final duplicate = await txn.query(
            'observations',
            where: 'id = ?',
            whereArgs: [id],
          );
          if (duplicate.isNotEmpty)
            throw StateError('Duplicate observation ID: $id');
          final evidenceId = observation['evidenceId']! as String;
          await txn.insert('observations', {
            'id': id,
            'entity_type': observation['entityType'],
            'entity_id':
                entityMap[observation['entityId']] ?? observation['entityId'],
            'field_name': observation['fieldName'],
            'value_json': jsonEncode(observation['value']),
            'source_id': observation['sourceId'],
            'observed_at': observation['observedAt'],
            'game_version': intake.session.officialGameVersion,
            'confidence': observation['confidence'],
            'verification_status': 'UNKNOWN',
            'evidence_ref': evidencePaths[evidenceId],
            'evidence_id': evidenceId,
            'review_state': 'ENTERED',
            'verification_session_id': intake.session.id,
            'notes': observation['notes'],
          });
        }
        await txn.insert('repository_intakes', {
          'dataset_id': datasetId,
          'manifest_hash': manifestHash,
          'session_id': intake.session.id,
          'observation_count': intake.observations.length,
          'evidence_count': intake.evidence.length,
          'created_ore_count': createdOres,
          'merged_ore_count': mergedOres,
          'imported_at': DateTime.now().toUtc().toIso8601String(),
        });
      });
      return RepositoryIntakeResult(
        imported: true,
        evidenceCount: intake.evidence.length,
        observationCount: intake.observations.length,
        createdOreCount: createdOres,
        mergedOreCount: mergedOres,
        sessionId: intake.session.id,
      );
    } on Object {
      for (final path in copiedPaths) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
      rethrow;
    }
  }

  @override
  Future<void> updateVerificationSession(VerificationSession session) async {
    final changed = await _db.update(
      'verification_sessions',
      {
        'game_update_label': session.gameUpdateLabel,
        'session_date': session.sessionDate.toIso8601String(),
        'world_location': session.worldLocation,
        'check_type': session.checkType,
        'notes': session.notes,
        'official_game_version': session.officialGameVersion,
        'observed_live_at': session.observedLiveAt?.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [session.id],
    );
    if (changed == 0) throw StateError('Verification session not found');
  }

  @override
  Future<List<VerificationSession>> getVerificationSessions() async {
    final rows = await _db.query(
      'verification_sessions',
      orderBy: 'session_date DESC',
    );
    return rows
        .map(
          (row) => VerificationSession(
            id: row['id']! as String,
            gameUpdateLabel: row['game_update_label']! as String,
            sessionDate: DateTime.parse(row['session_date']! as String),
            worldLocation: row['world_location'] as String?,
            checkType: row['check_type']! as String,
            notes: row['notes'] as String?,
            officialGameVersion: row['official_game_version'] as String?,
            observedLiveAt: row['observed_live_at'] == null
                ? null
                : DateTime.tryParse(row['observed_live_at']! as String),
            createdAt: DateTime.parse(row['created_at']! as String),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> addVerificationTarget(VerificationTarget target) async {
    await _db.insert('verification_targets', {
      'id': target.id,
      'session_id': target.sessionId,
      'entity_type': target.entityType,
      'entity_id': target.entityId,
      'field_name': target.fieldName,
      'priority': target.priority,
      'created_at': target.createdAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<List<VerificationTarget>> getVerificationTargets(
    String sessionId,
  ) async {
    final rows = await _db.query(
      'verification_targets',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'priority ASC, created_at ASC',
    );
    return rows
        .map(
          (row) => VerificationTarget(
            id: row['id']! as String,
            sessionId: row['session_id']! as String,
            entityType: row['entity_type']! as String,
            entityId: row['entity_id']! as String,
            fieldName: row['field_name']! as String,
            priority: row['priority']! as int,
            createdAt: DateTime.parse(row['created_at']! as String),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<FieldObservation>> getVerificationQueue({
    String? reviewState,
  }) async {
    final rows = await _db.query(
      'observations',
      where: reviewState == null
          ? 'verification_session_id IS NOT NULL'
          : 'verification_session_id IS NOT NULL AND review_state = ?',
      whereArgs: reviewState == null ? null : [reviewState],
      orderBy: 'observed_at DESC',
    );
    return rows.map(FieldObservation.fromMap).toList(growable: false);
  }

  @override
  Future<List<FieldObservation>> getSessionObservations(
    String sessionId,
  ) async {
    final rows = await _db.query(
      'observations',
      where: 'verification_session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'observed_at DESC',
    );
    return rows.map(FieldObservation.fromMap).toList(growable: false);
  }

  @override
  Future<EvidenceRecord?> getEvidenceByChecksum(String checksum) async {
    final rows = await _db.query(
      'evidence',
      where: 'checksum = ?',
      whereArgs: [checksum],
      limit: 1,
    );
    return rows.isEmpty ? null : _evidenceFromRow(rows.single);
  }

  @override
  Future<List<EvidenceRecord>> getEvidenceForSession(String sessionId) async {
    final rows = await _db.query(
      'evidence',
      where:
          'session_id = ? OR id IN (SELECT evidence_id FROM observations WHERE verification_session_id = ?)',
      whereArgs: [sessionId, sessionId],
      orderBy: 'imported_at DESC, captured_at DESC',
    );
    return rows.map(_evidenceFromRow).toList(growable: false);
  }

  Future<EvidenceRecord?> _evidenceById(String id) async {
    final rows = await _db.query('evidence', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _evidenceFromRow(rows.single);
  }

  Future<bool> isEvidenceFileIntact(EvidenceRecord evidence) async {
    if (evidence.type != EvidenceType.screenshot || evidence.checksum == null)
      return false;
    final file = File(evidence.reference);
    if (!await file.exists()) return false;
    final actual = sha256.convert(await file.readAsBytes()).toString();
    return actual == evidence.checksum;
  }

  @override
  Future<VerifiedCandidateDiff> buildVerifiedCandidateDiff() async {
    final verifiedRows = await _db.query(
      'observations',
      where: 'review_state = ? AND verification_status = ?',
      whereArgs: ['IN_GAME_VERIFIED', 'IN_GAME_VERIFIED'],
      orderBy: 'observed_at ASC',
    );
    final verified = <FieldObservation>[];
    for (final row in verifiedRows) {
      final item = FieldObservation.fromMap(row);
      final source = await getDataSource(item.sourceId);
      final evidence = item.evidenceId == null
          ? null
          : await _evidenceById(item.evidenceId!);
      final sessions = item.verificationSessionId == null
          ? <Map<String, Object?>>[]
          : await _db.query(
              'verification_sessions',
              where: 'id = ?',
              whereArgs: [item.verificationSessionId],
            );
      if (source?.sourceType == 'IN_GAME_MANUAL' &&
          item.verificationSessionId != null &&
          sessions.isNotEmpty &&
          sessions.single['official_game_version'] == item.gameVersion &&
          (sessions.single['observed_live_at'] ??
                  sessions.single['session_date']) !=
              null &&
          (sessions.single['world_location'] as String? ?? '')
              .trim()
              .isNotEmpty &&
          evidence != null &&
          evidence.sessionId == item.verificationSessionId &&
          await isEvidenceFileIntact(evidence)) {
        verified.add(item);
      }
    }
    final groups = <String, List<FieldObservation>>{};
    for (final item in verified) {
      final key = '${item.entityType}|${item.entityId}|${item.fieldName}';
      groups.putIfAbsent(key, () => []).add(item);
    }
    final added = <String>[];
    final changed = <String>[];
    final conflicts = <String>[];
    final candidateValues = <String, Object?>{};
    for (final entry in groups.entries) {
      final values = entry.value.map((o) => jsonEncode(o.value)).toSet();
      final label =
          '${entry.value.first.entityType} · ${entry.value.first.entityId} · ${entry.value.first.fieldName}';
      if (values.length > 1) {
        conflicts.add(label);
        continue;
      }
      candidateValues[entry.key] = entry.value.first.value;
      final oldRows = await _db.query(
        'observations',
        where:
            'entity_type = ? AND entity_id = ? AND field_name = ? AND verification_status != ?',
        whereArgs: [
          entry.value.first.entityType,
          entry.value.first.entityId,
          entry.value.first.fieldName,
          'IN_GAME_VERIFIED',
        ],
      );
      final oldValues = oldRows
          .map((row) => jsonEncode(jsonDecode(row['value_json']! as String)))
          .toSet();
      if (oldValues.isEmpty) {
        added.add(label);
      } else if (oldValues.any((value) => !values.contains(value))) {
        changed.add(label);
      }
    }
    return VerifiedCandidateDiff(
      candidateValues: Map.unmodifiable(candidateValues),
      added: List.unmodifiable(added),
      changed: List.unmodifiable(changed),
      conflicts: List.unmodifiable(conflicts),
      removed: const [],
    );
  }

  @override
  Future<VerifiedCandidatePack> buildVerifiedCandidatePack() async {
    final diff = await buildVerifiedCandidateDiff();
    final observations = <Map<String, Object?>>[];
    for (final entry in diff.candidateValues.entries) {
      final parts = entry.key.split('|');
      final rows = await _db.query(
        'observations',
        where:
            'entity_type = ? AND entity_id = ? AND field_name = ? AND review_state = ? AND verification_status = ?',
        whereArgs: [...parts, 'IN_GAME_VERIFIED', 'IN_GAME_VERIFIED'],
        orderBy: 'observed_at ASC',
      );
      for (final row in rows) {
        final field = FieldObservation.fromMap(row);
        if (jsonEncode(field.value) != jsonEncode(entry.value)) continue;
        final session = (await _db.query(
          'verification_sessions',
          where: 'id = ?',
          whereArgs: [field.verificationSessionId],
        )).firstOrNull;
        final evidence = field.evidenceId == null
            ? null
            : await _evidenceById(field.evidenceId!);
        observations.add({
          'id': field.id,
          'entityType': field.entityType,
          'entityId': field.entityId,
          'fieldName': field.fieldName,
          'value': field.value,
          'sourceId': field.sourceId,
          'evidenceId': field.evidenceId,
          'evidenceReference': evidence?.reference,
          'evidenceChecksum': evidence?.checksum,
          'observedAt': field.observedAt.toIso8601String(),
          'officialGameVersion': field.gameVersion,
          'location': session?['world_location'],
          'sessionId': field.verificationSessionId,
        });
      }
    }
    return VerifiedCandidatePack(
      schemaVersion: 1,
      sourceDataVersion: await getActiveDataVersion(),
      fieldValues: diff.candidateValues,
      diff: diff,
      verifiedObservations: List.unmodifiable(observations),
    );
  }

  @override
  Future<VerificationMetrics> getVerificationMetrics() async {
    final rows = await _db.query('observations');
    final fields = <String, List<Map<String, Object?>>>{};
    for (final row in rows) {
      final key =
          '${row['entity_type']}|${row['entity_id']}|${row['field_name']}';
      fields.putIfAbsent(key, () => []).add(row);
    }
    final verifiedDomains = <String, int>{};
    final totalDomains = <String, int>{};
    var verified = 0;
    var confirmed = 0;
    var communityOnly = 0;
    var conflicts = 0;
    var pending = 0;
    for (final field in fields.values) {
      final first = field.first;
      final domain = switch (first['entity_type']) {
        'ORE' => 'Ores',
        'WEAPON' || 'WEAPON_VARIANT' || 'WEAPON_CLASS' => 'Weapons',
        'TRAIT' => 'Traits',
        'PROBABILITY' ||
        'PROBABILITY_TABLE' ||
        'CRAFT_RESULT' => 'Probabilities',
        _ => 'Other',
      };
      totalDomains.update(domain, (value) => value + 1, ifAbsent: () => 1);
      final statuses = field
          .map((row) => row['verification_status'] as String)
          .toSet();
      final values = field.map((row) => row['value_json']).toSet();
      final hasGame = statuses.contains('IN_GAME_VERIFIED');
      final hasCapture =
          statuses.contains('USER_CONFIRMED_CAPTURE') ||
          field.any((row) => row['review_state'] == 'USER_CONFIRMED_CAPTURE');
      if (hasGame) {
        verified++;
        verifiedDomains.update(domain, (value) => value + 1, ifAbsent: () => 1);
      } else if (hasCapture) {
        confirmed++;
      } else if (statuses.every(
        (status) =>
            status == 'COMMUNITY' ||
            status == 'GUIDE_BASED' ||
            status == 'GUIDE_LISTED' ||
            status == 'ESTIMATED' ||
            status == 'CONFLICTING',
      )) {
        communityOnly++;
      }
      if (values.length > 1) conflicts++;
      if (field.any(
        (row) =>
            row['review_state'] == 'ENTERED' ||
            row['review_state'] == 'REVIEWED',
      ))
        pending++;
    }
    return VerificationMetrics(
      gameVerified: verified,
      userConfirmed: confirmed,
      communityOnly: communityOnly,
      conflicts: conflicts,
      pendingReview: pending,
      domainVerified: Map.unmodifiable(verifiedDomains),
      domainTotal: Map.unmodifiable(totalDomains),
    );
  }

  @override
  Future<void> updateObservationReviewState(String id, String state) async {
    if (!{'REVIEWED', 'REJECTED'}.contains(state))
      throw ArgumentError.value(state, 'state');
    final rows = await _db.query(
      'observations',
      columns: ['review_state'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) throw StateError('Observation not found');
    final current = rows.single['review_state'] as String? ?? 'ENTERED';
    if (current != 'ENTERED')
      throw StateError('Only ENTERED observations can be reviewed or rejected');
    await _db.update(
      'observations',
      {'review_state': state},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> updateEnteredObservation({
    required String id,
    required Object value,
    String? notes,
  }) async {
    final rows = await _db.query(
      'observations',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) throw StateError('Observation not found');
    if (!{'ENTERED', 'REVIEWED'}.contains(rows.single['review_state'])) {
      throw StateError('Only pending observations can be corrected');
    }
    await _db.update(
      'observations',
      {'value_json': jsonEncode(value), 'notes': notes},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> confirmObservationCapture({
    required String observationId,
    required String evidenceId,
  }) async {
    final rows = await _db.query(
      'observations',
      where: 'id = ?',
      whereArgs: [observationId],
    );
    if (rows.isEmpty) throw StateError('Observation not found');
    if (rows.single['review_state'] != 'REVIEWED')
      throw StateError('Observation must be reviewed first');
    final sessionId = rows.single['verification_session_id'] as String?;
    final evidence = await _evidenceById(evidenceId);
    if (sessionId == null ||
        evidence == null ||
        evidence.type != EvidenceType.screenshot ||
        evidence.sessionId != sessionId ||
        !await isEvidenceFileIntact(evidence)) {
      throw StateError(
        'A locally stored screenshot attached to this session with matching checksum is required',
      );
    }
    if ((await _db.query(
      'verification_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    )).isEmpty) {
      throw StateError('Verification session is missing');
    }
    await _db.update(
      'observations',
      {
        'evidence_id': evidenceId,
        'evidence_ref': evidence.reference,
        'verification_status': 'USER_CONFIRMED_CAPTURE',
        'review_state': 'USER_CONFIRMED_CAPTURE',
      },
      where: 'id = ?',
      whereArgs: [observationId],
    );
  }

  @override
  Future<int> confirmEvidenceCard(String evidenceId) async {
    final evidence = await _evidenceById(evidenceId);
    if (evidence == null ||
        evidence.type != EvidenceType.screenshot ||
        evidence.sessionId == null ||
        !await isEvidenceFileIntact(evidence)) {
      throw StateError('A valid session-bound original screenshot is required');
    }
    final sessionRows = await _db.query(
      'verification_sessions',
      where: 'id = ?',
      whereArgs: [evidence.sessionId],
    );
    if (sessionRows.isEmpty)
      throw StateError('Verification session is missing');
    final session = sessionRows.single;
    if ((session['observed_live_at'] as String?) == null ||
        (session['world_location'] as String? ?? '').trim().isEmpty) {
      throw StateError('A dated live observation and location are required');
    }
    final sourceRows = await _db.query(
      'data_sources',
      where:
          "id = (SELECT source_id FROM observations WHERE evidence_id = ? LIMIT 1)",
      whereArgs: [evidenceId],
    );
    if (sourceRows.isEmpty ||
        sourceRows.first['source_type'] != 'IN_GAME_MANUAL') {
      throw StateError(
        'Evidence is not linked to a manually observed in-game source',
      );
    }
    final rows = await _db.query(
      'observations',
      where: 'evidence_id = ? AND verification_session_id = ?',
      whereArgs: [evidenceId, evidence.sessionId],
    );
    if (rows.isEmpty)
      throw StateError('No observations are linked to this screenshot card');
    if (rows.any(
      (row) =>
          !{'ENTERED', 'REVIEWED'}.contains(row['review_state']) ||
          (row['verification_status'] as String?) == 'REJECTED',
    )) {
      throw StateError(
        'Card contains observations that are not pending review',
      );
    }
    final observationIds = rows.map((row) => row['id'] as String).toList();
    await _db.transaction((txn) async {
      for (final id in observationIds) {
        await txn.update(
          'observations',
          {
            'review_state': 'USER_CONFIRMED_CAPTURE',
            'verification_status': 'USER_CONFIRMED_CAPTURE',
            'evidence_ref': evidence.reference,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
    return rows.length;
  }

  @override
  Future<void> markObservationOutdated(String id) async {
    final rows = await _db.query(
      'observations',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) throw StateError('Observation not found');
    await _db.update(
      'observations',
      {'verification_status': 'OUTDATED'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> confirmObservationAsInGameVerified({
    required String observationId,
    required String? gameVersion,
    required String evidenceId,
  }) async {
    final rows = await _db.query(
      'observations',
      where: 'id = ?',
      whereArgs: [observationId],
    );
    if (rows.isEmpty) throw StateError('Observation not found');
    if ((rows.single['review_state'] as String?) != 'USER_CONFIRMED_CAPTURE') {
      throw StateError(
        'Observation must first be user-confirmed from a screenshot',
      );
    }
    if (rows.single['verification_status'] != 'USER_CONFIRMED_CAPTURE') {
      throw StateError(
        'Capture confirmation must be recorded by the review workflow',
      );
    }
    final sessionId = rows.single['verification_session_id'] as String?;
    if (sessionId == null || rows.single['evidence_id'] != evidenceId) {
      throw StateError(
        'A session-bound screenshot must be explicitly confirmed',
      );
    }
    final sessions = await _db.query(
      'verification_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    if (sessions.isEmpty) throw StateError('Verification session is missing');
    final session = sessions.single;
    final officialVersion = session['official_game_version'] as String?;
    if (officialVersion == null || officialVersion.trim().isEmpty) {
      throw StateError('An official game version is required for verification');
    }
    if (gameVersion != officialVersion) {
      throw StateError('Official game version does not match the session');
    }
    if ((session['world_location'] as String? ?? '').trim().isEmpty ||
        session['session_date'] == null) {
      throw StateError('A dated live observation and location are required');
    }
    final sources = await _db.query(
      'data_sources',
      where: 'id = ?',
      whereArgs: [rows.single['source_id']],
    );
    final evidence = await _db.query(
      'evidence',
      where: 'id = ?',
      whereArgs: [evidenceId],
    );
    if (sources.isEmpty || sources.single['source_type'] != 'IN_GAME_MANUAL')
      throw StateError('In-game confirmation requires IN_GAME_MANUAL source');
    if (evidence.isEmpty ||
        evidence.single['type'] != 'SCREENSHOT' ||
        evidence.single['session_id'] != sessionId)
      throw StateError('Screenshot evidence is required');
    final evidenceRecord = _evidenceFromRow(evidence.single);
    if (!await isEvidenceFileIntact(evidenceRecord))
      throw StateError(
        'Screenshot file is missing or its checksum does not match',
      );
    await _db.update(
      'observations',
      {
        'verification_status': 'IN_GAME_VERIFIED',
        'game_version': officialVersion,
        'evidence_id': evidenceId,
        'review_state': 'IN_GAME_VERIFIED',
      },
      where: 'id = ?',
      whereArgs: [observationId],
    );
  }

  @override
  Future<void> createExperiment(ExperimentRecord experiment) async {
    await _db.insert('experiments', {
      'id': experiment.id,
      'name': experiment.name,
      'craft_type': experiment.craftType,
      'created_at': experiment.createdAt.toIso8601String(),
      'notes': experiment.notes,
    });
  }

  @override
  Future<void> saveExperimentRun(
    ExperimentRunRecord run,
    List<OutcomeCount> outcomes,
  ) async {
    if (run.sampleSize <= 0)
      throw ArgumentError.value(run.sampleSize, 'sampleSize');
    if (outcomes.any((o) => o.count < 0) ||
        outcomes.fold<int>(0, (sum, item) => sum + item.count) > run.sampleSize)
      throw ArgumentError('Outcome counts exceed valid sample size');
    await _db.transaction((txn) async {
      await txn.insert('experiment_runs', {
        'id': run.id,
        'experiment_id': run.experimentId,
        'sample_size': run.sampleSize,
        'recipe_json': jsonEncode(run.recipe),
        'created_at': run.createdAt.toIso8601String(),
        'game_version': run.gameVersion,
        'notes': run.notes,
      });
      for (final outcome in outcomes) {
        await txn.insert('experiment_outcomes', {
          'run_id': run.id,
          'result_id': outcome.resultId,
          'count': outcome.count,
        });
      }
    });
  }

  @override
  Future<ExperimentSummary?> getExperimentSummary(String runId) async {
    final runs = await _db.query(
      'experiment_runs',
      where: 'id = ?',
      whereArgs: [runId],
    );
    if (runs.isEmpty) return null;
    final rows = await _db.query(
      'experiment_outcomes',
      where: 'run_id = ?',
      whereArgs: [runId],
    );
    final count = rows.fold<int>(0, (sum, row) => sum + (row['count']! as int));
    return ExperimentSummary(
      sampleSize: count,
      outcomes: Map.unmodifiable({
        for (final row in rows)
          row['result_id']! as String: row['count']! as int,
      }),
      isEvidenceOnly: true,
      message: count < 100
          ? 'Observation only ($count outcomes); not proof of probability.'
          : 'Observed frequencies only; not verified game probabilities.',
    );
  }

  Future<void> close() => _db.close();
}

String _evidenceTypeName(EvidenceType type) => switch (type) {
  EvidenceType.screenshot => 'SCREENSHOT',
  EvidenceType.manualTranscription => 'MANUAL_TRANSCRIPTION',
  EvidenceType.webSource => 'WEB_SOURCE',
  EvidenceType.datasetReference => 'DATASET_REFERENCE',
  EvidenceType.experiment => 'EXPERIMENT',
};

EvidenceRecord _evidenceFromRow(Map<String, Object?> row) => EvidenceRecord(
  id: row['id']! as String,
  type: EvidenceType.values.firstWhere(
    (type) => _evidenceTypeName(type) == row['type'],
    orElse: () => EvidenceType.datasetReference,
  ),
  reference: row['reference']! as String,
  capturedAt: row['captured_at'] == null
      ? null
      : DateTime.tryParse(row['captured_at']! as String),
  checksum: row['checksum'] as String?,
  notes: row['notes'] as String?,
  originalFilename: row['original_filename'] as String?,
  importedAt: row['imported_at'] == null
      ? null
      : DateTime.tryParse(row['imported_at']! as String),
  width: row['width'] as int?,
  height: row['height'] as int?,
  sessionId: row['session_id'] as String?,
  parentEvidenceId: row['parent_evidence_id'] as String?,
);

double? _numberFromObservation(Object? value) =>
    value is num ? value.toDouble() : null;

Future<void> _createMilestoneTables(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS data_packs (
      pack_id TEXT PRIMARY KEY,
      schema_version INTEGER NOT NULL,
      data_version TEXT NOT NULL UNIQUE,
      created_at TEXT NOT NULL,
      game_version TEXT,
      game_update_label TEXT,
      ruleset_version TEXT NOT NULL,
      manifest_json TEXT NOT NULL,
      active INTEGER NOT NULL DEFAULT 0 CHECK(active IN (0, 1))
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS pack_ores (
      pack_id TEXT NOT NULL REFERENCES data_packs(pack_id),
      ore_id TEXT NOT NULL,
      name TEXT NOT NULL,
      multiplier REAL,
      verification_status TEXT NOT NULL,
      payload_json TEXT NOT NULL,
      PRIMARY KEY(pack_id, ore_id)
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS pack_weapon_classes (
      pack_id TEXT NOT NULL REFERENCES data_packs(pack_id),
      class_id TEXT NOT NULL,
      name TEXT NOT NULL,
      forge_available INTEGER NOT NULL,
      verification_status TEXT NOT NULL,
      payload_json TEXT NOT NULL,
      PRIMARY KEY(pack_id, class_id)
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS pack_weapon_variants (
      pack_id TEXT NOT NULL REFERENCES data_packs(pack_id),
      variant_id TEXT NOT NULL,
      class_id TEXT NOT NULL,
      name TEXT NOT NULL,
      base_damage REAL,
      attack_interval REAL,
      range_value REAL,
      variant_weight REAL,
      verification_status TEXT NOT NULL,
      payload_json TEXT NOT NULL,
      PRIMARY KEY(pack_id, variant_id),
      FOREIGN KEY(pack_id, class_id) REFERENCES pack_weapon_classes(pack_id, class_id)
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS pack_traits (
      pack_id TEXT NOT NULL REFERENCES data_packs(pack_id),
      trait_id TEXT NOT NULL,
      ore_id TEXT NOT NULL,
      name TEXT NOT NULL,
      payload_json TEXT NOT NULL,
      PRIMARY KEY(pack_id, trait_id)
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS pack_probability_tables (
      pack_id TEXT NOT NULL REFERENCES data_packs(pack_id),
      table_id TEXT NOT NULL,
      craft_type TEXT NOT NULL,
      total_ores INTEGER NOT NULL,
      raw_sum REAL NOT NULL,
      validation_status TEXT NOT NULL,
      verification_status TEXT NOT NULL,
      source_id TEXT,
      game_context TEXT,
      notes TEXT,
      payload_json TEXT NOT NULL,
      PRIMARY KEY(pack_id, table_id)
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS pack_probability_entries (
      pack_id TEXT NOT NULL,
      table_id TEXT NOT NULL,
      result_id TEXT NOT NULL,
      probability REAL NOT NULL,
      PRIMARY KEY(pack_id, table_id, result_id),
      FOREIGN KEY(pack_id, table_id) REFERENCES pack_probability_tables(pack_id, table_id)
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS evidence (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      reference TEXT NOT NULL,
      captured_at TEXT,
      checksum TEXT,
      notes TEXT,
      original_filename TEXT,
      imported_at TEXT,
      width INTEGER,
      height INTEGER,
      session_id TEXT,
      parent_evidence_id TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS pack_observations (
      pack_id TEXT NOT NULL REFERENCES data_packs(pack_id),
      observation_id TEXT NOT NULL,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      field_name TEXT NOT NULL,
      value_json TEXT,
      source_id TEXT,
      observed_at TEXT NOT NULL,
      game_version TEXT,
      confidence REAL,
      verification_status TEXT NOT NULL,
      evidence_id TEXT REFERENCES evidence(id),
      notes TEXT,
      PRIMARY KEY(pack_id, observation_id)
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS calculation_snapshots (
      id TEXT PRIMARY KEY,
      catalog_version TEXT NOT NULL,
      ruleset_version TEXT NOT NULL,
      recipe_json TEXT NOT NULL,
      observation_ids_json TEXT NOT NULL,
      formula_ids_json TEXT NOT NULL,
      assumptions_json TEXT NOT NULL,
      resolved_inputs_json TEXT NOT NULL,
      result_json TEXT NOT NULL,
      data_certainty REAL NOT NULL,
      formula_certainty REAL NOT NULL,
      probability_certainty REAL NOT NULL,
      created_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS experiments (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      craft_type TEXT NOT NULL,
      created_at TEXT NOT NULL,
      notes TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS experiment_runs (
      id TEXT PRIMARY KEY,
      experiment_id TEXT NOT NULL REFERENCES experiments(id) ON DELETE CASCADE,
      sample_size INTEGER NOT NULL CHECK(sample_size > 0),
      recipe_json TEXT NOT NULL,
      created_at TEXT NOT NULL,
      game_version TEXT,
      notes TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS experiment_outcomes (
      run_id TEXT NOT NULL REFERENCES experiment_runs(id) ON DELETE CASCADE,
      result_id TEXT NOT NULL,
      count INTEGER NOT NULL CHECK(count >= 0),
      PRIMARY KEY(run_id, result_id)
    )
  ''');
}

Future<void> _createVerificationTables(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS verification_sessions (
      id TEXT PRIMARY KEY,
      game_update_label TEXT NOT NULL,
      session_date TEXT NOT NULL,
      world_location TEXT,
      check_type TEXT NOT NULL,
      notes TEXT,
      created_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS verification_targets (
      id TEXT PRIMARY KEY,
      session_id TEXT NOT NULL REFERENCES verification_sessions(id) ON DELETE CASCADE,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      field_name TEXT NOT NULL,
      priority INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      UNIQUE(session_id, entity_type, entity_id, field_name)
    )
  ''');
  await db.execute('''
    CREATE INDEX IF NOT EXISTS evidence_checksum_lookup
    ON evidence(checksum) WHERE checksum IS NOT NULL
  ''');
  await _createRepositoryIntakeTable(db);
}

Future<void> _createRepositoryIntakeTable(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS repository_intakes (
      dataset_id TEXT PRIMARY KEY,
      manifest_hash TEXT NOT NULL,
      session_id TEXT NOT NULL,
      observation_count INTEGER NOT NULL,
      evidence_count INTEGER NOT NULL,
      created_ore_count INTEGER NOT NULL,
      merged_ore_count INTEGER NOT NULL,
      imported_at TEXT NOT NULL
    )
  ''');
}
