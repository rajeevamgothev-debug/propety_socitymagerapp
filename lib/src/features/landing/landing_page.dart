import 'package:flutter/material.dart';

import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key, required this.onOpenAuth});

  final ValueChanged<AuthSource> onOpenAuth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F1),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Size viewport = constraints.biggest;
            final bool wide =
                viewport.width >= 900 ||
                (viewport.width > viewport.height && viewport.width >= 700);

            if (wide) {
              return _LandingWideLayout(
                viewport: viewport,
                onOpenAuth: onOpenAuth,
              );
            }

            return _LandingCompactLayout(
              viewport: viewport,
              onOpenAuth: onOpenAuth,
            );
          },
        ),
      ),
    );
  }
}

class _LandingCompactLayout extends StatelessWidget {
  const _LandingCompactLayout({
    required this.viewport,
    required this.onOpenAuth,
  });

  final Size viewport;
  final ValueChanged<AuthSource> onOpenAuth;

  @override
  Widget build(BuildContext context) {
    final bool compact = viewport.height < 780 || viewport.width < 390;
    final double heroHeight = (viewport.height * (compact ? 0.35 : 0.38))
        .clamp(252.0, 320.0)
        .toDouble();

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Column(
          children: <Widget>[
            SizedBox(
              height: heroHeight,
              child: _LandingHero(
                compact: compact,
                wide: false,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(40),
                ),
              ),
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
        Positioned.fill(
          top: heroHeight - 24,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(38)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Color(0x12111A2A),
                  blurRadius: 26,
                  offset: Offset(0, -6),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                compact ? 16 : 20,
                20,
                10 + MediaQuery.paddingOf(context).bottom,
              ),
              child: _WorkspaceSection(
                onOpenAuth: onOpenAuth,
                dense: compact,
                cardsInline: false,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LandingWideLayout extends StatelessWidget {
  const _LandingWideLayout({required this.viewport, required this.onOpenAuth});

  final Size viewport;
  final ValueChanged<AuthSource> onOpenAuth;

  @override
  Widget build(BuildContext context) {
    final bool compact = viewport.height < 620;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 11,
            child: _LandingHero(
              compact: compact,
              wide: true,
              borderRadius: BorderRadius.circular(40),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            flex: 10,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(40),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x12111A2A),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                child: _WorkspaceSection(
                  onOpenAuth: onOpenAuth,
                  dense: compact,
                  cardsInline: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingHero extends StatelessWidget {
  const _LandingHero({
    required this.compact,
    required this.wide,
    required this.borderRadius,
  });

  static const Color _accentColor = Color(0xFFFF6B6B);

  final bool compact;
  final bool wide;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double textWidth = wide
            ? constraints.maxWidth * 0.58
            : constraints.maxWidth * (compact ? 0.7 : 0.66);
        final double titleSize = wide ? 56 : (compact ? 31 : 36);
        final double subtitleSize = compact ? 13.5 : 15;

        return ClipRRect(
          borderRadius: borderRadius,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Image.asset(
                'assets/landing_hero_workspace.png',
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: <Color>[
                      const Color(0xFFFDFBF7),
                      const Color(0xFFFDFBF7).withValues(alpha: 0.95),
                      const Color(0xFFFDFBF7).withValues(alpha: 0.82),
                      const Color(0xFFFDFBF7).withValues(alpha: 0.18),
                    ],
                    stops: const <double>[0, 0.38, 0.60, 1],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  wide ? 26 : 18,
                  18,
                  wide ? 26 : 18,
                  wide ? 26 : 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: wide ? 68 : (compact ? 54 : 58),
                          height: wide ? 68 : (compact ? 54 : 58),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            shape: BoxShape.circle,
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x12111A2A),
                                blurRadius: 16,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/manager_logo.jpg',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: wide ? 18 : (compact ? 14 : 16),
                            vertical: wide ? 11 : (compact ? 9 : 10),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.person_outline_rounded,
                                size: 20,
                                color: AppTheme.textPrimary,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Manager App',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: compact ? 14 : null,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 20,
                                color: AppTheme.textPrimary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: textWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text.rich(
                            TextSpan(
                              style: theme.textTheme.headlineLarge?.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: titleSize,
                                height: 1.02,
                                letterSpacing: 0,
                              ),
                              children: <InlineSpan>[
                                const TextSpan(text: 'Everything you\n'),
                                const TextSpan(text: 'manage, in one\n'),
                                TextSpan(
                                  text: 'beautiful ',
                                  style: const TextStyle(color: _accentColor),
                                ),
                                const TextSpan(text: 'place.'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: compact ? 110 : 132,
                            height: 4,
                            decoration: BoxDecoration(
                              color: _accentColor.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Pick the workspace that fits you best and get started.',
                            maxLines: compact ? 2 : 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: AppTheme.textSecondary,
                              fontSize: subtitleSize,
                              height: 1.42,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WorkspaceSection extends StatelessWidget {
  const _WorkspaceSection({
    required this.onOpenAuth,
    required this.dense,
    required this.cardsInline,
  });

  final ValueChanged<AuthSource> onOpenAuth;
  final bool dense;
  final bool cardsInline;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Choose your workspace',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: dense ? 20 : 24,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Each workspace is designed for your role with tools, records, billing and support in one flow.',
          maxLines: dense ? 2 : 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.textSecondary,
            fontSize: dense ? 13.5 : 15,
            height: 1.42,
          ),
        ),
        SizedBox(height: dense ? 12 : 16),
        Expanded(
          child: cardsInline
              ? Row(
                  children: <Widget>[
                    Expanded(
                      child: _WorkspaceVisualCard(
                        source: AuthSource.propertyManagement,
                        imageAsset: 'assets/landing_property_workspace.png',
                        accentColor: const Color(0xFFFF5B61),
                        description:
                            'Manage listings, tenants, rent, contracts and collections.',
                        onTap: () => onOpenAuth(AuthSource.propertyManagement),
                        dense: dense,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _WorkspaceVisualCard(
                        source: AuthSource.society,
                        imageAsset: 'assets/landing_society_workspace.png',
                        accentColor: const Color(0xFF3E6F67),
                        description:
                            'Handle residents, maintenance, visitors and society operations.',
                        onTap: () => onOpenAuth(AuthSource.society),
                        dense: dense,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: <Widget>[
                    Expanded(
                      child: _WorkspaceVisualCard(
                        source: AuthSource.propertyManagement,
                        imageAsset: 'assets/landing_property_workspace.png',
                        accentColor: const Color(0xFFFF5B61),
                        description:
                            'Manage listings, tenants, rent, contracts and collections.',
                        onTap: () => onOpenAuth(AuthSource.propertyManagement),
                        dense: dense,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _WorkspaceVisualCard(
                        source: AuthSource.society,
                        imageAsset: 'assets/landing_society_workspace.png',
                        accentColor: const Color(0xFF3E6F67),
                        description:
                            'Handle residents, maintenance, visitors and society operations.',
                        onTap: () => onOpenAuth(AuthSource.society),
                        dense: dense,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _WorkspaceVisualCard extends StatelessWidget {
  const _WorkspaceVisualCard({
    required this.source,
    required this.imageAsset,
    required this.accentColor,
    required this.description,
    required this.onTap,
    required this.dense,
  });

  final AuthSource source;
  final String imageAsset;
  final Color accentColor;
  final String description;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool tight =
            dense || constraints.maxHeight < 180 || constraints.maxWidth < 340;
        final double iconBox = tight ? 46 : 56;
        final double iconSize = tight ? 24 : 28;
        final double arrowSize = tight ? 46 : 54;
        final double sidePadding = tight ? 14 : 18;
        final double titleSize = tight ? 16.5 : 20;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(30),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x0E111A2A),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Image.asset(
                      imageAsset,
                      fit: BoxFit.cover,
                      alignment: Alignment.centerRight,
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: <Color>[
                            const Color(0xFFFEFCF9),
                            const Color(0xFFFEFCF9).withValues(alpha: 0.96),
                            const Color(0xFFFEFCF9).withValues(alpha: 0.86),
                            const Color(0xFFFEFCF9).withValues(alpha: 0.14),
                          ],
                          stops: const <double>[0, 0.36, 0.58, 1],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        sidePadding,
                        sidePadding,
                        sidePadding,
                        sidePadding,
                      ),
                      child: Stack(
                        children: <Widget>[
                          Padding(
                            padding: EdgeInsets.only(right: arrowSize + 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                  width: iconBox,
                                  height: iconBox,
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    source.icon,
                                    color: accentColor,
                                    size: iconSize,
                                  ),
                                ),
                                SizedBox(height: tight ? 10 : 14),
                                Text(
                                  source.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: titleSize,
                                    height: 1.08,
                                  ),
                                ),
                                SizedBox(height: tight ? 6 : 8),
                                Text(
                                  description,
                                  maxLines: tight ? 2 : 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textSecondary,
                                    fontSize: tight ? 12.5 : 13.5,
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      'Continue',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            color: accentColor,
                                            fontWeight: FontWeight.w800,
                                            fontSize: tight ? 13.5 : 15,
                                          ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: tight ? 16 : 18,
                                      color: accentColor,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              width: arrowSize,
                              height: arrowSize,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.96),
                                shape: BoxShape.circle,
                                boxShadow: const <BoxShadow>[
                                  BoxShadow(
                                    color: Color(0x14111A2A),
                                    blurRadius: 18,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 20,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
