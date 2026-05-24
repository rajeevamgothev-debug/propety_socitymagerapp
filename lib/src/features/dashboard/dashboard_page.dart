import 'package:flutter/material.dart';

import '../../core/models/api_models.dart';
import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_card.dart';
import '../../core/widgets/mobile_banner_carousel.dart';
import '../../core/widgets/tone_badge.dart';

class DashboardPage extends StatelessWidget {
  static const List<_DefaultAmenity> _defaultAmenities = <_DefaultAmenity>[
    _DefaultAmenity(label: 'Swimming Pool', icon: Icons.pool_outlined),
    _DefaultAmenity(label: 'Gymnasium', icon: Icons.fitness_center_outlined),
    _DefaultAmenity(
      label: 'Children\'s Play Area',
      icon: Icons.child_care_outlined,
    ),
    _DefaultAmenity(label: 'Community Hall', icon: Icons.groups_outlined),
    _DefaultAmenity(label: 'Parking', icon: Icons.local_parking_outlined),
    _DefaultAmenity(label: '24/7 Security', icon: Icons.security_outlined),
    _DefaultAmenity(
      label: 'Power Backup',
      icon: Icons.electrical_services_outlined,
    ),
    _DefaultAmenity(label: 'Water Supply', icon: Icons.water_drop_outlined),
  ];

  const DashboardPage({
    super.key,
    required this.role,
    required this.metrics,
    required this.shortcuts,
    required this.announcements,
    required this.tickets,
    required this.onShortcutSelected,
    this.bills = const <BillRecord>[],
    this.vendor,
    this.societyInfo,
    this.billCollectionSummary,
    this.blockCount = 0,
    this.buildingCount = 0,
    this.propertyEnquiryCountOverride,
    this.isLoading = false,
    this.onRefresh,
  });

  final AppRole role;
  final List<DashboardMetric> metrics;
  final List<AppShortcut> shortcuts;
  final List<AnnouncementRecord> announcements;
  final List<TicketRecord> tickets;
  final List<BillRecord> bills;
  final ValueChanged<String> onShortcutSelected;
  final VendorData? vendor;
  final SocietyData? societyInfo;
  final BillCollectionSummaryData? billCollectionSummary;
  final int blockCount;
  final int buildingCount;
  final int? propertyEnquiryCountOverride;
  final bool isLoading;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final List<TicketRecord> ticketPreview = tickets.take(2).toList();
    final List<AnnouncementRecord> announcementPreview = announcements
        .take(2)
        .toList();

    if (role == AppRole.tenant ||
        role == AppRole.owner ||
        role == AppRole.pgResident) {
      Widget residentContent = _buildResidentDashboard(
        context,
        ticketPreview: ticketPreview,
        announcementPreview: announcementPreview,
      );
      if (onRefresh != null) {
        residentContent = RefreshIndicator(
          onRefresh: () async => onRefresh!(),
          child: residentContent,
        );
      }
      return residentContent;
    }

    Widget content = _PremiumDashboardScroll(
      role: role,
      metrics: metrics,
      shortcuts: shortcuts,
      ticketPreview: ticketPreview,
      announcementPreview: announcementPreview,
      vendor: vendor,
      societyInfo: societyInfo,
      billCollectionSummary: billCollectionSummary,
      isLoading: isLoading,
      onShortcutSelected: onShortcutSelected,
    );

    if (onRefresh != null) {
      content = RefreshIndicator(
        onRefresh: () async => onRefresh!(),
        child: content,
      );
    }

    return content;
  }

  String get _mobileBannerAudience {
    if (role == AppRole.societyManager) {
      return 'society_manager';
    }
    if (role == AppRole.propertyManager) {
      return 'property_manager';
    }
    return 'tenant';
  }

  Widget _buildResidentDashboard(
    BuildContext context, {
    required List<TicketRecord> ticketPreview,
    required List<AnnouncementRecord> announcementPreview,
  }) {
    final ThemeData theme = Theme.of(context);
    final DateTime now = DateTime.now();
    final String greeting = _timeGreeting(now.hour);
    final String dateLabel =
        '${_weekday(now.weekday)}, ${now.day} ${_monthShort(now.month)}';

    // Personalized name from vendor
    final String rawName = (vendor?.fullName ?? '').trim();
    final String firstName = rawName.isNotEmpty ? rawName.split(' ').first : '';
    final String greetingText = firstName.isNotEmpty
        ? '$greeting, $firstName'
        : greeting;

    // Bill urgency analysis
    final List<BillRecord> overdueBills =
        bills.where((BillRecord b) => b.status == BillStatus.overdue).toList()
          ..sort(
            (BillRecord a, BillRecord b) => a.dueDate.compareTo(b.dueDate),
          );

    final List<BillRecord> pendingBills =
        bills.where((BillRecord b) => b.status == BillStatus.pending).toList()
          ..sort(
            (BillRecord a, BillRecord b) => a.dueDate.compareTo(b.dueDate),
          );

    final List<BillRecord> dueSoon = pendingBills
        .where((BillRecord b) => b.dueDate.difference(now).inDays <= 7)
        .toList();

    final double totalDue = <BillRecord>[
      ...overdueBills,
      ...pendingBills,
    ].fold<double>(0, (double sum, BillRecord b) => sum + b.amount);

    final bool allClear =
        !isLoading &&
        bills.isNotEmpty &&
        overdueBills.isEmpty &&
        pendingBills.isEmpty;

    // Active tickets only, sorted urgent → high → medium → low
    final List<TicketRecord> activeTickets =
        tickets
            .where(
              (TicketRecord t) =>
                  t.status == TicketStatus.open ||
                  t.status == TicketStatus.inProgress,
            )
            .toList()
          ..sort(
            (TicketRecord a, TicketRecord b) =>
                b.priority.index.compareTo(a.priority.index),
          );

    // Announcements: unread first, then by date
    final List<AnnouncementRecord> sortedAnnouncements =
        <AnnouncementRecord>[...announcements]
          ..sort((AnnouncementRecord a, AnnouncementRecord b) {
            if (a.unread && !b.unread) return -1;
            if (!a.unread && b.unread) return 1;
            return b.createdAt.compareTo(a.createdAt);
          });
    final List<AnnouncementRecord> noticeSlice = sortedAnnouncements
        .take(2)
        .toList();
    final int unreadCount = announcements
        .where((AnnouncementRecord a) => a.unread)
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 124),
      children: <Widget>[
        // ── Greeting row ────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    greetingText,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    role.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                dateLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        MobileBannerCarousel(audience: _mobileBannerAudience),
        const SizedBox(height: 18),

        // ── Bill status banner ───────────────────────────────────
        if (isLoading)
          _buildLoadingBanner(theme)
        else if (overdueBills.isNotEmpty)
          _buildBillBanner(
            context,
            theme: theme,
            icon: Icons.error_outline_rounded,
            bgColor: const Color(0xFFFEF2F2),
            accentColor: const Color(0xFFDC2626),
            title: overdueBills.length == 1
                ? 'Payment Overdue'
                : '${overdueBills.length} Bills Overdue',
            subtitle: overdueBills.length == 1
                ? overdueBills.first.title
                : 'Total outstanding amount',
            amount: _fmt(totalDue),
            detail: overdueBills.length == 1
                ? 'Since ${formatCompactDate(overdueBills.first.dueDate)}'
                : '${overdueBills.length} unpaid bills need attention',
            actionLabel: 'Settle Now',
          )
        else if (dueSoon.isNotEmpty)
          _buildBillBanner(
            context,
            theme: theme,
            icon: Icons.schedule_rounded,
            bgColor: const Color(0xFFFEFCE8),
            accentColor: const Color(0xFFD97706),
            title: dueSoon.first.dueDate.difference(now).inDays == 0
                ? 'Due Today'
                : 'Due in ${dueSoon.first.dueDate.difference(now).inDays} Days',
            subtitle: dueSoon.first.title,
            amount: _fmt(dueSoon.first.amount),
            detail: 'On ${formatCompactDate(dueSoon.first.dueDate)}',
            actionLabel: 'Pay Now',
          )
        else if (pendingBills.isNotEmpty)
          _buildBillBanner(
            context,
            theme: theme,
            icon: Icons.receipt_long_outlined,
            bgColor: AppTheme.primarySoft,
            accentColor: AppTheme.primary,
            title:
                '${pendingBills.length} Bill${pendingBills.length > 1 ? 's' : ''} Pending',
            subtitle: pendingBills.first.title,
            amount: _fmt(totalDue),
            detail: 'Due ${formatCompactDate(pendingBills.first.dueDate)}',
            actionLabel: 'View Bills',
          )
        else if (allClear)
          _buildAllClearRow(theme)
        else
          const SizedBox.shrink(),

        const SizedBox(height: 18),

        // ── Metrics row ──────────────────────────────────────────
        if (metrics.isNotEmpty) ...<Widget>[
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: metrics.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (BuildContext ctx, int index) {
                final DashboardMetric metric = metrics[index];
                final Color accent = AppTheme.toneColor(metric.tone);
                return Container(
                  width: 148,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border(left: BorderSide(color: accent, width: 3)),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        metric.value,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        metric.title,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Quick actions ────────────────────────────────────────
        Text(
          'Quick actions',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: shortcuts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (BuildContext ctx, int index) {
              final AppShortcut shortcut = shortcuts[index];
              return GestureDetector(
                onTap: () => onShortcutSelected(shortcut.actionKey),
                child: SizedBox(
                  width: 72,
                  child: Column(
                    children: <Widget>[
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppTheme.primarySoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          shortcut.icon,
                          color: AppTheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        shortcut.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 22),

        // ── Active issues ────────────────────────────────────────
        _ResidentSectionHeader(
          title: 'Active Issues',
          count: activeTickets.length,
          onViewAll: activeTickets.length > 2
              ? () => onShortcutSelected('support')
              : null,
        ),
        const SizedBox(height: 10),
        if (activeTickets.isEmpty)
          const _ResidentEmptyRow(
            icon: Icons.check_circle_outline_rounded,
            message: 'No open issues right now',
            color: Color(0xFF16A34A),
          )
        else
          ...activeTickets.take(2).map((TicketRecord ticket) {
            final Color priorityColor = AppTheme.toneColor(
              ticket.priority.tone,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    left: BorderSide(color: priorityColor, width: 3),
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            ticket.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ToneBadge(
                          label: ticket.status.label,
                          tone: ticket.status.tone,
                          size: ToneBadgeSize.small,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ticket.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        ToneBadge(
                          label: ticket.priority.label,
                          tone: ticket.priority.tone,
                          size: ToneBadgeSize.small,
                        ),
                        const SizedBox(width: 6),
                        ToneBadge(
                          label: ticket.category,
                          tone: UiTone.neutral,
                          size: ToneBadgeSize.small,
                        ),
                        const Spacer(),
                        Text(
                          formatCompactDate(ticket.updatedAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 16),

        // ── Notices ──────────────────────────────────────────────
        _ResidentSectionHeader(
          title: 'Notices',
          badgeLabel: unreadCount > 0 ? '$unreadCount unread' : null,
          onViewAll: sortedAnnouncements.length > 2
              ? () => onShortcutSelected('communication')
              : null,
        ),
        const SizedBox(height: 10),
        if (noticeSlice.isEmpty)
          const _ResidentEmptyRow(
            icon: Icons.notifications_none_rounded,
            message: 'No new announcements',
            color: AppTheme.textMuted,
          )
        else
          ...noticeSlice.map((AnnouncementRecord announcement) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: announcement.unread
                        ? AppTheme.primaryTone
                        : AppTheme.border,
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: announcement.unread
                            ? AppTheme.primarySoft
                            : AppTheme.surfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        announcement.category.icon,
                        size: 18,
                        color: announcement.unread
                            ? AppTheme.primary
                            : AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  announcement.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (announcement.unread)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(left: 6),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            announcement.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: <Widget>[
                              ToneBadge(
                                label: announcement.priorityLabel,
                                tone: announcement.unread
                                    ? UiTone.brand
                                    : UiTone.neutral,
                                size: ToneBadgeSize.small,
                              ),
                              const Spacer(),
                              Text(
                                formatCompactDate(announcement.createdAt),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildBillBanner(
    BuildContext context, {
    required ThemeData theme,
    required IconData icon,
    required Color bgColor,
    required Color accentColor,
    required String title,
    required String subtitle,
    required String amount,
    required String detail,
    required String actionLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                amount,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Text(
                detail,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.textMuted,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => onShortcutSelected('billing'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    actionLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllClearRow(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Color(0xFF16A34A), width: 4),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF16A34A),
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            'All bills settled',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF15803D),
            ),
          ),
          const Spacer(),
          Text(
            'Great job!',
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF16A34A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingBanner(ThemeData theme) {
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: const Border(
          left: BorderSide(color: AppTheme.border, width: 4),
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  static String _timeGreeting(int hour) {
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String _weekday(int day) {
    const List<String> days = <String>[
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    return days[day - 1];
  }

  static String _monthShort(int month) {
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  String _fmt(double value) {
    if (value >= 100000) {
      return 'Rs ${(value / 100000).toStringAsFixed(1)}L';
    }
    if (value >= 1000) {
      return 'Rs ${(value / 1000).toStringAsFixed(1)}K';
    }
    return 'Rs ${value.toStringAsFixed(0)}';
  }

  int _residentSlotExpiryUrgency(String? value) {
    final DateTime? expiry = DateTime.tryParse(value?.trim() ?? '');
    if (expiry == null) {
      return 0;
    }

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime localExpiry = expiry.toLocal();
    final DateTime expiryDate = DateTime(
      localExpiry.year,
      localExpiry.month,
      localExpiry.day,
    );
    final int daysUntilExpiry = expiryDate.difference(today).inDays;

    if (daysUntilExpiry <= 2) {
      return 2;
    }
    if (daysUntilExpiry <= 5) {
      return 1;
    }
    return 0;
  }

  UiTone _residentSlotExpiryTone(int urgency) {
    return switch (urgency) {
      2 => UiTone.danger,
      1 => UiTone.warning,
      _ => UiTone.neutral,
    };
  }

  CustomButtonVariant _residentRenewButtonVariant(int urgency) {
    return switch (urgency) {
      2 => CustomButtonVariant.danger,
      1 => CustomButtonVariant.secondary,
      _ => CustomButtonVariant.outline,
    };
  }

  // ignore: unused_element
  List<Widget> _buildRoleSections(BuildContext context) {
    if (role.isSocietyScope) {
      return _buildSocietySections(context);
    }
    if (role == AppRole.propertyManager) {
      return _buildPropertySections(context);
    }
    return <Widget>[];
  }

  List<Widget> _buildSocietySections(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SocietyData? society = societyInfo;
    final bool hasSociety =
        (society?.societyId ?? vendor?.societyId ?? '').isNotEmpty;
    final int residentSlotExpiryUrgency = _residentSlotExpiryUrgency(
      society?.purchasedResidentsExpiryDate,
    );

    if (!hasSociety) {
      return <Widget>[
        _SectionHeader(
          title: 'Society Setup',
          actionLabel: 'Create Society',
          onAction: () => onShortcutSelected('society_management'),
        ),
        CustomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'No society profile found',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The website opens the create-society flow from the dashboard when setup is missing. Use the same mobile action here to start with profile, billing rules, blocks, and buildings.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  CustomButton(
                    label: 'Create Society',
                    icon: const Icon(Icons.add_business_outlined),
                    onPressed: () => onShortcutSelected('society_management'),
                  ),
                  CustomButton(
                    label: 'Residents',
                    variant: CustomButtonVariant.outline,
                    icon: const Icon(Icons.groups_outlined),
                    onPressed: () => onShortcutSelected('residents'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ];
    }

    final WalletSummaryData? walletInfo =
        society?.walletInfo ?? vendor?.walletInfo;
    final BillCollectionSummaryData? billSummary =
        vendor?.billCollectionSummary;
    final SupportTicketSummaryData? supportSummary =
        vendor?.supportTicketSummary;
    final SocietyMaintenanceRates rates =
        society?.maintenanceRates ?? const SocietyMaintenanceRates();
    final SocietyBillingConfig billingConfig =
        society?.billingConfig ?? const SocietyBillingConfig();

    final List<DashboardMetric> setupMetrics = <DashboardMetric>[
      DashboardMetric(
        title: 'Blocks',
        value: '$blockCount',
        subtitle: 'Society structure configured',
        tone: UiTone.brand,
      ),
      DashboardMetric(
        title: 'Buildings',
        value: '$buildingCount',
        subtitle: 'Mapped under current blocks',
        tone: UiTone.neutral,
      ),
      DashboardMetric(
        title: 'Residents',
        value: '${society?.totalResidents ?? 0}',
        subtitle: '${society?.activeResidents ?? 0} active profiles',
        tone: UiTone.success,
      ),
      DashboardMetric(
        title: 'Available Slots',
        value: '${society?.availableResidentsCreationCount ?? 0}',
        subtitle: '${society?.usedResidentsCreationCount ?? 0} slots used',
        tone: UiTone.warning,
      ),
    ];

    final List<DashboardMetric> billingMetrics = <DashboardMetric>[
      DashboardMetric(
        title: 'Total Pending',
        value: _formatCurrencyCompact(billSummary?.totalPendingAmount ?? 0.0),
        subtitle: 'All unpaid maintenance bills',
        tone: UiTone.warning,
      ),
      DashboardMetric(
        title: 'Total Collected',
        value: _formatCurrencyCompact(billSummary?.totalCollectedAmount ?? 0.0),
        subtitle: 'All collected maintenance bills',
        tone: UiTone.success,
      ),
      DashboardMetric(
        title: 'Total Overdue',
        value: _formatCurrencyCompact(billSummary?.totalOverdueAmount ?? 0.0),
        subtitle: 'Bills past due date',
        tone: UiTone.danger,
      ),
      DashboardMetric(
        title: 'Today',
        value: _formatCurrencyCompact(billSummary?.todaysCollection ?? 0.0),
        subtitle: 'Collection received today',
        tone: UiTone.brand,
      ),
      DashboardMetric(
        title: 'Month Collection',
        value: _formatCurrencyCompact(
          billSummary?.currentMonthCollected ?? 0.0,
        ),
        subtitle: 'Current month collected',
        tone: UiTone.success,
      ),
      DashboardMetric(
        title: 'Month Overdue',
        value: _formatCurrencyCompact(billSummary?.currentMonthOverdue ?? 0.0),
        subtitle: 'Current month overdue',
        tone: UiTone.danger,
      ),
      DashboardMetric(
        title: 'Month Pending',
        value: _formatCurrencyCompact(billSummary?.currentMonthPending ?? 0.0),
        subtitle: 'Current month outstanding',
        tone: UiTone.warning,
      ),
    ];

    final List<DashboardMetric> walletMetrics = <DashboardMetric>[
      DashboardMetric(
        title: 'Available',
        value: _formatCurrencyCompact(walletInfo?.availableAmount ?? 0.0),
        subtitle: 'Available for withdrawal',
        tone: UiTone.brand,
      ),
      DashboardMetric(
        title: 'Credited',
        value: _formatCurrencyCompact(walletInfo?.creditedAmount ?? 0.0),
        subtitle: 'Total credited to wallet',
        tone: UiTone.success,
      ),
      DashboardMetric(
        title: 'Debited',
        value: _formatCurrencyCompact(walletInfo?.debitedAmount ?? 0.0),
        subtitle: 'Total debited from wallet',
        tone: UiTone.danger,
      ),
    ];

    final List<DashboardMetric> supportMetrics = <DashboardMetric>[
      DashboardMetric(
        title: 'Open',
        value: '${supportSummary?.openTicketsCount ?? 0}',
        subtitle: 'Tickets awaiting action',
        tone: UiTone.warning,
      ),
      DashboardMetric(
        title: 'In Progress',
        value: '${supportSummary?.inProgressTicketsCount ?? 0}',
        subtitle: 'Currently being handled',
        tone: UiTone.brand,
      ),
      DashboardMetric(
        title: 'Resolved',
        value: '${supportSummary?.resolvedTicketsCount ?? 0}',
        subtitle: 'Closed support tickets',
        tone: UiTone.success,
      ),
      DashboardMetric(
        title: 'Critical',
        value: '${supportSummary?.criticalOpenTicketsCount ?? 0}',
        subtitle: 'Critical open tickets',
        tone: UiTone.danger,
      ),
    ];

    final List<String> maintenanceBadges = <String>[
      '1 BHK ${_formatCurrencyCompact(rates.oneBhk)}',
      '2 BHK ${_formatCurrencyCompact(rates.twoBhk)}',
      '3 BHK ${_formatCurrencyCompact(rates.threeBhk)}',
      '4 BHK ${_formatCurrencyCompact(rates.fourBhk)}',
      'Villa ${_formatCurrencyCompact(rates.villa)}',
    ];
    final double totalMonthlyCollection =
        rates.oneBhk +
        rates.twoBhk +
        rates.threeBhk +
        rates.fourBhk +
        rates.villa;
    final DateTime? lastGenerated = society?.updatedAt;
    final DateTime now = DateTime.now();
    final DateTime nextDueDate = DateTime(
      now.year,
      now.month,
      billingConfig.billGenerationDate + billingConfig.paymentDueDays,
    );

    return <Widget>[
      _SectionHeader(
        title: 'Society Profile',
        actionLabel: 'Open Society',
        onAction: () => onShortcutSelected('society_management'),
      ),
      CustomCard(
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
                        society?.name ?? 'Society',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        society?.locationAddress?.isNotEmpty == true
                            ? society!.locationAddress!
                            : society?.address ?? '',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                ToneBadge(
                  label: society?.isActive == false ? 'Inactive' : 'Active',
                  tone: society?.isActive == false
                      ? UiTone.warning
                      : UiTone.success,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if ((society?.phone ?? '').isNotEmpty)
              _DetailLine(label: 'Phone', value: society!.phone!),
            if ((society?.email ?? '').isNotEmpty)
              _DetailLine(label: 'Email', value: society!.email!),
            if ((society?.estYear ?? '').isNotEmpty)
              _DetailLine(label: 'Established', value: society!.estYear!),
            _DetailLine(
              label: 'Billing rule',
              value:
                  'Generate on day ${billingConfig.billGenerationDate} | Due in ${billingConfig.paymentDueDays} days',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                CustomButton(
                  label: 'Manage Society',
                  icon: const Icon(Icons.apartment_outlined),
                  onPressed: () => onShortcutSelected('society_management'),
                ),
                CustomButton(
                  label: 'Residents',
                  variant: CustomButtonVariant.outline,
                  icon: const Icon(Icons.groups_outlined),
                  onPressed: () => onShortcutSelected('residents'),
                ),
                CustomButton(
                  label: 'Security',
                  variant: CustomButtonVariant.outline,
                  icon: const Icon(Icons.shield_outlined),
                  onPressed: () => onShortcutSelected('security'),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _SectionHeader(
        title: 'Society Statistics',
        actionLabel: 'Residents',
        onAction: () => onShortcutSelected('residents'),
      ),
      _metricGrid(setupMetrics),
      const SizedBox(height: 12),
      CustomCard(
        color: AppTheme.primarySoft,
        borderColor: AppTheme.primaryTone,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Purchased Residents Expiry',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              (society?.purchasedResidentsExpiryDate ?? '').isNotEmpty
                  ? 'Purchased resident capacity is valid until ${society!.purchasedResidentsExpiryDate!}. Renew before expiry to avoid onboarding interruptions.'
                  : 'Use Residents to purchase or renew slots and continue onboarding after society, block, and building setup.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ToneBadge(
                  label: 'Free ${society?.freeResidentsCount ?? 0}',
                  tone: UiTone.success,
                ),
                ToneBadge(
                  label: 'Purchased ${society?.purchasedResidentsCount ?? 0}',
                  tone: UiTone.brand,
                ),
                ToneBadge(
                  label:
                      'Available ${society?.availableResidentsCreationCount ?? 0}',
                  tone: UiTone.success,
                ),
                ToneBadge(
                  label: 'Used ${society?.usedResidentsCreationCount ?? 0}',
                  tone: UiTone.warning,
                ),
                if ((society?.purchasedResidentsExpiryDate ?? '').isNotEmpty)
                  ToneBadge(
                    label: 'Expiry ${society!.purchasedResidentsExpiryDate!}',
                    tone: _residentSlotExpiryTone(residentSlotExpiryUrgency),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                CustomButton(
                  label: 'Manage Residents',
                  icon: const Icon(Icons.manage_accounts_outlined),
                  onPressed: () => onShortcutSelected('residents'),
                ),
                CustomButton(
                  label: 'Renew',
                  variant: _residentRenewButtonVariant(
                    residentSlotExpiryUrgency,
                  ),
                  icon: const Icon(Icons.autorenew_outlined),
                  onPressed: () => onShortcutSelected('residents'),
                ),
                CustomButton(
                  label: 'Wallet',
                  variant: CustomButtonVariant.outline,
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  onPressed: () => onShortcutSelected('bank_details'),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _SectionHeader(
        title: 'Billing Overview',
        actionLabel: 'Billing',
        onAction: () => onShortcutSelected('billing'),
      ),
      _metricGrid(billingMetrics),
      const SizedBox(height: 12),
      _SectionHeader(
        title: 'Wallet Overview',
        actionLabel: 'Wallet',
        onAction: () => onShortcutSelected('bank_details'),
      ),
      _metricGrid(walletMetrics),
      const SizedBox(height: 12),
      _SectionHeader(
        title: 'Support Tickets',
        actionLabel: 'Support',
        onAction: () => onShortcutSelected('support'),
      ),
      _metricGrid(supportMetrics),
      const SizedBox(height: 12),
      _SectionHeader(
        title: 'Monthly Maintenance Rates',
        actionLabel: 'Society',
        onAction: () => onShortcutSelected('society_management'),
      ),
      CustomCard(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: maintenanceBadges
              .map(
                (String label) => ToneBadge(label: label, tone: UiTone.neutral),
              )
              .toList(),
        ),
      ),
      const SizedBox(height: 12),
      _SectionHeader(
        title: 'Billing Information',
        actionLabel: 'Society',
        onAction: () => onShortcutSelected('society_management'),
      ),
      CustomCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Billing Information',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _DetailLine(
              label: 'Bill generation',
              value: 'Day ${billingConfig.billGenerationDate} of every month',
            ),
            _DetailLine(
              label: 'Payment due',
              value: '${billingConfig.paymentDueDays} days after generation',
            ),
            _DetailLine(
              label: 'Last generated',
              value: lastGenerated == null
                  ? 'Not available'
                  : formatCompactDate(lastGenerated),
            ),
            _DetailLine(
              label: 'Next due date',
              value: formatCompactDate(nextDueDate),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.toneSoft(UiTone.warning),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.toneContainer(UiTone.warning),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Total Monthly Collection',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppTheme.toneColor(UiTone.warning),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatCurrencyCompact(totalMonthlyCollection),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppTheme.toneColor(UiTone.warning),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Expected monthly maintenance collection by unit type.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      CustomCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Amenities',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Default society amenities shown on the website dashboard.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _defaultAmenities.map((_DefaultAmenity amenity) {
                return _AmenityChip(amenity: amenity);
              }).toList(),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildPropertySections(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final PropertySummaryData? propertySummary = vendor?.propertySummary;
    final RentalContractSummaryData? contractSummary =
        vendor?.rentalContractSummary;
    final BillCollectionSummaryData? billSummary =
        vendor?.billCollectionSummary;
    final SupportTicketSummaryData? supportSummary =
        vendor?.supportTicketSummary;
    final WalletSummaryData? walletInfo = vendor?.walletInfo;
    final String currentMonthLabel = _monthShort(DateTime.now().month);
    final int propertyEnquiryCount =
        propertyEnquiryCountOverride ?? propertySummary?.newEnquiriesCount ?? 0;

    final List<DashboardMetric> propertyMetrics = <DashboardMetric>[
      DashboardMetric(
        title: 'Total Properties',
        value: '${propertySummary?.totalPropertiesCount ?? 0}',
        subtitle: 'Managed inventory',
        tone: UiTone.brand,
      ),
      DashboardMetric(
        title: 'Approved',
        value: '${propertySummary?.approvedPropertiesCount ?? 0}',
        subtitle: 'Live listings ready',
        tone: UiTone.success,
      ),
      DashboardMetric(
        title: 'Pending',
        value: '${propertySummary?.pendingPropertiesCount ?? 0}',
        subtitle: 'Awaiting approval',
        tone: UiTone.warning,
      ),
      DashboardMetric(
        title: 'Rejected',
        value: '${propertySummary?.rejectedPropertiesCount ?? 0}',
        subtitle: 'Needs correction',
        tone: UiTone.danger,
      ),
    ];

    final List<DashboardMetric> contractMetrics = <DashboardMetric>[
      DashboardMetric(
        title: 'Active Contracts',
        value: '${contractSummary?.activeContractsCount ?? 0}',
        subtitle: 'Current agreements',
        tone: UiTone.success,
      ),
      DashboardMetric(
        title: 'Pending Renewal',
        value: '${contractSummary?.pendingRenewalCount ?? 0}',
        subtitle: 'Needs follow-up soon',
        tone: UiTone.warning,
      ),
      DashboardMetric(
        title: 'Expired',
        value: '${contractSummary?.expiredContractsCount ?? 0}',
        subtitle: 'Closed or lapsed',
        tone: UiTone.neutral,
      ),
      DashboardMetric(
        title: 'Monthly Rent',
        value: _formatCurrencyCompact(contractSummary?.totalMonthlyRent ?? 0.0),
        subtitle: 'Active rent value',
        tone: UiTone.brand,
      ),
    ];

    final List<DashboardMetric> billingMetrics = <DashboardMetric>[
      DashboardMetric(
        title: 'Total Pending',
        value: _formatCurrencyCompact(billSummary?.totalPendingAmount ?? 0.0),
        subtitle: 'All pending rental bills',
        tone: UiTone.warning,
      ),
      DashboardMetric(
        title: 'Total Collected',
        value: _formatCurrencyCompact(billSummary?.totalCollectedAmount ?? 0.0),
        subtitle: 'All collected rental bills',
        tone: UiTone.success,
      ),
      DashboardMetric(
        title: 'Total Overdue',
        value: _formatCurrencyCompact(billSummary?.totalOverdueAmount ?? 0.0),
        subtitle: 'Bills past due date',
        tone: UiTone.danger,
      ),
      DashboardMetric(
        title: 'Today',
        value: _formatCurrencyCompact(billSummary?.todaysCollection ?? 0.0),
        subtitle: 'Collection received today',
        tone: UiTone.brand,
      ),
      DashboardMetric(
        title: '$currentMonthLabel Collection',
        value: _formatCurrencyCompact(
          billSummary?.currentMonthCollected ?? 0.0,
        ),
        subtitle: 'Current month collected',
        tone: UiTone.success,
      ),
      DashboardMetric(
        title: '$currentMonthLabel Overdue',
        value: _formatCurrencyCompact(billSummary?.currentMonthOverdue ?? 0.0),
        subtitle: 'Current month overdue',
        tone: UiTone.danger,
      ),
      DashboardMetric(
        title: '$currentMonthLabel Pending',
        value: _formatCurrencyCompact(billSummary?.currentMonthPending ?? 0.0),
        subtitle: 'Current month pending',
        tone: UiTone.warning,
      ),
      DashboardMetric(
        title: 'Total Security Bill',
        value: _formatCurrencyCompact(
          billSummary?.totalSecurityBillAmount ?? 0.0,
        ),
        subtitle: 'Security deposit bill value',
        tone: UiTone.neutral,
      ),
      DashboardMetric(
        title: 'Pending Security',
        value: _formatCurrencyCompact(
          billSummary?.pendingSecurityAmount ?? 0.0,
        ),
        subtitle: 'Security deposit outstanding',
        tone: UiTone.warning,
      ),
      DashboardMetric(
        title: 'Collected Security',
        value: _formatCurrencyCompact(
          billSummary?.collectedSecurityAmount ?? 0.0,
        ),
        subtitle: 'Security deposit collected',
        tone: UiTone.success,
      ),
    ];

    final List<DashboardMetric> supportMetrics = <DashboardMetric>[
      DashboardMetric(
        title: 'Open',
        value: '${supportSummary?.openTicketsCount ?? 0}',
        subtitle: 'Tickets awaiting action',
        tone: UiTone.warning,
      ),
      DashboardMetric(
        title: 'In Progress',
        value: '${supportSummary?.inProgressTicketsCount ?? 0}',
        subtitle: 'Currently being handled',
        tone: UiTone.brand,
      ),
      DashboardMetric(
        title: 'Resolved',
        value: '${supportSummary?.resolvedTicketsCount ?? 0}',
        subtitle: 'Closed property tickets',
        tone: UiTone.success,
      ),
      DashboardMetric(
        title: 'Critical',
        value: '${supportSummary?.criticalOpenTicketsCount ?? 0}',
        subtitle: 'Critical open tickets',
        tone: UiTone.danger,
      ),
    ];

    final List<DashboardMetric> walletMetrics = <DashboardMetric>[
      DashboardMetric(
        title: 'Available',
        value: _formatCurrencyCompact(walletInfo?.availableAmount ?? 0.0),
        subtitle: 'Available for withdrawal',
        tone: UiTone.brand,
      ),
      DashboardMetric(
        title: 'Credited',
        value: _formatCurrencyCompact(walletInfo?.creditedAmount ?? 0.0),
        subtitle: 'Total credited to wallet',
        tone: UiTone.success,
      ),
      DashboardMetric(
        title: 'Debited',
        value: _formatCurrencyCompact(walletInfo?.debitedAmount ?? 0.0),
        subtitle: 'Total debited from wallet',
        tone: UiTone.neutral,
      ),
    ];

    return <Widget>[
      _SectionHeader(
        title: 'Property Overview',
        actionLabel: 'Properties',
        onAction: () => onShortcutSelected('properties'),
      ),
      CustomCard(
        color: const Color(0xFFF9FBFF),
        borderColor: const Color(0xFFD8E5FF),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFD8E5FF)),
                        ),
                        child: Text(
                          'Property Manager Console',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.primaryHover,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        (vendor?.fullName ?? '').isNotEmpty
                            ? vendor!.fullName
                            : 'Property Manager',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Inventory, contracts, billing, support, and wallet shortcuts are grouped here so the mobile view feels closer to the website control room.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD8E5FF)),
                  ),
                  child: const Icon(
                    Icons.dashboard_customize_rounded,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ToneBadge(
                  label:
                      '${propertySummary?.totalPropertiesCount ?? 0} properties',
                  tone: UiTone.brand,
                ),
                ToneBadge(
                  label:
                      '${contractSummary?.activeContractsCount ?? 0} active contracts',
                  tone: UiTone.success,
                ),
                ToneBadge(
                  label:
                      '${supportSummary?.openTicketsCount ?? 0} open tickets',
                  tone: UiTone.warning,
                ),
                if (propertyEnquiryCount > 0)
                  ToneBadge(
                    label: '$propertyEnquiryCount new enquiries',
                    tone: UiTone.warning,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if ((vendor?.email ?? '').isNotEmpty)
              _DetailLine(label: 'Email', value: vendor!.email),
            if ((vendor?.phone ?? '').isNotEmpty)
              _DetailLine(label: 'Phone', value: vendor!.phone),
            if ((vendor?.propertyId ?? '').isNotEmpty)
              _DetailLine(label: 'Property scope', value: vendor!.propertyId!),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                CustomButton(
                  label: 'Properties',
                  icon: const Icon(Icons.apartment_outlined),
                  onPressed: () => onShortcutSelected('properties'),
                ),
                CustomButton(
                  label: propertyEnquiryCount > 0
                      ? 'Enquiries - $propertyEnquiryCount'
                      : 'Enquiries',
                  variant: CustomButtonVariant.outline,
                  icon: const Icon(Icons.manage_search_outlined),
                  onPressed: () => onShortcutSelected('enquiries'),
                ),
                CustomButton(
                  label: 'Contracts',
                  variant: CustomButtonVariant.outline,
                  icon: const Icon(Icons.description_outlined),
                  onPressed: () => onShortcutSelected('rental_contracts'),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _metricGrid(propertyMetrics),
      const SizedBox(height: 12),
      _SectionHeader(
        title: 'Rental Contracts',
        actionLabel: 'Contracts',
        onAction: () => onShortcutSelected('rental_contracts'),
      ),
      _metricGrid(contractMetrics),
      const SizedBox(height: 12),
      _SectionHeader(
        title: 'Billing Overview',
        actionLabel: 'Rental Bills',
        onAction: () => onShortcutSelected('rental_bills'),
      ),
      _metricGrid(billingMetrics),
      const SizedBox(height: 12),
      _SectionHeader(
        title: 'Support Tickets',
        actionLabel: 'Support',
        onAction: () => onShortcutSelected('support'),
      ),
      _metricGrid(supportMetrics),
      const SizedBox(height: 12),
      _SectionHeader(
        title: 'Wallet Overview',
        actionLabel: 'Bank Details',
        onAction: () => onShortcutSelected('bank_details'),
      ),
      _metricGrid(walletMetrics),
      const SizedBox(height: 12),
      CustomCard(
        color: AppTheme.primarySoft,
        borderColor: AppTheme.primaryTone,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Operations Actions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Use billing, support, and bank details directly from the summary numbers, matching the website flow.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                CustomButton(
                  label: 'Rental Bills',
                  icon: const Icon(Icons.receipt_long_outlined),
                  onPressed: () => onShortcutSelected('rental_bills'),
                ),
                CustomButton(
                  label: 'Wallet',
                  variant: CustomButtonVariant.outline,
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  onPressed: () => onShortcutSelected('bank_details'),
                ),
                CustomButton(
                  label: 'Support',
                  variant: CustomButtonVariant.outline,
                  icon: const Icon(Icons.support_agent_outlined),
                  onPressed: () => onShortcutSelected('support'),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  Widget _metricGrid(List<DashboardMetric> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.28,
      ),
      itemBuilder: (BuildContext context, int index) {
        final DashboardMetric metric = items[index];
        return _MetricCard(metric: metric);
      },
    );
  }

  String _formatCurrencyCompact(double value) {
    if (value >= 10000000) {
      return 'Rs ${(value / 10000000).toStringAsFixed(2)} Cr';
    }
    if (value >= 100000) {
      return 'Rs ${(value / 100000).toStringAsFixed(2)} L';
    }
    if (value >= 1000) {
      return 'Rs ${(value / 1000).toStringAsFixed(1)} K';
    }
    return 'Rs ${value.toStringAsFixed(0)}';
  }
}

class _PremiumDashboardScroll extends StatelessWidget {
  const _PremiumDashboardScroll({
    required this.role,
    required this.metrics,
    required this.shortcuts,
    required this.ticketPreview,
    required this.announcementPreview,
    required this.vendor,
    required this.societyInfo,
    required this.billCollectionSummary,
    required this.isLoading,
    required this.onShortcutSelected,
  });

  final AppRole role;
  final List<DashboardMetric> metrics;
  final List<AppShortcut> shortcuts;
  final List<TicketRecord> ticketPreview;
  final List<AnnouncementRecord> announcementPreview;
  final VendorData? vendor;
  final SocietyData? societyInfo;
  final BillCollectionSummaryData? billCollectionSummary;
  final bool isLoading;
  final ValueChanged<String> onShortcutSelected;

  @override
  Widget build(BuildContext context) {
    final List<DashboardMetric> visibleMetrics = metrics.take(4).toList();
    final List<AppShortcut> visibleShortcuts = shortcuts.take(6).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 124),
      children: <Widget>[
        _PremiumHeroCard(
          role: role,
          vendor: vendor,
          societyInfo: societyInfo,
          metrics: visibleMetrics,
          onShortcutSelected: onShortcutSelected,
        ),
        const SizedBox(height: 18),
        MobileBannerCarousel(audience: _mobileBannerAudience),
        if (isLoading) ...<Widget>[
          const SizedBox(height: 14),
          const _DashboardSkeleton(),
        ],
        const SizedBox(height: 18),
        _PremiumSectionHeader(
          title: 'Overview',
          actionLabel: role == AppRole.propertyManager ? 'Properties' : 'Society',
          onAction: () => onShortcutSelected(
            role == AppRole.propertyManager ? 'properties' : 'society_management',
          ),
        ),
        _PremiumMetricGrid(metrics: visibleMetrics),
        const SizedBox(height: 20),
        _RevenueAnalyticsCard(
          metrics: visibleMetrics,
          summary: billCollectionSummary,
        ),
        const SizedBox(height: 20),
        _PremiumSectionHeader(title: 'Quick actions'),
        _QuickActionGrid(
          shortcuts: visibleShortcuts,
          onShortcutSelected: onShortcutSelected,
        ),
        const SizedBox(height: 20),
        _PremiumSectionHeader(title: 'Recent activity'),
        if (ticketPreview.isEmpty && announcementPreview.isEmpty)
          const _EmptyActivityCard()
        else ...<Widget>[
          ...ticketPreview.map(
            (TicketRecord ticket) => _ActivityTile.ticket(ticket: ticket),
          ),
          ...announcementPreview.map(
            (AnnouncementRecord announcement) =>
                _ActivityTile.announcement(announcement: announcement),
          ),
        ],
      ],
    );
  }

  String get _mobileBannerAudience {
    if (role == AppRole.societyManager) {
      return 'society_manager';
    }
    if (role == AppRole.propertyManager) {
      return 'property_manager';
    }
    return 'tenant';
  }
}

class _PremiumHeroCard extends StatelessWidget {
  const _PremiumHeroCard({
    required this.role,
    required this.vendor,
    required this.societyInfo,
    required this.metrics,
    required this.onShortcutSelected,
  });

  final AppRole role;
  final VendorData? vendor;
  final SocietyData? societyInfo;
  final List<DashboardMetric> metrics;
  final ValueChanged<String> onShortcutSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String rawName = (vendor?.fullName ?? societyInfo?.name ?? '').trim();
    final String title = rawName.isEmpty ? 'Premium command center' : rawName;
    final DashboardMetric? primaryMetric =
        metrics.isNotEmpty ? metrics.first : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x10121A26),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(role.icon, color: AppTheme.primary),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  role.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w900,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            role.homeHeadline,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _HeroStatPill(
                  label: primaryMetric?.title ?? 'Portfolio health',
                  value: primaryMetric?.value ?? 'Live',
                ),
              ),
              const SizedBox(width: 10),
              _HeroIconAction(
                icon: Icons.add_home_work_outlined,
                onTap: () => onShortcutSelected(
                  role == AppRole.propertyManager ? 'properties' : 'residents',
                ),
              ),
              const SizedBox(width: 10),
              _HeroIconAction(
                icon: Icons.receipt_long_outlined,
                onTap: () => onShortcutSelected('billing'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStatPill extends StatelessWidget {
  const _HeroStatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppTheme.secondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
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

class _HeroIconAction extends StatelessWidget {
  const _HeroIconAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primary,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _PremiumMetricGrid extends StatelessWidget {
  const _PremiumMetricGrid({required this.metrics});

  final List<DashboardMetric> metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.18,
      ),
      itemBuilder: (BuildContext context, int index) {
        return _PremiumMetricCard(metric: metrics[index], index: index);
      },
    );
  }
}

class _PremiumMetricCard extends StatelessWidget {
  const _PremiumMetricCard({required this.metric, required this.index});

  final DashboardMetric metric;
  final int index;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = index.isEven ? AppTheme.primary : AppTheme.secondary;

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withAlpha(22),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.auto_graph_rounded, color: accent, size: 20),
          ),
          const Spacer(),
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            metric.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            metric.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textMuted,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueAnalyticsCard extends StatelessWidget {
  const _RevenueAnalyticsCard({required this.metrics, required this.summary});

  final List<DashboardMetric> metrics;
  final BillCollectionSummaryData? summary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double monthCollected = summary?.currentMonthCollected ?? 0;
    final double todayCollected = summary?.todaysCollection ?? 0;
    final double pendingAmount = summary?.totalPendingAmount ?? 0;
    final double overdueAmount = summary?.totalOverdueAmount ?? 0;
    final double totalCollected = summary?.totalCollectedAmount ?? 0;
    final double securityCollected = summary?.collectedSecurityAmount ?? 0;
    final List<double> values = <double>[
      totalCollected,
      monthCollected,
      todayCollected,
      pendingAmount,
      overdueAmount,
      securityCollected,
    ];
    final double maxValue = values.fold<double>(
      0,
      (double max, double value) => value > max ? value : max,
    );
    final String headline = _formatCurrency(monthCollected);
    final String supporting = todayCollected > 0
        ? '${_formatCurrency(todayCollected)} today'
        : '${_formatCurrency(totalCollected)} total collected';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x10121A26),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Revenue analytics',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      supporting,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                headline,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 98,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                _ChartBar(
                  heightFactor: _heightFactor(totalCollected, maxValue),
                  active: totalCollected > 0,
                ),
                _ChartBar(
                  heightFactor: _heightFactor(monthCollected, maxValue),
                  active: monthCollected > 0,
                ),
                _ChartBar(
                  heightFactor: _heightFactor(todayCollected, maxValue),
                  active: todayCollected > 0,
                ),
                _ChartBar(
                  heightFactor: _heightFactor(pendingAmount, maxValue),
                ),
                _ChartBar(
                  heightFactor: _heightFactor(overdueAmount, maxValue),
                ),
                _ChartBar(
                  heightFactor: _heightFactor(securityCollected, maxValue),
                  active: securityCollected > 0,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _RevenueMiniStat(
                  label: 'Pending',
                  value: _formatCurrency(pendingAmount),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RevenueMiniStat(
                  label: 'Overdue',
                  value: _formatCurrency(overdueAmount),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _heightFactor(double value, double maxValue) {
    if (maxValue <= 0 || value <= 0) {
      return .12;
    }
    final double normalized = value / maxValue;
    return normalized.clamp(.18, 1).toDouble();
  }

  String _formatCurrency(double value) {
    if (value >= 10000000) {
      return 'Rs ${(value / 10000000).toStringAsFixed(2)} Cr';
    }
    if (value >= 100000) {
      return 'Rs ${(value / 100000).toStringAsFixed(2)} L';
    }
    if (value >= 1000) {
      return 'Rs ${(value / 1000).toStringAsFixed(1)} K';
    }
    return 'Rs ${value.toStringAsFixed(0)}';
  }
}

class _RevenueMiniStat extends StatelessWidget {
  const _RevenueMiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartBar extends StatelessWidget {
  const _ChartBar({required this.heightFactor, this.active = false});

  final double heightFactor;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: heightFactor,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: active ? AppTheme.primary : AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({
    required this.shortcuts,
    required this.onShortcutSelected,
  });

  final List<AppShortcut> shortcuts;
  final ValueChanged<String> onShortcutSelected;

  @override
  Widget build(BuildContext context) {
    if (shortcuts.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: shortcuts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: .9,
      ),
      itemBuilder: (BuildContext context, int index) {
        final AppShortcut shortcut = shortcuts[index];
        return _QuickActionTile(
          shortcut: shortcut,
          onTap: () => onShortcutSelected(shortcut.actionKey),
        );
      },
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.shortcut, required this.onTap});

  final AppShortcut shortcut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(shortcut.icon, color: AppTheme.primary, size: 20),
              ),
              const Spacer(),
              Text(
                shortcut.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile._({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.tone,
  });

  factory _ActivityTile.ticket({required TicketRecord ticket}) {
    return _ActivityTile._(
      icon: Icons.support_agent_rounded,
      title: ticket.title,
      subtitle: ticket.description,
      meta:
          '${ticket.status.label} - ${formatCompactDate(ticket.updatedAt)} ${formatClock(ticket.updatedAt)}',
      tone: ticket.status.tone,
    );
  }

  factory _ActivityTile.announcement({
    required AnnouncementRecord announcement,
  }) {
    return _ActivityTile._(
      icon: announcement.category.icon,
      title: announcement.title,
      subtitle: announcement.message,
      meta: announcement.priorityLabel,
      tone: announcement.unread ? UiTone.brand : UiTone.neutral,
    );
  }

  final IconData icon;
  final String title;
  final String subtitle;
  final String meta;
  final UiTone tone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = AppTheme.toneColor(tone);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.toneSoft(tone),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  meta,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w900,
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

class _EmptyActivityCard extends StatelessWidget {
  const _EmptyActivityCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.done_all_rounded, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No urgent activity right now.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumSectionHeader extends StatelessWidget {
  const _PremiumSectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _ResidentSectionHeader extends StatelessWidget {
  const _ResidentSectionHeader({
    required this.title,
    this.count,
    this.badgeLabel,
    this.onViewAll,
  });

  final String title;
  final int? count;
  final String? badgeLabel;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (count != null && count! > 0) ...<Widget>[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        if (badgeLabel != null) ...<Widget>[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badgeLabel!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        const Spacer(),
        if (onViewAll != null)
          GestureDetector(
            onTap: onViewAll,
            child: Text(
              'View all',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _DefaultAmenity {
  const _DefaultAmenity({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class _AmenityChip extends StatelessWidget {
  const _AmenityChip({required this.amenity});

  final _DefaultAmenity amenity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(amenity.icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text(
            amenity.label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ResidentEmptyRow extends StatelessWidget {
  const _ResidentEmptyRow({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.role,
    required this.vendor,
    // ignore: unused_element_parameter
    this.onPrimaryAction,
    // ignore: unused_element_parameter
    this.onSecondaryAction,
  });

  final AppRole role;
  final VendorData? vendor;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String name = (vendor?.fullName ?? '').trim();
    final String title = name.isEmpty ? 'Command center' : 'Welcome, $name';

    return CustomCard(
      padding: CustomCardPadding.lg,
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
                    ToneBadge(
                      label: role.label,
                      tone: UiTone.brand,
                      size: ToneBadgeSize.small,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      role.homeHeadline,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(color: AppTheme.primaryTone),
                ),
                child: const Icon(
                  Icons.dashboard_customize_outlined,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          if (onPrimaryAction != null || onSecondaryAction != null) ...<Widget>[
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                if (onPrimaryAction != null)
                  CustomButton(
                    label: 'Manage properties',
                    icon: const Icon(Icons.home_work_outlined),
                    onPressed: onPrimaryAction,
                  ),
                if (onSecondaryAction != null)
                  CustomButton(
                    label: 'Contracts',
                    variant: CustomButtonVariant.outline,
                    icon: const Icon(Icons.description_outlined),
                    onPressed: onSecondaryAction,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: CustomCardPadding.sm,
      color: AppTheme.surfaceElevated,
      child: Row(
        children: <Widget>[
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Refreshing dashboard data',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final DashboardMetric metric;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = AppTheme.toneColor(metric.tone);

    return CustomCard(
      padding: CustomCardPadding.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  metric.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            metric.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if ((actionLabel ?? '').isNotEmpty && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
