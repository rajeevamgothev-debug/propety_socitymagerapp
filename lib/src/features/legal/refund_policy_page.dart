import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class RefundPolicyPage extends StatelessWidget {
  const RefundPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text('Refund Policy'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.border),
        ),
      ),
      body: ListView(
        padding: AppTheme.pagePadding,
        children: <Widget>[
          Text(
            'Refund and Cancellation Policy',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Last updated: 16-10-2025',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          _highlightBox(
            theme,
            'At Urban Easyflats and Homes Private Limited, we are committed to providing seamless and satisfactory services to all our users. Our goal is to ensure transparency and complete customer satisfaction in every interaction.',
            const Color(0xFF059669),
            const Color(0xFFECFDF5),
          ),
          const SizedBox(height: 12),
          Text(
            'In the event that you are not satisfied with the services provided, we will carefully review your concern and may process a refund, subject to the conditions and verification mentioned below. We request all users to review the service details and terms before making any payment.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          _sectionHeader(theme, '1', 'Cancellation Policy'),
          _paragraph(
            theme,
            'If you wish to cancel your active subscription or service, you may contact us through our official support channels listed below.',
          ),
          _bulletList(theme, <String>[
            'Cancellation requests must be submitted within 7 business days from the date of payment.',
            'Any request made within this period will be treated as a cancellation for the upcoming service cycle.',
            'Once a service period has commenced, the cancellation will be effective only for the next billing cycle.',
          ]),
          _infoBox(
            theme,
            'To submit a cancellation request, please reach out to us via:\n\n'
            'Email: customersupport@urbaneasyflats.com\n'
            'Website: www.urbaneasyflats.com',
          ),
          const SizedBox(height: 20),

          _sectionHeader(theme, '2', 'Refund Policy'),
          _paragraph(
            theme,
            'At Urban Easyflats, we strive to deliver quality and reliability in every service we offer. If a client is genuinely dissatisfied with our services, they may be eligible for a refund under the following conditions:',
          ),
          _numberedList(theme, <String>[
            'The request must include a valid and verifiable reason for dissatisfaction.',
            'All refund claims are subject to internal review and approval by the Urban Easyflats management team.',
            'Refunds, once approved, will be processed to the original mode of payment used during the transaction.',
            'For payments made through payment gateways or online transfers, refunds will be credited back to the same bank account or card.',
          ]),
          const SizedBox(height: 8),
          _warningBox(
            theme,
            'Urban Easyflats reserves the right to approve, deny, or partially process refunds based on the nature of the service, duration of use, and the validity of the claim.',
          ),
          const SizedBox(height: 20),

          _sectionHeader(theme, '3', 'Contact Information'),
          _paragraph(
            theme,
            'For any queries regarding this policy, please contact:',
          ),
          _infoBox(
            theme,
            'Urban Easyflats and Homes Private Limited\n\n'
            'Registered Office:\n'
            'D.NO: 1-57/272/C, SRI RAM NAGAR COLONY,\n'
            'KONDAPUR-500084, Hyderabad, Telangana, India\n\n'
            'Email: customersupport@urbaneasyflats.com\n'
            'Website: www.urbaneasyflats.com',
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static Widget _sectionHeader(ThemeData theme, String number, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Color(0xFF059669),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _paragraph(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppTheme.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }

  static Widget _bulletList(ThemeData theme, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map(
              (String item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF059669),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  static Widget _numberedList(ThemeData theme, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List<Widget>.generate(items.length, (int index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF059669),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    items[index],
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  static Widget _infoBox(ThemeData theme, String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppTheme.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }

  static Widget _highlightBox(
    ThemeData theme,
    String text,
    Color textColor,
    Color bgColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
      ),
    );
  }

  static Widget _warningBox(ThemeData theme, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF92400E),
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
      ),
    );
  }
}
