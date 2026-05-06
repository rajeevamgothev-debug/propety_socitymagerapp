import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_bottom_nav_bar.dart';
import 'public_discovery_section.dart';

class PublicPropertiesPage extends StatefulWidget {
  const PublicPropertiesPage({
    super.key,
    this.openFiltersOnStart = false,
  });

  final bool openFiltersOnStart;

  @override
  State<PublicPropertiesPage> createState() => _PublicPropertiesPageState();
}

class _PublicPropertiesPageState extends State<PublicPropertiesPage> {
  final GlobalKey<PublicDiscoverySectionState> _sectionKey =
      GlobalKey<PublicDiscoverySectionState>();

  @override
  void initState() {
    super.initState();
    if (widget.openFiltersOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _sectionKey.currentState?.openFilters();
      });
    }
  }

  Future<void> _handleRefresh() async {
    await (_sectionKey.currentState?.reloadAll() ?? Future<void>.value());
  }

  void _handleNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.of(context).pop();
        return;
      case 1:
        // Already on search
        return;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to access this.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Text('Search homes'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.border),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: ListView(
          padding: AppTheme.pagePadding,
          children: <Widget>[
            PublicDiscoverySection(
              key: _sectionKey,
              showIntro: true,
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: 1,
        onSelected: _handleNavTap,
        items: const <CustomBottomNavItem>[
          CustomBottomNavItem(label: 'Home', icon: Icons.home_rounded),
          CustomBottomNavItem(label: 'Search', icon: Icons.search_rounded),
          CustomBottomNavItem(
            label: 'Saved',
            icon: Icons.favorite_border_rounded,
          ),
          CustomBottomNavItem(
            label: 'Profile',
            icon: Icons.person_outline_rounded,
          ),
        ],
      ),
    );
  }
}
