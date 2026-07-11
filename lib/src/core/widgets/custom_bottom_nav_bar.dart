import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CustomBottomNavItem {
  const CustomBottomNavItem({
    required this.label,
    required this.icon,
    this.floating = false,
  });

  final String label;
  final IconData icon;
  // kept for API compatibility, no longer used
  final bool floating;
}

class CustomBottomNavBar extends StatelessWidget {
  const CustomBottomNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<CustomBottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x140B1526),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: List<Widget>.generate(items.length, (int index) {
                return Expanded(
                  child: _NavItem(
                    item: items[index],
                    selected: selectedIndex == index,
                    onTap: () => onSelected(index),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final CustomBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? AppTheme.primary : AppTheme.textMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected ? AppTheme.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: selected ? Border.all(color: AppTheme.primaryTone) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(item.icon, size: 20, color: color),
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: color,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
