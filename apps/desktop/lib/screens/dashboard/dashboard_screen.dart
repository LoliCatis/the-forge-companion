part of '../../app/app.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.database, this.onOpenForge, this.onOpenInventory, this.onOpenCompare});
  final GameDataStore database;
  final VoidCallback? onOpenForge;
  final VoidCallback? onOpenInventory;
  final VoidCallback? onOpenCompare;
  @override
  Widget build(BuildContext context) => _Page(
    title: 'Your forge at a glance',
    subtitle: 'Your local workshop for ore, recipes, and source-aware results.',
    child: FutureBuilder<List<Object?>>(
      future: _loadDashboard(database),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final inventory = data![2] as List<InventoryRecord>;
        final metrics = data[4] as VerificationMetrics;
        final available = inventory.fold<int>(0, (sum, item) => sum + (item.quantity - item.protectedQuantity).clamp(0, item.quantity).toInt());
        final types = inventory.where((item) => item.quantity > 0).length;
        final builds = data[3] as List<SavedBuildRecord>;
        final warnings = metrics.conflicts + metrics.pendingReview;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AppCard(accent: true, padding: const EdgeInsets.all(22), child: LayoutBuilder(builder: (context, constraints) {
            final intro = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const AppText('Ready when you are', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              AppText('Build a recipe, inspect the mix, and keep every value tied to its source.', style: const TextStyle(color: _muted, fontSize: 14, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 7),
              AppText('Active data · ${data[0] ?? 'not installed'}', style: const TextStyle(color: _muted, fontSize: 12)),
            ]);
            final actions = Wrap(spacing: 9, runSpacing: 8, children: [PrimaryButton(label: 'Open Forge', icon: Icons.local_fire_department_outlined, onPressed: onOpenForge), SecondaryButton(label: 'Inventory', icon: Icons.inventory_2_outlined, onPressed: onOpenInventory)]);
            return constraints.maxWidth < 760 ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [intro, const SizedBox(height: 18), actions]) : Row(children: [Expanded(child: intro), const SizedBox(width: 22), actions]);
          })),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, constraints) {
            final cols = constraints.maxWidth >= 900 ? 4 : constraints.maxWidth >= 560 ? 2 : 1;
            return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: cols == 1 ? 3.3 : 1.55, children: [
              MetricCard('Ore types in inventory', '$types', 'with stored quantity', Icons.diamond_outlined),
              MetricCard('Usable quantity', '$available', 'after protected stock', Icons.inventory_2_outlined),
              MetricCard('Last Forge scenario', builds.isEmpty ? '—' : builds.first.name, builds.isEmpty ? 'No saved recipes yet' : '${builds.length} saved ${builds.length == 1 ? 'recipe' : 'recipes'}', Icons.history),
              MetricCard('Verified coverage', '${metrics.gameVerified}', 'of ${metrics.gameVerified + metrics.communityOnly} known fields', Icons.verified_outlined),
            ]);
          }),
          if (warnings > 0) ...[
            const SizedBox(height: 14),
            WarningBanner(icon: Icons.warning_amber_rounded, text: '$warnings data items need attention. Review conflicts and pending captures in Data Health.'),
          ],
          const SizedBox(height: 14),
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeader('Your workspace', subtitle: 'Data stays on this device. Community values remain attributed and unverified.'),
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _workspaceLink(Icons.local_fire_department_outlined, 'Forge', 'Configure and inspect a recipe', onOpenForge),
              _workspaceLink(Icons.inventory_2_outlined, 'Inventory', 'Track available and protected ores', onOpenInventory),
              _workspaceLink(Icons.compare_arrows, 'Compare', 'Review saved recipes side by side', onOpenCompare),
            ]),
          ])),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft, child: AppText('Ruleset · ${data[1] ?? 'not installed'}', style: const TextStyle(fontSize: 12, color: _muted))),
        ]);
      },
    ),
  );
}

Widget _workspaceLink(IconData icon, String title, String detail, VoidCallback? onTap) => SizedBox(width: 235, child: AppCard(padding: EdgeInsets.zero, child: Material(color: Colors.transparent, borderRadius: BorderRadius.circular(12), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [Icon(icon, color: _accent, size: 20), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [AppText(title, style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 3), AppText(detail, style: const TextStyle(color: _muted, fontSize: 12))])), const SizedBox(width: 6), const Icon(Icons.arrow_forward, size: 14, color: _muted)]))))));

Future<List<Object?>> _loadDashboard(GameDataStore database) async => [
  await database.getActiveDataVersion(),
  await database.getActiveRulesetVersion(),
  await database.getInventory(),
  await database.getSavedBuilds(),
  await database.getVerificationMetrics(),
];
