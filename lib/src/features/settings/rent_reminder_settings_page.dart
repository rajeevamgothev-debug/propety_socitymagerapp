import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/vendor_service.dart';
import '../../core/models/api_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_button.dart';

class RentReminderSettingsPage extends StatefulWidget {
  const RentReminderSettingsPage({super.key});

  @override
  State<RentReminderSettingsPage> createState() =>
      _RentReminderSettingsPageState();
}

class _RentReminderSettingsPageState extends State<RentReminderSettingsPage> {
  static const RentReminderSettingsData _fallbackReminder =
      RentReminderSettingsData(
        enabled: false,
        reminderDay: 1,
        reminderTime: '10:00',
      );
  static const BillingDefaultScheduleData _fallbackBilling =
      BillingDefaultScheduleData(
        whetherBillGenerationDayAvailable: false,
        billGenerationDay: 1,
        whetherDueScheduleAvailable: false,
        dueDay: 5,
        dueTime: '23:59',
      );

  RentReminderSettingsData? _settings;
  BillingDefaultScheduleData? _billingDefaults;
  RentReminderSettingsData? _loadedSettings;
  BillingDefaultScheduleData? _loadedBillingDefaults;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  RentReminderSettingsData get _currentReminder =>
      _settings ?? _fallbackReminder;

  BillingDefaultScheduleData get _currentBillingDefaults =>
      _billingDefaults ?? _fallbackBilling;

  bool get _hasChanges {
    final RentReminderSettingsData loadedReminder =
        _loadedSettings ?? _fallbackReminder;
    final BillingDefaultScheduleData loadedBilling =
        _loadedBillingDefaults ?? _fallbackBilling;
    return !_sameReminder(_currentReminder, loadedReminder) ||
        !_sameBillingDefaults(_currentBillingDefaults, loadedBilling);
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final RentReminderSettingsData? settings =
          await VendorService.fetchRentReminderSettings();
      final BillingDefaultScheduleData? billingDefaults =
          await VendorService.fetchBillingDefaultSchedule();
      if (!mounted) {
        return;
      }

      final RentReminderSettingsData resolvedReminder =
          settings ?? _fallbackReminder;
      final BillingDefaultScheduleData resolvedBilling =
          billingDefaults ?? _fallbackBilling;

      setState(() {
        _settings = resolvedReminder;
        _billingDefaults = resolvedBilling;
        _loadedSettings = resolvedReminder;
        _loadedBillingDefaults = resolvedBilling;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _pickReminderTime() async {
    final TimeOfDay? picked = await _pickTimeFor(_currentReminder.reminderTime);
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _settings = RentReminderSettingsData(
        enabled: _currentReminder.enabled,
        reminderDay: _currentReminder.reminderDay,
        reminderTime: _formatTimeForApi(picked),
      );
    });
  }

  Future<void> _pickDueTime() async {
    final TimeOfDay? picked = await _pickTimeFor(
      _currentBillingDefaults.dueTime,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _billingDefaults = BillingDefaultScheduleData(
        whetherBillGenerationDayAvailable:
            _currentBillingDefaults.whetherBillGenerationDayAvailable,
        billGenerationDay: _currentBillingDefaults.billGenerationDay,
        whetherDueScheduleAvailable:
            _currentBillingDefaults.whetherDueScheduleAvailable,
        dueDay: _currentBillingDefaults.dueDay,
        dueTime: _formatTimeForApi(picked),
      );
    });
  }

  Future<TimeOfDay?> _pickTimeFor(String value) {
    return showTimePicker(
      context: context,
      initialTime: _timeOfDayFromValue(value),
    );
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });

    final RentReminderSettingsData currentReminder = _currentReminder;
    final BillingDefaultScheduleData currentBilling = _currentBillingDefaults;

    try {
      final ApiResponse reminderResponse =
          await VendorService.updateRentReminderSettings(
            enabled: currentReminder.enabled,
            reminderDay: currentReminder.reminderDay,
            reminderTime: currentReminder.reminderTime,
          );
      final ApiResponse billingResponse =
          await VendorService.updateBillingDefaultSchedule(
            whetherBillGenerationDayAvailable:
                currentBilling.whetherBillGenerationDayAvailable,
            billGenerationDay: currentBilling.billGenerationDay,
            whetherDueScheduleAvailable:
                currentBilling.whetherDueScheduleAvailable,
            dueDay: currentBilling.dueDay,
            dueTime: currentBilling.dueTime,
          );

      if (!mounted) {
        return;
      }
      if (!reminderResponse.success || !billingResponse.success) {
        throw Exception(
          reminderResponse.message ??
              billingResponse.message ??
              reminderResponse.status ??
              billingResponse.status ??
              'Unable to save billing settings.',
        );
      }

      final RentReminderSettingsData savedReminder =
          reminderResponse.data is Map<String, dynamic>
          ? RentReminderSettingsData.fromJson(
              reminderResponse.data as Map<String, dynamic>,
            )
          : currentReminder;
      final BillingDefaultScheduleData savedBilling =
          billingResponse.data is Map<String, dynamic>
          ? BillingDefaultScheduleData.fromJson(
              billingResponse.data as Map<String, dynamic>,
            )
          : currentBilling;

      setState(() {
        _settings = savedReminder;
        _billingDefaults = savedBilling;
        _loadedSettings = savedReminder;
        _loadedBillingDefaults = savedBilling;
      });
      _showMessage('Reminder and billing defaults saved.');
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  TimeOfDay _timeOfDayFromValue(String value) {
    final List<String> parts = value.split(':');
    final int hour = parts.isNotEmpty ? int.tryParse(parts.first) ?? 10 : 10;
    final int minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  String _formatTimeForApi(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatTimeLabel(String value) {
    final TimeOfDay parsed = _timeOfDayFromValue(value);
    final int hour = parsed.hourOfPeriod == 0 ? 12 : parsed.hourOfPeriod;
    final String minute = parsed.minute.toString().padLeft(2, '0');
    final String period = parsed.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final RentReminderSettingsData reminder = _currentReminder;
    final BillingDefaultScheduleData billing = _currentBillingDefaults;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(title: const Text('Rent Reminder & Billing')),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: CustomButton(
            label: _hasChanges ? 'Save settings' : 'Saved',
            icon: const Icon(Icons.save_outlined),
            isLoading: _isSaving,
            onPressed: _isSaving || _isLoading || !_hasChanges
                ? null
                : _saveSettings,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadSettings,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: <Widget>[
            _IntroBand(
              title: 'Applies to all properties',
              description:
                  'Set one reminder schedule and one billing schedule for all properties. Contract-level custom schedules can still override these defaults.',
            ),
            const SizedBox(height: 18),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 72),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorPanel(message: _error!, onRetry: _loadSettings)
            else ...<Widget>[
              _SectionPanel(
                icon: Icons.notifications_active_rounded,
                iconBackground: const Color(0xFFE9F7F0),
                iconColor: const Color(0xFF15803D),
                title: 'WhatsApp rent reminder',
                subtitle:
                    'Choose when unpaid rent reminders go out each month.',
                trailing: Switch(
                  value: reminder.enabled,
                  onChanged: (bool value) {
                    setState(() {
                      _settings = RentReminderSettingsData(
                        enabled: value,
                        reminderDay: reminder.reminderDay,
                        reminderTime: reminder.reminderTime,
                      );
                    });
                  },
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _StatusSummary(
                      title: reminder.enabled
                          ? 'Reminder is active'
                          : 'Reminder is off',
                      subtitle: reminder.enabled
                          ? 'Sends every month on day ${reminder.reminderDay} at ${_formatTimeLabel(reminder.reminderTime)}.'
                          : 'Turn it on to choose the monthly day and time.',
                      tone: reminder.enabled
                          ? _PanelTone.success
                          : _PanelTone.neutral,
                    ),
                    const SizedBox(height: 18),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 220),
                      crossFadeState: reminder.enabled
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: const _CollapsedNote(
                        title: 'Schedule hidden while off',
                        message:
                            'Enable the reminder to choose when the monthly WhatsApp message is sent.',
                      ),
                      secondChild: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _FieldHeader(
                            title: 'Monthly day',
                            description:
                                'Pick the day of the month when the reminder should be sent.',
                          ),
                          const SizedBox(height: 12),
                          _DayGridPicker(
                            selectedDay: reminder.reminderDay,
                            onChanged: (int day) {
                              setState(() {
                                _settings = RentReminderSettingsData(
                                  enabled: reminder.enabled,
                                  reminderDay: day,
                                  reminderTime: reminder.reminderTime,
                                );
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          _FieldHeader(
                            title: 'Reminder time',
                            description:
                                'Choose the time for the monthly reminder.',
                          ),
                          const SizedBox(height: 12),
                          _TimeButton(
                            label: _formatTimeLabel(reminder.reminderTime),
                            onTap: _pickReminderTime,
                          ),
                          const SizedBox(height: 16),
                          const _HintBox(
                            icon: Icons.info_outline_rounded,
                            text:
                                'Paid bills are skipped automatically. Only unpaid rent bills receive reminders.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _SectionPanel(
                icon: Icons.calendar_month_rounded,
                iconBackground: const Color(0xFFE8F0FF),
                iconColor: const Color(0xFF1D4ED8),
                title: 'Billing defaults',
                subtitle:
                    'Apply one clean default schedule across all properties.',
                child: Column(
                  children: <Widget>[
                    _ScheduleSettingBlock(
                      title: 'Bill generation day',
                      description:
                          'Create monthly rent bills on one standard day.',
                      enabled: billing.whetherBillGenerationDayAvailable,
                      enabledSummary:
                          'Bills are generated on day ${billing.billGenerationDay} each month.',
                      disabledSummary: 'No default bill generation day is set.',
                      onToggle: (bool value) {
                        setState(() {
                          _billingDefaults = BillingDefaultScheduleData(
                            whetherBillGenerationDayAvailable: value,
                            billGenerationDay: billing.billGenerationDay,
                            whetherDueScheduleAvailable:
                                billing.whetherDueScheduleAvailable,
                            dueDay: billing.dueDay,
                            dueTime: billing.dueTime,
                          );
                        });
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const _FieldHeader(
                            title: 'Generation day',
                            description:
                                'Use the same day for all monthly bill generation.',
                          ),
                          const SizedBox(height: 12),
                          _DayGridPicker(
                            selectedDay: billing.billGenerationDay,
                            onChanged: (int day) {
                              setState(() {
                                _billingDefaults = BillingDefaultScheduleData(
                                  whetherBillGenerationDayAvailable:
                                      billing.whetherBillGenerationDayAvailable,
                                  billGenerationDay: day,
                                  whetherDueScheduleAvailable:
                                      billing.whetherDueScheduleAvailable,
                                  dueDay: billing.dueDay,
                                  dueTime: billing.dueTime,
                                );
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _ScheduleSettingBlock(
                      title: 'Due date and time',
                      description:
                          'Apply one default due day and one default due time to future rent bills.',
                      enabled: billing.whetherDueScheduleAvailable,
                      enabledSummary:
                          'Bills are due on day ${billing.dueDay} at ${_formatTimeLabel(billing.dueTime)}.',
                      disabledSummary: 'No default due date or time is set.',
                      onToggle: (bool value) {
                        setState(() {
                          _billingDefaults = BillingDefaultScheduleData(
                            whetherBillGenerationDayAvailable:
                                billing.whetherBillGenerationDayAvailable,
                            billGenerationDay: billing.billGenerationDay,
                            whetherDueScheduleAvailable: value,
                            dueDay: billing.dueDay,
                            dueTime: billing.dueTime,
                          );
                        });
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const _FieldHeader(
                            title: 'Due day',
                            description:
                                'Choose the day of the month when payment is due.',
                          ),
                          const SizedBox(height: 12),
                          _DayGridPicker(
                            selectedDay: billing.dueDay,
                            onChanged: (int day) {
                              setState(() {
                                _billingDefaults = BillingDefaultScheduleData(
                                  whetherBillGenerationDayAvailable:
                                      billing.whetherBillGenerationDayAvailable,
                                  billGenerationDay: billing.billGenerationDay,
                                  whetherDueScheduleAvailable:
                                      billing.whetherDueScheduleAvailable,
                                  dueDay: day,
                                  dueTime: billing.dueTime,
                                );
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          const _FieldHeader(
                            title: 'Due time',
                            description:
                                'Choose the cutoff time for the due day.',
                          ),
                          const SizedBox(height: 12),
                          _TimeButton(
                            label: _formatTimeLabel(billing.dueTime),
                            onTap: _pickDueTime,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _HintBox(
                      icon: Icons.calendar_today_outlined,
                      text:
                          'Only days 1-28 are supported so the schedule stays valid in every month.',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _sameReminder(RentReminderSettingsData a, RentReminderSettingsData b) {
    return a.enabled == b.enabled &&
        a.reminderDay == b.reminderDay &&
        a.reminderTime == b.reminderTime;
  }

  bool _sameBillingDefaults(
    BillingDefaultScheduleData a,
    BillingDefaultScheduleData b,
  ) {
    return a.whetherBillGenerationDayAvailable ==
            b.whetherBillGenerationDayAvailable &&
        a.billGenerationDay == b.billGenerationDay &&
        a.whetherDueScheduleAvailable == b.whetherDueScheduleAvailable &&
        a.dueDay == b.dueDay &&
        a.dueTime == b.dueTime;
  }
}

class _IntroBand extends StatelessWidget {
  const _IntroBand({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD9E5FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.secondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1C5C0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Unable to load reminder settings',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          CustomButton(
            label: 'Retry',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EBF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

enum _PanelTone { success, neutral }

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({
    required this.title,
    required this.subtitle,
    required this.tone,
  });

  final String title;
  final String subtitle;
  final _PanelTone tone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color background = tone == _PanelTone.success
        ? const Color(0xFFEAF8F0)
        : const Color(0xFFF2F5F9);
    final Color foreground = tone == _PanelTone.success
        ? const Color(0xFF15803D)
        : const Color(0xFF475569);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tone == _PanelTone.success
              ? const Color(0xFFCDE8D8)
              : const Color(0xFFDCE4EE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: foreground,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsedNote extends StatelessWidget {
  const _CollapsedNote({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6EBF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldHeader extends StatelessWidget {
  const _FieldHeader({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _DayGridPicker extends StatelessWidget {
  const _DayGridPicker({required this.selectedDay, required this.onChanged});

  final int selectedDay;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 28,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.12,
      ),
      itemBuilder: (BuildContext context, int index) {
        final int day = index + 1;
        final bool selected = selectedDay == day;

        return Semantics(
          button: true,
          selected: selected,
          label: 'Day $day',
          child: InkWell(
            onTap: () => onChanged(day),
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary : const Color(0xFFF8FAFD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? AppTheme.primary : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                '$day',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected ? Colors.white : AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD9E2EE)),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.schedule_rounded, color: AppTheme.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_right_rounded,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _HintBox extends StatelessWidget {
  const _HintBox({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4EAF2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleSettingBlock extends StatelessWidget {
  const _ScheduleSettingBlock({
    required this.title,
    required this.description,
    required this.enabled,
    required this.enabledSummary,
    required this.disabledSummary,
    required this.onToggle,
    required this.child,
  });

  final String title;
  final String description;
  final bool enabled;
  final String enabledSummary;
  final String disabledSummary;
  final ValueChanged<bool> onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFEFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7EDF6)),
      ),
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
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(value: enabled, onChanged: onToggle),
            ],
          ),
          const SizedBox(height: 14),
          _StatusSummary(
            title: enabled ? 'Default applied' : 'Default not applied',
            subtitle: enabled ? enabledSummary : disabledSummary,
            tone: enabled ? _PanelTone.success : _PanelTone.neutral,
          ),
          const SizedBox(height: 14),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: enabled
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const _CollapsedNote(
              title: 'Options hidden while off',
              message:
                  'Turn this setting on to choose the day and, if needed, the time.',
            ),
            secondChild: child,
          ),
        ],
      ),
    );
  }
}
