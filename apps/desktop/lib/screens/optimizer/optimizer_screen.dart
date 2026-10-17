part of '../../app/app.dart';

class OptimizerPage extends StatefulWidget {
  const OptimizerPage({super.key, required this.database});
  final GameDataStore database;
  @override
  State<OptimizerPage> createState() => _OptimizerPageState();
}

class _OptimizerPageState extends State<OptimizerPage> {
  OptimizerObjective _objective = OptimizerObjective.maxMultiplier;
  final Map<String, String> _snapshotIds = {};
  final _required = TextEditingController();
  final _forbidden = TextEditingController();
  final _effects = TextEditingController();
  final _minCount = TextEditingController(text: '3');
  final _maxCount = TextEditingController(text: '51');

  @override
  void dispose() {
    _required.dispose();
    _forbidden.dispose();
    _effects.dispose();
    _minCount.dispose();
    _maxCount.dispose();
    super.dispose();
  }

  Set<String> _list(String value) =>
      value.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toSet();

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Build optimizer',
    subtitle: 'Searches craftable inventory mixes; unknown data cannot improve a score.',
    child: FutureBuilder<List<InventoryRecord>>(
      future: widget.database.getInventory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final input = snapshot.data!
            .map(
              (item) => OptimizerOre(
                id: item.oreId,
                name: item.oreName,
                available: item.quantity,
                protectedQuantity: item.protectedQuantity,
                multiplier: item.multiplier,
                dataConfidence: item.confidence ?? 0,
                effectTags: item.effectTags,
                effectActivationThresholds: item.effectActivationThresholds,
              ),
            )
            .toList(growable: false);
        final min = int.tryParse(_minCount.text) ?? 3;
        final max = int.tryParse(_maxCount.text) ?? 51;
        final constraints = OptimizerConstraints(
          requiredOres: _list(_required.text),
          forbiddenOres: _list(_forbidden.text),
          minTotalOres: min.clamp(1, 1000),
          maxTotalOres: max.clamp(1, 1000),
          maxOreTypes: 4,
          targetEffects: _list(_effects.text),
          maxEvaluations: 15000,
        );
        final results = min <= max
            ? const BasicOptimizer().optimize(
                input,
                constraints: constraints,
                objective: _objective,
              )
            : const <OptimizerRecipe>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Surface(
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<OptimizerObjective>(
                      isExpanded: true,
                      initialValue: _objective,
                      decoration: InputDecoration(
                        labelText: appLocalizedText(context, 'Objective'),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: OptimizerObjective.maxMultiplier,
                          child: AppText('Max multiplier', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: OptimizerObjective.maxEffects,
                          child: AppText('Max selected effects', overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      onChanged: (value) => setState(
                        () => _objective =
                            value ?? OptimizerObjective.maxMultiplier,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _minCount,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: appLocalizedText(context, 'Min ores'),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _maxCount,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: appLocalizedText(context, 'Max ores'),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(
                    width: 230,
                    child: TextField(
                      controller: _required,
                      decoration: InputDecoration(
                        labelText: appLocalizedText(context, 'Required ore IDs'),
                        hintText: appLocalizedText(context, 'ore-one, ore-two'),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(
                    width: 230,
                    child: TextField(
                      controller: _forbidden,
                      decoration: InputDecoration(
                        labelText: appLocalizedText(context, 'Forbidden ore IDs'),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (_objective == OptimizerObjective.maxEffects)
                    SizedBox(
                      width: 230,
                      child: TextField(
                        controller: _effects,
                        decoration: InputDecoration(
                          labelText: appLocalizedText(context, 'Effect tags'),
                          hintText: appLocalizedText(context, 'burn, defense'),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Notice(
              icon: Icons.tune,
              text:
                      'Objective: ${_objective.name}. Protected quantities are reserved. Up to four ore types. DPS objectives are hidden until verified weapon and effect inputs are available.',
            ),
            const SizedBox(height: 12),
            _Surface(
              child: results.isEmpty
                  ? const AppText(
                      'No rankable recipes. Add inventory and source-aware multipliers in Ores; DPS objectives also require verified weapon and effect inputs.',
                      style: TextStyle(color: _muted, fontSize: 12),
                    )
                  : _optimizerResults(context, results.toList(), input),
            ),
          ],
        );
      },
    ),
  );

  Widget _optimizerResults(BuildContext context, List<OptimizerRecipe> results, List<OptimizerOre> input) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeader('Ranked recipes', subtitle: 'Protected quantities stay reserved from every suggestion.'),
      const SizedBox(height: 10),
      for (final entry in results.asMap().entries) ...[
        AppCard(accent: entry.key == 0, padding: const EdgeInsets.fromLTRB(15, 12, 12, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFF3D2E1C), borderRadius: BorderRadius.circular(10)), child: AppText('#${entry.key + 1}', translate: false, style: const TextStyle(color: _accent, fontWeight: FontWeight.w700))), const SizedBox(width: 11), Expanded(child: AppText(entry.value.recipe.entries.map((e) { final ore = input.firstWhere((item) => item.id == e.key); return '${ore.name} ×${e.value}'; }).join(' · '), translate: false, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis)), const SizedBox(width: 10), if (_snapshotIds[_recipeKey(entry.value.recipe)] == null) IconButton(tooltip: appLocalizedText(context, 'Save calculation snapshot'), icon: const Icon(Icons.save_outlined, color: _accent), onPressed: () => _saveOptimizerSnapshot(context, entry.value, input)) else Tooltip(message: appLocalizedText(context, 'Calculation snapshot saved'), child: Icon(Icons.check_circle_outline, color: _accent))]),
          const Divider(height: 18),
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth >= 760 ? 4 : constraints.maxWidth >= 440 ? 2 : 1;
            final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
            return Wrap(spacing: 8, runSpacing: 8, children: [
              _optimizerStat(width, 'Objective score', entry.value.score.toStringAsFixed(3), _objective.name),
              _optimizerStat(width, 'Ore multiplier', entry.value.multiplier?.toStringAsFixed(3) ?? 'Unknown', 'weighted mix'),
              _optimizerStat(width, 'Data confidence', '${(entry.value.dataCertainty * 100).round()}%', 'lowest input'),
              _optimizerStat(width, 'Formula confidence', '${(entry.value.formulaCertainty * 100).round()}%', 'calculation model'),
            ]);
          }),
          ExpansionTile(title: const AppText('Why this result', style: TextStyle(fontSize: 13)), tilePadding: EdgeInsets.zero, children: [Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: 10), child: AppText([entry.value.whyThisResult, ...entry.value.warnings, 'Probability confidence ${(entry.value.probabilityCertainty * 100).round()}% · not used for ranking.'].join('\n'), style: const TextStyle(color: _muted, fontSize: 13))))]),
        ])),
        const SizedBox(height: 9),
      ],
    ],
  );

  Widget _optimizerStat(double width, String label, String value, String detail) => SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [AppText(label, style: const TextStyle(fontSize: 12, color: _muted)), const SizedBox(height: 4), AppText(value, style: const TextStyle(fontSize: 17, color: _accent, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis), AppText(detail, style: const TextStyle(fontSize: 12, color: _muted), maxLines: 1, overflow: TextOverflow.ellipsis)]));

  Future<void> _saveOptimizerSnapshot(BuildContext context, OptimizerRecipe recipe, List<OptimizerOre> input) async {
    final id = 'optimizer-${DateTime.now().microsecondsSinceEpoch}';
    final observationIds = <String>[];
    for (final oreId in recipe.recipe.keys) {
      final field = await widget.database.resolveField(entityType: 'ORE', entityId: oreId, fieldName: 'multiplier');
      if (field.preferred?.id case final observationId?) observationIds.add(observationId);
    }
    await widget.database.saveCalculationSnapshot(CalculationSnapshot(
      id: id,
      catalogVersion: await widget.database.getActiveDataVersion() ?? 'unknown',
      rulesetVersion: await widget.database.getActiveRulesetVersion() ?? 'unknown',
      recipe: recipe.recipe,
      resolvedObservationIds: observationIds,
      formulaIds: const ['ore.weighted-average.v1'],
      assumptions: const {'objective': 'inventory mix', 'craftProbability': 'not modeled'},
      resolvedInputs: {'oreMultipliers': {for (final oreId in recipe.recipe.keys) oreId: input.firstWhere((ore) => ore.id == oreId).multiplier}},
      calculationResult: {'score': recipe.score, 'weightedMultiplier': recipe.multiplier, 'rankable': recipe.rankable},
      dataCertainty: recipe.dataCertainty,
      formulaCertainty: recipe.formulaCertainty,
      probabilityCertainty: recipe.probabilityCertainty,
      createdAt: DateTime.now(),
    ));
    if (!context.mounted) return;
    setState(() => _snapshotIds[_recipeKey(recipe.recipe)] = id);
  }
}

String _recipeKey(Map<String, int> recipe) {
  final entries = recipe.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return entries.map((entry) => '${entry.key}:${entry.value}').join('|');
}
