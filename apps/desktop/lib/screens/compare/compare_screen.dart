part of '../../app/app.dart';

enum _CompareCategory { weapon, armor, unclassified }

class ComparePage extends StatefulWidget {
  const ComparePage({super.key, required this.database});
  final GameDataStore database;

  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  final Set<String> _selected = {};
  _CompareCategory _category = _CompareCategory.unclassified;

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Compare builds',
    subtitle: 'Compare saved ore recipes for the same craft target.',
    child: FutureBuilder<List<SavedBuildRecord>>(
      future: widget.database.getSavedBuilds(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final builds = snapshot.data!;
        _selected.removeWhere((id) => !builds.any((build) => build.id == id));

        final categorized = <_CompareCategory, List<SavedBuildRecord>>{
          _CompareCategory.weapon: builds
              .where((build) => build.craftGoal == 'WEAPON')
              .toList(growable: false),
          _CompareCategory.armor: builds
              .where((build) => build.craftGoal == 'ARMOR')
              .toList(growable: false),
          _CompareCategory.unclassified: builds
              .where((build) => build.craftGoal == null ||
                  (build.craftGoal != 'WEAPON' && build.craftGoal != 'ARMOR'))
              .toList(growable: false),
        };
        final categoryBuilds = categorized[_category]!;
        final visibleBuilds = categoryBuilds
            .where((build) => _selected.isEmpty || _selected.contains(build.id))
            .take(4)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    'Choose craft target',
                    subtitle:
                        'Recipes are compared only within the selected category.',
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<_CompareCategory>(
                    segments: const [
                      ButtonSegment(
                        value: _CompareCategory.weapon,
                        icon: Icon(Icons.gavel_outlined),
                        label: AppText('Weapon'),
                      ),
                      ButtonSegment(
                        value: _CompareCategory.armor,
                        icon: Icon(Icons.shield_outlined),
                        label: AppText('Armor'),
                      ),
                      ButtonSegment(
                        value: _CompareCategory.unclassified,
                        icon: Icon(Icons.help_outline),
                        label: AppText('Unclassified'),
                      ),
                    ],
                    selected: {_category},
                    onSelectionChanged: (value) => setState(() {
                      _category = value.single;
                      _selected.clear();
                    }),
                  ),
                  const SizedBox(height: 10),
                  AppText(
                    _category == _CompareCategory.unclassified
                        ? '${categoryBuilds.length} saved recipes have no recorded craft target. They are kept separate until their target is known.'
                        : '${categoryBuilds.length} saved recipes are recorded for this target.',
                    style: const TextStyle(color: _muted, fontSize: 13),
                    softWrap: true,
                  ),
                  if (categoryBuilds.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    SectionHeader(
                      _category == _CompareCategory.unclassified
                          ? 'Saved recipes without a target'
                          : 'Saved recipes for this target',
                      subtitle: _category == _CompareCategory.unclassified
                          ? 'Choose up to four. Their type is unknown, so these stay separate from Weapon and Armor comparisons.'
                          : 'Choose up to four recipes to compare side by side.',
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 7,
                      runSpacing: 5,
                      children: [
                        for (final build in categoryBuilds)
                          FilterChip(
                            label: AppText(build.name, translate: false),
                            selected: _selected.isEmpty
                                ? categoryBuilds.take(4).any((e) => e.id == build.id)
                                : _selected.contains(build.id),
                            onSelected: (selected) => setState(() {
                              if (_selected.isEmpty) {
                                _selected.addAll(categoryBuilds
                                    .take(selected ? 3 : 4)
                                    .map((e) => e.id));
                                if (selected) _selected.add(build.id);
                              }
                              if (selected && _selected.length < 4) {
                                _selected.add(build.id);
                              }
                              if (!selected) _selected.remove(build.id);
                            }),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SectionHeader('What is being compared?'),
                  SizedBox(height: 8),
                  AppText(
                    'Each saved recipe stores ore IDs, quantities, and its craft target. Ore values use the Best Available data policy. The multiplier source ID is shown on each card; rarity, price, and trait fields can have separate sources that this summary does not list.',
                    style: TextStyle(color: _muted, fontSize: 13),
                    softWrap: true,
                  ),
                  SizedBox(height: 7),
                  AppText(
                    'These are recipe and ore-data comparisons, not finished-item predictions. Damage, attack speed, armor stats, and DPS are not calculated here.',
                    style: TextStyle(color: _muted, fontSize: 13),
                    softWrap: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (categoryBuilds.isEmpty)
              AppCard(
                child: EmptyState(
                  title: builds.isEmpty ? 'No saved recipes yet' : 'No recipes in this category',
                  message: builds.isEmpty
                      ? 'Build and save a recipe in Forge to compare it here.'
                      : _category == _CompareCategory.unclassified
                      ? 'All saved recipes have a recorded craft target.'
                      : 'Save a recipe for this target in Forge. Recipes with no target remain under Unclassified.',
                  icon: Icons.compare_arrows,
                ),
              )
            else ...[
              FutureBuilder<List<OreRecord>>(
                future: widget.database.searchOres(''),
                builder: (context, oresSnapshot) {
                  if (!oresSnapshot.hasData) {
                    return const LinearProgressIndicator();
                  }
                  final ores = {
                    for (final ore in oresSnapshot.data!) ore.id: ore,
                  };
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1100
                          ? 3
                          : constraints.maxWidth >= 650
                          ? 2
                          : 1;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 12) / columns;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final build in visibleBuilds)
                            SizedBox(
                              width: width,
                              child: _compareCard(build, ores),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ],
        );
      },
    ),
  );

  Widget _compareCard(SavedBuildRecord build, Map<String, OreRecord> ores) {
    final picked = build.recipe.entries
        .where((entry) => ores.containsKey(entry.key))
        .toList();
    final total = picked.fold<int>(0, (sum, entry) => sum + entry.value);
    final allKnown =
        picked.isNotEmpty && picked.every((entry) => ores[entry.key]!.multiplier != null);
    final multiplier = allKnown
        ? picked.fold<double>(
                0,
                (sum, entry) =>
                    sum + ores[entry.key]!.multiplier! * entry.value,
              ) /
              total
        : null;
    final certainty = picked.isEmpty || !allKnown
        ? 0.0
        : picked
              .map((entry) => ores[entry.key]!.confidence ?? 0)
              .reduce((a, b) => a < b ? a : b);
    final effects = picked
        .expand((entry) => ores[entry.key]!.traits.map((trait) => trait.name))
        .toSet();
    final conflictCount = picked
        .where((entry) => ores[entry.key]!.verificationStatus == 'CONFLICTING')
        .length;
    final recipe = picked
        .map((entry) => '${ores[entry.key]!.name} ×${entry.value}')
        .join(', ');

    return AppCard(
      accent: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText(
                  build.name,
                  translate: false,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: appLocalizedText(context, 'Delete saved recipe'),
                onPressed: () async {
                  await widget.database.deleteBuild(build.id);
                  _selected.remove(build.id);
                  setState(() {});
                },
                icon: const Icon(Icons.delete_outline, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 3),
          AppText(
            recipe.isEmpty ? 'Empty recipe' : recipe,
            style: const TextStyle(color: _muted, fontSize: 13),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const Divider(height: 22),
          _compareMetric(
            'Ore multiplier',
            multiplier?.toStringAsFixed(3) ?? 'Unknown',
            highlight: true,
          ),
          _compareMetric(
            'Multiplier source ID',
            picked.isEmpty
                ? 'Unknown'
                : picked
                      .map((entry) => ores[entry.key]!.source)
                      .toSet()
                      .join(', '),
          ),
          _compareMetric('Damage', 'Unknown'),
          _compareMetric('Attack speed / interval', 'Unknown'),
          _compareMetric('Raw / expected DPS', 'Unknown'),
          _compareMetric('Known traits', effects.isEmpty ? 'Unknown' : effects.join(', ')),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ConfidenceBadge(certainty),
              StatusBadge('$conflictCount conflicts'),
            ],
          ),
          const SizedBox(height: 10),
          AppText(
            'Data confidence ${(certainty * 100).round()}% · ${picked.length} ore types',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _compareMetric(String label, String value, {bool highlight = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: AppText(
                label,
                style: const TextStyle(color: _muted, fontSize: 13),
              ),
            ),
            Flexible(
              child: AppText(
                value,
                textAlign: TextAlign.right,
                softWrap: true,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: highlight ? _accent : null,
                  fontSize: highlight ? 15 : 13,
                ),
              ),
            ),
          ],
        ),
      );
}
