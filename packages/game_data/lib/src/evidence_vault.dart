import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'game_data_store.dart';
import 'models.dart';

class DuplicateEvidenceException implements Exception {
  const DuplicateEvidenceException(this.existing);
  final EvidenceRecord existing;
  @override
  String toString() => 'This image is already stored as ${existing.id}';
}

/// Copies screenshots into app-owned storage and records their immutable hash.
class EvidenceVault {
  EvidenceVault({required this.rootDirectory, required this.database});

  final Directory rootDirectory;
  final GameDataStore database;

  static const _allowedExtensions = {'png', 'jpg', 'jpeg', 'webp'};

  Future<EvidenceRecord> importScreenshot({
    required Uint8List bytes,
    required String originalFilename,
    String? sessionId,
    String? gameUpdateLabel,
    DateTime? capturedAt,
  }) async {
    final extension = p
        .extension(originalFilename)
        .replaceFirst('.', '')
        .toLowerCase();
    if (!_allowedExtensions.contains(extension)) {
      throw FormatException('Unsupported screenshot type .$extension');
    }
    final decoded = img.decodeImage(bytes);
    if (decoded == null)
      throw const FormatException('Image data is invalid or unsupported');
    final checksum = sha256.convert(bytes).toString();
    final duplicate = await database.getEvidenceByChecksum(checksum);
    if (duplicate != null) throw DuplicateEvidenceException(duplicate);
    await rootDirectory.create(recursive: true);
    final id = _newId();
    final path = p.join(rootDirectory.path, '$id.$extension');
    await File(path).writeAsBytes(bytes, flush: true);
    final now = DateTime.now().toUtc();
    final record = EvidenceRecord(
      id: id,
      type: EvidenceType.screenshot,
      reference: path,
      capturedAt: capturedAt,
      checksum: checksum,
      notes: gameUpdateLabel,
      originalFilename: p.basename(originalFilename),
      importedAt: now,
      width: decoded.width,
      height: decoded.height,
      sessionId: sessionId,
    );
    try {
      await database.saveEvidence(record);
    } on Object {
      await File(path).delete();
      rethrow;
    }
    return record;
  }

  Future<EvidenceRecord> createCrop({
    required EvidenceRecord original,
    required int x,
    required int y,
    required int width,
    required int height,
    required String label,
  }) async {
    if (!await database.isEvidenceFileIntact(original)) {
      throw StateError(
        'Original screenshot is missing or its checksum is invalid',
      );
    }
    final source = img.decodeImage(
      await File(original.reference).readAsBytes(),
    );
    if (source == null)
      throw StateError('Original screenshot cannot be decoded');
    final left = x.clamp(0, source.width - 1);
    final top = y.clamp(0, source.height - 1);
    final cropWidth = width.clamp(1, source.width - left);
    final cropHeight = height.clamp(1, source.height - top);
    final cropped = img.copyCrop(
      source,
      x: left,
      y: top,
      width: cropWidth,
      height: cropHeight,
    );
    final bytes = Uint8List.fromList(img.encodePng(cropped));
    final checksum = sha256.convert(bytes).toString();
    final duplicate = await database.getEvidenceByChecksum(checksum);
    if (duplicate != null) throw DuplicateEvidenceException(duplicate);
    final id = _newId();
    await rootDirectory.create(recursive: true);
    final path = p.join(rootDirectory.path, '$id.png');
    await File(path).writeAsBytes(bytes, flush: true);
    final record = EvidenceRecord(
      id: id,
      type: EvidenceType.screenshot,
      reference: path,
      checksum: checksum,
      notes: label,
      originalFilename:
          '${p.basenameWithoutExtension(original.originalFilename ?? 'screenshot')}-${_safeSlug(label)}.png',
      importedAt: DateTime.now().toUtc(),
      width: cropped.width,
      height: cropped.height,
      sessionId: original.sessionId,
      parentEvidenceId: original.id,
    );
    try {
      await database.saveEvidence(record);
    } on Object {
      await File(path).delete();
      rethrow;
    }
    return record;
  }

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32).toRadixString(16)}';

  String _safeSlug(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}
