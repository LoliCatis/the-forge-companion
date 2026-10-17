import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:game_data/game_data.dart';

ValidatedDataPack makePack({
  required String id,
  required String version,
  required double multiplier,
  bool invalidTrait = false,
  bool conflictingWeaponStats = false,
  double? baseDamage,
  DateTime? observedAt,
}) {
  final contents = <String, Object>{
    'sources.json': [
      {
        'id': 'community',
        'name': 'Community fixture',
        'type': 'COMMUNITY',
        'verificationStatus': 'COMMUNITY',
        'url': 'https://example.invalid/source',
      },
    ],
    'ores.json': [
      {
        'id': 'test-ore',
        'name': 'Test Ore',
        'multiplier': multiplier,
        'sourceId': 'community',
        'verificationStatus': 'COMMUNITY',
        'confidence': .4,
      },
    ],
    'weapons.json': {
      'classes': [
        {
          'id': 'test-weapon',
          'name': 'Test Weapon',
          'forgeAvailable': true,
          'verificationStatus': 'COMMUNITY',
        },
      ],
      'variants': [
        {
          'id': 'test-weapon-basic',
          'name': 'Test Weapon',
          'classId': 'test-weapon',
          'baseDamage': baseDamage,
          'attackIntervalSeconds': null,
          'range': null,
          'variantWeight': 1,
          'sourceId': 'community',
          'verificationStatus': 'COMMUNITY',
          'confidence': .4,
        },
      ],
    },
    'traits.json': invalidTrait
        ? [
            {
              'id': 'bad-trait',
              'name': 'Bad trait',
              'oreId': 'missing-ore',
              'verificationStatus': 'UNKNOWN',
            },
          ]
        : <Object>[],
    'probabilities.json': [
      {
        'id': 'test-weapon-at-3',
        'craftType': 'WEAPON_CLASS',
        'totalOres': 3,
        'entries': [
          {'resultId': 'test-weapon', 'probability': 1.0},
        ],
        'expectedResults': ['test-weapon'],
        'sourceId': 'community',
        'verificationStatus': 'COMMUNITY',
        'gameContext': 'test context',
        'notes': 'test probability fixture',
      },
    ],
    'evidence.json': <Object>[],
    'observations.json': [
      {
        'id': 'test-ore-multiplier',
        'entityType': 'ORE',
        'entityId': 'test-ore',
        'fieldName': 'multiplier',
        'value': multiplier,
        'sourceId': 'community',
        'observedAt': (observedAt ?? DateTime.utc(2026, 10, 15))
            .toIso8601String(),
        'verificationStatus': 'COMMUNITY',
        'confidence': .4,
      },
      if (conflictingWeaponStats) ...[
        {
          'id': 'test-weapon-damage-community-a',
          'entityType': 'WEAPON_VARIANT',
          'entityId': 'test-weapon-basic',
          'fieldName': 'base_damage',
          'value': 12.3,
          'sourceId': 'community',
          'observedAt': '2026-10-15T00:00:00Z',
          'verificationStatus': 'COMMUNITY',
          'confidence': .4,
        },
        {
          'id': 'test-weapon-damage-community-b',
          'entityType': 'WEAPON_VARIANT',
          'entityId': 'test-weapon-basic',
          'fieldName': 'base_damage',
          'value': 14.5,
          'sourceId': 'community',
          'observedAt': '2026-10-15T00:00:00Z',
          'verificationStatus': 'COMMUNITY',
          'confidence': .3,
        },
      ],
    ],
  };
  final files = <String, String>{
    for (final entry in contents.entries)
      entry.key: '${jsonEncode(entry.value)}\n',
  };
  final hashes = {
    for (final entry in files.entries)
      entry.key: sha256.convert(utf8.encode(entry.value)).toString(),
  };
  files['manifest.json'] =
      '${jsonEncode({
        'packId': id,
        'schemaVersion': 1,
        'dataVersion': version,
        'createdAt': '2026-10-15T00:00:00Z',
        'gameVersion': null,
        'gameUpdateLabel': 'Unknown',
        'rulesetVersion': 'rules-test-v1',
        'sources': ['community'],
        'contentHashes': hashes,
        'notes': 'test fixture',
      })}\n';
  return DataPackBundle(files).validate();
}
