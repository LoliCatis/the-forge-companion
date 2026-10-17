part of '../../app/app.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key, required this.database, required this.onChanged});
  final GameDataStore database;
  final VoidCallback onChanged;
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  String _query = '';
  String _rarityFilter = 'All';
  String _sortBy = 'Name';

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Inventory',
    subtitle: 'Track what you have and reserve the pieces you want to keep.',
    child: FutureBuilder<List<InventoryRecord>>(
      future: widget.database.getInventory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final all = snapshot.data!;
        final rows = all.where((row) => row.oreName.toLowerCase().contains(_query.toLowerCase()) && (_rarityFilter == 'All' || (row.rarity ?? 'Unknown').toLowerCase() == _rarityFilter.toLowerCase())).toList();
        rows.sort((a, b) => switch (_sortBy) {'Quantity' => b.quantity.compareTo(a.quantity), 'Rarity' => (a.rarity ?? 'Unknown').compareTo(b.rarity ?? 'Unknown'), _ => a.oreName.compareTo(b.oreName)});
        final usable = all.fold<int>(0, (sum, row) => sum + (row.quantity - row.protectedQuantity).clamp(0, row.quantity).toInt());
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          LayoutBuilder(builder: (context, constraints) {
            final cols = constraints.maxWidth > 900 ? 3 : constraints.maxWidth > 540 ? 2 : 1;
            return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: cols, childAspectRatio: cols == 1 ? 5 : 3.3, crossAxisSpacing: 10, mainAxisSpacing: 10, children: [
              MetricCard('Available to forge', '$usable', 'quantity after reservations', Icons.inventory_2_outlined),
              MetricCard('Ores tracked', '${all.where((row) => row.quantity > 0).length}', 'with a stored quantity', Icons.diamond_outlined),
              MetricCard('Protected stock', '${all.fold<int>(0, (sum, row) => sum + row.protectedQuantity)}', 'reserved from calculations', Icons.lock_outline),
            ]);
          }),
          const SizedBox(height: 14),
          AppCard(padding: const EdgeInsets.all(12), child: Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 300, child: TextField(decoration: InputDecoration(prefixIcon: Icon(Icons.search), hintText: appLocalizedText(context, 'Find an ore'), isDense: true), onChanged: (value) => setState(() => _query = value)),),
            SizedBox(width: 190, child: DropdownButtonFormField<String>(isExpanded: true, initialValue: _rarityFilter, decoration: InputDecoration(labelText: appLocalizedText(context, 'Rarity'), isDense: true), items: const ['All', 'Unknown', 'Common', 'Uncommon', 'Rare', 'Epic', 'Legendary', 'Mythic'].map((value) => DropdownMenuItem(value: value, child: AppText(value, overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) => setState(() => _rarityFilter = value ?? 'All'))),
            SizedBox(width: 170, child: DropdownButtonFormField<String>(isExpanded: true, initialValue: _sortBy, decoration: InputDecoration(labelText: appLocalizedText(context, 'Sort by'), isDense: true), items: const ['Name', 'Quantity', 'Rarity'].map((value) => DropdownMenuItem(value: value, child: AppText(value, overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) => setState(() => _sortBy = value ?? 'Name'))),
          ])),
          const SizedBox(height: 12),
          if (rows.isEmpty) const AppCard(child: EmptyState(title: 'No ores match', message: 'Try another search or clear the rarity filter.', icon: Icons.search_off)),
          for (final row in rows) ...[
            _InventoryOreCard(row: row, database: widget.database, onChanged: () { widget.onChanged(); setState(() {}); }),
            const SizedBox(height: 8),
          ],
        ]);
      },
    ),
  );
}

class _InventoryOreCard extends StatelessWidget {
  const _InventoryOreCard({required this.row, required this.database, required this.onChanged});
  final InventoryRecord row;
  final GameDataStore database;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => AppCard(padding: const EdgeInsets.fromLTRB(15, 13, 15, 14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Wrap(spacing: 10, runSpacing: 7, crossAxisAlignment: WrapCrossAlignment.center, children: [
      const Icon(Icons.diamond_outlined, size: 18, color: _accent),
      AppText(row.oreName, translate: false, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      StatusBadge(row.rarity ?? 'Unknown'),
      AppText(row.multiplier == null ? 'Multiplier unknown' : '${row.multiplier!.toStringAsFixed(3)}×', style: const TextStyle(color: _accent, fontSize: 15, fontWeight: FontWeight.w700)),
      Tooltip(message: '${row.verificationStatus} · confidence ${row.confidence == null ? 'unknown' : '${(row.confidence! * 100).round()}%'}', child: Icon(Icons.circle, color: row.verificationStatus == 'IN_GAME_VERIFIED' ? const Color(0xFF75C49B) : _accent, size: 10)),
    ]),
    const Divider(height: 20),
    Wrap(spacing: 14, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
      SizedBox(width: 145, child: _InventoryField(label: 'Quantity owned', value: row.quantity, onSubmitted: (count) async { if (count < row.protectedQuantity) return; await _saveQuantity(row, count); })),
      SizedBox(width: 145, child: _InventoryField(label: 'Protected', value: row.protectedQuantity, onSubmitted: (count) async { if (count > row.quantity) return; await _saveProtected(row, count); })),
      AppText('${(row.quantity - row.protectedQuantity).clamp(0, row.quantity)} available for recipes', style: const TextStyle(color: _muted, fontSize: 12)),
    ]),
  ]));

  Future<void> _saveQuantity(InventoryRecord row, int count) async {
    await database.setInventoryQuantity(row.oreId, count, protectedQuantity: row.protectedQuantity);
    onChanged();
  }
  Future<void> _saveProtected(InventoryRecord row, int count) async {
    await database.setProtectedQuantity(row.oreId, count);
    onChanged();
  }
}

class _InventoryField extends StatelessWidget {
  const _InventoryField({required this.label, required this.value, required this.onSubmitted});
  final String label;
  final int value;
  final Future<void> Function(int) onSubmitted;
  @override
  Widget build(BuildContext context) => TextFormField(key: ValueKey('$label-$value'), initialValue: '$value', keyboardType: TextInputType.number, decoration: InputDecoration(labelText: appLocalizedText(context, label), isDense: true, suffixIcon: const Icon(Icons.edit_outlined, size: 16)), onFieldSubmitted: (text) { final parsed = int.tryParse(text); if (parsed != null && parsed >= 0) onSubmitted(parsed); });
}
