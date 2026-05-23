import 'package:flutter/material.dart';

import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_button.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key, required this.onRoleSelected});

  final ValueChanged<AppRole> onRoleSelected;

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  AppRole _selectedRole = AppRole.propertyManager;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
          children: <Widget>[
            Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/manager_logo.jpg',
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    'Workspace',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _BuildingPanel(selectedRole: _selectedRole),
            const SizedBox(height: 26),
            Text(
              'Choose workspace',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.08,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select the operating mode for this session.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            _WorkspaceCard(
              role: AppRole.propertyManager,
              selected: _selectedRole == AppRole.propertyManager,
              title: 'Property Management',
              subtitle: 'Listings, enquiries, rental contracts, bills.',
              icon: Icons.home_work_outlined,
              onTap: () {
                setState(() => _selectedRole = AppRole.propertyManager);
              },
            ),
            const SizedBox(height: 12),
            _WorkspaceCard(
              role: AppRole.societyManager,
              selected: _selectedRole == AppRole.societyManager,
              title: 'Society Management',
              subtitle: 'Residents, maintenance billing, notices, security.',
              icon: Icons.apartment_outlined,
              onTap: () {
                setState(() => _selectedRole = AppRole.societyManager);
              },
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                label: 'Continue',
                icon: const Icon(Icons.arrow_forward_rounded),
                size: CustomButtonSize.lg,
                onPressed: () => widget.onRoleSelected(_selectedRole),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildingPanel extends StatelessWidget {
  const _BuildingPanel({required this.selectedRole});

  final AppRole selectedRole;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      height: 174,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEFE8DE),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE4D9CB)),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -10,
            bottom: -16,
            child: Icon(
              Icons.location_city_rounded,
              size: 130,
              color: AppTheme.primary.withAlpha(30),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Icon(selectedRole.icon, color: AppTheme.primary),
              ),
              const Spacer(),
              Text(
                'UrbanEasyFlats',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                selectedRole.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({
    required this.role,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final AppRole role;
  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.border,
              width: selected ? 1.4 : 1,
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x0D121A26),
                blurRadius: 20,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primarySoft : AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: AppTheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppTheme.primary : AppTheme.borderStrong,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 17,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
