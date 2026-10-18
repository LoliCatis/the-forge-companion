part of '../../app/app.dart';

class OresPage extends StatefulWidget {
  const OresPage({super.key, required this.database, required this.onChanged});
  final GameDataStore database;
  final VoidCallback onChanged;
  @override
  State<OresPage> createState() => _OresPageState();
}

class _OresPageState extends State<OresPage> {
  String _query = '';
  @override
  Widget build(BuildContext context) => _Page(
    title: 'Ore database',
    subtitle: 'Edit a value with its source. An unverified manual value stays marked UNKNOWN.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 350,
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: appLocalizedText(context, 'Search ore database'),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        const SizedBox(height: 13),
        _Surface(
          child: FutureBuilder<List<OreRecord>>(
            future: widget.database.searchOres(_query),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();
              if (snapshot.data!.isEmpty) return const EmptyState(title: 'No ores found', message: 'Try a shorter name or another search.', icon: Icons.search_off);
              return Column(children: [for (final ore in snapshot.data!) Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: AppCard(padding: const EdgeInsets.fromLTRB(14, 12, 8, 12), child: Row(children: [
                const Icon(Icons.diamond_outlined, color: _accent, size: 21), const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 7, runSpacing: 5, crossAxisAlignment: WrapCrossAlignment.center, children: [AppText(ore.name, translate: false, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)), StatusBadge(ore.rarity ?? 'Unknown'), StatusBadge(ore.verificationStatus), ConfidenceBadge(ore.confidence)]),
                  const SizedBox(height: 6),
                  AppText('Trait · ${ore.traits.isEmpty ? 'Unknown' : ore.traits.map((trait) => trait.name).join(', ')}', style: const TextStyle(color: _muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  AppText('Source · ${ore.source}', style: const TextStyle(color: _muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [AppText(ore.multiplier?.toStringAsFixed(3) ?? 'Unknown', style: const TextStyle(color: _accent, fontSize: 16, fontWeight: FontWeight.w700)), AppText(ore.price == null ? 'Price unknown' : '\$${ore.price!.toStringAsFixed(0)}', style: const TextStyle(color: _muted, fontSize: 12))]),
                IconButton(tooltip: appLocalizedText(context, 'Inspect multiplier sources'), onPressed: () => _inspectField(context, ore, 'multiplier'), icon: const Icon(Icons.info_outline, size: 18)),
                IconButton(tooltip: appLocalizedText(context, 'Edit values'), onPressed: () => _editOre(context, ore), icon: const Icon(Icons.edit_outlined, size: 18)),
              ])))]);
            },
          ),
        ),
      ],
    ),
  );

  Future<void> _editOre(BuildContext context, OreRecord ore) async {
    final multiplier = TextEditingController(
      text: ore.multiplier?.toString() ?? '',
    );
    final price = TextEditingController(text: ore.price?.toString() ?? '');
    final evidenceReference = TextEditingController();
    final notes = TextEditingController();
    final gameVersion = TextEditingController();
    final observedDate = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );
    var evidenceType = EvidenceType.manualTranscription;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: AppText('Edit ${ore.name}'),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: multiplier,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: appLocalizedText(context, 'Multiplier')),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: appLocalizedText(context, 'Ore price')),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: observedDate,
                decoration: InputDecoration(
                  labelText: appLocalizedText(context, 'Observed date (YYYY-MM-DD)'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: gameVersion,
                decoration: InputDecoration(
                  labelText: appLocalizedText(context, 'Game version/update context'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: evidenceReference,
                decoration: InputDecoration(
                  labelText: appLocalizedText(context, 'Local evidence reference (relative path)'),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<EvidenceType>(
                initialValue: evidenceType,
                decoration: InputDecoration(labelText: appLocalizedText(context, 'Evidence type')),
                items: const [
                  EvidenceType.screenshot,
                  EvidenceType.manualTranscription,
                  EvidenceType.experiment,
                ]
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: AppText(type.name)),
                    )
                    .toList(),
                onChanged: (value) =>
                    evidenceType = value ?? EvidenceType.webSource,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notes,
                decoration: InputDecoration(labelText: appLocalizedText(context, 'Notes')),
              ),
              const SizedBox(height: 10),
              const AppText(
                'Entry is saved as a candidate. IN_GAME_VERIFIED requires review, game context and evidence.',
                style: TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Save'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (save != true) {
      multiplier.dispose();
      price.dispose();
      evidenceReference.dispose();
      notes.dispose();
      gameVersion.dispose();
      observedDate.dispose();
      return;
    }
    final parsedMultiplier = double.tryParse(
      multiplier.text.replaceAll(',', '.'),
    );
    final parsedPrice = double.tryParse(price.text.replaceAll(',', '.'));
    final observedAt = DateTime.tryParse(observedDate.text.trim());
    final localEvidenceRef = evidenceReference.text.trim();
    final evidenceUri = Uri.tryParse(localEvidenceRef);
    final unsafeEvidenceRef = localEvidenceRef.startsWith('/') ||
        RegExp(r'^[A-Za-z]:[\\/]').hasMatch(localEvidenceRef) ||
        (evidenceUri?.hasScheme ?? false) ||
        localEvidenceRef.split(RegExp(r'[\\/]')).contains('..');
    if ((multiplier.text.trim().isNotEmpty &&
            (parsedMultiplier == null || parsedMultiplier < 0)) ||
        (price.text.trim().isNotEmpty &&
            (parsedPrice == null || parsedPrice < 0)) ||
        observedAt == null ||
        unsafeEvidenceRef) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Enter non-negative values and a relative local evidence path.')),
      );
      multiplier.dispose();
      price.dispose();
      evidenceReference.dispose();
      notes.dispose();
      gameVersion.dispose();
      observedDate.dispose();
      return;
    }
    final stamp = observedAt;
    final enteredAt = DateTime.now();
    const sourceId = 'local-wiki-candidate';
    const candidateStatus = 'UNKNOWN';
    final evidenceId = localEvidenceRef.isEmpty
        ? null
        : '$sourceId-${enteredAt.microsecondsSinceEpoch}-evidence';
    await widget.database.upsertDataSource(
      const DataSourceRecord(
        id: sourceId,
        name: 'Local wiki candidate',
        sourceType: 'LOCAL_CANDIDATE',
      ),
    );
    if (evidenceId != null) {
      await widget.database.saveEvidence(
        EvidenceRecord(
          id: evidenceId,
          type: evidenceType,
          reference: localEvidenceRef,
          capturedAt: enteredAt,
          notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
        ),
      );
    }
    for (final field in [
      ('multiplier', parsedMultiplier, multiplier.text),
      ('price', parsedPrice, price.text),
    ]) {
      if (field.$3.trim().isEmpty) continue;
      final observationId = '$sourceId-${field.$1}';
      await widget.database.addObservation(
        FieldObservation(
          id: observationId,
          entityType: 'ORE',
          entityId: ore.id,
          fieldName: field.$1,
          value: field.$2,
          sourceId: sourceId,
          observedAt: stamp,
          verificationStatus: candidateStatus,
          evidenceReference: localEvidenceRef.isEmpty ? null : localEvidenceRef,
          evidenceId: evidenceId,
          gameVersion: gameVersion.text.trim().isEmpty
              ? null
              : gameVersion.text.trim(),
          reviewState: 'ENTERED',
          notes: notes.text.trim().isEmpty
              ? 'Local wiki entry; not verified in game.'
              : notes.text.trim(),
        ),
      );
    }
    final multiplierField = await widget.database.resolveField(
      entityType: 'ORE',
      entityId: ore.id,
      fieldName: 'multiplier',
    );
    final multiplierConflict = multiplierField.conflicting;
    final resolvedMultiplier = multiplierConflict
        ? null
        : (multiplierField.preferred?.value as num?)?.toDouble() ??
              ore.multiplier;
    final resolvedStatus = multiplierConflict
        ? 'CONFLICTING'
        : multiplierField.preferred?.verificationStatus ??
              ore.verificationStatus;
    await widget.database.upsertOre(
      OreRecord(
        id: ore.id,
        name: ore.name,
        rarity: ore.rarity,
        multiplier: resolvedMultiplier,
        price: parsedPrice ?? ore.price,
        source: 'Local wiki',
        sourceUrl: null,
        verificationStatus: resolvedStatus,
      ),
    );
    multiplier.dispose();
    price.dispose();
    evidenceReference.dispose();
    notes.dispose();
    gameVersion.dispose();
    observedDate.dispose();
    widget.onChanged();
    setState(() {});
  }

  Future<void> _inspectField(
    BuildContext context,
    OreRecord ore,
    String field,
  ) async {
    final resolved = await widget.database.resolveField(
      entityType: 'ORE',
      entityId: ore.id,
      fieldName: field,
    );
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: AppText('${ore.name} · $field'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText(
                  'Preferred: ${resolved.preferred?.value ?? 'Unknown'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (resolved.conflicting)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: _Notice(
                      icon: Icons.warning_amber,
                      text: 'Conflicting observations remain preserved. This value needs in-game verification.',
                    ),
                  ),
                const SizedBox(height: 14),
                if (resolved.preferred != null) ...[
                  const AppText(
                    'CURRENT PREFERRED SOURCE',
                    style: TextStyle(color: _muted, fontSize: 10),
                  ),
                  _ObservationTile(
                    database: widget.database,
                    observation: resolved.preferred!,
                  ),
                ],
                if (resolved.alternatives.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const AppText(
                    'ALTERNATIVE OBSERVATIONS',
                    style: TextStyle(color: _muted, fontSize: 10),
                  ),
                  for (final observation in resolved.alternatives)
                    _ObservationTile(
                      database: widget.database,
                      observation: observation,
                    ),
                ],
                if (resolved.preferred == null)
                  const AppText(
                    'No observations are recorded for this field.',
                    style: TextStyle(color: _muted),
                  ),
              ],
            ),
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
}

class _ObservationTile extends StatelessWidget {
  const _ObservationTile({required this.database, required this.observation});
  final GameDataStore database;
  final FieldObservation observation;

  @override
  Widget build(BuildContext context) => FutureBuilder<DataSourceRecord?>(
    future: database.getDataSource(observation.sourceId),
    builder: (context, snapshot) {
      final source = snapshot.data;
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: AppText(
          '${observation.value ?? 'Unknown'}  ·  ${observation.verificationStatus}',
        ),
        subtitle: AppText(
          [
            source?.name ?? observation.sourceId,
            if (source?.url != null) source!.url!,
            'Observed ${observation.observedAt.toLocal().toString().split('.').first}',
            if (observation.gameVersion != null)
              'Game ${observation.gameVersion}',
            if (observation.evidenceReference != null)
              'Evidence ${observation.evidenceReference}',
            if (observation.evidenceId != null)
              'Evidence record ${observation.evidenceId}',
            'Review ${observation.reviewState}',
            if (observation.notes != null) observation.notes!,
          ].join('\n'),
        ),
        trailing: PopupMenuButton<String>(
          tooltip: appLocalizedText(context, 'Review observation'),
          onSelected: (action) async {
            try {
              if (action == 'review') {
                await database.updateObservationReviewState(
                  observation.id,
                  'REVIEWED',
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: AppText(
                        'Observation marked reviewed. Reopen the inspector to confirm it.',
                      ),
                    ),
                  );
                }
              } else if (action == 'prefer') {
                await database.setPreferredObservation(
                  entityType: observation.entityType,
                  entityId: observation.entityId,
                  fieldName: observation.fieldName,
                  observationId: observation.id,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: AppText(
                        'Preferred value set to ${observation.value}. Alternatives remain in history.',
                      ),
                    ),
                  );
                }
              } else if (action == 'confirm') {
                final version = TextEditingController(
                  text: observation.gameVersion ?? '',
                );
                final accepted = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const AppText('Confirm from in-game evidence'),
                    content: SizedBox(
                      width: 380,
                      child: TextField(
                        controller: version,
                        decoration: InputDecoration(
                          labelText: appLocalizedText(context, 'Game version / update context'),
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const AppText('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const AppText('Confirm'),
                      ),
                    ],
                  ),
                );
                if (accepted == true && observation.evidenceId != null) {
                  await database.confirmObservationAsInGameVerified(
                    observationId: observation.id,
                    gameVersion: version.text,
                    evidenceId: observation.evidenceId!,
                  );
                }
                version.dispose();
              }
            } on Object catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: AppText('Review failed: $error')),
                );
              }
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'prefer',
              child: AppText('Set this observation as preferred'),
            ),
            if (observation.reviewState == 'ENTERED')
              const PopupMenuItem(
                value: 'review',
                child: AppText('Mark reviewed'),
              ),
            if (observation.reviewState == 'REVIEWED' &&
                source?.sourceType == 'IN_GAME_MANUAL' &&
                observation.evidenceId != null)
              const PopupMenuItem(
                value: 'confirm',
                child: AppText('Confirm as IN_GAME_VERIFIED'),
              ),
          ],
        ),
      );
    },
  );
}
