part of 'app.dart';

class _Section {
  const _Section(this.title, this.icon, this.group, {this.label});
  final String title;
  final IconData icon;
  final String group;
  final String? label;
  String get displayTitle => label ?? title;
}

const _sections = [
  _Section('Dashboard', Icons.dashboard_outlined, 'WORKSPACE'),
  _Section('Forge', Icons.local_fire_department_outlined, 'WORKSPACE'),
  _Section('Compare', Icons.compare_arrows, 'WORKSPACE'),
  _Section('Ores', Icons.diamond_outlined, 'DATA / RESEARCH'),
  _Section('Data Health', Icons.fact_check_outlined, 'DATA / RESEARCH', label: 'Data status'),
  _Section('Verification', Icons.menu_book_outlined, 'DATA / RESEARCH', label: 'Wiki review'),
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
  bool _dataResearchExpanded = false;
  void _refresh() => setState(() => _refreshKey++);

  void _selectSection(String title) => setState(() {
    final index = _sections.indexWhere((candidate) => candidate.title == title);
    if (index < 0) return;
    _selected = index;
    if (_sections[index].group == 'DATA / RESEARCH') {
      _dataResearchExpanded = true;
    }
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final compact = constraints.maxWidth < 1150;
    final collapsed = compact || _collapsed;
    final section = _sections[_selected];
    final showDataResearch = _dataResearchExpanded;
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
              if (!collapsed) const Padding(padding: EdgeInsets.fromLTRB(10, 8, 0, 4), child: AppText('WORKSPACE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .8, color: _subtle))),
              for (var i = 0; i < _sections.length; i++) if (_sections[i].group == 'WORKSPACE')
                _NavItem(section: _sections[i], selected: _selected == i, collapsed: collapsed, onTap: () => setState(() => _selected = i)),
              const SizedBox(height: 8),
              _DataResearchNavHeader(
                collapsed: collapsed,
                expanded: showDataResearch,
                onTap: () => setState(() => _dataResearchExpanded = !_dataResearchExpanded),
              ),
              if (showDataResearch)
                for (var i = 0; i < _sections.length; i++) if (_sections[i].group == 'DATA / RESEARCH')
                  _NavItem(section: _sections[i], selected: _selected == i, collapsed: collapsed, onTap: () => setState(() { _selected = i; _dataResearchExpanded = true; })),
              const SizedBox(height: 8),
              if (!collapsed) const Padding(padding: EdgeInsets.fromLTRB(10, 8, 0, 4), child: AppText('PREFERENCES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .8, color: _subtle))),
              for (var i = 0; i < _sections.length; i++) if (_sections[i].group == 'PREFERENCES')
                _NavItem(section: _sections[i], selected: _selected == i, collapsed: collapsed, onTap: () => setState(() => _selected = i)),
            ])),
            IconButton(tooltip: appLocalizedText(context, collapsed ? 'Expand navigation' : 'Collapse navigation'), onPressed: compact ? null : () => setState(() => _collapsed = !_collapsed), icon: Icon(collapsed ? Icons.keyboard_double_arrow_right : Icons.keyboard_double_arrow_left, color: _muted)),
            if (!collapsed) const Padding(padding: EdgeInsets.fromLTRB(12, 0, 10, 14), child: Row(children: [Icon(Icons.circle, color: Color(0xFF74B68F), size: 8), SizedBox(width: 8), Expanded(child: AppText('Local data ready', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: _muted))) ])),
          ]),
        ),
        Expanded(child: Column(children: [
          Container(height: 54, padding: const EdgeInsets.symmetric(horizontal: 18), decoration: const BoxDecoration(color: Color(0xFF121619), border: Border(bottom: BorderSide(color: _border))), child: Row(children: [
            Icon(section.icon, size: 18, color: _accent), const SizedBox(width: 10), AppText(section.displayTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const Spacer(), if (constraints.maxWidth > 760) const Flexible(child: AppText('Values keep their source and confidence', textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, style: TextStyle(color: _muted, fontSize: 12))),
          ])),
          Expanded(child: KeyedSubtree(key: ValueKey('$_selected-$_refreshKey'), child: _page(section))),
        ])),
      ]),
    );
  });

  Widget _page(_Section section) => switch (section.title) {
    'Dashboard' => DashboardPage(database: widget.database, onOpenForge: () => _selectSection('Forge'), onOpenOres: () => _selectSection('Ores'), onOpenCompare: () => _selectSection('Compare')),
    'Forge' => ForgePage(database: widget.database),
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
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Tooltip(message: collapsed ? appLocalizedText(context, section.displayTitle) : '', child: Material(color: selected ? const Color(0xFF32271A) : Colors.transparent, borderRadius: BorderRadius.circular(9), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(9), child: SizedBox(height: 40, child: Row(children: [
    const SizedBox(width: 11), Icon(section.icon, size: 19, color: selected ? _accent : _muted),
    if (!collapsed) ...[const SizedBox(width: 11), Expanded(child: AppText(section.displayTitle, style: TextStyle(fontSize: 13, color: selected ? Colors.white : _muted, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)))],
  ]))))));
}

class _DataResearchNavHeader extends StatelessWidget {
  const _DataResearchNavHeader({required this.collapsed, required this.expanded, required this.onTap});
  final bool collapsed;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: collapsed ? appLocalizedText(context, 'DATA / RESEARCH') : '',
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          height: 40,
          child: Row(children: [
            const SizedBox(width: 11),
            const Icon(Icons.library_books_outlined, size: 19, color: _muted),
            if (!collapsed) ...[
              const SizedBox(width: 11),
              Expanded(child: AppText('DATA / RESEARCH', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .3, color: _subtle))),
              Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 18, color: _muted),
              const SizedBox(width: 7),
            ],
          ]),
        ),
      ),
    ),
  );
}
