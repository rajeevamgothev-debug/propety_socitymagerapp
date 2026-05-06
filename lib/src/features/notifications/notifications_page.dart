import 'dart:async';

import 'package:flutter/material.dart';

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
      notification.type.toLowerCase() == 'enquiry';
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
  int _totalCount = 0;
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

      await _loadContractDetailsFor(result.notifications);

      if (!mounted) return;

      setState(() {
        if (reset) {
          _notifications = result.notifications;
        } else {
          _notifications = <NotificationData>[
            ..._notifications,
            ...result.notifications,
          ];
        }
        _totalCount = result.count;
        _unreadCount = result.unreadCount;
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
      await NotificationService.markAllAsRead();
      await _loadNotifications(reset: true);
      _showMessage('All notifications marked as read.');
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasMore = _skip < _totalCount;
    final bool hasUnread = _unreadCount > 0;

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
            // Search
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search notifications',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => _loadNotifications(reset: true),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 12),
            // Filter tabs
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
                  label: _unreadCount > 0 ? 'Unread ($_unreadCount)' : 'Unread',
                ),
                const CustomTabItem(label: 'Read'),
              ],
            ),
            const SizedBox(height: 16),
            // List
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
                        'Load More (${_totalCount - _skip} remaining)',
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Center(
                    child: Text(
                      'All $_totalCount notifications loaded',
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
    final ThemeData theme = Theme.of(context);
    final UiTone tone = _typeTone(notification.type);
    final String typeLabel = _typeLabel(notification.type);
    final String message = _displayMessage(notification, contract);

    return CustomCard(
      padding: CustomCardPadding.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Unread dot
              if (!notification.isRead) ...<Widget>[
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6, right: 10),
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ] else
                const SizedBox(width: 18),
              Expanded(
                child: Text(
                  notification.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: notification.isRead
                        ? FontWeight.w500
                        : FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ToneBadge(
                label: typeLabel,
                tone: tone,
                size: ToneBadgeSize.small,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${formatCompactDate(notification.createdAt)} at ${formatClock(notification.createdAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
                ),
                if (onMarkRead != null) ...<Widget>[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onMarkRead,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Mark as Read'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _typeLabel(String type) {
    return switch (type.toLowerCase()) {
      'payment' || 'billing' || '1' => 'Payment',
      'support' || 'ticket' || '2' => 'Support',
      'contract' || '3' => 'Contract',
      'enquiry' || 'lead' || '4' => 'Enquiry',
      'security' || '5' => 'Security',
      'announcement' || 'notice' || '6' => 'Notice',
      'system' || '7' => 'System',
      _ => 'Alert',
    };
  }

  static UiTone _typeTone(String type) {
    return switch (type.toLowerCase()) {
      'payment' || 'billing' || '1' => UiTone.success,
      'support' || 'ticket' || '2' => UiTone.brand,
      'contract' || '3' => UiTone.brand,
      'enquiry' || 'lead' || '4' => UiTone.warning,
      'security' || '5' => UiTone.danger,
      'announcement' || 'notice' || '6' => UiTone.brand,
      'system' || '7' => UiTone.neutral,
      _ => UiTone.neutral,
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

    if (_isEnquiryNotification(notification)) {
      final String message = _enquiryMessage(notification);
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

  static String _enquiryMessage(NotificationData notification) {
    final String name = _dataText(notification, <String>[
      'Name',
      'Full_Name',
      'Enquiry_Name',
    ]);
    final String phone = _dataText(notification, <String>[
      'FinalPhoneNumber',
      'PhoneNumber',
      'Phone',
    ]);
    final String email = _dataText(notification, <String>['EmailID', 'Email']);
    final String propertyTitle = _dataText(notification, <String>[
      'Property_Title',
      'Property_Name',
    ]);
    final String ownerName = _dataText(notification, <String>[
      'Owner_Name',
      'OwnerName',
    ]);
    final String status = _enquiryStatusLabel(
      notification.data['Enquiry_Status'],
    );

    final List<String> lines = <String>[
      if (name.isNotEmpty) 'Name: $name',
      if (phone.isNotEmpty) 'Mobile: $phone',
      if (email.isNotEmpty) 'Email: $email',
      if (propertyTitle.isNotEmpty) 'Property: $propertyTitle',
      if (ownerName.isNotEmpty) 'Owner: $ownerName',
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

  static String _enquiryStatusLabel(dynamic rawStatus) {
    return switch ('${rawStatus ?? ''}'.trim()) {
      '1' => 'New',
      '2' => 'Resolved',
      _ => '',
    };
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
}
