import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class ShippingPage extends StatelessWidget {
  const ShippingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text('Shipping & Delivery'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.border),
        ),
      ),
      body: ListView(
        padding: AppTheme.pagePadding,
        children: <Widget>[
          Text(
            'Shipping and Delivery Policy',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Last updated: October 15, 2025',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          _highlightBox(
            theme,
            'This Shipping and Delivery Policy outlines the terms and conditions regarding the delivery of services or products provided by URBAN EASYFLATS AND HOMES PRIVATE LIMITED.',
          ),
          const SizedBox(height: 24),

          _sectionHeader(theme, 'Service Delivery'),
          const SizedBox(height: 10),
          _card(
            theme,
            icon: Icons.computer_rounded,
            iconColor: const Color(0xFF2563EB),
            iconBgColor: const Color(0xFFEFF6FF),
            title: 'Digital Services',
            body:
                'For digital services, access will be granted immediately upon successful payment confirmation. You will receive an email with instructions on how to access your purchased services.',
          ),
          const SizedBox(height: 10),
          _card(
            theme,
            icon: Icons.inventory_2_rounded,
            iconColor: const Color(0xFF059669),
            iconBgColor: const Color(0xFFECFDF5),
            title: 'Physical Products',
            body:
                'For physical products, delivery times may vary based on your location and the shipping method selected during checkout. Estimated delivery times will be provided at the time of purchase.',
          ),
          const SizedBox(height: 24),

          _sectionHeader(theme, 'Shipping Costs'),
          const SizedBox(height: 10),
          _paragraph(
            theme,
            'Shipping costs for physical products will be calculated and displayed at checkout. These costs may vary based on the size, weight, and destination of your order.',
          ),
          const SizedBox(height: 20),

          _sectionHeader(theme, 'Delivery Timeframes'),
          const SizedBox(height: 10),
          _paragraph(
            theme,
            'While we strive to deliver all products and services within the estimated timeframes, delays may occur due to unforeseen circumstances such as:',
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              _delayChip(theme, Icons.cloud_rounded, 'Weather'),
              const SizedBox(width: 8),
              _delayChip(theme, Icons.description_rounded, 'Customs'),
              const SizedBox(width: 8),
              _delayChip(theme, Icons.local_shipping_rounded, 'Logistics'),
            ],
          ),
          const SizedBox(height: 12),
          _infoBox(
            theme,
            'We will keep you informed of any significant delays.',
          ),
          const SizedBox(height: 20),

          _sectionHeader(theme, 'Tracking Your Order'),
          const SizedBox(height: 10),
          _paragraph(
            theme,
            'For physical products, a tracking number will be provided once your order has been shipped. You can use this tracking number to monitor the status of your delivery in real-time.',
          ),
          const SizedBox(height: 20),

          _sectionHeader(theme, 'Contact Us'),
          const SizedBox(height: 10),
          _paragraph(
            theme,
            'If you have any questions about your shipping or delivery, please contact us:',
          ),
          _contactBox(theme),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static Widget _sectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }

  static Widget _paragraph(ThemeData theme, String text) {
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: AppTheme.textSecondary,
        height: 1.5,
      ),
    );
  }

  static Widget _highlightBox(ThemeData theme, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF9A3412),
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
      ),
    );
  }

  static Widget _card(
    ThemeData theme, {
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String body,
  }) {
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
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
                const SizedBox(height: 4),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _delayChip(ThemeData theme, IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, color: const Color(0xFFEA580C), size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _infoBox(ThemeData theme, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primarySoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryTone),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppTheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static Widget _contactBox(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Urban Easyflats and Homes Private Limited',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Email: support@urbaneasyflats.com\n'
            'Website: www.urbaneasyflats.com\n\n'
            'Address:\n'
            'H.NO 1-57/272/C, SRI RAM NAGAR COLONY\n'
            'KONDAPUR SERILINGAMPALLY, Kondapur\n'
            'Hyderabad, Rangareddy, Telangana\n'
            'PIN Code: 500084',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
