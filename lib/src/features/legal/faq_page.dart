import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

const List<({String q, String a})> _faqData = <({String q, String a})>[
  (
    q: 'What is UrbanEasyFlats?',
    a:
        'UrbanEasyFlats is a complete property and society management platform that helps property owners, tenants, and society administrators manage apartments digitally in one place.',
  ),
  (
    q: 'Who can use UrbanEasyFlats?',
    a:
        'Property Owners, Apartment Owners, Tenants, Property Managers, Society Presidents, PG Owners and Real Estate Managers can use UrbanEasyFlats.',
  ),
  (
    q: 'What features does UrbanEasyFlats provide?',
    a:
        'Property Listings, Tenant Management, Digital Agreements, Automated Rent Bills, Maintenance Bills, Due Date Reminders, Society Management and Payment Tracking.',
  ),
  (
    q: 'How does UrbanEasyFlats work?',
    a:
        'Add your property, add tenants, create agreements, generate bills and track payments digitally.',
  ),
  (
    q: 'Can I list my property on UrbanEasyFlats?',
    a:
        'Yes. You can list apartments, flats, PG rooms, rental properties and commercial spaces.',
  ),
  (
    q: 'Can UrbanEasyFlats generate rent bills automatically?',
    a:
        'Yes. Monthly rent and maintenance bills can be generated automatically.',
  ),
  (
    q: 'Can I create rental agreements?',
    a: 'Yes. Rental agreements can be created and stored digitally.',
  ),
  (
    q: 'Can societies use UrbanEasyFlats?',
    a:
        'Yes. UrbanEasyFlats supports apartment and society management including resident and maintenance management.',
  ),
  (
    q: 'Can I manage multiple properties?',
    a: 'Yes. Multiple properties can be managed in one account.',
  ),
  (
    q: 'Is UrbanEasyFlats suitable for PG owners?',
    a: 'Yes. PG owners can manage rooms, tenants and rent easily.',
  ),
  (
    q: 'Can tenants use UrbanEasyFlats?',
    a: 'Yes. Tenants can view bills, agreements and payment history.',
  ),
  (
    q: 'Is UrbanEasyFlats easy to use?',
    a: 'Yes. It is simple and user friendly.',
  ),
  (q: 'Is my data safe?', a: 'Yes. Data is stored securely.'),
  (
    q: 'Can I access UrbanEasyFlats from mobile?',
    a: 'Yes. It works on mobile, tablet and desktop.',
  ),
  (
    q: 'Why should I use UrbanEasyFlats?',
    a:
        'It saves time and helps manage properties and payments easily.',
  ),
  (
    q: 'How is UrbanEasyFlats different from others?',
    a:
        'It provides property management, tenant management, society management and billing in one platform.',
  ),
  (
    q: 'How can I get started?',
    a: 'Register an account, add property and start managing.',
  ),
  (
    q: 'Is UrbanEasyFlats suitable for small property owners?',
    a: 'Yes. Even single property owners can use it.',
  ),
  (
    q: 'Can I track rent payments?',
    a: 'Yes. Payment history and dues can be tracked.',
  ),
  (
    q: 'Does UrbanEasyFlats send reminders?',
    a: 'Yes. Rent and maintenance reminders are supported.',
  ),
  (
    q: 'Can UrbanEasyFlats help in finding flats?',
    a: 'Yes. Users can find apartments and rental properties.',
  ),
  (
    q: 'Is UrbanEasyFlats a property management platform?',
    a:
        'Yes. It is a complete digital property and society management platform.',
  ),
];

class FaqPage extends StatefulWidget {
  const FaqPage({super.key});

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  int? _openIndex;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text('FAQ'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.border),
        ),
      ),
      body: ListView(
        padding: AppTheme.pagePadding,
        children: <Widget>[
          Text(
            'Frequently Asked Questions',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Find answers to common questions about UrbanEasyFlats.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          ...List<Widget>.generate(_faqData.length, (int index) {
            final ({String q, String a}) item = _faqData[index];
            final bool isOpen = _openIndex == index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isOpen ? AppTheme.primary : AppTheme.border,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: <Widget>[
                    InkWell(
                      onTap: () {
                        setState(() {
                          _openIndex = isOpen ? null : index;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: <Widget>[
                            Text(
                              '${index + 1}.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.q,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedRotation(
                              turns: isOpen ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppTheme.primary,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isOpen)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Text(
                          item.a,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
