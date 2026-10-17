part of 'app.dart';

class _Section {
  const _Section(this.title, this.icon, this.group);
  final String title;
  final IconData icon;
  final String group;
}

const _sections = [
  _Section('Dashboard', Icons.dashboard_outlined, 'WORKSPACE'),
  _Section('Inventory', Icons.inventory_2_outlined, 'WORKSPACE'),
  _Section('Forge', Icons.local_fire_department_outlined, 'WORKSPACE'),
  _Section('Optimizer', Icons.auto_awesome_outlined, 'WORKSPACE'),
  _Section('Compare', Icons.compare_arrows, 'WORKSPACE'),
  _Section('Ores', Icons.diamond_outlined, 'DATA TOOLS'),
  _Section('Data Health', Icons.fact_check_outlined, 'DATA TOOLS'),
  _Section('Verification', Icons.verified_user_outlined, 'DATA TOOLS'),
  _Section('Settings', Icons.settings_outlined, 'PREFERENCES'),
];

class CompanionShell extends StatefulWidget {
  const CompanionShell({super.key, required this.database, this.appDirectory, this.evidenceDirectory, required this.language, required this.onLanguageChanged});
  final GameDataStore database;
  final Directory? appDirectory;
  final Directory? evidenceDirectory;
  final String language;
  final ValueChanged<String> onLanguageChanged;
  @override
  State<CompanionShell> createState() => _CompanionShellState();
}

class _CompanionShellState extends State<CompanionShell> {
  int _selected = 0;
  int _refreshKey = 0;
  bool _collapsed = false;
  void _refresh() => setState(() => _refreshKey++);

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final compact = constraints.maxWidth < 1150;
    final collapsed = compact || _collapsed;
    final section = _sections[_selected];
    return Scaffold(
      body: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: collapsed ? 66 : 190,
          decoration: const BoxDecoration(color: Color(0xFF14181B), border: Border(right: BorderSide(color: _border))),
          child: Column(children: [
            Padding(padding: EdgeInsets.fromLTRB(collapsed ? 12 : 15, 18, 10, 15), child: Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFF392918), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.local_fire_department, color: _accent, size: 22)),
              if (!collapsed) ...[const SizedBox(width: 10), const Expanded(child: AppText('The Forge\nCompanion', style: TextStyle(fontSize: 14, height: 1.2, fontWeight: FontWeight.w700)))],
            ])),
            const Divider(height: 1),
            Expanded(child: ListView(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 7), children: [
              for (final group in const ['WORKSPACE', 'DATA TOOLS', 'PREFERENCES']) ...[
                if (!collapsed) Padding(padding: const EdgeInsets.fromLTRB(10, 14, 0, 6), child: AppText(group == 'WORKSPACE' ? 'WORKSPACE' : group == 'DATA TOOLS' ? 'DATA TOOLS' : 'PREFERENCES', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .8, color: _subtle))),
                for (var i = 0; i < _sections.length; i++) if (_sections[i].group == group)
                  _NavItem(section: _sections[i], selected: _selected == i, collapsed: collapsed, onTap: () => setState(() => _selected = i)),
              ],
            ])),
            IconButton(tooltip: appLocalizedText(context, collapsed ? 'Expand navigation' : 'Collapse navigation'), onPressed: compact ? null : () => setState(() => _collapsed = !_collapsed), icon: Icon(collapsed ? Icons.keyboard_double_arrow_right : Icons.keyboard_double_arrow_left, color: _muted)),
            if (!collapsed) const Padding(padding: EdgeInsets.fromLTRB(12, 0, 10, 14), child: Row(children: [Icon(Icons.circle, color: Color(0xFF74B68F), size: 8), SizedBox(width: 8), Expanded(child: AppText('Local data ready', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: _muted))) ])),
          ]),
        ),
        Expanded(child: Column(children: [
          Container(height: 54, padding: const EdgeInsets.symmetric(horizontal: 18), decoration: const BoxDecoration(color: Color(0xFF121619), border: Border(bottom: BorderSide(color: _border))), child: Row(children: [
            Icon(section.icon, size: 18, color: _accent), const SizedBox(width: 10), AppText(section.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const Spacer(), if (constraints.maxWidth > 760) const Flexible(child: AppText('Values keep their source and confidence', textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, style: TextStyle(color: _muted, fontSize: 12))),
          ])),
          Expanded(child: KeyedSubtree(key: ValueKey('$_selected-$_refreshKey'), child: _page(section))),
        ])),
      ]),
    );
  });

  Widget _page(_Section section) => switch (section.title) {
    'Dashboard' => DashboardPage(database: widget.database, onOpenForge: () => setState(() => _selected = 2), onOpenInventory: () => setState(() => _selected = 1), onOpenCompare: () => setState(() => _selected = 4)),
    'Inventory' => InventoryPage(database: widget.database, onChanged: _refresh),
    'Forge' => ForgePage(database: widget.database),
    'Optimizer' => OptimizerPage(database: widget.database),
    'Ores' => OresPage(database: widget.database, onChanged: _refresh),
    'Compare' => ComparePage(database: widget.database),
    'Data Health' => DataHealthPage(database: widget.database),
    'Verification' => VerificationPage(database: widget.database, evidenceDirectory: widget.evidenceDirectory ?? Directory(p.join(Directory.systemTemp.path, 'the-forge-companion-evidence'))),
    'Settings' => _SettingsPage(
      language: widget.language,
      appDirectory: widget.appDirectory,
      onLanguageChanged: widget.onLanguageChanged,
    ),
    _ => _ComingSoonPage(title: section.title),
  };
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.section, required this.selected, required this.collapsed, required this.onTap});
  final _Section section;
  final bool selected, collapsed;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Tooltip(message: collapsed ? appLocalizedText(context, section.title) : '', child: Material(color: selected ? const Color(0xFF32271A) : Colors.transparent, borderRadius: BorderRadius.circular(9), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(9), child: SizedBox(height: 40, child: Row(children: [
    const SizedBox(width: 11), Icon(section.icon, size: 19, color: selected ? _accent : _muted),
    if (!collapsed) ...[const SizedBox(width: 11), Expanded(child: AppText(section.title, style: TextStyle(fontSize: 13, color: selected ? Colors.white : _muted, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)))],
  ]))))));
}
