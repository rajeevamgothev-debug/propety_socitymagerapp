import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum CustomCardPadding { none, sm, md, lg }

class CustomCard extends StatelessWidget {
  const CustomCard({
    super.key,
    required this.child,
    this.padding = CustomCardPadding.md,
    this.onTap,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final CustomCardPadding padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(padding: _paddingFor(padding), child: child);
    final BorderRadius radius = BorderRadius.circular(AppTheme.radiusMedium);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? AppTheme.surface,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? AppTheme.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0D17202A),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
          BoxShadow(
            color: Color(0x08FFFFFF),
            blurRadius: 1,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, borderRadius: radius, child: content),
      ),
    );
  }

  EdgeInsets _paddingFor(CustomCardPadding value) {
    return switch (value) {
      CustomCardPadding.none => EdgeInsets.zero,
      CustomCardPadding.sm => const EdgeInsets.all(16),
      CustomCardPadding.md => const EdgeInsets.all(22),
      CustomCardPadding.lg => const EdgeInsets.all(28),
    };
  }
}
