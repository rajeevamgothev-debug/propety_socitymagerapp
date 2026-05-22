import 'package:flutter/material.dart';

import '../../core/models/app_models.dart';
import '../../core/services/version_update_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_button.dart';

class AppUpdateGatePage extends StatefulWidget {
  const AppUpdateGatePage({
    super.key,
    required this.decision,
    required this.appName,
    required this.logoAsset,
    required this.onLater,
  });

  final AppUpdateDecision decision;
  final String appName;
  final String logoAsset;
  final VoidCallback onLater;

  @override
  State<AppUpdateGatePage> createState() => _AppUpdateGatePageState();
}

class _AppUpdateGatePageState extends State<AppUpdateGatePage> {
  bool _isOpening = false;
  String? _errorMessage;

  Future<void> _openUpdate() async {
    setState(() {
      _isOpening = true;
      _errorMessage = null;
    });

    final bool opened = await VersionUpdateService.openUpdate(widget.decision);
    if (!mounted) {
      return;
    }

    setState(() {
      _isOpening = false;
      _errorMessage = opened
          ? null
          : 'Update link is not configured yet. Please contact support.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool force = widget.decision.isForce;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFAF7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Spacer(),
              Center(
                child: Container(
                  width: 92,
                  height: 92,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x1417202A),
                        blurRadius: 28,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(widget.logoAsset, fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(height: 34),
              Text(
                force ? 'Update required' : 'A better version is ready',
                textAlign: TextAlign.left,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                  height: 1.12,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                force
                    ? 'This version of ${widget.appName} is no longer supported. Update now to continue securely.'
                    : 'Install the latest ${widget.appName} update for smoother performance and the newest fixes.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _VersionLine(
                      label: 'Installed',
                      value:
                          '${widget.decision.currentVersion} (${widget.decision.currentBuildNumber})',
                    ),
                    const SizedBox(height: 10),
                    _VersionLine(
                      label: 'Latest',
                      value: widget.decision.latestVersion,
                    ),
                    if (widget.decision.releaseNotes.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 14),
                      Text(
                        widget.decision.releaseNotes,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
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
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  label: _isOpening ? 'Opening...' : 'Update now',
                  icon: const Icon(Icons.arrow_outward_rounded),
                  isLoading: _isOpening,
                  onPressed: _isOpening ? null : _openUpdate,
                ),
              ),
              if (!force) ...<Widget>[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    label: 'Later',
                    variant: CustomButtonVariant.ghost,
                    onPressed: widget.onLater,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VersionLine extends StatelessWidget {
  const _VersionLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
