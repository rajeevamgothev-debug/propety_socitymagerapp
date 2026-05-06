import 'package:flutter/material.dart';

import '../../core/api/notification_service.dart';
import '../../core/api/society_service.dart';
import '../../core/api/vendor_service.dart';
import '../../core/models/api_models.dart';
import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_card.dart';
import '../../core/widgets/custom_tab_bar.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/tone_badge.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  VendorData? _vendor;
  SocietyData? _society;
  int _notificationCount = 0;
  int _currentReportTab = 0;
  bool _isLoading = true;
  String _selectedPeriod = 'month';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final VendorData? vendor = await VendorService.fetchVendorInfo();
      final SocietyData? society = vendor?.vendorType == 1
          ? await SocietyService.fetchSocietyInfo()
          : null;
      final notifications = await NotificationService.filterNotifications(
        limit: 100,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _vendor = vendor;
        _society = society;
        _notificationCount = notifications.count;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final BillCollectionSummaryData? billSummary =
        _vendor?.billCollectionSummary;
    final SupportTicketSummaryData? supportSummary =
        _vendor?.supportTicketSummary;
    final PropertySummaryData? propertySummary = _vendor?.propertySummary;
    final RentalContractSummaryData? contractSummary =
        _vendor?.rentalContractSummary;

    final List<_ReportMetric> metrics = switch (_vendor?.vendorType) {
      1 => <_ReportMetric>[
        _ReportMetric(
          title: 'Collected',
          value: _formatCurrency(billSummary?.currentMonthCollected ?? 0),
          subtitle: 'Current month collections',
          tone: UiTone.success,
        ),
        _ReportMetric(
          title: 'Pending',
          value: _formatCurrency(billSummary?.currentMonthPending ?? 0),
          subtitle: 'Current month pending bills',
          tone: UiTone.warning,
        ),
        _ReportMetric(
          title: 'Open Tickets',
          value: '${supportSummary?.openTicketsCount ?? 0}',
          subtitle: '${supportSummary?.criticalOpenTicketsCount ?? 0} critical',
          tone: UiTone.brand,
        ),
        _ReportMetric(
          title: 'Activity',
          value: '$_notificationCount',
          subtitle: 'Vendor notification records',
          tone: UiTone.neutral,
        ),
      ],
      2 => <_ReportMetric>[
        _ReportMetric(
          title: 'Properties',
          value: '${propertySummary?.totalPropertiesCount ?? 0}',
          subtitle: '${propertySummary?.approvedPropertiesCount ?? 0} approved',
          tone: UiTone.brand,
        ),
        _ReportMetric(
          title: 'Contracts',
          value: '${contractSummary?.activeContractsCount ?? 0}',
          subtitle: '${contractSummary?.pendingRenewalCount ?? 0} near renewal',
          tone: UiTone.success,
        ),
        _ReportMetric(
          title: 'Monthly Rent',
          value: _formatCurrency(contractSummary?.totalMonthlyRent ?? 0),
          subtitle: 'Active contract rent value',
          tone: UiTone.neutral,
        ),
        _ReportMetric(
          title: 'Outstanding',
          value: _formatCurrency(billSummary?.currentMonthPending ?? 0),
          subtitle: 'Pending bill amount',
          tone: UiTone.warning,
        ),
      ],
      _ => <_ReportMetric>[
        _ReportMetric(
          title: 'Activity',
          value: '$_notificationCount',
          subtitle: 'Vendor notification records',
          tone: UiTone.brand,
        ),
      ],
    };

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Text('Reports'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.border),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: AppTheme.pagePadding,
          children: <Widget>[
            const PageHeader(
              title: 'Reports and Analytics',
              description:
                  'Website reports were mock-driven; this mobile screen uses live vendor summaries from the backend.',
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 64),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              CustomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Unable to load analytics',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else ...<Widget>[
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: metrics.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.15,
                ),
                itemBuilder: (BuildContext context, int index) {
                  final _ReportMetric metric = metrics[index];
                  return CustomCard(
                    padding: CustomCardPadding.sm,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        ToneBadge(
                          label: metric.title,
                          tone: metric.tone,
                          size: ToneBadgeSize.small,
                        ),
                        const Spacer(),
                        Text(
                          metric.value,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          metric.subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (_vendor?.vendorType == 1) ...<Widget>[
                const SizedBox(height: 20),
                _buildReportControls(context),
                const SizedBox(height: 16),
                CustomTabBar(
                  style: CustomTabBarStyle.pill,
                  currentIndex: _currentReportTab,
                  onChanged: (int index) {
                    setState(() {
                      _currentReportTab = index;
                    });
                  },
                  tabs: const <CustomTabItem>[
                    CustomTabItem(
                      label: 'Financial',
                      icon: Icons.payments_outlined,
                    ),
                    CustomTabItem(
                      label: 'Visitors',
                      icon: Icons.badge_outlined,
                    ),
                    CustomTabItem(
                      label: 'Maintenance',
                      icon: Icons.home_repair_service_outlined,
                    ),
                    CustomTabItem(
                      label: 'Support',
                      icon: Icons.support_agent_outlined,
                    ),
                    CustomTabItem(
                      label: 'Wallet',
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSelectedSocietyReportTab(context),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedSocietyReportTab(BuildContext context) {
    return switch (_currentReportTab) {
      0 => _buildFinancialReportTab(context),
      1 => _buildVisitorReportTab(context),
      2 => _buildMaintenanceReportTab(context),
      3 => _buildSupportReportTab(context),
      _ => _buildWalletReportTab(context),
    };
  }

  Widget _buildReportControls(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Report Options',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedPeriod,
            decoration: const InputDecoration(labelText: 'Period'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(value: 'week', child: Text('This Week')),
              DropdownMenuItem<String>(
                value: 'month',
                child: Text('This Month'),
              ),
              DropdownMenuItem<String>(
                value: 'quarter',
                child: Text('This Quarter'),
              ),
              DropdownMenuItem<String>(value: 'year', child: Text('This Year')),
            ],
            onChanged: (String? value) {
              if (value == null) {
                return;
              }
              setState(() {
                _selectedPeriod = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              CustomButton(
                label: 'Date Range',
                variant: CustomButtonVariant.outline,
                size: CustomButtonSize.sm,
                icon: const Icon(Icons.calendar_today_outlined),
                onPressed: () => _showMessage(
                  'Date range reports need backend report filters before export.',
                ),
              ),
              CustomButton(
                label: 'Export All',
                variant: CustomButtonVariant.outline,
                size: CustomButtonSize.sm,
                icon: const Icon(Icons.download_outlined),
                onPressed: () => _showMessage(
                  'Report export is not available from the backend yet.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialReportTab(BuildContext context) {
    final BillCollectionSummaryData? summary = _vendor?.billCollectionSummary;
    final double collected = summary?.totalCollectedAmount ?? 0;
    final double pending = summary?.totalPendingAmount ?? 0;
    final double overdue = summary?.totalOverdueAmount ?? 0;
    final double total = collected + pending + overdue;
    final double collectionRate = _safeRatio(collected, total);

    return Column(
      children: <Widget>[
        CustomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Collection Overview',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              _CollectionRow(
                label: 'Total collected',
                value: _formatCurrency(collected),
                tone: UiTone.success,
              ),
              _CollectionRow(
                label: 'Pending',
                value: _formatCurrency(pending),
                tone: UiTone.warning,
              ),
              _CollectionRow(
                label: 'Overdue',
                value: _formatCurrency(overdue),
                tone: UiTone.danger,
              ),
              _CollectionRow(
                label: 'Today',
                value: _formatCurrency(summary?.todaysCollection ?? 0),
                tone: UiTone.brand,
              ),
              const SizedBox(height: 12),
              _StatusBar(
                label: 'Collection rate',
                value: collected,
                total: total,
                tone: UiTone.success,
                trailing: _formatPercent(collectionRate),
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
                'Bill Status Distribution',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              _StatusBar(
                label: 'Collected',
                value: collected,
                total: total,
                tone: UiTone.success,
              ),
              const SizedBox(height: 12),
              _StatusBar(
                label: 'Pending',
                value: pending,
                total: total,
                tone: UiTone.warning,
              ),
              const SizedBox(height: 12),
              _StatusBar(
                label: 'Overdue',
                value: overdue,
                total: total,
                tone: UiTone.danger,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSupportReportTab(BuildContext context) {
    final SupportTicketSummaryData? summary = _vendor?.supportTicketSummary;

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Support Ticket Summary',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          _CollectionRow(
            label: 'Open',
            value: '${summary?.openTicketsCount ?? 0}',
            tone: UiTone.warning,
          ),
          _CollectionRow(
            label: 'In progress',
            value: '${summary?.inProgressTicketsCount ?? 0}',
            tone: UiTone.brand,
          ),
          _CollectionRow(
            label: 'Resolved',
            value: '${summary?.resolvedTicketsCount ?? 0}',
            tone: UiTone.success,
          ),
          _CollectionRow(
            label: 'Critical',
            value: '${summary?.criticalOpenTicketsCount ?? 0}',
            tone: UiTone.danger,
          ),
        ],
      ),
    );
  }

  Widget _buildVisitorReportTab(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Visitor Analytics',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'The website visitor report is mock-driven. Mobile keeps this section visible but marks it as pending until live visitor APIs are available.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),
          _CollectionRow(
            label: 'Total visitors',
            value: '0',
            tone: UiTone.brand,
          ),
          _CollectionRow(
            label: 'Currently in',
            value: '0',
            tone: UiTone.success,
          ),
          _CollectionRow(
            label: 'Pre-approved',
            value: '0',
            tone: UiTone.neutral,
          ),
          _CollectionRow(label: 'Today', value: '0', tone: UiTone.warning),
        ],
      ),
    );
  }

  Widget _buildMaintenanceReportTab(BuildContext context) {
    final SocietyMaintenanceRates rates =
        _society?.maintenanceRates ?? const SocietyMaintenanceRates();
    final SocietyBillingConfig billingConfig =
        _society?.billingConfig ?? const SocietyBillingConfig();
    final double totalMonthly =
        rates.oneBhk +
        rates.twoBhk +
        rates.threeBhk +
        rates.fourBhk +
        rates.villa;

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Maintenance Reports',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          _CollectionRow(
            label: '1 BHK',
            value: _formatCurrency(rates.oneBhk),
            tone: UiTone.brand,
          ),
          _CollectionRow(
            label: '2 BHK',
            value: _formatCurrency(rates.twoBhk),
            tone: UiTone.success,
          ),
          _CollectionRow(
            label: '3 BHK',
            value: _formatCurrency(rates.threeBhk),
            tone: UiTone.warning,
          ),
          _CollectionRow(
            label: '4 BHK',
            value: _formatCurrency(rates.fourBhk),
            tone: UiTone.neutral,
          ),
          _CollectionRow(
            label: 'Villa',
            value: _formatCurrency(rates.villa),
            tone: UiTone.danger,
          ),
          const SizedBox(height: 8),
          _StatusBar(
            label: 'Expected monthly collection',
            value: totalMonthly,
            total: totalMonthly,
            tone: UiTone.success,
            trailing: _formatCurrency(totalMonthly),
          ),
          const SizedBox(height: 14),
          Text(
            'Bills generate on day ${billingConfig.billGenerationDate} and are due ${billingConfig.paymentDueDays} days later.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletReportTab(BuildContext context) {
    final WalletSummaryData? wallet = _vendor?.walletInfo;

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Wallet Overview',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          _CollectionRow(
            label: 'Available',
            value: _formatCurrency(wallet?.availableAmount ?? 0),
            tone: UiTone.brand,
          ),
          _CollectionRow(
            label: 'Credited',
            value: _formatCurrency(wallet?.creditedAmount ?? 0),
            tone: UiTone.success,
          ),
          _CollectionRow(
            label: 'Debited',
            value: _formatCurrency(wallet?.debitedAmount ?? 0),
            tone: UiTone.warning,
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  double _safeRatio(double value, double total) {
    if (total <= 0) {
      return 0;
    }
    final double ratio = value / total;
    if (ratio < 0) {
      return 0;
    }
    if (ratio > 1) {
      return 1;
    }
    return ratio;
  }

  String _formatPercent(double ratio) {
    final double percentage = ratio * 100;
    return '${percentage.toStringAsFixed(0)}%';
  }

  String _formatCurrency(double value) {
    if (value >= 100000) {
      return 'Rs ${(value / 100000).toStringAsFixed(1)}L';
    }
    if (value >= 1000) {
      return 'Rs ${(value / 1000).toStringAsFixed(1)}K';
    }
    return 'Rs ${value.toStringAsFixed(0)}';
  }
}

class _ReportMetric {
  const _ReportMetric({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.tone,
  });

  final String title;
  final String value;
  final String subtitle;
  final UiTone tone;
}

class _CollectionRow extends StatelessWidget {
  const _CollectionRow({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final UiTone tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppTheme.toneColor(tone),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.label,
    required this.value,
    required this.total,
    required this.tone,
    this.trailing,
  });

  final String label;
  final double value;
  final double total;
  final UiTone tone;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final double ratio = total <= 0 ? 0 : value / total;
    final double safeRatio = ratio < 0
        ? 0
        : ratio > 1
        ? 1
        : ratio;
    final String percentLabel =
        trailing ?? '${(safeRatio * 100).toStringAsFixed(0)}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              percentLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          minHeight: 8,
          value: safeRatio,
          color: AppTheme.toneColor(tone),
          backgroundColor: AppTheme.toneSoft(tone),
        ),
      ],
    );
  }
}
