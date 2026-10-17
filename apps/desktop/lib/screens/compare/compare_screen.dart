part of '../../app/app.dart';

class ComparePage extends StatefulWidget {
  const ComparePage({super.key, required this.database});
  final GameDataStore database;
  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Compare builds',
    subtitle: 'See recipe composition, multipliers, and what the current data cannot establish.',
    child: FutureBuilder<List<SavedBuildRecord>>(
      future: widget.database.getSavedBuilds(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final builds = snapshot.data!;
        _selected.removeWhere((id) => !builds.any((build) => build.id == id));
        if (builds.isEmpty) return const AppCard(child: EmptyState(title: 'No saved recipes yet', message: 'Build and save a recipe in Forge to compare it here.', icon: Icons.compare_arrows));
        final visibleBuilds = builds.where((build) => _selected.isEmpty || _selected.contains(build.id)).take(4).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeader('Saved recipes', subtitle: 'Choose up to four recipes to compare.'),
            const SizedBox(height: 10),
            Wrap(spacing: 7, runSpacing: 5, children: [for (final build in builds) FilterChip(label: AppText(build.name, translate: false), selected: _selected.isEmpty || _selected.contains(build.id), onSelected: (selected) => setState(() {
              if (_selected.isEmpty) _selected.addAll(builds.take(4).map((e) => e.id));
              if (selected && _selected.length < 4) _selected.add(build.id);
              if (!selected) _selected.remove(build.id);
            }))]),
          ])),
          const SizedBox(height: 13),
          FutureBuilder<List<OreRecord>>(future: widget.database.searchOres(''), builder: (context, oresSnapshot) {
            if (!oresSnapshot.hasData) return const LinearProgressIndicator();
            final ores = {for (final ore in oresSnapshot.data!) ore.id: ore};
            return LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1100 ? 3 : constraints.maxWidth >= 650 ? 2 : 1;
              final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(spacing: 12, runSpacing: 12, children: [for (final build in visibleBuilds) SizedBox(width: width, child: _compareCard(build, ores))]);
            });
          }),
          const SizedBox(height: 10),
          const WarningBanner(icon: Icons.info_outline, text: 'Weapon damage and attack speed are not available as verified local inputs, so DPS remains Unknown for every recipe.'),
        ]);
      },
    ),
  );

  Widget _compareCard(SavedBuildRecord build, Map<String, OreRecord> ores) {
    final picked = build.recipe.entries.where((entry) => ores.containsKey(entry.key)).toList();
    final total = picked.fold<int>(0, (sum, entry) => sum + entry.value);
    final allKnown = picked.isNotEmpty && picked.every((entry) => ores[entry.key]!.multiplier != null);
    final multiplier = allKnown ? picked.fold<double>(0, (sum, entry) => sum + ores[entry.key]!.multiplier! * entry.value) / total : null;
    final certainty = picked.isEmpty || !allKnown ? 0.0 : picked.map((entry) => ores[entry.key]!.confidence ?? 0).reduce((a, b) => a < b ? a : b);
    final effects = picked.expand((entry) => ores[entry.key]!.traits.map((trait) => trait.name)).toSet();
    final conflictCount = picked.where((entry) => ores[entry.key]!.verificationStatus == 'CONFLICTING').length;
    final recipe = picked.map((entry) => '${ores[entry.key]!.name} ×${entry.value}').join(', ');
    return AppCard(accent: true, padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Expanded(child: AppText(build.name, translate: false, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)), IconButton(tooltip: appLocalizedText(context, 'Delete saved recipe'), onPressed: () async { await widget.database.deleteBuild(build.id); _selected.remove(build.id); setState(() {}); }, icon: const Icon(Icons.delete_outline, size: 19))]),
      const SizedBox(height: 3),
      AppText(recipe.isEmpty ? 'Empty recipe' : recipe, style: const TextStyle(color: _muted, fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
      const Divider(height: 22),
      _compareMetric('Ore multiplier', multiplier?.toStringAsFixed(3) ?? 'Unknown', highlight: true),
      _compareMetric('Damage', 'Unknown'),
      _compareMetric('Attack speed / interval', 'Unknown'),
      _compareMetric('Raw / expected DPS', 'Unknown'),
      _compareMetric('Known traits', effects.isEmpty ? 'Unknown' : effects.join(', ')),
      const SizedBox(height: 9),
      Wrap(spacing: 8, runSpacing: 6, children: [ConfidenceBadge(certainty), StatusBadge('$conflictCount conflicts')]),
      const SizedBox(height: 10),
      AppText('Data confidence ${(certainty * 100).round()}% · ${picked.length} ore types', style: const TextStyle(color: _muted, fontSize: 12)),
    ]));
  }

  Widget _compareMetric(String label, String value, {bool highlight = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: AppText(label, style: const TextStyle(color: _muted, fontSize: 13))), Flexible(child: AppText(value, textAlign: TextAlign.right, softWrap: true, style: TextStyle(fontWeight: FontWeight.w600, color: highlight ? _accent : null, fontSize: highlight ? 15 : 13)))]));
}
