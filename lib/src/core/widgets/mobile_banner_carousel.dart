import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/public_discovery_service.dart';
import '../models/api_models.dart';
import '../theme/app_theme.dart';

class MobileBannerCarousel extends StatefulWidget {
  const MobileBannerCarousel({super.key, required this.audience});

  final String audience;

  @override
  State<MobileBannerCarousel> createState() => _MobileBannerCarouselState();
}

class _MobileBannerCarouselState extends State<MobileBannerCarousel> {
  final PageController _controller = PageController(viewportFraction: 1);
  List<PublicBannerData> _banners = <PublicBannerData>[];
  Timer? _timer;
  int _index = 0;
  bool _loading = true;
  bool _touching = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MobileBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audience != widget.audience) {
      _load();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _timer?.cancel();
    setState(() {
      _loading = true;
      _banners = <PublicBannerData>[];
      _index = 0;
    });
    try {
      final result = await PublicDiscoveryService.filterMobileBanners(
        audience: widget.audience,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _banners = result.banners;
        _loading = false;
      });
      _startTimer();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_banners.length < 2) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _touching || !_controller.hasClients) {
        return;
      }
      final int next = (_index + 1) % _banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _open(PublicBannerData banner) async {
    final String rawUrl = (banner.navigationUrl ?? '').trim();
    if (rawUrl.isEmpty || rawUrl.startsWith('app://')) {
      return;
    }
    final Uri? uri = Uri.tryParse(
      rawUrl.startsWith('http') ? rawUrl : 'https://$rawUrl',
    );
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 176);
    }
    if (_banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: <Widget>[
        Listener(
          onPointerDown: (_) => _touching = true,
          onPointerUp: (_) => _touching = false,
          onPointerCancel: (_) => _touching = false,
          child: SizedBox(
            height: 176,
            child: PageView.builder(
              controller: _controller,
              itemCount: _banners.length,
              onPageChanged: (int value) => setState(() => _index = value),
              itemBuilder: (BuildContext context, int index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _MobileBannerCard(
                    banner: _banners[index],
                    onAction: () => _open(_banners[index]),
                  ),
                );
              },
            ),
          ),
        ),
        if (_banners.length > 1) ...<Widget>[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(_banners.length, (int itemIndex) {
              final bool active = itemIndex == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 6,
                width: active ? 18 : 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: active ? AppTheme.primary : AppTheme.primaryTone,
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _MobileBannerCard extends StatelessWidget {
  const _MobileBannerCard({required this.banner, required this.onAction});

  final PublicBannerData banner;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String title = (banner.title ?? '').trim();
    final String subtitle = (banner.subtitle ?? '').trim();
    final String buttonText = (banner.buttonText ?? '').trim();
    final String link = (banner.navigationUrl ?? '').trim();
    final bool hasActionLink = link.isNotEmpty && !link.startsWith('app://');
    final bool showAction = hasActionLink;
    final bool isYoutubeBanner =
        title.toLowerCase().contains('youtube') ||
        subtitle.toLowerCase().contains('youtube');
    final String ctaText = buttonText.isNotEmpty
        ? buttonText
        : (isYoutubeBanner ? 'Watch now' : 'Open');

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x140F172A),
              blurRadius: 24,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFF0F172A), Color(0xFF1E3A8A)],
              ),
            ),
            child: Stack(
              children: <Widget>[
                Positioned(
                  top: -36,
                  right: -24,
                  child: Container(
                    width: 144,
                    height: 144,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x14FFFFFF),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -28,
                  left: 160,
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x124F46E5),
                    ),
                  ),
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      flex: 6,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (isYoutubeBanner) ...<Widget>[
                              Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.red,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            if (title.isNotEmpty)
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  height: 1.12,
                                ),
                              ),
                            if (subtitle.isNotEmpty) ...<Widget>[
                              if (title.isNotEmpty) const SizedBox(height: 6),
                              Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFFE2E8F0),
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            if (showAction) const Spacer(),
                            if (showAction) ...<Widget>[
                              FilledButton.tonalIcon(
                                onPressed: onAction,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 40),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppTheme.textPrimary,
                                  elevation: 0,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                icon: Icon(
                                  isYoutubeBanner
                                      ? Icons.play_circle_fill_rounded
                                      : Icons.arrow_forward_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  ctaText,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            fit: StackFit.expand,
                            children: <Widget>[
                              Image.network(
                                banner.imageUrl ?? '',
                                fit: BoxFit.cover,
                                alignment: Alignment.centerRight,
                                errorBuilder: (_, _, _) =>
                                    const ColoredBox(color: Color(0xFF1E40AF)),
                              ),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: <Color>[
                                      Color(0x080F172A),
                                      Color(0x420F172A),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
