import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:game_data/game_data.dart';
import 'package:the_forge_companion/main.dart';

class _DashboardStore extends Fake implements GameDataStore {
  @override
  Future<String?> getActiveDataVersion() async => 'community-test';
  @override
  Future<String?> getActiveRulesetVersion() async => 'rules-test';
  @override
  Future<VerificationMetrics> getVerificationMetrics() async =>
      const VerificationMetrics(
        gameVerified: 0,
        userConfirmed: 0,
        communityOnly: 0,
        conflicts: 0,
        pendingReview: 0,
        domainVerified: {},
        domainTotal: {},
      );
  @override
  Future<List<SavedBuildRecord>> getSavedBuilds() async => [];
  @override
  Future<List<OreRecord>> searchOres(String query, {DataPolicy policy = DataPolicy.bestAvailable}) async => [];
  @override
  Future<List<OreTraitRecord>> getOreTraits(String oreId) async => [];
  @override
  Future<List<DataHealthIssue>> getDataHealthIssues() async => [];
  @override
  Future<int> countAllOres() async => 0;
  @override
  Future<int> countObservationsByVerificationStatus(String status) async => 0;
  @override
  Future<List<FieldObservation>> getVerificationQueue({String? reviewState}) async => [];
  @override
  Future<List<VerificationSession>> getVerificationSessions() async => [];
  @override
  Future<List<VerificationTarget>> getVerificationTargets(String sessionId) async => [];
  @override
  Future<ResolvedField> resolveField({required String entityType, required String entityId, required String fieldName, DataPolicy policy = DataPolicy.bestAvailable}) async => const ResolvedField(preferred: null, alternatives: [], conflicting: false, incomplete: true);
  @override
  Future<List<WeaponVariantRecord>> getWeaponVariants({String? classId}) async => [];
  @override
  Future<List<WeaponClassRecord>> getWeaponClasses() async => [];
  @override
  Future<ProbabilityTableRecord?> getProbabilityTable(String id) async => null;
}

class _VerificationStore extends _DashboardStore {
  final sessions = <VerificationSession>[];
  @override
  Future<List<VerificationSession>> getVerificationSessions() async => sessions;
  @override
  Future<void> createVerificationSession(VerificationSession session) async =>
      sessions.add(session);
  @override
  Future<List<EvidenceRecord>> getEvidenceForSession(String sessionId) async =>
      [];
  @override
  Future<List<FieldObservation>> getSessionObservations(
    String sessionId,
  ) async => [];
  @override
  Future<List<VerificationTarget>> getVerificationTargets(
    String sessionId,
  ) async => [];
  @override
  Future<ResolvedField> resolveField({
    required String entityType,
    required String entityId,
    required String fieldName,
    DataPolicy policy = DataPolicy.bestAvailable,
  }) async => const ResolvedField(
    preferred: null,
    alternatives: [],
    conflicting: false,
  );
  @override
  Future<VerificationMetrics> getVerificationMetrics() async =>
      const VerificationMetrics(
        gameVerified: 0,
        userConfirmed: 0,
        communityOnly: 0,
        conflicts: 0,
        pendingReview: 0,
        domainVerified: {},
        domainTotal: {},
      );
  @override
  Future<String?> getActiveDataVersion() async => 'community-test';
  @override
  Future<String?> getActiveRulesetVersion() async => 'rules-test';
}

class _LocalizationStore extends _DashboardStore {
  @override
  Future<List<OreRecord>> searchOres(String query, {DataPolicy policy = DataPolicy.bestAvailable}) async =>
      query.isEmpty || 'aite'.contains(query.toLowerCase())
      ? const [
          OreRecord(
            id: 'aite',
            name: 'Aite',
            rarity: 'Epic',
            multiplier: 1.1,
            price: 16.5,
            source: 'community',
            verificationStatus: 'COMMUNITY',
            confidence: 0.6,
          ),
        ]
      : [];

  @override
  Future<List<SavedBuildRecord>> getSavedBuilds() async => [
    SavedBuildRecord(
      id: 'user-recipe',
      name: 'Dashboard',
      recipe: const {'aite': 3},
      createdAt: DateTime.utc(2026, 10, 17),
    ),
  ];
}

void main() {
  test('bundled composite ore wiki manifest is available to the app', () async {
    final manifest = await rootBundle.loadString(
      'assets/packs/2026.10.17-composite.1/manifest.json',
    );
    expect(manifest, contains('2026.10.17-composite.1'));
    expect(manifest, contains('USER_CONFIRMED_CAPTURE'));
    expect(manifest, contains('Unknown; live game observed'));
  });

  testWidgets('opens the desktop dashboard with source status', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = _DashboardStore();
    await tester.pumpWidget(ForgeCompanionApp(database: database));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(find.text('Your forge at a glance'), findsOneWidget);
    expect(find.text('Inventory'), findsNothing);
    expect(find.text('Optimizer'), findsNothing);
    expect(find.text('Ore entries in catalog'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('language switches in place and persists across restarts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final appDirectory = await _runAsync(
      tester,
      () => Directory.systemTemp.createTemp('forge-language-test-'),
    );
    addTearDown(
      () => _runAsync(tester, () => appDirectory.delete(recursive: true)),
    );

    Future<void> pumpApp() async {
      await tester.pumpWidget(
        ForgeCompanionApp(
          database: _DashboardStore(),
          appDirectory: appDirectory,
        ),
      );
      await _pumpAndSettleBounded(tester);
    }

    Future<void> chooseLanguage(
      String label, {
      required String settingsLabel,
    }) async {
      await tester.tap(find.text(settingsLabel).first);
      await _pumpAndSettleBounded(tester);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await _pumpAndSettleBounded(tester);
      await tester.tap(find.text(label).last);
      await _pumpAndSettleBounded(tester);
    }

    await pumpApp();
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Your forge at a glance'), findsOneWidget);
    expect(await File('${appDirectory.path}/ui-language.txt').exists(), isFalse);

    await chooseLanguage('Русский', settingsLabel: 'Settings');
    await _waitForFileContents(
      tester,
      File('${appDirectory.path}/ui-language.txt'),
      'ru',
    );
    expect(find.text('Обзор'), findsOneWidget);
    expect(find.text('Настройки'), findsWidgets);
    await tester.tap(find.text('Обзор').first);
    await _pumpAndSettleBounded(tester);
    expect(find.text('Кузница: обзор'), findsOneWidget);
    expect(
      await _runAsync(
        tester,
        () => File('${appDirectory.path}/ui-language.txt').readAsString(),
      ),
      'ru',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpApp();
    await _waitForLocalizedWidget(tester, find.text('Кузница: обзор'));
    expect(find.text('Кузница: обзор'), findsOneWidget);
    await chooseLanguage('English', settingsLabel: 'Настройки');
    await _waitForFileContents(
      tester,
      File('${appDirectory.path}/ui-language.txt'),
      'en',
    );
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Settings'), findsWidgets);
    await tester.tap(find.text('Dashboard').first);
    await _pumpAndSettleBounded(tester);
    expect(find.text('Your forge at a glance'), findsOneWidget);
    expect(
      await _runAsync(
        tester,
        () => File('${appDirectory.path}/ui-language.txt').readAsString(),
      ),
      'en',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpApp();
    await _waitForLocalizedWidget(tester, find.text('Your forge at a glance'));
    expect(find.text('Your forge at a glance'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Russian layout opens all primary screens at 1280 by 720', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final appDirectory = await Directory.systemTemp.createTemp(
      'forge-russian-layout-',
    );
    addTearDown(() => appDirectory.delete(recursive: true));
    await tester.pumpWidget(
      ForgeCompanionApp(
        database: _DashboardStore(),
        appDirectory: appDirectory,
      ),
    );
    await _pumpAndSettleBounded(tester);
    await tester.tap(find.text('Settings').first);
    await _pumpAndSettleBounded(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await _pumpAndSettleBounded(tester);
    await tester.tap(find.text('Русский').last);
    await _pumpAndSettleBounded(tester);

    for (final label in [
      'Обзор',
      'Кузница',
      'Сравнение',
    ]) {
      await tester.tap(find.text(label).first);
      await _pumpAndSettleBounded(tester);
      expect(tester.takeException(), isNull, reason: 'screen: $label');
    }
    await tester.tap(find.text('ДАННЫЕ / ВИКИ').first);
    await _pumpAndSettleBounded(tester);
    for (final label in [
      'Руды',
      'Состояние данных',
      'Проверка вики',
    ]) {
      await tester.tap(find.text(label).first);
      await _pumpAndSettleBounded(tester);
      expect(tester.takeException(), isNull, reason: 'screen: $label');
    }
    for (final label in [
      'Настройки',
    ]) {
      await tester.tap(find.text(label).first);
      await _pumpAndSettleBounded(tester);
      expect(tester.takeException(), isNull, reason: 'screen: $label');
    }
  });

  testWidgets('Russian UI keeps ore and user recipe names unchanged', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final appDirectory = await Directory.systemTemp.createTemp(
      'forge-russian-data-labels-',
    );
    addTearDown(() => appDirectory.delete(recursive: true));
    await tester.pumpWidget(
      ForgeCompanionApp(
        database: _LocalizationStore(),
        appDirectory: appDirectory,
      ),
    );
    await _pumpAndSettleBounded(tester);
    await tester.tap(find.text('Settings').first);
    await _pumpAndSettleBounded(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await _pumpAndSettleBounded(tester);
    await tester.tap(find.text('Русский').last);
    await _pumpAndSettleBounded(tester);

    await tester.tap(find.text('ДАННЫЕ / ВИКИ').first);
    await _pumpAndSettleBounded(tester);
    await tester.tap(find.text('Руды').first);
    await _pumpAndSettleBounded(tester);
    expect(find.text('Aite'), findsOneWidget);

    await tester.tap(find.text('Сравнение').first);
    await _pumpAndSettleBounded(tester);
    expect(find.text('Dashboard'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard, forge, and embedded composition search fit a 1280 by 720 window', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ForgeCompanionApp(database: _DashboardStore()));
    await _pumpAndSettleBounded(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Forge').first);
    await _pumpAndSettleBounded(tester);
    expect(find.text('Test recipe'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Find ore composition'));
    await _pumpAndSettleBounded(tester);
    expect(find.text('Suggested ore compositions'), findsOneWidget);
    expect(find.text('No rankable mixes. Add multiplier values to the catalog first.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard adapts to laptop, desktop, and 125 percent scaling', (tester) async {
    final database = _DashboardStore();
    for (final viewport in [
      (size: const Size(1280, 720), ratio: 1.0),
      (size: const Size(1366, 768), ratio: 1.0),
      (size: const Size(1920, 1080), ratio: 1.0),
      (size: const Size(1280, 720), ratio: 1.25),
    ]) {
      tester.view.physicalSize = viewport.size;
      tester.view.devicePixelRatio = viewport.ratio;
      await tester.pumpWidget(ForgeCompanionApp(database: database));
      await _pumpAndSettleBounded(tester);
      expect(find.text('Open Forge'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Verification creates a dated session', (tester) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = _VerificationStore();
    await tester.pumpWidget(
      ForgeCompanionApp(
        database: database,
        evidenceDirectory: Directory.systemTemp,
      ),
    );
    await _pumpAndSettleBounded(tester);
    await tester.tap(find.text('DATA / RESEARCH').first);
    await _pumpAndSettleBounded(tester);
    await tester.tap(find.text('Wiki review').first);
    await _pumpAndSettleBounded(tester);
    expect(find.text('Session queue'), findsOneWidget);
    await tester.tap(find.text('New session'));
    await _pumpAndSettleBounded(tester);
    await tester.enterText(
      find.widgetWithText(
        TextField,
        'Official game version / update (optional)',
      ),
      'Update test 1',
    );
    await tester.tap(find.text('Create'));
    await _pumpAndSettleBounded(tester);
    expect(find.textContaining('Update test 1 · Ore'), findsOneWidget);
  });
}

Future<void> _pumpAndSettleBounded(WidgetTester tester) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (!tester.binding.hasScheduledFrame) return;
  }
  throw TestFailure('Widget tree did not settle within 100 frames.');
}

Future<T> _runAsync<T>(
  WidgetTester tester,
  Future<T> Function() callback,
) async {
  final result = await tester.runAsync(callback);
  return result as T;
}

Future<String> _waitForFileContents(
  WidgetTester tester,
  File file,
  String expected,
) => _runAsync(tester, () async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (DateTime.now().isBefore(deadline)) {
    if (await file.exists() && await file.readAsString() == expected) {
      return expected;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  throw StateError('Timed out waiting for ${file.path} to contain $expected');
});

Future<void> _waitForLocalizedWidget(
  WidgetTester tester,
  Finder finder,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (DateTime.now().isBefore(deadline)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for localized widget: $finder');
}
