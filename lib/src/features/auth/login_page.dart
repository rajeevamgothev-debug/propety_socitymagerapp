import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/auth_service.dart';
import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.authSource,
    required this.onOtpRequested,
    required this.onBack,
  });

  final AuthSource authSource;
  final ValueChanged<String> onOtpRequested;
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
        setState(() {
          _isLoading = false;
          _errorMessage =
              response.message ?? response.status ?? 'Failed to send OTP';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Network error. Please check your connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFBFAF7),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: _BackPill(onPressed: widget.onBack),
            ),
            const SizedBox(height: 26),
            _LoginBrandHeader(authSource: widget.authSource),
            const SizedBox(height: 30),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.border),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x0D17202A),
                    blurRadius: 22,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Continue with mobile',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Enter the number linked to your management account.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceMuted,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Icon(
                            widget.authSource.icon,
                            color: AppTheme.primary,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Mobile number',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
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
                        hintText: '10-digit mobile number',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 14, right: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                '+91',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 1,
                                height: 24,
                                color: AppTheme.border,
                              ),
                            ],
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 70,
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
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _requestOtp,
                      ),
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

class _BackPill extends StatelessWidget {
  const _BackPill({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _LoginBrandHeader extends StatelessWidget {
  const _LoginBrandHeader({required this.authSource});

  final AuthSource authSource;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 78,
          height: 78,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.border),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x0D17202A),
                blurRadius: 22,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Image.asset('assets/manager_logo.jpg', fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Welcome back',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            height: 1.08,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          authSource.description,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(authSource.icon, size: 17, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                authSource.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
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
    final ThemeData theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
