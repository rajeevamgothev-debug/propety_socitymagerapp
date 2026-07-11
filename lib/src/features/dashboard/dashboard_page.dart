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
    this.showHomeHeaderInBody = true,
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
  final bool showHomeHeaderInBody;

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
      showHomeHeader: showHomeHeaderInBody,
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
  static const List<AppShortcut> _propertyManagerHomeShortcuts = <AppShortcut>[
    AppShortcut(
      title: 'Enquiries',
      subtitle: 'Follow up on property leads',
      icon: Icons.manage_search_outlined,
      actionKey: 'enquiries',
    ),
    AppShortcut(
      title: 'Tenant Bookings',
      subtitle: 'Review paid bookings and approvals',
      icon: Icons.event_available_outlined,
      actionKey: 'bookings',
    ),
    AppShortcut(
      title: 'Food Management',
      subtitle: 'Manage PG meals, voting, and results',
      icon: Icons.restaurant_menu_outlined,
      actionKey: 'food_management',
    ),
    AppShortcut(
      title: 'Rent Reminder',
      subtitle: 'Manage rent reminder schedule',
      icon: Icons.notifications_active_outlined,
      actionKey: 'rental_bills',
    ),
  ];

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
    required this.showHomeHeader,
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
  final bool showHomeHeader;

  List<AppShortcut> get _orderedShortcuts {
    final List<String> priorityKeys = role == AppRole.propertyManager
        ? const <String>[
            'properties',
            'rental_contracts',
            'rental_bills',
            'enquiries',
            'support',
            'bank_details',
          ]
        : const <String>[
            'society_management',
            'residents',
            'billing',
            'security',
            'support',
          ];

    final Map<String, AppShortcut> byKey = <String, AppShortcut>{
      for (final AppShortcut shortcut in shortcuts)
        shortcut.actionKey: shortcut,
    };
    final List<AppShortcut> ordered = <AppShortcut>[];

    for (final String key in priorityKeys) {
      final AppShortcut? shortcut = byKey.remove(key);
      if (shortcut != null) {
        ordered.add(shortcut);
      }
    }

    for (final AppShortcut shortcut in shortcuts) {
      if (byKey.remove(shortcut.actionKey) != null) {
        ordered.add(shortcut);
      }
    }

    return ordered;
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

  @override
  Widget build(BuildContext context) {
    final List<DashboardMetric> visibleMetrics = metrics.take(4).toList();
    final List<AppShortcut> orderedShortcuts = _orderedShortcuts;
    final List<AppShortcut> homeShortcutSource = role == AppRole.propertyManager
        ? _propertyManagerHomeShortcuts
        : orderedShortcuts;
    final List<AppShortcut> shortcutHighlights = homeShortcutSource
        .take(4)
        .toList();
    final String overviewActionKey = role == AppRole.propertyManager
        ? 'properties'
        : 'society_management';
    final String collectionsActionKey = role == AppRole.propertyManager
        ? 'rental_bills'
        : 'billing';

    return ListView(
      padding: EdgeInsets.fromLTRB(20, showHomeHeader ? 12 : 4, 20, 124),
      children: <Widget>[
        if (showHomeHeader) ...<Widget>[
          _HomeHeader(role: role, vendor: vendor, societyInfo: societyInfo),
          const SizedBox(height: 18),
        ],
        _HeroBanner(role: role),
        if (visibleMetrics.isNotEmpty) ...<Widget>[
          const SizedBox(height: 22),
          _StatsSection(metrics: visibleMetrics),
        ],
        if (shortcutHighlights.isNotEmpty) ...<Widget>[
          const SizedBox(height: 28),
          _ShortcutSection(
            shortcuts: shortcutHighlights,
            onShortcutSelected: onShortcutSelected,
            actionLabel: 'View all',
            onAction: () => onShortcutSelected(overviewActionKey),
          ),
        ],
        const SizedBox(height: 28),
        MobileBannerCarousel(audience: _mobileBannerAudience),
        if (isLoading) ...<Widget>[
          const SizedBox(height: 18),
          const _DashboardSkeleton(),
        ],
        const SizedBox(height: 28),
        _PremiumSectionHeader(
          title: 'Collections overview',
          actionLabel: role == AppRole.propertyManager
              ? 'Open bills'
              : 'Open billing',
          onAction: () => onShortcutSelected(collectionsActionKey),
        ),
        _RevenueAnalyticsCard(
          metrics: visibleMetrics,
          summary: billCollectionSummary,
        ),
        const SizedBox(height: 28),
        _RecentActivitySection(
          ticketPreview: ticketPreview,
          announcementPreview: announcementPreview,
        ),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.role,
    required this.vendor,
    required this.societyInfo,
  });

  final AppRole role;
  final VendorData? vendor;
  final SocietyData? societyInfo;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String rawName = (vendor?.fullName ?? societyInfo?.name ?? '').trim();
    final String firstName = rawName.isEmpty
        ? ''
        : rawName.split(RegExp(r'\s+')).first;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text.rich(
        TextSpan(
          style: theme.textTheme.headlineSmall?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            height: 1.08,
          ),
          children: <InlineSpan>[
            const TextSpan(text: 'Hello'),
            if (firstName.isNotEmpty) ...<InlineSpan>[
              const TextSpan(text: ', '),
              TextSpan(
                text: firstName,
                style: const TextStyle(color: AppTheme.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.role});

  final AppRole role;
  static const String _propertyManagerHeroAsset =
      'assets/hero_property_manager.png';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool compact = MediaQuery.sizeOf(context).width < 380;
    final bool isPropertyManager = role == AppRole.propertyManager;
    final double heroHeight = compact ? 204 : 220;
    final String accentWord = role == AppRole.propertyManager
        ? 'properties'
        : 'society';
    final String description = role == AppRole.propertyManager
        ? 'Track inventory, contracts, enquiries and collections in one clear workspace.'
        : 'Track residents, billing, security and announcements from one clear workspace.';

    return Container(
      height: heroHeight,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFF8FAFF), Colors.white, Color(0xFFEEF2FF)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: isPropertyManager
            ? Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Positioned(
                    top: 0,
                    right: compact ? -8 : -12,
                    bottom: 0,
                    width: compact ? 188 : 232,
                    child: Image.asset(
                      _propertyManagerHeroAsset,
                      fit: BoxFit.cover,
                      alignment: Alignment.centerRight,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, _, _) => const Padding(
                        padding: EdgeInsets.fromLTRB(12, 18, 12, 18),
                        child: _HeroIllustration(),
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: <Color>[
                            Color(0xFCFFFFFF),
                            Color(0xF8FFFFFF),
                            Color(0xD7F8FAFF),
                            Color(0x00EEF2FF),
                          ],
                          stops: <double>[0, .34, .62, 1],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: compact ? 160 : 210,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'MANAGE SMARTER',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text.rich(
                              TextSpan(
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  height: 1.08,
                                ),
                                children: <InlineSpan>[
                                  const TextSpan(text: 'Manage your\n'),
                                  TextSpan(
                                    text: accentWord,
                                    style: const TextStyle(
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              description,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Positioned(
                    top: -26,
                    right: -20,
                    child: Container(
                      width: compact ? 120 : 160,
                      height: compact ? 120 : 160,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0x1A4F46E5),
                      ),
                    ),
                  ),
                  Positioned(
                    right: compact ? 56 : 96,
                    bottom: -34,
                    child: Container(
                      width: compact ? 96 : 132,
                      height: compact ? 96 : 132,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0x144F46E5),
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            Color(0xFFF8FAFF),
                            Colors.white,
                            Color(0xFFEEF2FF),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          flex: compact ? 7 : 6,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'RUN SMARTER',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text.rich(
                                TextSpan(
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    height: 1.08,
                                  ),
                                  children: <InlineSpan>[
                                    const TextSpan(text: 'Run your\n'),
                                    TextSpan(
                                      text: accentWord,
                                      style: const TextStyle(
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: compact ? 170 : 220,
                                ),
                                child: Text(
                                  description,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          flex: 4,
                          child: Align(
                            alignment: Alignment.bottomRight,
                            child: _HeroIllustration(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: .9,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          const Positioned(
            top: 10,
            right: 18,
            child: _FloatingIcon(
              icon: Icons.cloud_outlined,
              color: Color(0xFF60A5FA),
            ),
          ),
          const Positioned(
            top: 40,
            left: 12,
            child: _FloatingIcon(
              icon: Icons.inventory_2_outlined,
              color: AppTheme.primary,
            ),
          ),
          const Positioned(
            left: 34,
            bottom: 36,
            child: _FloatingIcon(
              icon: Icons.description_outlined,
              color: Color(0xFF10B981),
            ),
          ),
          const Positioned(
            right: 2,
            bottom: 28,
            child: _FloatingIcon(
              icon: Icons.payments_outlined,
              color: Color(0xFFF59E0B),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const <Widget>[
                _IllustrationTower(
                  width: 42,
                  height: 88,
                  accent: Color(0xFF93C5FD),
                  fill: Color(0xFFE0ECFF),
                ),
                SizedBox(width: 10),
                _IllustrationTower(
                  width: 56,
                  height: 124,
                  accent: Color(0xFF60A5FA),
                  fill: Colors.white,
                ),
                SizedBox(width: 10),
                _IllustrationTower(
                  width: 72,
                  height: 152,
                  accent: AppTheme.primary,
                  fill: Color(0xFFF8FBFF),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IllustrationTower extends StatelessWidget {
  const _IllustrationTower({
    required this.width,
    required this.height,
    required this.accent,
    required this.fill,
  });

  final double width;
  final double height;
  final Color accent;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Colors.white.withAlpha(240), fill],
        ),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(18),
          bottom: Radius.circular(6),
        ),
        border: Border.all(color: const Color(0xFFD6E0F5)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x100F172A),
            blurRadius: 12,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List<Widget>.generate(
                4,
                (_) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List<Widget>.generate(
                    2,
                    (_) => Container(
                      width: 8,
                      height: 10,
                      decoration: BoxDecoration(
                        color: accent.withAlpha(44),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingIcon extends StatelessWidget {
  const _FloatingIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(220),
        shape: BoxShape.circle,
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.metrics});

  final List<DashboardMetric> metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: List<Widget>.generate(metrics.length, (int index) {
        return Expanded(
          child: _StatItem(
            metric: metrics[index],
            showTrailingDivider: index != metrics.length - 1,
          ),
        );
      }),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.metric, required this.showTrailingDivider});

  final DashboardMetric metric;
  final bool showTrailingDivider;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = _accentForMetric(metric);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: showTrailingDivider
            ? const Border(right: BorderSide(color: AppTheme.borderSoft))
            : null,
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withAlpha(22),
              shape: BoxShape.circle,
            ),
            child: Icon(_iconForMetric(metric.title), color: accent, size: 21),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              metric.value,
              maxLines: 1,
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _metricLabel(metric.title),
            maxLines: 2,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForMetric(String title) {
    final String normalized = title.toLowerCase();
    if (normalized.contains('propert')) {
      return Icons.apartment_outlined;
    }
    if (normalized.contains('contract')) {
      return Icons.description_outlined;
    }
    if (normalized.contains('pending')) {
      return Icons.schedule_outlined;
    }
    if (normalized.contains('outstanding') || normalized.contains('bill')) {
      return Icons.receipt_long_outlined;
    }
    return Icons.insights_outlined;
  }

  Color _accentForMetric(DashboardMetric metric) {
    final String normalized = metric.title.toLowerCase();
    if (normalized.contains('propert')) {
      return AppTheme.primary;
    }
    if (normalized.contains('contract')) {
      return const Color(0xFF22C55E);
    }
    if (normalized.contains('pending')) {
      return AppTheme.secondary;
    }
    if (normalized.contains('outstanding') || normalized.contains('bill')) {
      return const Color(0xFF8B5CF6);
    }
    return AppTheme.toneColor(metric.tone);
  }

  String _metricLabel(String title) {
    if (title == 'Pending Approval') {
      return 'Pending';
    }
    if (title == 'Live Contracts') {
      return 'Contracts';
    }
    if (title == 'Outstanding') {
      return 'Due amount';
    }
    return title;
  }
}

class _ShortcutSection extends StatelessWidget {
  const _ShortcutSection({
    required this.shortcuts,
    required this.onShortcutSelected,
    this.actionLabel,
    this.onAction,
  });

  final List<AppShortcut> shortcuts;
  final ValueChanged<String> onShortcutSelected;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _PremiumSectionHeader(
          title: 'Shortcuts',
          actionLabel: actionLabel,
          onAction: onAction,
        ),
        Row(
          children: List<Widget>.generate(shortcuts.length, (int index) {
            final AppShortcut shortcut = shortcuts[index];
            return Expanded(
              child: _ShortcutBubble(
                shortcut: shortcut,
                onTap: () => onShortcutSelected(shortcut.actionKey),
                showTrailingDivider: index != shortcuts.length - 1,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ShortcutBubble extends StatelessWidget {
  const _ShortcutBubble({
    required this.shortcut,
    required this.onTap,
    required this.showTrailingDivider,
  });

  final AppShortcut shortcut;
  final VoidCallback onTap;
  final bool showTrailingDivider;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = _accentForShortcut(shortcut.actionKey);

    return Stack(
      alignment: Alignment.centerRight,
      children: <Widget>[
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Column(
                children: <Widget>[
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: accent.withAlpha(18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(shortcut.icon, color: accent, size: 26),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _shortcutLabel(shortcut.title),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showTrailingDivider)
          Container(
            width: 1,
            height: 42,
            margin: const EdgeInsets.only(bottom: 18),
            color: AppTheme.borderSoft,
          ),
      ],
    );
  }

  Color _accentForShortcut(String actionKey) {
    switch (actionKey) {
      case 'properties':
      case 'society_management':
        return AppTheme.primary;
      case 'rental_contracts':
      case 'residents':
        return const Color(0xFF22C55E);
      case 'rental_bills':
      case 'billing':
        return const Color(0xFF8B5CF6);
      case 'security':
        return AppTheme.secondary;
      case 'enquiries':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  String _shortcutLabel(String label) {
    if (label == 'Rental Bills') {
      return 'Bills';
    }
    return label;
  }
}

class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection({
    required this.ticketPreview,
    required this.announcementPreview,
  });

  final List<TicketRecord> ticketPreview;
  final List<AnnouncementRecord> announcementPreview;

  @override
  Widget build(BuildContext context) {
    final List<_ActivityLine> activity = <_ActivityLine>[
      ...ticketPreview.map(
        (TicketRecord ticket) => _ActivityLine.ticket(ticket: ticket),
      ),
      ...announcementPreview.map(
        (AnnouncementRecord announcement) =>
            _ActivityLine.announcement(announcement: announcement),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _PremiumSectionHeader(title: 'Recent activity'),
        if (activity.isEmpty)
          const _EmptyActivityState()
        else
          Column(
            children: List<Widget>.generate(activity.length, (int index) {
              return activity[index].copyWith(
                showDivider: index != activity.length - 1,
              );
            }),
          ),
      ],
    );
  }
}

class _ActivityLine extends StatelessWidget {
  const _ActivityLine._({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.tone,
    this.showDivider = false,
  });

  factory _ActivityLine.ticket({required TicketRecord ticket}) {
    return _ActivityLine._(
      icon: Icons.support_agent_outlined,
      title: ticket.title,
      subtitle: ticket.description,
      meta:
          '${ticket.status.label} - ${formatCompactDate(ticket.updatedAt)} ${formatClock(ticket.updatedAt)}',
      tone: ticket.status.tone,
    );
  }

  factory _ActivityLine.announcement({
    required AnnouncementRecord announcement,
  }) {
    return _ActivityLine._(
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
  final bool showDivider;

  _ActivityLine copyWith({required bool showDivider}) {
    return _ActivityLine._(
      icon: icon,
      title: title,
      subtitle: subtitle,
      meta: meta,
      tone: tone,
      showDivider: showDivider,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = AppTheme.toneColor(tone);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.toneSoft(tone),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showDivider) ...<Widget>[
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.only(left: 58),
              child: Divider(
                height: 1,
                thickness: 1,
                color: AppTheme.borderSoft,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyActivityState extends StatelessWidget {
  const _EmptyActivityState();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: AppTheme.primarySoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.done_all_rounded, color: AppTheme.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'No urgent activity right now.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
    final double currentMonthPending = summary?.currentMonthPending ?? 0;
    final double currentMonthOverdue = summary?.currentMonthOverdue ?? 0;
    final double securityCollected = summary?.collectedSecurityAmount ?? 0;
    final double monthFlowTotal =
        monthCollected + currentMonthPending + currentMonthOverdue;
    final double totalReceivable =
        totalCollected + pendingAmount + overdueAmount;
    const Color collectedColor = Color(0xFF0F766E);
    const Color monthColor = Color(0xFF2563EB);
    const Color todayColor = Color(0xFF14B8A6);
    const Color pendingColor = Color(0xFFF59E0B);
    const Color overdueColor = Color(0xFFE11D48);
    const Color securityColor = Color(0xFF334155);
    final List<double> values = <double>[
      totalCollected,
      monthCollected,
      todayCollected,
      pendingAmount,
      overdueAmount,
    ];
    final double maxValue = values.fold<double>(
      0,
      (double max, double value) => value > max ? value : max,
    );
    final String headline = _formatCurrency(monthCollected);
    final String supporting = todayCollected > 0
        ? '${_formatCurrency(todayCollected)} collected today'
        : '${_formatCurrency(totalCollected)} collected overall';
    final List<_RevenueBarValue> bars = <_RevenueBarValue>[
      _RevenueBarValue(
        label: 'Total',
        value: totalCollected,
        color: collectedColor,
      ),
      _RevenueBarValue(
        label: 'Month',
        value: monthCollected,
        color: monthColor,
      ),
      _RevenueBarValue(
        label: 'Today',
        value: todayCollected,
        color: todayColor,
      ),
      _RevenueBarValue(
        label: 'Pending',
        value: pendingAmount,
        color: pendingColor,
      ),
      _RevenueBarValue(
        label: 'Overdue',
        value: overdueAmount,
        color: overdueColor,
      ),
    ];
    final String statusLabel = overdueAmount > 0
        ? 'Overdue attention'
        : pendingAmount > 0
        ? 'Collection active'
        : 'On track';
    final Color statusColor = overdueAmount > 0
        ? overdueColor
        : pendingAmount > 0
        ? pendingColor
        : collectedColor;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 380;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFFF5FBF9),
                Colors.white,
                Color(0xFFF8FAFC),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD8E4E2)),
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
                          'Revenue analytics',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Collections, month flow, and recovery pressure in one view.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0xFF0F172A), Color(0xFF134E4A)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _RevenueHeadlineBlock(
                            eyebrow: 'Collected this month',
                            headline: headline,
                            supporting: supporting,
                          ),
                          const SizedBox(height: 16),
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0x2AFFFFFF),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: _RevenueBandMetric(
                                  label: 'Today',
                                  value: _formatCurrency(todayCollected),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _RevenueBandMetric(
                                  label: 'Security',
                                  value: _formatCurrency(securityCollected),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: <Widget>[
                          Expanded(
                            child: _RevenueHeadlineBlock(
                              eyebrow: 'Collected this month',
                              headline: headline,
                              supporting: supporting,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 72,
                            margin: const EdgeInsets.symmetric(horizontal: 18),
                            color: const Color(0x2AFFFFFF),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                _RevenueBandMetric(
                                  label: 'Today',
                                  value: _formatCurrency(todayCollected),
                                ),
                                const SizedBox(height: 14),
                                _RevenueBandMetric(
                                  label: 'Security',
                                  value: _formatCurrency(securityCollected),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Text(
                    'Monthly flow',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_percentageLabel(monthCollected, monthFlowTotal)} settled',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: collectedColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _RevenueSplitBar(
                segments: <_RevenueSplitSegment>[
                  _RevenueSplitSegment(
                    label: 'Collected',
                    value: monthCollected,
                    total: monthFlowTotal,
                    color: collectedColor,
                  ),
                  _RevenueSplitSegment(
                    label: 'Pending',
                    value: currentMonthPending,
                    total: monthFlowTotal,
                    color: pendingColor,
                  ),
                  _RevenueSplitSegment(
                    label: 'Overdue',
                    value: currentMonthOverdue,
                    total: monthFlowTotal,
                    color: overdueColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 12,
                children: <Widget>[
                  _RevenueLegendStat(
                    label: 'Collected',
                    value: _formatCurrency(monthCollected),
                    share: _percentageLabel(monthCollected, monthFlowTotal),
                    color: collectedColor,
                  ),
                  _RevenueLegendStat(
                    label: 'Pending',
                    value: _formatCurrency(currentMonthPending),
                    share: _percentageLabel(
                      currentMonthPending,
                      monthFlowTotal,
                    ),
                    color: pendingColor,
                  ),
                  _RevenueLegendStat(
                    label: 'Overdue',
                    value: _formatCurrency(currentMonthOverdue),
                    share: _percentageLabel(
                      currentMonthOverdue,
                      monthFlowTotal,
                    ),
                    color: overdueColor,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Text(
                    'Performance view',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_percentageLabel(totalCollected, totalReceivable)} recovered overall',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 156,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: bars
                      .map(
                        (_RevenueBarValue item) => _RevenueChartColumn(
                          label: item.label,
                          value: _formatCurrency(item.value),
                          heightFactor: _heightFactor(item.value, maxValue),
                          color: item.color,
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5ECEC)),
                ),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _RevenueMiniStat(
                            label: 'Total collected',
                            value: _formatCurrency(totalCollected),
                            icon: Icons.account_balance_wallet_outlined,
                            color: collectedColor,
                          ),
                        ),
                        const _RevenueStatDivider(),
                        Expanded(
                          child: _RevenueMiniStat(
                            label: 'Pending now',
                            value: _formatCurrency(pendingAmount),
                            icon: Icons.schedule_outlined,
                            color: pendingColor,
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(height: 1, thickness: 1),
                    ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _RevenueMiniStat(
                            label: 'Overdue now',
                            value: _formatCurrency(overdueAmount),
                            icon: Icons.error_outline_rounded,
                            color: overdueColor,
                          ),
                        ),
                        const _RevenueStatDivider(),
                        Expanded(
                          child: _RevenueMiniStat(
                            label: 'Security recovered',
                            value: _formatCurrency(securityCollected),
                            icon: Icons.lock_outline_rounded,
                            color: securityColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _heightFactor(double value, double maxValue) {
    if (maxValue <= 0 || value <= 0) {
      return .18;
    }
    final double normalized = value / maxValue;
    return normalized.clamp(.18, 1).toDouble();
  }

  String _percentageLabel(double value, double total) {
    if (total <= 0 || value <= 0) {
      return '0%';
    }
    return '${((value / total) * 100).round()}%';
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
  const _RevenueMiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
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

class _RevenueChartColumn extends StatelessWidget {
  const _RevenueChartColumn({
    required this.label,
    required this.value,
    required this.heightFactor,
    required this.color,
  });

  final String label;
  final String value;
  final double heightFactor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4F3),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: heightFactor,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[color.withValues(alpha: 0.72), color],
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueHeadlineBlock extends StatelessWidget {
  const _RevenueHeadlineBlock({
    required this.eyebrow,
    required this.headline,
    required this.supporting,
  });

  final String eyebrow;
  final String headline;
  final String supporting;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          eyebrow,
          style: theme.textTheme.labelSmall?.copyWith(
            color: const Color(0xFFCCFBF1),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          headline,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          supporting,
          style: theme.textTheme.bodySmall?.copyWith(
            color: const Color(0xFFD1FAE5),
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _RevenueBandMetric extends StatelessWidget {
  const _RevenueBandMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: const Color(0xFFBFDBFE),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _RevenueSplitBar extends StatelessWidget {
  const _RevenueSplitBar({required this.segments});

  final List<_RevenueSplitSegment> segments;

  @override
  Widget build(BuildContext context) {
    final List<_RevenueSplitSegment> positiveSegments = segments
        .where((_RevenueSplitSegment segment) => segment.value > 0)
        .toList();

    if (positiveSegments.isEmpty) {
      return Container(
        height: 12,
        decoration: BoxDecoration(
          color: const Color(0xFFE5ECEC),
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 12,
        child: Row(
          children: positiveSegments
              .map(
                (_RevenueSplitSegment segment) => Expanded(
                  flex: segment.flex,
                  child: ColoredBox(color: segment.color),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _RevenueLegendStat extends StatelessWidget {
  const _RevenueLegendStat({
    required this.label,
    required this.value,
    required this.share,
    required this.color,
  });

  final String label;
  final String value;
  final String share;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '$label  $share',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RevenueStatDivider extends StatelessWidget {
  const _RevenueStatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFFE2E8F0),
    );
  }
}

class _RevenueSplitSegment {
  const _RevenueSplitSegment({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final double value;
  final double total;
  final Color color;

  int get flex {
    if (total <= 0 || value <= 0) {
      return 0;
    }
    return ((value / total) * 100).round().clamp(1, 100);
  }
}

class _RevenueBarValue {
  const _RevenueBarValue({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: Size.zero,
              ),
              child: Text(
                actionLabel!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
