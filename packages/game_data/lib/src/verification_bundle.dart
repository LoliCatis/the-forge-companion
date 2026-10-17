import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import 'game_data_store.dart';
import 'models.dart';

class InvalidVerificationBundle implements Exception {
  const InvalidVerificationBundle(this.message);
  final String message;
  @override
  String toString() => message;
}

class ValidatedVerificationBundle {
  const ValidatedVerificationBundle({
    required this.manifest,
    required this.files,
  });
  final Map<String, Object?> manifest;
  final Map<String, Uint8List> files;
}

/// Portable ZIP export and integrity-only import validation. Import does not
/// install observations into the active data pack or database.
class VerificationBundleService {
  VerificationBundleService(this.database);
  final GameDataStore database;

  Future<Uint8List> exportSession(String sessionId) async {
    final sessions = await database.getVerificationSessions();
    final matches = sessions.where((session) => session.id == sessionId);
    if (matches.isEmpty) throw StateError('Verification session not found');
    final session = matches.first;
    final observations = await database.getSessionObservations(sessionId);
    final evidence = await database.getEvidenceForSession(sessionId);
    final files = <String, Uint8List>{
      'session.json': Uint8List.fromList(
        utf8.encode(jsonEncode(_sessionJson(session))),
      ),
      'observations.json': Uint8List.fromList(
        utf8.encode(jsonEncode(observations.map(_observationJson).toList())),
      ),
      'evidence.json': Uint8List.fromList(
        utf8.encode(jsonEncode(evidence.map(_evidenceJson).toList())),
      ),
    };
    for (final item in evidence) {
      if (!await database.isEvidenceFileIntact(item)) {
        throw StateError(
          'Evidence ${item.id} is unavailable or checksum-invalid',
        );
      }
      final extension = item.reference.split('.').last.toLowerCase();
      files['evidence/${item.id}.$extension'] = await File(
        item.reference,
      ).readAsBytes();
    }
    final manifest = <String, Object?>{
      'format': 'the-forge-companion-verification-bundle',
      'schemaVersion': 1,
      'sessionId': sessionId,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'files': {
        for (final entry in files.entries)
          entry.key: sha256.convert(entry.value).toString(),
      },
    };
    final archive = Archive();
    archive.addFile(
      ArchiveFile(
        'manifest.json',
        utf8.encode(jsonEncode(manifest)).length,
        utf8.encode(jsonEncode(manifest)),
      ),
    );
    for (final entry in files.entries) {
      archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static ValidatedVerificationBundle validate(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } on Object {
      throw const InvalidVerificationBundle(
        'ZIP archive is corrupted or unreadable',
      );
    }
    final files = <String, Uint8List>{};
    try {
      for (final file in archive.files) {
        if (!file.isFile) continue;
        final name = file.name.replaceAll('\\', '/');
        if (name.startsWith('/') || name.split('/').contains('..')) {
          throw const InvalidVerificationBundle(
            'Bundle contains an unsafe path',
          );
        }
        if (files.containsKey(name)) {
          throw const InvalidVerificationBundle(
            'Bundle contains a duplicate path',
          );
        }
        files[name] = Uint8List.fromList(file.content as List<int>);
      }
    } on InvalidVerificationBundle {
      rethrow;
    } on Object {
      throw const InvalidVerificationBundle(
        'ZIP payload is corrupted or unreadable',
      );
    }
    final manifestBytes = files['manifest.json'];
    if (manifestBytes == null)
      throw const InvalidVerificationBundle('manifest.json is missing');
    final Map<String, Object?> manifest;
    try {
      manifest = jsonDecode(utf8.decode(manifestBytes)) as Map<String, Object?>;
    } on Object {
      throw const InvalidVerificationBundle('manifest.json is invalid JSON');
    }
    if (manifest['format'] != 'the-forge-companion-verification-bundle' ||
        manifest['schemaVersion'] != 1) {
      throw const InvalidVerificationBundle(
        'Unsupported verification bundle format/version',
      );
    }
    final declared = manifest['files'];
    if (declared is! Map<String, dynamic>)
      throw const InvalidVerificationBundle('Manifest files map is missing');
    final payloadNames = files.keys
        .where((name) => name != 'manifest.json')
        .toSet();
    if (payloadNames.length != declared.length ||
        !payloadNames.containsAll(declared.keys)) {
      throw const InvalidVerificationBundle(
        'Manifest does not cover every payload file',
      );
    }
    for (final entry in declared.entries) {
      final contents = files[entry.key];
      if (contents == null)
        throw InvalidVerificationBundle('Bundle file ${entry.key} is missing');
      if (sha256.convert(contents).toString() != entry.value) {
        throw InvalidVerificationBundle('Checksum mismatch for ${entry.key}');
      }
    }
    if (!files.containsKey('session.json') ||
        !files.containsKey('observations.json') ||
        !files.containsKey('evidence.json')) {
      throw const InvalidVerificationBundle(
        'Required session/observations/evidence data is missing',
      );
    }
    final Object? evidenceMetadata;
    final Object? sessionMetadata;
    final Object? observationsMetadata;
    try {
      evidenceMetadata = jsonDecode(utf8.decode(files['evidence.json']!));
      sessionMetadata = jsonDecode(utf8.decode(files['session.json']!));
      observationsMetadata = jsonDecode(
        utf8.decode(files['observations.json']!),
      );
    } on Object {
      throw const InvalidVerificationBundle(
        'A bundle payload contains invalid JSON',
      );
    }
    if (sessionMetadata is! Map<String, dynamic> ||
        sessionMetadata['id'] != manifest['sessionId'] ||
        observationsMetadata is! List) {
      throw const InvalidVerificationBundle(
        'Session or observations data is invalid',
      );
    }
    if (evidenceMetadata is! List) {
      throw const InvalidVerificationBundle(
        'evidence.json must contain a list',
      );
    }
    for (final item in evidenceMetadata) {
      if (item is! Map<String, dynamic>) {
        throw const InvalidVerificationBundle(
          'Evidence metadata entry is invalid',
        );
      }
      final path = item['bundlePath'];
      final checksum = item['checksum'];
      if (path is! String ||
          checksum is! String ||
          files[path] == null ||
          sha256.convert(files[path]!).toString() != checksum) {
        throw InvalidVerificationBundle(
          'Evidence metadata checksum mismatch for ${item['id']}',
        );
      }
    }
    return ValidatedVerificationBundle(
      manifest: manifest,
      files: Map.unmodifiable(files),
    );
  }

  Map<String, Object?> _sessionJson(VerificationSession session) => {
    'id': session.id,
    'gameUpdateLabel': session.gameUpdateLabel,
    'officialGameVersion': session.officialGameVersion,
    'observedLiveAt': session.observedLiveAt?.toIso8601String(),
    'sessionDate': session.sessionDate.toIso8601String(),
    'worldLocation': session.worldLocation,
    'checkType': session.checkType,
    'notes': session.notes,
    'createdAt': session.createdAt.toIso8601String(),
  };

  Map<String, Object?> _observationJson(FieldObservation observation) => {
    'id': observation.id,
    'entityType': observation.entityType,
    'entityId': observation.entityId,
    'fieldName': observation.fieldName,
    'value': observation.value,
    'sourceId': observation.sourceId,
    'observedAt': observation.observedAt.toIso8601String(),
    'gameVersion': observation.gameVersion,
    'confidence': observation.confidence,
    'verificationStatus': observation.verificationStatus,
    'evidenceId': observation.evidenceId,
    'reviewState': observation.reviewState,
    'notes': observation.notes,
  };

  Map<String, Object?> _evidenceJson(EvidenceRecord evidence) => {
    'id': evidence.id,
    'type': evidence.type.name,
    'bundlePath':
        'evidence/${evidence.id}.${evidence.reference.split('.').last.toLowerCase()}',
    'checksum': evidence.checksum,
    'originalFilename': evidence.originalFilename,
    'importedAt': evidence.importedAt?.toIso8601String(),
    'capturedAt': evidence.capturedAt?.toIso8601String(),
    'width': evidence.width,
    'height': evidence.height,
    'sessionId': evidence.sessionId,
    'parentEvidenceId': evidence.parentEvidenceId,
    'notes': evidence.notes,
  };
}
