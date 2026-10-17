import 'dart:io';

import 'package:flutter/services.dart';
import 'package:game_data/game_data.dart';
import 'package:path/path.dart' as p;

const bundledPackVersion = '2026.10.17-bootstrap.1';
const bundledPackAssetRoot = 'assets/packs/$bundledPackVersion';
const startupAppVersion = String.fromEnvironment(
  'APP_BUILD_VERSION',
  defaultValue: 'development',
);

const bundledPackFiles = <String>[
  'manifest.json',
  'ores.json',
  'weapons.json',
  'traits.json',
  'probabilities.json',
  'sources.json',
  'observations.json',
  'evidence.json',
];

class StartupLog {
  StartupLog._(this.file);

  final File file;

  Directory get directory => file.parent;

  static Future<StartupLog> create(Directory appDirectory) async {
    final directory = Directory(p.join(appDirectory.path, 'logs'));
    await directory.create(recursive: true);
    return StartupLog._(File(p.join(directory.path, 'startup.log')));
  }

  Future<void> write(String message) async {
    final line = '${DateTime.now().toUtc().toIso8601String()} $message\n';
    await file.writeAsString(line, mode: FileMode.append, flush: true);
  }
}

class StartupBootstrapFailure implements Exception {
  const StartupBootstrapFailure({
    required this.stage,
    required this.resource,
    required this.error,
    required this.stackTrace,
  });

  final String stage;
  final String resource;
  final Object error;
  final StackTrace stackTrace;

  @override
  String toString() => '$stage failed ($resource): $error';
}

class StartupBootstrapResult {
  const StartupBootstrapResult({
    required this.database,
    required this.appDirectory,
  });

  final GameDatabase database;
  final Directory appDirectory;
}

typedef PackAssetLoader = Future<String> Function(String assetKey);

class StartupBootstrap {
  StartupBootstrap({
    required this.appDirectory,
    required this.log,
    PackAssetLoader? loadAsset,
  }) : loadAsset = loadAsset ?? rootBundle.loadString;

  final Directory appDirectory;
  final StartupLog? log;
  final PackAssetLoader loadAsset;

  Future<StartupBootstrapResult> run() async {
    GameDatabase? database;
    var stage = 'Create application data directory';
    var resource = appDirectory.path;
    try {
      await appDirectory.create(recursive: true);
      final databasePath = p.join(appDirectory.path, 'forge-companion.sqlite3');
      stage = 'Open local SQLite database';
      resource = databasePath;
      await _writeLog('Database path: $databasePath');
      database = await GameDatabase.open(databasePath);

      final activeVersion = await database.getActiveDataVersion();
      if (activeVersion == null) {
        stage = 'Load bundled data pack';
        resource = '$bundledPackAssetRoot/manifest.json';
        await _writeLog(
          'Pack bootstrap start; asset version: $bundledPackVersion',
        );
        final contents = <String, String>{};
        for (final file in bundledPackFiles) {
          final asset = '$bundledPackAssetRoot/$file';
          resource = asset;
          contents[file] = await loadAsset(asset);
        }

        stage = 'Validate and import bundled data pack';
        resource = bundledPackAssetRoot;
        final pack = DataPackBundle(contents).validate();
        if (pack.manifest.dataVersion != bundledPackVersion) {
          throw FormatException(
            'Bundled data version ${pack.manifest.dataVersion} does not match '
            'expected $bundledPackVersion',
          );
        }
        await database.importDataPack(pack);
        await _writeLog(
          'Pack import success; active data version: '
          '${await database.getActiveDataVersion()}',
        );
      } else {
        await _writeLog(
          'Pack bootstrap success; existing active data version: $activeVersion',
        );
      }

      return StartupBootstrapResult(
        database: database,
        appDirectory: appDirectory,
      );
    } catch (error, stackTrace) {
      try {
        final failureKind = stage.contains('data pack') ||
                stage.contains('bundled data pack')
            ? 'Pack bootstrap/import failure'
            : 'Startup failure';
        await log?.write(
          '$failureKind; stage: $stage; resource: $resource; '
          'exception: $error\n$stackTrace',
        );
      } catch (_) {
        // Keep the bootstrap error visible even if the log location is unwritable.
      }
      try {
        await database?.close();
      } catch (_) {
        // The original startup error is the useful diagnostic.
      }
      throw StartupBootstrapFailure(
        stage: stage,
        resource: resource,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _writeLog(String message) async {
    try {
      await log?.write(message);
    } catch (_) {
      // Logging must not prevent the app from reaching a usable screen.
    }
  }
}

Directory defaultAppDirectory() {
  final userHome = Platform.environment['USERPROFILE'] ??
      Platform.environment['HOME'] ??
      Directory.current.path;
  final appSupport = Platform.environment['APPDATA'] ??
      (Platform.isWindows
          ? p.join(userHome, 'AppData', 'Roaming')
          : p.join(userHome, 'Library', 'Application Support'));
  return Directory(p.join(appSupport, 'The Forge Companion'));
}

String formatStartupError(Object error) {
  if (error is StartupBootstrapFailure) {
    return '${error.stage}\n${error.error}\n\nResource: ${error.resource}';
  }
  return error.toString();
}

String startupErrorStack(Object error) => error is StartupBootstrapFailure
    ? error.stackTrace.toString()
    : error.toString();
