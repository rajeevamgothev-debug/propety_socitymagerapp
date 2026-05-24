import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/public_discovery_service.dart';
import '../models/api_models.dart';

class MobileBannerCarousel extends StatefulWidget {
  const MobileBannerCarousel({
    super.key,
    required this.audience,
  });

  final String audience;

  @override
  State<MobileBannerCarousel> createState() => _MobileBannerCarouselState();
}

class _MobileBannerCarouselState extends State<MobileBannerCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.92);
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
    final Uri? uri = Uri.tryParse(rawUrl.startsWith('http') ? rawUrl : 'https://$rawUrl');
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 132);
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
            height: 142,
            child: PageView.builder(
              controller: _controller,
              itemCount: _banners.length,
              onPageChanged: (int value) => setState(() => _index = value),
              itemBuilder: (BuildContext context, int index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
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
                  color: active
                      ? const Color(0xFF8B5E34)
                      : const Color(0xFFD6D3D1),
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
    final String title = (banner.title ?? '').trim();
    final String subtitle = (banner.subtitle ?? '').trim();
    final String buttonText = (banner.buttonText ?? '').trim();
    final String link = (banner.navigationUrl ?? '').trim();
    final bool showAction = buttonText.isNotEmpty && link.isNotEmpty;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x16000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Image.network(
                  banner.imageUrl ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Color(0xFF8B5E34),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[Color(0xCC1C1917), Color(0x221C1917)],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      if (title.isNotEmpty)
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            height: 1.08,
                          ),
                        ),
                      if (subtitle.isNotEmpty) ...<Widget>[
                        if (title.isNotEmpty) const SizedBox(height: 6),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFF5F5F4),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ],
                      if (showAction) ...<Widget>[
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: onAction,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              buttonText,
                              style: const TextStyle(
                                color: Color(0xFF1C1917),
                                fontSize: 12,
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
    );
  }
}
