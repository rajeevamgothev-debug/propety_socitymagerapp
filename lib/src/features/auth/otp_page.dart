import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/auth_service.dart';
import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_button.dart';

class OtpPage extends StatefulWidget {
  const OtpPage({
    super.key,
    required this.phoneNumber,
    required this.authSource,
    required this.onBack,
    required this.onVerified,
  });

  final String phoneNumber;
  final AuthSource authSource;
  final VoidCallback onBack;
  final ValueChanged<bool> onVerified;

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final TextEditingController _otpController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  int _resendCountdown = 30;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendCountdown = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCountdown--;
      });
      if (_resendCountdown <= 0) timer.cancel();
    });
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await AuthService.validateOtp(
        widget.phoneNumber,
        _otpController.text.trim(),
        vendorType: widget.authSource.vendorType,
      );

      if (!mounted) return;

      if (response.success) {
        final Map<String, dynamic>? data =
            response.data as Map<String, dynamic>?;
        final bool hasBasicInformation = _readBackendBool(
          data?['Whether_Basic_Information_Available'] ??
              data?['whether_basic_information_available'] ??
              data?['WhetherBasicInformationAvailable'],
          fallback: false,
        );

        setState(() {
          _isLoading = false;
        });
        widget.onVerified(!hasBasicInformation);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = response.message ?? response.status ?? 'Invalid OTP';
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

  bool _readBackendBool(dynamic value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return fallback;
  }

  Future<void> _resendOtp() async {
    _startResendTimer();
    try {
      await AuthService.generateOtp(
        widget.phoneNumber,
        vendorType: widget.authSource.vendorType,
      );
    } catch (_) {}
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
                _OtpBackButton(onPressed: widget.onBack),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    widget.authSource.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 44),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
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
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primarySoft,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Enter verification code',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '+91 ${widget.phoneNumber}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      autofocus: true,
                      enabled: !_isLoading,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 12,
                        color: AppTheme.primary,
                      ),
                      decoration: InputDecoration(
                        hintText: '0000',
                        counterText: '',
                        fillColor: const Color(0xFFFFFCF8),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(
                            color: AppTheme.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'OTP is required';
                        }
                        if (value.trim().length != 4) {
                          return 'Enter a valid 4-digit OTP';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _ResendRow(
                      seconds: _resendCountdown,
                      onResend: _resendOtp,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: CustomButton(
                        label: 'Verify',
                        icon: const Icon(Icons.arrow_forward_rounded),
                        size: CustomButtonSize.lg,
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _verifyOtp,
                      ),
                    ),
                    if (_errorMessage != null) ...<Widget>[
                      const SizedBox(height: 14),
                      Text(
                        _errorMessage!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.toneColor(UiTone.danger),
                          fontWeight: FontWeight.w800,
                        ),
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

class _ResendRow extends StatelessWidget {
  const _ResendRow({required this.seconds, required this.onResend});

  final int seconds;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            seconds > 0
                ? 'Resend code in ${seconds}s'
                : 'Didn\'t receive the code?',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(
          onPressed: seconds > 0 ? null : onResend,
          child: const Text('Resend'),
        ),
      ],
    );
  }
}

class _OtpBackButton extends StatelessWidget {
  const _OtpBackButton({required this.onPressed});

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
        child: const Padding(
          padding: EdgeInsets.all(11),
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
