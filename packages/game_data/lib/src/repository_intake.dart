import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'game_data_store.dart';
import 'models.dart';

class InvalidRepositoryIntake implements Exception {
  const InvalidRepositoryIntake(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Validates a staged `data/verification/<location>/<date>` directory before
/// handing its records to the database's all-or-nothing import transaction.
class RepositoryIntakeImporter {
  const RepositoryIntakeImporter(this.database);
  final GameDataStore database;

  Future<RepositoryIntakeResult> importDirectory(
    Directory directory, {
    required Directory evidenceDirectory,
  }) async {
    final intake = await validateDirectory(directory);
    return database.importRepositoryIntake(
      intake,
      evidenceDirectory: evidenceDirectory,
    );
  }

  static Future<RepositoryIntakeData> validateDirectory(
    Directory directory,
  ) async {
    if (!await directory.exists()) {
      throw const InvalidRepositoryIntake('Intake directory does not exist');
    }
    final root = p.normalize(await directory.resolveSymbolicLinks());
    final files = <String, Uint8List>{};
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (await Link(entity.path).exists()) {
        throw const InvalidRepositoryIntake(
          'Symlinks are not allowed in intake',
        );
      }
      if (entity is! File) continue;
      final relative = p
          .relative(entity.path, from: directory.path)
          .replaceAll('\\', '/');
      _validateRelativePath(relative);
      final actual = p.normalize(await entity.resolveSymbolicLinks());
      if (!p.isWithin(root, actual)) {
        throw InvalidRepositoryIntake(
          'Intake file escapes its root: $relative',
        );
      }
      files[relative] = await entity.readAsBytes();
    }
    Map<String, Object?> jsonMap(String name) {
      final bytes = files[name];
      if (bytes == null) throw InvalidRepositoryIntake('$name is missing');
      try {
        return jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
      } on Object {
        throw InvalidRepositoryIntake('$name is invalid JSON');
      }
    }

    final manifest = jsonMap('manifest.json');
    if (manifest['format'] != 'the-forge-companion-verification-intake' ||
        manifest['schemaVersion'] != 1) {
      throw const InvalidRepositoryIntake('Unsupported intake schemaVersion');
    }
    final declared = manifest['contentHashes'];
    if (declared is! Map<String, dynamic>) {
      throw const InvalidRepositoryIntake('Manifest contentHashes is missing');
    }
    final payloads = files.keys
        .where((path) => path != 'manifest.json')
        .toSet();
    if (payloads.length != declared.length ||
        !payloads.containsAll(declared.keys)) {
      throw const InvalidRepositoryIntake(
        'Manifest does not cover the exact intake file set',
      );
    }
    for (final entry in declared.entries) {
      _validateRelativePath(entry.key);
      final bytes = files[entry.key];
      if (bytes == null || sha256.convert(bytes).toString() != entry.value) {
        throw InvalidRepositoryIntake(
          'Manifest hash mismatch or missing file: ${entry.key}',
        );
      }
    }
    final checksumLines = utf8
        .decode(files['SHA256SUMS.csv'] ?? Uint8List(0))
        .trim()
        .split('\n');
    if (checksumLines.isEmpty ||
        checksumLines.first.replaceAll('"', '') != 'file,sha256') {
      throw const InvalidRepositoryIntake(
        'SHA256SUMS.csv has an invalid header',
      );
    }
    final listedEvidence = <String, String>{};
    for (final line in checksumLines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final columns = line
          .split(',')
          .map((part) => part.trim().replaceAll('"', ''))
          .toList();
      if (columns.length != 2)
        throw const InvalidRepositoryIntake('Invalid SHA256SUMS.csv row');
      _validateRelativePath(columns[0]);
      if (listedEvidence.containsKey(columns[0]))
        throw InvalidRepositoryIntake('Duplicate checksum path: ${columns[0]}');
      listedEvidence[columns[0]] = columns[1];
    }
    final evidenceRows = _jsonList(files, 'evidence.json');
    final sources = _jsonList(files, 'sources.json');
    final entities = _jsonList(files, 'entities.json');
    final observations = _jsonList(files, 'observations.json');
    final sourceIds = _uniqueIds(sources, 'source');
    final entityIds = _uniqueIds(entities, 'entity');
    final evidenceIds = _uniqueIds(evidenceRows, 'evidence');
    _uniqueIds(observations, 'observation');
    final sessionJson = jsonMap('session.json');
    final sessionId = manifest['sessionId'];
    if (sessionId is! String || sessionJson['id'] != sessionId) {
      throw const InvalidRepositoryIntake('Manifest/session ID mismatch');
    }
    if (sessionJson['sourceId'] is String &&
        !sourceIds.contains(sessionJson['sourceId'])) {
      throw const InvalidRepositoryIntake(
        'Session references an unknown source ID',
      );
    }
    final evidenceBytes = <String, Uint8List>{};
    final checksumByPath = <String, String>{};
    for (final row in evidenceRows) {
      final id = row['id'] as String;
      final path = row['reference'] as String?;
      if (path == null)
        throw InvalidRepositoryIntake('Evidence $id has no relative path');
      _validateRelativePath(path);
      final bytes = files[path];
      if (bytes == null)
        throw InvalidRepositoryIntake('Evidence file is missing: $path');
      final actualHash = sha256.convert(bytes).toString();
      if (actualHash != row['checksum'] ||
          actualHash != listedEvidence[path] ||
          actualHash != declared[path]) {
        throw InvalidRepositoryIntake('Evidence checksum mismatch: $path');
      }
      if (row['type'] != 'SCREENSHOT' || row['sessionId'] != sessionId) {
        throw InvalidRepositoryIntake(
          'Evidence $id is not a session-bound screenshot',
        );
      }
      if (checksumByPath.values.contains(actualHash)) {
        throw InvalidRepositoryIntake(
          'Duplicate evidence checksum: $actualHash',
        );
      }
      checksumByPath[path] = actualHash;
      evidenceBytes[id] = bytes;
    }
    if (listedEvidence.length != evidenceRows.length ||
        !listedEvidence.keys.toSet().containsAll(
          evidenceRows.map((e) => e['reference']),
        )) {
      throw const InvalidRepositoryIntake(
        'Checksum list and evidence metadata differ',
      );
    }
    for (final row in observations) {
      if (!entityIds.contains(row['entityId'])) {
        throw InvalidRepositoryIntake(
          'Observation ${row['id']} references unknown entity ${row['entityId']}',
        );
      }
      if (!sourceIds.contains(row['sourceId'])) {
        throw InvalidRepositoryIntake(
          'Observation ${row['id']} references unknown source ${row['sourceId']}',
        );
      }
      final evidenceId = row['evidenceId'];
      if (!evidenceIds.contains(evidenceId) || row['sessionId'] != sessionId) {
        throw InvalidRepositoryIntake(
          'Observation ${row['id']} has invalid evidence/session binding',
        );
      }
      if (row['reviewState'] != 'ENTERED' ||
          row['verificationStatus'] == 'IN_GAME_VERIFIED') {
        throw InvalidRepositoryIntake(
          'Staged observations must remain ENTERED and unverified',
        );
      }
    }
    for (final row in entities) {
      if (!sourceIds.contains(row['sourceId']))
        throw InvalidRepositoryIntake(
          'Entity ${row['id']} references unknown source',
        );
    }
    final observationCount = manifest['observationCount'];
    final evidenceCount = manifest['evidenceCount'];
    if (observationCount != observations.length ||
        evidenceCount != evidenceRows.length) {
      throw const InvalidRepositoryIntake(
        'Manifest record counts do not match payloads',
      );
    }
    final liveDate = DateTime.tryParse(
      sessionJson['capturedDate'] as String? ?? '',
    );
    if (liveDate == null ||
        (sessionJson['location'] as String? ?? '').trim().isEmpty) {
      throw const InvalidRepositoryIntake(
        'Observed live date and location are required',
      );
    }
    final officialVersion = sessionJson['gameVersion'] as String?;
    final createdAt =
        DateTime.tryParse(manifest['createdAt'] as String? ?? '') ?? liveDate;
    final session = VerificationSession(
      id: sessionId,
      gameUpdateLabel: (officialVersion?.trim().isNotEmpty ?? false)
          ? officialVersion!.trim()
          : 'Unknown official update',
      officialGameVersion: officialVersion,
      observedLiveAt: liveDate,
      sessionDate: liveDate,
      checkType: sessionJson['checkType'] as String? ?? 'Index',
      worldLocation: sessionJson['location'] as String,
      notes:
          sessionJson['sessionContext'] as String? ??
          sessionJson['notes'] as String?,
      createdAt: createdAt,
    );
    return RepositoryIntakeData(
      manifest: manifest,
      session: session,
      sources: sources,
      entities: entities,
      observations: observations,
      evidence: evidenceRows,
      evidenceBytes: evidenceBytes,
      repositoryPath: root,
    );
  }

  static List<Map<String, Object?>> _jsonList(
    Map<String, Uint8List> files,
    String name,
  ) {
    try {
      final value = jsonDecode(utf8.decode(files[name]!));
      if (value is! List) throw const FormatException();
      return value.cast<Map<String, Object?>>();
    } on Object {
      throw InvalidRepositoryIntake('$name is missing or invalid');
    }
  }

  static Set<String> _uniqueIds(List<Map<String, Object?>> rows, String label) {
    final result = <String>{};
    for (final row in rows) {
      final id = row['id'];
      if (id is! String || id.isEmpty || !result.add(id)) {
        throw InvalidRepositoryIntake('Missing or duplicate $label ID');
      }
    }
    return result;
  }

  static void _validateRelativePath(String value) {
    if (value.isEmpty ||
        value.contains('\\') ||
        p.isAbsolute(value) ||
        value
            .split('/')
            .any((part) => part.isEmpty || part == '.' || part == '..')) {
      throw InvalidRepositoryIntake('Unsafe relative path: $value');
    }
  }
}
