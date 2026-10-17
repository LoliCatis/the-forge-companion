import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:archive/archive.dart';
import 'package:game_data/game_data.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import 'data_pack_test_utils.dart';

void main() {
  late GameDatabase database;

  setUp(() async {
    database = await GameDatabase.open(':memory:');
  });

  tearDown(() => database.close());

  test(
    'imports data pack transactionally and exposes active versioned records',
    () async {
      final pack = makePack(id: 'pack-v1', version: 'v1', multiplier: 2);
      await database.importDataPack(pack);
      expect(await database.getActiveDataVersion(), 'v1');
      expect(await database.getActiveRulesetVersion(), 'rules-test-v1');
      expect((await database.getWeaponClasses()).single.id, 'test-weapon');
      final weapon = (await database.getWeaponVariants()).single;
      expect(weapon.baseDamage, isNull);
      expect(weapon.attackIntervalSeconds, isNull);
      expect(weapon.verificationStatus, 'COMMUNITY');
      final probabilities = await database.getProbabilityTable('test-weapon-at-3');
      expect(probabilities?.status, 'VALID');
      expect(probabilities?.sourceSum, 1);
      expect(probabilities?.verificationStatus, 'COMMUNITY');
    },
  );

  test(
    'rolls back all imported rows when pack references an invalid entity',
    () async {
      final pack = makePack(
        id: 'invalid-pack',
        version: 'invalid-v1',
        multiplier: 2,
        invalidTrait: true,
      );
      await expectLater(database.importDataPack(pack), throwsStateError);
      expect(await database.getActiveDataVersion(), isNull);
      expect(await database.countAllOres(), 0);
      expect(await database.getWeaponClasses(), isEmpty);
    },
  );

  test(
    'weapon stat conflicts remain separate and unresolved on import',
    () async {
      await database.importDataPack(
        makePack(
          id: 'weapon-conflict-pack',
          version: 'weapon-conflict-v1',
          multiplier: 2,
          baseDamage: 12.3,
          conflictingWeaponStats: true,
        ),
      );
      final weapon = (await database.getWeaponVariants()).single;
      expect(weapon.baseDamage, isNull);
      expect(weapon.verificationStatus, 'CONFLICTING');
      final observations = await database.getObservations(
        entityType: 'WEAPON_VARIANT',
        entityId: 'test-weapon-basic',
        fieldName: 'base_damage',
      );
      expect(observations.map((item) => item.value).toSet(), {12.3, 14.5});
      expect(observations, hasLength(2));
    },
  );

  test(
    'old calculation snapshot remains reproducible after a new pack install',
    () async {
      await database.importDataPack(
        makePack(id: 'pack-v1', version: 'v1', multiplier: 2),
      );
      final snapshot = CalculationSnapshot(
        id: 'snapshot-v1',
        catalogVersion: (await database.getActiveDataVersion())!,
        rulesetVersion: (await database.getActiveRulesetVersion())!,
        recipe: const {'test-ore': 3},
        resolvedObservationIds: const ['pack-v1:test-ore-multiplier'],
        formulaIds: const ['ore.weighted-average.v1'],
        assumptions: const {'qualityMultiplier': 1.0},
        resolvedInputs: const {'stoneMultiplier': 2.0, 'baseDamage': 12.3},
        calculationResult: const {
          'projectedDamage': 8.6,
          'rawDps': 18.29787234042553,
        },
        dataCertainty: .4,
        formulaCertainty: .7,
        probabilityCertainty: .5,
        createdAt: DateTime.utc(2026, 10, 15),
      );
      await database.saveCalculationSnapshot(snapshot);
      await database.importDataPack(
        makePack(
          id: 'pack-v2',
          version: 'v2',
          multiplier: 4,
          observedAt: DateTime.utc(2026, 10, 17),
        ),
      );

      final restored = await database.getCalculationSnapshot('snapshot-v1');
      expect(await database.getActiveDataVersion(), 'v2');
      expect((await database.searchOres('Test Ore')).single.multiplier, 4);
      expect(restored?.catalogVersion, 'v1');
      expect(restored?.rulesetVersion, 'rules-test-v1');
      expect(restored?.resolvedInputs['stoneMultiplier'], 2);
      expect(restored?.calculationResult['projectedDamage'], 8.6);
    },
  );

  test(
    'manual observation follows entered, reviewed, capture-confirmed then game-verified policy',
    () async {
      final temp = await Directory.systemTemp.createTemp('forge-evidence-test');
      addTearDown(() => temp.delete(recursive: true));
      final now = DateTime.now().toUtc();
      final session = VerificationSession(
        id: 'session-a',
        gameUpdateLabel: 'Update 2026-10',
        officialGameVersion: 'Update 2026-10',
        sessionDate: DateTime.utc(2026, 10, 15),
        observedLiveAt: DateTime.utc(2026, 10, 15),
        worldLocation: 'Test location',
        checkType: 'Weapon',
        createdAt: now,
      );
      await database.createVerificationSession(session);
      final png = img.encodePng(img.Image(width: 8, height: 6));
      final vault = EvidenceVault(rootDirectory: temp, database: database);
      final imported = await vault.importScreenshot(
        bytes: png,
        originalFilename: 'index.png',
        sessionId: session.id,
        gameUpdateLabel: session.gameUpdateLabel,
      );
      expect(imported.checksum, sha256.convert(png).toString());
      expect(imported.width, 8);
      expect(imported.height, 6);
      expect(await File(imported.reference).exists(), isTrue);
      await expectLater(
        vault.importScreenshot(
          bytes: png,
          originalFilename: 'duplicate.png',
          sessionId: session.id,
        ),
        throwsA(isA<DuplicateEvidenceException>()),
      );
      final crop = await vault.createCrop(
        original: imported,
        x: 1,
        y: 1,
        width: 3,
        height: 2,
        label: 'damage-value',
      );
      expect(crop.parentEvidenceId, imported.id);
      expect(crop.width, 3);
      expect(crop.height, 2);
      await database.upsertDataSource(
        const DataSourceRecord(
          id: 'manual-game',
          name: 'In-game manual check',
          sourceType: 'IN_GAME_MANUAL',
        ),
      );
      await expectLater(
        database.addObservation(
          FieldObservation(
            id: 'forged-confirmation',
            entityType: 'WEAPON_VARIANT',
            entityId: 'test-weapon-basic',
            fieldName: 'base_damage',
            value: 12.3,
            sourceId: 'manual-game',
            observedAt: session.sessionDate,
            verificationStatus: 'USER_CONFIRMED_CAPTURE',
            reviewState: 'USER_CONFIRMED_CAPTURE',
            verificationSessionId: session.id,
          ),
        ),
        throwsStateError,
      );
      final observation = FieldObservation(
        id: 'manual-obs',
        entityType: 'WEAPON_VARIANT',
        entityId: 'test-weapon-basic',
        fieldName: 'base_damage',
        value: 12.3,
        sourceId: 'manual-game',
        observedAt: session.sessionDate,
        verificationStatus: 'UNKNOWN',
        evidenceId: imported.id,
        evidenceReference: imported.reference,
        gameVersion: 'Update 2026-10',
        verificationSessionId: session.id,
      );
      await database.addObservation(observation);
      await expectLater(
        database.confirmObservationAsInGameVerified(
          observationId: observation.id,
          gameVersion: 'Update 2026-10',
          evidenceId: imported.id,
        ),
        throwsStateError,
      );
      await database.updateObservationReviewState(observation.id, 'REVIEWED');
      await expectLater(
        database.updateObservationReviewState(observation.id, 'REJECTED'),
        throwsStateError,
      );
      await expectLater(
        database.confirmObservationAsInGameVerified(
          observationId: observation.id,
          gameVersion: 'Update 2026-10',
          evidenceId: imported.id,
        ),
        throwsStateError,
      );
      await database.confirmObservationCapture(
        observationId: observation.id,
        evidenceId: imported.id,
      );
      var resolved = await database.resolveField(
        entityType: 'WEAPON_VARIANT',
        entityId: 'test-weapon-basic',
        fieldName: 'base_damage',
      );
      expect(resolved.preferred?.verificationStatus, 'USER_CONFIRMED_CAPTURE');
      expect(resolved.preferred?.reviewState, 'USER_CONFIRMED_CAPTURE');
      await database.confirmObservationAsInGameVerified(
        observationId: observation.id,
        gameVersion: 'Update 2026-10',
        evidenceId: imported.id,
      );
      resolved = await database.resolveField(
        entityType: 'WEAPON_VARIANT',
        entityId: 'test-weapon-basic',
        fieldName: 'base_damage',
      );
      expect(resolved.preferred?.verificationStatus, 'IN_GAME_VERIFIED');
      expect(resolved.preferred?.evidenceId, imported.id);
      expect(resolved.preferred?.reviewState, 'IN_GAME_VERIFIED');
      final candidate = await database.buildVerifiedCandidatePack();
      expect(
        candidate.diff.added,
        contains('WEAPON_VARIANT · test-weapon-basic · base_damage'),
      );
      expect(
        candidate.fieldValues['WEAPON_VARIANT|test-weapon-basic|base_damage'],
        12.3,
      );
      expect(candidate.schemaVersion, 1);
    },
  );

  test(
    'missing or corrupted local screenshot cannot promote a capture',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'forge-missing-evidence',
      );
      addTearDown(() => temp.delete(recursive: true));
      final now = DateTime.now().toUtc();
      await database.createVerificationSession(
        VerificationSession(
          id: 's',
          gameUpdateLabel: 'Patch 1',
          sessionDate: now,
          checkType: 'Ore',
          createdAt: now,
        ),
      );
      await database.upsertDataSource(
        const DataSourceRecord(
          id: 'manual-game',
          name: 'Manual',
          sourceType: 'IN_GAME_MANUAL',
        ),
      );
      final imageBytes = img.encodePng(img.Image(width: 2, height: 2));
      final evidence =
          await EvidenceVault(
            rootDirectory: temp,
            database: database,
          ).importScreenshot(
            bytes: imageBytes,
            originalFilename: 'ore.png',
            sessionId: 's',
          );
      final observation = FieldObservation(
        id: 'o',
        entityType: 'ORE',
        entityId: 'test-ore',
        fieldName: 'multiplier',
        value: 7.25,
        sourceId: 'manual-game',
        observedAt: now,
        gameVersion: 'Patch 1',
        verificationStatus: 'UNKNOWN',
        evidenceId: evidence.id,
        verificationSessionId: 's',
      );
      await database.addObservation(observation);
      await database.updateObservationReviewState('o', 'REVIEWED');
      await database.confirmObservationCapture(
        observationId: 'o',
        evidenceId: evidence.id,
      );
      final corrupted = Uint8List.fromList(imageBytes)
        ..[imageBytes.length - 1] ^= 0x01;
      await File(evidence.reference).writeAsBytes(corrupted, flush: true);
      expect(await database.isEvidenceFileIntact(evidence), isFalse);
      await expectLater(
        database.confirmObservationAsInGameVerified(
          observationId: 'o',
          gameVersion: 'Patch 1',
          evidenceId: evidence.id,
        ),
        throwsStateError,
      );
      await File(evidence.reference).delete();
      expect(await database.isEvidenceFileIntact(evidence), isFalse);
      await expectLater(
        database.confirmObservationAsInGameVerified(
          observationId: 'o',
          gameVersion: 'Patch 1',
          evidenceId: evidence.id,
        ),
        throwsStateError,
      );
    },
  );

  test(
    'verification bundle validates manifest and rejects a damaged artifact',
    () async {
      final temp = await Directory.systemTemp.createTemp('forge-bundle-test');
      addTearDown(() => temp.delete(recursive: true));
      final now = DateTime.now().toUtc();
      await database.createVerificationSession(
        VerificationSession(
          id: 'bundle-session',
          gameUpdateLabel: 'Patch 2',
          sessionDate: now,
          checkType: 'Ore',
          createdAt: now,
        ),
      );
      final screenshot = img.encodePng(img.Image(width: 2, height: 2));
      await EvidenceVault(
        rootDirectory: temp,
        database: database,
      ).importScreenshot(
        bytes: screenshot,
        originalFilename: 'sample.png',
        sessionId: 'bundle-session',
      );
      final bytes = await VerificationBundleService(
        database,
      ).exportSession('bundle-session');
      final valid = VerificationBundleService.validate(bytes);
      expect(valid.manifest['schemaVersion'], 1);
      expect(
        valid.files.keys,
        contains(
          'evidence/${(await database.getEvidenceForSession('bundle-session')).single.id}.png',
        ),
      );
      final archive = ZipDecoder().decodeBytes(bytes);
      final changedArchive = Archive();
      for (final file in archive.files) {
        final contents = Uint8List.fromList(file.content as List<int>);
        if (file.name.startsWith('evidence/') && !file.name.endsWith('.json')) {
          contents[0] ^= 0x01;
        }
        changedArchive.addFile(
          ArchiveFile(file.name, contents.length, contents),
        );
      }
      final damaged = Uint8List.fromList(ZipEncoder().encode(changedArchive));
      await expectLater(
        () async => VerificationBundleService.validate(damaged),
        throwsA(isA<InvalidVerificationBundle>()),
      );
      final payloads = <String, Uint8List>{};
      for (final file in archive.files) {
        payloads[file.name] = Uint8List.fromList(file.content as List<int>);
      }
      final manifest =
          jsonDecode(utf8.decode(payloads['manifest.json']!))
              as Map<String, dynamic>;
      final evidenceMetadata =
          jsonDecode(utf8.decode(payloads['evidence.json']!)) as List<dynamic>;
      evidenceMetadata.single['checksum'] = List.filled(64, '0').join();
      payloads['evidence.json'] = Uint8List.fromList(
        utf8.encode(jsonEncode(evidenceMetadata)),
      );
      (manifest['files'] as Map<String, dynamic>)['evidence.json'] = sha256
          .convert(payloads['evidence.json']!)
          .toString();
      payloads['manifest.json'] = Uint8List.fromList(
        utf8.encode(jsonEncode(manifest)),
      );
      final metadataArchive = Archive();
      for (final entry in payloads.entries) {
        metadataArchive.addFile(
          ArchiveFile(entry.key, entry.value.length, entry.value),
        );
      }
      await expectLater(
        () async => VerificationBundleService.validate(
          Uint8List.fromList(ZipEncoder().encode(metadataArchive)),
        ),
        throwsA(isA<InvalidVerificationBundle>()),
      );
    },
  );

  test('small experiment remains observation only', () async {
    await database.createExperiment(
      ExperimentRecord(
        id: 'exp',
        name: 'Three-ore craft check',
        craftType: 'WEAPON',
        createdAt: DateTime.utc(2026, 10, 15),
      ),
    );
    await database.saveExperimentRun(
      ExperimentRunRecord(
        id: 'run',
        experimentId: 'exp',
        sampleSize: 10,
        recipe: const {'test-ore': 3},
        createdAt: DateTime.utc(2026, 10, 15),
      ),
      const [OutcomeCount(resultId: 'test-weapon', count: 7)],
    );
    final summary = await database.getExperimentSummary('run');
    expect(summary?.isEvidenceOnly, isTrue);
    expect(summary?.message, contains('not proof'));
    expect(summary?.outcomes['test-weapon'], 7);
  });
}
