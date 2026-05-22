import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum CustomTabBarStyle { underline, pill }

class CustomTabItem {
  const CustomTabItem({required this.label, this.icon, this.trailing});

  final String label;
  final IconData? icon;
  final Widget? trailing;
}

class CustomTabBar extends StatelessWidget {
  const CustomTabBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onChanged,
    this.style = CustomTabBarStyle.underline,
  });

  final List<CustomTabItem> tabs;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final CustomTabBarStyle style;

  @override
  Widget build(BuildContext context) {
    final Widget row = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List<Widget>.generate(tabs.length, (int index) {
          final CustomTabItem tab = tabs[index];
          final bool selected = index == currentIndex;
          return Padding(
            padding: EdgeInsets.only(
              right: style == CustomTabBarStyle.pill ? 8 : 24,
            ),
            child: _CustomTabButton(
              item: tab,
              selected: selected,
              style: style,
              onTap: () => onChanged(index),
            ),
          );
        }),
      ),
    );

    if (style == CustomTabBarStyle.underline) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border)),
        ),
        child: row,
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.border),
      ),
      child: row,
    );
  }
}

class _CustomTabButton extends StatelessWidget {
  const _CustomTabButton({
    required this.item,
    required this.selected,
    required this.style,
    required this.onTap,
  });

  final CustomTabItem item;
  final bool selected;
  final CustomTabBarStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isUnderline = style == CustomTabBarStyle.underline;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isUnderline ? 4 : 15,
            vertical: isUnderline ? 12 : 10,
          ),
          decoration: BoxDecoration(
            color: isUnderline
                ? Colors.transparent
                : selected
                ? AppTheme.surface
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            boxShadow: !isUnderline && selected
                ? const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x0D17202A),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ]
                : null,
            border: isUnderline
                ? Border(
                    bottom: BorderSide(
                      color: selected ? AppTheme.primary : Colors.transparent,
                      width: 2,
                    ),
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (item.icon != null) ...<Widget>[
                Icon(
                  item.icon,
                  size: 16,
                  color: selected ? AppTheme.primary : AppTheme.textMuted,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                item.label,
                style: TextStyle(
                  color: selected
                      ? (isUnderline ? AppTheme.primary : AppTheme.primary)
                      : AppTheme.textMuted,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  height: 1.429,
                ),
              ),
              if (item.trailing != null) ...<Widget>[
                const SizedBox(width: 8),
                item.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
