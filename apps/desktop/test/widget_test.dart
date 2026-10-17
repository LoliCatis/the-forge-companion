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
  Future<List<InventoryRecord>> getInventory({DataPolicy policy = DataPolicy.bestAvailable}) async => [];
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
      query.isEmpty || 'test ore'.contains(query.toLowerCase())
      ? const [
          OreRecord(
            id: 'test-ore',
            name: 'Test Ore',
            rarity: 'Epic',
            multiplier: 2.25,
            price: 12.75,
            source: 'community',
            verificationStatus: 'COMMUNITY',
            confidence: 0.6,
          ),
        ]
      : [];

  @override
  Future<List<InventoryRecord>> getInventory({DataPolicy policy = DataPolicy.bestAvailable}) async => const [
    InventoryRecord(
      oreId: 'test-ore',
      oreName: 'Test Ore',
      quantity: 3,
      protectedQuantity: 0,
      verificationStatus: 'COMMUNITY',
      multiplier: 2.25,
      rarity: 'Epic',
      confidence: 0.6,
    ),
  ];

  @override
  Future<List<SavedBuildRecord>> getSavedBuilds() async => [
    SavedBuildRecord(
      id: 'user-recipe',
      name: 'Dashboard',
      recipe: const {'test-ore': 3},
      createdAt: DateTime.utc(2026, 10, 17),
    ),
  ];
}

void main() {
  test('bundled bootstrap pack manifest is available to the app', () async {
    final manifest = await rootBundle.loadString(
      'assets/packs/2026.10.17-bootstrap.1/manifest.json',
    );
    expect(manifest, contains('2026.10.17-bootstrap.1'));
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
    expect(find.text('Inventory'), findsWidgets);
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
      await _pumpForUi(tester);
    }

    Future<void> chooseLanguage(
      String label, {
      required String settingsLabel,
    }) async {
      await tester.tap(find.text(settingsLabel).first);
      await _pumpForUi(tester);
      final languageCode = label == 'Русский' ? 'ru' : 'en';
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      await tester.runAsync(() async {
        dropdown.onChanged?.call(languageCode);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return true;
      });
      await _pumpForUi(tester);
    }

    await pumpApp();
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Your forge at a glance'), findsOneWidget);
    expect(
      await _runAsync(
        tester,
        () => File('${appDirectory.path}/ui-language.txt').exists(),
      ),
      isFalse,
    );

    await chooseLanguage('Русский', settingsLabel: 'Settings');
    expect(find.text('Обзор'), findsOneWidget);
    expect(find.text('Настройки'), findsWidgets);
    await tester.tap(find.text('Обзор').first);
    await _pumpForUi(tester);
    expect(find.text('Кузница: обзор'), findsOneWidget);
    expect(
      await _waitForFileContents(
        tester,
        File('${appDirectory.path}/ui-language.txt'),
        'ru',
      ),
      'ru',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpApp();
    await _pumpUntilText(tester, find.text('Кузница: обзор'));
    expect(find.text('Кузница: обзор'), findsOneWidget);
    await chooseLanguage('English', settingsLabel: 'Настройки');
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
    await tester.tap(find.text('Dashboard').first);
    await _pumpForUi(tester);
    expect(find.text('Your forge at a glance'), findsOneWidget);
    expect(
      await _waitForFileContents(
        tester,
        File('${appDirectory.path}/ui-language.txt'),
        'en',
      ),
      'en',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpApp();
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
    final appDirectory = await _runAsync(
      tester,
      () => Directory.systemTemp.createTemp('forge-russian-layout-'),
    );
    addTearDown(
      () => _runAsync(tester, () => appDirectory.delete(recursive: true)),
    );
    await tester.pumpWidget(
      ForgeCompanionApp(
        database: _DashboardStore(),
        appDirectory: appDirectory,
      ),
    );
    await _pumpForUi(tester);
    await tester.tap(find.text('Settings').first);
    await _pumpForUi(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await _pumpForUi(tester);
    await tester.tap(find.text('Русский').last);
    await _pumpForUi(tester);

    for (final label in [
      'Обзор',
      'Инвентарь',
      'Кузница',
      'Оптимизатор',
      'Сравнение',
      'Руды',
      'Состояние данных',
      'Проверка',
      'Настройки',
    ]) {
      await tester.tap(find.text(label).first);
      await _pumpForUi(tester);
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
    final appDirectory = await _runAsync(
      tester,
      () => Directory.systemTemp.createTemp('forge-russian-data-labels-'),
    );
    addTearDown(
      () => _runAsync(tester, () => appDirectory.delete(recursive: true)),
    );
    await tester.pumpWidget(
      ForgeCompanionApp(
        database: _LocalizationStore(),
        appDirectory: appDirectory,
      ),
    );
    await _pumpForUi(tester);
    await tester.tap(find.text('Settings').first);
    await _pumpForUi(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await _pumpForUi(tester);
    await tester.tap(find.text('Русский').last);
    await _pumpForUi(tester);

    await tester.tap(find.text('Инвентарь').first);
    await _pumpForUi(tester);
    expect(find.text('Test Ore'), findsOneWidget);
    expect(find.text('2.250×'), findsOneWidget);

    await tester.tap(find.text('Руды').first);
    await _pumpForUi(tester);
    expect(find.text('Test Ore'), findsOneWidget);

    await tester.tap(find.text('Сравнение').first);
    await _pumpForUi(tester);
    expect(find.text('Dashboard'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard and inventory fit a 1280 by 720 window', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ForgeCompanionApp(database: _DashboardStore()));
    await _pumpForUi(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Inventory').first);
    await _pumpForUi(tester);
    expect(find.text('Available to forge'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Forge').first);
    await _pumpForUi(tester);
    expect(find.text('Current recipe'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Optimizer').first);
    await _pumpForUi(tester);
    expect(find.text('Build optimizer'), findsOneWidget);
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
      await _pumpForUi(tester);
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
    await _pumpForUi(tester);
    await tester.tap(find.text('Verification').first);
    await _pumpForUi(tester);
    expect(find.text('Session queue'), findsOneWidget);
    await tester.tap(find.text('New session'));
    await _pumpForUi(tester);
    await tester.enterText(
      find.widgetWithText(
        TextField,
        'Official game version / update (optional)',
      ),
      'Update test 1',
    );
    await tester.tap(find.text('Create'));
    await _pumpForUi(tester);
    expect(find.textContaining('Update test 1 · Ore'), findsOneWidget);
  });
}

Future<void> _pumpForUi(WidgetTester tester) async {
  await tester.pump();
  for (var frame = 0; frame < 5; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpUntilText(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for localized widget: $finder');
}

Future<T> _runAsync<T>(
  WidgetTester tester,
  Future<T> Function() callback,
) async {
  final result = await tester.runAsync(callback);
  if (result == null) throw StateError('Widget test async operation failed.');
  return result as T;
}

Future<String> _waitForFileContents(
  WidgetTester tester,
  File file,
  String expected,
) => _runAsync(tester, () async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (DateTime.now().isBefore(deadline)) {
    if (await file.exists()) {
      final contents = await file.readAsString();
      if (contents == expected) return contents;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  throw StateError('Timed out waiting for ${file.path} to contain $expected');
});
