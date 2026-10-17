import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_forge_companion/startup/startup_bootstrap.dart';
import 'package:the_forge_companion/startup/startup_gate.dart';

void main() {
  test('clean install creates SQLite and imports the empty bundled bootstrap pack', () async {
    final appDirectory = await Directory.systemTemp.createTemp(
      'forge-companion-clean-start-',
    );
    addTearDown(() async {
      await appDirectory.delete(recursive: true);
    });
    final log = await StartupLog.create(appDirectory);

    final result = await StartupBootstrap(
      appDirectory: appDirectory,
      log: log,
    ).run();
    addTearDown(result.database.close);

    expect(
      await result.database.getActiveDataVersion(),
      bundledPackVersion,
    );
    expect(await result.database.countAllOres(), 0);
    expect(
      File('${appDirectory.path}${Platform.pathSeparator}forge-companion.sqlite3')
          .existsSync(),
      isTrue,
    );
    final logText = await log.file.readAsString();
    expect(logText, contains('Pack import success'));
  });

  test('missing bundled pack is reported as a bootstrap failure', () async {
    final appDirectory = await Directory.systemTemp.createTemp(
      'forge-companion-missing-pack-',
    );
    addTearDown(() async {
      await appDirectory.delete(recursive: true);
    });
    final log = await StartupLog.create(appDirectory);
    final bootstrap = StartupBootstrap(
      appDirectory: appDirectory,
      log: log,
      loadAsset: (asset) async => throw StateError('Missing asset: $asset'),
    );

    await expectLater(
      bootstrap.run(),
      throwsA(
        isA<StartupBootstrapFailure>()
            .having((failure) => failure.stage, 'stage', 'Load bundled data pack')
            .having(
              (failure) => failure.resource,
              'resource',
              '$bundledPackAssetRoot/manifest.json',
            ),
      ),
    );
    final logText = await log.file.readAsString();
    expect(logText, contains('Pack bootstrap/import failure'));
    expect(logText, contains('Missing asset'));
  });

  test('corrupt bundled pack is rejected before database import', () async {
    final appDirectory = await Directory.systemTemp.createTemp(
      'forge-companion-corrupt-pack-',
    );
    addTearDown(() async {
      await appDirectory.delete(recursive: true);
    });
    final log = await StartupLog.create(appDirectory);
    final bootstrap = StartupBootstrap(
      appDirectory: appDirectory,
      log: log,
      loadAsset: (asset) async {
        final content = await rootBundle.loadString(asset);
        return asset.endsWith('/ores.json') ? '$content ' : content;
      },
    );

    await expectLater(
      bootstrap.run(),
      throwsA(
        isA<StartupBootstrapFailure>().having(
          (failure) => failure.stage,
          'stage',
          'Validate and import bundled data pack',
        ),
      ),
    );
    final logText = await log.file.readAsString();
    expect(logText, contains('Pack bootstrap/import failure'));
    expect(logText, contains('Content hash mismatch for ores.json'));
  });

  testWidgets('startup error has visible details and retry action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StartupFailureView(
              error: 'Load bundled data pack failed: Asset not found',
              logPath: 'app-support/logs/startup.log',
              onRetry: () {},
              onOpenLogs: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('The app could not finish starting'), findsOneWidget);
    expect(find.textContaining('Asset not found'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('app-support'), findsOneWidget);
    expect(find.text('Open diagnostic location'), findsOneWidget);
  });
}
