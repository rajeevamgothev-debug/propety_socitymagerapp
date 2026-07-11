import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/auth_service.dart';
import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_button.dart';
import '../legal/legal_policy_page.dart';

typedef OtpRequestedCallback =
    void Function(String phone, {bool otpAlreadySent});

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

  bool get _usePropertyManagementLayout =>
      widget.authSource == AuthSource.propertyManagement;

  @override
  Widget build(BuildContext context) {
    if (_usePropertyManagementLayout) {
      return _buildPropertyManagementLogin(context);
    }

    return _buildDefaultLogin(context);
  }

  Widget _buildDefaultLogin(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double keyboardBottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppTheme.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(22, 18, 22, keyboardBottom + 30),
          child: Column(
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
      ),
    );
  }

  Widget _buildPropertyManagementLogin(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double width = mediaQuery.size.width;
    final double keyboardInset = mediaQuery.viewInsets.bottom;
    final bool compact = width < 390;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FD),
      resizeToAvoidBottomInset: false,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFF4F6FF), Color(0xFFF8F9FF), Colors.white],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double sheetHeight = compact ? 338 : 356;
              final double horizontalInset = compact ? 14 : 18;
              final double maxSheetTop = math.max(
                118,
                constraints.maxHeight - sheetHeight - 14,
              );
              final double desiredSheetTop =
                  constraints.maxHeight * (compact ? 0.49 : 0.5);
              final double keyboardLift = keyboardInset > 0
                  ? math.min(keyboardInset * 0.42, compact ? 144.0 : 156.0)
                  : 0;
              final double minSheetTop = compact ? 214 : 228;
              final double sheetTop = math.max(
                minSheetTop,
                math.min(maxSheetTop, desiredSheetTop - keyboardLift),
              );

              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _PropertyLoginHero(compact: compact, onBack: widget.onBack),
                  Positioned(
                    left: horizontalInset,
                    right: horizontalInset,
                    top: sheetTop,
                    height: sheetHeight,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(40),
                          bottom: Radius.circular(36),
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Color(0x120F172A),
                            blurRadius: 28,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                "Let's get you signed in",
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  height: 1.05,
                                ),
                              ),
                              const SizedBox(height: 26),
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.done,
                                maxLength: 10,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                                inputFormatters: <TextInputFormatter>[
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  hintText: 'Enter mobile number',
                                  hintStyle: theme.textTheme.titleMedium
                                      ?.copyWith(
                                        color: AppTheme.textMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                  counterText: '',
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 21,
                                  ),
                                  prefixIcon: const _PropertyPhonePrefix(),
                                  prefixIconConstraints: const BoxConstraints(
                                    minWidth: 118,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE4E0FD),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE4E0FD),
                                      width: 1.2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: const BorderSide(
                                      color: AppTheme.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                validator: (String? value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Phone number is required';
                                  }
                                  if (!_indianMobilePattern.hasMatch(
                                    value.trim(),
                                  )) {
                                    return 'Enter a valid 10-digit Indian mobile number';
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (_) =>
                                    _isLoading ? null : _requestOtp(),
                              ),
                              const SizedBox(height: 22),
                              _GradientContinueButton(
                                label: 'Next',
                                isLoading: _isLoading,
                                onPressed: _isLoading ? null : _requestOtp,
                              ),
                              const SizedBox(height: 18),
                              Center(
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: <Widget>[
                                    Text(
                                      'By signing in, you agree to our ',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: AppTheme.textSecondary,
                                            height: 1.45,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    _PolicyLink(
                                      text: 'Terms of Service',
                                      onTap: () => _openPolicy(
                                        context,
                                        LegalPolicyType.terms,
                                      ),
                                    ),
                                    Text(
                                      ' and ',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: AppTheme.textSecondary,
                                            height: 1.45,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    _PolicyLink(
                                      text: 'Privacy Policy',
                                      onTap: () => _openPolicy(
                                        context,
                                        LegalPolicyType.privacy,
                                      ),
                                    ),
                                    Text(
                                      '.',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: AppTheme.textSecondary,
                                            height: 1.45,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_otpSent) ...<Widget>[
                                const SizedBox(height: 16),
                                _InlineStatusMessage(
                                  icon: Icons.check_circle_rounded,
                                  color: AppTheme.toneColor(UiTone.success),
                                  message: 'OTP sent successfully.',
                                ),
                              ],
                              if (_errorMessage != null) ...<Widget>[
                                const SizedBox(height: 16),
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
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TermsText extends StatelessWidget {
  const _TermsText({required this.onTermsTap, required this.onPrivacyTap});

  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 2,
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

class _PropertyLoginHero extends StatelessWidget {
  const _PropertyLoginHero({required this.compact, required this.onBack});

  final bool compact;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double textWidth = constraints.maxWidth * (compact ? 0.56 : 0.54);

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0xFFF4F6FF), Color(0xFFF8FAFF)],
                ),
              ),
            ),
            Positioned(
              left: constraints.maxWidth * (compact ? 0.18 : 0.22),
              right: compact ? -34 : -26,
              top: compact ? 42 : 48,
              bottom: compact ? 40 : 50,
              child: IgnorePointer(
                child: Image.asset(
                  'assets/hero_property_manager.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _PlainIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: onBack,
                  ),
                  const Spacer(),
                  Container(
                    width: 62,
                    height: 62,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x10111A2A),
                          blurRadius: 22,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/manager_logo.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 22,
              top: compact ? 126 : 138,
              width: textWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Welcome to',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: compact ? 58 : 62,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'UrbanEasyFlats',
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: compact ? 33 : 36,
                            height: 1.02,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Property operations, simplified.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: compact ? 16 : 17,
                      height: 1.32,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PropertyPhonePrefix extends StatelessWidget {
  const _PropertyPhonePrefix();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              width: 20,
              height: 14,
              child: Column(
                children: const <Widget>[
                  Expanded(child: ColoredBox(color: Color(0xFFFF9933))),
                  Expanded(child: ColoredBox(color: Colors.white)),
                  Expanded(child: ColoredBox(color: Color(0xFF138808))),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '+91',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: AppTheme.primary,
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 28, color: const Color(0xFFE3E6F6)),
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
      shape: const CircleBorder(side: BorderSide(color: Color(0xFFE8E7EE))),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Icon(icon, size: 20, color: AppTheme.textPrimary),
        ),
      ),
    );
  }
}

class _GradientContinueButton extends StatelessWidget {
  const _GradientContinueButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null || isLoading;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: disabled ? 0.55 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF6F63FF), Color(0xFF4F46E5)],
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x2B4F46E5),
              blurRadius: 20,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: disabled ? null : onPressed,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (isLoading) ...<Widget>[
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (!isLoading) ...<Widget>[
                    const SizedBox(width: 14),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ],
                ],
              ),
            ),
          ),
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
