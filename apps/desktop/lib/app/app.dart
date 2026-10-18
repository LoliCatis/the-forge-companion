import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:calculation_engine/calculation_engine.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart' as selector;
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:game_data/game_data.dart';
import 'package:image/image.dart' as img;

import 'update_service.dart';

part 'theme.dart';
part 'localization.dart';
part 'navigation.dart';
part '../widgets/page_layout.dart';
part '../widgets/common.dart';
part '../screens/dashboard/dashboard_screen.dart';
part '../screens/forge/forge_screen.dart';
part '../screens/optimizer/optimizer_screen.dart';
part '../screens/compare/compare_screen.dart';
part '../screens/ores/ores_screen.dart';
part '../screens/data_health/data_health_screen.dart';
part '../screens/settings/settings_screen.dart';
part '../screens/verification/verification_screen.dart';

class ForgeCompanionApp extends StatefulWidget {
  const ForgeCompanionApp({
    super.key,
    required this.database,
    this.evidenceDirectory,
    this.appDirectory,
  });
  final GameDataStore database;
  final Directory? evidenceDirectory;
  final Directory? appDirectory;

  @override
  State<ForgeCompanionApp> createState() => _ForgeCompanionAppState();
}

class _ForgeCompanionAppState extends State<ForgeCompanionApp> {
  Locale _locale = const Locale('en');

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final directory = widget.appDirectory;
    if (directory == null) return;
    try {
      final file = File(p.join(directory.path, 'ui-language.txt'));
      if (!await file.exists()) return;
      final language = (await file.readAsString()).trim();
      if (language == 'ru' && mounted) {
        setState(() => _locale = const Locale('ru'));
      }
    } on FileSystemException {
      // English remains the fallback if the optional preference cannot be read.
    }
  }

  Future<void> _setLanguage(String language) async {
    final nextLocale = Locale(language == 'ru' ? 'ru' : 'en');
    setState(() => _locale = nextLocale);
    final directory = widget.appDirectory;
    if (directory == null) return;
    try {
      await directory.create(recursive: true);
      await File(p.join(directory.path, 'ui-language.txt'))
          .writeAsString(nextLocale.languageCode);
    } on FileSystemException {
      // Keep the in-memory language selection even if it cannot be persisted.
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'The Forge Companion',
    debugShowCheckedModeBanner: false,
    locale: _locale,
    supportedLocales: const [Locale('en'), Locale('ru')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: buildAppTheme(),
    home: CompanionShell(
      database: widget.database,
      appDirectory: widget.appDirectory,
      evidenceDirectory: widget.evidenceDirectory,
      language: _locale.languageCode,
      onLanguageChanged: _setLanguage,
    ),
  );
}
