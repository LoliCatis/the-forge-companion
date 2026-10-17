part of '../../app/app.dart';

class DataHealthPage extends StatefulWidget {
  const DataHealthPage({super.key, required this.database});
  final GameDataStore database;
  @override
  State<DataHealthPage> createState() => _DataHealthPageState();
}

class _DataHealthPageState extends State<DataHealthPage> {
  String _filter = 'All';
  String _category = 'All';
  String _severity = 'All';

  Future<void> _addToVerification(DataHealthIssue issue) async {
    var sessions = await widget.database.getVerificationSessions();
    VerificationSession? selected;
    if (sessions.isEmpty) {
      final now = DateTime.now().toUtc();
      selected = VerificationSession(
        id: 'session-${now.microsecondsSinceEpoch}',
        gameUpdateLabel:
            'Unspecified update · ${DateTime.now().toIso8601String().substring(0, 10)}',
        sessionDate: DateTime.now(),
        checkType: _checkType(issue.entityType),
        createdAt: now,
        notes: 'Created from Data Health target',
      );
      await widget.database.createVerificationSession(selected);
      sessions = [selected];
    }
    if (sessions.length == 1) {
      selected = sessions.single;
    } else if (mounted) {
      selected = await showDialog<VerificationSession>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const AppText('Add target to session'),
          children: [
            for (final session in sessions)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, session),
                child: AppText(
                  '${session.gameUpdateLabel} · ${session.checkType}',
                ),
              ),
          ],
        ),
      );
    }
    if (selected == null) return;
    final priority = _priority(issue);
    await widget.database.addVerificationTarget(
      VerificationTarget(
        id: '${selected.id}-${issue.entityType}-${issue.entityId}-${issue.fieldName}',
        sessionId: selected.id,
        entityType: issue.entityType,
        entityId: issue.entityId,
        fieldName: issue.fieldName,
        priority: priority,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            '${issue.entityId} · ${issue.fieldName} added to ${selected.gameUpdateLabel} (priority $priority)',
          ),
        ),
      );
    }
  }

  String _checkType(String entityType) => switch (entityType) {
    'ORE' => 'Ore',
    'WEAPON' || 'WEAPON_VARIANT' || 'WEAPON_CLASS' => 'Weapon',
    'TRAIT' => 'Trait',
    'PROBABILITY_TABLE' || 'PROBABILITY' => 'Probability',
    _ => 'Craft Result',
  };

  int _priority(DataHealthIssue issue) {
    if (issue.entityType == 'ORE' && issue.fieldName == 'multiplier') return 1;
    if (issue.entityType == 'WEAPON_VARIANT' &&
        issue.fieldName == 'base_damage') {
      return 3;
    }
    if (issue.entityType == 'WEAPON_VARIANT' &&
        issue.fieldName == 'attack_interval_seconds') {
      return 4;
    }
    if (issue.entityType.contains('PROBABILITY')) return 5;
    if (issue.entityType == 'TRAIT' && issue.fieldName.contains('threshold')) {
      return 6;
    }
    if (issue.status == 'CONFLICTING') return 2;
    return 7;
  }

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Data health',
    subtitle: 'Field-level provenance, unresolved conflicts, and probability diagnostics.',
    child: FutureBuilder<List<Object?>>(
      future: _loadDataHealth(widget.database),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final issues = snapshot.data![6] as List<DataHealthIssue>;
        final filtered = issues
            .where((issue) => _filter == 'All' || issue.status == _filter)
            .where((issue) => _category == 'All' || issue.category == _category)
            .where((issue) => _severity == 'All' || issue.severity == _severity)
            .toList();
        final verified =
            (snapshot.data![1] as int) + (snapshot.data![2] as int);
        final community =
            (snapshot.data![3] as int) + (snapshot.data![4] as int);
        final coverage = snapshot.data![9] as Map<String, (int, int)>;
        final verifiedObservations =
            snapshot.data![10] as List<FieldObservation>;
        final counts = <(String, int, IconData)>[
          ('ORES IN CATALOG', snapshot.data![0] as int, Icons.diamond_outlined),
          ('VERIFIED FIELD OBSERVATIONS', verified, Icons.verified_outlined),
          ('COMMUNITY / GUIDE FIELDS', community, Icons.public_outlined),
          (
            'CONFLICTING FIELDS',
            issues.where((i) => i.status == 'CONFLICTING').length,
            Icons.warning_amber,
          ),
          ('OUTDATED OBSERVATIONS', snapshot.data![5] as int, Icons.history),
          (
            'UNKNOWN / TABLE ISSUES',
            issues
                .where(
                  (i) =>
                      i.status == 'UNKNOWN' ||
                      i.status == 'UNDERFLOW' ||
                      i.status == 'OVERFLOW' ||
                      i.status == 'INVALID',
                )
                .length,
            Icons.help_outline,
          ),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 11,
              runSpacing: 11,
              children: [
                for (final item in counts)
                  SizedBox(width: 210, child: _Metric(item.$1, '${item.$2}', 'Field-level records and issues', item.$3)),
              ],
            ),
            const SizedBox(height: 12),
            _Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    'ACTIVE DATA · ${snapshot.data![7] ?? 'No pack'}  /  ${snapshot.data![8] ?? 'No ruleset'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final severity in const [
                        'Critical',
                        'Needs Verification',
                        'Stale',
                        'Conflict',
                        'Resolved',
                        'Unknown',
                      ])
                        _StatusPill(
                          '$severity · ${issues.where((i) => i.severity == severity).length}',
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in const [
                        'Ores',
                        'Weapons',
                        'Traits',
                        'Probabilities',
                        'Formulas',
                      ])
                        _StatusPill(
                          '$category · ${issues.where((i) => i.category == category).length}',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText(
                    'CALCULATION-CRITICAL VERIFIED COVERAGE',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    runSpacing: 12,
                    children: [
                      for (final entry in coverage.entries)
                        SizedBox(
                          width: 190,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                entry.key,
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 11,
                                ),
                              ),
                              AppText(
                                '${entry.value.$1}/${entry.value.$2} · ${entry.value.$2 == 0 ? 0 : (100 * entry.value.$1 / entry.value.$2).round()}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const AppText(
                    'Counts cover catalog-critical fields; hidden effect parameters are not inferred from visible screenshots.',
                    style: TextStyle(color: _muted, fontSize: 10),
                  ),
                ],
              ),
            ),
            if (verifiedObservations.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'IN-GAME VERIFIED OBSERVATIONS · ${verifiedObservations.length}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    for (final observation in verifiedObservations)
                      ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.verified_outlined, color: _accent), title: AppText('${observation.entityType} · ${observation.entityId} · ${observation.fieldName}', translate: false, maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: AppText('${observation.value} · ${observation.observedAt.toIso8601String().substring(0, 10)} · evidence ${observation.evidenceId ?? '—'}', translate: false, maxLines: 2, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 13),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const AppText(
                  'ISSUE FILTER',
                  style: TextStyle(color: _muted, fontSize: 10),
                ),
                DropdownButton<String>(
                  value: _filter,
                  items:
                      const [
                            'All',
                            'CONFLICTING',
                            'UNKNOWN',
                            'OUTDATED',
                            'UNDERFLOW',
                            'OVERFLOW',
                            'INVALID',
                          ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: AppText(value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) =>
                      setState(() => _filter = value ?? 'All'),
                ),
                DropdownButton<String>(
                  value: _severity,
                  items:
                      const [
                            'All',
                            'Critical',
                            'Needs Verification',
                            'Stale',
                            'Conflict',
                            'Unknown',
                          ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: AppText(value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) =>
                      setState(() => _severity = value ?? 'All'),
                ),
                DropdownButton<String>(
                  value: _category,
                  items:
                      const [
                            'All',
                            'Ores',
                            'Weapons',
                            'Traits',
                            'Probabilities',
                            'Formulas',
                          ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: AppText(value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) =>
                      setState(() => _category = value ?? 'All'),
                ),
              ],
            ),
            if (filtered.isEmpty) const AppCard(child: EmptyState(title: 'No data issues here', message: 'Nothing matches the current filters.', icon: Icons.verified_outlined)),
            for (final issue in filtered) ...[
              AppCard(padding: const EdgeInsets.fromLTRB(15, 12, 8, 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 8, runSpacing: 5, crossAxisAlignment: WrapCrossAlignment.center, children: [AppText('${issue.entityType} · ${issue.entityId}', translate: false, style: const TextStyle(fontWeight: FontWeight.w600)), StatusBadge(issue.status)]),
                  const SizedBox(height: 5),
                  AppText(issue.fieldName, translate: false, style: const TextStyle(color: _accent, fontSize: 12)),
                  const SizedBox(height: 4),
                  AppText(issue.message, softWrap: true, style: const TextStyle(color: _muted, fontSize: 13)),
                ])),
                IconButton(tooltip: appLocalizedText(context, 'Add to verification session'), icon: const Icon(Icons.playlist_add), onPressed: () => _addToVerification(issue)),
              ])),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            const _Notice(
              icon: Icons.shield_outlined,
              text: 'Source confidence and formula confidence are kept separate. Probability-table diagnostic rows show source sums and are never normalized in storage.',
            ),
          ],
        );
      },
    ),
  );
}

Future<List<Object?>> _loadDataHealth(GameDataStore database) async {
  final totalOres = await database.countAllOres();
  final inGame = await database.countObservationsByVerificationStatus(
    'IN_GAME_VERIFIED',
  );
  final multiSource = await database.countObservationsByVerificationStatus(
    'MULTI_SOURCE_VERIFIED',
  );
  final community = await database.countObservationsByVerificationStatus(
    'COMMUNITY',
  );
  final guide = await database.countObservationsByVerificationStatus(
    'GUIDE_BASED',
  );
  final outdated = await database.countObservationsByVerificationStatus(
    'OUTDATED',
  );
  final issues = await database.getDataHealthIssues();
  final dataVersion = await database.getActiveDataVersion();
  final rulesetVersion = await database.getActiveRulesetVersion();
  final coverage = await _criticalCoverage(database);
  final verifiedObservations = await database.getVerificationQueue(
    reviewState: 'IN_GAME_VERIFIED',
  );
  return [
    totalOres,
    inGame,
    multiSource,
    community,
    guide,
    outdated,
    issues,
    dataVersion,
    rulesetVersion,
    coverage,
    verifiedObservations,
  ];
}

Future<Map<String, (int, int)>> _criticalCoverage(
  GameDataStore database,
) async {
  var oreVerified = 0;
  final ores = await database.searchOres('');
  for (final ore in ores) {
    final field = await database.resolveField(
      entityType: 'ORE',
      entityId: ore.id,
      fieldName: 'multiplier',
    );
    if (field.preferred?.verificationStatus == 'IN_GAME_VERIFIED') {
      oreVerified++;
    }
  }
  final weapons = await database.getWeaponVariants();
  var weaponVerified = 0;
  for (final weapon in weapons) {
    for (final key in const ['base_damage', 'attack_interval']) {
      final field = await database.resolveField(
        entityType: 'WEAPON_VARIANT',
        entityId: weapon.id,
        fieldName: key,
      );
      if (field.preferred?.verificationStatus == 'IN_GAME_VERIFIED') {
        weaponVerified++;
      }
    }
  }
  var traitThresholdTotal = 0;
  var traitThresholdVerified = 0;
  var effectTotal = 0;
  var effectVerified = 0;
  const thresholdKeys = ['activation_threshold', 'full_threshold'];
  const effectKeys = [
    'proc_chance',
    'damage_multiplier',
    'flat_damage',
    'duration_seconds',
    'cooldown_seconds',
    'radius',
    'trigger',
    'stat_modifier',
  ];
  for (final ore in ores) {
    for (final trait in await database.getOreTraits(ore.id)) {
      for (final key in thresholdKeys) {
        traitThresholdTotal++;
        final field = await database.resolveField(
          entityType: 'TRAIT',
          entityId: trait.id,
          fieldName: key,
        );
        if (field.preferred?.verificationStatus == 'IN_GAME_VERIFIED') {
          traitThresholdVerified++;
        }
      }
      for (final key in effectKeys) {
        effectTotal++;
        final field = await database.resolveField(
          entityType: 'TRAIT',
          entityId: trait.id,
          fieldName: key,
        );
        if (field.preferred?.verificationStatus == 'IN_GAME_VERIFIED') {
          effectVerified++;
        }
      }
    }
  }
  var probabilityVerified = 0;
  for (final id in const ['weapon-class-3-ores', 'dagger-variants-3-ores']) {
    if ((await database.getProbabilityTable(id))?.verificationStatus ==
        'IN_GAME_VERIFIED') {
      probabilityVerified++;
    }
  }
  final totalCritical =
      ores.length + weapons.length * 2 + traitThresholdTotal + effectTotal + 2;
  final totalVerified =
      oreVerified +
      weaponVerified +
      traitThresholdVerified +
      effectVerified +
      probabilityVerified;
  return {
    'All critical inputs': (totalVerified, totalCritical),
    'Ore multipliers': (oreVerified, ores.length),
    'Weapon stats': (weaponVerified, weapons.length * 2),
    'Trait thresholds': (traitThresholdVerified, traitThresholdTotal),
    'Probabilities': (probabilityVerified, 2),
    'Effect parameters': (effectVerified, effectTotal),
  };
}
