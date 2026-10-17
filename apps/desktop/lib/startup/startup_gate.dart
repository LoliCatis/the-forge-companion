import 'dart:io';

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/update_service.dart';
import 'startup_bootstrap.dart';

class StartupGate extends StatefulWidget {
  const StartupGate({
    super.key,
    required this.appDirectory,
    required this.log,
    this.bootstrap,
    this.logSetupError,
  });

  final Directory appDirectory;
  final StartupLog? log;
  final Future<StartupBootstrapResult> Function()? bootstrap;
  final Object? logSetupError;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  StartupBootstrapResult? _result;
  Object? _error;
  String? _openError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _start(initial: true);
  }

  Future<void> _start({bool initial = false}) async {
    if (!initial) {
      setState(() {
        _loading = true;
        _error = null;
        _openError = null;
      });
    }
    try {
      final result = await (widget.bootstrap ??
          () => StartupBootstrap(
                appDirectory: widget.appDirectory,
                log: widget.log,
              ).run())();
      try {
        await const AppUpdateService().confirmSuccessfulStartup(
          appDataDirectory: result.appDirectory,
          currentCommit: appBuildCommit,
          writeLog: (message) async {
            await widget.log?.write(message);
          },
        );
      } catch (error) {
        await widget.log?.write('Update startup confirmation failed: $error');
      }
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openLogs() async {
    final logDirectory = widget.log?.directory ??
        Directory('${widget.appDirectory.path}${Platform.pathSeparator}logs');
    try {
      await logDirectory.create(recursive: true);
      if (Platform.isWindows) {
        await Process.start('explorer.exe', [logDirectory.path]);
      } else if (Platform.isMacOS) {
        await Process.start('open', [logDirectory.path]);
      } else {
        setState(() => _openError = 'Open this folder manually: ${logDirectory.path}');
        return;
      }
    } catch (error) {
      if (mounted) setState(() => _openError = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (result != null) {
      return ForgeCompanionApp(
        database: result.database,
        appDirectory: result.appDirectory,
        evidenceDirectory: Directory(
          '${result.appDirectory.path}${Platform.pathSeparator}evidence',
        ),
      );
    }

    return MaterialApp(
      title: 'The Forge Companion startup',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xff8155d9), useMaterial3: true),
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: _loading
                    ? const _StartupLoadingView()
                    : StartupFailureView(
                        error: _error ??
                            widget.logSetupError ??
                            'Unknown startup error',
                        logPath: widget.log?.file.path ??
                            '${widget.appDirectory.path}'
                                '${Platform.pathSeparator}logs'
                                '${Platform.pathSeparator}startup.log',
                        openError: _openError,
                        onRetry: _start,
                        onOpenLogs: _openLogs,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StartupLoadingView extends StatelessWidget {
  const _StartupLoadingView();

  @override
  Widget build(BuildContext context) => const Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircularProgressIndicator(),
      SizedBox(height: 24),
      Text('Starting The Forge Companion…'),
    ],
  );
}

class StartupFailureView extends StatelessWidget {
  const StartupFailureView({
    super.key,
    required this.error,
    required this.logPath,
    required this.onRetry,
    required this.onOpenLogs,
    this.openError,
  });

  final Object error;
  final String logPath;
  final VoidCallback onRetry;
  final VoidCallback onOpenLogs;
  final String? openError;

  @override
  Widget build(BuildContext context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red),
        const SizedBox(height: 16),
        Text('The app could not finish starting',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        const Text('Startup step and error:'),
        const SizedBox(height: 8),
        SelectableText(formatStartupError(error)),
        if (error is StartupBootstrapFailure) ...[
          const SizedBox(height: 8),
          const Text('Stack trace:'),
          const SizedBox(height: 4),
          SelectableText(startupErrorStack(error)),
        ],
        const SizedBox(height: 12),
        const Text('Diagnostic log:'),
        SelectableText(logPath),
        if (openError != null) ...[
          const SizedBox(height: 8),
          SelectableText('Could not open log folder: $openError'),
        ],
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
            OutlinedButton.icon(
              onPressed: onOpenLogs,
              icon: const Icon(Icons.folder_open),
              label: const Text('Open diagnostic location'),
            ),
          ],
        ),
      ],
    );
}
