part of '../../app/app.dart';

class _VerificationSessionDraft {
  const _VerificationSessionDraft({
    required this.label,
    required this.date,
    required this.type,
    this.world,
    this.notes,
  });
  final String label;
  final DateTime date;
  final String type;
  final String? world;
  final String? notes;
}

class _VerificationSessionDialog extends StatefulWidget {
  const _VerificationSessionDialog({this.existing});
  final VerificationSession? existing;
  @override
  State<_VerificationSessionDialog> createState() =>
      _VerificationSessionDialogState();
}

class _VerificationSessionDialogState
    extends State<_VerificationSessionDialog> {
  late final TextEditingController _label = TextEditingController(
    text: widget.existing?.officialGameVersion ?? '',
  );
  late final TextEditingController _world = TextEditingController(
    text: widget.existing?.worldLocation,
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.existing?.notes,
  );
  late DateTime _date = widget.existing?.sessionDate ?? DateTime.now();
  late String _type = widget.existing?.checkType ?? 'Ore';
  @override
  void dispose() {
    _label.dispose();
    _world.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: AppText(
      widget.existing == null
          ? 'New verification session'
          : 'Edit verification session',
    ),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _label,
            decoration: InputDecoration(
              labelText: appLocalizedText(context, 'Official game version / update (optional)'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppText(
                  'Date: ${MaterialLocalizations.of(context).formatMediumDate(_date)}',
                ),
              ),
              TextButton(
                onPressed: () async {
                  final chosen = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (chosen != null && mounted) setState(() => _date = chosen);
                },
                child: const AppText('Choose'),
              ),
            ],
          ),
          TextField(
            controller: _world,
            decoration: InputDecoration(
              labelText: appLocalizedText(context, 'World / location (optional)'),
            ),
          ),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: InputDecoration(labelText: appLocalizedText(context, 'Check type')),
            items:
                const ['Ore', 'Weapon', 'Trait', 'Probability', 'Craft Result']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: AppText(value)),
                    )
                    .toList(),
            onChanged: (value) => setState(() => _type = value ?? 'Ore'),
          ),
          TextField(
            controller: _notes,
            decoration: InputDecoration(labelText: appLocalizedText(context, 'Notes')),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const AppText('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          Navigator.pop(
            context,
            _VerificationSessionDraft(
              label: _label.text.trim(),
              date: _date,
              type: _type,
              world: _world.text.trim().isEmpty ? null : _world.text.trim(),
              notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            ),
          );
        },
        child: AppText(widget.existing == null ? 'Create' : 'Save changes'),
      ),
    ],
  );
}

class VerificationPage extends StatefulWidget {
  const VerificationPage({
    super.key,
    required this.database,
    required this.evidenceDirectory,
  });
  final GameDataStore database;
  final Directory evidenceDirectory;
  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  List<VerificationSession> _sessions = [];
  List<EvidenceRecord> _evidence = [];
  List<FieldObservation> _queue = [];
  List<VerificationTarget> _targets = [];
  final Set<String> _conflictIds = {};
  VerificationSession? _session;
  EvidenceRecord? _selectedEvidence;
  FieldObservation? _selectedObservation;
  String _filter = 'All';
  String? _error;
  bool _cropMode = false;
  Offset? _cropStart;
  Rect? _cropRect;
  Size? _viewerSize;
  final _entityId = TextEditingController();
  final _fieldName = TextEditingController();
  final _value = TextEditingController();
  final _notes = TextEditingController();
  String _entityType = 'ORE';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _entityId.dispose();
    _fieldName.dispose();
    _value.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final sessions = await widget.database.getVerificationSessions();
    final session = _session == null
        ? (sessions.isEmpty ? null : sessions.first)
        : sessions.where((s) => s.id == _session!.id).firstOrNull;
    final evidence = session == null
        ? <EvidenceRecord>[]
        : await widget.database.getEvidenceForSession(session.id);
    final queue = session == null
        ? <FieldObservation>[]
        : await widget.database.getSessionObservations(session.id);
    final targets = session == null
        ? <VerificationTarget>[]
        : await widget.database.getVerificationTargets(session.id);
    final conflicts = <String>{};
    for (final observation in queue) {
      final resolved = await widget.database.resolveField(
        entityType: observation.entityType,
        entityId: observation.entityId,
        fieldName: observation.fieldName,
      );
      if (resolved.conflicting) conflicts.add(observation.id);
    }
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _session = session;
      _evidence = evidence;
      _queue = queue;
      _targets = targets;
      _conflictIds
        ..clear()
        ..addAll(conflicts);
      _selectedObservation = _selectedObservation == null
          ? null
          : queue.where((o) => o.id == _selectedObservation!.id).firstOrNull;
      if (_selectedEvidence != null) {
        _selectedEvidence = evidence
            .where((e) => e.id == _selectedEvidence!.id)
            .firstOrNull;
      }
    });
  }

  Future<void> _createSession({VerificationSession? existing}) async {
    final draft = await showDialog<_VerificationSessionDraft>(
      context: context,
      builder: (context) => _VerificationSessionDialog(existing: existing),
    );
    if (draft != null) {
      final now = DateTime.now().toUtc();
      final session = VerificationSession(
        id: existing?.id ?? 'session-${now.microsecondsSinceEpoch}',
        gameUpdateLabel: draft.label.isEmpty
            ? 'Unknown official update'
            : draft.label,
        officialGameVersion: draft.label.isEmpty ? null : draft.label,
        observedLiveAt: draft.date,
        sessionDate: draft.date,
        checkType: draft.type,
        worldLocation: draft.world,
        notes: draft.notes,
        createdAt: existing?.createdAt ?? now,
      );
      if (existing == null) {
        await widget.database.createVerificationSession(session);
      } else {
        await widget.database.updateVerificationSession(session);
      }
      _session = session;
      await _reload();
    }
  }

  Future<void> _importBytes(Uint8List bytes, String filename) async {
    final session = _session;
    if (session == null) {
      setState(
        () =>
            _error = 'Create a verification session before importing evidence.',
      );
      return;
    }
    try {
      final item =
          await EvidenceVault(
            rootDirectory: widget.evidenceDirectory,
            database: widget.database,
          ).importScreenshot(
            bytes: bytes,
            originalFilename: filename,
            sessionId: session.id,
            gameUpdateLabel: session.gameUpdateLabel,
          );
      setState(() {
        _selectedEvidence = item;
        _error = null;
      });
      await _reload();
    } on Object catch (error) {
      setState(() => _error = error.toString());
    }
  }

  Future<void> _pickImage() async {
    try {
      final file = await selector.openFile(
        acceptedTypeGroups: [
          const selector.XTypeGroup(
            label: 'Screenshots',
            extensions: ['png', 'jpg', 'jpeg', 'webp'],
          ),
        ],
      );
      if (file != null) await _importBytes(await file.readAsBytes(), file.name);
    } on Object catch (error) {
      setState(() => _error = error.toString());
    }
  }

  Future<void> _saveCrop() async {
    final original = _selectedEvidence;
    final rect = _cropRect;
    if (original == null || rect == null || rect.width < 5 || rect.height < 5) {
      return;
    }
    final source = img.decodeImage(
      await File(original.reference).readAsBytes(),
    );
    if (source == null) return;
    if (!mounted) return;
    final size = _viewerSize ?? MediaQuery.sizeOf(context);
    final scale = math.min(
      size.width / source.width,
      size.height / source.height,
    );
    final shownWidth = source.width * scale;
    final shownHeight = source.height * scale;
    final origin = Offset(
      (size.width - shownWidth) / 2,
      (size.height - shownHeight) / 2,
    );
    final left = ((rect.left - origin.dx) / scale).round().clamp(
      0,
      source.width - 1,
    );
    final top = ((rect.top - origin.dy) / scale).round().clamp(
      0,
      source.height - 1,
    );
    final right = ((rect.right - origin.dx) / scale).round().clamp(
      left + 1,
      source.width,
    );
    final bottom = ((rect.bottom - origin.dy) / scale).round().clamp(
      top + 1,
      source.height,
    );
    final label = TextEditingController(text: 'field-crop');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Save crop'),
        content: TextField(
          controller: label,
          decoration: InputDecoration(labelText: appLocalizedText(context, 'Crop label')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Save crop'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final crop =
          await EvidenceVault(
            rootDirectory: widget.evidenceDirectory,
            database: widget.database,
          ).createCrop(
            original: original,
            x: left,
            y: top,
            width: right - left,
            height: bottom - top,
            label: label.text.trim(),
          );
      setState(() {
        _selectedEvidence = crop;
        _cropMode = false;
        _cropRect = null;
        _error = null;
      });
      await _reload();
    } on Object catch (error) {
      setState(() => _error = error.toString());
    }
  }

  Future<void> _addObservation() async {
    final session = _session;
    if (session == null ||
        _selectedEvidence == null ||
        _entityId.text.trim().isEmpty ||
        _fieldName.text.trim().isEmpty ||
        _value.text.trim().isEmpty) {
      return;
    }
    final now = DateTime.now().toUtc();
    await widget.database.upsertDataSource(
      const DataSourceRecord(
        id: 'verification-manual-game',
        name: 'Manual game observation',
        sourceType: 'IN_GAME_MANUAL',
      ),
    );
    Object value = _value.text.trim();
    final numeric = num.tryParse(_value.text.trim());
    if (numeric != null) value = numeric;
    await widget.database.addObservation(
      FieldObservation(
        id: 'obs-${now.microsecondsSinceEpoch}',
        entityType: _entityType,
        entityId: _entityId.text.trim().toLowerCase().replaceAll(' ', '-'),
        fieldName: _fieldName.text.trim(),
        value: value,
        sourceId: 'verification-manual-game',
        observedAt: session.sessionDate,
        gameVersion: session.officialGameVersion,
        verificationStatus: 'UNKNOWN',
        evidenceId: _selectedEvidence?.id,
        evidenceReference: _selectedEvidence?.reference,
        notes: _notes.text.trim(),
        reviewState: 'ENTERED',
        verificationSessionId: session.id,
      ),
    );
    _value.clear();
    _notes.clear();
    await _reload();
  }

  Future<void> _setPreferred(FieldObservation observation) async {
    await widget.database.setPreferredObservation(
      entityType: observation.entityType,
      entityId: observation.entityId,
      fieldName: observation.fieldName,
      observationId: observation.id,
    );
    await _reload();
  }

  Future<void> _saveCorrection(FieldObservation observation) async {
    final raw = _value.text.trim();
    final Object value = observation.fieldName == 'rocks'
        ? raw
              .split(RegExp(r'[;,]'))
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty)
              .toList()
        : num.tryParse(raw) ?? raw;
    await widget.database.updateEnteredObservation(
      id: observation.id,
      value: value,
      notes: _notes.text.trim(),
    );
    await _reload();
  }

  Future<void> _confirmGame(FieldObservation observation) async {
    final session = _session;
    final evidence = observation.evidenceId;
    if (session == null || evidence == null) return;
    try {
      await widget.database.confirmObservationAsInGameVerified(
        observationId: observation.id,
        gameVersion: session.officialGameVersion,
        evidenceId: evidence,
      );
      await _reload();
    } on Object catch (error) {
      setState(() => _error = error.toString());
    }
  }

  Future<void> _exportBundle() async {
    final session = _session;
    if (session == null) return;
    try {
      final bytes = await VerificationBundleService(widget.database)
          .exportSession(session.id);
      final path = p.join(
        widget.evidenceDirectory.path,
        'verification-${session.id}.zip',
      );
      await widget.evidenceDirectory.create(recursive: true);
      await File(path).writeAsBytes(bytes, flush: true);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText('Bundle exported: $path')));
      }
    } on Object catch (error) {
      setState(() => _error = error.toString());
    }
  }

  Future<void> _validateBundle() async {
    final file = await selector.openFile(
      acceptedTypeGroups: [
        const selector.XTypeGroup(
          label: 'Verification bundle',
          extensions: ['zip'],
        ),
      ],
    );
    if (file == null) return;
    try {
      final bundle = VerificationBundleService.validate(
        await file.readAsBytes(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText(
              'Valid bundle · schema ${bundle.manifest['schemaVersion']} · session ${bundle.manifest['sessionId']} · integrity checks passed. No data was installed.',
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText('Bundle validation failed: $error')),
        );
      }
    }
  }

  Future<void> _showCandidateDiff() async {
    final candidate = await widget.database.buildVerifiedCandidatePack();
    final diff = candidate.diff;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: AppText(
          'Verified candidate pack v${candidate.schemaVersion} · ${candidate.fieldValues.length} eligible fields',
        ),
        content: SizedBox(
          width: 520,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final entry in [
                ('Added', diff.added),
                ('Changed', diff.changed),
                ('Conflicts', diff.conflicts),
                ('Removed', diff.removed),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        '${entry.$1} (${entry.$2.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      for (final item in entry.$2) AppText('• $item'),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AppText('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _importRepositoryIntake() async {
    final selected = await selector.getDirectoryPath();
    if (selected == null) return;
    try {
      final result = await RepositoryIntakeImporter(widget.database)
          .importDirectory(
            Directory(selected),
            evidenceDirectory: widget.evidenceDirectory,
          );
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText(
              result.imported
                  ? 'Imported ${result.observationCount} observations, ${result.evidenceCount} screenshots; ${result.createdOreCount} new ores, ${result.mergedOreCount} merged. All remain ENTERED.'
                  : 'This intake was already imported; no changes made.',
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = 'Repository intake import failed: $error');
      }
    }
  }

  Future<void> _reviewEvidenceCard(EvidenceRecord evidence) async {
    final card = _queue
        .where((item) => item.evidenceId == evidence.id)
        .toList();
    if (card.isEmpty) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AppText('Review ${evidence.originalFilename ?? evidence.id}', translate: false),
        content: SizedBox(
          width: 640,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 220,
                width: double.infinity,
                child: Image.file(
                  File(evidence.reference),
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 8),
              AppText(
                '${card.length} transcribed fields · ${_session?.worldLocation ?? 'unknown location'} · observed ${_session?.observedLiveAt?.toIso8601String().substring(0, 10) ?? 'unknown date'}',
                style: const TextStyle(color: _muted),
              ),
              const Divider(),
              SizedBox(
                height: 190,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final item in card)
                      ListTile(
                        dense: true,
                        title: AppText('${item.entityId} · ${item.fieldName}', translate: false),
                        subtitle: AppText('${item.value} · ${item.reviewState}', translate: false),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const AppText(
                'Confirm only if the screenshot supports every listed field. This action marks this card IN_GAME_VERIFIED; an official update number is optional.',
                style: TextStyle(color: _muted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const AppText('Confirm card and verify fields'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    try {
      final count = await widget.database.confirmEvidenceCard(evidence.id);
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText('$count fields verified from this screenshot.'),
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _exportVerifiedOverlay() async {
    final candidate = await widget.database.buildVerifiedCandidatePack();
    if (candidate.verifiedObservations.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText(
              'No verified fields are eligible for an overlay yet.',
            ),
          ),
        );
      }
      return;
    }
    final dates =
        candidate.verifiedObservations
            .map(
              (item) => DateTime.tryParse(item['observedAt'] as String? ?? ''),
            )
            .whereType<DateTime>()
            .toList()
          ..sort();
    final observedAt = dates.last;
    final packId =
        '${observedAt.year}.${observedAt.month.toString().padLeft(2, '0')}.${observedAt.day.toString().padLeft(2, '0')}-verified.1';
    final overlay = {
      'format': 'the-forge-companion-verified-overlay',
      'schemaVersion': 1,
      'packId': packId,
      'baseDataVersion': candidate.sourceDataVersion,
      'officialGameVersion': candidate.verifiedObservations
          .map((item) => item['officialGameVersion'])
          .where((value) => value != null)
          .firstOrNull,
      'observations': candidate.verifiedObservations,
      'diff': {
        'added': candidate.diff.added,
        'changed': candidate.diff.changed,
        'conflicts': candidate.diff.conflicts,
      },
    };
    await widget.evidenceDirectory.create(recursive: true);
    final path = p.join(widget.evidenceDirectory.path, '$packId.json');
    await File(path).writeAsString(
      const JsonEncoder.withIndent('  ').convert(overlay),
      flush: true,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText('Verified overlay exported: $path')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(builder: (context, constraints) => Wrap(
          spacing: 8,
          runSpacing: 7,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: math.min(430.0, constraints.maxWidth),
              child: DropdownButton<VerificationSession>(
                isExpanded: true,
                value: _session,
                hint: const AppText('Select or create a verification session'),
                items: _sessions
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: AppText(
                          '${s.gameUpdateLabel} · ${s.checkType} · ${MaterialLocalizations.of(context).formatShortDate(s.sessionDate)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) async {
                  setState(() => _session = v);
                  await _reload();
                },
              ),
            ),
            OutlinedButton.icon(
              onPressed: _createSession,
              icon: const Icon(Icons.add),
              label: const AppText('New session'),
            ),
            OutlinedButton.icon(
              onPressed: _exportBundle,
              icon: const Icon(Icons.archive_outlined),
              label: const AppText('Export ZIP'),
            ),
            IconButton(
              tooltip: appLocalizedText(context, 'Validate ZIP'),
              onPressed: _validateBundle,
              icon: const Icon(Icons.fact_check_outlined),
            ),
            IconButton(
              tooltip: appLocalizedText(context, 'Import staged intake'),
              onPressed: _importRepositoryIntake,
              icon: const Icon(Icons.folder_open),
            ),
            IconButton(
              tooltip: appLocalizedText(context, 'Candidate diff'),
              onPressed: _showCandidateDiff,
              icon: const Icon(Icons.difference_outlined),
            ),
            IconButton(
              tooltip: appLocalizedText(context, 'Export verified overlay'),
              onPressed: _exportVerifiedOverlay,
              icon: const Icon(Icons.inventory_2_outlined),
            ),
          ],
        )),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: AppText(
              _error!,
              style: const TextStyle(color: Colors.orangeAccent),
            ),
          ),
        if (_session != null)
          TextButton.icon(
            onPressed: () => _createSession(existing: _session),
            icon: const Icon(Icons.edit_outlined),
            label: const AppText('Edit session'),
          ),
        const SizedBox(height: 12),
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) => constraints.maxWidth < 950
            ? ListView(children: [SizedBox(height: 235, child: _leftPane()), const SizedBox(height: 10), SizedBox(height: 540, child: _viewer()), const SizedBox(height: 10), SizedBox(height: 520, child: _entryPane())])
            : Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 258, child: _leftPane()),
              const SizedBox(width: 12),
              Expanded(flex: 5, child: _viewer()),
              const SizedBox(width: 12),
              SizedBox(width: 310, child: _entryPane()),
            ],
          )),
        ),
      ],
    ),
  );

  Widget _leftPane() => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF171D21),
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Expanded(
                child: AppText(
                  'Session queue',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: appLocalizedText(context, 'Import screenshot'),
                onPressed: _pickImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          child: Wrap(
            spacing: 5,
            runSpacing: 5,
            children:
                [
                      'All',
                      'CONFLICTS',
                      'ENTERED',
                      'REVIEWED',
                      'USER_CONFIRMED_CAPTURE',
                      'IN_GAME_VERIFIED',
                      'REJECTED',
                    ]
                    .map(
                      (state) => Padding(
                          padding: EdgeInsets.zero,
                        child: ChoiceChip(
                          label: AppText(
                            state == 'All'
                                ? 'All'
                                : (state == 'CONFLICTS'
                                      ? 'Conflicts'
                                      : _shortState(state)),
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: _filter == state,
                          onSelected: (_) => setState(() => _filter = state),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ),
        const Divider(height: 18),
        if (_targets.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 5),
            child: AppText(
              'Priority targets',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _muted,
              ),
            ),
          ),
          for (final target in _targets.take(5))
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: CircleAvatar(
                radius: 11,
                child: AppText(
                  '${target.priority}',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
              title: AppText(
                '${target.entityId} · ${target.fieldName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
              onTap: () => setState(() {
                _entityType = target.entityType;
                _entityId.text = target.entityId;
                _fieldName.text = target.fieldName;
              }),
            ),
          const Divider(height: 10),
        ],
        Expanded(
          child: ListView(
            children: [
              for (final observation in _queue.where(
                (o) =>
                    _filter == 'All' ||
                    (_filter == 'CONFLICTS'
                        ? _conflictIds.contains(o.id)
                        : o.reviewState == _filter),
              ))
                _queueTile(observation),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(10),
          child: AppText(
            '${_evidence.length} local evidence artifacts · ${_session?.gameUpdateLabel ?? 'No session'}',
            style: const TextStyle(color: _muted, fontSize: 10),
          ),
        ),
      ],
    ),
  );

  String _shortState(String value) => switch (value) {
    'ENTERED' => 'Unreviewed',
    'REVIEWED' => 'Needs confirmation',
    'USER_CONFIRMED_CAPTURE' => 'Confirmed capture',
    'IN_GAME_VERIFIED' => 'Game verified',
    'REJECTED' => 'Rejected',
    _ => value,
  };

  Widget _queueTile(FieldObservation o) {
    final evidence = _evidence.where((e) => e.id == o.evidenceId).firstOrNull;
    return ListTile(
      dense: true,
      selected: _selectedObservation?.id == o.id,
      onTap: () => setState(() {
        _selectedObservation = o;
        _selectedEvidence = evidence ?? _selectedEvidence;
        _entityType = o.entityType;
        _entityId.text = o.entityId;
        _fieldName.text = o.fieldName;
        _value.text = '${o.value ?? ''}';
        _notes.text = o.notes ?? '';
      }),
      title: AppText(
        '${o.entityId} · ${o.fieldName}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: AppText(
        '${o.value} · ${_conflictIds.contains(o.id) ? 'Conflict · ' : ''}${_shortState(o.reviewState)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      leading: evidence != null && File(evidence.reference).existsSync()
          ? Image.file(
              File(evidence.reference),
              width: 38,
              height: 38,
              fit: BoxFit.cover,
            )
          : const Icon(Icons.image_not_supported_outlined, size: 25),
    );
  }

  Widget _viewer() => DropTarget(
    onDragDone: (detail) async {
      for (final file in detail.files) {
        await _importBytes(await file.readAsBytes(), file.name);
      }
    },
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101416),
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              children: [
                Expanded(
                  child: AppText(
                    _selectedEvidence?.originalFilename ??
                        'Drop screenshot here or choose a file',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                ),
                const Spacer(),
                if (_selectedEvidence != null &&
                    _queue.any(
                      (item) =>
                          item.evidenceId == _selectedEvidence!.id &&
                          item.reviewState != 'IN_GAME_VERIFIED',
                    ))
                  FilledButton.tonalIcon(
                    onPressed: () => _reviewEvidenceCard(_selectedEvidence!),
                    icon: const Icon(Icons.verified_outlined, size: 16),
                    label: AppText(
                      'Review & confirm ${_queue.where((item) => item.evidenceId == _selectedEvidence!.id).length} fields',
                    ),
                  ),
                IconButton(
                  tooltip: appLocalizedText(context, 'Choose screenshot'),
                  onPressed: _pickImage,
                  icon: const Icon(Icons.folder_open, size: 18),
                ),
                IconButton(
                  tooltip: appLocalizedText(context, _cropMode ? 'Cancel crop' : 'Select crop'),
                  onPressed: _selectedEvidence == null
                      ? null
                      : () => setState(() {
                          _cropMode = !_cropMode;
                          _cropRect = null;
                        }),
                  icon: Icon(_cropMode ? Icons.close : Icons.crop, size: 18),
                ),
                if (_cropMode)
                  IconButton(
                    tooltip: appLocalizedText(context, 'Save crop as evidence'),
                    onPressed: _saveCrop,
                    icon: const Icon(Icons.save_outlined, size: 18),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _selectedEvidence == null
                ? const Center(
                    child: AppText(
                      'Import a PNG, JPG or WebP screenshot',
                      style: TextStyle(color: _muted),
                    ),
                  )
                : _imageViewer(),
          ),
        ],
      ),
    ),
  );

  Widget _imageViewer() {
    final file = File(_selectedEvidence!.reference);
    if (!file.existsSync()) {
      return const Center(
        child: AppText(
          'Evidence file is missing',
          style: TextStyle(color: Colors.orangeAccent),
        ),
      );
    }
    final image = Image.file(file, fit: BoxFit.contain);
    if (!_cropMode) {
      return InteractiveViewer(
        minScale: .35,
        maxScale: 6,
        child: Center(child: image),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewerSize = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => setState(() {
            _cropStart = d.localPosition;
            _cropRect = Rect.fromPoints(d.localPosition, d.localPosition);
          }),
          onPanUpdate: (d) => setState(
            () => _cropRect = Rect.fromPoints(_cropStart!, d.localPosition),
          ),
          onPanEnd: (_) {},
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(child: image),
              if (_cropRect != null)
                Positioned(
                  left: _cropRect!.left,
                  top: _cropRect!.top,
                  width: _cropRect!.width,
                  height: _cropRect!.height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: _accent, width: 2),
                      color: _accent.withValues(alpha: .15),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _entryPane() => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF171D21),
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(8),
    ),
    padding: const EdgeInsets.all(14),
    child: ListView(
      children: [
        const AppText(
          'Manual extraction',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const AppText(
          'Community examples remain labeled COMMUNITY. Screenshot values enter as ENTERED; confirmation is always explicit.',
          style: TextStyle(fontSize: 10, color: _muted),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _entityType,
          decoration: InputDecoration(labelText: appLocalizedText(context, 'Entity type')),
          items: const [
            'ORE',
            'WEAPON',
            'TRAIT',
            'PROBABILITY',
            'CRAFT_RESULT',
          ].map((v) => DropdownMenuItem(value: v, child: AppText(v))).toList(),
          onChanged: (v) => setState(() => _entityType = v ?? 'ORE'),
        ),
        TextField(
          controller: _entityId,
          decoration: InputDecoration(labelText: appLocalizedText(context, 'Entity id / name')),
        ),
        TextField(
          controller: _fieldName,
          decoration: InputDecoration(labelText: appLocalizedText(context, 'Field')),
        ),
        TextField(
          controller: _value,
          decoration: InputDecoration(labelText: appLocalizedText(context, 'Value')),
        ),
        TextField(
          controller: _notes,
          decoration: InputDecoration(labelText: appLocalizedText(context, 'Notes')),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<EvidenceRecord>(
          initialValue: _selectedEvidence,
          decoration: InputDecoration(
            labelText: appLocalizedText(context, 'Evidence crop / screenshot'),
          ),
          items: _evidence
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: AppText(
                    e.originalFilename ?? e.id,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedEvidence = v),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _session == null || _selectedEvidence == null
              ? null
              : _addObservation,
          icon: const Icon(Icons.add),
          label: const AppText('Save as ENTERED'),
        ),
        if (_selectedObservation case final selected?)
          ..._observationActions(selected),
      ],
    ),
  );

  List<Widget> _observationActions(FieldObservation o) => [
    const Divider(height: 24),
    const AppText(
      'Review & provenance',
      style: TextStyle(fontWeight: FontWeight.w700),
    ),
    if (o.reviewState == 'ENTERED' || o.reviewState == 'REVIEWED')
      OutlinedButton.icon(
        onPressed: () => _saveCorrection(o),
        icon: const Icon(Icons.save_outlined),
        label: const AppText('Save correction to this field'),
      ),
    FutureBuilder<ResolvedField>(
      future: widget.database.resolveField(
        entityType: o.entityType,
        entityId: o.entityId,
        fieldName: o.fieldName,
      ),
      builder: (context, snapshot) {
        final r = snapshot.data;
        if (r == null) return const SizedBox.shrink();
        final preferred = r.preferred;
        return FutureBuilder<DataSourceRecord?>(
          future: preferred == null
              ? Future.value(null)
              : widget.database.getDataSource(preferred.sourceId),
          builder: (context, sourceSnapshot) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: AppText(
              'Current preferred: ${preferred?.value ?? '—'}\nSource: ${sourceSnapshot.data?.name ?? preferred?.sourceId ?? '—'} · ${preferred?.verificationStatus ?? '—'} · confidence ${preferred?.confidence?.toStringAsFixed(2) ?? '—'}\nNew observation: ${o.value} · ${o.verificationStatus}\nDifference: ${_diff(preferred?.value, o.value)}',
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
          ),
        );
      },
    ),
    if (o.reviewState == 'ENTERED')
      FilledButton.tonal(
        onPressed: () async {
          await widget.database.updateObservationReviewState(o.id, 'REVIEWED');
          await _reload();
        },
        child: const AppText('Review observation'),
      ),
    if (o.reviewState == 'ENTERED')
      TextButton(
        onPressed: () async {
          await widget.database.updateObservationReviewState(o.id, 'REJECTED');
          await _reload();
        },
        child: const AppText('Reject'),
      ),
    if (o.reviewState == 'REVIEWED')
      FilledButton.tonal(
        onPressed: o.evidenceId == null
            ? null
            : () async {
                await widget.database.confirmObservationCapture(
                  observationId: o.id,
                  evidenceId: o.evidenceId!,
                );
                await _reload();
              },
        child: const AppText('Confirm from screenshot'),
      ),
    if (o.reviewState == 'USER_CONFIRMED_CAPTURE')
      FilledButton(
        onPressed: () => _confirmGame(o),
        child: const AppText('Promote to IN_GAME_VERIFIED'),
      ),
    if (o.reviewState == 'USER_CONFIRMED_CAPTURE')
      const AppText(
        'Requires explicit confirmation, update context and an intact local screenshot checksum.',
        style: TextStyle(fontSize: 10, color: _muted),
      ),
    if (o.reviewState == 'USER_CONFIRMED_CAPTURE' ||
        o.reviewState == 'IN_GAME_VERIFIED')
      OutlinedButton(
        onPressed: () => _setPreferred(o),
        child: const AppText('Prefer this observation'),
      ),
    FutureBuilder<List<FieldObservation>>(
      future: widget.database.getObservations(
        entityType: o.entityType,
        entityId: o.entityId,
        fieldName: o.fieldName,
      ),
      builder: (context, snapshot) {
        final previous = (snapshot.data ?? const <FieldObservation>[])
            .where(
              (item) =>
                  item.id != o.id && item.verificationStatus != 'OUTDATED',
            )
            .toList();
        if (previous.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText(
              'Existing alternatives',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _muted,
              ),
            ),
            for (final old in previous)
              TextButton.icon(
                onPressed: () async {
                  await widget.database.markObservationOutdated(old.id);
                  await _reload();
                },
                icon: const Icon(Icons.history, size: 15),
                label: AppText(
                  'Mark ${old.value} (${old.verificationStatus}) outdated',
                ),
              ),
          ],
        );
      },
    ),
    if (o.reviewState == 'ENTERED' || o.reviewState == 'REVIEWED')
      TextButton(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText(
              'Observation remains unresolved; no preferred value was changed.',
            ),
          ),
        ),
        child: const AppText('Keep unresolved'),
      ),
  ];

  String _diff(Object? before, Object? after) {
    final a = num.tryParse('$before');
    final b = num.tryParse('$after');
    if (a != null && b != null) {
      final d = b - a;
      return '${d >= 0 ? '+' : ''}$d';
    }
    return before == after ? 'No difference' : 'Different value';
  }
}
