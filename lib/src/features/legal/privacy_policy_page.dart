import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text('Privacy Policy'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.border),
        ),
      ),
      body: ListView(
        padding: AppTheme.pagePadding,
        children: <Widget>[
          Text(
            'Privacy Policy',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Effective Date: 16-10-2025',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          _infoBox(
            theme,
            'Entity: URBAN EASYFLATS AND HOMES PRIVATE LIMITED\n'
            'Website: www.urbaneasyflats.com\n'
            'Email: customersupport@urbaneasyflats.com',
          ),
          const SizedBox(height: 20),

          _sectionHeader(theme, '1', 'Introduction'),
          _paragraph(
            theme,
            'URBAN EASYFLATS AND HOMES PRIVATE LIMITED ("Urban EasyFlats", "we", "our", or "us") respects your privacy and values your trust. This Privacy Policy explains how we collect, use, store, share, and protect your personal information when you use our website, mobile application, or any of our services (collectively, the "Platform").',
          ),
          _warningBox(
            theme,
            'By accessing or using our Platform, you agree to the terms described in this Privacy Policy. If you do not agree, please discontinue use of our services immediately.',
          ),
          const SizedBox(height: 20),

          _sectionHeader(theme, '2', 'Scope of This Policy'),
          _paragraph(theme, 'This Privacy Policy applies to:'),
          _bulletList(theme, <String>[
            'Users who access or register on our website or mobile application.',
            'Property owners, tenants, societies, and agents using Urban EasyFlats for hosting, renting, or managing properties.',
            'Visitors interacting with our services, forms, or customer support.',
          ]),
          _paragraph(
            theme,
            'It does not apply to external websites or services linked through our Platform that are not owned or controlled by us.',
          ),
          const SizedBox(height: 20),

          _sectionHeader(theme, '3', 'Information We Collect'),
          _paragraph(
            theme,
            'We collect information that helps us deliver, personalize, and improve our services. This includes:',
          ),
          _subHeader(theme, 'A. Personal Information'),
          _bulletList(theme, <String>[
            'Full name',
            'Contact number',
            'Email address',
            'Property address',
            'Identity proofs',
            'Payment details',
          ]),
          _subHeader(theme, 'B. Non-Personal Information'),
          _bulletList(theme, <String>[
            'Device information (model, operating system, and browser type)',
            'IP address and location data',
            'App usage patterns and preferences',
            'Cookies and analytics data for improving performance and experience',
          ]),
          _infoBox(
            theme,
            'You provide most of this information voluntarily during account creation, property hosting, or communication with our support team.',
          ),
          const SizedBox(height: 20),

          _sectionHeader(theme, '4', 'Purpose of Data Collection'),
          _paragraph(
            theme,
            'We collect and use your information for the following purposes:',
          ),
          _bulletList(theme, <String>[
            'To create and manage user accounts.',
            'To enable hosting, renting, and property management operations.',
            'To generate digital rental agreements and bills.',
            'To send booking confirmations, alerts, or due date reminders.',
            'To ensure property compliance and tenant verification.',
            'To improve our platform and develop new features.',
            'To communicate offers, updates, or service-related announcements (with your consent).',
          ]),
          const SizedBox(height: 20),

          _sectionHeader(theme, '5', 'Data Sharing and Disclosure'),
          _highlightBox(
            theme,
            'We do not sell or rent your personal data.',
            const Color(0xFF059669),
            const Color(0xFFECFDF5),
          ),
          const SizedBox(height: 8),
          _paragraph(
            theme,
            'However, we may share limited information in the following cases:',
          ),
          _bulletList(theme, <String>[
            'With Property Owners or Managers: When you rent or reside in a property listed on Urban EasyFlats, your details are shared with the respective property owner or manager for verification and stay management purposes.',
            'With Service Providers: We engage third-party service providers (such as payment gateways, verification partners, and analytics providers) who work under strict confidentiality agreements.',
            'Legal and Regulatory Requirements: We may disclose information when required by law, court order, or government authority to prevent fraud, cyber incidents, or other unlawful activities.',
          ]),
          const SizedBox(height: 20),

          _sectionHeader(theme, '6', 'Your Rights and Choices'),
          _paragraph(theme, 'You have the right to:'),
          _bulletList(theme, <String>[
            'Access or review your personal data stored with us.',
            'Request correction or updates to your information.',
            'Withdraw consent for promotional communications.',
            'Request deletion of your personal data.',
          ]),
          _paragraph(
            theme,
            'To exercise any of these rights, contact us at customersupport@urbaneasyflats.com',
          ),
          const SizedBox(height: 20),

          _sectionHeader(theme, '7', 'Data Retention and Deletion'),
          _paragraph(
            theme,
            'We retain your personal information only for as long as required to provide our services or comply with legal obligations.',
          ),
          _infoBox(
            theme,
            'If you wish to delete your account and associated data:\n'
            '- Go to your profile settings in the app, or\n'
            '- Send a deletion request to customersupport@urbaneasyflats.com with the subject "Data Deletion Request".',
          ),
          _paragraph(
            theme,
            'Upon verification, your data will be permanently removed within a reasonable time frame, unless retention is required by law.',
          ),
          const SizedBox(height: 20),

          _sectionHeader(theme, '8', 'Cookies and Tracking Technologies'),
          _paragraph(
            theme,
            'Our Platform uses cookies and similar tools to enhance your browsing experience. Cookies help us:',
          ),
          _bulletList(theme, <String>[
            'Recognize returning users,',
            'Analyze usage trends, and',
            'Personalize content and recommendations.',
          ]),
          _paragraph(
            theme,
            'You can modify your browser settings to disable cookies; however, certain parts of our services may not function optimally.',
          ),
          const SizedBox(height: 20),

          _sectionHeader(theme, '9', 'Data Security'),
          _paragraph(
            theme,
            'We follow strict technical and organizational measures to safeguard your data against unauthorized access, alteration, or destruction. These include:',
          ),
          _bulletList(theme, <String>[
            'Encrypted data storage',
            'Restricted access control',
            'Regular security audits',
          ]),
          _warningBox(
            theme,
            'While we strive for the highest security standards, please note that no online platform can guarantee complete protection.',
          ),
          const SizedBox(height: 20),

          _sectionHeader(theme, '10', 'Third-Party Links'),
          _paragraph(
            theme,
            'Our website or app may contain links to third-party websites or services. Urban EasyFlats is not responsible for the privacy practices or content of such external sites. We encourage users to review their respective privacy policies.',
          ),
          const SizedBox(height: 20),

          _sectionHeader(theme, '11', 'Updates to This Policy'),
          _paragraph(
            theme,
            'We may update or revise this Privacy Policy from time to time to reflect changes in our practices, technologies, or legal requirements. The latest version will always be available on our website with the effective date clearly mentioned.',
          ),
          _paragraph(
            theme,
            'Continued use of our services after changes means you accept the updated terms.',
          ),
          const SizedBox(height: 20),

          _sectionHeader(theme, '12', 'Grievance and Contact Information'),
          _paragraph(
            theme,
            'For any concerns, complaints, or requests regarding your personal information or this Privacy Policy, please reach out to our Data Protection Officer (DPO):',
          ),
          _infoBox(
            theme,
            'Grievance Officer: URBAN EASYFLATS AND HOMES PRIVATE LIMITED\n\n'
            'Registered Office Address:\n'
            'D.NO: 1-57/272/C, SRI RAM NAGAR COLONY,\n'
            'KONDAPUR-500084, Hyderabad, Telangana, India\n\n'
            'Email: customersupport@urbaneasyflats.com | info@urbaneasyflats.com | sales@urbaneasyflats.com\n\n'
            'Website: www.urbaneasyflats.com',
          ),
          const SizedBox(height: 24),

          Center(
            child: Text(
              'Urban EasyFlats – Making Real Estate Simpler, Safer, and Smarter.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
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
              color: AppTheme.primary,
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

  static Widget _subHeader(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
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
                          color: AppTheme.primary,
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

  static Widget _infoBox(ThemeData theme, String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primarySoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryTone),
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

  static Widget _warningBox(ThemeData theme, String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
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

  static Widget _highlightBox(
    ThemeData theme,
    String text,
    Color textColor,
    Color bgColor,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
