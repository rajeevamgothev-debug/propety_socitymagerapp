import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/notification_service.dart';
import '../../core/api/rental_contract_service.dart';
import '../../core/models/api_models.dart';
import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_card.dart';
import '../../core/widgets/custom_tab_bar.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/tone_badge.dart';

bool _isRentalContractNotification(NotificationData notification) {
  final String referenceType = notification.referenceType.toLowerCase();
  final String title = notification.title.toLowerCase();
  return referenceType.contains('rental_contract') ||
      notification.type.toLowerCase() == 'contract' ||
      title.contains('rental contract');
}

bool _isEnquiryNotification(NotificationData notification) {
  final String referenceType = notification.referenceType.toLowerCase();
  return referenceType.contains('property_enquiry') ||
      referenceType.contains('enquiry') ||
      referenceType.contains('lead') ||
      notification.type.toLowerCase() == 'enquiry';
}

bool _isPaymentNotification(NotificationData notification) {
  final String referenceType = notification.referenceType.toLowerCase();
  final String type = notification.type.toLowerCase();
  final String title = notification.title.toLowerCase();
  final String message = notification.message.toLowerCase();
  final String combined = '$referenceType $type $title $message';
  return combined.contains('bill') ||
      combined.contains('rent') ||
      combined.contains('payment') ||
      combined.contains('wallet') ||
      combined.contains('security deposit') ||
      combined.contains('maintenance');
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const int _pageSize = 10;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // 0 = All, 1 = Unread, 2 = Read
  int _filterTab = 0;

  List<NotificationData> _notifications = <NotificationData>[];
  int _backendTotalCount = 0;
  int _unreadCount = 0;
  int _skip = 0;
  bool _isLoading = true;
  String? _errorMessage;
  final Map<String, RentalContractRecord> _contractsById =
      <String, RentalContractRecord>{};

  bool? get _readFilter => switch (_filterTab) {
    1 => false, // unread
    2 => true, // read
    _ => null, // all
  };

  @override
  void initState() {
    super.initState();
    _loadNotifications(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications({bool reset = false}) async {
    final int skip = reset ? 0 : _skip;
    if (reset) {
      setState(() {
        _skip = 0;
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final String? search = _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim();

      final result = await NotificationService.filterNotifications(
        skip: skip,
        limit: _pageSize,
        read: _readFilter,
        search: search,
      );

      final List<NotificationData> enquiryNotifications =
          reset && _readFilter != true
          ? (await NotificationService.filterOpenPropertyEnquiryNotifications(
              limit: 50,
              search: search,
            )).notifications
          : <NotificationData>[];
      final List<NotificationData> visibleNotifications = reset
          ? NotificationService.mergePropertyEnquiryNotifications(
              result.notifications,
              enquiryNotifications,
            )
          : result.notifications;

      await _loadContractDetailsFor(visibleNotifications);

      if (!mounted) return;

      setState(() {
        if (reset) {
          _notifications = visibleNotifications;
        } else {
          _notifications = <NotificationData>[
            ..._notifications,
            ...visibleNotifications,
          ];
        }
        final int localUnreadCount = _notifications
            .where(
              (NotificationData item) =>
                  item.isLocalPropertyEnquiry && !item.isRead,
            )
            .length;
        _backendTotalCount = result.count;
        _unreadCount = result.unreadCount + localUnreadCount;
        _skip = skip + result.notifications.length;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadContractDetailsFor(
    List<NotificationData> notifications,
  ) async {
    final Set<String> missingContractIds = notifications
        .where(
          (NotificationData notification) =>
              _isRentalContractNotification(notification) &&
              notification.referenceId.isNotEmpty &&
              !_contractsById.containsKey(notification.referenceId),
        )
        .map((NotificationData notification) => notification.referenceId)
        .toSet();

    if (missingContractIds.isEmpty) return;

    try {
      final Set<String> remainingIds = <String>{...missingContractIds};
      const int pageSize = 100;
      const int maxContractsToScan = 1000;
      int skip = 0;
      int scannedCount = 0;

      while (remainingIds.isNotEmpty && scannedCount < maxContractsToScan) {
        final result = await RentalContractService.filterRentalContracts(
          skip: skip,
          limit: pageSize,
        );
        if (result.contracts.isEmpty) break;

        for (final RentalContractRecord contract in result.contracts) {
          _contractsById[contract.id] = contract;
          remainingIds.remove(contract.id);
        }

        skip += result.contracts.length;
        scannedCount += result.contracts.length;
        if (skip >= result.count) break;
      }
    } catch (_) {
      // Keep the notification list usable even if the linked contract lookup
      // fails for older/deleted contracts.
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _loadNotifications(reset: true);
    });
  }

  Future<void> _markAsRead(NotificationData notification) async {
    try {
      await NotificationService.markAsRead(notification.notificationId);
      await _loadNotifications(reset: true);
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final bool hasBackendUnread = _notifications.any(
        (NotificationData item) => !item.isRead && !item.isLocalPropertyEnquiry,
      );
      NotificationService.markLocalPropertyEnquiriesAsRead(
        _notifications.where((NotificationData item) => !item.isRead),
      );
      if (hasBackendUnread) {
        await NotificationService.markAllAsRead();
      }
      await _loadNotifications(reset: true);
      _showMessage('All notifications marked as read.');
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasMore = _skip < _backendTotalCount;
    final bool hasUnread = _notifications.any(
      (NotificationData item) => !item.isRead,
    );
    final int visibleCount = _notifications.length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Text('Notifications'),
        actions: <Widget>[
          if (hasUnread)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Mark all read'),
            ),
          const SizedBox(width: 4),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.border),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadNotifications(reset: true),
        child: ListView(
          padding: AppTheme.pagePadding,
          children: <Widget>[
            const PageHeader(
              title: 'Notifications',
              description:
                  'Activity alerts, payment updates, and system messages.',
            ),
            const SizedBox(height: 16),
            CustomCard(
              padding: CustomCardPadding.sm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Inbox controls',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      ToneBadge(
                        label: _unreadCount > 0
                            ? '$_unreadCount unread'
                            : 'All caught up',
                        tone: _unreadCount > 0 ? UiTone.brand : UiTone.success,
                        size: ToneBadgeSize.small,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search notifications',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward_rounded),
                        onPressed: () => _loadNotifications(reset: true),
                      ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                  const SizedBox(height: 14),
                  CustomTabBar(
                    style: CustomTabBarStyle.pill,
                    currentIndex: _filterTab,
                    onChanged: (int index) {
                      setState(() => _filterTab = index);
                      _loadNotifications(reset: true);
                    },
                    tabs: <CustomTabItem>[
                      const CustomTabItem(label: 'All'),
                      CustomTabItem(
                        label: _unreadCount > 0
                            ? 'Unread ($_unreadCount)'
                            : 'Unread',
                      ),
                      const CustomTabItem(label: 'Read'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading && _notifications.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 64),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null && _notifications.isEmpty)
              CustomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Unable to load notifications',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CustomButton(
                      label: 'Retry',
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: () => _loadNotifications(reset: true),
                    ),
                  ],
                ),
              )
            else if (_notifications.isEmpty)
              const CustomCard(
                padding: CustomCardPadding.sm,
                child: Text('No notifications found.'),
              )
            else ...<Widget>[
              ..._notifications.map(
                (NotificationData n) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _NotificationCard(
                    notification: n,
                    contract: _contractsById[n.referenceId],
                    onMarkRead: n.isRead ? null : () => _markAsRead(n),
                  ),
                ),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (hasMore)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _loadNotifications(),
                      child: Text(
                        'Load More (${_backendTotalCount - _skip} remaining)',
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Center(
                    child: Text(
                      'All $visibleCount notifications loaded',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.contract,
    required this.onMarkRead,
  });

  final NotificationData notification;
  final RentalContractRecord? contract;
  final VoidCallback? onMarkRead;

  @override
  Widget build(BuildContext context) {
    final UiTone tone = _typeTone(notification.type);
    final String typeLabel = _typeLabel(notification.type);
    final String message = _displayMessage(notification, contract);
    final IconData typeIcon = _typeIcon(notification.type);
    final String propertyImageUrl = _propertyImageUrl(notification);
    final NotificationDisplayModel display =
        NotificationDisplayModel.fromNotification(
          notification,
          contract: contract,
          typeLabel: typeLabel,
          message: message,
        );

    return CustomCard(
      padding: CustomCardPadding.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _NotificationTopSection(
            display: display,
            logo: _NotificationLogo(
              tone: tone,
              icon: typeIcon,
              isRead: notification.isRead,
              imageUrl: propertyImageUrl,
            ),
            tone: tone,
          ),
          if (propertyImageUrl.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _NotificationImagePreview(imageUrl: propertyImageUrl, tone: tone),
          ],
          const SizedBox(height: 14),
          _NotificationMessageSection(display: display),
          if (display.contextDetails.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            _NotificationContextSection(
              details: display.contextDetails,
              onPhoneTap: _launchPhone,
            ),
          ],
          const SizedBox(height: 12),
          _NotificationActions(
            onMarkRead: onMarkRead,
            onViewDetails: () => _showDetailsSheet(context, display),
          ),
        ],
      ),
    );
  }

  static Future<void> _launchPhone(String phone) async {
    await launchUrl(Uri.parse('tel:${_digitsForDial(phone)}'));
  }

  static void _showDetailsSheet(
    BuildContext context,
    NotificationDisplayModel display,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) =>
          _NotificationDetailsSheet(display: display, onPhoneTap: _launchPhone),
    );
  }

  static String _digitsForDial(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  static String _typeLabel(String type) {
    return switch (type.toLowerCase()) {
      'payment' || 'billing' || '1' || '5' => 'Billing',
      'contract' || '2' => 'Contract',
      'announcement' || 'notice' || '3' => 'Notice',
      'support' || 'ticket' || '4' => 'Support',
      'enquiry' || 'lead' || '6' => 'Enquiry',
      'security' => 'Security',
      'system' || '7' => 'System',
      _ => 'Alert',
    };
  }

  static UiTone _typeTone(String type) {
    return switch (type.toLowerCase()) {
      'payment' || 'billing' || '1' || '5' => UiTone.success,
      'contract' || '2' => UiTone.brand,
      'announcement' || 'notice' || '3' => UiTone.brand,
      'support' || 'ticket' || '4' => UiTone.brand,
      'enquiry' || 'lead' || '6' => UiTone.warning,
      'security' => UiTone.danger,
      'system' || '7' => UiTone.neutral,
      _ => UiTone.neutral,
    };
  }

  static IconData _typeIcon(String type) {
    return switch (type.toLowerCase()) {
      'payment' ||
      'billing' ||
      '1' ||
      '5' => Icons.account_balance_wallet_rounded,
      'contract' || '2' => Icons.description_rounded,
      'announcement' || 'notice' || '3' => Icons.campaign_rounded,
      'support' || 'ticket' || '4' => Icons.confirmation_number_rounded,
      'enquiry' || 'lead' || '6' => Icons.person_search_rounded,
      'security' => Icons.security_rounded,
      'system' || '7' => Icons.settings_suggest_rounded,
      _ => Icons.notifications_rounded,
    };
  }

  static String _displayMessage(
    NotificationData notification,
    RentalContractRecord? contract,
  ) {
    if (_isRentalContractNotification(notification)) {
      final String message = _rentalContractMessage(notification, contract);
      if (message.isNotEmpty) return message;
    }

    return notification.message;
  }

  static String _rentalContractMessage(
    NotificationData notification,
    RentalContractRecord? contract,
  ) {
    final String tenantName = _firstNonEmpty(<String?>[
      contract?.tenantName,
      _dataText(notification, <String>['Tenant_Name', 'TenantName', 'Tenant']),
    ]);
    final String tenantPhone = _firstNonEmpty(<String?>[
      contract?.tenantPhone,
      _dataText(notification, <String>[
        'Tenant_PhoneNumber',
        'Tenant_Phone',
        'PhoneNumber',
        'Phone',
      ]),
    ]);
    final String tenantEmail = _firstNonEmpty(<String?>[
      contract?.tenantEmail,
      _dataText(notification, <String>['Tenant_EmailID', 'Tenant_Email']),
    ]);
    final String propertyTitle = _firstNonEmpty(<String?>[
      contract?.propertyTitle,
      _dataText(notification, <String>['Property_Title', 'Property_Name']),
    ]);
    final String unit = _firstNonEmpty(<String?>[
      contract?.flatNo,
      _dataText(notification, <String>['Flat_Or_Unit_No', 'Unit_No']),
    ]);
    final String status = _contractStatusLabel(notification);

    final List<String> lines = <String>[
      if (tenantName.isNotEmpty) 'Tenant: $tenantName',
      if (tenantPhone.isNotEmpty) 'Mobile: $tenantPhone',
      if (tenantEmail.isNotEmpty) 'Email: $tenantEmail',
      if (propertyTitle.isNotEmpty) 'Property: $propertyTitle',
      if (unit.isNotEmpty) 'Unit: $unit',
      if (status.isNotEmpty) 'Status: $status',
    ];

    return lines.join('\n');
  }

  static String _contractStatusLabel(NotificationData notification) {
    final String content = '${notification.title} ${notification.message}'
        .toLowerCase();
    if (content.contains('inactivated') || content.contains('deactivated')) {
      return 'Deactivated';
    }
    if (content.contains('activated')) return 'Activated';
    if (content.contains('created')) return 'Created';
    if (content.contains('updated')) return 'Updated';
    if (content.contains('closed')) return 'Closed';
    return '';
  }

  static String _dataText(NotificationData notification, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = notification.data[key];
      final String text = '${value ?? ''}'.trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final String? value in values) {
      final String text = (value ?? '').trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String _propertyImageUrl(NotificationData notification) {
    final String propertyImageUrl = _dataText(notification, <String>[
      'Property_Image_URL',
      'Property_Image_Original_URL',
      'propertyImageUrl',
      'propertyImage',
      'Property_Image',
    ]);
    if (_isPaymentNotification(notification)) return propertyImageUrl;
    if (propertyImageUrl.isNotEmpty) return propertyImageUrl;
    if (!_isEnquiryNotification(notification)) return '';
    return _dataText(notification, <String>[
      'Image_Original_URL',
      'Image_URL',
    ]);
  }
}

class _NotificationLogo extends StatelessWidget {
  const _NotificationLogo({
    required this.tone,
    required this.icon,
    required this.isRead,
    required this.imageUrl,
  });

  final UiTone tone;
  final IconData icon;
  final bool isRead;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final Color toneColor = AppTheme.toneColor(tone);
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.toneSoft(tone),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(color: AppTheme.toneContainer(tone)),
          ),
          clipBehavior: Clip.antiAlias,
          child: imageUrl.isEmpty
              ? Image.asset(
                  'assets/manager_logo.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.home_work_rounded, color: toneColor),
                )
              : Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.home_work_rounded, color: toneColor),
                ),
        ),
        Positioned(
          right: -5,
          bottom: -5,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border),
            ),
            child: Icon(icon, size: 14, color: toneColor),
          ),
        ),
        if (!isRead)
          Positioned(
            top: -3,
            right: -3,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class _NotificationTopSection extends StatelessWidget {
  const _NotificationTopSection({
    required this.display,
    required this.logo,
    required this.tone,
  });

  final NotificationDisplayModel display;
  final Widget logo;
  final UiTone tone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(label: '${display.category} notification', child: logo),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      display.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: display.isRead
                            ? FontWeight.w600
                            : FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ToneBadge(
                    label: display.category,
                    tone: tone,
                    size: ToneBadgeSize.small,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  _NotificationMeta(
                    icon: Icons.schedule_rounded,
                    label: display.time,
                  ),
                  _NotificationMeta(
                    icon: display.isRead
                        ? Icons.mark_email_read_rounded
                        : Icons.mark_email_unread_rounded,
                    label: display.isRead ? 'Read' : 'Unread',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotificationMeta extends StatelessWidget {
  const _NotificationMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _NotificationMessageSection extends StatelessWidget {
  const _NotificationMessageSection({required this.display});

  final NotificationDisplayModel display;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      label: 'Notification message',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.45,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            display.message,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationContextSection extends StatelessWidget {
  const _NotificationContextSection({
    required this.details,
    required this.onPhoneTap,
  });

  final List<_NotificationDetail> details;
  final ValueChanged<String> onPhoneTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Details',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        ...details.map(
          (_NotificationDetail detail) => _NotificationInfoRow(
            detail: detail,
            onTap: detail.isPhone ? () => onPhoneTap(detail.value) : null,
          ),
        ),
      ],
    );
  }
}

class _NotificationInfoRow extends StatelessWidget {
  const _NotificationInfoRow({required this.detail, this.onTap});

  final _NotificationDetail detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isPhone = detail.isPhone;
    final Color callColor = AppTheme.primary;
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            detail.icon,
            size: 17,
            color: isPhone ? callColor : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 98,
            child: Text(
              detail.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isPhone ? callColor : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              detail.value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isPhone ? callColor : theme.colorScheme.onSurface,
                fontWeight: isPhone ? FontWeight.w800 : FontWeight.w400,
                decoration: isPhone
                    ? TextDecoration.underline
                    : TextDecoration.none,
              ),
            ),
          ),
          if (isPhone) ...<Widget>[
            const SizedBox(width: 8),
            Icon(Icons.call_rounded, size: 16, color: callColor),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: content,
    );
  }
}

class _NotificationActions extends StatelessWidget {
  const _NotificationActions({
    required this.onMarkRead,
    required this.onViewDetails,
  });

  final VoidCallback? onMarkRead;
  final VoidCallback? onViewDetails;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: onMarkRead,
          icon: const Icon(Icons.done_all_rounded, size: 18),
          label: const Text('Mark as Read'),
        ),
        OutlinedButton.icon(
          onPressed: onViewDetails,
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: const Text('View Details'),
        ),
      ],
    );
  }
}

class _NotificationDetailsSheet extends StatelessWidget {
  const _NotificationDetailsSheet({
    required this.display,
    required this.onPhoneTap,
  });

  final NotificationDisplayModel display;
  final ValueChanged<String> onPhoneTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              display.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            _NotificationMeta(
              icon: Icons.schedule_rounded,
              label: display.time,
            ),
            const SizedBox(height: 14),
            Text(
              display.message,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            if (display.contextDetails.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              _NotificationContextSection(
                details: display.contextDetails,
                onPhoneTap: onPhoneTap,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationImagePreview extends StatelessWidget {
  const _NotificationImagePreview({required this.imageUrl, required this.tone});

  final String imageUrl;
  final UiTone tone;

  @override
  Widget build(BuildContext context) {
    final Color toneColor = AppTheme.toneColor(tone);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppTheme.toneSoft(tone),
            alignment: Alignment.center,
            child: Icon(Icons.apartment_rounded, color: toneColor),
          ),
        ),
      ),
    );
  }
}

class _NotificationDetail {
  const _NotificationDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  bool get isPhone => label.toLowerCase().contains('phone');
}

class NotificationDisplayModel {
  const NotificationDisplayModel({
    required this.title,
    required this.message,
    required this.category,
    required this.time,
    required this.isRead,
    required this.contextDetails,
    required this.phone,
    required this.canContact,
  });

  final String title;
  final String message;
  final String category;
  final String time;
  final bool isRead;
  final List<_NotificationDetail> contextDetails;
  final String phone;
  final bool canContact;

  factory NotificationDisplayModel.fromNotification(
    NotificationData notification, {
    required RentalContractRecord? contract,
    required String typeLabel,
    required String message,
  }) {
    final bool isEnquiry = _isEnquiryNotification(notification);
    final bool isAnnouncement = typeLabel == 'Notice';
    final String title = notification.title.trim().isEmpty
        ? typeLabel
        : notification.title.trim();
    final String phone = _firstDataText(notification, <String>[
      'PhoneNumber',
      'Phone',
      'Tenant_PhoneNumber',
      'Resident_PhoneNumber',
    ]);
    final String propertyName = _firstNonEmpty(<String?>[
      contract?.propertyTitle,
      _firstDataText(notification, <String>[
        'Property_Title',
        'Property_Name',
        'Society_Name',
      ]),
    ]);
    final String apartmentType = _firstDataText(notification, <String>[
      'Sub_Type_Label',
      'Flat_Or_Unit_No',
      'Property_Type_Label',
    ]);
    final String priority = _firstDataText(notification, <String>[
      'Priority_Label',
      'Priority',
    ]);
    final String target = _firstDataText(notification, <String>[
      'Announcement_Target_Label',
    ]);
    final String blockNames = _firstDataText(notification, <String>[
      'Block_Names',
      'Block_Name',
    ]);
    final String buildingNames = _firstDataText(notification, <String>[
      'Building_Names',
      'Building_Name',
    ]);
    final String summary = isEnquiry
        ? _buildEnquirySummary(
            apartmentType: apartmentType,
            propertyName: propertyName,
          )
        : (message.trim().isEmpty
              ? 'No message details were provided.'
              : message.trim());

    final List<_NotificationDetail> details = <_NotificationDetail>[
      if (propertyName.isNotEmpty)
        _NotificationDetail(
          icon: Icons.apartment_rounded,
          label: isAnnouncement ? 'Society' : 'Property',
          value: propertyName,
        ),
      if (phone.isNotEmpty)
        _NotificationDetail(
          icon: Icons.phone_rounded,
          label: 'Phone',
          value: phone,
        ),
      if (isAnnouncement && priority.isNotEmpty)
        _NotificationDetail(
          icon: Icons.flag_rounded,
          label: 'Priority',
          value: _priorityLabel(priority),
        ),
      if (isAnnouncement && target.isNotEmpty)
        _NotificationDetail(
          icon: Icons.groups_rounded,
          label: 'Target',
          value: target,
        ),
      if (isAnnouncement && blockNames.isNotEmpty)
        _NotificationDetail(
          icon: Icons.domain_rounded,
          label: 'Block',
          value: blockNames,
        ),
      if (isAnnouncement && buildingNames.isNotEmpty)
        _NotificationDetail(
          icon: Icons.location_city_rounded,
          label: 'Building',
          value: buildingNames,
        ),
    ];

    return NotificationDisplayModel(
      title: title,
      message: summary,
      category: typeLabel,
      time:
          '${formatCompactDate(notification.createdAt)} at ${formatClock(notification.createdAt)}',
      isRead: notification.isRead,
      contextDetails: details,
      phone: phone,
      canContact: phone.isNotEmpty,
    );
  }

  static String _buildEnquirySummary({
    required String apartmentType,
    required String propertyName,
  }) {
    final String home = apartmentType.isEmpty ? 'property' : apartmentType;
    if (propertyName.isEmpty) {
      return 'A customer is interested in your $home.';
    }
    return 'A customer is interested in your $home at $propertyName.';
  }

  static String _firstDataText(
    NotificationData notification,
    List<String> keys,
  ) {
    for (final String key in keys) {
      final Object? value = notification.data[key];
      final String text = _displayText(value);
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }

  static String _displayText(Object? value) {
    if (value == null) return '';
    if (value is List) {
      return value
          .map((Object? item) => '$item'.trim())
          .where((String item) => item.isNotEmpty && item != 'null')
          .join(', ');
    }
    return '$value'.trim();
  }

  static String _priorityLabel(String value) {
    return switch (value.trim()) {
      '1' => 'Low',
      '2' => 'Medium',
      '3' => 'High',
      '4' => 'Critical',
      _ => value,
    };
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final String? value in values) {
      final String text = (value ?? '').trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}
