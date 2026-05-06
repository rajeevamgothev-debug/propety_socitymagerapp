import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';

class ContactUsPage extends StatelessWidget {
  const ContactUsPage({super.key});

  Future<void> _launch(String url, BuildContext context) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text('Contact Us'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.border),
        ),
      ),
      body: ListView(
        padding: AppTheme.pagePadding,
        children: <Widget>[
          Text(
            'Contact Us',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "We'd love to hear from you! Please reach out to us using the details below.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Address
          _ContactCard(
            icon: Icons.location_on_rounded,
            iconColor: const Color(0xFF4F46E5),
            iconBgColor: const Color(0xFFEEF2FF),
            title: 'Registered Office',
            child: Text(
              'URBAN EASYFLATS AND HOMES PRIVATE LIMITED\n'
              'H.NO 1-57/272/C, SRI RAM NAGAR COLONY\n'
              'KONDAPUR SERILINGAMPALLY\n'
              'Hyderabad, Rangareddy, Telangana\n'
              'PIN Code: 500084',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Phone
          _ContactCard(
            icon: Icons.phone_rounded,
            iconColor: const Color(0xFF059669),
            iconBgColor: const Color(0xFFECFDF5),
            title: 'Phone',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _PhoneLink(
                  label: '+91 79953 28833',
                  onTap: () => _launch('tel:+917995328833', context),
                ),
                const SizedBox(height: 6),
                _PhoneLink(
                  label: '+91 79953 28822',
                  onTap: () => _launch('tel:+917995328822', context),
                ),
                const SizedBox(height: 6),
                _PhoneLink(
                  label: '+91 79953 28811',
                  onTap: () => _launch('tel:+917995328811', context),
                ),
                const SizedBox(height: 6),
                _PhoneLink(
                  label: '+91 77021 76856',
                  onTap: () => _launch('tel:+917702176856', context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Email
          _ContactCard(
            icon: Icons.email_rounded,
            iconColor: const Color(0xFF2563EB),
            iconBgColor: const Color(0xFFEFF6FF),
            title: 'Email',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _PhoneLink(
                  label: 'info@urbaneasyflats.com',
                  onTap: () =>
                      _launch('mailto:info@urbaneasyflats.com', context),
                ),
                const SizedBox(height: 6),
                _PhoneLink(
                  label: 'customersupport@urbaneasyflats.com',
                  onTap: () => _launch(
                    'mailto:customersupport@urbaneasyflats.com',
                    context,
                  ),
                ),
                const SizedBox(height: 6),
                _PhoneLink(
                  label: 'sales@urbaneasyflats.com',
                  onTap: () =>
                      _launch('mailto:sales@urbaneasyflats.com', context),
                ),
                const SizedBox(height: 6),
                _PhoneLink(
                  label: 'support@urbaneasyflats.com',
                  onTap: () =>
                      _launch('mailto:support@urbaneasyflats.com', context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Message section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primaryTone),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Send us a message',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'For any inquiries, feedback, or support, please email us directly or call us during business hours.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneLink extends StatelessWidget {
  const _PhoneLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppTheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
