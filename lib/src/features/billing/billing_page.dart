import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/billing_service.dart';
import '../../core/api/block_building_service.dart';
import '../../core/api/society_service.dart';
import '../../core/api/property_service.dart';
import '../../core/api/razorpay_checkout_service.dart';
import '../../core/api/rental_contract_service.dart';
import '../../core/api/upload_service.dart';
import '../../core/api/vendor_service.dart';
import '../../core/models/api_models.dart';
import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/rental_bills_excel_service.dart';
import '../../core/utils/rental_bill_pdf_service.dart';
import '../../core/utils/society_bills_excel_service.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_card.dart';
import '../../core/widgets/custom_tab_bar.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/tone_badge.dart';

class BillingPage extends StatefulWidget {
  const BillingPage({
    super.key,
    required this.role,
    required this.bills,
    this.isLoading = false,
    this.onRefresh,
    this.societyId = '',
  });

  final AppRole role;
  final List<BillRecord> bills;
  final bool isLoading;
  final VoidCallback? onRefresh;
  final String societyId;

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  static const Map<int, String> _propertyFlatTypeLabels = <int, String>{
    1: '1 BHK',
    2: '2 BHK',
    3: '3 BHK',
    4: '4 BHK',
    5: 'Studio',
    6: 'Duplex',
    7: 'Penthouse',
    8: 'Villa',
  };

  static const Map<int, Map<int, String>> _propertySubtypeLabels =
      <int, Map<int, String>>{
        1: <int, String>{
          1: '1 BHK',
          2: '2 BHK',
          3: '3 BHK',
          4: '4 BHK',
          5: 'Studio',
        },
        2: <int, String>{
          1: '2 BHK Villa',
          2: '3 BHK Villa',
          3: '4 BHK Villa',
          4: 'Duplex Villa',
        },
        3: <int, String>{1: 'Mens PG', 2: 'Womens PG', 3: 'Coliving'},
        4: <int, String>{
          1: 'Office',
          2: 'Retail',
          3: 'Warehouse',
          4: 'Showroom',
        },
      };

  final TextEditingController _searchController = TextEditingController();

  BillStatus? _selectedFilter;
  VendorData? _vendor;
  String _societyId = '';
  Timer? _searchDebounce;

  // ---------------------------------------------------------------------------
  // Tenant flow state
  // ---------------------------------------------------------------------------
  int? _billTypeFilter;
  bool _isLoadingTenantBills = false;
  String? _tenantError;
  List<BillRecord> _tenantBills = <BillRecord>[];
  double _tenantPendingAmount = 0;
  double _tenantPaidAmount = 0;
  double _tenantOverdueAmount = 0;

  // ---------------------------------------------------------------------------
  // Property Manager direct-fetch state
  // ---------------------------------------------------------------------------
  bool _isPmLoading = false;
  String? _pmError;
  List<BillRecord> _pmBills = <BillRecord>[];
  double _pmPendingAmount = 0;
  double _pmCollectedAmount = 0;
  double _pmOverdueAmount = 0;
  double _pmTodayCollection = 0;
  double _pmMonthCollection = 0;
  double _pmMonthOverdue = 0;
  double _pmMonthPending = 0;
  double _pmTotalSecurityBill = 0;
  double _pmPendingSecurity = 0;
  double _pmCollectedSecurity = 0;
  int _pmSkip = 0;
  int _pmTotalCount = 0;
  static const int _pmPageSize = 10;
  final Map<String, String> _localPaymentProofPaths = <String, String>{};

  // PM filters
  String? _pmPropertyId;
  String? _pmContractId;
  List<Map<String, String>> _pmProperties = <Map<String, String>>[];
  List<Map<String, String>> _pmContracts = <Map<String, String>>[];
  Map<String, RentalContractRecord> _pmContractsById =
      <String, RentalContractRecord>{};

  // ---------------------------------------------------------------------------
  // Society Manager direct-fetch state
  // ---------------------------------------------------------------------------
  bool _isSocietyLoading = false;
  String? _societyError;
  List<BillRecord> _societyBills = <BillRecord>[];
  double _societyPendingAmount = 0;
  double _societyCollectedAmount = 0;
  double _societyOverdueAmount = 0;
  double _societyTodayCollection = 0;
  double _societyMonthCollection = 0;
  double _societyMonthOverdue = 0;
  double _societyMonthPending = 0;
  int _societySkip = 0;
  int _societyTotalCount = 0;
  static const int _societyPageSize = 10;

  // Society filters
  int? _societyBillTypeFilter;
  BillStatus? _societyStatusFilter;
  String _societyBlockFilter = '';
  String _societyBuildingFilter = '';
  List<BlockData> _societyBlocks = <BlockData>[];
  List<BuildingData> _societyBuildings = <BuildingData>[];

  bool get _usesTenantWebsiteFlow => widget.role == AppRole.tenant;
  bool get _usesPmFlow => widget.role == AppRole.propertyManager;
  bool get _usesSocietyFlow => widget.role.isSocietyScope;

  @override
  void initState() {
    super.initState();
    _societyId = widget.societyId;
    _loadVendor();
    if (_usesTenantWebsiteFlow) {
      _loadTenantBills();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load PM data after vendor is known — vendor is loaded async so we
    // trigger PM load once vendor arrives via _loadVendor().
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVendor() async {
    try {
      _vendor = await VendorService.fetchVendorInfo();
    } catch (_) {
      _vendor = null;
    }
    // Resolve societyId from the society API (Vendor model has no SocietyID).
    if (_usesSocietyFlow && _societyId.isEmpty) {
      try {
        final SocietyData? society = await SocietyService.fetchSocietyInfo();
        _societyId = society?.societyId ?? '';
      } catch (_) {}
    }
    if (_usesPmFlow) {
      await Future.wait(<Future<void>>[
        _loadPmBills(),
        _loadPmContracts(),
        _loadPmProperties(),
      ]);
    }
    if (_usesSocietyFlow && _societyId.isNotEmpty) {
      try {
        final blocksResult = await BlockBuildingService.filterBlocks(
          _societyId,
          limit: 200,
        );
        final buildingsResult = await BlockBuildingService.filterBuildings(
          _societyId,
          limit: 200,
        );
        if (mounted) {
          setState(() {
            _societyBlocks = blocksResult.blocks;
            _societyBuildings = buildingsResult.buildings;
          });
        }
      } catch (_) {}
      // Now that societyId is resolved, load society bills.
      _loadSocietyBills();
    }
  }

  // ---------------------------------------------------------------------------
  // Tenant bills
  // ---------------------------------------------------------------------------
  Future<void> _loadTenantBills() async {
    setState(() {
      _isLoadingTenantBills = true;
      _tenantError = null;
    });

    try {
      final result = await BillingService.filterTenantBillsDetailed(
        limit: 100,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        billType: _billTypeFilter,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _tenantBills = result.bills;
        _tenantPendingAmount = result.pendingAmount;
        _tenantPaidAmount = result.paidAmount;
        _tenantOverdueAmount = result.overdueAmount;
        _isLoadingTenantBills = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _tenantError = error.toString().replaceFirst('Exception: ', '');
        _isLoadingTenantBills = false;
      });
    }
  }

  void _handleTenantSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      _loadTenantBills,
    );
  }

  // ---------------------------------------------------------------------------
  // Society Manager bills
  // ---------------------------------------------------------------------------
  Future<void> _loadSocietyBills() async {
    if (_societyId.isEmpty) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _isSocietyLoading = true;
      _societyError = null;
    });

    try {
      final result = await BillingService.filterSocietyResidentBills(
        societyId: _societyId,
        skip: _societySkip,
        limit: _societyPageSize,
        statusFilter: _societyStatusFilter,
        billType: _societyBillTypeFilter,
        blockId: _societyBlockFilter.isEmpty ? null : _societyBlockFilter,
        buildingId: _societyBuildingFilter.isEmpty
            ? null
            : _societyBuildingFilter,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _societyBills = result.bills;
        _societyTotalCount = result.count;
        _societyPendingAmount = result.pendingAmount;
        _societyCollectedAmount = result.collectedAmount;
        _societyOverdueAmount = result.overdueAmount;
        _societyTodayCollection = result.todayCollection;
        _societyMonthCollection = result.monthCollection;
        _societyMonthOverdue = result.monthOverdue;
        _societyMonthPending = result.monthPending;
        _isSocietyLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _societyError = error.toString().replaceFirst('Exception: ', '');
        _isSocietyLoading = false;
      });
    }
  }

  Future<void> _exportSocietyBillsPdf() async {
    if (_societyId.isEmpty) {
      return;
    }

    try {
      final int exportLimit = _societyTotalCount > 0
          ? _societyTotalCount
          : _societyPageSize;
      final result = await BillingService.filterSocietyResidentBills(
        societyId: _societyId,
        skip: 0,
        limit: exportLimit,
        statusFilter: _societyStatusFilter,
        billType: _societyBillTypeFilter,
        blockId: _societyBlockFilter.isEmpty ? null : _societyBlockFilter,
        buildingId: _societyBuildingFilter.isEmpty
            ? null
            : _societyBuildingFilter,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );
      if (result.bills.isEmpty) {
        _showMessage('No society bills available for export.');
        return;
      }
      await _openBillsReportPdfPreview(result.bills);
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _handleSocietySearchChanged(String value) {
    setState(() {
      _societySkip = 0;
    });
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 400),
      _loadSocietyBills,
    );
  }

  // ---------------------------------------------------------------------------
  // Property Manager bills
  // ---------------------------------------------------------------------------
  Future<void> _loadPmBills() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isPmLoading = true;
      _pmError = null;
    });

    try {
      final String? pid = (_pmPropertyId != null && _pmPropertyId!.isNotEmpty)
          ? _pmPropertyId
          : null;
      final bool hasEntityFilter =
          pid != null || (_pmContractId?.trim().isNotEmpty ?? false);
      final result = await BillingService.filterPropertyContractBillsDetailed(
        propertyId: pid,
        skip: hasEntityFilter ? 0 : _pmSkip,
        limit: hasEntityFilter ? 200 : _pmPageSize,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        statusFilter: _selectedFilter,
        contractId: _pmContractId,
      );
      if (!mounted) {
        return;
      }
      final List<BillRecord> bills = _enrichPmBillsWithContractImages(
        result.bills,
      );
      final List<BillRecord> visibleBills = _applyPmBillEntityFilters(bills);
      setState(() {
        _pmBills = visibleBills;
        _pmTotalCount = hasEntityFilter ? visibleBills.length : result.count;
        _pmPendingAmount = result.pendingAmount;
        _pmCollectedAmount = result.collectedAmount;
        _pmOverdueAmount = result.overdueAmount;
        _pmTodayCollection = result.todayCollection;
        _pmMonthCollection = result.monthCollection;
        _pmMonthOverdue = result.monthOverdue;
        _pmMonthPending = result.monthPending;
        _pmTotalSecurityBill = result.totalSecurityBill;
        _pmPendingSecurity = result.pendingSecurity;
        _pmCollectedSecurity = result.collectedSecurity;
        _isPmLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pmError = error.toString().replaceFirst('Exception: ', '');
        _isPmLoading = false;
      });
    }
  }

  Future<void> _loadPmContracts() async {
    try {
      final result = await RentalContractService.filterRentalContracts(
        limit: 200,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _pmContractsById = <String, RentalContractRecord>{
          for (final RentalContractRecord contract in result.contracts)
            contract.id: contract,
        };
        _pmContracts = result.contracts.map((RentalContractRecord c) {
          return <String, String>{
            'id': c.id,
            'label': _contractOptionDropdownLabel(c),
          };
        }).toList();
        if (_pmBills.isNotEmpty) {
          _pmBills = _applyPmBillEntityFilters(
            _enrichPmBillsWithContractImages(_pmBills),
          );
          if ((_pmPropertyId?.trim().isNotEmpty ?? false) ||
              (_pmContractId?.trim().isNotEmpty ?? false)) {
            _pmTotalCount = _pmBills.length;
          }
        }
      });
    } catch (_) {
      // contracts are optional for filter — silently ignore
    }
  }

  List<BillRecord> _enrichPmBillsWithContractImages(List<BillRecord> bills) {
    if (_pmContractsById.isEmpty) {
      return bills;
    }

    return bills.map((BillRecord bill) {
      if ((bill.tenantImageUrl ?? '').trim().isNotEmpty &&
          (bill.unitType ?? '').trim().isNotEmpty) {
        return bill;
      }

      RentalContractRecord? linkedContract;
      final String contractId = (bill.rentalContractId ?? '').trim();
      if (contractId.isNotEmpty) {
        linkedContract = _pmContractsById[contractId];
      }

      linkedContract ??= _findMatchingPmContract(bill);
      final String imageUrl = linkedContract?.tenantImageUrl?.trim() ?? '';
      final String unitType = linkedContract?.flatType?.trim() ?? '';
      return bill.copyWith(
        tenantImageUrl: imageUrl.isEmpty ? null : imageUrl,
        unitType: unitType.isEmpty ? null : unitType,
      );
    }).toList();
  }

  RentalContractRecord? _findMatchingPmContract(BillRecord bill) {
    final String billPropertyId = (bill.propertyId ?? '').trim();
    final String billPhone = _digitsOnly(bill.residentPhone ?? '');
    final String billUnit = bill.unitLabel.trim().toLowerCase();
    final String billName = (bill.residentName ?? '').trim().toLowerCase();

    for (final RentalContractRecord contract in _pmContractsById.values) {
      final bool propertyMatches =
          billPropertyId.isEmpty || billPropertyId == (contract.propertyId ?? '');
      final bool phoneMatches =
          billPhone.isNotEmpty &&
          billPhone == _digitsOnly(contract.tenantPhone ?? '');
      final bool unitMatches =
          billUnit.isNotEmpty &&
          billUnit != 'n/a' &&
          billUnit == (contract.flatNo ?? '').trim().toLowerCase();
      final bool nameMatches =
          billName.isNotEmpty &&
          billName == contract.tenantName.trim().toLowerCase();
      if (propertyMatches && (phoneMatches || unitMatches || nameMatches)) {
        return contract;
      }
    }
    return null;
  }

  List<BillRecord> _applyPmBillEntityFilters(List<BillRecord> bills) {
    final String propertyId = _pmPropertyId?.trim() ?? '';
    final String contractId = _pmContractId?.trim() ?? '';
    if (propertyId.isEmpty && contractId.isEmpty) {
      return bills;
    }

    return bills.where((BillRecord bill) {
      final RentalContractRecord? linkedContract =
          _linkedContractForPmBill(bill);
      if (propertyId.isNotEmpty) {
        final String billPropertyId = (bill.propertyId ?? '').trim();
        final String linkedPropertyId =
            (linkedContract?.propertyId ?? '').trim();
        final bool canCheckProperty =
            billPropertyId.isNotEmpty || linkedPropertyId.isNotEmpty;
        if (canCheckProperty &&
            billPropertyId != propertyId &&
            linkedPropertyId != propertyId) {
          return false;
        }
      }
      if (contractId.isNotEmpty) {
        final String billContractId = (bill.rentalContractId ?? '').trim();
        final String linkedContractId = (linkedContract?.id ?? '').trim();
        final bool canCheckContract =
            billContractId.isNotEmpty || linkedContractId.isNotEmpty;
        if (canCheckContract &&
            billContractId != contractId &&
            linkedContractId != contractId) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  RentalContractRecord? _linkedContractForPmBill(BillRecord bill) {
    final String contractId = (bill.rentalContractId ?? '').trim();
    if (contractId.isNotEmpty) {
      final RentalContractRecord? contract = _pmContractsById[contractId];
      if (contract != null) {
        return contract;
      }
    }
    return _findMatchingPmContract(bill);
  }

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  static int? _readPropertyOptionInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static String _readPropertyOptionString(List<dynamic> values) {
    for (final dynamic value in values) {
      final String text = '${value ?? ''}'.trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  static String _propertyOptionSubtypeLabel(Map<String, dynamic> property) {
    final String explicit = _readPropertyOptionString(<dynamic>[
      property['Flat_Type_Label'],
      property['Property_Sub_Type_Label'],
      property['Sub_Type_Label'],
    ]);
    if (explicit.isNotEmpty) {
      return explicit;
    }

    final int? flatType = _readPropertyOptionInt(property['Flat_Type']);
    if (flatType != null) {
      return _propertyFlatTypeLabels[flatType] ?? '';
    }

    final int? propertyType = _readPropertyOptionInt(property['Property_Type']);
    final int? subType = _readPropertyOptionInt(property['Sub_Type']);
    if (propertyType == null || subType == null) {
      return '';
    }
    return _propertySubtypeLabels[propertyType]?[subType] ?? '';
  }

  static String _propertyOptionDropdownLabel(Map<String, dynamic> property) {
    final String title = _readPropertyOptionString(<dynamic>[
      property['Property_Title'],
      property['Title'],
      property['Name'],
    ]);
    final String resolvedTitle = title.isEmpty ? 'Untitled' : title;
    final String subtype = _propertyOptionSubtypeLabel(property);
    if (subtype.isEmpty) {
      return resolvedTitle;
    }
    return '$resolvedTitle - $subtype';
  }

  static String _contractOptionDropdownLabel(RentalContractRecord contract) {
    final String tenant = contract.tenantName.trim();
    final String property = contract.propertyTitle.trim();
    final String flatType = (contract.flatType ?? '').trim();
    final String propertyLabel = flatType.isEmpty
        ? property
        : '$property - $flatType';
    if (tenant.isEmpty) {
      return propertyLabel;
    }
    return '$tenant - $propertyLabel';
  }

  Future<void> _loadPmProperties() async {
    try {
      final result = await PropertyService.filterPropertiesLite(limit: 200);
      if (!mounted) return;
      setState(() {
        _pmProperties = result.properties.map((Map<String, dynamic> p) {
          return <String, String>{
            'id': (p['PropertyID'] ?? p['_id'] ?? '').toString(),
            'label': _propertyOptionDropdownLabel(p),
          };
        }).toList();
      });
    } catch (_) {}
  }

  void _handlePmSearchChanged(String value) {
    setState(() {
      _pmSkip = 0;
    });
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), _loadPmBills);
  }

  Widget _buildPmExportMenu(ThemeData theme, List<BillRecord> bills) {
    return PopupMenuButton<String>(
      onSelected: (String value) async {
        if (value == 'pdf') {
          await _openBillsReportPdfPreview(bills);
          return;
        }
        if (value == 'excel') {
          RentalBillsExcelService.exportToExcel(
            bills: bills,
            pendingAmount: _pmPendingAmount,
            collectedAmount: _pmCollectedAmount,
            overdueAmount: _pmOverdueAmount,
            todayCollection: _pmTodayCollection,
            monthCollection: _pmMonthCollection,
            monthOverdue: _pmMonthOverdue,
            monthPending: _pmMonthPending,
            totalSecurityBill: _pmTotalSecurityBill,
            pendingSecurity: _pmPendingSecurity,
            collectedSecurity: _pmCollectedSecurity,
          );
        }
      },
      itemBuilder: (BuildContext ctx) => const <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'pdf',
          child: Row(
            children: <Widget>[
              Icon(Icons.picture_as_pdf_outlined, size: 18),
              SizedBox(width: 8),
              Text('Export PDF'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'excel',
          child: Row(
            children: <Widget>[
              Icon(Icons.table_chart_outlined, size: 18),
              SizedBox(width: 8),
              Text('Export Excel'),
            ],
          ),
        ),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.file_download_outlined,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Export Report',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    const List<String> monthNames = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final String currentMonth = monthNames[DateTime.now().month - 1];
    final List<BillRecord> sourceBills = _usesPmFlow
        ? _pmBills
        : (_usesTenantWebsiteFlow
              ? _tenantBills
              : (_usesSocietyFlow ? _societyBills : widget.bills));

    // Society, PM, and tenant flows apply server-side filtering; others filter locally.
    final List<BillRecord> visibleBills =
        (_usesPmFlow || _usesTenantWebsiteFlow || _usesSocietyFlow)
        ? sourceBills
        : sourceBills.where((BillRecord bill) {
            return _selectedFilter == null || bill.status == _selectedFilter;
          }).toList();

    final bool canGenerateBills = widget.role.isSocietyScope;

    if (!widget.role.supportsBilling) {
      return ListView(
        padding: AppTheme.pagePadding,
        children: <Widget>[
          PageHeader(
            title: widget.role.billingSectionTitle,
            description:
                'This role does not use the billing module in the current website navigation.',
          ),
          const SizedBox(height: 16),
          const CustomCard(
            child: Text(
              'Billing stays hidden for this role until the website feature is relevant.',
            ),
          ),
        ],
      );
    }

    final int pendingCount = sourceBills
        .where((BillRecord bill) => bill.status == BillStatus.pending)
        .length;
    final int overdueCount = sourceBills
        .where((BillRecord bill) => bill.status == BillStatus.overdue)
        .length;
    final double totalAmount = sourceBills.fold<double>(
      0,
      (double sum, BillRecord bill) => sum + bill.amount,
    );
    final int pmShowingStart = _pmTotalCount == 0 ? 0 : _pmSkip + 1;
    final int pmShowingEnd = _pmSkip + _pmBills.length > _pmTotalCount
        ? _pmTotalCount
        : _pmSkip + _pmBills.length;

    final bool isBusy = _usesPmFlow
        ? _isPmLoading
        : (_usesTenantWebsiteFlow
              ? _isLoadingTenantBills
              : (_usesSocietyFlow ? _isSocietyLoading : widget.isLoading));
    final String? activeError = _usesPmFlow
        ? _pmError
        : (_usesTenantWebsiteFlow
              ? _tenantError
              : (_usesSocietyFlow ? _societyError : null));

    final List<BillStatus> filterableStatuses = _usesTenantWebsiteFlow
        ? <BillStatus>[BillStatus.pending, BillStatus.paid, BillStatus.overdue]
        : BillStatus.values;

    Widget content = ListView(
      padding: AppTheme.pagePadding,
      children: <Widget>[
        if (_usesPmFlow) ...<Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget? exportMenu = sourceBills.isNotEmpty
                  ? _buildPmExportMenu(theme, sourceBills)
                  : null;
              const PageHeader header = PageHeader(
                title: 'Rental Bills Management',
                description:
                    'Manage and track rental bills for your properties',
              );

              if (exportMenu == null) {
                return header;
              }
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    header,
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: exportMenu),
                  ],
                );
              }

              return PageHeader(
                title: 'Rental Bills Management',
                description:
                    'Manage and track rental bills for your properties',
                trailing: exportMenu,
              );
            },
          ),
        ] else ...<Widget>[
          PageHeader(
            title: widget.role.billingSectionTitle,
            description: _usesTenantWebsiteFlow
                ? 'Search, review, and pay tenant bills using the same website tenant flow.'
                : 'View maintenance and rent records connected to the live backend.',
          ),
        ],
        const SizedBox(height: 16),

        // ── Summary cards ────────────────────────────────────────────────────
        if (_usesPmFlow) ...<Widget>[
          SizedBox(
            height: 104,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                _PmMetricCard(
                  label: 'Total Pending',
                  value: _compactRs(_pmPendingAmount),
                  color: const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 12),
                _PmMetricCard(
                  label: 'Total Collected',
                  value: _compactRs(_pmCollectedAmount),
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(width: 12),
                _PmMetricCard(
                  label: 'Total Overdue',
                  value: _compactRs(_pmOverdueAmount),
                  color: const Color(0xFFEF4444),
                ),
                const SizedBox(width: 12),
                _PmMetricCard(
                  label: "Today's Collection",
                  value: _compactRs(_pmTodayCollection),
                  color: const Color(0xFF2563EB),
                ),
                const SizedBox(width: 12),
                _PmMetricCard(
                  label: '$currentMonth Collection',
                  value: _compactRs(_pmMonthCollection),
                  color: const Color(0xFF059669),
                ),
                const SizedBox(width: 12),
                _PmMetricCard(
                  label: '$currentMonth Overdue',
                  value: _compactRs(_pmMonthOverdue),
                  color: const Color(0xFFE11D48),
                ),
                const SizedBox(width: 12),
                _PmMetricCard(
                  label: '$currentMonth Pending',
                  value: _compactRs(_pmMonthPending),
                  color: const Color(0xFFD97706),
                ),
                const SizedBox(width: 12),
                _PmMetricCard(
                  label: 'Total Security Bill',
                  value: _compactRs(_pmTotalSecurityBill),
                  color: const Color(0xFF7C3AED),
                ),
                const SizedBox(width: 12),
                _PmMetricCard(
                  label: 'Pending Security',
                  value: _compactRs(_pmPendingSecurity),
                  color: const Color(0xFFEA580C),
                ),
                const SizedBox(width: 12),
                _PmMetricCard(
                  label: 'Collected Security',
                  value: _compactRs(_pmCollectedSecurity),
                  color: const Color(0xFF16A34A),
                ),
              ],
            ),
          ),
        ] else if (_usesSocietyFlow) ...<Widget>[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _SummaryCard(
                label: 'Total Pending',
                value: _compactRs(_societyPendingAmount),
                tone: UiTone.warning,
              ),
              _SummaryCard(
                label: 'Total Collected',
                value: _compactRs(_societyCollectedAmount),
                tone: UiTone.success,
              ),
              _SummaryCard(
                label: 'Total Overdue',
                value: _compactRs(_societyOverdueAmount),
                tone: UiTone.danger,
              ),
              _SummaryCard(
                label: "Today's Collection",
                value: _compactRs(_societyTodayCollection),
                tone: UiTone.brand,
              ),
              _SummaryCard(
                label: '$currentMonth Collected',
                value: _compactRs(_societyMonthCollection),
                tone: UiTone.success,
              ),
              _SummaryCard(
                label: '$currentMonth Overdue',
                value: _compactRs(_societyMonthOverdue),
                tone: UiTone.danger,
              ),
              _SummaryCard(
                label: '$currentMonth Pending',
                value: _compactRs(_societyMonthPending),
                tone: UiTone.warning,
              ),
            ],
          ),
        ] else ...<Widget>[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              if (_usesTenantWebsiteFlow) ...<Widget>[
                _SummaryCard(
                  label: 'Pending To Pay',
                  value: 'Rs ${_tenantPendingAmount.toStringAsFixed(0)}',
                  tone: UiTone.warning,
                ),
                _SummaryCard(
                  label: 'Total Paid',
                  value: 'Rs ${_tenantPaidAmount.toStringAsFixed(0)}',
                  tone: UiTone.success,
                ),
                _SummaryCard(
                  label: 'Overdue To Pay',
                  value: 'Rs ${_tenantOverdueAmount.toStringAsFixed(0)}',
                  tone: UiTone.danger,
                ),
              ] else ...<Widget>[
                _SummaryCard(
                  label: 'Records',
                  value: '${sourceBills.length}',
                  tone: UiTone.brand,
                ),
                _SummaryCard(
                  label: 'Pending',
                  value: '$pendingCount',
                  tone: UiTone.warning,
                ),
                _SummaryCard(
                  label: 'Overdue',
                  value: '$overdueCount',
                  tone: UiTone.danger,
                ),
                _SummaryCard(
                  label: 'Total',
                  value: 'Rs ${totalAmount.toStringAsFixed(0)}',
                  tone: UiTone.success,
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 16),

        // ── Filters ──────────────────────────────────────────────────────────
        if (_usesPmFlow) ...<Widget>[
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by tenant, owner, property title...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _pmSkip = 0;
                        });
                        _loadPmBills();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: _handlePmSearchChanged,
            onSubmitted: (_) => _loadPmBills(),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _pmPropertyId,
                  decoration: InputDecoration(
                    labelText: 'Property',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  isExpanded: true,
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Properties'),
                    ),
                    ..._pmProperties.map(
                      (Map<String, String> p) => DropdownMenuItem<String?>(
                        value: p['id'],
                        child: Text(
                          p['label']!,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (String? value) {
                    setState(() {
                      _pmPropertyId = value;
                      _pmContractId = null;
                      _pmSkip = 0;
                    });
                    _loadPmBills();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _pmContractId,
                  decoration: InputDecoration(
                    labelText: 'Contract',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  isExpanded: true,
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Contracts'),
                    ),
                    ..._pmContracts.map(
                      (Map<String, String> c) => DropdownMenuItem<String?>(
                        value: c['id'],
                        child: Text(
                          c['label']!,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (String? value) {
                    setState(() {
                      _pmContractId = value;
                      _pmSkip = 0;
                    });
                    _loadPmBills();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<BillStatus?>(
            value: _selectedFilter,
            decoration: InputDecoration(
              labelText: 'Status',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            items: <DropdownMenuItem<BillStatus?>>[
              const DropdownMenuItem<BillStatus?>(
                value: null,
                child: Text('All Status'),
              ),
              ...<BillStatus>[
                BillStatus.pending,
                BillStatus.paid,
                BillStatus.overdue,
              ].map(
                (BillStatus s) => DropdownMenuItem<BillStatus?>(
                  value: s,
                  child: Text(s.label),
                ),
              ),
            ],
            onChanged: (BillStatus? value) {
              setState(() {
                _selectedFilter = value;
                _pmSkip = 0;
              });
              _loadPmBills();
            },
          ),
          const SizedBox(height: 12),
        ],
        if (_usesTenantWebsiteFlow) ...<Widget>[
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search bills',
              hintText: 'Search by bill details',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _loadTenantBills();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
            onChanged: _handleTenantSearchChanged,
            onSubmitted: (_) => _loadTenantBills(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            value: _billTypeFilter,
            decoration: const InputDecoration(labelText: 'Bill Type'),
            items: const <DropdownMenuItem<int?>>[
              DropdownMenuItem<int?>(value: null, child: Text('All Types')),
              DropdownMenuItem<int?>(value: 1, child: Text('Maintenance')),
              DropdownMenuItem<int?>(value: 2, child: Text('Rental')),
            ],
            onChanged: (int? value) {
              setState(() {
                _billTypeFilter = value;
              });
              _loadTenantBills();
            },
          ),
          const SizedBox(height: 16),
        ],
        if (_usesSocietyFlow) ...<Widget>[
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search bills',
              hintText: 'Resident name, flat no…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _societySkip = 0;
                        });
                        _loadSocietyBills();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
            onChanged: _handleSocietySearchChanged,
            onSubmitted: (_) {
              setState(() {
                _societySkip = 0;
              });
              _loadSocietyBills();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            value: _societyBillTypeFilter,
            decoration: const InputDecoration(labelText: 'Bill Type'),
            items: const <DropdownMenuItem<int?>>[
              DropdownMenuItem<int?>(value: null, child: Text('All Types')),
              DropdownMenuItem<int?>(value: 1, child: Text('Maintenance')),
              DropdownMenuItem<int?>(value: 2, child: Text('Rental')),
            ],
            onChanged: (int? value) {
              setState(() {
                _societyBillTypeFilter = value;
                _societySkip = 0;
              });
              _loadSocietyBills();
            },
          ),
          if (_societyBlocks.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _societyBlockFilter.isEmpty ? null : _societyBlockFilter,
              decoration: const InputDecoration(labelText: 'Block'),
              isExpanded: true,
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Blocks'),
                ),
                ..._societyBlocks.map(
                  (BlockData b) => DropdownMenuItem<String?>(
                    value: b.blockId,
                    child: Text(b.name),
                  ),
                ),
              ],
              onChanged: (String? value) {
                setState(() {
                  _societyBlockFilter = value ?? '';
                  _societyBuildingFilter = '';
                  _societySkip = 0;
                });
                _loadSocietyBills();
              },
            ),
          ],
          if (_societyBuildings.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _societyBuildingFilter.isEmpty
                  ? null
                  : _societyBuildingFilter,
              decoration: const InputDecoration(labelText: 'Building'),
              isExpanded: true,
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Buildings'),
                ),
                ...(_societyBlockFilter.isEmpty
                        ? _societyBuildings
                        : _societyBuildings
                              .where(
                                (BuildingData b) =>
                                    b.blockId == _societyBlockFilter,
                              )
                              .toList())
                    .map(
                      (BuildingData b) => DropdownMenuItem<String?>(
                        value: b.buildingId,
                        child: Text(b.name),
                      ),
                    ),
              ],
              onChanged: (String? value) {
                setState(() {
                  _societyBuildingFilter = value ?? '';
                  _societySkip = 0;
                });
                _loadSocietyBills();
              },
            ),
          ],
          const SizedBox(height: 16),
        ],

        // ── Generate Bills + Export ──────────────────────────────────────────
        if (canGenerateBills) ...<Widget>[
          CustomCard(
            padding: CustomCardPadding.sm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Generate maintenance bills for the linked society account.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    if (_usesSocietyFlow && sourceBills.isNotEmpty) ...<Widget>[
                      CustomButton(
                        label: 'Export PDF',
                        variant: CustomButtonVariant.outline,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        onPressed: _exportSocietyBillsPdf,
                      ),
                      CustomButton(
                        label: 'Export Excel',
                        variant: CustomButtonVariant.outline,
                        icon: const Icon(Icons.table_chart_outlined),
                        onPressed: () => SocietyBillsExcelService.exportToExcel(
                          bills: sourceBills,
                          pendingAmount: _societyPendingAmount,
                          collectedAmount: _societyCollectedAmount,
                          overdueAmount: _societyOverdueAmount,
                          todayCollection: _societyTodayCollection,
                          monthCollection: _societyMonthCollection,
                          monthOverdue: _societyMonthOverdue,
                          monthPending: _societyMonthPending,
                        ),
                      ),
                    ],
                    CustomButton(
                      label: 'Generate Bills',
                      icon: const Icon(Icons.auto_awesome_outlined),
                      onPressed: _generateBills,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Status tabs ──────────────────────────────────────────────────────
        if (!_usesPmFlow && !_usesSocietyFlow) ...<Widget>[
          CustomTabBar(
            style: CustomTabBarStyle.pill,
            currentIndex: _selectedFilter == null
                ? 0
                : filterableStatuses.indexOf(_selectedFilter!) + 1,
            onChanged: (int index) {
              setState(() {
                _selectedFilter = index == 0
                    ? null
                    : filterableStatuses[index - 1];
              });
            },
            tabs: <CustomTabItem>[
              const CustomTabItem(label: 'All'),
              ...filterableStatuses.map(
                (BillStatus status) => CustomTabItem(label: status.label),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        // PM status filter is handled via dropdown above; no tab bar needed.
        if (_usesSocietyFlow) ...<Widget>[
          CustomTabBar(
            style: CustomTabBarStyle.pill,
            currentIndex: _societyStatusFilter == null
                ? 0
                : BillStatus.values.indexOf(_societyStatusFilter!) + 1,
            onChanged: (int index) {
              setState(() {
                _societyStatusFilter = index == 0
                    ? null
                    : BillStatus.values[index - 1];
                _societySkip = 0;
              });
              _loadSocietyBills();
            },
            tabs: <CustomTabItem>[
              const CustomTabItem(label: 'All'),
              ...BillStatus.values.map(
                (BillStatus s) => CustomTabItem(label: s.label),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // ── Loading / error / empty ──────────────────────────────────────────
        if (isBusy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!isBusy && activeError != null)
          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Unable to load bills',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  activeError,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                CustomButton(
                  label: 'Retry',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () {
                    if (_usesPmFlow) {
                      _loadPmBills();
                      return;
                    }
                    if (_usesTenantWebsiteFlow) {
                      _loadTenantBills();
                      return;
                    }
                    widget.onRefresh?.call();
                  },
                ),
              ],
            ),
          ),
        if (!isBusy && activeError == null && visibleBills.isEmpty)
          const CustomCard(
            padding: CustomCardPadding.sm,
            child: Text('No bills match this filter.'),
          ),

        // ── Bill cards ───────────────────────────────────────────────────────
        ...visibleBills.map((BillRecord bill) {
          if (_usesPmFlow) {
            return _buildPmBillCard(bill, theme);
          }
          if (_usesSocietyFlow) {
            return _buildSocietyBillCard(bill, theme);
          }
          return _buildDefaultBillCard(bill, theme);
        }),

        // ── Society pagination ───────────────────────────────────────────────
        if (_usesPmFlow && _pmTotalCount > _pmPageSize) ...<Widget>[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextButton.icon(
                onPressed: _pmSkip == 0
                    ? null
                    : () {
                        setState(() {
                          _pmSkip = (_pmSkip - _pmPageSize).clamp(0, _pmSkip);
                        });
                        _loadPmBills();
                      },
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('Prev'),
              ),
              Text(
                'Showing $pmShowingStart-$pmShowingEnd of $_pmTotalCount',
                style: theme.textTheme.bodyMedium,
              ),
              TextButton.icon(
                onPressed: _pmSkip + _pmPageSize >= _pmTotalCount
                    ? null
                    : () {
                        setState(() {
                          _pmSkip += _pmPageSize;
                        });
                        _loadPmBills();
                      },
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text('Next'),
              ),
            ],
          ),
        ],

        if (_usesSocietyFlow &&
            _societyTotalCount > _societyPageSize) ...<Widget>[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextButton.icon(
                onPressed: _societySkip == 0
                    ? null
                    : () {
                        setState(() {
                          _societySkip = (_societySkip - _societyPageSize)
                              .clamp(0, _societySkip);
                        });
                        _loadSocietyBills();
                      },
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('Prev'),
              ),
              Text(
                'Showing ${_societySkip + 1}–${_societySkip + _societyBills.length} of $_societyTotalCount',
                style: theme.textTheme.bodyMedium,
              ),
              TextButton.icon(
                onPressed: _societySkip + _societyPageSize >= _societyTotalCount
                    ? null
                    : () {
                        setState(() {
                          _societySkip += _societyPageSize;
                        });
                        _loadSocietyBills();
                      },
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text('Next'),
              ),
            ],
          ),
        ],
      ],
    );

    if (widget.onRefresh != null || _usesPmFlow || _usesSocietyFlow) {
      content = RefreshIndicator(
        onRefresh: () async {
          if (_usesPmFlow) {
            await _loadPmBills();
            return;
          }
          if (_usesSocietyFlow) {
            setState(() {
              _societySkip = 0;
            });
            await _loadSocietyBills();
            return;
          }
          if (_usesTenantWebsiteFlow) {
            await _loadTenantBills();
          }
          widget.onRefresh?.call();
        },
        child: content,
      );
    }

    return content;
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  Future<void> _generateBills() async {
    try {
      if (widget.role == AppRole.propertyManager) {
        await _openPmGenerateBillsSheet();
        return;
      }
      if (!widget.role.isSocietyScope || _societyId.isEmpty) {
        _showMessage(
          'Linked society or property information is not available.',
        );
        return;
      }
      final response = await BillingService.generateSocietyBills(_societyId);
      if (!response.success) {
        throw Exception(
          response.message ??
              response.status ??
              'Unable to generate society bills.',
        );
      }
      _showMessage(
        response.status ?? response.message ?? 'Society bills generated.',
      );
      if (_usesPmFlow) {
        await _loadPmBills();
      } else if (_usesSocietyFlow) {
        await _reloadSocietyBillsAfterGeneration();
      } else {
        widget.onRefresh?.call();
      }
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _reloadSocietyBillsAfterGeneration() async {
    if (!_usesSocietyFlow || _societyId.isEmpty) {
      return;
    }
    if (mounted) {
      setState(() {
        _societySkip = 0;
      });
    }

    await _loadSocietyBills();

    // The live API can return success before async bill creation is visible.
    // Poll a few times so newly generated bills appear without leaving screen.
    const List<Duration> retryDelays = <Duration>[
      Duration(milliseconds: 800),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ];
    for (final Duration delay in retryDelays) {
      if (!mounted) {
        return;
      }
      await Future.delayed(delay);
      if (!mounted) {
        return;
      }
      await _loadSocietyBills();
    }
  }

  Future<void> _openPmGenerateBillsSheet() async {
    if (_pmProperties.isEmpty) {
      await _loadPmProperties();
    }
    if (!mounted) {
      return;
    }
    if (_pmProperties.isEmpty) {
      _showMessage('No properties are available for bill generation.');
      return;
    }

    String? selectedPropertyId =
        _pmPropertyId ??
        (_pmProperties.length == 1 ? _pmProperties.first['id'] : null);
    bool? whetherPaid;
    bool isGenerating = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  top: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Generate Rental Bills',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select a property and whether the generated bills are already paid.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedPropertyId,
                      decoration: const InputDecoration(labelText: 'Property'),
                      isExpanded: true,
                      items: _pmProperties
                          .map(
                            (Map<String, String> property) =>
                                DropdownMenuItem<String>(
                                  value: property['id'],
                                  child: Text(
                                    property['label'] ?? 'Untitled',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                          )
                          .toList(),
                      onChanged: isGenerating
                          ? null
                          : (String? value) {
                              setModalState(() {
                                selectedPropertyId = value;
                              });
                            },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Has this bill already been paid?',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('No'),
                            selected: whetherPaid == false,
                            onSelected: isGenerating
                                ? null
                                : (_) {
                                    setModalState(() {
                                      whetherPaid = false;
                                    });
                                  },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Yes'),
                            selected: whetherPaid == true,
                            onSelected: isGenerating
                                ? null
                                : (_) {
                                    setModalState(() {
                                      whetherPaid = true;
                                    });
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: CustomButton(
                            label: 'Cancel',
                            variant: CustomButtonVariant.outline,
                            onPressed: isGenerating
                                ? null
                                : () => Navigator.of(sheetContext).pop(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CustomButton(
                            label: isGenerating ? 'Generating...' : 'Generate',
                            icon: isGenerating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome_outlined),
                            onPressed:
                                selectedPropertyId == null ||
                                    whetherPaid == null ||
                                    isGenerating
                                ? null
                                : () async {
                                    setModalState(() {
                                      isGenerating = true;
                                    });
                                    try {
                                      await BillingService.generatePropertyBills(
                                        selectedPropertyId!,
                                        whetherPaid: whetherPaid!,
                                      );
                                      if (!sheetContext.mounted) {
                                        return;
                                      }
                                      Navigator.of(sheetContext).pop();
                                      _showMessage(
                                        'Bill generation request submitted.',
                                      );
                                      await _loadPmBills();
                                    } catch (error) {
                                      setModalState(() {
                                        isGenerating = false;
                                      });
                                      _showMessage(
                                        error.toString().replaceFirst(
                                          'Exception: ',
                                          '',
                                        ),
                                      );
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleBillAction(BillRecord bill) async {
    try {
      if (widget.role.isResidentScope || widget.role == AppRole.owner) {
        final response = await BillingService.collectBillPayment(
          bill.id,
          paymentType: 2,
        );

        if (!response.success) {
          throw Exception(
            response.message ?? response.status ?? 'Unable to start payment.',
          );
        }

        final String orderId =
            response.extras['Razorpay_Order_ID'] as String? ?? '';
        if (orderId.isNotEmpty) {
          final RazorpayCheckoutResult checkoutResult =
              await RazorpayCheckoutService.openCheckout(
                keyId: response.extras['Razorpay_Key_ID'] as String? ?? '',
                amountInPaise:
                    (response.extras['Amount_In_Paise'] as num?)?.toInt() ??
                    (((response.extras['Amount'] as num?) ?? bill.amount) * 100)
                        .round(),
                name: 'Urban Easy Flats',
                description: bill.title,
                orderId: orderId,
                currency: response.extras['Currency'] as String? ?? 'INR',
                prefillName: _vendor?.fullName,
                prefillEmail: _vendor?.email,
                prefillContact: _vendor?.phone,
              );

          if (!checkoutResult.success) {
            throw Exception(
              checkoutResult.message ?? 'Payment was not completed.',
            );
          }

          _showMessage('Payment completed. Confirmation is being processed.');
        } else {
          _showMessage(
            response.message ?? response.status ?? 'Payment request submitted.',
          );
        }
      } else {
        await BillingService.sendBillWhatsAppReminder(bill.id);
        _showMessage('Reminder sent successfully.');
      }
      if (_usesPmFlow) {
        await _loadPmBills();
      } else if (_usesTenantWebsiteFlow) {
        await _loadTenantBills();
      } else if (_usesSocietyFlow) {
        await _loadSocietyBills();
      }
      widget.onRefresh?.call();
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openBillDetails(BillRecord bill) async {
    try {
      final BillRecord? fullBill = await BillingService.fetchBillInfo(bill.id);
      // Merge: use fullBill for detailed payment fields, but fall back to
      // the original list-level bill for context fields (name, phone, email,
      // unit, property, owner) that fetchBillInfo may not return.
      final BillRecord activeBill = fullBill != null
          ? BillRecord(
              id: fullBill.id,
              title: fullBill.title,
              unitLabel: fullBill.unitLabel != 'N/A'
                  ? fullBill.unitLabel
                  : bill.unitLabel,
              amount: fullBill.amount,
              dueDate: fullBill.dueDate,
              status: fullBill.status,
              category: fullBill.category,
              note: fullBill.note ?? bill.note,
              billTypeCode: fullBill.billTypeCode ?? bill.billTypeCode,
              finalAmount: fullBill.finalAmount ?? bill.finalAmount,
              billDate: fullBill.billDate ?? bill.billDate,
              paidDate: fullBill.paidDate ?? bill.paidDate,
              paymentType: fullBill.paymentType ?? bill.paymentType,
              manualOnlinePaymentMode:
                  fullBill.manualOnlinePaymentMode ??
                  bill.manualOnlinePaymentMode,
              paymentNote: fullBill.paymentNote ?? bill.paymentNote,
              billAmount: fullBill.billAmount ?? bill.billAmount,
              maintenanceAmount:
                  fullBill.maintenanceAmount ?? bill.maintenanceAmount,
              tokenAmount: fullBill.tokenAmount ?? bill.tokenAmount,
              paymentImageUrl: fullBill.paymentImageUrl ?? bill.paymentImageUrl,
              tenantImageUrl: fullBill.tenantImageUrl ?? bill.tenantImageUrl,
              rentalContractId:
                  fullBill.rentalContractId ?? bill.rentalContractId,
              propertyId: fullBill.propertyId ?? bill.propertyId,
              unitType: (fullBill.unitType ?? '').isNotEmpty
                  ? fullBill.unitType
                  : bill.unitType,
              walletCredited: fullBill.walletCredited ?? bill.walletCredited,
              walletCreditTime:
                  fullBill.walletCreditTime ?? bill.walletCreditTime,
              walletCreditedTime:
                  fullBill.walletCreditedTime ?? bill.walletCreditedTime,
              residentName: (fullBill.residentName ?? '').isNotEmpty
                  ? fullBill.residentName
                  : bill.residentName,
              residentPhone: (fullBill.residentPhone ?? '').isNotEmpty
                  ? fullBill.residentPhone
                  : bill.residentPhone,
              residentEmail: (fullBill.residentEmail ?? '').isNotEmpty
                  ? fullBill.residentEmail
                  : bill.residentEmail,
              residentTypeLabel:
                  fullBill.residentTypeLabel ?? bill.residentTypeLabel,
              societyName: (fullBill.societyName ?? '').isNotEmpty
                  ? fullBill.societyName
                  : bill.societyName,
              blockName: (fullBill.blockName ?? '').isNotEmpty
                  ? fullBill.blockName
                  : bill.blockName,
              buildingName: (fullBill.buildingName ?? '').isNotEmpty
                  ? fullBill.buildingName
                  : bill.buildingName,
              propertyTitle: (fullBill.propertyTitle ?? '').isNotEmpty
                  ? fullBill.propertyTitle
                  : bill.propertyTitle,
              ownerName: (fullBill.ownerName ?? '').isNotEmpty
                  ? fullBill.ownerName
                  : bill.ownerName,
              ownerPhone: (fullBill.ownerPhone ?? '').isNotEmpty
                  ? fullBill.ownerPhone
                  : bill.ownerPhone,
              ownerEmail: (fullBill.ownerEmail ?? '').isNotEmpty
                  ? fullBill.ownerEmail
                  : bill.ownerEmail,
              contractStartDate:
                  fullBill.contractStartDate ?? bill.contractStartDate,
              contractEndDate: fullBill.contractEndDate ?? bill.contractEndDate,
              rentAmount: fullBill.rentAmount ?? bill.rentAmount,
              depositAmount: fullBill.depositAmount ?? bill.depositAmount,
              vacateDate: fullBill.vacateDate ?? bill.vacateDate,
            )
          : bill;
      if (!mounted) {
        return;
      }

      showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          final bool canRecordPayment =
              !(widget.role.isResidentScope || widget.role == AppRole.owner) &&
              activeBill.status != BillStatus.paid;
          final ThemeData theme = Theme.of(context);
          final String? localPaymentProofPath =
              _localPaymentProofPathFor(activeBill) ??
              _localPaymentProofPathFor(bill);
          return AlertDialog(
            title: Text(activeBill.title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ToneBadge(
                        label: activeBill.status.label,
                        tone: activeBill.status.tone,
                      ),
                      ToneBadge(
                        label: activeBill.category,
                        tone: UiTone.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if ((activeBill.residentName ?? '').isNotEmpty ||
                      (activeBill.residentPhone ?? '').isNotEmpty ||
                      (activeBill.residentEmail ?? '').isNotEmpty ||
                      (activeBill.propertyTitle ?? '').isNotEmpty ||
                      (activeBill.ownerName ?? '').isNotEmpty ||
                      (activeBill.unitLabel.isNotEmpty &&
                          activeBill.unitLabel != 'N/A')) ...<Widget>[
                    Text(
                      'Bill Context',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if ((activeBill.residentName ?? '').isNotEmpty)
                      _DetailLine(
                        label: _usesPmFlow ? 'Tenant' : 'Resident',
                        value: activeBill.residentName!,
                      ),
                    if ((activeBill.residentPhone ?? '').isNotEmpty)
                      _DetailLine(
                        label: 'Phone',
                        value: activeBill.residentPhone!,
                      ),
                    if ((activeBill.residentEmail ?? '').isNotEmpty)
                      _DetailLine(
                        label: 'Email',
                        value: activeBill.residentEmail!,
                      ),
                    if ((activeBill.societyName ?? '').isNotEmpty)
                      _DetailLine(
                        label: 'Society',
                        value: activeBill.societyName!,
                      ),
                    if ((activeBill.blockName ?? '').isNotEmpty)
                      _DetailLine(label: 'Block', value: activeBill.blockName!),
                    if ((activeBill.buildingName ?? '').isNotEmpty)
                      _DetailLine(
                        label: 'Building',
                        value: activeBill.buildingName!,
                      ),
                    if ((activeBill.propertyTitle ?? '').isNotEmpty)
                      _DetailLine(
                        label: 'Property',
                        value: activeBill.propertyTitle!,
                      ),
                    if (activeBill.unitLabel.isNotEmpty &&
                        activeBill.unitLabel != 'N/A')
                      _DetailLine(
                        label: 'Flat / Unit No',
                        value: activeBill.unitLabel,
                      ),
                    if ((activeBill.ownerName ?? '').isNotEmpty)
                      _DetailLine(label: 'Owner', value: activeBill.ownerName!),
                    if ((activeBill.ownerPhone ?? '').isNotEmpty)
                      _DetailLine(
                        label: 'Owner Phone',
                        value: activeBill.ownerPhone!,
                      ),
                    if ((activeBill.ownerEmail ?? '').isNotEmpty)
                      _DetailLine(
                        label: 'Owner Email',
                        value: activeBill.ownerEmail!,
                      ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Bill Details',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _DetailLine(label: 'Unit', value: activeBill.unitLabel),
                  _DetailLine(label: 'Category', value: activeBill.category),
                  _DetailLine(
                    label: 'Final Amount',
                    value:
                        'Rs ${(activeBill.finalAmount ?? activeBill.amount).toStringAsFixed(0)}',
                  ),
                  // Bill type 3 = Security Deposit, 2 = Rental Amount
                  if (activeBill.billAmount != null)
                    _DetailLine(
                      label: activeBill.billTypeCode == 3
                          ? 'Security Deposit Amount'
                          : 'Bill Amount',
                      value: 'Rs ${activeBill.billAmount!.toStringAsFixed(0)}',
                    ),
                  if (activeBill.maintenanceAmount != null &&
                      activeBill.billTypeCode != 3)
                    _DetailLine(
                      label: 'Maintenance',
                      value:
                          'Rs ${activeBill.maintenanceAmount!.toStringAsFixed(0)}',
                    ),
                  if (activeBill.tokenAmount != null)
                    _DetailLine(
                      label: 'Token Amount',
                      value: 'Rs ${activeBill.tokenAmount!.toStringAsFixed(0)}',
                    ),
                  // Show Monthly Rent only for rental bills, not security deposit
                  if (activeBill.rentAmount != null &&
                      activeBill.billTypeCode != 3)
                    _DetailLine(
                      label: 'Monthly Rent',
                      value: 'Rs ${activeBill.rentAmount!.toStringAsFixed(0)}',
                    ),
                  // Show Security Deposit from contract only for non-security-deposit bills
                  if (activeBill.depositAmount != null &&
                      activeBill.billTypeCode != 3)
                    _DetailLine(
                      label: 'Security Deposit',
                      value:
                          'Rs ${activeBill.depositAmount!.toStringAsFixed(0)}',
                    ),
                  if (activeBill.billDate != null)
                    _DetailLine(
                      label: 'Bill Date',
                      value: formatCompactDate(activeBill.billDate!),
                    ),
                  _DetailLine(
                    label: 'Due Date',
                    value: formatCompactDate(activeBill.dueDate),
                  ),
                  if (activeBill.paidDate != null)
                    _DetailLine(
                      label: 'Paid Date',
                      value: formatCompactDate(activeBill.paidDate!),
                    ),
                  if (activeBill.paymentType != null)
                    _DetailLine(
                      label: 'Payment Mode',
                      value: _paymentTypeLabel(activeBill.paymentType!),
                    ),
                  if (activeBill.manualOnlinePaymentMode != null)
                    _DetailLine(
                      label: 'Online Mode',
                      value: _manualOnlinePaymentModeLabel(
                        activeBill.manualOnlinePaymentMode!,
                      ),
                    ),
                  if ((activeBill.paymentNote ?? '').isNotEmpty)
                    _DetailLine(
                      label: 'Payment Note',
                      value: activeBill.paymentNote!,
                    ),
                  if (activeBill.contractStartDate != null &&
                      activeBill.contractEndDate != null)
                    _DetailLine(
                      label: 'Contract',
                      value:
                          '${formatCompactDate(activeBill.contractStartDate!)} to ${formatCompactDate(activeBill.contractEndDate!)}',
                    ),
                  if (activeBill.vacateDate != null)
                    _DetailLine(
                      label: 'Vacate Date',
                      value: formatCompactDate(activeBill.vacateDate!),
                    ),
                  if (activeBill.walletCredited != null) ...<Widget>[
                    const SizedBox(height: 12),
                    _DetailLine(
                      label: 'Wallet Credit',
                      value: activeBill.walletCredited!
                          ? 'Credited'
                          : 'Pending',
                    ),
                    if (activeBill.walletCreditTime != null)
                      _DetailLine(
                        label: 'Credit Initiated',
                        value:
                            '${formatCompactDate(activeBill.walletCreditTime!)} ${formatClock(activeBill.walletCreditTime!)}',
                      ),
                    if (activeBill.walletCreditedTime != null)
                      _DetailLine(
                        label: 'Credited At',
                        value:
                            '${formatCompactDate(activeBill.walletCreditedTime!)} ${formatClock(activeBill.walletCreditedTime!)}',
                      ),
                  ],
                  if ((activeBill.paymentImageUrl ?? '').isNotEmpty ||
                      (localPaymentProofPath ?? '').isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    _PaymentProofImage(
                      imageUrl: activeBill.paymentImageUrl,
                      localPath: localPaymentProofPath,
                    ),
                  ],
                  if ((activeBill.note ?? '').isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    Text(
                      activeBill.note!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: <Widget>[
              if (_usesTenantWebsiteFlow || _usesSocietyFlow || _usesPmFlow)
                TextButton(
                  onPressed: () => _openBillPdfPreview(activeBill),
                  child: Text(
                    activeBill.status == BillStatus.paid
                        ? 'Download Receipt'
                        : 'Download Bill',
                  ),
                ),
              if (_usesTenantWebsiteFlow &&
                  (activeBill.ownerPhone ?? '').isNotEmpty)
                TextButton(
                  onPressed: () => _contactOwner(activeBill.ownerPhone!),
                  child: const Text('Contact Owner'),
                ),
              if (_usesPmFlow && (activeBill.residentPhone ?? '').isNotEmpty)
                TextButton(
                  onPressed: () => _contactOwner(activeBill.residentPhone!),
                  child: const Text('Contact Tenant'),
                ),
              if (canRecordPayment)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openManualCollectionSheet(activeBill);
                  },
                  child: const Text('Record Payment'),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Manual payment collection sheet — supports cash, manual online
  /// (with mode dropdown, description, and optional payment proof image).
  Future<void> _openManualCollectionSheet(BillRecord bill) async {
    // First ask: cash or manual online?
    final bool? isManualOnline = await showModalBottomSheet<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Record Payment',
                  style: Theme.of(
                    ctx,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '${bill.title} | Rs ${bill.amount.toStringAsFixed(0)}',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    label: 'Paid by Cash',
                    icon: const Icon(Icons.payments_outlined),
                    variant: CustomButtonVariant.outline,
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    label: 'Paid by Manual Online',
                    icon: const Icon(Icons.phone_android_outlined),
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (isManualOnline == null || !mounted) {
      return;
    }

    if (!isManualOnline) {
      // Cash payment
      try {
        await BillingService.collectBillManualOnline(bill.id, paymentType: 1);
        _showMessage('Cash payment recorded successfully.');
        if (_usesPmFlow) {
          _loadPmBills();
        } else if (_usesSocietyFlow) {
          _loadSocietyBills();
        } else {
          widget.onRefresh?.call();
        }
      } catch (error) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
      return;
    }

    // Manual online — show full form
    bool sheetClosed = false;
    int? selectedMode;
    final TextEditingController descController = TextEditingController();
    String? uploadedImageId;
    String? uploadedImagePath;
    bool isUploadingImage = false;
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            void safeSet(VoidCallback fn) {
              if (!mounted || sheetClosed) {
                return;
              }
              setModalState(fn);
            }

            Future<void> pickImage() async {
              final FilePickerResult? result = await FilePicker.platform
                  .pickFiles(type: FileType.image);
              if (result == null || result.files.single.path == null) {
                return;
              }
              safeSet(() {
                isUploadingImage = true;
              });
              try {
                final String? imgId = await UploadService.uploadImage(
                  File(result.files.single.path!),
                );
                if (imgId == null || imgId.trim().isEmpty) {
                  throw Exception('Server did not return an image ID.');
                }
                safeSet(() {
                  uploadedImageId = imgId;
                  uploadedImagePath = result.files.single.path;
                  isUploadingImage = false;
                });
              } catch (_) {
                safeSet(() {
                  isUploadingImage = false;
                });
                _showMessage('Image upload failed. Please try again.');
              }
            }

            Future<void> submit() async {
              if (selectedMode == null) {
                _showMessage('Please select the payment mode.');
                return;
              }
              safeSet(() {
                isSubmitting = true;
              });
              try {
                await BillingService.collectBillManualOnline(
                  bill.id,
                  paymentType: 3,
                  manualOnlinePaymentMode: selectedMode,
                  paymentDescription: descController.text.trim().isEmpty
                      ? null
                      : descController.text.trim(),
                  whetherPaymentImageAvailable: uploadedImageId != null,
                  imageId: uploadedImageId,
                );
                if (!mounted || !context.mounted || sheetClosed) {
                  return;
                }
                if ((uploadedImagePath ?? '').isNotEmpty) {
                  _rememberLocalPaymentProof(bill, uploadedImagePath!);
                }
                sheetClosed = true;
                Navigator.of(context).pop();
                _showMessage('Manual online payment recorded successfully.');
                if (_usesPmFlow) {
                  _loadPmBills();
                } else if (_usesSocietyFlow) {
                  _loadSocietyBills();
                } else {
                  widget.onRefresh?.call();
                }
              } catch (error) {
                _showMessage(error.toString().replaceFirst('Exception: ', ''));
                safeSet(() {
                  isSubmitting = false;
                });
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    Text(
                      'Manual Online Payment',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${bill.title} | Rs ${bill.amount.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<int?>(
                      value: selectedMode,
                      decoration: const InputDecoration(
                        labelText: 'Payment Mode *',
                      ),
                      items: _manualOnlinePaymentModes.entries
                          .map(
                            (MapEntry<int, String> e) => DropdownMenuItem<int?>(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (int? v) => safeSet(() {
                        selectedMode = v;
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Description / Transaction ID (optional)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          uploadedImagePath != null
                              ? 'Proof: ${uploadedImagePath!.split('/').last.split('\\').last}'
                              : 'No payment proof attached',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: uploadedImagePath != null
                                    ? const Color(0xFF16A34A)
                                    : AppTheme.textSecondary,
                              ),
                        ),
                        const SizedBox(height: 12),
                        if (uploadedImagePath != null) ...<Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(uploadedImagePath!),
                              width: double.infinity,
                              height: 150,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (
                                    BuildContext context,
                                    Object error,
                                    StackTrace? stackTrace,
                                  ) => Container(
                                    height: 150,
                                    color: AppTheme.surfaceMuted,
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'Unable to preview selected proof',
                                    ),
                                  ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (isUploadingImage)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: CustomButton(
                              label: uploadedImagePath != null
                                  ? 'Change Proof'
                                  : 'Upload Proof',
                              icon: const Icon(Icons.upload_outlined),
                              variant: CustomButtonVariant.outline,
                              onPressed: pickImage,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: CustomButton(
                        label: 'Confirm Payment',
                        isLoading: isSubmitting,
                        onPressed: isSubmitting || isUploadingImage
                            ? null
                            : submit,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      sheetClosed = true;
    });
  }

  // ---------------------------------------------------------------------------
  // Card builders
  // ---------------------------------------------------------------------------

  /// PM bill card matching the reference design: property name + amount header,
  /// status badge row, date row, tenant/owner/unit/phone grid, action buttons.
  Widget _buildPmBillCard(BillRecord bill, ThemeData theme) {
    final bool isPending =
        bill.status == BillStatus.pending || bill.status == BillStatus.overdue;
    final double displayAmount = bill.finalAmount ?? bill.amount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CustomCard(
        padding: CustomCardPadding.sm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ── Property name + Amount ─────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _BillTenantAvatar(imageUrl: bill.tenantImageUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _billDisplayTitle(bill),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if ((bill.residentName ?? '').isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          bill.residentName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    'Rs ${displayAmount.toStringAsFixed(0)}',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Status badge ───────────────────────────────────────────
            _PmStatusBadge(status: bill.status),
            const SizedBox(height: 12),

            // ── Bill Date + Due Date ───────────────────────────────────
            Row(
              children: <Widget>[
                Expanded(
                  child: _PmInfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Bill Date',
                    value: bill.billDate != null
                        ? formatCompactDate(bill.billDate!)
                        : '—',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PmInfoRow(
                    icon: Icons.event_outlined,
                    label: 'Due Date',
                    value: formatCompactDate(bill.dueDate),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Tenant + Owner ─────────────────────────────────────────
            Row(
              children: <Widget>[
                Expanded(
                  child: _PmInfoRow(
                    icon: Icons.person_outline,
                    label: 'Tenant',
                    value: (bill.residentName ?? '').isEmpty
                        ? '—'
                        : bill.residentName!,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PmInfoRow(
                    icon: Icons.home_work_outlined,
                    label: 'Owner',
                    value: (bill.ownerName ?? '').isEmpty
                        ? '—'
                        : bill.ownerName!,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Unit + Phone ───────────────────────────────────────────
            Row(
              children: <Widget>[
                Expanded(
                  child: _PmInfoRow(
                    icon: Icons.door_front_door_outlined,
                    label: 'Unit No',
                    value: bill.unitLabel,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PmInfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: (bill.residentPhone ?? '').isEmpty
                        ? '—'
                        : bill.residentPhone!,
                  ),
                ),
              ],
            ),
            if ((bill.residentEmail ?? '').isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              _PmInfoRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: bill.residentEmail!,
              ),
            ],
            const SizedBox(height: 14),

            // ── Action buttons ─────────────────────────────────────────
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openBillDetails(bill),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Details'),
                  ),
                ),
                if (isPending) ...<Widget>[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await BillingService.sendBillWhatsAppReminder(
                            bill.id,
                          );
                          _showMessage('WhatsApp reminder sent.');
                        } catch (e) {
                          _showMessage(
                            e.toString().replaceFirst('Exception: ', ''),
                          );
                        }
                      },
                      icon: const Icon(Icons.chat_outlined, size: 16),
                      label: const Text('Remind'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _openManualCollectionSheet(bill),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Record Payment'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Default bill card for tenant / society / other roles (unchanged layout).
  Widget _buildSocietyBillCard(BillRecord bill, ThemeData theme) {
    final bool isPaid = bill.status == BillStatus.paid;
    final String title = _societyBillTitle(bill);
    final String contactLine = _societyBillContactLine(bill);
    final String amount =
        'Rs ${(bill.finalAmount ?? bill.amount).toStringAsFixed(0)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CustomCard(
        padding: CustomCardPadding.sm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _SocietyStatusBadge(status: bill.status),
                _SocietyCategoryBadge(label: bill.category),
              ],
            ),
            if (contactLine.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                contactLine,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'Amount: $amount',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Bill Date: ${bill.billDate != null ? formatCompactDate(bill.billDate!) : '-'}',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Due: ${formatCompactDate(bill.dueDate)}',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 12,
              children: <Widget>[
                _SocietyActionButton(
                  label: 'View',
                  icon: Icons.visibility_outlined,
                  onPressed: () => _openBillDetails(bill),
                ),
                if (!isPaid)
                  _SocietyActionButton(
                    label: 'Remind',
                    icon: Icons.chat_outlined,
                    onPressed: () => _handleBillAction(bill),
                    foregroundColor: const Color(0xFF16A34A),
                    borderColor: const Color(0xFF86EFAC),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (isPaid)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 270),
                child: const SizedBox(
                  width: double.infinity,
                  child: CustomButton(label: 'Completed', onPressed: null),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openManualCollectionSheet(bill),
                    icon: const Icon(Icons.credit_card_outlined),
                    label: const Text('Record Payment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusSmall,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _societyBillTitle(BillRecord bill) {
    final String property = (bill.propertyTitle ?? '').trim();
    final String unit = _billUnitTypeOrUnit(bill);
    if (property.isNotEmpty && unit.isNotEmpty && unit != 'N/A') {
      return '$property - $unit';
    }
    if (property.isNotEmpty) {
      return property;
    }
    if (unit.isNotEmpty && unit != 'N/A') {
      return unit;
    }
    return bill.title;
  }

  String _societyBillContactLine(BillRecord bill) {
    final List<String> values = <String>[
      if ((bill.residentName ?? '').trim().isNotEmpty)
        bill.residentName!.trim(),
      if ((bill.residentEmail ?? '').trim().isNotEmpty)
        bill.residentEmail!.trim(),
      if ((bill.residentPhone ?? '').trim().isNotEmpty)
        bill.residentPhone!.trim(),
    ];
    return values.join(' • ');
  }

  Widget _buildDefaultBillCard(BillRecord bill, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CustomCard(
        padding: CustomCardPadding.sm,
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
                        _billDisplayTitle(bill),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _buildBillSubtitle(bill),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ToneBadge(label: bill.status.label, tone: bill.status.tone),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MetaItem(
                    label: 'Amount',
                    value:
                        'Rs ${(bill.finalAmount ?? bill.amount).toStringAsFixed(0)}',
                  ),
                ),
                Expanded(
                  child: _MetaItem(
                    label: 'Due',
                    value: formatCompactDate(bill.dueDate),
                  ),
                ),
              ],
            ),
            if ((_usesTenantWebsiteFlow) &&
                ((bill.societyName ?? '').isNotEmpty ||
                    (bill.propertyTitle ?? '').isNotEmpty ||
                    (bill.ownerName ?? '').isNotEmpty ||
                    (bill.residentName ?? '').isNotEmpty)) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if ((bill.societyName ?? '').isNotEmpty)
                    ToneBadge(label: bill.societyName!, tone: UiTone.brand),
                  if ((bill.propertyTitle ?? '').isNotEmpty)
                    ToneBadge(label: bill.propertyTitle!, tone: UiTone.neutral),
                  if (_usesTenantWebsiteFlow &&
                      (bill.ownerName ?? '').isNotEmpty)
                    ToneBadge(
                      label: 'Owner: ${bill.ownerName!}',
                      tone: UiTone.neutral,
                    ),
                ],
              ),
            ],
            if (bill.note != null) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Text(
                  bill.note!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Column(
              children: <Widget>[
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    label: 'View Details',
                    variant: CustomButtonVariant.outline,
                    onPressed: () => _openBillDetails(bill),
                  ),
                ),
                if (bill.status == BillStatus.paid) ...<Widget>[
                  const SizedBox(height: 10),
                  const SizedBox(
                    width: double.infinity,
                    child: CustomButton(label: 'Completed', onPressed: null),
                  ),
                ] else if (_usesSocietyFlow) ...<Widget>[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      label: 'Record Payment',
                      onPressed: () => _openManualCollectionSheet(bill),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _handleBillAction(bill),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSmall,
                          ),
                        ),
                      ),
                      child: const Text('Send Reminder'),
                    ),
                  ),
                ] else ...<Widget>[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      label:
                          (widget.role.isResidentScope ||
                              widget.role == AppRole.owner)
                          ? 'Pay Now'
                          : 'Send Reminder',
                      onPressed: () => _handleBillAction(bill),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  String _buildBillSubtitle(BillRecord bill) {
    if (_usesPmFlow) {
      if ((bill.residentName ?? '').isNotEmpty) {
        return '${bill.residentName!} | ${bill.unitLabel}';
      }
      if ((bill.propertyTitle ?? '').isNotEmpty) {
        return '${bill.propertyTitle!} | ${bill.unitLabel}';
      }
      return '${bill.category} for ${bill.unitLabel}';
    }
    if (_usesTenantWebsiteFlow) {
      if ((bill.propertyTitle ?? '').isNotEmpty) {
        if ((bill.ownerName ?? '').isNotEmpty) {
          return '${bill.propertyTitle} | ${bill.ownerName}';
        }
        return bill.propertyTitle!;
      }
      if ((bill.societyName ?? '').isNotEmpty) {
        return '${bill.category} | ${bill.societyName}';
      }
    }
    return '${bill.category} for ${bill.unitLabel}';
  }

  String _billDisplayTitle(BillRecord bill) {
    final String property = (bill.propertyTitle ?? '').trim();
    final String unit = _billUnitTypeOrUnit(bill);
    if (property.isNotEmpty && unit.isNotEmpty && unit != 'N/A') {
      return '$property - $unit';
    }
    if (property.isNotEmpty) return property;
    return bill.title;
  }

  static String _billUnitTypeOrUnit(BillRecord bill) {
    final String unitType = (bill.unitType ?? '').trim();
    if (unitType.isNotEmpty) return unitType;
    return bill.unitLabel.trim();
  }

  String _paymentTypeLabel(int value) {
    return switch (value) {
      1 => 'Cash',
      2 => 'Online',
      3 => 'Manual Online',
      _ => 'Other',
    };
  }

  String _manualOnlinePaymentModeLabel(int value) {
    return _manualOnlinePaymentModes[value] ?? 'Other';
  }

  static const Map<int, String> _manualOnlinePaymentModes = <int, String>{
    1: 'UPI',
    2: 'NetBanking',
    3: 'Card',
    4: 'Wallet',
    5: 'NEFT',
    6: 'IMPS',
    7: 'RTGS',
    8: 'Cash Deposit',
    9: 'Bank Transfer',
    10: 'Other',
  };

  /// Compact currency formatter: 1,50,000 → "Rs 1.5L", 5000 → "Rs 5K"
  String _compactRs(double value) {
    if (value >= 100000) {
      return 'Rs ${(value / 100000).toStringAsFixed(1)}L';
    }
    if (value >= 1000) {
      return 'Rs ${(value / 1000).toStringAsFixed(1)}K';
    }
    return 'Rs ${value.toStringAsFixed(0)}';
  }

  Future<void> _contactOwner(String phoneNumber) async {
    final Uri uri = Uri.parse('tel:$phoneNumber');
    final bool launched = await launchUrl(uri);
    if (!launched && mounted) {
      _showMessage('Unable to open the phone dialer.');
    }
  }

  void _rememberLocalPaymentProof(BillRecord bill, String path) {
    for (final String key in _paymentProofKeys(bill)) {
      _localPaymentProofPaths[key] = path;
    }
  }

  String? _localPaymentProofPathFor(BillRecord bill) {
    for (final String key in _paymentProofKeys(bill)) {
      final String? path = _localPaymentProofPaths[key];
      if ((path ?? '').isNotEmpty) {
        return path;
      }
    }
    return null;
  }

  List<String> _paymentProofKeys(BillRecord bill) {
    final List<String> keys = <String>[];
    void add(String value) {
      final String key = value.trim();
      if (key.isNotEmpty && !keys.contains(key)) {
        keys.add(key);
      }
    }

    add(bill.id);
    add(
      '${bill.title}|${bill.unitLabel}|${bill.amount}|${bill.dueDate.toIso8601String()}',
    );
    add('${bill.title}|${bill.amount}|${bill.dueDate.toIso8601String()}');
    return keys;
  }

  Future<void> _openBillPdfPreview(BillRecord bill) async {
    try {
      final Uint8List bytes = await RentalBillPdfService.buildBillPdf(bill);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => _BillPdfPreviewPage(
            title: bill.status == BillStatus.paid
                ? 'Receipt Preview'
                : 'Bill Preview',
            filename: RentalBillPdfService.billPdfFilename(bill),
            bytes: bytes,
          ),
        ),
      );
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openBillsReportPdfPreview(List<BillRecord> bills) async {
    try {
      final Uint8List bytes = await RentalBillPdfService.buildBillsReportPdf(
        bills,
      );
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => _BillPdfPreviewPage(
            title: 'Bills Report Preview',
            filename: RentalBillPdfService.billsReportPdfFilename(bills),
            bytes: bytes,
          ),
        ),
      );
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------
class _BillPdfPreviewPage extends StatelessWidget {
  const _BillPdfPreviewPage({
    required this.title,
    required this.filename,
    required this.bytes,
  });

  final String title;
  final String filename;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.border),
        ),
      ),
      body: PdfPreview(
        build: (_) async => bytes,
        pdfFileName: filename,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowSharing: true,
        allowPrinting: true,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final UiTone tone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 146,
      child: CustomCard(
        padding: CustomCardPadding.sm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ToneBadge(label: label, tone: tone, size: ToneBadgeSize.small),
            const SizedBox(height: 14),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 112,
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

class _SocietyStatusBadge extends StatelessWidget {
  const _SocietyStatusBadge({required this.status});

  final BillStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color = AppTheme.toneColor(status.tone);
    final IconData icon = switch (status) {
      BillStatus.paid => Icons.check_circle_outline,
      BillStatus.pending => Icons.schedule_outlined,
      BillStatus.overdue => Icons.error_outline,
      BillStatus.partial => Icons.pending_actions_outlined,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.toneContainer(status.tone),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SocietyCategoryBadge extends StatelessWidget {
  const _SocietyCategoryBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.primaryTone,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: const Color(0xFF1E40AF),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SocietyActionButton extends StatelessWidget {
  const _SocietyActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.foregroundColor = AppTheme.textPrimary,
    this.borderColor = AppTheme.borderStrong,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color foregroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: foregroundColor,
        side: BorderSide(color: borderColor, width: 1.5),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        textStyle: themeTextStyle(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
      ),
    );
  }

  TextStyle? themeTextStyle(BuildContext context) {
    return Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600);
  }
}

class _PaymentProofImage extends StatelessWidget {
  const _PaymentProofImage({this.imageUrl, this.localPath});

  final String? imageUrl;
  final String? localPath;

  @override
  Widget build(BuildContext context) {
    final String normalizedUrl = _normalizedUrl(imageUrl);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: double.infinity,
        height: 180,
        child: normalizedUrl.isNotEmpty
            ? Image.network(
                normalizedUrl,
                fit: BoxFit.cover,
                loadingBuilder:
                    (
                      BuildContext context,
                      Widget child,
                      ImageChunkEvent? loadingProgress,
                    ) {
                      if (loadingProgress == null) {
                        return child;
                      }
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    },
                errorBuilder:
                    (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) => _localOrEmpty(),
              )
            : _localOrEmpty(),
      ),
    );
  }

  Widget _localOrEmpty() {
    final String path = localPath?.trim() ?? '';
    if (path.isNotEmpty) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) =>
                _emptyState(),
      );
    }
    return _emptyState();
  }

  Widget _emptyState() {
    return Container(
      color: AppTheme.surfaceMuted,
      alignment: Alignment.center,
      child: const Text('Unable to load payment proof'),
    );
  }

  String _normalizedUrl(String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) {
      return '';
    }
    if (text.startsWith('//')) {
      return 'https:$text';
    }
    return text;
  }
}

class _PmMetricCard extends StatelessWidget {
  const _PmMetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BillTenantAvatar extends StatefulWidget {
  const _BillTenantAvatar({this.imageUrl});

  final String? imageUrl;

  @override
  State<_BillTenantAvatar> createState() => _BillTenantAvatarState();
}

class _BillTenantAvatarState extends State<_BillTenantAvatar> {
  String? _resolvedUrl;
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    _resolveImageId();
  }

  @override
  void didUpdateWidget(covariant _BillTenantAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resolvedUrl = null;
      _resolveImageId();
    }
  }

  Future<void> _resolveImageId() async {
    final String value = widget.imageUrl?.trim() ?? '';
    if (!value.startsWith('imageid:') || _isResolving) {
      return;
    }

    final String imageId = value.substring('imageid:'.length).trim();
    if (imageId.isEmpty) {
      return;
    }

    setState(() => _isResolving = true);
    try {
      final String? resolved = await UploadService.fetchImageInfo(imageId);
      if (!mounted) {
        return;
      }
      setState(() {
        _resolvedUrl = resolved;
        _isResolving = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isResolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String rawUrl = widget.imageUrl?.trim() ?? '';
    final String url = rawUrl.startsWith('imageid:')
        ? (_resolvedUrl ?? '')
        : rawUrl;

    return ClipOval(
      child: Container(
        width: 56,
        height: 56,
        color: AppTheme.surfaceMuted,
        child: _isResolving
            ? const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : url.isEmpty
            ? const Icon(
                Icons.person_outline,
                color: AppTheme.textMuted,
                size: 28,
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.person_outline,
                  color: AppTheme.textMuted,
                  size: 28,
                ),
              ),
      ),
    );
  }
}

/// Status badge for PM bill cards - icon + colored label.
class _PmStatusBadge extends StatelessWidget {
  const _PmStatusBadge({required this.status});

  final BillStatus status;

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color fgColor;
    final IconData icon;

    switch (status) {
      case BillStatus.paid:
        bgColor = const Color(0xFFDCFCE7);
        fgColor = const Color(0xFF16A34A);
        icon = Icons.check_circle_outline;
      case BillStatus.pending:
        bgColor = const Color(0xFFFEF3C7);
        fgColor = const Color(0xFFD97706);
        icon = Icons.access_time;
      case BillStatus.overdue:
        bgColor = const Color(0xFFFEE2E2);
        fgColor = const Color(0xFFDC2626);
        icon = Icons.warning_amber_rounded;
      case BillStatus.partial:
        bgColor = const Color(0xFFDBEAFE);
        fgColor = const Color(0xFF2563EB);
        icon = Icons.pie_chart_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: fgColor),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: fgColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Info row used inside PM bill cards — icon + label + value.
class _PmInfoRow extends StatelessWidget {
  const _PmInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 14, color: AppTheme.textMuted),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted),
              ),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
