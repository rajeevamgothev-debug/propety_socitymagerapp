import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/property_service.dart';
import '../../core/api/razorpay_checkout_service.dart';
import '../../core/api/rental_contract_service.dart';
import '../../core/api/subscription_service.dart';
import '../../core/api/upload_service.dart';
import '../../core/api/vendor_service.dart';
import '../../core/models/api_models.dart';
import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_card.dart';
import '../../core/widgets/custom_tab_bar.dart';
import '../../core/widgets/location_picker_sheet.dart';
import '../../core/widgets/tone_badge.dart';
import 'property_enquiries_page.dart';

const Map<int, String> _propertyTypeLabels = <int, String>{
  1: 'Apartment',
  2: 'Villa',
  3: 'PG',
  4: 'Commercial',
};

const Map<int, Map<int, String>> _propertySubTypeLabels =
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
      4: <int, String>{1: 'Office', 2: 'Retail', 3: 'Warehouse', 4: 'Showroom'},
    };

const Map<int, String> _pgSharingLabels = <int, String>{
  1: 'Single',
  2: 'Double',
  3: 'Triple',
  4: 'Quad',
  5: 'Dorm',
};

const Map<int, String> _categoryTypeLabels = <int, String>{
  1: 'Rent',
  2: 'Lease',
};

int _openEnquiryCount({int? totalLeads, int? totalUnseenLeads}) {
  return totalUnseenLeads ?? totalLeads ?? 0;
}

String? propertyRenewalContractReductionMessage({
  required int activeContracts,
  required int freeContracts,
  required int requestedExtraContracts,
}) {
  final int sanitizedRequestedExtraContracts = requestedExtraContracts < 0
      ? 0
      : requestedExtraContracts;
  final int totalAfterRenewal =
      freeContracts + sanitizedRequestedExtraContracts;
  if (activeContracts <= totalAfterRenewal) {
    return null;
  }

  final int minimumExtraContracts = activeContracts - freeContracts;
  String contractWord(int count) => count == 1 ? 'contract' : 'contracts';
  return 'You have $activeContracts Active ${contractWord(activeContracts)} and $minimumExtraContracts purchased and $freeContracts free ${contractWord(freeContracts)} so you need to add $minimumExtraContracts extra ${contractWord(minimumExtraContracts)} to process the Renewal plan.';
}

const Map<int, String> _facingDirectionLabels = <int, String>{
  0: 'Not Specified',
  1: 'North',
  2: 'South',
  3: 'East',
  4: 'West',
  5: 'North East',
  6: 'North West',
  7: 'South East',
  8: 'South West',
};

const Map<int, String> _furnishedTypeLabels = <int, String>{
  0: 'Not Specified',
  1: 'Unfurnished',
  2: 'Semi-Furnished',
  3: 'Fully-Furnished',
};

const Map<int, String> _billTypeLabels = <int, String>{
  1: 'Included',
  2: 'Separate Meter',
  3: 'Shared',
  4: 'Not Available',
};

const Map<int, String> _parkingTypeLabels = <int, String>{
  1: 'Covered',
  2: 'Open',
  3: 'Basement',
};

const Map<int, String> _tenantTypeLabels = <int, String>{
  1: 'Any',
  2: 'Family Only',
  3: 'Bachelor Only',
  4: 'Students Only',
};

const Map<int, String> _petPolicyLabels = <int, String>{
  1: 'Not Allowed',
  2: 'Allowed',
  3: 'Conditional',
};

const Map<int, String> _smokingPolicyLabels = <int, String>{
  1: 'Not Allowed',
  2: 'Allowed',
};

const Map<int, String> _visitorsPolicyLabels = <int, String>{
  1: 'Not Allowed',
  2: 'Allowed',
  3: 'Restricted Hours',
};

const Map<int, String> _genderLabels = <int, String>{
  0: 'Any',
  1: 'Male',
  2: 'Female',
  3: 'Co-ed',
};

const Map<int, String> _propertyAmenityLabels = <int, String>{
  1: 'AC',
  2: 'Modular Kitchen',
  3: 'Wardrobes',
  4: 'Geyser',
  5: 'WiFi',
  6: 'Security',
  7: 'Lift',
  8: 'CCTV',
  9: 'Power Backup',
  10: 'Parking',
  11: 'Swimming Pool',
  12: 'Gym',
  13: 'Club House',
  14: 'Garden',
  15: "Children's Play Area",
  16: 'Intercom',
  17: 'Fire Safety',
  18: 'Maintenance Staff',
  19: 'Housekeeping',
  20: 'Meals Included',
  21: 'Playground',
  22: 'Laundry',
  23: 'Refrigerator',
  24: 'Microwave',
  25: 'TV',
  26: 'DTH',
  27: 'Sofa',
  28: 'Curtains',
  29: 'Beds',
  30: 'Cooking Utensils',
  31: 'Drinking Water',
  32: 'Hot Water',
  33: 'Visitor Parking',
  34: 'Elevator',
  35: 'Gas Connection',
  36: 'Water Purifier',
  37: 'Sewage Treatment Plant',
  38: 'Rain Water Harvesting',
  39: 'Meals Not Included',
};

const Set<int> _pgHiddenAmenityIds = <int>{11, 13, 14, 16, 21};

class _UploadedAsset {
  const _UploadedAsset({required this.id, required this.label, this.url});

  final String id;
  final String label;
  final String? url;
}

enum _SubscriptionPlanMode { subscribe, renew, change }

class _PropertyFormResult {
  const _PropertyFormResult({
    this.createdPropertyId,
    this.openSubscriptionAfterSave = false,
  });

  final String? createdPropertyId;
  final bool openSubscriptionAfterSave;
}

class PropertiesPage extends StatefulWidget {
  const PropertiesPage({
    super.key,
    this.showAppBar = true,
    this.onBack,
  });

  final bool showAppBar;
  final VoidCallback? onBack;

  @override
  State<PropertiesPage> createState() => _PropertiesPageState();
}

class _PropertiesPageState extends State<PropertiesPage> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _renewalPopupShown = false;
  String? _errorMessage;
  PropertyStatus? _statusFilter;
  int? _typeFilter;
  int? _subTypeFilter;
  int? _categoryTypeFilter;
  String? _stateId;
  String? _cityId;
  int _page = 0;
  final int _pageSize = 20;
  int _totalCount = 0;
  List<PropertyRecord> _properties = <PropertyRecord>[];
  List<PropertyStateData> _states = <PropertyStateData>[];
  List<PropertyCityData> _cities = <PropertyCityData>[];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleBackPressed() {
    if (widget.onBack != null) {
      widget.onBack!.call();
      return;
    }

    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.maybePop();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        PropertyService.filterStates(limit: 100),
        PropertyService.filterProperties(
          skip: _page * _pageSize,
          limit: _pageSize,
          typeFilter: _typeFilter,
          subType: _subTypeFilter,
          categoryType: _categoryTypeFilter,
          stateId: _stateId,
          cityId: _cityId,
          search: _searchController.text.trim().isEmpty
              ? null
              : _searchController.text.trim(),
        ),
      ]);

      if (!mounted) {
        return;
      }

      final statesResult =
          results[0] as ({List<PropertyStateData> states, int count});
      final propertyResult =
          results[1] as ({List<PropertyRecord> properties, int count});

      setState(() {
        _states = statesResult.states;
        _properties = _applyStatusFilter(propertyResult.properties);
        _totalCount = propertyResult.count;
        _isLoading = false;
      });

      _checkRenewalPopup(propertyResult.properties);
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

  void _checkRenewalPopup(List<PropertyRecord> properties) {
    if (_renewalPopupShown || !mounted) return;

    final List<PropertyRecord> urgentProperties = properties.where((p) {
      if (!p.isSubscribed) return false;
      final timing = _subscriptionTiming(
        p.currentSubscriptionExpiryDate,
        apiExpired: p.subscriptionExpired == true,
      );
      return timing.isExpired || timing.isExpiringSoon;
    }).toList();

    if (urgentProperties.isEmpty) return;

    _renewalPopupShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFDC2626),
            size: 40,
          ),
          title: const Text('Subscription Renewal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  urgentProperties.length == 1
                      ? 'The following property subscription needs renewal:'
                      : 'The following property subscriptions need renewal:',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 12),
                ...urgentProperties.map((p) {
                  final timing = _subscriptionTiming(
                    p.currentSubscriptionExpiryDate,
                    apiExpired: p.subscriptionExpired == true,
                  );
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: timing.isExpired
                          ? const Color(0xFFFEF2F2)
                          : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: timing.isExpired
                            ? const Color(0xFFFECACA)
                            : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                p.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                timing.isExpired
                                    ? 'Expired'
                                    : timing.daysRemaining == 0
                                    ? 'Expires today'
                                    : 'Expires in ${timing.daysRemaining} day${timing.daysRemaining == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: timing.isExpired
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _openSubscriptionSheet(
                              p.id,
                              mode: _SubscriptionPlanMode.renew,
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: const Color(0xFFDC2626),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text(
                            'Renew',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Dismiss'),
            ),
          ],
        ),
      );
    });
  }

  List<PropertyRecord> _applyStatusFilter(List<PropertyRecord> items) {
    if (_statusFilter == null) {
      return items;
    }
    if (_statusFilter == PropertyStatus.inactive) {
      return items
          .where(
            (PropertyRecord item) =>
                !item.isActive || item.status == PropertyStatus.inactive,
          )
          .toList();
    }
    return items
        .where(
          (PropertyRecord item) =>
              item.isActive && item.status == _statusFilter,
        )
        .toList();
  }

  Future<void> _loadCitiesForSelectedState() async {
    if ((_stateId ?? '').isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cities = <PropertyCityData>[];
        _cityId = null;
      });
      return;
    }

    try {
      final result = await PropertyService.filterCities(
        stateId: _stateId,
        limit: 100,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _cities = result.cities;
        if (_cityId != null &&
            !_cities.any((PropertyCityData item) => item.cityId == _cityId)) {
          _cityId = null;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cities = <PropertyCityData>[];
        _cityId = null;
      });
    }
  }

  Future<void> _loadProperties() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await PropertyService.filterProperties(
        skip: _page * _pageSize,
        limit: _pageSize,
        typeFilter: _typeFilter,
        subType: _subTypeFilter,
        categoryType: _categoryTypeFilter,
        stateId: _stateId,
        cityId: _cityId,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _properties = _applyStatusFilter(result.properties);
        _totalCount = result.count;
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

  Future<void> _applyFilters() async {
    setState(() {
      _page = 0;
    });
    await _loadProperties();
  }

  Future<void> _clearFilters() async {
    _searchController.clear();
    setState(() {
      _statusFilter = null;
      _typeFilter = null;
      _subTypeFilter = null;
      _categoryTypeFilter = null;
      _stateId = null;
      _cityId = null;
      _page = 0;
      _cities = <PropertyCityData>[];
    });
    await _loadProperties();
  }

  Future<void> _toggleProperty(PropertyRecord property) async {
    final bool isDeactivating = property.isActive;
    if (isDeactivating) {
      final bool? confirmed = await _confirmAction(
        title: 'Deactivate Property',
        message:
            'Deactivating "${property.title}" will hide it from listings. You can reactivate it anytime. Continue?',
        confirmLabel: 'Deactivate',
      );
      if (confirmed != true) return;
    }
    try {
      if (isDeactivating) {
        await PropertyService.inactivateProperty(property.id);
      } else {
        await PropertyService.activateProperty(property.id);
      }
      _showMessage(
        isDeactivating ? 'Property deactivated.' : 'Property activated.',
      );
      await _loadProperties();
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<bool?> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _openPropertySheet({
    String? propertyId,
    String? cloneFromPropertyId,
  }) async {
    final _PropertyFormResult? result = await Navigator.of(context)
        .push<_PropertyFormResult>(
          MaterialPageRoute<_PropertyFormResult>(
            builder: (_) => _PropertyFormPage(
              propertyId: propertyId,
              cloneFromPropertyId: cloneFromPropertyId,
              states: _states,
              onSaved: _loadProperties,
            ),
          ),
        );

    if (!mounted ||
        result == null ||
        !result.openSubscriptionAfterSave ||
        (result.createdPropertyId ?? '').isEmpty) {
      return;
    }

    await _openSubscriptionSheet(
      result.createdPropertyId!,
      mode: _SubscriptionPlanMode.subscribe,
    );
  }

  Future<void> _showPropertyDetails(String propertyId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PropertyDetailsPage(
          propertyId: propertyId,
          onManagePlan: _openSubscriptionSheet,
        ),
      ),
    );
  }

  Future<void> _openSubscriptionSheet(
    String propertyId, {
    _SubscriptionPlanMode? mode,
  }) async {
    PropertyData? property = await PropertyService.fetchPropertyInfo(
      propertyId,
    );
    if (property == null) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      property = await PropertyService.fetchPropertyInfo(propertyId);
    }
    if (property == null) {
      _showMessage('Unable to load property subscription details.');
      return;
    }
    final PropertyData propertyInfo = property;

    int freeContractsFromSettings(Map<String, dynamic>? settings) {
      if (settings == null) {
        return 0;
      }

      return switch (propertyInfo.propertyType) {
        1 =>
          (settings['Free_Resident_Contracts_Count_For_Apartment'] as num?)
                  ?.toInt() ??
              0,
        2 =>
          (settings['Free_Resident_Contracts_Count_For_Villa'] as num?)
                  ?.toInt() ??
              0,
        3 =>
          (settings['Free_Resident_Contracts_Count_For_PG'] as num?)?.toInt() ??
              0,
        4 =>
          (settings['Free_Resident_Contracts_Count_For_Commercial'] as num?)
                  ?.toInt() ??
              0,
        _ => 0,
      };
    }

    SubscriptionPlanData? findPlanById(
      List<SubscriptionPlanData> planItems,
      String? subscriptionId,
    ) {
      if ((subscriptionId ?? '').isEmpty) {
        return null;
      }

      for (final SubscriptionPlanData plan in planItems) {
        if (plan.subscriptionId == subscriptionId) {
          return plan;
        }
      }
      return null;
    }

    final _SubscriptionTimingInfo timing = _subscriptionTiming(
      propertyInfo.currentSubscriptionExpiryDate,
      apiExpired: propertyInfo.subscriptionExpired == true,
    );
    final _SubscriptionPlanMode sheetMode =
        mode ??
        (!propertyInfo.isSubscribed
            ? _SubscriptionPlanMode.subscribe
            : (timing.isExpired || timing.isExpiringSoon)
            ? _SubscriptionPlanMode.renew
            : _SubscriptionPlanMode.change);

    List<SubscriptionPlanData> plans = <SubscriptionPlanData>[];
    Map<String, dynamic>? appSettings;
    String? initialErrorMessage;

    if (sheetMode != _SubscriptionPlanMode.renew) {
      try {
        final result = await SubscriptionService.filterSubscriptions(
          propertyType: propertyInfo.propertyType,
          limit: 50,
        );
        plans = result.plans;
      } catch (error) {
        initialErrorMessage = error.toString().replaceFirst('Exception: ', '');
      }

      try {
        appSettings = await PropertyService.fetchAppCommonSettings();
      } catch (_) {}
    }
    if (appSettings == null) {
      try {
        appSettings = await PropertyService.fetchAppCommonSettings();
      } catch (_) {}
    }

    int maxPositive(List<int?> values) {
      int result = 0;
      for (final int? value in values) {
        if (value != null && value > result) {
          result = value;
        }
      }
      return result;
    }

    int firstPositive(List<int?> values) {
      for (final int? value in values) {
        if (value != null && value > 0) {
          return value;
        }
      }
      return 0;
    }

    String? selectedPlanId = sheetMode == _SubscriptionPlanMode.renew
        ? propertyInfo.currentSubscriptionId
        : null;
    final int initialExtraContracts = sheetMode == _SubscriptionPlanMode.renew
        ? (propertyInfo.currentSubscriptionExtraResidentContracts ?? 0)
        : (propertyInfo.totalPurchasedResidentContractsCreationCount ?? 0);
    final TextEditingController extraContractsController =
        TextEditingController(text: '$initialExtraContracts');
    SubscriptionCalculationData? calculation;
    int? activeContractsFromService;

    if (sheetMode == _SubscriptionPlanMode.renew) {
      int countActiveContracts(List<RentalContractRecord> contracts) {
        return contracts
            .where(
              (RentalContractRecord contract) =>
                  contract.status == ContractStatus.active &&
                  contract.isActive &&
                  (contract.propertyId ?? '').trim() == propertyInfo.propertyId,
            )
            .length;
      }

      try {
        final result = await RentalContractService.filterRentalContracts(
          status: ContractStatus.active,
          propertyId: propertyInfo.propertyId,
          limit: 200,
        );
        activeContractsFromService = countActiveContracts(result.contracts);
      } catch (_) {}
      try {
        final result = await RentalContractService.filterContractsForProperty(
          propertyInfo.propertyId,
          limit: 200,
        );
        final bool resultHasPropertyIds = result.contracts.any(
          (RentalContractRecord contract) =>
              (contract.propertyId ?? '').trim().isNotEmpty,
        );
        final int propertyMatchedCount = countActiveContracts(result.contracts);
        final int trustedFilteredCount =
            propertyMatchedCount > 0 || resultHasPropertyIds
            ? propertyMatchedCount
            : result.contracts
                  .where(
                    (RentalContractRecord contract) =>
                        contract.status == ContractStatus.active &&
                        contract.isActive,
                  )
                  .length;
        activeContractsFromService = maxPositive(<int?>[
          activeContractsFromService,
          trustedFilteredCount,
        ]);
      } catch (_) {}
    }

    if (sheetMode == _SubscriptionPlanMode.renew) {
      if ((selectedPlanId ?? '').isEmpty) {
        initialErrorMessage =
            'Unable to identify the current subscription plan for renewal.';
      } else {
        try {
          calculation = await SubscriptionService.calculateSubscription(
            propertyId: propertyInfo.propertyId,
            subscriptionId: selectedPlanId!,
            extraResidentContracts: initialExtraContracts,
          );
        } catch (error) {
          initialErrorMessage = error.toString().replaceFirst(
            'Exception: ',
            '',
          );
        }
      }
    }

    int? freeFromTotal(int? total) {
      if (total == null || total <= 0) {
        return null;
      }
      final int free = total - initialExtraContracts;
      return free < 0 ? 0 : free;
    }

    final int derivedFreeContracts = firstPositive(<int?>[
      freeFromTotal(calculation?.totalAvailableContracts),
      freeFromTotal(
        propertyInfo.currentSubscriptionCalculation?.totalAvailableContracts,
      ),
      propertyInfo.totalResidentContractsCount != null
          ? propertyInfo.totalResidentContractsCount! - initialExtraContracts
          : null,
      propertyInfo.availableResidentContractsCreationCount != null
          ? propertyInfo.availableResidentContractsCreationCount! -
                initialExtraContracts
          : null,
    ]);
    final int renewalActiveContracts =
        activeContractsFromService ??
        firstPositive(<int?>[
          propertyInfo.usedResidentContractsCount,
          propertyInfo
              .currentSubscriptionCalculation
              ?.activeRentalContractsCount,
          calculation?.activeRentalContractsCount,
        ]);
    final int renewalFreeContracts = firstPositive(<int?>[
      derivedFreeContracts,
      propertyInfo.freeResidentContractsCount,
      freeContractsFromSettings(appSettings),
      propertyInfo.currentSubscriptionCalculation?.freeContractsCount,
      calculation?.freeContractsCount,
    ]);
    String? errorMessage = initialErrorMessage;
    String? successMessage;
    bool calculating = false;
    bool purchasing = false;
    bool reviewStep = sheetMode == _SubscriptionPlanMode.renew;

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            int currentExtraContracts() {
              final int parsed =
                  int.tryParse(extraContractsController.text.trim()) ?? 0;
              return parsed < 0 ? 0 : parsed;
            }

            int activeContractsForRenewal() {
              return renewalActiveContracts;
            }

            int freeContractsForRenewal() {
              final int calculatedFree = calculation?.freeContractsCount ?? 0;
              if (calculatedFree <= 0) {
                return renewalFreeContracts;
              }
              if (renewalFreeContracts <= 0) {
                return calculatedFree;
              }
              return calculatedFree < renewalFreeContracts
                  ? calculatedFree
                  : renewalFreeContracts;
            }

            String? renewalReductionMessage(int requestedExtraContracts) {
              if (sheetMode != _SubscriptionPlanMode.renew) {
                return null;
              }

              return propertyRenewalContractReductionMessage(
                activeContracts: activeContractsForRenewal(),
                freeContracts: freeContractsForRenewal(),
                requestedExtraContracts: requestedExtraContracts,
              );
            }

            Future<void> showRenewalReductionPopup(String message) async {
              if (!context.mounted) {
                return;
              }
              await showDialog<void>(
                context: context,
                builder: (BuildContext dialogContext) => AlertDialog(
                  title: const Text('Renewal Cannot Reduce Contracts'),
                  content: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Text(
                      message,
                      style: Theme.of(dialogContext).textTheme.bodyMedium
                          ?.copyWith(
                            color: const Color(0xFF991B1B),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            Future<bool> guardRenewalReduction(
              int requestedExtraContracts,
            ) async {
              final String? message = renewalReductionMessage(
                requestedExtraContracts,
              );
              if (message == null) {
                return true;
              }
              setModalState(() {
                errorMessage = message;
                successMessage = null;
                calculation = null;
              });
              await showRenewalReductionPopup(message);
              return false;
            }

            Future<void> updateExtraContracts(int value) async {
              final int sanitized = value < 0 ? 0 : value;
              extraContractsController.text = '$sanitized';
              extraContractsController.selection = TextSelection.collapsed(
                offset: extraContractsController.text.length,
              );
              if (await guardRenewalReduction(sanitized)) {
                setModalState(() {
                  errorMessage = null;
                  successMessage = null;
                  calculation = null;
                });
              }
            }

            Future<void> calculateAndReview() async {
              if ((selectedPlanId ?? '').isEmpty) {
                setModalState(() {
                  errorMessage = 'Select a subscription plan first.';
                });
                return;
              }

              if (!await guardRenewalReduction(currentExtraContracts())) {
                return;
              }

              setModalState(() {
                calculating = true;
                errorMessage = null;
                successMessage = null;
              });

              try {
                calculation = await SubscriptionService.calculateSubscription(
                  propertyId: propertyInfo.propertyId,
                  subscriptionId: selectedPlanId!,
                  extraResidentContracts: currentExtraContracts(),
                );
                setModalState(() {
                  reviewStep = true;
                });
              } catch (error) {
                final String message = error.toString().replaceFirst(
                  'Exception: ',
                  '',
                );
                setModalState(() {
                  errorMessage = message;
                  calculating = false;
                });
                if (sheetMode == _SubscriptionPlanMode.renew &&
                    currentExtraContracts() < initialExtraContracts) {
                  await showRenewalReductionPopup(message);
                }
              } finally {
                if (context.mounted) {
                  setModalState(() {
                    calculating = false;
                  });
                }
              }
            }

            Future<void> purchase() async {
              if ((selectedPlanId ?? '').isEmpty) {
                setModalState(() {
                  errorMessage = 'Select and calculate a plan first.';
                });
                return;
              }

              if (!await guardRenewalReduction(currentExtraContracts())) {
                return;
              }

              setModalState(() {
                purchasing = true;
                errorMessage = null;
                successMessage = null;
              });

              bool closingAfterSuccess = false;
              try {
                calculation ??= await SubscriptionService.calculateSubscription(
                  propertyId: propertyInfo.propertyId,
                  subscriptionId: selectedPlanId!,
                  extraResidentContracts: currentExtraContracts(),
                );

                final response = await SubscriptionService.purchaseSubscription(
                  propertyId: propertyInfo.propertyId,
                  subscriptionId: selectedPlanId!,
                  extraResidentContracts: currentExtraContracts(),
                );

                if (!response.success) {
                  throw Exception(
                    response.message ??
                        response.status ??
                        'Unable to continue with the subscription.',
                  );
                }

                final bool isFree =
                    response.extras['Is_Free_Subscription'] as bool? ?? false;
                final num amount = response.extras['Amount'] as num? ?? 0;
                final String orderId =
                    response.extras['Razorpay_Order_ID'] as String? ?? '';
                final String keyId =
                    response.extras['Razorpay_Key_ID'] as String? ?? '';
                final int amountInPaise =
                    response.extras['Amount_In_Paise'] as int? ??
                    (amount * 100).round();

                if (isFree || amount == 0) {
                  setModalState(() {
                    successMessage = switch (sheetMode) {
                      _SubscriptionPlanMode.renew =>
                        'Subscription renewed successfully.',
                      _SubscriptionPlanMode.change =>
                        'Subscription plan changed successfully.',
                      _SubscriptionPlanMode.subscribe =>
                        'Subscription activated successfully.',
                    };
                  });
                } else {
                  VendorData? vendor;
                  try {
                    vendor = await VendorService.fetchVendorInfo();
                  } catch (_) {
                    vendor = null;
                  }
                  final RazorpayCheckoutResult checkoutResult =
                      await RazorpayCheckoutService.openCheckout(
                        keyId: keyId,
                        amountInPaise: amountInPaise,
                        name: 'Urban Easy Flats',
                        description: switch (sheetMode) {
                          _SubscriptionPlanMode.renew =>
                            'Property Subscription Renewal',
                          _SubscriptionPlanMode.change =>
                            'Property Subscription Change',
                          _SubscriptionPlanMode.subscribe =>
                            'Property Subscription',
                        },
                        orderId: orderId,
                        currency:
                            response.extras['Currency'] as String? ?? 'INR',
                        prefillName: vendor?.fullName,
                        prefillEmail: vendor?.email,
                        prefillContact: vendor?.phone,
                      );

                  if (!checkoutResult.success) {
                    throw Exception(
                      checkoutResult.message ??
                          'Subscription payment was not completed.',
                    );
                  }

                  setModalState(() {
                    successMessage = switch (sheetMode) {
                      _SubscriptionPlanMode.renew =>
                        'Payment completed. Renewal is being processed.',
                      _SubscriptionPlanMode.change =>
                        'Payment completed. Plan change is being processed.',
                      _SubscriptionPlanMode.subscribe =>
                        'Payment completed. Subscription activation is being processed.',
                    };
                  });
                }
                await _loadProperties();
                if (!context.mounted) {
                  return;
                }
                await Future<void>.delayed(const Duration(milliseconds: 900));
                if (context.mounted && Navigator.of(context).canPop()) {
                  closingAfterSuccess = true;
                  Navigator.of(context).pop();
                }
              } catch (error) {
                final String message = error.toString().replaceFirst(
                  'Exception: ',
                  '',
                );
                setModalState(() {
                  errorMessage = message;
                  purchasing = false;
                });
                if (sheetMode == _SubscriptionPlanMode.renew &&
                    currentExtraContracts() < initialExtraContracts) {
                  await showRenewalReductionPopup(message);
                }
              } finally {
                if (context.mounted && !closingAfterSuccess) {
                  setModalState(() {
                    purchasing = false;
                  });
                }
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
                      switch (sheetMode) {
                        _SubscriptionPlanMode.renew =>
                          'Renew Property Subscription',
                        _SubscriptionPlanMode.change =>
                          'Change Property Subscription',
                        _SubscriptionPlanMode.subscribe =>
                          'Property Subscription',
                      },
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      propertyInfo.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        ToneBadge(
                          label: _propertyTypeLabel(propertyInfo.propertyType),
                          tone: UiTone.brand,
                        ),
                        if (propertyInfo.currentSubscriptionTitle?.isNotEmpty ==
                            true)
                          ToneBadge(
                            label: propertyInfo.currentSubscriptionTitle!,
                            tone: UiTone.warning,
                          ),
                        ToneBadge(
                          label:
                              '${propertyInfo.availableResidentContractsCreationCount ?? 0} contracts available',
                          tone: UiTone.success,
                        ),
                        ToneBadge(
                          label:
                              '${propertyInfo.freeResidentContractsCount ?? 0} free contracts',
                          tone: UiTone.neutral,
                        ),
                      ],
                    ),
                    if (sheetMode == _SubscriptionPlanMode.subscribe &&
                        !propertyInfo.wasSubscribedAtLeastOnce &&
                        freeContractsFromSettings(appSettings) > 0) ...<Widget>[
                      const SizedBox(height: 12),
                      _InlineStatusCard(
                        title: 'Free Contracts',
                        message:
                            '${freeContractsFromSettings(appSettings)} resident contract(s) are available without extra cost on the first subscription for this property type.',
                        tone: UiTone.brand,
                      ),
                    ],
                    if (errorMessage != null) ...<Widget>[
                      const SizedBox(height: 12),
                      _InlineStatusCard(
                        title: 'Issue',
                        message: errorMessage!,
                        tone: UiTone.danger,
                      ),
                    ],
                    if (successMessage != null) ...<Widget>[
                      const SizedBox(height: 12),
                      _InlineStatusCard(
                        title: 'Updated',
                        message: successMessage!,
                        tone: UiTone.success,
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (!reviewStep && plans.isEmpty)
                      const CustomCard(
                        child: Text(
                          'No subscription plans are available for this property type right now.',
                        ),
                      )
                    else if (!reviewStep)
                      ...plans.map((SubscriptionPlanData plan) {
                        final bool selected =
                            selectedPlanId == plan.subscriptionId;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: CustomCard(
                            onTap: () {
                              setModalState(() {
                                selectedPlanId = plan.subscriptionId;
                                calculation = null;
                                successMessage = null;
                              });
                            },
                            color: selected
                                ? AppTheme.primarySoft
                                : AppTheme.surface,
                            borderColor: selected
                                ? AppTheme.primary
                                : AppTheme.borderSoft,
                            padding: CustomCardPadding.sm,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        plan.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    Radio<String>(
                                      value: plan.subscriptionId,
                                      groupValue: selectedPlanId,
                                      onChanged: (String? value) {
                                        setModalState(() {
                                          selectedPlanId = value;
                                          calculation = null;
                                          successMessage = null;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                Text(
                                  plan.description,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: AppTheme.textSecondary),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: <Widget>[
                                    ToneBadge(
                                      label:
                                          'Rs ${plan.price.toStringAsFixed(0)}',
                                      tone: UiTone.brand,
                                    ),
                                    ToneBadge(
                                      label: '${plan.duration} days',
                                      tone: UiTone.neutral,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    if (reviewStep) ...<Widget>[
                      if (sheetMode == _SubscriptionPlanMode.renew)
                        CustomCard(
                          padding: CustomCardPadding.sm,
                          color: AppTheme.primarySoft,
                          borderColor: AppTheme.primary,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                propertyInfo.currentSubscriptionTitle ??
                                    'Current Plan',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              if (_hasText(
                                propertyInfo.currentSubscriptionDescription,
                              ))
                                Text(
                                  propertyInfo.currentSubscriptionDescription!,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: AppTheme.textSecondary),
                                ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: <Widget>[
                                  if (propertyInfo.currentSubscriptionPrice !=
                                      null)
                                    ToneBadge(
                                      label: _formatPropertyCurrency(
                                        propertyInfo.currentSubscriptionPrice,
                                      ),
                                      tone: UiTone.brand,
                                    ),
                                  if (propertyInfo
                                          .currentSubscriptionDuration !=
                                      null)
                                    ToneBadge(
                                      label:
                                          '${propertyInfo.currentSubscriptionDuration} days',
                                      tone: UiTone.neutral,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        )
                      else if (findPlanById(plans, selectedPlanId) !=
                          null) ...<Widget>[
                        CustomCard(
                          padding: CustomCardPadding.sm,
                          color: AppTheme.primarySoft,
                          borderColor: AppTheme.primary,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                findPlanById(plans, selectedPlanId)!.title,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                findPlanById(
                                  plans,
                                  selectedPlanId,
                                )!.description,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: <Widget>[
                                  ToneBadge(
                                    label: _formatPropertyCurrency(
                                      findPlanById(
                                        plans,
                                        selectedPlanId,
                                      )!.price,
                                    ),
                                    tone: UiTone.brand,
                                  ),
                                  ToneBadge(
                                    label:
                                        '${findPlanById(plans, selectedPlanId)!.duration} days',
                                    tone: UiTone.neutral,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: extraContractsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Extra resident contracts',
                              ),
                              onChanged: (_) {
                                setModalState(() {
                                  errorMessage = null;
                                  successMessage = null;
                                  calculation = null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            children: <Widget>[
                              SizedBox(
                                width: 42,
                                child: IconButton(
                                  onPressed: calculating
                                      ? null
                                      : () async {
                                          await updateExtraContracts(
                                            currentExtraContracts() + 1,
                                          );
                                        },
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ),
                              SizedBox(
                                width: 42,
                                child: IconButton(
                                  onPressed:
                                      calculating ||
                                          currentExtraContracts() <= 0
                                      ? null
                                      : () async {
                                          await updateExtraContracts(
                                            currentExtraContracts() - 1,
                                          );
                                        },
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: CustomButton(
                              label: calculation == null
                                  ? 'Calculate'
                                  : 'Recalculate',
                              isLoading: calculating,
                              onPressed: calculating
                                  ? null
                                  : calculateAndReview,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (calculation != null) ...<Widget>[
                      const SizedBox(height: 16),
                      CustomCard(
                        padding: CustomCardPadding.sm,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Calculation',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            _detailLine(
                              'Subscription',
                              'Rs ${calculation!.subscriptionPrice.toStringAsFixed(0)}',
                            ),
                            _detailLine(
                              'Extra contracts',
                              '${calculation!.extraContractsCount}',
                            ),
                            _detailLine(
                              'Free contracts',
                              '${calculation!.freeContractsCount}',
                            ),
                            _detailLine(
                              'Total available',
                              '${calculation!.totalAvailableContracts}',
                            ),
                            _detailLine(
                              'Amount per contract',
                              'Rs ${calculation!.amountPerContract.toStringAsFixed(0)}',
                            ),
                            _detailLine(
                              'Subscription months',
                              '${calculation!.subscriptionMonths}',
                            ),
                            if (calculation!.extraContractsCount > 0)
                              _detailLine(
                                'Extra contract formula',
                                '${calculation!.extraContractsCount} x Rs '
                                    '${calculation!.amountPerContract.toStringAsFixed(0)} x '
                                    '${calculation!.subscriptionMonths}',
                              ),
                            _detailLine(
                              'Extra contracts amount',
                              'Rs ${calculation!.extraContractsAmount.toStringAsFixed(0)}',
                            ),
                            _detailLine(
                              'Subtotal',
                              'Rs ${calculation!.subtotal.toStringAsFixed(0)}',
                            ),
                            _detailLine(
                              'GST',
                              '${calculation!.gstPercentage.toStringAsFixed(0)}% | Rs ${calculation!.gstAmount.toStringAsFixed(0)}',
                            ),
                            _detailLine(
                              'Total',
                              'Rs ${calculation!.totalAmount.toStringAsFixed(0)}',
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: CustomButton(
                            label:
                                reviewStep &&
                                    sheetMode != _SubscriptionPlanMode.renew
                                ? 'Back'
                                : 'Close',
                            variant: CustomButtonVariant.outline,
                            onPressed: purchasing
                                ? null
                                : () {
                                    if (reviewStep &&
                                        sheetMode !=
                                            _SubscriptionPlanMode.renew) {
                                      setModalState(() {
                                        reviewStep = false;
                                        calculation = null;
                                        errorMessage = null;
                                        successMessage = null;
                                      });
                                      return;
                                    }
                                    Navigator.of(context).pop();
                                  },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomButton(
                            label: reviewStep
                                ? (sheetMode == _SubscriptionPlanMode.renew
                                      ? 'Renew Plan Now'
                                      : 'Proceed to Pay')
                                : 'Proceed',
                            isLoading: reviewStep ? purchasing : calculating,
                            onPressed: reviewStep
                                ? (purchasing ? null : purchase)
                                : (calculating || plans.isEmpty)
                                ? null
                                : calculateAndReview,
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

    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        extraContractsController.dispose();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int approvedCount = _properties
        .where(
          (PropertyRecord item) =>
              item.isActive && item.status == PropertyStatus.approved,
        )
        .length;
    final int pendingCount = _properties
        .where(
          (PropertyRecord item) =>
              item.isActive && item.status == PropertyStatus.pending,
        )
        .length;

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              titleSpacing: 16,
              title: const Text('Properties'),
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(1),
                child: Divider(height: 1, thickness: 1, color: AppTheme.border),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _loadInitialData,
        child: ListView(
          padding: AppTheme.pagePadding,
          children: <Widget>[
            _PropertySummaryHero(
              liveCount: _totalCount,
              totalCount: _totalCount,
              approvedCount: approvedCount,
              pendingCount: pendingCount,
              onAddProperty: _openPropertySheet,
            ),
            const SizedBox(height: 14),
            _PropertyFilterPanel(
              searchController: _searchController,
              typeFilter: _typeFilter,
              subTypeFilter: _subTypeFilter,
              categoryTypeFilter: _categoryTypeFilter,
              propertyTypeLabels: _propertyTypeLabels,
              stateId: _stateId,
              states: _states,
              cityId: _cityId,
              cities: _cities,
              onApply: _applyFilters,
              onBack: _handleBackPressed,
              onClear: _clearFilters,
              onTypeChanged: (int? value) {
                setState(() {
                  _typeFilter = value;
                  _subTypeFilter = null;
                });
              },
              onSubTypeChanged: (int? value) {
                setState(() {
                  _subTypeFilter = value;
                });
              },
              onCategoryTypeChanged: (int? value) {
                setState(() {
                  _categoryTypeFilter = value;
                });
              },
              onStateChanged: (String? value) async {
                setState(() {
                  _stateId = value;
                  _cityId = null;
                });
                await _loadCitiesForSelectedState();
              },
              onCityChanged: (String? value) {
                setState(() {
                  _cityId = value;
                });
              },
            ),
            const SizedBox(height: 14),
            _PropertyListHeader(
              page: _page + 1,
              visibleCount: _properties.length,
              totalCount: _totalCount,
            ),
            const SizedBox(height: 14),
            CustomTabBar(
              style: CustomTabBarStyle.pill,
              currentIndex: _statusFilter == null
                  ? 0
                  : PropertyStatus.values.indexOf(_statusFilter!) + 1,
              onChanged: (int index) {
                setState(() {
                  _statusFilter = index == 0
                      ? null
                      : PropertyStatus.values[index - 1];
                });
                _loadProperties();
              },
              tabs: <CustomTabItem>[
                const CustomTabItem(label: 'All'),
                ...PropertyStatus.values.map(
                  (PropertyStatus status) => CustomTabItem(label: status.label),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 64),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              _PropertyErrorCard(
                message: _errorMessage!,
                onRetry: _loadInitialData,
              )
            else if (_properties.isEmpty)
              const CustomCard(
                child: Text('No properties found for the current filters.'),
              )
            else
              ..._properties.map((PropertyRecord property) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PropertyRecordCard(
                    property: property,
                    onDetails: () => _showPropertyDetails(property.id),
                    onEnquiries: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PropertyEnquiriesPage(
                            initialPropertyId: property.id,
                            onEnquiryStatusChanged: _loadProperties,
                          ),
                        ),
                      );
                      if (mounted) {
                        await _loadProperties();
                      }
                    },
                    onClone: () =>
                        _openPropertySheet(cloneFromPropertyId: property.id),
                    onManagePlan: () => _openSubscriptionSheet(
                      property.id,
                      mode: !property.isSubscribed
                          ? _SubscriptionPlanMode.subscribe
                          : property.subscriptionExpired == true
                          ? _SubscriptionPlanMode.renew
                          : _SubscriptionPlanMode.change,
                    ),
                    onEdit: () => _openPropertySheet(propertyId: property.id),
                    onToggle: () => _toggleProperty(property),
                  ),
                );
              }),
            if (!_isLoading && _totalCount > _pageSize) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: CustomButton(
                      label: 'Previous',
                      variant: CustomButtonVariant.outline,
                      onPressed: _page == 0
                          ? null
                          : () async {
                              setState(() {
                                _page -= 1;
                              });
                              await _loadProperties();
                            },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      label: 'Next',
                      onPressed: (_page + 1) * _pageSize >= _totalCount
                          ? null
                          : () async {
                              setState(() {
                                _page += 1;
                              });
                              await _loadProperties();
                            },
                    ),
                  ),
                ],
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

  String _propertyTypeLabel(int type) {
    return _propertyTypeLabels[type] ?? 'Property';
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _PropertyFormPage extends StatefulWidget {
  const _PropertyFormPage({
    this.propertyId,
    this.cloneFromPropertyId,
    required this.states,
    required this.onSaved,
  });

  final String? propertyId;
  final String? cloneFromPropertyId;
  final List<PropertyStateData> states;
  final Future<void> Function() onSaved;

  @override
  State<_PropertyFormPage> createState() => _PropertyFormPageState();
}

class _PropertyFormPageState extends State<_PropertyFormPage> {
  static const List<String> _stepTitles = <String>[
    'Basic Information',
    'Pricing & Financial Details',
    'Amenities & Features',
    'Owner Details & Media',
    'Location & Address Details',
  ];

  static const List<String> _stepShortTitles = <String>[
    'Basic',
    'Pricing',
    'Amenities',
    'Owner',
    'Location',
  ];

  int _currentStep = 0;
  bool _isLoadingData = false;
  bool _isSubmitting = false;
  bool _isUploadingMedia = false;

  bool get _isClone => widget.cloneFromPropertyId != null;
  bool get _isEdit => widget.propertyId != null;

  // Controllers
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();
  final TextEditingController _unitCtrl = TextEditingController();
  final TextEditingController _locationCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _rentCtrl = TextEditingController();
  final TextEditingController _depositCtrl = TextEditingController();
  final TextEditingController _areaCtrl = TextEditingController();
  final TextEditingController _bedroomsCtrl = TextEditingController();
  final TextEditingController _bathroomsCtrl = TextEditingController();
  final TextEditingController _ownerNameCtrl = TextEditingController();
  final TextEditingController _ownerPhoneCtrl = TextEditingController();
  final TextEditingController _ownerEmailCtrl = TextEditingController();
  final TextEditingController _availableFromCtrl = TextEditingController(
    text: DateTime.now().toIso8601String().split('T').first,
  );
  final TextEditingController _maintenanceCtrl = TextEditingController(
    text: '0',
  );
  final TextEditingController _brokerageCtrl = TextEditingController(text: '0');
  final TextEditingController _carpetAreaCtrl = TextEditingController();
  final TextEditingController _floorNoCtrl = TextEditingController(text: '0');
  final TextEditingController _noOfFloorsCtrl = TextEditingController(
    text: '0',
  );
  final TextEditingController _noOfVacancyCtrl = TextEditingController(
    text: '0',
  );
  final TextEditingController _balconiesCtrl = TextEditingController(text: '0');
  final TextEditingController _localityCtrl = TextEditingController();
  final TextEditingController _pincodeCtrl = TextEditingController();
  final TextEditingController _ownerAddressCtrl = TextEditingController();
  final TextEditingController _parkingSlotsCtrl = TextEditingController(
    text: '0',
  );
  final TextEditingController _parkingChargesCtrl = TextEditingController(
    text: '0',
  );
  final TextEditingController _metroCtrl = TextEditingController();
  final TextEditingController _hospitalCtrl = TextEditingController();
  final TextEditingController _schoolCtrl = TextEditingController();
  final TextEditingController _shoppingMallCtrl = TextEditingController();
  final TextEditingController _restaurantCtrl = TextEditingController();
  final TextEditingController _atmCtrl = TextEditingController();
  final TextEditingController _rulesCtrl = TextEditingController();

  // Form state
  int _propertyType = 1;
  int _subType = 1;
  int _pgSharingType = 1;
  int _categoryType = 1;
  int _facingDirection = 0;
  int _furnishedType = 0;
  int _gender = 0;
  bool _parkingAvailable = false;
  int _parkingType = 1;
  int _electricityBillType = 1;
  int _waterBillType = 1;
  int _gasBillType = 4;
  int _internetBillType = 4;
  int _tenantType = 1;
  int _petPolicy = 1;
  int _smokingPolicy = 1;
  int _visitorsPolicy = 2;
  List<int> _selectedAmenities = <int>[1];
  List<_UploadedAsset> _propertyImages = <_UploadedAsset>[];
  _UploadedAsset? _floorPlanDocument;
  String? _selectedStateId;
  String? _selectedCityId;
  List<PropertyCityData> _modalCities = <PropertyCityData>[];
  double _pickedLatitude = 0;
  double _pickedLongitude = 0;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _unitCtrl.dispose();
    _locationCtrl.dispose();
    _addressCtrl.dispose();
    _rentCtrl.dispose();
    _depositCtrl.dispose();
    _areaCtrl.dispose();
    _bedroomsCtrl.dispose();
    _bathroomsCtrl.dispose();
    _ownerNameCtrl.dispose();
    _ownerPhoneCtrl.dispose();
    _ownerEmailCtrl.dispose();
    _availableFromCtrl.dispose();
    _maintenanceCtrl.dispose();
    _brokerageCtrl.dispose();
    _carpetAreaCtrl.dispose();
    _floorNoCtrl.dispose();
    _noOfFloorsCtrl.dispose();
    _noOfVacancyCtrl.dispose();
    _balconiesCtrl.dispose();
    _localityCtrl.dispose();
    _pincodeCtrl.dispose();
    _ownerAddressCtrl.dispose();
    _parkingSlotsCtrl.dispose();
    _parkingChargesCtrl.dispose();
    _metroCtrl.dispose();
    _hospitalCtrl.dispose();
    _schoolCtrl.dispose();
    _shoppingMallCtrl.dispose();
    _restaurantCtrl.dispose();
    _atmCtrl.dispose();
    _rulesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    final String? sourceId = widget.propertyId ?? widget.cloneFromPropertyId;
    if (sourceId == null) {
      return;
    }

    setState(() => _isLoadingData = true);
    try {
      final PropertyData? existing = await PropertyService.fetchPropertyInfo(
        sourceId,
      );
      if (!mounted || existing == null) {
        return;
      }

      _titleCtrl.text = _isClone ? '${existing.title} Copy' : existing.title;
      _descriptionCtrl.text = existing.description;
      _unitCtrl.text = existing.flatUnitNo ?? '';
      _locationCtrl.text = existing.locationAddress ?? existing.address ?? '';
      _addressCtrl.text = existing.address ?? '';
      _rentCtrl.text = existing.rent.toStringAsFixed(0);
      _depositCtrl.text = existing.deposit.toStringAsFixed(0);
      _areaCtrl.text = existing.area?.toStringAsFixed(0) ?? '';
      _bedroomsCtrl.text = existing.bedrooms?.toString() ?? '';
      _bathroomsCtrl.text = existing.bathrooms?.toString() ?? '';
      _ownerNameCtrl.text = existing.ownerName ?? '';
      _ownerPhoneCtrl.text = existing.ownerPhone ?? '';
      _ownerEmailCtrl.text = existing.ownerEmail ?? '';
      _availableFromCtrl.text =
          existing.availableFrom?.split('T').first ??
          DateTime.now().toIso8601String().split('T').first;
      _maintenanceCtrl.text = existing.maintenance?.toStringAsFixed(0) ?? '0';
      _brokerageCtrl.text = existing.brokerage?.toStringAsFixed(0) ?? '0';
      _carpetAreaCtrl.text = existing.carpetArea?.toStringAsFixed(0) ?? '';
      _floorNoCtrl.text = existing.floor?.toString() ?? '0';
      _noOfFloorsCtrl.text = existing.noOfFloors?.toString() ?? '0';
      _noOfVacancyCtrl.text = existing.noOfVacancy?.toString() ?? '0';
      _balconiesCtrl.text = existing.balconies?.toString() ?? '0';
      _localityCtrl.text = existing.locality ?? '';
      _pincodeCtrl.text = existing.pincode ?? '';
      _ownerAddressCtrl.text = existing.ownerAddress ?? '';
      _parkingSlotsCtrl.text = existing.parkingSlots?.toString() ?? '0';
      _parkingChargesCtrl.text =
          existing.parkingCharges?.toStringAsFixed(0) ?? '0';
      _metroCtrl.text = existing.metroOrBusStation ?? '';
      _hospitalCtrl.text = existing.hospital ?? '';
      _schoolCtrl.text = existing.schoolOrCollege ?? '';
      _shoppingMallCtrl.text = existing.shoppingMall ?? '';
      _restaurantCtrl.text = existing.restaurant ?? '';
      _atmCtrl.text = existing.atmOrBank ?? '';
      _rulesCtrl.text = existing.propertyRulesDescription ?? '';

      _propertyType = existing.propertyType;
      _subType =
          existing.subType ??
          (_propertySubTypeLabels[_propertyType]?.keys.first ?? 1);
      _pgSharingType = existing.pgSharingType ?? 1;
      _categoryType = existing.category ?? 1;
      _facingDirection =
          existing.facingDirectionType ??
          (existing.facing != null
              ? _facingDirectionLabels.entries
                        .where(
                          (MapEntry<int, String> e) =>
                              e.value.toLowerCase() ==
                              existing.facing!.toLowerCase(),
                        )
                        .map((MapEntry<int, String> e) => e.key)
                        .firstOrNull ??
                    0
              : 0);
      _furnishedType = existing.furnishedType ?? 0;
      _gender = existing.gender ?? 0;
      _parkingAvailable = existing.whetherParkingAvailable ?? false;
      _parkingType = existing.parkingType ?? 1;
      _electricityBillType = existing.electricityBillType ?? 1;
      _waterBillType = existing.waterBillType ?? 1;
      _gasBillType = existing.gasBillType ?? 4;
      _internetBillType = existing.internetBillType ?? 4;
      _tenantType = existing.preferredTenantType ?? 1;
      _petPolicy = existing.petPolicy ?? 1;
      _smokingPolicy = existing.smokingPolicy ?? 1;
      _visitorsPolicy = existing.visitorsPolicy ?? 2;
      _selectedAmenities = List<int>.from(existing.amenityIds ?? <int>[1]);
      _propertyImages = <_UploadedAsset>[
        for (int i = 0; i < (existing.imageIds?.length ?? 0); i += 1)
          _UploadedAsset(
            id: existing.imageIds![i],
            label: 'Image ${i + 1}',
            url: i < (existing.images?.length ?? 0)
                ? existing.images![i]
                : null,
          ),
      ];
      _floorPlanDocument = (existing.floorPlanDocumentId?.isNotEmpty ?? false)
          ? _UploadedAsset(
              id: existing.floorPlanDocumentId!,
              label: 'Floor Plan',
              url: existing.floorPlanDocumentUrl,
            )
          : null;
      _pickedLatitude = existing.latitude ?? 0;
      _pickedLongitude = existing.longitude ?? 0;
      _selectedStateId = existing.stateId;
      _selectedCityId = existing.cityId;

      if (_selectedStateId != null && _selectedStateId!.isNotEmpty) {
        try {
          final result = await PropertyService.filterCities(
            stateId: _selectedStateId,
            limit: 100,
          );
          if (mounted) {
            _modalCities = result.cities;
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  void _showMsg(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _changeState(String? value) async {
    setState(() {
      _selectedStateId = value;
      _selectedCityId = null;
      _modalCities = <PropertyCityData>[];
    });
    if (value == null || value.isEmpty) {
      return;
    }
    try {
      final result = await PropertyService.filterCities(
        stateId: value,
        limit: 100,
      );
      if (mounted) {
        setState(() => _modalCities = result.cities);
      }
    } catch (_) {}
  }

  Future<void> _uploadPropertyImages() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: <String>['jpg', 'jpeg', 'png', 'webp'],
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    setState(() => _isUploadingMedia = true);
    try {
      for (final PlatformFile file in result.files) {
        if ((file.path ?? '').isEmpty) {
          continue;
        }
        final String? imageId = await UploadService.uploadImage(
          File(file.path!),
        );
        if (imageId == null || imageId.isEmpty) {
          throw Exception('Failed to upload ${file.name}.');
        }
        final String? imageUrl = await UploadService.fetchImageInfo(imageId);
        if (!mounted) {
          return;
        }
        setState(() {
          if (!_propertyImages.any(
            (_UploadedAsset item) => item.id == imageId,
          )) {
            _propertyImages = <_UploadedAsset>[
              ..._propertyImages,
              _UploadedAsset(id: imageId, label: file.name, url: imageUrl),
            ];
          }
        });
      }
    } catch (error) {
      _showMsg(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isUploadingMedia = false);
      }
    }
  }

  Future<void> _uploadFloorPlan() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: <String>['pdf', 'png', 'jpg', 'jpeg', 'webp'],
    );
    if (result == null ||
        result.files.isEmpty ||
        (result.files.single.path ?? '').isEmpty) {
      return;
    }
    setState(() => _isUploadingMedia = true);
    try {
      final PlatformFile file = result.files.single;
      final String? documentId = await UploadService.uploadDocument(
        File(file.path!),
      );
      if (documentId == null || documentId.isEmpty) {
        throw Exception('Failed to upload the floor plan.');
      }
      final String? documentUrl = await UploadService.fetchDocumentInfo(
        documentId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _floorPlanDocument = _UploadedAsset(
          id: documentId,
          label: file.name,
          url: documentUrl,
        );
      });
    } catch (error) {
      _showMsg(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isUploadingMedia = false);
      }
    }
  }

  // ── Validation ──────────────────────────────────────────────────────

  bool _validateStep(int step) {
    switch (step) {
      case 0:
        return _validateStep1();
      case 1:
        return _validateStep2();
      case 2:
        return _validateStep3();
      case 3:
        return _validateStep4();
      case 4:
        return _validateStep5();
      default:
        return true;
    }
  }

  bool _validateStep1() {
    if (_titleCtrl.text.trim().isEmpty) {
      _showMsg('Title is required.');
      return false;
    }
    if (_unitCtrl.text.trim().isEmpty) {
      _showMsg(
        _propertyType == 3
            ? 'Beds field is required.'
            : 'Flat/Unit No is required.',
      );
      return false;
    }
    if (_descriptionCtrl.text.trim().isEmpty) {
      _showMsg('Description is required.');
      return false;
    }
    if (_furnishedType == 0) {
      _showMsg('Select the furnishing status.');
      return false;
    }
    if (_propertyType != 3) {
      if (_facingDirection == 0) {
        _showMsg('Facing direction is required.');
        return false;
      }
      if (_areaCtrl.text.trim().isEmpty) {
        _showMsg('Total area is required.');
        return false;
      }
      if (_bedroomsCtrl.text.trim().isEmpty) {
        _showMsg('Bedrooms is required.');
        return false;
      }
      if (_bathroomsCtrl.text.trim().isEmpty) {
        _showMsg('Bathrooms is required.');
        return false;
      }
    }
    return true;
  }

  bool _validateStep2() {
    final double rent = double.tryParse(_rentCtrl.text.trim()) ?? 0;
    if (rent <= 0) {
      _showMsg('Monthly rent must be greater than 0.');
      return false;
    }
    if (_availableFromCtrl.text.trim().isEmpty) {
      _showMsg('Available from date is required.');
      return false;
    }
    return true;
  }

  bool _validateStep3() {
    if (_selectedAmenities.isEmpty) {
      _showMsg('Select at least one amenity.');
      return false;
    }
    return true;
  }

  bool _validateStep4() {
    if (_ownerNameCtrl.text.trim().isEmpty) {
      _showMsg('Owner name is required.');
      return false;
    }
    final String phone = _ownerPhoneCtrl.text.trim();
    if (phone.isEmpty || !RegExp(r'^\d{10}$').hasMatch(phone)) {
      _showMsg('Enter a valid 10-digit owner phone number.');
      return false;
    }
    final String email = _ownerEmailCtrl.text.trim();
    if (email.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showMsg('Enter a valid owner email address.');
      return false;
    }
    if (_ownerAddressCtrl.text.trim().isEmpty) {
      _showMsg('Owner address is required.');
      return false;
    }
    if (_propertyImages.isEmpty) {
      _showMsg('Upload at least one property image.');
      return false;
    }
    return true;
  }

  bool _validateStep5() {
    if (_addressCtrl.text.trim().isEmpty) {
      _showMsg('Full address is required.');
      return false;
    }
    if (_selectedStateId == null || _selectedStateId!.isEmpty) {
      _showMsg('State is required.');
      return false;
    }
    if (_selectedCityId == null || _selectedCityId!.isEmpty) {
      _showMsg('City is required.');
      return false;
    }
    return true;
  }

  // ── Submit ──────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_validateStep5()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final Map<String, dynamic> payload = <String, dynamic>{
      if (widget.propertyId != null) 'PropertyID': widget.propertyId,
      'Property_Title': _titleCtrl.text.trim(),
      'Property_Description': _descriptionCtrl.text.trim(),
      'Flat_Or_Unit_No': _unitCtrl.text.trim(),
      'Property_Type': _propertyType,
      'Category_Type': _categoryType,
      'Sub_Type': _subType,
      'Facing_Direction_Type': _facingDirection,
      'Furnished_Type': _furnishedType,
      'Floor_No': int.tryParse(_floorNoCtrl.text.trim()) ?? 0,
      'No_Of_Floors': int.tryParse(_noOfFloorsCtrl.text.trim()) ?? 0,
      'No_Of_Vacancy': int.tryParse(_noOfVacancyCtrl.text.trim()) ?? 0,
      'PG_Sharing_Type': _propertyType == 3 ? _pgSharingType : 0,
      'Gender': _propertyType == 3 ? _gender : 0,
      'Total_Area': double.tryParse(_areaCtrl.text.trim()) ?? 0,
      'Carpet_Area': double.tryParse(_carpetAreaCtrl.text.trim()) ?? 0,
      'Bedrooms': int.tryParse(_bedroomsCtrl.text.trim()) ?? 0,
      'Bathrooms': int.tryParse(_bathroomsCtrl.text.trim()) ?? 0,
      'Balconies': int.tryParse(_balconiesCtrl.text.trim()) ?? 0,
      'Locality': _localityCtrl.text.trim(),
      'Pincode': _pincodeCtrl.text.trim(),
      'Monthly_Rent': double.tryParse(_rentCtrl.text.trim()) ?? 0,
      'Security_Deposit': double.tryParse(_depositCtrl.text.trim()) ?? 0,
      'Maintainance_Charge': double.tryParse(_maintenanceCtrl.text.trim()) ?? 0,
      'Brokerage_Percentage': double.tryParse(_brokerageCtrl.text.trim()) ?? 0,
      'Available_From': _availableFromCtrl.text.trim(),
      'Electricity_Bill_Type': _electricityBillType,
      'Water_Bill_Type': _waterBillType,
      'Gas_Bill_Type': _gasBillType,
      'Internet_Bill_Type': _internetBillType,
      'Whether_Parking_Available': _parkingAvailable,
      'Parking_Type': _parkingAvailable ? _parkingType : 1,
      'Parking_Slots': _parkingAvailable
          ? (int.tryParse(_parkingSlotsCtrl.text.trim()) ?? 0)
          : 0,
      'Parking_Charges': _parkingAvailable
          ? (double.tryParse(_parkingChargesCtrl.text.trim()) ?? 0)
          : 0,
      'Amenities': _selectedAmenities,
      'Metro_Or_Bus_Station': _metroCtrl.text.trim(),
      'Hospital': _hospitalCtrl.text.trim(),
      'School_Or_College': _schoolCtrl.text.trim(),
      'Shopping_Mall': _shoppingMallCtrl.text.trim(),
      'Restaurant': _restaurantCtrl.text.trim(),
      'ATM_Or_Bank': _atmCtrl.text.trim(),
      'Preferred_Tenant_Type': _tenantType,
      'Pet_Policy': _petPolicy,
      'Smoking_Policy': _smokingPolicy,
      'Visitors_Policy': _visitorsPolicy,
      'Property_Rules_Description': _rulesCtrl.text.trim(),
      'Owner_Name': _ownerNameCtrl.text.trim(),
      'Owner_Phone': _ownerPhoneCtrl.text.trim(),
      'Owner_Email': _ownerEmailCtrl.text.trim(),
      'Owner_Address': _ownerAddressCtrl.text.trim(),
      'Whether_Property_Image_Array_Available': _propertyImages.isNotEmpty,
      'Property_ImageID_Array': _propertyImages
          .map((_UploadedAsset item) => item.id)
          .toList(),
      'Whether_Floor_Plan_Document_Available': _floorPlanDocument != null,
      'Floor_Plan_DocumentID': _floorPlanDocument?.id ?? '',
      'Latitude': _pickedLatitude,
      'Longitude': _pickedLongitude,
      'Location_Address': _locationCtrl.text.trim(),
      'Address': _addressCtrl.text.trim(),
      'Whether_State_Available':
          _selectedStateId != null && _selectedStateId!.isNotEmpty,
      'StateID': _selectedStateId ?? '',
      'Whether_City_Available':
          _selectedCityId != null && _selectedCityId!.isNotEmpty,
      'CityID': _selectedCityId ?? '',
    };

    try {
      final response = widget.propertyId == null
          ? await PropertyService.createProperty(payload)
          : await PropertyService.editProperty(payload);

      if (!response.success) {
        throw Exception(
          response.message ?? response.status ?? 'Unable to save the property.',
        );
      }

      final String? createdPropertyId =
          response.extras['PropertyID'] as String? ??
          response.extras['Property_ID'] as String?;
      if (!mounted) {
        return;
      }
      _showMsg(
        _isClone
            ? 'Property cloned successfully.'
            : _isEdit
            ? 'Property updated successfully.'
            : 'Property created successfully.',
      );
      await widget.onSaved();
      if (mounted) {
        Navigator.of(context).pop(
          widget.propertyId == null
              ? _PropertyFormResult(
                  createdPropertyId: createdPropertyId,
                  openSubscriptionAfterSave:
                      (createdPropertyId ?? '').isNotEmpty,
                )
              : const _PropertyFormResult(),
        );
      }
    } catch (error) {
      _showMsg(error.toString().replaceFirst('Exception: ', ''));
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // ── Navigation ──────────────────────────────────────────────────────

  void _nextStep() {
    if (_validateStep(_currentStep)) {
      setState(() => _currentStep += 1);
    }
  }

  void _previousStep() {
    setState(() => _currentStep -= 1);
  }

  List<MapEntry<int, String>> _amenityOptionsForCurrentType() {
    if (_propertyType != 3) {
      return _propertyAmenityLabels.entries.toList();
    }

    return _propertyAmenityLabels.entries
        .where(
          (MapEntry<int, String> entry) =>
              !_pgHiddenAmenityIds.contains(entry.key),
        )
        .toList();
  }

  bool _isImageAsset(_UploadedAsset asset) {
    final String source = '${asset.label} ${asset.url ?? ''}'.toLowerCase();
    return source.contains('.jpg') ||
        source.contains('.jpeg') ||
        source.contains('.png') ||
        source.contains('.webp');
  }

  Widget _buildStepHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Step ${_currentStep + 1} of ${_stepTitles.length}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _stepTitles[_currentStep],
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadedImagePreview(_UploadedAsset item) {
    return SizedBox(
      width: 104,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Stack(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                child: Container(
                  width: 104,
                  height: 84,
                  color: AppTheme.surfaceMuted,
                  child: item.url?.isNotEmpty == true
                      ? Image.network(
                          item.url!,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (
                                BuildContext context,
                                Object error,
                                StackTrace? stackTrace,
                              ) {
                                return const Center(
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                    color: AppTheme.textMuted,
                                  ),
                                );
                              },
                        )
                      : const Center(
                          child: Icon(
                            Icons.image_outlined,
                            color: AppTheme.textMuted,
                          ),
                        ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _propertyImages = _propertyImages
                            .where(
                              (_UploadedAsset image) => image.id != item.id,
                            )
                            .toList();
                      });
                    },
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorPlanPreview() {
    if (_floorPlanDocument == null) {
      return const SizedBox.shrink();
    }

    final _UploadedAsset asset = _floorPlanDocument!;

    return SizedBox(
      width: double.infinity,
      child: CustomCard(
        padding: CustomCardPadding.sm,
        color: AppTheme.surfaceMuted,
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              child: Container(
                width: 68,
                height: 68,
                color: AppTheme.surface,
                child: _isImageAsset(asset) && asset.url?.isNotEmpty == true
                    ? Image.network(
                        asset.url!,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (
                              BuildContext context,
                              Object error,
                              StackTrace? stackTrace,
                            ) {
                              return const Icon(
                                Icons.description_outlined,
                                color: AppTheme.textMuted,
                              );
                            },
                      )
                    : const Icon(
                        Icons.description_outlined,
                        color: AppTheme.textMuted,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    asset.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isImageAsset(asset)
                        ? 'Image preview attached'
                        : 'Document attached',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() => _floorPlanDocument = null);
              },
              icon: const Icon(Icons.delete_outline_rounded),
              color: AppTheme.textSecondary,
              tooltip: 'Remove floor plan',
            ),
          ],
        ),
      ),
    );
  }

  // ── Stepper indicator ───────────────────────────────────────────────

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < _stepTitles.length; i += 1) ...<Widget>[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= _currentStep
                      ? AppTheme.primary
                      : AppTheme.borderSoft,
                ),
              ),
            _buildStepCircle(i),
          ],
        ],
      ),
    );
  }

  Widget _buildStepCircle(int index) {
    final bool isCompleted = index < _currentStep;
    final bool isCurrent = index == _currentStep;
    return GestureDetector(
      onTap: index < _currentStep
          ? () => setState(() => _currentStep = index)
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted || isCurrent
                  ? AppTheme.primary
                  : Colors.transparent,
              border: Border.all(
                color: isCompleted || isCurrent
                    ? AppTheme.primary
                    : AppTheme.textSecondary,
                width: 2,
              ),
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isCurrent
                            ? Colors.white
                            : AppTheme.textSecondary,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _stepShortTitles[index],
            style: TextStyle(
              fontSize: 10,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
              color: isCurrent ? AppTheme.primary : AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Step 1: Basic Information ───────────────────────────────────────

  Widget _buildStep1() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: <Widget>[
        const SizedBox(height: 8),
        TextField(
          controller: _titleCtrl,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey<String>('ptype_$_propertyType'),
                value: _propertyType,
                decoration: const InputDecoration(labelText: 'Property type'),
                items: _propertyTypeLabels.entries
                    .map(
                      (MapEntry<int, String> entry) => DropdownMenuItem<int>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (int? value) {
                  setState(() {
                    _propertyType = value ?? 1;
                    final Map<int, String> options =
                        _propertySubTypeLabels[_propertyType] ??
                        const <int, String>{};
                    if (!options.containsKey(_subType)) {
                      _subType = options.isEmpty ? 1 : options.keys.first;
                    }
                    if (_propertyType == 3) {
                      _facingDirection = 0;
                      _selectedAmenities = _selectedAmenities
                          .where(
                            (int amenityId) =>
                                !_pgHiddenAmenityIds.contains(amenityId),
                          )
                          .toList();
                    } else {
                      _pgSharingType = 1;
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey<String>('subtype_$_propertyType'),
                value: _subType,
                decoration: const InputDecoration(labelText: 'Subtype'),
                items:
                    (_propertySubTypeLabels[_propertyType] ??
                            const <int, String>{})
                        .entries
                        .map(
                          (MapEntry<int, String> entry) =>
                              DropdownMenuItem<int>(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                        )
                        .toList(),
                onChanged: (int? value) {
                  setState(() => _subType = value ?? _subType);
                },
              ),
            ),
          ],
        ),
        if (_propertyType == 3) ...<Widget>[
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _pgSharingType,
                  decoration: const InputDecoration(labelText: 'PG sharing'),
                  items: _pgSharingLabels.entries
                      .map(
                        (MapEntry<int, String> entry) => DropdownMenuItem<int>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (int? value) {
                    setState(() => _pgSharingType = value ?? 1);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _gender,
                  decoration: const InputDecoration(
                    labelText: 'Gender preference',
                  ),
                  items: _genderLabels.entries
                      .map(
                        (MapEntry<int, String> entry) => DropdownMenuItem<int>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (int? value) {
                    setState(() => _gender = value ?? 0);
                  },
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _categoryType,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categoryTypeLabels.entries
                    .map(
                      (MapEntry<int, String> entry) => DropdownMenuItem<int>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (int? value) {
                  setState(() => _categoryType = value ?? 1);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _furnishedType,
                decoration: const InputDecoration(labelText: 'Furnished'),
                items: _furnishedTypeLabels.entries
                    .map(
                      (MapEntry<int, String> entry) => DropdownMenuItem<int>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (int? value) {
                  setState(() => _furnishedType = value ?? 0);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _unitCtrl,
                decoration: InputDecoration(
                  labelText: _propertyType == 3
                      ? 'Number of beds'
                      : 'Flat or unit no',
                ),
              ),
            ),
            if (_propertyType != 3) const SizedBox(width: 12),
            if (_propertyType != 3)
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _facingDirection,
                  decoration: const InputDecoration(
                    labelText: 'Facing direction',
                  ),
                  items: _facingDirectionLabels.entries
                      .map(
                        (MapEntry<int, String> entry) => DropdownMenuItem<int>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (int? value) {
                    setState(() => _facingDirection = value ?? 0);
                  },
                ),
              ),
          ],
        ),
        if (_propertyType != 3) ...<Widget>[
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _areaCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Total area'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _carpetAreaCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Carpet area (sq ft)',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _bedroomsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Bedrooms'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _bathroomsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Bathrooms'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _balconiesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Balconies'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _noOfFloorsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Total floors'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _noOfVacancyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Vacancies'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionCtrl,
          minLines: 3,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Step 2: Pricing & Financial Details ─────────────────────────────

  Widget _buildStep2() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: <Widget>[
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _rentCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Monthly rent',
                  prefixText: 'Rs ',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _depositCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Security deposit',
                  prefixText: 'Rs ',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _maintenanceCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Maintenance charge',
            prefixText: 'Rs ',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _availableFromCtrl,
          decoration: const InputDecoration(
            labelText: 'Available from',
            hintText: 'YYYY-MM-DD',
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Bill Types',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _electricityBillType,
                decoration: const InputDecoration(labelText: 'Electricity'),
                items: _billTypeLabels.entries
                    .map(
                      (MapEntry<int, String> e) => DropdownMenuItem<int>(
                        value: e.key,
                        child: Text(e.value),
                      ),
                    )
                    .toList(),
                onChanged: (int? v) => setState(() {
                  _electricityBillType = v ?? 1;
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _waterBillType,
                decoration: const InputDecoration(labelText: 'Water'),
                items: _billTypeLabels.entries
                    .map(
                      (MapEntry<int, String> e) => DropdownMenuItem<int>(
                        value: e.key,
                        child: Text(e.value),
                      ),
                    )
                    .toList(),
                onChanged: (int? v) => setState(() {
                  _waterBillType = v ?? 1;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _gasBillType,
                decoration: const InputDecoration(labelText: 'Gas'),
                items: _billTypeLabels.entries
                    .map(
                      (MapEntry<int, String> e) => DropdownMenuItem<int>(
                        value: e.key,
                        child: Text(e.value),
                      ),
                    )
                    .toList(),
                onChanged: (int? v) => setState(() {
                  _gasBillType = v ?? 4;
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _internetBillType,
                decoration: const InputDecoration(labelText: 'Internet'),
                items: _billTypeLabels.entries
                    .map(
                      (MapEntry<int, String> e) => DropdownMenuItem<int>(
                        value: e.key,
                        child: Text(e.value),
                      ),
                    )
                    .toList(),
                onChanged: (int? v) => setState(() {
                  _internetBillType = v ?? 4;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Parking',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Switch(
              value: _parkingAvailable,
              onChanged: (bool v) => setState(() => _parkingAvailable = v),
            ),
          ],
        ),
        if (_parkingAvailable) ...<Widget>[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _parkingType,
            decoration: const InputDecoration(labelText: 'Parking type'),
            items: _parkingTypeLabels.entries
                .map(
                  (MapEntry<int, String> e) =>
                      DropdownMenuItem<int>(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (int? v) => setState(() => _parkingType = v ?? 1),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _parkingSlotsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Slots'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _parkingChargesCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Monthly charges',
                    prefixText: 'Rs ',
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Step 3: Amenities & Features ────────────────────────────────────

  Widget _buildStep3() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: <Widget>[
        const SizedBox(height: 8),
        Text(
          'Amenities',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _amenityOptionsForCurrentType().map((
            MapEntry<int, String> entry,
          ) {
            final bool selected = _selectedAmenities.contains(entry.key);
            return FilterChip(
              label: Text(entry.value),
              selected: selected,
              onSelected: (bool value) {
                setState(() {
                  if (value) {
                    _selectedAmenities = <int>[
                      ..._selectedAmenities,
                      entry.key,
                    ];
                  } else {
                    _selectedAmenities = _selectedAmenities
                        .where((int item) => item != entry.key)
                        .toList();
                  }
                });
              },
            );
          }).toList(),
        ),
        if (_propertyType != 3) ...<Widget>[
          const SizedBox(height: 16),
          Text(
            'Nearby Facilities',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _metroCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Metro / Bus stop',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _hospitalCtrl,
                  decoration: const InputDecoration(labelText: 'Hospital'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _schoolCtrl,
                  decoration: const InputDecoration(
                    labelText: 'School / College',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _shoppingMallCtrl,
                  decoration: const InputDecoration(labelText: 'Shopping mall'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _restaurantCtrl,
                  decoration: const InputDecoration(labelText: 'Restaurant'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _atmCtrl,
                  decoration: const InputDecoration(labelText: 'ATM / Bank'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Rules & Policies',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _tenantType,
                  decoration: const InputDecoration(labelText: 'Tenant type'),
                  items: _tenantTypeLabels.entries
                      .map(
                        (MapEntry<int, String> e) => DropdownMenuItem<int>(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (int? v) => setState(() => _tenantType = v ?? 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _petPolicy,
                  decoration: const InputDecoration(labelText: 'Pet policy'),
                  items: _petPolicyLabels.entries
                      .map(
                        (MapEntry<int, String> e) => DropdownMenuItem<int>(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (int? v) => setState(() => _petPolicy = v ?? 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _smokingPolicy,
                  decoration: const InputDecoration(labelText: 'Smoking'),
                  items: _smokingPolicyLabels.entries
                      .map(
                        (MapEntry<int, String> e) => DropdownMenuItem<int>(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (int? v) =>
                      setState(() => _smokingPolicy = v ?? 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _visitorsPolicy,
                  decoration: const InputDecoration(labelText: 'Visitors'),
                  items: _visitorsPolicyLabels.entries
                      .map(
                        (MapEntry<int, String> e) => DropdownMenuItem<int>(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (int? v) =>
                      setState(() => _visitorsPolicy = v ?? 2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rulesCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Property rules',
              hintText: 'Describe any additional rules...',
            ),
          ),
        ] else ...<Widget>[
          const SizedBox(height: 16),
          CustomCard(
            padding: CustomCardPadding.sm,
            color: AppTheme.primarySoft,
            borderColor: AppTheme.primary.withValues(alpha: 0.12),
            child: Text(
              'PG amenities now follow the website flow. Nearby facilities and rules are hidden for PG listings.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Step 4: Owner Details & Media ───────────────────────────────────

  Widget _buildStep4() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: <Widget>[
        const SizedBox(height: 8),
        TextField(
          controller: _ownerNameCtrl,
          decoration: const InputDecoration(labelText: 'Owner name'),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _ownerPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Owner phone'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _ownerEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Owner email'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ownerAddressCtrl,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Owner address'),
        ),
        const SizedBox(height: 16),
        CustomCard(
          padding: CustomCardPadding.sm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Property Images',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                _isClone
                    ? 'You can keep or replace the copied uploads before saving the clone.'
                    : 'Upload property images (JPG, PNG, WebP).',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              Text(
                _propertyImages.isEmpty
                    ? 'No images uploaded yet.'
                    : '${_propertyImages.length} image(s) ready',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  label: _propertyImages.isEmpty
                      ? 'Upload Images'
                      : 'Add More Images',
                  variant: CustomButtonVariant.outline,
                  isLoading: _isUploadingMedia,
                  onPressed: _isUploadingMedia ? null : _uploadPropertyImages,
                ),
              ),
              if (_propertyImages.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _propertyImages
                      .map(
                        (_UploadedAsset item) =>
                            _buildUploadedImagePreview(item),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        CustomCard(
          padding: CustomCardPadding.sm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Floor Plan',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Upload an optional floor plan document.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  label: 'Upload Floor Plan',
                  variant: CustomButtonVariant.outline,
                  isLoading: _isUploadingMedia,
                  onPressed: _isUploadingMedia ? null : _uploadFloorPlan,
                ),
              ),
              if (_floorPlanDocument != null) ...<Widget>[
                const SizedBox(height: 12),
                _buildFloorPlanPreview(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Step 5: Location & Address ──────────────────────────────────────

  Widget _buildStep5() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: <Widget>[
        const SizedBox(height: 8),
        TextField(
          controller: _locationCtrl,
          decoration: InputDecoration(
            labelText: 'Location address',
            suffixIcon: IconButton(
              icon: const Icon(Icons.map_rounded, color: AppTheme.primary),
              tooltip: 'Pick on Map',
              onPressed: () async {
                final LocationPickerResult? result = await Navigator.of(context)
                    .push(
                      MaterialPageRoute<LocationPickerResult>(
                        builder: (_) => LocationPickerSheet(
                          initialLatitude: _pickedLatitude,
                          initialLongitude: _pickedLongitude,
                        ),
                      ),
                    );
                if (result != null) {
                  setState(() {
                    _pickedLatitude = result.latitude;
                    _pickedLongitude = result.longitude;
                    _locationCtrl.text = result.address;
                  });
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addressCtrl,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Full address'),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _localityCtrl,
                decoration: const InputDecoration(labelText: 'Locality'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _pincodeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Pincode'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final String? selected = await _showSearchableDropdown(
                    context: context,
                    title: 'Select State',
                    items: widget.states
                        .map(
                          (PropertyStateData s) =>
                              (value: s.stateId, label: s.stateName),
                        )
                        .toList(),
                    currentValue: _selectedStateId,
                  );
                  if (selected != _selectedStateId) {
                    _changeState(selected);
                  }
                },
                child: AbsorbPointer(
                  child: TextField(
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'State',
                      hintText: 'Select state',
                      suffixIcon: const Icon(Icons.arrow_drop_down),
                    ),
                    controller: TextEditingController(
                      text: _selectedStateId != null
                          ? widget.states
                                    .where(
                                      (PropertyStateData s) =>
                                          s.stateId == _selectedStateId,
                                    )
                                    .map((PropertyStateData s) => s.stateName)
                                    .firstOrNull ??
                                ''
                          : '',
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final String? selected = await _showSearchableDropdown(
                    context: context,
                    title: 'Select City',
                    items: _modalCities
                        .map(
                          (PropertyCityData c) =>
                              (value: c.cityId, label: c.cityName),
                        )
                        .toList(),
                    currentValue: _selectedCityId,
                  );
                  if (selected != _selectedCityId) {
                    setState(() => _selectedCityId = selected);
                  }
                },
                child: AbsorbPointer(
                  child: TextField(
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'City',
                      hintText: 'Select city',
                      suffixIcon: const Icon(Icons.arrow_drop_down),
                    ),
                    controller: TextEditingController(
                      text: _selectedCityId != null
                          ? _modalCities
                                    .where(
                                      (PropertyCityData c) =>
                                          c.cityId == _selectedCityId,
                                    )
                                    .map((PropertyCityData c) => c.cityName)
                                    .firstOrNull ??
                                ''
                          : '',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_pickedLatitude != 0 || _pickedLongitude != 0) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            'Map coordinates: ${_pickedLatitude.toStringAsFixed(6)}, ${_pickedLongitude.toStringAsFixed(6)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final String title = _isClone
        ? 'Clone Property'
        : _isEdit
        ? 'Edit Property'
        : 'Add Property';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.border),
        ),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: <Widget>[
                _buildStepIndicator(),
                _buildStepHeader(),
                const Divider(height: 1),
                Expanded(
                  child: IndexedStack(
                    index: _currentStep,
                    children: <Widget>[
                      _buildStep1(),
                      _buildStep2(),
                      _buildStep3(),
                      _buildStep4(),
                      _buildStep5(),
                    ],
                  ),
                ),
                const Divider(height: 1),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: <Widget>[
                        if (_currentStep == 0)
                          Expanded(
                            child: CustomButton(
                              label: 'Cancel',
                              variant: CustomButtonVariant.outline,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          )
                        else
                          Expanded(
                            child: CustomButton(
                              label: 'Back',
                              variant: CustomButtonVariant.outline,
                              onPressed: _previousStep,
                            ),
                          ),
                        const SizedBox(width: 12),
                        if (_currentStep < 4)
                          Expanded(
                            child: CustomButton(
                              label: 'Next',
                              onPressed: _nextStep,
                            ),
                          )
                        else
                          Expanded(
                            child: CustomButton(
                              label: _isClone
                                  ? 'Create Clone'
                                  : _isEdit
                                  ? 'Update Property'
                                  : 'Save Property',
                              isLoading: _isSubmitting,
                              onPressed: _isSubmitting || _isUploadingMedia
                                  ? null
                                  : _submit,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

bool _hasText(String? value) => value?.trim().isNotEmpty == true;

String _formatPropertyCurrency(num? value, {String suffix = ''}) {
  final num safeValue = value ?? 0;
  final bool isWhole = safeValue == safeValue.roundToDouble();
  final String formatted = isWhole
      ? safeValue.toStringAsFixed(0)
      : safeValue.toStringAsFixed(2);
  return 'Rs $formatted$suffix';
}

String _formatPropertyDate(String? value) {
  if (!_hasText(value)) {
    return 'N/A';
  }

  final DateTime? parsed = DateTime.tryParse(value!);
  if (parsed == null) {
    return value.split('T').first;
  }

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

  final DateTime local = parsed.toLocal();
  return '${local.day.toString().padLeft(2, '0')} ${months[local.month - 1]} ${local.year}';
}

String _propertyStatusLabelFromCode(int status) {
  return switch (status) {
    1 => 'Pending',
    2 => 'Approved',
    3 => 'Rejected',
    4 => 'Inactive',
    _ => 'Pending',
  };
}

UiTone _propertyStatusToneFromCode(int status) {
  return switch (status) {
    1 => UiTone.warning,
    2 => UiTone.success,
    3 => UiTone.danger,
    4 => UiTone.neutral,
    _ => UiTone.warning,
  };
}

String _propertyDisplayStatusLabel(PropertyRecord property) {
  return property.isActive ? property.status.label : 'Inactive';
}

UiTone _propertyDisplayStatusTone(PropertyRecord property) {
  return property.isActive ? property.status.tone : UiTone.danger;
}

class _SubscriptionTimingInfo {
  const _SubscriptionTimingInfo({
    required this.isExpired,
    required this.isExpiringSoon,
    this.daysRemaining,
  });

  final bool isExpired;
  final bool isExpiringSoon;
  final int? daysRemaining;
}

_SubscriptionTimingInfo _subscriptionTiming(
  String? expiryDate, {
  bool apiExpired = false,
}) {
  final DateTime? parsed = DateTime.tryParse(expiryDate ?? '');
  if (parsed == null) {
    return _SubscriptionTimingInfo(
      isExpired: apiExpired,
      isExpiringSoon: false,
    );
  }

  final DateTime today = DateTime.now();
  final DateTime startOfToday = DateTime(today.year, today.month, today.day);
  final DateTime localExpiry = parsed.toLocal();
  final DateTime expiryDay = DateTime(
    localExpiry.year,
    localExpiry.month,
    localExpiry.day,
  );

  final int daysRemaining = expiryDay.difference(startOfToday).inDays;
  final bool isExpired = apiExpired || daysRemaining < 0;

  return _SubscriptionTimingInfo(
    isExpired: isExpired,
    isExpiringSoon: !isExpired && daysRemaining <= 2,
    daysRemaining: isExpired ? null : daysRemaining,
  );
}

class _PropertyDetailsPage extends StatefulWidget {
  const _PropertyDetailsPage({
    required this.propertyId,
    required this.onManagePlan,
  });

  final String propertyId;
  final Future<void> Function(String propertyId, {_SubscriptionPlanMode? mode})
  onManagePlan;

  @override
  State<_PropertyDetailsPage> createState() => _PropertyDetailsPageState();
}

class _PropertyDetailsPageState extends State<_PropertyDetailsPage> {
  final PageController _galleryController = PageController();

  bool _isLoading = true;
  String? _errorMessage;
  PropertyData? _property;
  int _activeImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadProperty();
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  Future<void> _loadProperty() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final PropertyData? property = await PropertyService.fetchPropertyInfo(
        widget.propertyId,
      );
      if (!mounted) {
        return;
      }
      if (property == null) {
        setState(() {
          _errorMessage = 'Unable to load property details.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _property = property;
        _activeImageIndex = 0;
        _isLoading = false;
      });
      if (_galleryController.hasClients) {
        _galleryController.jumpToPage(0);
      }
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

  Future<void> _managePlan(_SubscriptionPlanMode mode) async {
    await widget.onManagePlan(widget.propertyId, mode: mode);
    if (!mounted) {
      return;
    }
    await _loadProperty();
  }

  Future<void> _openGoogleMaps() async {
    final PropertyData? property = _property;
    if (property == null ||
        property.latitude == null ||
        property.longitude == null ||
        (property.latitude == 0 && property.longitude == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Property coordinates are unavailable.')),
      );
      return;
    }

    final Uri uri = Uri.parse(
      'https://www.google.com/maps?q=${property.latitude},${property.longitude}',
    );
    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open Google Maps.')),
      );
    }
  }

  void _goToImage(int index) {
    _galleryController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  List<MapEntry<String, String>> _nearbyFacilities(PropertyData property) {
    return <MapEntry<String, String>>[
      if (_hasText(property.metroOrBusStation))
        MapEntry('Metro / Bus', property.metroOrBusStation!.trim()),
      if (_hasText(property.hospital))
        MapEntry('Hospital', property.hospital!.trim()),
      if (_hasText(property.schoolOrCollege))
        MapEntry('School / College', property.schoolOrCollege!.trim()),
      if (_hasText(property.shoppingMall))
        MapEntry('Shopping Mall', property.shoppingMall!.trim()),
      if (_hasText(property.restaurant))
        MapEntry('Restaurant', property.restaurant!.trim()),
      if (_hasText(property.atmOrBank))
        MapEntry('ATM / Bank', property.atmOrBank!.trim()),
    ];
  }

  String? _facingLabel(PropertyData property) {
    if (_hasText(property.facing)) {
      return property.facing!.trim();
    }
    if (property.facingDirectionType != null) {
      return _facingDirectionLabels[property.facingDirectionType];
    }
    return null;
  }

  Widget _buildGallery(PropertyData property) {
    final List<String> images = property.images ?? <String>[];

    if (images.isEmpty) {
      return Container(
        height: 260,
        color: AppTheme.surfaceMuted,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.image_not_supported_outlined,
              size: 40,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 8),
            Text(
              'No property images uploaded',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: <Widget>[
        SizedBox(
          height: 280,
          child: Stack(
            children: <Widget>[
              PageView.builder(
                controller: _galleryController,
                itemCount: images.length,
                onPageChanged: (int value) {
                  setState(() => _activeImageIndex = value);
                },
                itemBuilder: (BuildContext context, int index) {
                  return Image.network(
                    images[index],
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) {
                          return Container(
                            color: AppTheme.surfaceMuted,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: AppTheme.textMuted,
                              size: 36,
                            ),
                          );
                        },
                  );
                },
              ),
              Positioned(
                top: 16,
                right: 16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      '${_activeImageIndex + 1}/${images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              if (images.length > 1)
                Positioned(
                  left: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _GalleryArrowButton(
                      icon: Icons.chevron_left_rounded,
                      onPressed: () {
                        final int target =
                            (_activeImageIndex - 1 + images.length) %
                            images.length;
                        _goToImage(target);
                      },
                    ),
                  ),
                ),
              if (images.length > 1)
                Positioned(
                  right: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _GalleryArrowButton(
                      icon: Icons.chevron_right_rounded,
                      onPressed: () {
                        final int target =
                            (_activeImageIndex + 1) % images.length;
                        _goToImage(target);
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (images.length > 1)
          SizedBox(
            height: 92,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              scrollDirection: Axis.horizontal,
              itemBuilder: (BuildContext context, int index) {
                final bool isActive = index == _activeImageIndex;
                return GestureDetector(
                  onTap: () => _goToImage(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 84,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      border: Border.all(
                        color: isActive
                            ? AppTheme.primary
                            : AppTheme.borderStrong,
                        width: isActive ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusSmall - 1,
                      ),
                      child: Image.network(
                        images[index],
                        fit: BoxFit.cover,
                        errorBuilder:
                            (
                              BuildContext context,
                              Object error,
                              StackTrace? stackTrace,
                            ) {
                              return Container(
                                color: AppTheme.surfaceMuted,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: AppTheme.textMuted,
                                ),
                              );
                            },
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemCount: images.length,
            ),
          ),
      ],
    );
  }

  Widget _buildHeaderCard(PropertyData property) {
    final _SubscriptionTimingInfo timing = _subscriptionTiming(
      property.currentSubscriptionExpiryDate,
      apiExpired: property.subscriptionExpired == true,
    );

    return CustomCard(
      padding: CustomCardPadding.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _PropertyImageStrip(property: property),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  property.displayTitle?.trim().isNotEmpty == true
                      ? property.displayTitle!
                      : property.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ToneBadge(
                label: property.isActive
                    ? _propertyStatusLabelFromCode(property.propertyStatus)
                    : 'Inactive',
                tone: property.isActive
                    ? _propertyStatusToneFromCode(property.propertyStatus)
                    : UiTone.danger,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ToneBadge(
                label: _propertyTypeLabels[property.propertyType] ?? 'Property',
                tone: UiTone.brand,
              ),
              ToneBadge(
                label:
                    _propertySubTypeLabels[property.propertyType]?[property
                        .subType] ??
                    'Subtype',
                tone: UiTone.neutral,
              ),
              if (property.category != null)
                ToneBadge(
                  label: _categoryTypeLabels[property.category] ?? 'Category',
                  tone: UiTone.success,
                ),
              if (property.isSubscribed)
                ToneBadge(
                  label: timing.isExpired
                      ? 'Subscription Expired'
                      : timing.isExpiringSoon
                      ? 'Renew Soon'
                      : (property.currentSubscriptionTitle?.isNotEmpty == true
                            ? property.currentSubscriptionTitle!
                            : 'Subscribed'),
                  tone: timing.isExpired
                      ? UiTone.danger
                      : timing.isExpiringSoon
                      ? UiTone.warning
                      : UiTone.success,
                ),
              if (property.whetherVerifiedPlus == true)
                const ToneBadge(label: 'Verified+', tone: UiTone.warning),
              if (property.totalLeads != null ||
                  property.totalUnseenLeads != null)
                ToneBadge(
                  label:
                      'Open enquiries ${_openEnquiryCount(totalLeads: property.totalLeads, totalUnseenLeads: property.totalUnseenLeads)}',
                  tone: UiTone.neutral,
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _formatPropertyCurrency(property.rent, suffix: ' / month'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Security deposit: ${_formatPropertyCurrency(property.deposit)}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
          if ((property.maintenance ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Maintenance: ${_formatPropertyCurrency(property.maintenance)}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
              ),
            ),
          if (_hasText(property.availableFrom))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Available from: ${_formatPropertyDate(property.availableFrom)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionSpacing() => const SizedBox(height: 12);

  @override
  Widget build(BuildContext context) {
    final PropertyData? property = _property;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Details'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.border),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : property == null
          ? ListView(
              padding: AppTheme.pagePadding,
              children: <Widget>[
                _PropertyErrorCard(
                  message: _errorMessage ?? 'Unable to load property.',
                  onRetry: () {
                    _loadProperty();
                  },
                ),
              ],
            )
          : RefreshIndicator(
              onRefresh: _loadProperty,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: <Widget>[
                  _buildGallery(property),
                  Padding(
                    padding: AppTheme.pagePadding.copyWith(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _buildHeaderCard(property),
                        if (_hasText(property.description)) ...<Widget>[
                          _buildSectionSpacing(),
                          _PropertyDetailSectionCard(
                            title: 'Description',
                            icon: Icons.notes_rounded,
                            tone: UiTone.neutral,
                            child: Text(
                              property.description.trim(),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.textSecondary,
                                    height: 1.5,
                                  ),
                            ),
                          ),
                        ],
                        _buildSectionSpacing(),
                        _PropertyDetailSectionCard(
                          title: 'Overview',
                          icon: Icons.home_work_outlined,
                          tone: UiTone.brand,
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: <Widget>[
                              _DetailFactTile(
                                label: 'Rent',
                                value: _formatPropertyCurrency(
                                  property.rent,
                                  suffix: ' / month',
                                ),
                                tone: UiTone.brand,
                              ),
                              _DetailFactTile(
                                label: 'Deposit',
                                value: _formatPropertyCurrency(
                                  property.deposit,
                                ),
                                tone: UiTone.brand,
                              ),
                              if ((property.maintenance ?? 0) > 0)
                                _DetailFactTile(
                                  label: 'Maintenance',
                                  value: _formatPropertyCurrency(
                                    property.maintenance,
                                  ),
                                  tone: UiTone.brand,
                                ),
                              if ((property.brokerage ?? 0) > 0)
                                _DetailFactTile(
                                  label: 'Brokerage',
                                  value:
                                      '${property.brokerage!.toStringAsFixed(1)}%',
                                  tone: UiTone.brand,
                                ),
                              _DetailFactTile(
                                label: 'Furnishing',
                                value:
                                    _furnishedTypeLabels[property
                                        .furnishedType] ??
                                    'Not specified',
                                tone: UiTone.brand,
                              ),
                              if (property.category != null)
                                _DetailFactTile(
                                  label: 'Category',
                                  value:
                                      _categoryTypeLabels[property.category] ??
                                      'Category',
                                  tone: UiTone.brand,
                                ),
                              if (property.propertyType == 3)
                                _DetailFactTile(
                                  label: 'PG Sharing',
                                  value:
                                      _pgSharingLabels[property
                                          .pgSharingType] ??
                                      'N/A',
                                  tone: UiTone.brand,
                                ),
                              if (property.propertyType == 3 &&
                                  property.gender != null)
                                _DetailFactTile(
                                  label: 'Gender',
                                  value:
                                      _genderLabels[property.gender] ?? 'Any',
                                  tone: UiTone.brand,
                                ),
                            ],
                          ),
                        ),
                        _buildSectionSpacing(),
                        _PropertyDetailSectionCard(
                          title: 'Location',
                          icon: Icons.location_on_outlined,
                          tone: UiTone.success,
                          child: Column(
                            children: <Widget>[
                              _PropertyInfoRow(
                                label: 'Address',
                                value:
                                    property.locationAddress ??
                                    property.address ??
                                    'N/A',
                              ),
                              if (_hasText(property.locality))
                                _PropertyInfoRow(
                                  label: 'Locality',
                                  value: property.locality!.trim(),
                                ),
                              if (_hasText(property.pincode))
                                _PropertyInfoRow(
                                  label: 'Pincode',
                                  value: property.pincode!.trim(),
                                ),
                              if (_hasText(property.state) ||
                                  _hasText(property.city))
                                _PropertyInfoRow(
                                  label: 'State / City',
                                  value: <String>[
                                    property.city ?? '',
                                    property.state ?? '',
                                  ].where(_hasText).join(', '),
                                ),
                              if (property.latitude != null &&
                                  property.longitude != null &&
                                  (property.latitude != 0 ||
                                      property.longitude != 0))
                                _PropertyInfoRow(
                                  label: 'Coordinates',
                                  value:
                                      '${property.latitude!.toStringAsFixed(6)}, ${property.longitude!.toStringAsFixed(6)}',
                                ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: CustomButton(
                                  label: 'View on Google Maps',
                                  icon: const Icon(Icons.map_outlined),
                                  variant: CustomButtonVariant.outline,
                                  onPressed: _openGoogleMaps,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildSectionSpacing(),
                        _PropertyDetailSectionCard(
                          title: 'Property Details',
                          icon: Icons.apartment_outlined,
                          tone: UiTone.warning,
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: <Widget>[
                              if (_hasText(property.flatUnitNo))
                                _DetailFactTile(
                                  label: 'Flat / Unit',
                                  value: property.flatUnitNo!.trim(),
                                  tone: UiTone.warning,
                                ),
                              if ((property.area ?? 0) > 0)
                                _DetailFactTile(
                                  label: 'Total Area',
                                  value:
                                      '${property.area!.toStringAsFixed(0)} sq ft',
                                  tone: UiTone.warning,
                                ),
                              if ((property.carpetArea ?? 0) > 0)
                                _DetailFactTile(
                                  label: 'Carpet Area',
                                  value:
                                      '${property.carpetArea!.toStringAsFixed(0)} sq ft',
                                  tone: UiTone.warning,
                                ),
                              if (property.bedrooms != null)
                                _DetailFactTile(
                                  label: 'Bedrooms',
                                  value: '${property.bedrooms}',
                                  tone: UiTone.warning,
                                ),
                              if (property.bathrooms != null)
                                _DetailFactTile(
                                  label: 'Bathrooms',
                                  value: '${property.bathrooms}',
                                  tone: UiTone.warning,
                                ),
                              if (property.balconies != null)
                                _DetailFactTile(
                                  label: 'Balconies',
                                  value: '${property.balconies}',
                                  tone: UiTone.warning,
                                ),
                              if (property.floor != null)
                                _DetailFactTile(
                                  label: 'Floor',
                                  value: property.noOfFloors != null
                                      ? '${property.floor} of ${property.noOfFloors}'
                                      : '${property.floor}',
                                  tone: UiTone.warning,
                                ),
                              if ((property.noOfVacancy ?? 0) > 0)
                                _DetailFactTile(
                                  label: 'Vacancies',
                                  value: '${property.noOfVacancy}',
                                  tone: UiTone.warning,
                                ),
                              if (_facingLabel(property) != null)
                                _DetailFactTile(
                                  label: 'Facing',
                                  value: _facingLabel(property)!,
                                  tone: UiTone.warning,
                                ),
                              _DetailFactTile(
                                label: 'Uploads',
                                value:
                                    '${property.images?.length ?? 0} images${property.floorPlanDocumentId?.isNotEmpty == true ? ' + floor plan' : ''}',
                                tone: UiTone.warning,
                              ),
                            ],
                          ),
                        ),
                        if (property.amenityIds?.isNotEmpty ==
                            true) ...<Widget>[
                          _buildSectionSpacing(),
                          _PropertyDetailSectionCard(
                            title: 'Amenities',
                            icon: Icons.star_outline_rounded,
                            tone: UiTone.neutral,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: property.amenityIds!
                                  .map(
                                    (int amenityId) => ToneBadge(
                                      label:
                                          _propertyAmenityLabels[amenityId] ??
                                          'Amenity $amenityId',
                                      tone: UiTone.neutral,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                        if (_nearbyFacilities(property).isNotEmpty) ...<Widget>[
                          _buildSectionSpacing(),
                          _PropertyDetailSectionCard(
                            title: 'Nearby Facilities',
                            icon: Icons.near_me_outlined,
                            tone: UiTone.success,
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _nearbyFacilities(property)
                                  .map(
                                    (MapEntry<String, String> item) =>
                                        _DetailFactTile(
                                          label: item.key,
                                          value: item.value,
                                          tone: UiTone.success,
                                        ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                        _buildSectionSpacing(),
                        _PropertyDetailSectionCard(
                          title: 'Owner Information',
                          icon: Icons.person_outline_rounded,
                          tone: UiTone.brand,
                          child: Column(
                            children: <Widget>[
                              _PropertyInfoRow(
                                label: 'Name',
                                value: _hasText(property.ownerName)
                                    ? property.ownerName!.trim()
                                    : 'N/A',
                              ),
                              if (_hasText(property.ownerPhone))
                                _PropertyInfoRow(
                                  label: 'Phone',
                                  value: property.ownerPhone!.trim(),
                                ),
                              if (_hasText(property.ownerEmail))
                                _PropertyInfoRow(
                                  label: 'Email',
                                  value: property.ownerEmail!.trim(),
                                ),
                              if (_hasText(property.ownerAddress))
                                _PropertyInfoRow(
                                  label: 'Address',
                                  value: property.ownerAddress!.trim(),
                                ),
                            ],
                          ),
                        ),
                        if (property.electricityBillType != null ||
                            property.waterBillType != null ||
                            property.gasBillType != null ||
                            property.internetBillType != null) ...<Widget>[
                          _buildSectionSpacing(),
                          _PropertyDetailSectionCard(
                            title: 'Bill Types',
                            icon: Icons.receipt_long_outlined,
                            tone: UiTone.warning,
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: <Widget>[
                                if (property.electricityBillType != null)
                                  _DetailFactTile(
                                    label: 'Electricity',
                                    value:
                                        _billTypeLabels[property
                                            .electricityBillType] ??
                                        'N/A',
                                    tone: UiTone.warning,
                                  ),
                                if (property.waterBillType != null)
                                  _DetailFactTile(
                                    label: 'Water',
                                    value:
                                        _billTypeLabels[property
                                            .waterBillType] ??
                                        'N/A',
                                    tone: UiTone.warning,
                                  ),
                                if (property.gasBillType != null)
                                  _DetailFactTile(
                                    label: 'Gas',
                                    value:
                                        _billTypeLabels[property.gasBillType] ??
                                        'N/A',
                                    tone: UiTone.warning,
                                  ),
                                if (property.internetBillType != null)
                                  _DetailFactTile(
                                    label: 'Internet',
                                    value:
                                        _billTypeLabels[property
                                            .internetBillType] ??
                                        'N/A',
                                    tone: UiTone.warning,
                                  ),
                              ],
                            ),
                          ),
                        ],
                        _buildSectionSpacing(),
                        _PropertyDetailSectionCard(
                          title: 'Parking',
                          icon: Icons.local_parking_outlined,
                          tone: UiTone.success,
                          child: property.whetherParkingAvailable == true
                              ? Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: <Widget>[
                                    if (property.parkingType != null)
                                      _DetailFactTile(
                                        label: 'Type',
                                        value:
                                            _parkingTypeLabels[property
                                                .parkingType] ??
                                            'N/A',
                                        tone: UiTone.success,
                                      ),
                                    if ((property.parkingSlots ?? 0) > 0)
                                      _DetailFactTile(
                                        label: 'Slots',
                                        value: '${property.parkingSlots}',
                                        tone: UiTone.success,
                                      ),
                                    if ((property.parkingCharges ?? 0) > 0)
                                      _DetailFactTile(
                                        label: 'Charges',
                                        value: _formatPropertyCurrency(
                                          property.parkingCharges,
                                        ),
                                        tone: UiTone.success,
                                      ),
                                  ],
                                )
                              : Text(
                                  'Parking not available',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: AppTheme.textSecondary),
                                ),
                        ),
                        if (property.propertyType != 3 &&
                            (property.preferredTenantType != null ||
                                property.petPolicy != null ||
                                property.smokingPolicy != null ||
                                property.visitorsPolicy != null ||
                                _hasText(
                                  property.propertyRulesDescription,
                                ))) ...<Widget>[
                          _buildSectionSpacing(),
                          _PropertyDetailSectionCard(
                            title: 'Rules & Preferences',
                            icon: Icons.rule_folder_outlined,
                            tone: UiTone.neutral,
                            child: Column(
                              children: <Widget>[
                                if (property.preferredTenantType != null)
                                  _PropertyInfoRow(
                                    label: 'Tenant type',
                                    value:
                                        _tenantTypeLabels[property
                                            .preferredTenantType] ??
                                        'N/A',
                                  ),
                                if (property.petPolicy != null)
                                  _PropertyInfoRow(
                                    label: 'Pet policy',
                                    value:
                                        _petPolicyLabels[property.petPolicy] ??
                                        'N/A',
                                  ),
                                if (property.smokingPolicy != null)
                                  _PropertyInfoRow(
                                    label: 'Smoking',
                                    value:
                                        _smokingPolicyLabels[property
                                            .smokingPolicy] ??
                                        'N/A',
                                  ),
                                if (property.visitorsPolicy != null)
                                  _PropertyInfoRow(
                                    label: 'Visitors',
                                    value:
                                        _visitorsPolicyLabels[property
                                            .visitorsPolicy] ??
                                        'N/A',
                                  ),
                                if (_hasText(property.propertyRulesDescription))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusSmall,
                                        ),
                                        border: Border.all(
                                          color: AppTheme.borderSoft,
                                        ),
                                      ),
                                      child: Text(
                                        property.propertyRulesDescription!
                                            .trim(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: AppTheme.textSecondary,
                                              height: 1.45,
                                            ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (property.totalResidentContractsCount !=
                            null) ...<Widget>[
                          _buildSectionSpacing(),
                          _PropertyDetailSectionCard(
                            title: 'Resident Contracts',
                            icon: Icons.groups_2_outlined,
                            tone: UiTone.brand,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: <Widget>[
                                  _DetailMetricCard(
                                    label: 'Free',
                                    value:
                                        '${property.freeResidentContractsCount ?? 0}',
                                    tone: UiTone.brand,
                                  ),
                                  const SizedBox(width: 10),
                                  _DetailMetricCard(
                                    label: 'Purchased',
                                    value:
                                        '${property.totalPurchasedResidentContractsCreationCount ?? 0}',
                                    tone: UiTone.success,
                                  ),
                                  const SizedBox(width: 10),
                                  _DetailMetricCard(
                                    label: 'Total',
                                    value:
                                        '${property.totalResidentContractsCount ?? 0}',
                                    tone: UiTone.neutral,
                                  ),
                                  const SizedBox(width: 10),
                                  _DetailMetricCard(
                                    label: 'Available',
                                    value:
                                        '${property.availableResidentContractsCreationCount ?? 0}',
                                    tone: UiTone.warning,
                                  ),
                                  const SizedBox(width: 10),
                                  _DetailMetricCard(
                                    label: 'Used',
                                    value:
                                        '${property.usedResidentContractsCount ?? 0}',
                                    tone: UiTone.danger,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        _buildSectionSpacing(),
                        _PropertySubscriptionCard(
                          property: property,
                          onManagePlan: _managePlan,
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

class _GalleryArrowButton extends StatelessWidget {
  const _GalleryArrowButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _PropertyDetailSectionCard extends StatelessWidget {
  const _PropertyDetailSectionCard({
    required this.title,
    required this.icon,
    required this.tone,
    required this.child,
  });

  final String title;
  final IconData icon;
  final UiTone tone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: CustomCardPadding.sm,
      color: AppTheme.toneSoft(tone),
      borderColor: AppTheme.toneContainer(tone),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(icon, color: AppTheme.toneColor(tone)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DetailFactTile extends StatelessWidget {
  const _DetailFactTile({
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
      width: 152,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(color: AppTheme.toneContainer(tone)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PropertyInfoRow extends StatelessWidget {
  const _PropertyInfoRow({required this.label, required this.value});

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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailMetricCard extends StatelessWidget {
  const _DetailMetricCard({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final UiTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppTheme.toneContainer(tone)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.toneColor(tone),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertySubscriptionCard extends StatelessWidget {
  const _PropertySubscriptionCard({
    required this.property,
    required this.onManagePlan,
  });

  final PropertyData property;
  final Future<void> Function(_SubscriptionPlanMode mode) onManagePlan;

  @override
  Widget build(BuildContext context) {
    final _SubscriptionTimingInfo timing = _subscriptionTiming(
      property.currentSubscriptionExpiryDate,
      apiExpired: property.subscriptionExpired == true,
    );
    final bool attentionState = timing.isExpired || timing.isExpiringSoon;
    final List<Color> headerColors = attentionState
        ? <Color>[const Color(0xFFEA580C), const Color(0xFFF97316)]
        : <Color>[const Color(0xFF2563EB), const Color(0xFF1D4ED8)];
    final SubscriptionCalculationData? calculation =
        property.currentSubscriptionCalculation;

    return CustomCard(
      padding: CustomCardPadding.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: headerColors),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusMedium),
              ),
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
                            property.currentSubscriptionTitle?.isNotEmpty ==
                                    true
                                ? property.currentSubscriptionTitle!
                                : 'Subscription Plan',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            property.currentSubscriptionPrice != null &&
                                    property.currentSubscriptionDuration != null
                                ? '${_formatPropertyCurrency(property.currentSubscriptionPrice)} / ${property.currentSubscriptionDuration} days'
                                : 'Plan details will appear here after subscription.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.92),
                                ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.workspace_premium_outlined,
                      color: Colors.white,
                      size: 30,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: timing.isExpired
                        ? const Color(0xFFDC2626)
                        : timing.isExpiringSoon
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Text(
                    !property.isSubscribed
                        ? 'No active subscription'
                        : timing.isExpired
                        ? 'Expired'
                        : timing.isExpiringSoon
                        ? 'Renew Soon'
                        : 'Active',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: property.isSubscribed
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (_hasText(property.currentSubscriptionDescription))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            property.currentSubscriptionDescription!.trim(),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppTheme.textSecondary,
                                  height: 1.45,
                                ),
                          ),
                        ),
                      _PropertyInfoRow(
                        label: 'Expiry',
                        value: _formatPropertyDate(
                          property.currentSubscriptionExpiryDate,
                        ),
                      ),
                      if (timing.isExpiringSoon && timing.daysRemaining != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '${timing.daysRemaining} day(s) remaining',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: const Color(0xFFB45309),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      _PropertyInfoRow(
                        label: 'Payment Status',
                        value: property.currentSubscriptionPaymentStatus == 2
                            ? 'Paid'
                            : 'Pending',
                      ),
                      if (_hasText(property.currentSubscriptionPaymentDate))
                        _PropertyInfoRow(
                          label: 'Payment Date',
                          value: _formatPropertyDate(
                            property.currentSubscriptionPaymentDate,
                          ),
                        ),
                      if (_hasText(property.currentSubscriptionPaymentMethod))
                        _PropertyInfoRow(
                          label: 'Payment Method',
                          value: property.currentSubscriptionPaymentMethod!
                              .toUpperCase(),
                        ),
                      if (calculation != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          'Payment Breakdown',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        _PropertyInfoRow(
                          label: 'Subscription',
                          value: _formatPropertyCurrency(
                            calculation.subscriptionPrice,
                          ),
                        ),
                        _PropertyInfoRow(
                          label: 'Free Contracts',
                          value: '${calculation.freeContractsCount}',
                        ),
                        _PropertyInfoRow(
                          label: 'Extra Contracts',
                          value:
                              '${calculation.extraContractsCount} x ${_formatPropertyCurrency(calculation.amountPerContract)}',
                        ),
                        _PropertyInfoRow(
                          label: 'Extra Amount',
                          value: _formatPropertyCurrency(
                            calculation.extraContractsAmount,
                          ),
                        ),
                        _PropertyInfoRow(
                          label: 'Subtotal',
                          value: _formatPropertyCurrency(calculation.subtotal),
                        ),
                        _PropertyInfoRow(
                          label:
                              'GST (${calculation.gstPercentage.toStringAsFixed(0)}%)',
                          value: _formatPropertyCurrency(calculation.gstAmount),
                        ),
                        _PropertyInfoRow(
                          label: 'Total Amount',
                          value: _formatPropertyCurrency(
                            calculation.totalAmount,
                          ),
                        ),
                      ],
                    ],
                  )
                : Text(
                    'No active subscription is attached to this property yet. Subscribe to list it with a plan and manage resident contract capacity.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.45,
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: !property.isSubscribed
                ? SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      label: 'Subscribe Now',
                      icon: const Icon(Icons.workspace_premium_outlined),
                      onPressed: () {
                        onManagePlan(_SubscriptionPlanMode.subscribe);
                      },
                    ),
                  )
                : (timing.isExpired || timing.isExpiringSoon)
                ? Column(
                    children: <Widget>[
                      SizedBox(
                        width: double.infinity,
                        child: CustomButton(
                          label: timing.isExpired
                              ? 'Renew Plan Now'
                              : ((timing.daysRemaining ?? 0) == 0
                                    ? 'Renew Today'
                                    : 'Renew Soon - ${timing.daysRemaining}d'),
                          icon: const Icon(Icons.workspace_premium_outlined),
                          onPressed: () {
                            onManagePlan(_SubscriptionPlanMode.renew);
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: CustomButton(
                          label: 'Change Plan',
                          variant: CustomButtonVariant.outline,
                          icon: const Icon(Icons.swap_horiz_rounded),
                          onPressed: () {
                            onManagePlan(_SubscriptionPlanMode.change);
                          },
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      label: 'Change Plan',
                      icon: const Icon(Icons.swap_horiz_rounded),
                      onPressed: () {
                        onManagePlan(_SubscriptionPlanMode.change);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PropertySummaryHero extends StatelessWidget {
  const _PropertySummaryHero({
    required this.liveCount,
    required this.totalCount,
    required this.approvedCount,
    required this.pendingCount,
    required this.onAddProperty,
  });

  final int liveCount;
  final int totalCount;
  final int approvedCount;
  final int pendingCount;
  final VoidCallback onAddProperty;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Widget> stats = <Widget>[
      Expanded(
        child: _PropertyOverviewStat(
          label: 'Inventory',
          value: '$totalCount',
          icon: Icons.apartment_outlined,
          color: AppTheme.primary,
        ),
      ),
      const _PropertyOverviewDivider(),
      Expanded(
        child: _PropertyOverviewStat(
          label: 'Approved',
          value: '$approvedCount',
          icon: Icons.check_circle_outline_rounded,
          color: const Color(0xFF10B981),
        ),
      ),
      const _PropertyOverviewDivider(),
      Expanded(
        child: _PropertyOverviewStat(
          label: 'Pending',
          value: '$pendingCount',
          icon: Icons.schedule_outlined,
          color: const Color(0xFFF59E0B),
        ),
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x08111827),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
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
                      'Inventory control',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Track approvals, subscriptions, activation status, and inventory health from one clear workspace.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$liveCount live',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(children: stats),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              label: 'Add Property',
              icon: const Icon(Icons.add_home_work_outlined),
              onPressed: onAddProperty,
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyOverviewStat extends StatelessWidget {
  const _PropertyOverviewStat({
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyOverviewDivider extends StatelessWidget {
  const _PropertyOverviewDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 72, color: const Color(0xFFE5E7EB));
  }
}

class _PropertyFilterPanel extends StatelessWidget {
  const _PropertyFilterPanel({
    required this.searchController,
    required this.typeFilter,
    required this.subTypeFilter,
    required this.categoryTypeFilter,
    required this.propertyTypeLabels,
    required this.stateId,
    required this.states,
    required this.cityId,
    required this.cities,
    required this.onApply,
    required this.onBack,
    required this.onClear,
    required this.onTypeChanged,
    required this.onSubTypeChanged,
    required this.onCategoryTypeChanged,
    required this.onStateChanged,
    required this.onCityChanged,
  });

  final TextEditingController searchController;
  final int? typeFilter;
  final int? subTypeFilter;
  final int? categoryTypeFilter;
  final Map<int, String> propertyTypeLabels;
  final String? stateId;
  final List<PropertyStateData> states;
  final String? cityId;
  final List<PropertyCityData> cities;
  final VoidCallback onApply;
  final VoidCallback onBack;
  final VoidCallback onClear;
  final ValueChanged<int?> onTypeChanged;
  final ValueChanged<int?> onSubTypeChanged;
  final ValueChanged<int?> onCategoryTypeChanged;
  final ValueChanged<String?> onStateChanged;
  final ValueChanged<String?> onCityChanged;

  InputDecoration _searchDecoration({required VoidCallback onApply}) {
    OutlineInputBorder border(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      hintText: 'Search by property name or location',
      prefixIcon: IconButton(
        tooltip: 'Back',
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      suffixIcon: IconButton(
        tooltip: 'Apply search',
        onPressed: onApply,
        icon: const Icon(Icons.arrow_forward_rounded),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border(const Color(0xFFE5E7EB)),
      enabledBorder: border(const Color(0xFFE5E7EB)),
      focusedBorder: border(AppTheme.primary, width: 1.4),
    );
  }

  String? _selectedStateName() {
    if (stateId == null) {
      return null;
    }
    for (final PropertyStateData state in states) {
      if (state.stateId == stateId) {
        return state.stateName;
      }
    }
    return null;
  }

  String? _selectedCityName() {
    if (cityId == null) {
      return null;
    }
    for (final PropertyCityData city in cities) {
      if (city.cityId == cityId) {
        return city.cityName;
      }
    }
    return null;
  }

  int _activeCriteriaCount() {
    int count = 0;
    if (searchController.text.trim().isNotEmpty) count++;
    if (typeFilter != null) count++;
    if (subTypeFilter != null) count++;
    if (categoryTypeFilter != null) count++;
    if ((stateId ?? '').isNotEmpty) count++;
    if ((cityId ?? '').isNotEmpty) count++;
    return count;
  }

  Future<void> _selectMappedFilter({
    required BuildContext context,
    required String title,
    required Map<int, String> items,
    required int? currentValue,
    required String allLabel,
    required ValueChanged<int?> onChanged,
  }) async {
    final String? selected = await _showSearchableDropdown(
      context: context,
      title: title,
      items: items.entries
          .map(
            (MapEntry<int, String> entry) =>
                (value: entry.key.toString(), label: entry.value),
          )
          .toList(),
      currentValue: currentValue?.toString(),
      allLabel: allLabel,
    );
    onChanged(selected == null ? null : int.tryParse(selected));
  }

  Future<void> _selectState(BuildContext context) async {
    final String? selected = await _showSearchableDropdown(
      context: context,
      title: 'Select State',
      items: states
          .map((PropertyStateData s) => (value: s.stateId, label: s.stateName))
          .toList(),
      currentValue: stateId,
      allLabel: 'All States',
    );
    onStateChanged(selected);
  }

  Future<void> _selectCity(BuildContext context) async {
    final String? selected = await _showSearchableDropdown(
      context: context,
      title: 'Select City',
      items: cities
          .map((PropertyCityData c) => (value: c.cityId, label: c.cityName))
          .toList(),
      currentValue: cityId,
      allLabel: 'All Cities',
    );
    onCityChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int activeCriteria = _activeCriteriaCount();
    final String typeLabel = propertyTypeLabels[typeFilter] ?? 'All types';
    final String subtypeLabel = typeFilter == null
        ? 'All subtypes'
        : _propertySubTypeLabels[typeFilter]?[subTypeFilter] ?? 'All subtypes';
    final String categoryLabel =
        _categoryTypeLabels[categoryTypeFilter] ?? 'All categories';
    final String stateLabel = _selectedStateName() ?? 'All states';
    final String cityLabel = _selectedCityName() ?? 'All cities';
    final bool cityEnabled =
        (stateId ?? '').isNotEmpty ||
        cities.isNotEmpty ||
        (cityId ?? '').isNotEmpty;
    final List<Widget> filterChips = <Widget>[
      _FilterControlChip(
        icon: Icons.apartment_outlined,
        label: 'Type: $typeLabel',
        active: typeFilter != null,
        onTap: () => _selectMappedFilter(
          context: context,
          title: 'Select Type',
          items: propertyTypeLabels,
          currentValue: typeFilter,
          allLabel: 'All Types',
          onChanged: onTypeChanged,
        ),
      ),
      if (typeFilter != null)
        _FilterControlChip(
          icon: Icons.grid_view_rounded,
          label: 'Subtype: $subtypeLabel',
          active: subTypeFilter != null,
          onTap: () => _selectMappedFilter(
            context: context,
            title: 'Select Subtype',
            items: _propertySubTypeLabels[typeFilter] ?? <int, String>{},
            currentValue: subTypeFilter,
            allLabel: 'All Subtypes',
            onChanged: onSubTypeChanged,
          ),
        ),
      _FilterControlChip(
        icon: Icons.sell_outlined,
        label: 'Category: $categoryLabel',
        active: categoryTypeFilter != null,
        onTap: () => _selectMappedFilter(
          context: context,
          title: 'Select Category',
          items: _categoryTypeLabels,
          currentValue: categoryTypeFilter,
          allLabel: 'All Categories',
          onChanged: onCategoryTypeChanged,
        ),
      ),
      _FilterControlChip(
        icon: Icons.map_outlined,
        label: 'State: $stateLabel',
        active: (stateId ?? '').isNotEmpty,
        onTap: () => _selectState(context),
      ),
      _FilterControlChip(
        icon: Icons.location_city_outlined,
        label: cityEnabled ? 'City: $cityLabel' : 'City: select state',
        active: (cityId ?? '').isNotEmpty,
        enabled: cityEnabled,
        onTap: cityEnabled ? () => _selectCity(context) : null,
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Search & filter',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (activeCriteria > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$activeCriteria active',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              TextButton(
                onPressed: activeCriteria > 0 ? onClear : null,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  foregroundColor: AppTheme.textSecondary,
                ),
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: searchController,
            decoration: _searchDecoration(onApply: onApply),
            onSubmitted: (_) => onApply(),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  filterChips
                      .expand<Widget>(
                        (Widget chip) => <Widget>[
                          chip,
                          const SizedBox(width: 8),
                        ],
                      )
                      .toList()
                    ..removeLast(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterControlChip extends StatelessWidget {
  const _FilterControlChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color backgroundColor = !enabled
        ? const Color(0xFFF8FAFC)
        : active
        ? AppTheme.primarySoft
        : Colors.white;
    final Color borderColor = active
        ? const Color(0xFFC7D2FE)
        : const Color(0xFFE5E7EB);
    final Color iconColor = !enabled
        ? AppTheme.textMuted
        : active
        ? AppTheme.primary
        : AppTheme.textSecondary;
    final Color textColor = !enabled
        ? AppTheme.textMuted
        : active
        ? AppTheme.primary
        : AppTheme.textPrimary;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44, maxWidth: 210),
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 17, color: iconColor),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 17,
                    color: iconColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PropertyListHeader extends StatelessWidget {
  const _PropertyListHeader({
    required this.page,
    required this.visibleCount,
    required this.totalCount,
  });

  final int page;
  final int visibleCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Showing $visibleCount properties',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Page $page of inventory results',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Text(
            'Total $totalCount',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _PropertyRecordCard extends StatelessWidget {
  const _PropertyRecordCard({
    required this.property,
    required this.onDetails,
    required this.onClone,
    required this.onManagePlan,
    required this.onEdit,
    required this.onToggle,
    required this.onEnquiries,
  });

  final PropertyRecord property;
  final VoidCallback onDetails;
  final VoidCallback onClone;
  final VoidCallback onManagePlan;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onEnquiries;

  static String _formatExpiryDate(String raw) {
    try {
      final DateTime dt = DateTime.parse(raw);
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
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String rentLabel = 'Rs ${property.rent.toStringAsFixed(0)}';
    final String depositLabel = 'Rs ${property.deposit.toStringAsFixed(0)}';

    return CustomCard(
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
                      property.displayTitle?.trim().isNotEmpty == true
                          ? property.displayTitle!
                          : property.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      property.address ?? property.type,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ToneBadge(
                label: _propertyDisplayStatusLabel(property),
                tone: _propertyDisplayStatusTone(property),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _PropertyStat(label: 'Rent', value: rentLabel),
                ),
                Expanded(
                  child: _PropertyStat(label: 'Deposit', value: depositLabel),
                ),
                Expanded(
                  child: _PropertyStat(
                    label: 'Available Contracts',
                    value:
                        '${property.availableResidentContractsCreationCount ?? property.noOfVacancy ?? 0}',
                  ),
                ),
              ],
            ),
          ),
          // --- Subscription Plan Info ---
          if (property.isSubscribed &&
              property.currentSubscriptionTitle != null) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: property.subscriptionExpired == true
                    ? const Color(0xFFFEF3C7)
                    : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: property.subscriptionExpired == true
                      ? const Color(0xFFFBBF24)
                      : const Color(0xFF86EFAC),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.workspace_premium_outlined,
                    size: 18,
                    color: property.subscriptionExpired == true
                        ? const Color(0xFFD97706)
                        : const Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          property.currentSubscriptionTitle!,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (property.currentSubscriptionPrice != null ||
                            property.currentSubscriptionDuration != null)
                          Text(
                            [
                              if (property.currentSubscriptionPrice != null)
                                'Rs ${property.currentSubscriptionPrice!.toStringAsFixed(0)}',
                              if (property.currentSubscriptionDuration != null)
                                '${property.currentSubscriptionDuration} days',
                            ].join(' / '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        if (property.currentSubscriptionExpiryDate != null &&
                            property.currentSubscriptionExpiryDate!.isNotEmpty)
                          Text(
                            'Expires: ${_formatExpiryDate(property.currentSubscriptionExpiryDate!)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: property.subscriptionExpired == true
                                  ? const Color(0xFFDC2626)
                                  : AppTheme.textSecondary,
                              fontWeight: property.subscriptionExpired == true
                                  ? FontWeight.w600
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ToneBadge(label: property.type, tone: UiTone.brand),
              if (property.isSubscribed)
                ToneBadge(
                  label: property.subscriptionExpired == true
                      ? 'Plan Expired'
                      : 'Subscribed',
                  tone: property.subscriptionExpired == true
                      ? UiTone.danger
                      : UiTone.success,
                ),
              if (!property.isSubscribed)
                const ToneBadge(label: 'Plan required', tone: UiTone.warning),
              if (property.whetherVerifiedPlus == true)
                const ToneBadge(label: 'Verified+', tone: UiTone.warning),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _ActionChipButton(
                label: 'Details',
                icon: Icons.visibility_outlined,
                onPressed: onDetails,
              ),
              _ActionChipButton(
                label:
                    'Enquiries - ${_openEnquiryCount(totalLeads: property.totalLeads, totalUnseenLeads: property.totalUnseenLeads)}',
                icon: Icons.people_outline,
                onPressed: onEnquiries,
                badgeCount: _openEnquiryCount(
                  totalLeads: property.totalLeads,
                  totalUnseenLeads: property.totalUnseenLeads,
                ),
              ),
              _ActionChipButton(
                label: 'Clone',
                icon: Icons.copy_outlined,
                onPressed: onClone,
              ),
              if (!property.isSubscribed)
                _ActionChipButton(
                  label: 'Subscribe',
                  icon: Icons.workspace_premium_outlined,
                  onPressed: onManagePlan,
                ),
              if (property.isSubscribed)
                Builder(
                  builder: (context) {
                    final timing = _subscriptionTiming(
                      property.currentSubscriptionExpiryDate,
                      apiExpired: property.subscriptionExpired == true,
                    );
                    return _ActionChipButton(
                      label: 'Renew Plan',
                      icon: Icons.workspace_premium_outlined,
                      onPressed: onManagePlan,
                      color: (timing.isExpired || timing.isExpiringSoon)
                          ? const Color(0xFFDC2626)
                          : const Color(0xFFD97706),
                    );
                  },
                ),
              if (property.isSubscribed)
                Builder(
                  builder: (context) {
                    final timing = _subscriptionTiming(
                      property.currentSubscriptionExpiryDate,
                      apiExpired: property.subscriptionExpired == true,
                    );
                    return _ActionChipButton(
                      label: 'Change Plan',
                      icon: Icons.workspace_premium_outlined,
                      onPressed: onManagePlan,
                      color: (timing.isExpired || timing.isExpiringSoon)
                          ? const Color(0xFFD97706)
                          : null,
                    );
                  },
                ),
              _ActionChipButton(
                label: 'Edit',
                icon: Icons.edit_outlined,
                onPressed: onEdit,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              label: property.isActive
                  ? 'Deactivate Property'
                  : 'Activate Property',
              variant: property.isActive
                  ? CustomButtonVariant.danger
                  : CustomButtonVariant.primary,
              onPressed: onToggle,
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyImageStrip extends StatelessWidget {
  const _PropertyImageStrip({required this.property});

  final Object property;

  String get _imageUrl {
    final Object item = property;
    if (item is PropertyRecord) {
      return (item.imageUrl ?? '').trim();
    }
    if (item is PropertyData) {
      return (item.imageUrl ?? '').trim();
    }
    return '';
  }

  String get _typeLabel {
    final Object item = property;
    if (item is PropertyRecord) {
      return item.type;
    }
    if (item is PropertyData) {
      return _propertyTypeLabels[item.propertyType] ?? 'Property';
    }
    return 'Property';
  }

  @override
  Widget build(BuildContext context) {
    final String imageUrl = _imageUrl;
    final String typeLabel = _typeLabel;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: AspectRatio(
        aspectRatio: 16 / 7,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _PropertyImageFallback(typeLabel: typeLabel),
              )
            else
              _PropertyImageFallback(typeLabel: typeLabel),
            Positioned(
              left: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(235),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  typeLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PropertyImageFallback extends StatelessWidget {
  const _PropertyImageFallback({required this.typeLabel});

  final String typeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primarySoft,
      child: Center(
        child: Icon(
          typeLabel.toLowerCase().contains('pg')
              ? Icons.bed_outlined
              : Icons.apartment_rounded,
          color: AppTheme.primary,
          size: 34,
        ),
      ),
    );
  }
}

class _PropertyStat extends StatelessWidget {
  const _PropertyStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.badgeCount = 0,
    this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final int badgeCount;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bool hasColor = color != null;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: hasColor ? color : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: hasColor ? color! : AppTheme.borderStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 16,
              color: hasColor ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: hasColor ? Colors.white : AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (badgeCount > 0) ...<Widget>[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$badgeCount',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PropertyErrorCard extends StatelessWidget {
  const _PropertyErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Unable to load properties',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
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

class _InlineStatusCard extends StatelessWidget {
  const _InlineStatusCard({
    required this.title,
    required this.message,
    required this.tone,
  });

  final String title;
  final String message;
  final UiTone tone;

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      color: AppTheme.toneSoft(tone),
      borderColor: AppTheme.toneColor(tone).withValues(alpha: 0.2),
      padding: CustomCardPadding.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ToneBadge(label: title, tone: tone),
          const SizedBox(height: 10),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Searchable dropdown helper — opens a bottom sheet with a search field and
/// scrollable list. Returns the selected value or `null` if dismissed.
Future<String?> _showSearchableDropdown({
  required BuildContext context,
  required String title,
  required List<({String value, String label})> items,
  String? currentValue,
  String? allLabel,
}) async {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext ctx) {
      return _SearchableDropdownSheet(
        title: title,
        items: items,
        currentValue: currentValue,
        allLabel: allLabel,
      );
    },
  );
}

class _SearchableDropdownSheet extends StatefulWidget {
  const _SearchableDropdownSheet({
    required this.title,
    required this.items,
    this.currentValue,
    this.allLabel,
  });

  final String title;
  final List<({String value, String label})> items;
  final String? currentValue;
  final String? allLabel;

  @override
  State<_SearchableDropdownSheet> createState() =>
      _SearchableDropdownSheetState();
}

class _SearchableDropdownSheetState extends State<_SearchableDropdownSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String normalizedQuery = _query.toLowerCase();
    final List<({String value, String label})> filtered =
        normalizedQuery.isEmpty
        ? widget.items
        : widget.items
              .where(
                (({String value, String label}) item) =>
                    item.label.toLowerCase().contains(normalizedQuery),
              )
              .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        widget.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                  onChanged: (String value) => setState(() => _query = value),
                ),
              ),
              if (widget.allLabel != null)
                ListTile(
                  title: Text(
                    widget.allLabel!,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: widget.currentValue == null
                          ? FontWeight.w700
                          : null,
                      color: widget.currentValue == null
                          ? AppTheme.primary
                          : null,
                    ),
                  ),
                  trailing: widget.currentValue == null
                      ? const Icon(Icons.check, color: AppTheme.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(null),
                ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: filtered.length,
                  itemBuilder: (BuildContext context, int index) {
                    final ({String value, String label}) item = filtered[index];
                    final bool isSelected = item.value == widget.currentValue;
                    return ListTile(
                      title: Text(
                        item.label,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: isSelected ? FontWeight.w700 : null,
                          color: isSelected ? AppTheme.primary : null,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: AppTheme.primary)
                          : null,
                      onTap: () => Navigator.of(context).pop(item.value),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
