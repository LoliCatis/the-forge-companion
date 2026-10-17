import 'package:flutter/widgets.dart';

import 'startup/startup_bootstrap.dart';
import 'startup/startup_gate.dart';

export 'app/app.dart' show ForgeCompanionApp, CompanionShell;
export 'startup/startup_gate.dart' show StartupGate;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appDirectory = defaultAppDirectory();
  StartupLog? log;
  Object? logSetupError;
  try {
    log = await StartupLog.create(appDirectory);
    await log.write('App start; version: $startupAppVersion');
    await log.write('Bundled pack version: $bundledPackVersion');
  } catch (error) {
    logSetupError = error;
  }

  try {
    await log?.write('runApp reached');
  } catch (error) {
    logSetupError ??= error;
    log = null;
  }
  runApp(
    StartupGate(
      appDirectory: appDirectory,
      log: log,
      logSetupError: logSetupError,
    ),
  );
}
