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
      if (_resendCountdown <= 0) {
        timer.cancel();
      }
    });
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

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

      if (!mounted) {
        return;
      }

      if (response.success) {
        final Map<String, dynamic>? data =
            response.data as Map<String, dynamic>?;
        final bool hasBasicInformation =
            data?['Whether_Basic_Information_Available'] as bool? ?? true;

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
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Network error. Please check your connection.';
      });
    }
  }

  Future<void> _resendOtp() async {
    _startResendTimer();
    try {
      await AuthService.generateOtp(
        widget.phoneNumber,
        vendorType: widget.authSource.vendorType,
      );
    } catch (_) {
      // Silently fail; user can retry again.
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
              child: _OtpBackPill(onPressed: widget.onBack),
            ),
            const SizedBox(height: 26),
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
                child: Image.asset(
                  'assets/manager_logo.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Enter the code',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                height: 1.08,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'We sent it to +91 ${widget.phoneNumber}. This keeps your ${widget.authSource.label.toLowerCase()} workspace protected.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
            ),
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
                    Text(
                      'Verification',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '+91 ${widget.phoneNumber}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      autofocus: true,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                      ),
                      decoration: const InputDecoration(
                        hintText: '0000',
                        counterText: '',
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
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: CustomButton(
                        label: 'Verify and continue',
                        icon: const Icon(Icons.arrow_forward_rounded),
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
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: _resendCountdown > 0
                  ? Text(
                      'Request a new code in ${_resendCountdown}s',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : TextButton(
                      onPressed: _resendOtp,
                      child: const Text('Send a new code'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpBackPill extends StatelessWidget {
  const _OtpBackPill({required this.onPressed});

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
