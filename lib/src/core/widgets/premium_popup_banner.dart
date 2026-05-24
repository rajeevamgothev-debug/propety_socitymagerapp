import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/api_models.dart';

enum PremiumPopupBannerVariant { property, society }

Future<void> showPremiumPopupBanner(
  BuildContext context, {
  required PremiumPopupBannerVariant variant,
  PublicBannerData? banner,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close banner',
    barrierColor: Colors.black.withOpacity(0.68),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (BuildContext context, _, __) {
      return Center(
        child: PremiumPopupBanner(variant: variant, banner: banner),
      );
    },
    transitionBuilder: (_, Animation<double> animation, __, Widget child) {
      final CurvedAnimation curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curve,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curve),
          child: child,
        ),
      );
    },
  );
}

class PremiumPopupBanner extends StatelessWidget {
  const PremiumPopupBanner({
    super.key,
    required this.variant,
    this.banner,
  });

  final PremiumPopupBannerVariant variant;
  final PublicBannerData? banner;

  @override
  Widget build(BuildContext context) {
    final _BannerCopy copy = _copyForVariant(variant, banner);
    final String? imageUrl = banner?.imageUrl?.trim();

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        minimum: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF101316),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 34,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: imageUrl == null || imageUrl.isEmpty
                        ? _PremiumGradientBackground(variant: variant)
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _PremiumGradientBackground(variant: variant),
                          ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.black.withOpacity(0.08),
                            Colors.black.withOpacity(0.72),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.18),
                              foregroundColor: Colors.white,
                            ),
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                        const SizedBox(height: 104),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.24),
                            ),
                          ),
                          child: Text(
                            copy.badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (copy.title.isNotEmpty)
                          Text(
                            copy.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              height: 1.02,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                        if (copy.subtitle.isNotEmpty) ...<Widget>[
                          if (copy.title.isNotEmpty) const SizedBox(height: 8),
                          Text(
                            copy.subtitle,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.84),
                              fontSize: 15,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (copy.showAction) ...<Widget>[
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF111418),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () => _openLink(context),
                              icon: const Icon(Icons.arrow_forward_rounded),
                              label: Text(
                                copy.action,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _BannerCopy _copyForVariant(
    PremiumPopupBannerVariant variant,
    PublicBannerData? banner,
  ) {
    final String apiTitle = banner?.title?.trim() ?? '';
    final String apiSubtitle = banner?.subtitle?.trim() ?? '';
    final String apiButtonText = banner?.buttonText?.trim() ?? '';
    final String apiUrl = banner?.navigationUrl?.trim() ?? '';
    if (variant == PremiumPopupBannerVariant.society) {
      return _BannerCopy(
        badge: 'Society Management',
        title: apiTitle,
        subtitle: apiSubtitle,
        action: apiButtonText,
        showAction: apiButtonText.isNotEmpty && apiUrl.isNotEmpty,
      );
    }
    return _BannerCopy(
      badge: 'Property Management',
      title: apiTitle,
      subtitle: apiSubtitle,
      action: apiButtonText,
      showAction: apiButtonText.isNotEmpty && apiUrl.isNotEmpty,
    );
  }

  Future<void> _openLink(BuildContext context) async {
    final String rawUrl = banner?.navigationUrl?.trim() ?? '';
    if (rawUrl.isEmpty) {
      return;
    }
    final Uri uri = Uri.parse(
      rawUrl.startsWith('http') ? rawUrl : 'https://$rawUrl',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _PremiumGradientBackground extends StatelessWidget {
  const _PremiumGradientBackground({required this.variant});

  final PremiumPopupBannerVariant variant;

  @override
  Widget build(BuildContext context) {
    final bool society = variant == PremiumPopupBannerVariant.society;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: society
              ? const <Color>[
                  Color(0xFF0F766E),
                  Color(0xFF1E293B),
                  Color(0xFF111827),
                ]
              : const <Color>[
                  Color(0xFF7C2D12),
                  Color(0xFFBE123C),
                  Color(0xFF111827),
                ],
        ),
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Icon(
            society ? Icons.apartment_rounded : Icons.home_work_rounded,
            size: 92,
            color: Colors.white.withOpacity(0.18),
          ),
        ),
      ),
    );
  }
}

class _BannerCopy {
  const _BannerCopy({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.showAction,
  });

  final String badge;
  final String title;
  final String subtitle;
  final String action;
  final bool showAction;
}
