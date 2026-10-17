part of '../app/app.dart';

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(17), this.accent = false});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool accent;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: _panel,
      border: Border.all(color: accent ? const Color(0xFF72502A) : _border),
      borderRadius: BorderRadius.circular(12),
      boxShadow: accent ? [BoxShadow(color: _accent.withValues(alpha: .08), blurRadius: 18)] : null,
    ),
    child: child,
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppText(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        if (subtitle != null) ...[const SizedBox(height: 3), AppText(subtitle!, style: const TextStyle(fontSize: 12, color: _muted))],
      ])),
      ?trailing,
    ],
  );
}

class MetricCard extends StatelessWidget {
  const MetricCard(this.label, this.value, this.detail, this.icon, {super.key});
  final String label, value, detail;
  final IconData icon;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [Icon(icon, size: 17, color: _accent), const SizedBox(width: 8), Expanded(child: AppText(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 12)))]),
      const SizedBox(height: 6),
      AppText(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700, height: 1)),
      const SizedBox(height: 4),
      AppText(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 12)),
    ]),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final known = status.toUpperCase() == 'IN_GAME_VERIFIED' || status.toUpperCase() == 'USER_CONFIRMED_CAPTURE';
    final conflict = status.toUpperCase().contains('CONFLICT');
    final color = conflict ? const Color(0xFFE58B73) : known ? const Color(0xFF75C49B) : _accent;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(30), border: Border.all(color: color.withValues(alpha: .3))), child: AppText(status.replaceAll('_', ' ').toLowerCase(), style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)));
  }
}

class ConfidenceBadge extends StatelessWidget {
  const ConfidenceBadge(this.confidence, {super.key});
  final double? confidence;
  @override
  Widget build(BuildContext context) => StatusBadge(confidence == null ? 'Unknown' : '${(confidence! * 100).round()}% confidence');
}

class OreChip extends StatelessWidget {
  const OreChip({super.key, required this.label, this.selected = false, this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ActionChip(label: AppText(label, translate: false), avatar: const Icon(Icons.diamond_outlined, size: 15), onPressed: onTap, backgroundColor: selected ? const Color(0xFF41301C) : _panel2);
}

class OreRow extends StatelessWidget {
  const OreRow({super.key, required this.name, required this.rarity, required this.multiplier, this.quantity, this.status});
  final String name, rarity, multiplier;
  final String? quantity, status;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Row(children: [
    const Icon(Icons.diamond_outlined, color: _accent, size: 18), const SizedBox(width: 11),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [AppText(name, translate: false, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), AppText(rarity, style: const TextStyle(color: _muted, fontSize: 12))])),
    AppText(multiplier, style: const TextStyle(fontSize: 15, color: _accent, fontWeight: FontWeight.w700)),
    if (quantity != null) ...[const SizedBox(width: 18), AppText(quantity!, style: const TextStyle(fontSize: 13))],
    if (status != null) ...[const SizedBox(width: 12), StatusBadge(status!)],
  ]));
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => icon == null ? FilledButton(onPressed: onPressed, child: AppText(label)) : FilledButton.icon(onPressed: onPressed, icon: Icon(icon), label: AppText(label));
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => icon == null ? OutlinedButton(onPressed: onPressed, child: AppText(label)) : OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon), label: AppText(label));
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.message, this.icon = Icons.inbox_outlined, this.action});
  final String title, message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 32, color: _subtle), const SizedBox(height: 12), AppText(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), const SizedBox(height: 6), AppText(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: _muted)), if (action != null) ...[const SizedBox(height: 16), action!]])));
}

class WarningBanner extends StatelessWidget {
  const WarningBanner({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: const Color(0xFF29231A), border: Border.all(color: const Color(0xFF624A2C)), borderRadius: BorderRadius.circular(10)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 18, color: _accent), const SizedBox(width: 10), Expanded(child: AppText(text, style: const TextStyle(color: Color(0xFFE2D3BE), fontSize: 13, height: 1.4)))]));
}

class _Surface extends AppCard { const _Surface({required super.child}); }
class _Metric extends MetricCard { const _Metric(super.label, super.value, super.detail, super.icon); }
class _Notice extends WarningBanner { const _Notice({required super.icon, required super.text}); }
class _StatusPill extends StatusBadge { const _StatusPill(super.status); }

class _ResultLine extends StatelessWidget {
  const _ResultLine(this.label, this.value, this.detail);
  final String label, value, detail;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: AppText(label, style: const TextStyle(fontSize: 13, color: _muted))), Flexible(child: AppText(value, textAlign: TextAlign.right, softWrap: true, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)))]), const SizedBox(height: 3), AppText(detail, softWrap: true, style: const TextStyle(fontSize: 12, color: _muted))]));
}

VerificationStatus _verificationStatus(String value) => switch (value.toUpperCase()) {
  'IN_GAME_VERIFIED' => VerificationStatus.inGameVerified,
  'MULTI_SOURCE_VERIFIED' => VerificationStatus.multiSourceVerified,
  'COMMUNITY' => VerificationStatus.community,
  'GUIDE_BASED' => VerificationStatus.guideBased,
  'CONFLICTING' => VerificationStatus.conflicting,
  'OUTDATED' => VerificationStatus.outdated,
  _ => VerificationStatus.unknown,
};
