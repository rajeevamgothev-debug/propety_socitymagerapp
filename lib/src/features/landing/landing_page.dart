import 'package:flutter/material.dart';

import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key, required this.onOpenAuth});

  final ValueChanged<AuthSource> onOpenAuth;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFBFAF7),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
          children: <Widget>[
            _LandingHero(theme: theme),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.border),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x0D17202A),
                    blurRadius: 22,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Choose your workspace',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Continue with the account type connected to your mobile number.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _WorkspaceOptionTile(
                    source: AuthSource.propertyManagement,
                    onTap: () => onOpenAuth(AuthSource.propertyManagement),
                    accentColor: AppTheme.primary,
                    meta: 'Listings, tenants, rent and contracts',
                  ),
                  const SizedBox(height: 12),
                  _WorkspaceOptionTile(
                    source: AuthSource.society,
                    onTap: () => onOpenAuth(AuthSource.society),
                    accentColor: AppTheme.secondary,
                    meta: 'Residents, maintenance and society operations',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandingHero extends StatelessWidget {
  const _LandingHero({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.border),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x0D17202A),
                    blurRadius: 22,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Image.asset(
                  'assets/manager_logo.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text(
                'Manager App',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          'Your operations desk, refined for everyday work.',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w900,
            height: 1.12,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Choose the workspace that matches your account. Each path opens the tools, records, billing, and support workflows built for that role.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.textSecondary,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _WorkspaceOptionTile extends StatelessWidget {
  const _WorkspaceOptionTile({
    required this.source,
    required this.onTap,
    required this.accentColor,
    required this.meta,
  });

  final AuthSource source;
  final VoidCallback onTap;
  final Color accentColor;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(source.icon, color: accentColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      source.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 17,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
