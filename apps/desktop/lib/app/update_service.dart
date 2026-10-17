import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

const appBuildCommit = String.fromEnvironment(
  'APP_COMMIT_SHA',
  defaultValue: 'development',
);
const appBuildVersion = String.fromEnvironment(
  'APP_BUILD_VERSION',
  defaultValue: 'development',
);

const _repository = 'LoliCatis/the-forge-companion';
const _expectedAssetName = 'the-forge-companion-windows-alpha.zip';
const _manifestAssetName = 'windows-alpha-manifest.json';
const _maxUpdateBytes = 512 * 1024 * 1024;

class AppReleaseVersion implements Comparable<AppReleaseVersion> {
  const AppReleaseVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.channel,
    required this.sequence,
  });

  final int major;
  final int minor;
  final int patch;
  final String channel;
  final int sequence;

  static AppReleaseVersion? tryParse(String value) {
    final match = RegExp(
      r'^v?(\d+)\.(\d+)\.(\d+)-(alpha|beta)\.(\d+)$',
    ).firstMatch(value);
    if (match == null) return null;
    return AppReleaseVersion(
      major: int.parse(match[1]!),
      minor: int.parse(match[2]!),
      patch: int.parse(match[3]!),
      channel: match[4]!,
      sequence: int.parse(match[5]!),
    );
  }

  @override
  int compareTo(AppReleaseVersion other) {
    final base = major.compareTo(other.major);
    if (base != 0) return base;
    final minorOrder = minor.compareTo(other.minor);
    if (minorOrder != 0) return minorOrder;
    final patchOrder = patch.compareTo(other.patch);
    if (patchOrder != 0) return patchOrder;
    final channelOrder = _channelOrder(channel).compareTo(
      _channelOrder(other.channel),
    );
    if (channelOrder != 0) return channelOrder;
    return sequence.compareTo(other.sequence);
  }

  static int _channelOrder(String value) => switch (value) {
    'alpha' => 0,
    'beta' => 1,
    _ => -1,
  };

  @override
  String toString() => '$major.$minor.$patch-$channel.$sequence';
}

class AppUpdate {
  const AppUpdate({
    required this.commit,
    required this.version,
    required this.releaseName,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.sha256,
    required this.size,
    required this.dataVersion,
    required this.buildDateUtc,
    required this.releaseUrl,
  });

  final String commit;
  final String version;
  final String releaseName;
  final String releaseNotes;
  final Uri downloadUrl;
  final String sha256;
  final int size;
  final String dataVersion;
  final String buildDateUtc;
  final Uri releaseUrl;
}

/// Check and install support is intentionally limited to this app's public
/// Windows alpha releases. Game data and the user's SQLite database are never
/// included in the replacement step.
class AppUpdateService {
  const AppUpdateService();

  Future<AppUpdate?> checkForUpdate({
    required String currentCommit,
    required String currentVersion,
  }) async {
    final current = AppReleaseVersion.tryParse(currentVersion);
    if (current == null) {
      throw const FormatException(
        'This build has no comparable release version. Install an official alpha build before checking for updates.',
      );
    }

    final client = _newHttpClient();
    try {
      final releasesUri = Uri.https(
        'api.github.com',
        '/repos/$_repository/releases',
        {'per_page': '100'},
      );
      final releasesBody = await _getText(client, releasesUri);
      final decoded = jsonDecode(releasesBody);
      if (decoded is! List) {
        throw const FormatException('GitHub returned an invalid releases list.');
      }

      final candidates = selectCompatibleAppReleases(
        decoded,
        currentCommit: currentCommit,
        currentVersion: currentVersion,
      );
      var invalidNewerRelease = false;
      for (final candidate in candidates) {
        try {
          final update = await _readCandidate(client, candidate);
          if (update != null) return update;
          invalidNewerRelease = true;
        } on _AssetNotFound {
          invalidNewerRelease = true;
          continue;
        } on FormatException {
          invalidNewerRelease = true;
          continue;
        }
      }
      if (invalidNewerRelease ||
          (candidates.isEmpty &&
              _hasNewerReleaseWithDifferentCommit(
                decoded,
                currentCommit: currentCommit,
                currentVersion: currentVersion,
              ))) {
        throw const FormatException(
          'A newer alpha release exists, but its Windows portable assets are missing or failed integrity validation. The current installation was not changed.',
        );
      }
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<AppUpdate?> _readCandidate(
    HttpClient client,
    AppUpdateCandidate candidate,
  ) async {
    final downloadUrl = _githubAssetUrl(candidate.zipAsset);
    final digest = _sha256FromAsset(candidate.zipAsset);
    final size = candidate.zipAsset['size'];
    if (size is! int || size <= 0 || size > _maxUpdateBytes) return null;

    final manifestUrl = _githubAssetUrl(candidate.manifestAsset);
    final manifestDigest = _sha256FromAsset(candidate.manifestAsset);
    final manifestText = await _getText(client, manifestUrl);
    if (sha256.convert(utf8.encode(manifestText)).toString() != manifestDigest) {
      throw const FormatException(
        'The Windows update manifest failed its GitHub SHA-256 check.',
      );
    }
    final manifest = jsonDecode(manifestText);
    if (manifest is! Map<String, dynamic> ||
        manifest['platform'] != 'windows-x64' ||
        manifest['assetName'] != _expectedAssetName ||
        manifest['version'] != candidate.version.toString() ||
        manifest['commit'] != candidate.commit ||
        manifest['sha256'] != digest ||
        manifest['size'] != size ||
        manifest['dataVersion'] is! String ||
        (manifest['dataVersion'] as String).isEmpty ||
        manifest['buildDateUtc'] is! String ||
        manifest['executableName'] != 'the_forge_companion.exe') {
      return null;
    }

    final releaseUrlText = candidate.release['html_url'];
    final releaseName = candidate.release['name'];
    final releaseNotes = candidate.release['body'];
    return AppUpdate(
      commit: candidate.commit,
      version: candidate.version.toString(),
      releaseName: releaseName is String && releaseName.trim().isNotEmpty
          ? releaseName
          : candidate.version.toString(),
      releaseNotes: releaseNotes is String ? releaseNotes : '',
      downloadUrl: downloadUrl,
      sha256: digest,
      size: size,
      dataVersion: manifest['dataVersion'] as String,
      buildDateUtc: manifest['buildDateUtc'] as String,
      releaseUrl: Uri.parse(
        releaseUrlText is String
            ? releaseUrlText
            : 'https://github.com/$_repository/releases/tag/${candidate.version}',
      ),
    );
  }

  Future<Directory> downloadAndStage(
    AppUpdate update, {
    required Directory appDataDirectory,
    required void Function(double progress) onProgress,
  }) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Not supported yet');
    }
    final updaterDirectory = Directory(
      p.join(appDataDirectory.path, 'updates', update.commit),
    );
    await updaterDirectory.create(recursive: true);
    final zipFile = File(p.join(updaterDirectory.path, _expectedAssetName));
    if (await zipFile.exists()) await zipFile.delete();

    try {
      final client = _newHttpClient();
      try {
        final request = await client.getUrl(update.downloadUrl);
        request.followRedirects = true;
        final response = await request.close().timeout(
          const Duration(seconds: 60),
        );
        if (response.statusCode != HttpStatus.ok) {
          throw _httpStatusError(response.statusCode, uri: update.downloadUrl);
        }
        if (response.contentLength > 0 &&
            response.contentLength != update.size) {
          throw const FormatException(
            'Downloaded file size does not match the GitHub release.',
          );
        }
        final sink = zipFile.openWrite();
        var received = 0;
        try {
          await for (final chunk in response.timeout(
            const Duration(seconds: 30),
          )) {
            received += chunk.length;
            if (received > update.size || received > _maxUpdateBytes) {
              throw const FormatException(
                'Downloaded update is larger than the release manifest.',
              );
            }
            sink.add(chunk);
            onProgress((received / update.size).clamp(0.0, 1.0));
          }
        } finally {
          await sink.close();
        }
        if (received != update.size) {
          throw const FormatException(
            'Downloaded file size does not match the GitHub release.',
          );
        }
      } finally {
        client.close(force: true);
      }

      final actualDigest = sha256.convert(await zipFile.readAsBytes()).toString();
      if (actualDigest != update.sha256) {
        throw const FormatException(
          'The downloaded update failed its SHA-256 check.',
        );
      }

      final stage = Directory(p.join(updaterDirectory.path, 'stage'));
      if (await stage.exists()) await stage.delete(recursive: true);
      await stage.create(recursive: true);
      try {
        final archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());
        var hasExecutable = false;
        var hasFlutterRuntime = false;
        for (final entry in archive) {
          final destination = safeArchiveDestination(
            stage.path,
            entry.name,
          );
          if (entry.isDirectory) {
            await Directory(destination).create(recursive: true);
            continue;
          }
          final file = File(destination);
          await file.parent.create(recursive: true);
          await file.writeAsBytes(entry.content as List<int>, flush: true);
          if (p.basename(destination).toLowerCase() ==
              'the_forge_companion.exe') {
            hasExecutable = true;
          }
          if (p.basename(destination).toLowerCase() == 'flutter_windows.dll') {
            hasFlutterRuntime = true;
          }
        }
        if (!hasExecutable || !hasFlutterRuntime) {
          throw const FormatException(
            'The archive is missing the Windows executable or Flutter runtime DLL.',
          );
        }
        await _validateBuildInfo(stage, update);
      } catch (_) {
        await stage.delete(recursive: true);
        rethrow;
      }
      return stage;
    } catch (_) {
      if (await zipFile.exists()) await zipFile.delete();
      rethrow;
    }
  }

  Future<void> _validateBuildInfo(Directory stage, AppUpdate update) async {
    final buildInfo = File(p.join(stage.path, 'BUILD_INFO.txt'));
    if (!await buildInfo.exists()) {
      throw const FormatException('The update is missing BUILD_INFO.txt.');
    }
    final lines = await buildInfo.readAsLines();
    final values = <String, String>{};
    for (final line in lines) {
      final separator = line.indexOf(':');
      if (separator > 0) {
        values[line.substring(0, separator).trim()] =
            line.substring(separator + 1).trim();
      }
    }
    if (!await File(p.join(stage.path, 'data', 'flutter_assets', 'AssetManifest.bin'))
        .exists()) {
      throw const FormatException(
        'The archive is missing Flutter assets and is not a complete Windows portable build.',
      );
    }
    final packManifest = File(
      p.join(
        stage.path,
        'data',
        'flutter_assets',
        'assets',
        'packs',
        update.dataVersion,
        'manifest.json',
      ),
    );
    if (!await packManifest.exists()) {
      throw const FormatException(
        'The archive does not contain the data pack named in its release manifest.',
      );
    }
    final decodedPack = jsonDecode(await packManifest.readAsString());
    if (decodedPack is! Map<String, dynamic> ||
        decodedPack['dataVersion'] != update.dataVersion) {
      throw const FormatException(
        'The bundled data pack version does not match the release manifest.',
      );
    }
    final contentHashes = decodedPack['contentHashes'];
    const requiredPackFiles = [
      'ores.json',
      'weapons.json',
      'traits.json',
      'probabilities.json',
      'sources.json',
      'observations.json',
      'evidence.json',
    ];
    if (contentHashes is! Map<String, dynamic>) {
      throw const FormatException('The bundled data pack manifest is invalid.');
    }
    for (final name in requiredPackFiles) {
      final file = File(p.join(packManifest.parent.path, name));
      final expectedHash = contentHashes[name];
      if (expectedHash is! String ||
          !await file.exists() ||
          sha256.convert(await file.readAsBytes()).toString() != expectedHash) {
        throw FormatException('The bundled data pack file $name is missing or corrupt.');
      }
    }
    if (!lines.contains('ALPHA / TEST BUILD') ||
        values['App version'] != update.version ||
        values['Commit SHA'] != update.commit ||
        values['Data version'] != update.dataVersion ||
        values['Build date (UTC)'] != update.buildDateUtc ||
        values['Executable']?.toLowerCase() != 'the_forge_companion.exe') {
      throw const FormatException(
        'BUILD_INFO.txt does not match the selected release, commit and data pack.',
      );
    }
  }

  Future<void> scheduleInstall({
    required Directory stage,
    required Directory appDataDirectory,
    required AppUpdate update,
  }) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Not supported yet');
    }
    final installRoot = File(Platform.resolvedExecutable).parent;
    final writeProbe = File(
      p.join(installRoot.path, '.the-forge-update-write-check-$pid'),
    );
    try {
      await writeProbe.writeAsString('update permission check', flush: true);
    } on FileSystemException catch (error) {
      throw StateError(
        'The application folder is not writable. Extract the portable build to a folder you own and try again. $error',
      );
    } finally {
      if (await writeProbe.exists()) await writeProbe.delete();
    }
    final executableName = p.basename(Platform.resolvedExecutable);
    final logFile = File(p.join(appDataDirectory.path, 'logs', 'update.log'));
    await logFile.parent.create(recursive: true);
    final pendingUpdate = File(
      p.join(appDataDirectory.path, 'pending-update.json'),
    );
    final scriptFile = File(p.join(stage.parent.path, 'install-update.ps1'));
    await scriptFile.writeAsString(_installScript, flush: true);
    await Process.start(
      'powershell.exe',
      [
        '-NoProfile',
        '-WindowStyle',
        'Hidden',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptFile.path,
        '-InstallRoot',
        installRoot.path,
        '-StageRoot',
        stage.path,
        '-ProcessId',
        '$pid',
        '-ExecutableName',
        executableName,
        '-Commit',
        update.commit,
        '-Version',
        update.version,
        '-PendingUpdatePath',
        pendingUpdate.path,
        '-LogPath',
        logFile.path,
      ],
      mode: ProcessStartMode.detached,
    );
  }

  /// Called after the new build has successfully opened its database and
  /// bundled pack. The backup remains on disk until this explicit handshake.
  Future<void> confirmSuccessfulStartup({
    required Directory appDataDirectory,
    required String currentCommit,
    required Future<void> Function(String message) writeLog,
  }) async {
    if (!Platform.isWindows) return;
    final marker = File(p.join(appDataDirectory.path, 'pending-update.json'));
    if (!await marker.exists()) return;
    try {
      final decoded = jsonDecode(await marker.readAsString());
      if (decoded is! Map<String, dynamic> ||
          decoded['commit'] != currentCommit ||
          decoded['backupDirectory'] != '.the-forge-update-backup') {
        return;
      }
      final installRoot = File(Platform.resolvedExecutable).parent;
      final backupRoot = Directory(
        p.join(installRoot.path, '.the-forge-update-backup'),
      );
      if (await backupRoot.exists()) await backupRoot.delete(recursive: true);
      await marker.delete();
      await writeLog(
        'Update ${decoded['version']} (${decoded['commit']}) confirmed after successful startup; installation backup removed.',
      );
    } catch (error) {
      await writeLog('Unable to finalize update backup cleanup: $error');
    }
  }
}

bool _hasNewerReleaseWithDifferentCommit(
  List<dynamic> releases, {
  required String currentCommit,
  required String currentVersion,
}) {
  final current = AppReleaseVersion.tryParse(currentVersion);
  if (current == null) return false;
  return releases.any((item) {
    if (item is! Map<String, dynamic> ||
        item['draft'] != false ||
        item['prerelease'] != true) {
      return false;
    }
    final rawTag = item['tag_name'];
    final version = rawTag is String ? AppReleaseVersion.tryParse(rawTag) : null;
    final commit = _releaseCommit(item);
    return version != null &&
        version.compareTo(current) > 0 &&
        commit != null &&
        commit != currentCommit;
  });
}

/// Resolves and validates a ZIP member before writing any bytes to staging.
String safeArchiveDestination(String stagingPath, String entryName) {
  final normalizedName = entryName.replaceAll('\\', '/');
  if (normalizedName.isEmpty ||
      normalizedName.startsWith('/') ||
      normalizedName.startsWith('//') ||
      RegExp(r'^[A-Za-z]:').hasMatch(normalizedName) ||
      normalizedName.split('/').contains('..')) {
    throw const FormatException('The update ZIP contains an unsafe path.');
  }
  final root = p.normalize(p.absolute(stagingPath));
  final destination = p.normalize(p.join(root, normalizedName));
  if (!p.isWithin(root, destination)) {
    throw const FormatException('The update ZIP contains a path traversal entry.');
  }
  return destination;
}

HttpClient _newHttpClient() => HttpClient()
  ..userAgent = 'TheForgeCompanion-Updater'
  ..connectionTimeout = const Duration(seconds: 15)
  ..idleTimeout = const Duration(seconds: 30);

Future<String> _getText(HttpClient client, Uri uri) async {
  final request = await client.getUrl(uri).timeout(const Duration(seconds: 30));
  request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
  request.headers.set('X-GitHub-Api-Version', '2022-11-28');
  final response = await request.close().timeout(const Duration(seconds: 60));
  if (response.statusCode != HttpStatus.ok) {
    throw _httpStatusError(response.statusCode, uri: uri);
  }
  return response
      .transform(utf8.decoder)
      .join()
      .timeout(const Duration(seconds: 30));
}

Exception _httpStatusError(int statusCode, {required Uri uri}) {
  if (statusCode == HttpStatus.forbidden || statusCode == 429) {
    return const HttpException(
      'GitHub rate limit reached. Wait a little and check for updates again.',
    );
  }
  if (statusCode == HttpStatus.notFound) {
    return _AssetNotFound('The GitHub release or asset was not found.');
  }
  return HttpException(
    'GitHub returned HTTP $statusCode while checking for an update.',
    uri: uri,
  );
}

class _AssetNotFound implements Exception {
  const _AssetNotFound(this.message);
  final String message;
  @override
  String toString() => message;
}

Uri _githubAssetUrl(Map<String, dynamic> asset) {
  final raw = asset['browser_download_url'];
  if (raw is! String) {
    throw const FormatException('A GitHub release asset has no download URL.');
  }
  final uri = Uri.parse(raw);
  if (uri.scheme != 'https' ||
      uri.host != 'github.com' ||
      !uri.path.startsWith(
        '/LoliCatis/the-forge-companion/releases/download/',
      )) {
    throw const FormatException(
      'Release assets must belong to the configured GitHub repository.',
    );
  }
  return uri;
}

String _sha256FromAsset(Map<String, dynamic> asset) {
  final digest = asset['digest'];
  if (digest is! String || !RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(digest)) {
    throw const FormatException('The GitHub asset has no valid SHA-256 digest.');
  }
  return digest.substring('sha256:'.length);
}

String? _releaseCommit(Map<String, dynamic> release) {
  final body = release['body'];
  if (body is! String) return null;
  final match = RegExp(
    r'^Commit SHA: ([0-9a-f]{40})\s*$',
    multiLine: true,
  ).firstMatch(body);
  return match?[1];
}

class AppUpdateCandidate {
  const AppUpdateCandidate({
    required this.release,
    required this.version,
    required this.commit,
    required this.zipAsset,
    required this.manifestAsset,
  });

  final Map<String, dynamic> release;
  final AppReleaseVersion version;
  final String commit;
  final Map<String, dynamic> zipAsset;
  final Map<String, dynamic> manifestAsset;
}

/// Filters the release list returned by the fixed official repository API.
/// Version ordering is semantic and never depends on publication timestamps.
List<AppUpdateCandidate> selectCompatibleAppReleases(
  List<dynamic> releases, {
  required String currentCommit,
  required String currentVersion,
}) {
  final current = AppReleaseVersion.tryParse(currentVersion);
  if (current == null) {
    throw const FormatException('Current build version cannot be compared.');
  }
  final candidates = <AppUpdateCandidate>[];
  for (final item in releases) {
    if (item is! Map<String, dynamic> ||
        item['draft'] != false ||
        item['prerelease'] != true) {
      continue;
    }
    final tag = item['tag_name'];
    final version = tag is String ? AppReleaseVersion.tryParse(tag) : null;
    final assets = item['assets'];
    if (version == null || assets is! List || version.compareTo(current) <= 0) {
      continue;
    }
    final assetRows = assets.whereType<Map<String, dynamic>>();
    final zipAsset = assetRows
        .where((asset) => asset['name'] == _expectedAssetName)
        .firstOrNull;
    final manifestAsset = assetRows
        .where((asset) => asset['name'] == _manifestAssetName)
        .firstOrNull;
    if (zipAsset == null || manifestAsset == null) continue;
    final commit = _releaseCommit(item);
    if (commit == null ||
        !RegExp(r'^[0-9a-f]{40}$').hasMatch(commit) ||
        commit == currentCommit) {
      continue;
    }
    final size = zipAsset['size'];
    if (size is! int || size <= 0 || size > _maxUpdateBytes) continue;
    try {
      _sha256FromAsset(zipAsset);
      _sha256FromAsset(manifestAsset);
      _githubAssetUrl(zipAsset);
      _githubAssetUrl(manifestAsset);
    } on FormatException {
      continue;
    }
    candidates.add(
      AppUpdateCandidate(
        release: item,
        version: version,
        commit: commit,
        zipAsset: zipAsset,
        manifestAsset: manifestAsset,
      ),
    );
  }
  candidates.sort((a, b) => b.version.compareTo(a.version));
  return List.unmodifiable(candidates);
}

const _installScript = r'''
param(
  [Parameter(Mandatory=$true)][string]$InstallRoot,
  [Parameter(Mandatory=$true)][string]$StageRoot,
  [Parameter(Mandatory=$true)][int]$ProcessId,
  [Parameter(Mandatory=$true)][string]$ExecutableName,
  [Parameter(Mandatory=$true)][string]$Commit,
  [Parameter(Mandatory=$true)][string]$Version,
  [Parameter(Mandatory=$true)][string]$PendingUpdatePath,
  [Parameter(Mandatory=$true)][string]$LogPath
)
$ErrorActionPreference = 'Stop'
$backupRoot = Join-Path $InstallRoot '.the-forge-update-backup'
$changed = @()
$newProcess = $null
try {
  while (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 300 }
  New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
  $root = $StageRoot.TrimEnd('\')
  Get-ChildItem -LiteralPath $root -Recurse -File | ForEach-Object {
    $relative = $_.FullName.Substring($root.Length + 1)
    $destination = Join-Path $InstallRoot $relative
    $backup = Join-Path $backupRoot $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    if (Test-Path -LiteralPath $destination -PathType Leaf) {
      New-Item -ItemType Directory -Path (Split-Path -Parent $backup) -Force | Out-Null
      Copy-Item -LiteralPath $destination -Destination $backup -Force
      $hadOriginal = $true
    } else { $hadOriginal = $false }
    $changed += [pscustomobject]@{ Destination = $destination; Backup = $backup; HadOriginal = $hadOriginal }
    Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
  }
  [ordered]@{ commit = $Commit; version = $Version; backupDirectory = '.the-forge-update-backup' } |
    ConvertTo-Json -Compress | Set-Content -LiteralPath $PendingUpdatePath -Encoding utf8
  Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Installed update files for $Version ($Commit); awaiting successful startup confirmation."
  $newProcess = Start-Process -FilePath (Join-Path $InstallRoot $ExecutableName) -PassThru
  $startupDeadline = (Get-Date).AddMinutes(2)
  while ((Get-Date) -lt $startupDeadline) {
    if (-not (Test-Path -LiteralPath $PendingUpdatePath)) {
      Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Update $Version startup was confirmed."
      Remove-Item -LiteralPath $StageRoot -Recurse -Force -ErrorAction SilentlyContinue
      exit 0
    }
    if (-not (Get-Process -Id $newProcess.Id -ErrorAction SilentlyContinue)) {
      throw 'Updated application exited before confirming startup.'
    }
    Start-Sleep -Milliseconds 500
  }
  throw 'Updated application did not confirm startup within two minutes.'
} catch {
  if ($newProcess -and (Get-Process -Id $newProcess.Id -ErrorAction SilentlyContinue)) {
    Stop-Process -Id $newProcess.Id -Force -ErrorAction SilentlyContinue
  }
  for ($i = $changed.Count - 1; $i -ge 0; $i--) {
    $item = $changed[$i]
    if ($item.HadOriginal -and (Test-Path -LiteralPath $item.Backup -PathType Leaf)) {
      Copy-Item -LiteralPath $item.Backup -Destination $item.Destination -Force
    } elseif (-not $item.HadOriginal) {
      Remove-Item -LiteralPath $item.Destination -Force -ErrorAction SilentlyContinue
    }
  }
  Remove-Item -LiteralPath $PendingUpdatePath -Force -ErrorAction SilentlyContinue
  Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Update failed and was rolled back: $($_.Exception.Message)"
  Start-Process -FilePath (Join-Path $InstallRoot $ExecutableName) -ErrorAction SilentlyContinue
}
''';
