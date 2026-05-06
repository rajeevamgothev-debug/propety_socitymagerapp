import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text('Terms & Conditions'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.border),
        ),
      ),
      body: ListView(
        padding: AppTheme.pagePadding,
        children: <Widget>[
          Text(
            'Terms and Conditions',
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
          _infoBox(
            theme,
            'Urban Easyflats and Homes Private Limited (hereinafter referred to as "Urban Easyflats," "Company," "We," "Us," or "Our").\n\n'
            'The following Terms and Conditions ("Terms") govern your access to and use of the website www.urbaneasyflats.com, our mobile application, and all related services (collectively referred to as the "Platform").\n\n'
            'By accessing, browsing, or registering on our Platform, you ("User," "Visitor," "Resident," "Tenant", "Owner," or "Society Member") acknowledge that you have read, understood, and agreed to be bound by these Terms. If you do not agree, please discontinue using the Platform immediately.',
          ),
          const SizedBox(height: 20),

          _section(theme, '1', 'INTRODUCTION',
              'Urban Easyflats and Homes Private Limited is a technology-driven platform that provides property listing, rental management, digital tenancy agreements, society maintenance management, and payment processing services for property owners, tenants, and societies.\n\nThese Terms are subject to change or update at any time, without prior notice. You are advised to revisit this page periodically to stay informed of any modifications, as continued use of our Platform implies your acceptance of the updated Terms.'),
          _section(theme, '2', 'OWNERSHIP AND USE OF CONTENT',
              'All logos, marks, designs, graphics, names, software, and other intellectual property visible on this Platform are the property of Urban Easyflats and Homes Pvt. Ltd. or its licensed partners.\n\nNo part of the Platform or its content may be copied, modified, republished, uploaded, posted, transmitted, or distributed in any way, without prior written consent from the Company. Unauthorized use may result in civil or criminal liability.\n\nUsers may download or print information from the Platform solely for personal and non-commercial purposes.'),
          _section(theme, '3', 'ACCEPTABLE USE POLICY',
              'Security Obligations — Users are strictly prohibited from:\n• Accessing data or servers without authorization.\n• Attempting to probe or test the vulnerability of any system or network connected to the Platform.\n• Introducing viruses, worms, or malicious code that could disrupt our services.\n• Using any device, software, or routine to interfere with the proper functioning of the Platform.\n• Sending spam, junk mail, or unsolicited advertising messages through the Platform.\n\nViolation of these rules may lead to suspension of access, legal prosecution, or both.\n\nResponsible Use — Users shall not use the Platform to:\n• Upload or share defamatory, obscene, abusive, or unlawful content.\n• Violate intellectual property rights of others.\n• Engage in activities that could harm, disrupt, or compromise the integrity of the Platform.\n• Impersonate another person or misrepresent their affiliation with any entity.'),
          _section(theme, '4', 'PROPERTY & SOCIETY MANAGEMENT SERVICES',
              'Urban Easyflats provides digital solutions for property owners, tenants, and societies to manage:\n• Property listings and hosting\n• Digital rent agreements\n• Automated bill generation\n• Payment processing\n• Society communication and management tools\n\nThe Company acts only as a technology intermediary. We do not participate in rent negotiations, disputes, or personal transactions between the user and third parties.'),
          _section(theme, '5', 'RENT AND MAINTENANCE PAYMENT TERMS',
              'Urban Easyflats offers users a secure platform to make rental and society maintenance payments via integrated third-party payment gateways.\n\nWe are not a financial institution and do not provide banking or escrow services. Our role is limited to facilitating payments between users (payers) and beneficiaries (payees), such as landlords or society associations.\n\nThe user acknowledges that the transaction represents a valid payment based on an actual rent or maintenance agreement between the parties involved. The Company bears no responsibility for the underlying contractual relationship.'),
          _section(theme, '6', 'KYC AND VERIFICATION',
              'To comply with legal and regulatory requirements, Urban Easyflats may request user verification documents including:\n• Upload document of Government-issued ID (Aadhaar, PAN, Passport, etc.)\n• Rent or maintenance agreements\n• Proof of property ownership or tenancy\n\nFor transactions above Rs 50,000 or as required by law, PAN and other supporting documents may be mandatory.\n\nUsers consent to Urban Easyflats verifying submitted details through authorized sources or third-party APIs.'),
          _section(theme, '7', 'PAYMENT AUTHORIZATION',
              'By initiating a payment on our Platform, you authorize Urban Easyflats to:\n• Process your payment through authorized gateways.\n• Transfer funds to the designated beneficiary\'s account as per your instructions.\n• Deduct applicable convenience fees, service charges, or taxes, if any.\n\nIf the payment fails or details provided are incomplete or incorrect, the Company may refund the amount to the original source account after deducting applicable charges.'),
          _section(theme, '8', 'TRANSACTION TERMS AND RESPONSIBILITY',
              'Users must ensure accuracy in entering beneficiary bank details. Urban Easyflats will not be liable for payments credited to an incorrect account due to user error.\n\nYou are responsible for safeguarding your login credentials and payment details. The Company will not be liable for unauthorized transactions resulting from your negligence, password sharing, or device compromise.\n\nWe reserve the right to delay, hold, or reject a payment if it appears suspicious, fraudulent, or in violation of these Terms.'),
          _section(theme, '9', 'REFUNDS, REVERSALS, AND CHARGEBACKS',
              '1. If a transaction fails due to technical issues on our side, the amount will be automatically refunded to the payer\'s original payment source within the standard processing period.\n2. Once funds are successfully credited to the beneficiary\'s account, no refund or reversal will be initiated by Urban Easyflats.\n3. Chargebacks or disputes raised with payment providers will be handled in accordance with their respective policies.\n4. Users and beneficiaries must cooperate and provide all necessary documents for dispute resolution.'),
          _section(theme, '10', 'FRAUD AND UNAUTHORIZED ACTIVITY',
              'If you notice suspicious or unauthorized transactions, immediately notify Urban Easyflats at customersupport@urbaneasyflats.com.\n\nWe will take reasonable steps to prevent further unauthorized use but will not be liable for losses if payments have already been transferred as per the details provided by the user.\n\nUsers are solely responsible for maintaining confidentiality of their login credentials and personal information.'),
          _section(theme, '11', 'INDEMNITY',
              'You agree to indemnify, defend, and hold harmless Urban Easyflats, its directors, officers, employees, and partners from any claim, damage, liability, or expense arising from:\n• Your misuse of the Platform;\n• Your breach of these Terms;\n• Any dispute between you and another user, property owner, tenant, or society; or\n• Any legal or regulatory action related to your transactions.'),
          _section(theme, '12', 'LIMITATION OF LIABILITY',
              'Urban Easyflats shall not be liable for any direct, indirect, incidental, or consequential damages arising out of:\n• Use or inability to use the Platform;\n• Delays or errors in processing payments;\n• Unauthorized access to your data;\n• Interruption, suspension, or termination of services.\n\nOur total liability in any circumstance shall not exceed the total service fee paid by the user, if any, related to the disputed transaction.'),
          _section(theme, '13', 'TERMINATION OR SUSPENSION',
              'The Company reserves the right to suspend or terminate user access at any time if it suspects misuse, fraud, or violation of these Terms. Upon termination, all rights granted to you will immediately cease.'),
          _section(theme, '14', 'GOVERNING LAW AND JURISDICTION',
              'These Terms shall be governed and construed in accordance with the laws of India.\n\nAny disputes shall be subject exclusively to the jurisdiction of the courts of Hyderabad, Telangana.'),
          _section(theme, '15', 'CONTACT INFORMATION',
              'For any concerns, disputes, or clarifications regarding these Terms, please contact:\n\nUrban Easyflats and Homes Private Limited\nEmail: customersupport@urbaneasyflats.com | info@urbaneasyflats.com\nWebsite: www.urbaneasyflats.com\nAddress: D.NO: 1-57/272/C, SRI RAM NAGAR COLONY, KONDAPUR-500084, Hyderabad, Telangana, India'),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static Widget _section(
    ThemeData theme,
    String number,
    String title,
    String body,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
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
          const SizedBox(height: 10),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
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
          color: AppTheme.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }
}
