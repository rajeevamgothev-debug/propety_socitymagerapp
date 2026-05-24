import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/auth_service.dart';
import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_button.dart';
import '../legal/legal_policy_page.dart';

typedef OtpRequestedCallback = void Function(
  String phone, {
  bool otpAlreadySent,
});

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.authSource,
    required this.onOtpRequested,
    required this.onBack,
  });

  final AuthSource authSource;
  final OtpRequestedCallback onOtpRequested;
  final VoidCallback onBack;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _otpSent = false;
  String? _errorMessage;

  static final RegExp _indianMobilePattern = RegExp(r'^[6-9]\d{9}$');

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _otpSent = false;
      _errorMessage = null;
    });

    try {
      final response = await AuthService.generateOtp(
        _phoneController.text.trim(),
        vendorType: widget.authSource.vendorType,
      );

      if (!mounted) return;

      if (response.success) {
        setState(() {
          _isLoading = false;
          _otpSent = true;
        });
        widget.onOtpRequested(_phoneController.text.trim());
      } else {
        final String message =
            response.message ??
            response.status ??
            'Unable to send OTP. Please try again.';
        if (_isOtpCooldownMessage(message)) {
          setState(() {
            _isLoading = false;
            _otpSent = true;
          });
          widget.onOtpRequested(
            _phoneController.text.trim(),
            otpAlreadySent: true,
          );
          return;
        }
        setState(() {
          _isLoading = false;
          _errorMessage = message;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Network error. Please check your connection.';
      });
    }
  }

  bool _isOtpCooldownMessage(String message) {
    final String normalized = message.toLowerCase();
    return normalized.contains('please wait') &&
        normalized.contains('request') &&
        normalized.contains('otp');
  }

  void _openPolicy(BuildContext context, LegalPolicyType type) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LegalPolicyPage(type: type)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
          children: <Widget>[
            Row(
              children: <Widget>[
                _PlainIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onPressed: widget.onBack,
                ),
                const Spacer(),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/manager_logo.jpg',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _QuietPropertyHeader(authSource: widget.authSource),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppTheme.border),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x10121A26),
                    blurRadius: 24,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Login or sign up',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Mobile number',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        hintText: 'XXXXX XXXXX',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 12, right: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                '+91',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 1,
                                height: 24,
                                color: AppTheme.border,
                              ),
                            ],
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 72,
                        ),
                        counterText: '',
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Phone number is required';
                        }
                        if (!_indianMobilePattern.hasMatch(value.trim())) {
                          return 'Enter a valid 10-digit Indian mobile number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: CustomButton(
                        label: 'Continue',
                        icon: const Icon(Icons.arrow_forward_rounded),
                        size: CustomButtonSize.lg,
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _requestOtp,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Divider(height: 1, color: AppTheme.border),
                    const SizedBox(height: 14),
                    _TermsText(
                      onTermsTap: () =>
                          _openPolicy(context, LegalPolicyType.terms),
                      onPrivacyTap: () =>
                          _openPolicy(context, LegalPolicyType.privacy),
                    ),
                    if (_otpSent) ...<Widget>[
                      const SizedBox(height: 14),
                      _InlineStatusMessage(
                        icon: Icons.check_circle_rounded,
                        color: AppTheme.toneColor(UiTone.success),
                        message: 'OTP sent successfully.',
                      ),
                    ],
                    if (_errorMessage != null) ...<Widget>[
                      const SizedBox(height: 14),
                      _InlineStatusMessage(
                        icon: Icons.error_rounded,
                        color: AppTheme.toneColor(UiTone.danger),
                        message: _errorMessage!,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermsText extends StatelessWidget {
  const _TermsText({
    required this.onTermsTap,
    required this.onPrivacyTap,
  });

  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        const Text(
          'By continuing, you agree to our ',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 12.5,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        _PolicyLink(text: 'Terms of Service', onTap: onTermsTap),
        const Text(
          ' and ',
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 12.5,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        _PolicyLink(text: 'Privacy Policy', onTap: onPrivacyTap),
        const Text(
          '.',
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 12.5,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PolicyLink extends StatelessWidget {
  const _PolicyLink({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
        child: Text(
          text,
          style: const TextStyle(
            color: AppTheme.primary,
            decoration: TextDecoration.underline,
            decorationColor: AppTheme.primary,
            fontSize: 12.5,
            height: 1.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _QuietPropertyHeader extends StatelessWidget {
  const _QuietPropertyHeader({required this.authSource});

  final AuthSource authSource;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      height: 178,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEFE8DE),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE4D9CB)),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -8,
            bottom: -18,
            child: Icon(
              Icons.apartment_rounded,
              size: 128,
              color: AppTheme.primary.withAlpha(32),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(210),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(authSource.icon, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 7),
                    Text(
                      authSource.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'UrbanEasyFlats',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Property operations, simplified.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlainIconButton extends StatelessWidget {
  const _PlainIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(icon, size: 18, color: AppTheme.textPrimary),
        ),
      ),
    );
  }
}

class _InlineStatusMessage extends StatelessWidget {
  const _InlineStatusMessage({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
