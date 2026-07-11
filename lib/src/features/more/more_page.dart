import 'package:flutter/material.dart';

import '../../core/models/api_models.dart';
import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_card.dart';
import '../../core/widgets/tone_badge.dart';
import '../settings/rent_reminder_settings_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({
    super.key,
    required this.role,
    required this.modules,
    required this.onModuleSelected,
    required this.onLogout,
    this.vendor,
  });

  final AppRole role;
  final List<ModuleStatusItem> modules;
  final ValueChanged<ModuleStatusItem> onModuleSelected;
  final VoidCallback onLogout;
  final VendorData? vendor;

  @override
  Widget build(BuildContext context) {
    final List<ModuleStatusItem> readyModules = modules
        .where((ModuleStatusItem m) => m.readyNow)
        .toList();
    final List<ModuleStatusItem> comingModules = modules
        .where((ModuleStatusItem m) => !m.readyNow)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 124),
      children: <Widget>[
        _ProfileHeader(
          role: role,
          vendor: vendor,
          onTap: () => onModuleSelected(
            const ModuleStatusItem(
              title: 'Settings',
              subtitle: 'Profile and account preferences',
              icon: Icons.settings_outlined,
              phaseLabel: 'Ready now',
              actionKey: 'settings',
              readyNow: true,
            ),
          ),
        ),
        const SizedBox(height: 24),

        if (role == AppRole.propertyManager) ...<Widget>[
          _FoodManagementCard(onModuleSelected: onModuleSelected),
          const SizedBox(height: 16),
          _AccountReminderCard(vendor: vendor),
          const SizedBox(height: 24),
        ],

        if (readyModules.isNotEmpty)
          _ModuleSection(
            label: 'Modules',
            modules: readyModules,
            onModuleSelected: onModuleSelected,
            dimmed: false,
          ),

        if (comingModules.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          _ModuleSection(
            label: 'Coming soon',
            modules: comingModules,
            onModuleSelected: onModuleSelected,
            dimmed: true,
          ),
        ],

        const SizedBox(height: 24),
        _SignOutRow(onTap: onLogout),
      ],
    );
  }
}

class _FoodManagementCard extends StatelessWidget {
  const _FoodManagementCard({required this.onModuleSelected});

  final ValueChanged<ModuleStatusItem> onModuleSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return CustomCard(
      padding: CustomCardPadding.none,
      child: InkWell(
        onTap: () => onModuleSelected(
          const ModuleStatusItem(
            title: 'Food Management',
            subtitle: 'PG menus, resident voting, final menu and analytics',
            icon: Icons.restaurant_menu_rounded,
            phaseLabel: 'Ready now',
            actionKey: 'food_management',
            readyNow: true,
          ),
        ),
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF111827), Color(0xFF4F46E5)],
            ),
          ),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: const Icon(
                  Icons.restaurant_menu_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Food Management',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create weekly menus, run resident voting, finalize meals and track feedback.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const <Widget>[
                        ToneBadge(label: 'PG Food OS', tone: UiTone.brand),
                        ToneBadge(label: 'Voting', tone: UiTone.success),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(19),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF111827),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountReminderCard extends StatelessWidget {
  const _AccountReminderCard({this.vendor});

  final VendorData? vendor;

  @override
  Widget build(BuildContext context) {
    final bool enabled = vendor?.rentReminderSettings?.enabled ?? false;
    final String summary = enabled
        ? 'Manage WhatsApp rent reminders and your default bill schedule from one account page.'
        : 'Set WhatsApp reminders plus default bill date, due date, and due time.';

    return CustomCard(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const RentReminderSettingsPage(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: enabled ? const Color(0xFFE8FFF1) : AppTheme.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.alarm_on_rounded,
                color: enabled
                    ? const Color(0xFF15803D)
                    : const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Rent Reminder Alarm',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ToneBadge(
                    label: enabled ? 'Active' : 'Set Schedule',
                    tone: enabled ? UiTone.success : UiTone.brand,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile header — avatar, name, phone, role & vendor-ID badges
// ---------------------------------------------------------------------------

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.role,
    required this.vendor,
    required this.onTap,
  });

  final AppRole role;
  final VendorData? vendor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String displayName = (vendor?.fullName.isNotEmpty ?? false)
        ? vendor!.fullName
        : 'UrbanEasyFlats User';
    final String? phone = (vendor?.phone.isNotEmpty ?? false)
        ? vendor!.phone
        : null;

    return CustomCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: <Widget>[
            _ProfileAvatar(imageUrl: vendor?.imageUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (phone != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      phone,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: <Widget>[
                      ToneBadge(label: role.label, tone: UiTone.brand),
                      if (vendor?.vendorId.isNotEmpty ?? false)
                        ToneBadge(
                          label:
                              'ID: ${vendor!.vendorId.length > 8 ? '${vendor!.vendorId.substring(0, 8)}...' : vendor!.vendorId}',
                          tone: UiTone.neutral,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.person_rounded,
                color: AppTheme.primary,
                size: 28,
              ),
            )
          : const Icon(Icons.person_rounded, color: AppTheme.primary, size: 28),
    );
  }
}

// ---------------------------------------------------------------------------
// Module section — section header + card containing list rows
// ---------------------------------------------------------------------------

class _ModuleSection extends StatelessWidget {
  const _ModuleSection({
    required this.label,
    required this.modules,
    required this.onModuleSelected,
    required this.dimmed,
  });

  final String label;
  final List<ModuleStatusItem> modules;
  final ValueChanged<ModuleStatusItem> onModuleSelected;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: dimmed ? AppTheme.textSecondary : AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        CustomCard(
          padding: CustomCardPadding.none,
          child: Column(
            children: <Widget>[
              for (int i = 0; i < modules.length; i++) ...<Widget>[
                _MenuRow(
                  module: modules[i],
                  dimmed: dimmed,
                  onTap: () => onModuleSelected(modules[i]),
                ),
                if (i < modules.length - 1)
                  const Divider(height: 1, indent: 66, color: AppTheme.border),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Menu row — icon | title + subtitle | chevron / coming-soon badge
// ---------------------------------------------------------------------------

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.module,
    required this.dimmed,
    required this.onTap,
  });

  final ModuleStatusItem module;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color iconBg = dimmed
        ? AppTheme.surfaceMuted
        : AppTheme.toneSoft(UiTone.brand);
    final Color iconColor = dimmed
        ? AppTheme.textMuted
        : AppTheme.toneColor(UiTone.brand);

    return InkWell(
      onTap: dimmed ? null : onTap,
      child: Opacity(
        opacity: dimmed ? 0.55 : 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(module.icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      module.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      module.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (dimmed)
                const ToneBadge(label: 'Soon', tone: UiTone.neutral)
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppTheme.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sign-out row — red standalone row at the bottom
// ---------------------------------------------------------------------------

class _SignOutRow extends StatelessWidget {
  const _SignOutRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const Color red = Color(0xFFDC2626);

    return CustomCard(
      padding: CustomCardPadding.none,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout_outlined, color: red, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Sign out',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: red,
                ),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, size: 20, color: red),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholder page for modules that aren't ready yet
// ---------------------------------------------------------------------------

class ModulePlaceholderPage extends StatelessWidget {
  const ModulePlaceholderPage({super.key, required this.module});

  final ModuleStatusItem module;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Text(module.title),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.border),
        ),
      ),
      body: ListView(
        padding: AppTheme.pagePadding,
        children: <Widget>[
          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.toneSoft(UiTone.warning),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    module.icon,
                    color: AppTheme.toneColor(UiTone.warning),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  module.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  module.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                ToneBadge(
                  label: 'Module status: ${module.phaseLabel}',
                  tone: UiTone.warning,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
