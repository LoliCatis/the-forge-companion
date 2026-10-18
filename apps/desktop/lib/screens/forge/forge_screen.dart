part of '../../app/app.dart';

class ForgePage extends StatefulWidget {
  const ForgePage({super.key, required this.database});
  final GameDataStore database;
  @override
  State<ForgePage> createState() => _ForgePageState();
}

class _ForgePageState extends State<ForgePage> {
  final _ids = List<String?>.filled(4, null);
  final _counts = List.generate(4, (_) => TextEditingController(text: '3'));
  final _buildName = TextEditingController();
  final _baseDamage = TextEditingController();
  final _attackInterval = TextEditingController();
  String _traitFormula = 'unknown';
  DataPolicy _dataPolicy = DataPolicy.bestAvailable;
  String _craftGoal = 'WEAPON';
  String _weaponClassId = 'dagger';
  String? _weaponId;
  bool _showCompositionSearch = false;
  @override
  void dispose() {
    for (final item in _counts) {
      item.dispose();
    }
    _buildName.dispose();
    _baseDamage.dispose();
    _attackInterval.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Forge calculator',
    subtitle: 'Build and compare hypothetical mixes from the full ore catalog.',
    child: FutureBuilder<List<Object?>>(
      future: _loadForgeData(widget.database, _dataPolicy),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final ores = snapshot.data![0] as List<OreRecord>;
        final weapons = snapshot.data![1] as List<WeaponVariantRecord>;
        final weaponClasses = snapshot.data![2] as List<WeaponClassRecord>;
        final classTable = snapshot.data![3] as ProbabilityTableRecord?;
        final variantTable = snapshot.data![4] as ProbabilityTableRecord?;
        final oreFields = snapshot.data![5] as Map<String, ResolvedField>;
        final weaponFields = snapshot.data![6] as Map<String, ResolvedField>;
        final selectedWeapon = weapons
            .where((weapon) => weapon.id == _weaponId && weapon.classId == _weaponClassId)
            .firstOrNull;
        final classWeapons = weapons.where((weapon) => weapon.classId == _weaponClassId).toList();
        final selected = <OreAmount>[];
        for (var i = 0; i < 4; i++) {
          final ore = ores.where((item) => item.id == _ids[i]).firstOrNull;
          final quantity = int.tryParse(_counts[i].text) ?? 0;
          if (ore != null && quantity > 0) {
            selected.add(
              OreAmount(
                ore: OreDefinition(
                  id: ore.id,
                  name: ore.name,
                  multiplier: _resolvedNumber(
                    oreFields[ore.id],
                    _dataPolicy == DataPolicy.verifiedOnly
                        ? null
                        : ore.multiplier,
                  ),
                  verificationStatus: _verificationStatus(
                    oreFields[ore.id]?.preferred?.verificationStatus ??
                        ore.verificationStatus,
                  ),
                  confidence: ore.confidence,
                  traits:
                      (_dataPolicy == DataPolicy.verifiedOnly
                              ? const <OreTraitRecord>[]
                              : ore.traits)
                          .map(
                            (trait) => OreTrait(
                              id: trait.id,
                              name: trait.name,
                              effectType: trait.effectType,
                              activationThreshold: trait.activationThreshold,
                              fullThreshold: trait.fullThreshold,
                              procChance: trait.procChance,
                              damageMultiplier: trait.damageMultiplier,
                              flatDamage: trait.flatDamage,
                              durationSeconds: trait.durationSeconds,
                              cooldownSeconds: trait.cooldownSeconds,
                              radius: trait.radius,
                              stackingRule: trait.stackingRule,
                              trigger: trait.trigger,
                              statModifier: trait.statModifier,
                              scalingRule: switch (trait.scalingRule) {
                                'LINEAR_BETWEEN_THRESHOLDS' =>
                                  TraitScalingRule.linearBetweenThresholds,
                                _ => TraitScalingRule.unknown,
                              },
                            ),
                          )
                          .toList(growable: false),
                ),
                quantity: quantity,
              ),
            );
          }
        }
        final compositionCandidates = _showCompositionSearch
            ? const BasicOptimizer().optimize(
          ores.map((ore) => OptimizerOre(
            id: ore.id,
            name: ore.name,
            // Internal per-recipe search bound, not player inventory.
            maxPerRecipe: 12,
            multiplier: _resolvedNumber(oreFields[ore.id], _dataPolicy == DataPolicy.verifiedOnly ? null : ore.multiplier),
            dataConfidence: ore.confidence ?? 0,
            effectTags: ore.traits.map((trait) => trait.effectType ?? trait.name).toSet(),
            effectActivationThresholds: {
              for (final trait in ore.traits)
                if (trait.activationThreshold != null)
                  (trait.effectType ?? trait.name): trait.activationThreshold!,
            },
          )).toList(growable: false),
          constraints: const OptimizerConstraints(minTotalOres: 3, maxTotalOres: 12, maxOreTypes: 4, maxEvaluations: 4000),
                objective: OptimizerObjective.maxMultiplier,
              ).where((recipe) => recipe.rankable).toList(growable: false)
            : const <OptimizerRecipe>[];
        final formulaPolicy = switch (_traitFormula) {
          'linear' => const TraitFormulaPolicy(
            formula: FormulaDefinition(
              id: 'traitScaling.linear.v1',
              name: 'Linear scaling',
              version: '1',
              source: 'Unverified community description',
              verificationStatus: VerificationStatus.community,
              description: 'Linear from activation to full threshold.',
            ),
          ),
          _ => null,
        };
        final result = const ForgeCalculator().calculate(
          selected,
          traitFormulaPolicy: formulaPolicy,
        );
        final verifiedOnlyIncomplete =
            _dataPolicy == DataPolicy.verifiedOnly &&
            (selected.any((amount) => amount.ore.multiplier == null) ||
                selected.any(
                  (amount) => (ores
                      .firstWhere((ore) => ore.id == amount.ore.id)
                      .traits
                      .isNotEmpty),
                ) ||
                (selectedWeapon != null &&
                    (_resolvedNumber(
                              weaponFields['${selectedWeapon.id}:base_damage'],
                              null,
                            ) ==
                            null ||
                        _resolvedNumber(
                              weaponFields['${selectedWeapon.id}:attack_interval'],
                              null,
                            ) ==
                            null)) ||
                selected.isNotEmpty &&
                    (classTable?.totalOres != result.totalOres ||
                        classTable?.verificationStatus != 'IN_GAME_VERIFIED' ||
                        variantTable?.totalOres != result.totalOres ||
                        variantTable?.verificationStatus !=
                            'IN_GAME_VERIFIED'));
        final verifiedPreferredFallback =
            _dataPolicy == DataPolicy.verifiedPreferred &&
            (selected.any(
                  (amount) => oreFields[amount.ore.id]?.usedFallback ?? false,
                ) ||
                (selectedWeapon != null &&
                    ['base_damage', 'attack_interval'].any(
                      (field) =>
                          weaponFields['${selectedWeapon.id}:$field']
                              ?.usedFallback ??
                          false,
                    )) ||
                (selected.isNotEmpty &&
                    ((classTable?.totalOres == result.totalOres &&
                            classTable?.verificationStatus !=
                                'IN_GAME_VERIFIED') ||
                        (variantTable?.totalOres == result.totalOres &&
                            variantTable?.verificationStatus !=
                                'IN_GAME_VERIFIED'))));
        final dps = const DpsCalculator().calculate(
          DpsInput(
            weapon: WeaponVariant(
              id: selectedWeapon?.id ?? 'manual-preview',
              name: selectedWeapon?.name ?? 'Manual scenario',
              baseDamage: _resolvedNumber(
                weaponFields['${selectedWeapon?.id}:base_damage'],
                _dataPolicy == DataPolicy.verifiedOnly
                    ? null
                    : double.tryParse(_baseDamage.text.replaceAll(',', '.')) ??
                          selectedWeapon?.baseDamage,
              ),
              attackIntervalSeconds: _resolvedNumber(
                weaponFields['${selectedWeapon?.id}:attack_interval'],
                _dataPolicy == DataPolicy.verifiedOnly
                    ? null
                    : double.tryParse(
                            _attackInterval.text.replaceAll(',', '.'),
                          ) ??
                          selectedWeapon?.attackIntervalSeconds,
              ),
            ),
            oreMultiplier: result.weightedMultiplier,
            inputDataConfidence: selected.fold<double>(
              1,
              (value, amount) => value < (amount.ore.confidence ?? 0)
                  ? value
                  : (amount.ore.confidence ?? 0),
            ),
          ),
        );
        final applicableClassTable =
            classTable?.totalOres == result.totalOres &&
                !(_dataPolicy == DataPolicy.verifiedOnly &&
                    classTable?.verificationStatus != 'IN_GAME_VERIFIED')
            ? classTable
            : null;
        final applicableVariantTable =
            variantTable?.totalOres == result.totalOres &&
                !(_dataPolicy == DataPolicy.verifiedOnly &&
                    variantTable?.verificationStatus != 'IN_GAME_VERIFIED')
            ? variantTable
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Surface(
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const AppText('DATA POLICY'),
                  DropdownButton<DataPolicy>(
                    value: _dataPolicy,
                    items: const [
                      DropdownMenuItem(
                        value: DataPolicy.bestAvailable,
                        child: AppText('Best available'),
                      ),
                      DropdownMenuItem(
                        value: DataPolicy.verifiedPreferred,
                        child: AppText('Verified preferred'),
                      ),
                      DropdownMenuItem(
                        value: DataPolicy.verifiedOnly,
                        child: AppText('Verified only'),
                      ),
                    ],
                    onChanged: (value) => setState(
                      () => _dataPolicy = value ?? DataPolicy.bestAvailable,
                    ),
                  ),
                ],
              ),
            ),
            if (_dataPolicy == DataPolicy.verifiedPreferred)
              _Notice(
                icon: Icons.info_outline,
                text: verifiedPreferredFallback
                    ? 'Community fallback is active for selected inputs; results remain estimates.'
                    : 'Game-verified values are preferred. Missing values use community data and remain labeled as such.',
              ),
            if (_dataPolicy == DataPolicy.verifiedOnly &&
                verifiedOnlyIncomplete)
              const _Notice(
                icon: Icons.warning_amber,
                text: 'INCOMPLETE · Required verified inputs are missing; community values are withheld for this calculation.',
              ),
            _Surface(
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const AppText('CRAFT GOAL', style: TextStyle(fontWeight: FontWeight.w700)),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'WEAPON', label: AppText('Weapon'), icon: Icon(Icons.gps_fixed)),
                      ButtonSegment(value: 'ARMOR', label: AppText('Armor'), icon: Icon(Icons.shield_outlined)),
                    ],
                    selected: {_craftGoal},
                    onSelectionChanged: (value) => setState(() {
                      _craftGoal = value.first;
                      _weaponId = null;
                      if (_craftGoal == 'ARMOR') {
                        _baseDamage.clear();
                        _attackInterval.clear();
                      }
                    }),
                  ),
                  if (_craftGoal == 'WEAPON') ...[
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: weaponClasses.any((item) => item.id == _weaponClassId) ? _weaponClassId : null,
                        decoration: const InputDecoration(labelText: 'Weapon type', isDense: true),
                        items: weaponClasses.where((item) => item.forgeAvailable).map((item) => DropdownMenuItem(value: item.id, child: AppText(item.name))).toList(),
                        onChanged: (value) => setState(() {
                          _weaponClassId = value ?? '';
                          _weaponId = null;
                          _baseDamage.clear();
                          _attackInterval.clear();
                        }),
                      ),
                    ),
                    if (classWeapons.isNotEmpty)
                      SizedBox(
                        width: 240,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: classWeapons.any((item) => item.id == _weaponId) ? _weaponId : null,
                          decoration: const InputDecoration(labelText: 'Stats source (optional)', isDense: true),
                          hint: const AppText('Unknown until selected'),
                          items: classWeapons.map((weapon) => DropdownMenuItem(value: weapon.id, child: AppText(weapon.name))).toList(),
                          onChanged: (value) => setState(() => _weaponId = value),
                        ),
                      ),
                  ] else
                    const AppText('Armor class and defense data: Unknown', style: TextStyle(color: _muted)),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _showCompositionSearch = !_showCompositionSearch),
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: AppText(_showCompositionSearch ? 'Hide composition search' : 'Find ore composition'),
                  ),
                ],
              ),
            ),
            if (_showCompositionSearch)
              _Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionHeader('Suggested ore compositions', subtitle: 'Ranks available multiplier values only; it does not predict weapon or armor stats.'),
                const SizedBox(height: 8),
                if (compositionCandidates.isEmpty)
                  const AppText('No rankable mixes. Add multiplier values to the catalog first.', style: TextStyle(color: _muted))
                else
                  for (final candidate in compositionCandidates.take(3))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: AppText(candidate.recipe.entries.map((entry) => '${ores.firstWhere((ore) => ore.id == entry.key).name} ×${entry.value}').join(' · '), translate: false),
                      subtitle: AppText('Estimated ore multiplier: ${candidate.multiplier?.toStringAsFixed(3) ?? 'Unknown'}'),
                      trailing: TextButton(onPressed: () => setState(() {
                        for (var i = 0; i < 4; i++) {
                          final entry = i < candidate.recipe.entries.length ? candidate.recipe.entries.elementAt(i) : null;
                          _ids[i] = entry?.key;
                          _counts[i].text = entry?.value.toString() ?? '3';
                        }
                      }), child: const AppText('Use mix')),
                    ),
              ])),
            LayoutBuilder(builder: (context, constraints) {
              final compact = constraints.maxWidth < 1300;
              final recipeWidth = compact ? constraints.maxWidth : (constraints.maxWidth - 14) * .60;
              final resultWidth = compact ? constraints.maxWidth : (constraints.maxWidth - 14) * .40;
              return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: recipeWidth,
                  child: _Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader('Test recipe', subtitle: 'Select any catalog ores and set hypothetical amounts.'),
                        const SizedBox(height: 10),
                        for (var i = 0; i < 4; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _ids[i] ?? '',
                                    decoration: InputDecoration(
                                      labelText: appLocalizedText(context, 'Ore slot ${i + 1}'),
                                      isDense: true,
                                    ),
                                    items: [
                                      const DropdownMenuItem(
                                        value: '',
                                        child: AppText('Select ore'),
                                      ),
                                      ...ores.map(
                                        (ore) => DropdownMenuItem(
                                          value: ore.id,
                                          child: AppText(ore.name, translate: false),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) => setState(
                                      () => _ids[i] =
                                          value == null || value.isEmpty
                                          ? null
                                          : value,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 9),
                                SizedBox(
                                  width: 76,
                                  child: TextField(
                                    controller: _counts[i],
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: appLocalizedText(context, 'Qty'),
                                      isDense: true,
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        AppText(
                          'Total ores: ${result.totalOres}   •   Up to 4 ore types',
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: 220,
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: _traitFormula,
                                decoration: InputDecoration(
                                  labelText: appLocalizedText(context, 'Trait scaling hypothesis'),
                                  isDense: true,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'unknown',
                                    child: AppText('Unknown / no curve'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'linear',
                                    child: AppText('Linear 10% → 30%'),
                                  ),
                                ],
                                onChanged: (value) => setState(
                                  () => _traitFormula = value ?? 'unknown',
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 250,
                              child: TextField(
                                controller: _buildName,
                                decoration: InputDecoration(
                                  labelText: appLocalizedText(context, 'Recipe name'),
                                  isDense: true,
                                ),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: selected.isEmpty
                                  ? null
                                  : () async {
                                      final id = DateTime.now()
                                          .microsecondsSinceEpoch
                                          .toString();
                                      await widget.database.saveBuild(
                                        SavedBuildRecord(
                                          id: id,
                                          name: _buildName.text.trim().isEmpty
                                              ? 'Build $id'
                                              : _buildName.text.trim(),
                                          recipe: {
                                            for (final amount in selected)
                                              amount.ore.id: amount.quantity,
                                          },
                                          createdAt: DateTime.now(),
                                          craftGoal: _craftGoal,
                                        ),
                                      );
                                      final snapshotId = 'calc-$id';
                                      final observationIds = <String>[];
                                      for (final amount in selected) {
                                        final field = await widget.database
                                            .resolveField(
                                              entityType: 'ORE',
                                              entityId: amount.ore.id,
                                              fieldName: 'multiplier',
                                            );
                                        final observationId =
                                            field.preferred?.id;
                                        if (observationId != null) {
                                          observationIds.add(observationId);
                                        }
                                      }
                                      if (selectedWeapon != null) {
                                        for (final fieldName in const [
                                          'base_damage',
                                          'attack_interval',
                                          'variant_weight',
                                        ]) {
                                          final resolved = await widget.database
                                              .resolveField(
                                                entityType: 'WEAPON_VARIANT',
                                                entityId: selectedWeapon.id,
                                                fieldName: fieldName,
                                              );
                                          final observationId =
                                              resolved.preferred?.id;
                                          if (observationId != null) {
                                            observationIds.add(observationId);
                                          }
                                        }
                                      }
                                      await widget.database.saveCalculationSnapshot(
                                        CalculationSnapshot(
                                          id: snapshotId,
                                          catalogVersion:
                                              await widget.database
                                                  .getActiveDataVersion() ??
                                              'unknown',
                                          rulesetVersion:
                                              await widget.database
                                                  .getActiveRulesetVersion() ??
                                              'unknown',
                                          recipe: {
                                            for (final amount in selected)
                                              amount.ore.id: amount.quantity,
                                          },
                                          resolvedObservationIds:
                                              observationIds,
                                          formulaIds: [
                                            if (_traitFormula != 'unknown')
                                              'traitScaling.$_traitFormula.v1',
                                            'weightedMultiplier.v1',
                                            'scenarioRawDps.v1',
                                          ],
                                          assumptions: {
                                            'traitFormula': _traitFormula,
                                            'weaponStats':
                                                'manual scenario inputs',
                                            'quality': 'unknown',
                                            'probabilities': 'not applied',
                                          },
                                          resolvedInputs: {
                                            'oreMultipliers': {
                                              for (final amount in selected)
                                                amount.ore.id:
                                                    amount.ore.multiplier,
                                            },
                                            'baseDamage': double.tryParse(
                                              _baseDamage.text.replaceAll(
                                                ',',
                                                '.',
                                              ),
                                            ),
                                            'attackIntervalSeconds':
                                                double.tryParse(
                                                  _attackInterval.text
                                                      .replaceAll(',', '.'),
                                                ),
                                            'weaponVariantId':
                                                selectedWeapon?.id,
                                            'weaponBaseDamage':
                                                double.tryParse(
                                                  _baseDamage.text.replaceAll(
                                                    ',',
                                                    '.',
                                                  ),
                                                ) ??
                                                selectedWeapon?.baseDamage,
                                            'weaponAttackInterval':
                                                double.tryParse(
                                                  _attackInterval.text
                                                      .replaceAll(',', '.'),
                                                ) ??
                                                selectedWeapon
                                                    ?.attackIntervalSeconds,
                                            'classProbabilityRawSum':
                                                applicableClassTable?.sourceSum,
                                            'classProbabilityStatus':
                                                applicableClassTable
                                                    ?.verificationStatus,
                                            'variantProbabilityRawSum':
                                                applicableVariantTable
                                                    ?.sourceSum,
                                            'variantProbabilityStatus':
                                                applicableVariantTable
                                                    ?.verificationStatus,
                                          },
                                          calculationResult: {
                                            'weightedMultiplier':
                                                result.weightedMultiplier,
                                            'rawDps': dps.rawDps,
                                            'attacksPerSecond':
                                                dps.attacksPerSecond,
                                            'totalOres': result.totalOres,
                                            'probabilityTablesAreVerified':
                                                false,
                                          },
                                          dataCertainty:
                                              [
                                                ...selected.map(
                                                  (e) => e.ore.confidence ?? 0,
                                                ),
                                                if (selectedWeapon != null)
                                                  selectedWeapon.confidence ??
                                                      0,
                                              ].isEmpty
                                              ? 0
                                              : [
                                                  ...selected.map(
                                                    (e) =>
                                                        e.ore.confidence ?? 0,
                                                  ),
                                                  if (selectedWeapon != null)
                                                    selectedWeapon.confidence ??
                                                        0,
                                                ].reduce(
                                                  (a, b) => a < b ? a : b,
                                                ),
                                          formulaCertainty:
                                              _traitFormula == 'unknown'
                                              ? 0
                                              : .3,
                                          probabilityCertainty:
                                              applicableClassTable == null &&
                                                  applicableVariantTable == null
                                              ? 0
                                              : .25,
                                          createdAt: DateTime.now(),
                                        ),
                                      );
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            const SnackBar(
                                              content: AppText(
                                                'Recipe and calculation snapshot saved.',
                                              ),
                                            ),
                                          );
                                    },
                              icon: const Icon(Icons.save_outlined),
                              label: const AppText('Save scenario'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: resultWidth,
                  child: _Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppText(
                          'CALCULATION',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            letterSpacing: .8,
                          ),
                        ),
                        const SizedBox(height: 13),
          _ResultLine(
                          'Weighted multiplier',
                          result.weightedMultiplier?.toStringAsFixed(3) ??
                              'Unknown',
                          result.weightedMultiplier == null
                              ? 'At least one ore has no multiplier'
                              : 'Estimated from selected values',
                        ),
                        if (_craftGoal == 'WEAPON') ...[
                        const Divider(height: 19),
                        _ResultLine(
                          'Selected weapon type chance',
                          applicableClassTable?.entries[_weaponClassId] == null
                              ? 'Unknown'
                              : '${(applicableClassTable!.entries[_weaponClassId]! * 100).toStringAsFixed(1)}%',
                          applicableClassTable == null
                              ? 'No table for ${result.totalOres} ores'
                              : '${applicableClassTable.verificationStatus} · raw sum ${applicableClassTable.sourceSum.toStringAsFixed(4)} · ${applicableClassTable.normalizedForEstimate ? 'normalized estimate' : 'source values'}',
                        ),
                        if (_weaponClassId == 'dagger') const Divider(height: 19),
                        if (_weaponClassId == 'dagger') _ResultLine(
                          'Dagger variant odds',
                          applicableVariantTable?.entries.entries
                                  .map(
                                    (entry) =>
                                        '${entry.key}: ${(entry.value * 100 / (applicableVariantTable.normalizedForEstimate ? applicableVariantTable.sourceSum : 1)).toStringAsFixed(2)}%',
                                  )
                                  .join('\n') ??
                              'Unknown',
                          applicableVariantTable == null
                              ? 'Unknown for this composition'
                              : '${applicableVariantTable.verificationStatus} · raw sum ${applicableVariantTable.sourceSum.toStringAsFixed(4)} · ${applicableVariantTable.normalizedForEstimate ? 'normalized estimate' : 'source values'}',
                        ),
                        ],
                        if (_craftGoal == 'ARMOR') ...[
                          const Divider(height: 19),
                          const _ResultLine('Armor class odds', 'Unknown', 'No current verified probability table'),
                          const _ResultLine('Armor defense', 'Unknown', 'No verified armor stats are available'),
                        ],
                        const Divider(height: 19),
                        const _ResultLine(
                          'Craft quality',
                          'Unknown',
                          'Quality formula is not established',
                        ),
                        const Divider(height: 19),
                        if (_craftGoal == 'WEAPON' && selectedWeapon == null)
                          const AppText('Weapon stats: Unknown until a variant is selected above.', style: TextStyle(color: _muted)),
                        if (_craftGoal == 'WEAPON' && selectedWeapon != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: AppText(
                              '${selectedWeapon.verificationStatus} · confidence ${(100 * (selectedWeapon.confidence ?? 0)).toStringAsFixed(0)}% · source values are candidates, not in-game verified.',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        if (_craftGoal == 'WEAPON' && selectedWeapon != null)
                          Wrap(
                            spacing: 4,
                            children: [
                              _fieldInspectorButton(
                                context,
                                widget.database,
                                selectedWeapon,
                                'base_damage',
                                'Damage',
                              ),
                              _fieldInspectorButton(
                                context,
                                widget.database,
                                selectedWeapon,
                                'attack_interval',
                                'Attack interval',
                              ),
                              _fieldInspectorButton(
                                context,
                                widget.database,
                                selectedWeapon,
                                'variant_weight',
                                'Variant weight',
                              ),
                            ],
                          ),
                        if (_craftGoal == 'WEAPON') Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _baseDamage,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText: appLocalizedText(context, 'Scenario base damage'),
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: TextField(
                                controller: _attackInterval,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText: appLocalizedText(context, 'Attack interval (s)'),
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        if (_craftGoal == 'WEAPON') const SizedBox(height: 10),
                        if (_craftGoal == 'WEAPON') _ResultLine(
                          'Attacks per second',
                          dps.attacksPerSecond?.toStringAsFixed(3) ?? 'Unknown',
                          '1 / attack interval',
                        ),
                        if (_craftGoal == 'WEAPON') const Divider(height: 16),
                        if (_craftGoal == 'WEAPON') _ResultLine(
                          'Raw DPS',
                          dps.rawDps?.toStringAsFixed(2) ?? 'Unknown',
                          selectedWeapon == null
                              ? 'Manual scenario input'
                              : '${selectedWeapon.verificationStatus} weapon stats × estimated ore multiplier',
                        ),
                        if (_craftGoal == 'WEAPON') _ResultLine(
                          'Expected DPS',
                          'Unknown',
                          dps.unknownContributions.join(' · ').toUpperCase(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ); }),
            const SizedBox(height: 12),
            _Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText(
                    'COMPOSITION',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (selected.isEmpty)
                    const AppText(
                      'Choose ores to see the mix.',
                      style: TextStyle(color: _muted, fontSize: 11),
                    )
                  else
                    for (final amount in selected)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Expanded(child: AppText(amount.ore.name, translate: false)),
                            SizedBox(
                              width: 170,
                              child: LinearProgressIndicator(
                                value: result.composition[amount.ore.id],
                                color: _accent,
                                backgroundColor: _panel2,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 44,
                              child: AppText(
                                '${((result.composition[amount.ore.id] ?? 0) * 100).toStringAsFixed(1)}%',
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (result.traits.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppText(
                      'TRAIT BREAKDOWN',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final trait in result.traits)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: AppText('${trait.oreName} · ${trait.trait.name}', translate: false),
                        subtitle: AppText(
                          'Share ${(trait.share * 100).toStringAsFixed(1)}% · ${trait.activation.name.toUpperCase()} · strength ${trait.strength == null ? 'UNKNOWN' : '${(trait.strength! * 100).toStringAsFixed(1)}%'}',
                        ),
                        trailing: const AppText(
                          'Effect parameters unknown',
                          style: TextStyle(color: _muted, fontSize: 10),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            const _Notice(
              icon: Icons.info_outline,
              text: 'Variant probabilities, base weapon stats, critical contribution, proc effects, craft quality and sell value remain unknown unless you enter or verify their inputs. Scenario DPS is not a game prediction.',
            ),
          ],
        );
      },
    ),
  );
}

double? _resolvedNumber(ResolvedField? field, double? fallback) {
  final value = field?.preferred?.value;
  return value is num ? value.toDouble() : fallback;
}

Future<List<Object?>> _loadForgeData(
  GameDataStore database,
  DataPolicy policy,
) async {
  final ores = await database.searchOres('', policy: policy);
  final weapons = await database.getWeaponVariants();
  final weaponClasses = await database.getWeaponClasses();
  final oreFields = <String, ResolvedField>{};
  for (final ore in ores) {
    oreFields[ore.id] = await database.resolveField(
      entityType: 'ORE',
      entityId: ore.id,
      fieldName: 'multiplier',
      policy: policy,
    );
  }
  final weaponFields = <String, ResolvedField>{};
  for (final weapon in weapons) {
    for (final field in const ['base_damage', 'attack_interval']) {
      weaponFields['${weapon.id}:$field'] = await database.resolveField(
        entityType: 'WEAPON_VARIANT',
        entityId: weapon.id,
        fieldName: field,
        policy: policy,
      );
    }
  }
  final classTable = await database.getProbabilityTable('weapon-class-3-ores');
  final variantTable = await database.getProbabilityTable(
    'dagger-variants-3-ores',
  );
  return [ores, weapons, weaponClasses, classTable, variantTable, oreFields, weaponFields];
}

Widget _fieldInspectorButton(
  BuildContext context,
  GameDataStore database,
  WeaponVariantRecord weapon,
  String field,
  String label,
) => TextButton.icon(
  onPressed: () async {
    final resolved = await database.resolveField(
      entityType: 'WEAPON_VARIANT',
      entityId: weapon.id,
      fieldName: field,
    );
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AppText('${weapon.name} · $label'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText(
                  'Preferred value: ${resolved.preferred?.value ?? 'Unknown'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                AppText(
                  'Status: ${resolved.conflicting ? 'CONFLICTING' : resolved.preferred?.verificationStatus ?? weapon.verificationStatus}',
                ),
                if (resolved.conflicting)
                  const _Notice(
                    icon: Icons.warning_amber,
                    text: 'Multiple values are retained. Choosing a preferred observation does not remove the conflict history.',
                  ),
                for (final observation in [
                  if (resolved.preferred != null) resolved.preferred!,
                  ...resolved.alternatives,
                ])
                  _ObservationTile(
                    database: database,
                    observation: observation,
                  ),
                if (resolved.preferred == null)
                  const AppText(
                    'No field observations recorded. Pack-level candidate values are shown with their source status.',
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const AppText('Close'),
          ),
        ],
      ),
    );
  },
  icon: const Icon(Icons.info_outline, size: 14),
  label: AppText(label, style: const TextStyle(fontSize: 10)),
);
