part of '../../app/app.dart';

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({
    required this.language,
    required this.onLanguageChanged,
    this.appDirectory,
  });
  final String language;
  final ValueChanged<String> onLanguageChanged;
  final Directory? appDirectory;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  bool _checkingUpdate = false;
  double? _downloadProgress;
  String? _updateError;

  Future<void> _checkForUpdates() async {
    if (!Platform.isWindows) {
      setState(() => _updateError = 'This portable update is available for Windows builds only.');
      return;
    }
    setState(() {
      _checkingUpdate = true;
      _downloadProgress = null;
      _updateError = null;
    });
    try {
      final update = await const AppUpdateService().checkForUpdate(
        currentCommit: appBuildCommit,
        currentVersion: appBuildVersion,
      );
      if (!mounted) return;
      if (update == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('No update available')),
        );
        return;
      }
      final install = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const AppText('Update available'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(update.releaseName, translate: false),
              const SizedBox(height: 6),
              AppText('Version: $appBuildVersion → ${update.version}'),
              AppText('Commit: ${_shortCommit(appBuildCommit)} → ${_shortCommit(update.commit)}'),
              AppText('Data version: ${update.dataVersion}'),
              AppText('Build date (UTC): ${update.buildDateUtc}'),
              if (update.releaseNotes.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                AppText('Changes', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    child: AppText(update.releaseNotes, translate: false),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const AppText(
                'The app will close and reopen to finish installing the update.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AppText('Not now'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.download_outlined),
              label: const AppText('Install now'),
            ),
          ],
        ),
      );
      if (install != true || !mounted) return;
      final appDirectory = widget.appDirectory;
      if (appDirectory == null) {
        throw StateError('The application data directory is unavailable.');
      }
      final service = const AppUpdateService();
      final stage = await service.downloadAndStage(
        update,
        appDataDirectory: appDirectory,
        onProgress: (value) {
          if (mounted) setState(() => _downloadProgress = value);
        },
      );
      await service.scheduleInstall(
        stage: stage,
        appDataDirectory: appDirectory,
        update: update,
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      exit(0);
    } catch (error) {
      if (mounted) setState(() => _updateError = '$error');
    } finally {
      if (mounted) {
        setState(() {
          _checkingUpdate = false;
          _downloadProgress = null;
        });
      }
    }
  }

  String _shortCommit(String value) =>
      value == 'development' ? value : value.substring(0, math.min(7, value.length));

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Settings',
    subtitle: 'Local-first prototype settings.',
    child: _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText('Storage', style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          AppText(
            'Ore catalog, recipes, observations, and data source records are stored locally in SQLite.',
            style: TextStyle(color: _muted),
          ),
          SizedBox(height: 16),
          AppText('Network access', style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          AppText(
            'The app does not collect game data. Application updates require your confirmation.',
            style: TextStyle(color: _muted),
          ),
          SizedBox(height: 20),
          AppText('Interface language', style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String>(
              initialValue: widget.language,
              decoration: InputDecoration(labelText: appLocalizedText(context, 'Language')),
              items: const [
                DropdownMenuItem(value: 'en', child: AppText('English')),
                DropdownMenuItem(value: 'ru', child: AppText('Русский')),
              ],
              onChanged: (value) {
                if (value != null) widget.onLanguageChanged(value);
              },
            ),
          ),
          SizedBox(height: 24),
          AppText('Application updates', style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          AppText(
            'Check the latest portable Windows build from the official project GitHub releases. Installation starts only after confirmation.',
            style: TextStyle(color: _muted),
          ),
          SizedBox(height: 12),
          if (Platform.isMacOS) ...[
            AppText('Not supported yet', style: TextStyle(color: _muted)),
            SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: _checkingUpdate || !Platform.isWindows
                ? null
                : _checkForUpdates,
            icon: Icon(_checkingUpdate ? Icons.hourglass_top : Icons.system_update_alt),
            label: AppText(_checkingUpdate ? 'Loading updates…' : 'Check for updates'),
          ),
          if (_checkingUpdate) ...[
            SizedBox(height: 10),
            LinearProgressIndicator(value: _downloadProgress),
          ],
          if (_updateError != null) ...[
            SizedBox(height: 8),
            AppText('Update check failed: $_updateError', style: TextStyle(color: Colors.orangeAccent)),
          ],
        ],
      ),
    ),
  );
}

class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => _Page(
    title: title,
    subtitle: 'Planned after the first working version.',
    child: const _Notice(
      icon: Icons.construction_outlined,
      text: 'This section will use the same source tracking and verification rules as the current data layer.',
    ),
  );
}
