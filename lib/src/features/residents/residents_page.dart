import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/block_building_service.dart';
import '../../core/api/razorpay_checkout_service.dart';
import '../../core/api/society_service.dart';
import '../../core/api/support_service.dart';
import '../../core/api/upload_service.dart';
import '../../core/api/vendor_service.dart';
import '../../core/models/api_models.dart';
import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_card.dart';
import '../../core/widgets/custom_tab_bar.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/tone_badge.dart';

class ResidentsPage extends StatefulWidget {
  const ResidentsPage({super.key, this.societyId = ''});

  final String societyId;

  @override
  State<ResidentsPage> createState() => _ResidentsPageState();
}

class _ResidentsPageState extends State<ResidentsPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  static const int _pageSize = 10;

  bool _isLoading = true;
  String? _errorMessage;
  String _societyId = '';
  bool? _statusFilter;
  int? _residentTypeFilter;
  String _blockFilter = '';
  String _buildingFilter = '';
  int _skip = 0;
  int _totalCount = 0;
  SocietyData? _societyInfo;
  List<BlockData> _blocks = <BlockData>[];
  List<BuildingData> _buildings = <BuildingData>[];
  List<ResidentRecord> _residents = <ResidentRecord>[];

  @override
  void initState() {
    super.initState();
    _societyId = widget.societyId;
    _loadAll();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String societyId = _societyId;
      if (societyId.isEmpty) {
        final SocietyData? society = await SocietyService.fetchSocietyInfo();
        societyId = society?.societyId ?? '';
      }
      if (societyId.isEmpty) {
        throw Exception('Society information is not available for this user.');
      }

      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        BlockBuildingService.filterBlocks(societyId),
        BlockBuildingService.filterBuildings(societyId),
        SocietyService.filterResidents(
          societyId: societyId,
          skip: _skip,
          limit: _pageSize,
          search: _searchController.text.trim().isEmpty
              ? null
              : _searchController.text.trim(),
          statusFilter: _statusFilter,
          blockId: _blockFilter.isEmpty ? null : _blockFilter,
          buildingId: _buildingFilter.isEmpty ? null : _buildingFilter,
          residentType: _residentTypeFilter,
        ),
        _loadResidentSupportTickets(societyId),
        SocietyService.fetchSocietyInfo(),
      ]);

      if (!mounted) {
        return;
      }

      final blocksResult = results[0] as ({List<BlockData> blocks, int count});
      final buildingsResult =
          results[1] as ({List<BuildingData> buildings, int count});
      final residentsResult =
          results[2] as ({List<ResidentRecord> residents, int count});
      final supportTickets = results[3] as List<TicketRecord>;
      final SocietyData? societyInfo = results[4] as SocietyData?;
      final List<ResidentRecord> residents = _mergeResidentImagesFromTickets(
        residentsResult.residents,
        supportTickets,
      );

      setState(() {
        _societyId = societyId;
        _societyInfo = societyInfo;
        _blocks = blocksResult.blocks
            .where((BlockData item) => item.status)
            .toList();
        _buildings = buildingsResult.buildings
            .where((BuildingData item) => item.status)
            .toList();
        _residents = residents;
        _totalCount = residentsResult.count;
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

  Future<List<TicketRecord>> _loadResidentSupportTickets(String societyId) async {
    try {
      final result = await SupportService.filterSocietyTickets(
        societyId: societyId,
        limit: 200,
      );
      return result.tickets;
    } catch (_) {
      return <TicketRecord>[];
    }
  }

  List<ResidentRecord> _mergeResidentImagesFromTickets(
    List<ResidentRecord> residents,
    List<TicketRecord> tickets,
  ) {
    if (residents.isEmpty || tickets.isEmpty) {
      return residents;
    }

    final Map<String, String> imageByKey = <String, String>{};
    for (final TicketRecord ticket in tickets) {
      final String imageUrl = ticket.residentImageUrl?.trim() ?? '';
      if (imageUrl.isEmpty) {
        continue;
      }

      for (final String key in <String>[
        _profilePhoneKey(ticket.residentPhone),
        _profileEmailKey(ticket.residentEmail),
        _profileFlatNameKey(ticket.flatNo, ticket.residentName),
      ]) {
        if (key.isNotEmpty) {
          imageByKey.putIfAbsent(key, () => imageUrl);
        }
      }
    }

    if (imageByKey.isEmpty) {
      return residents;
    }

    return residents.map((ResidentRecord resident) {
      if ((resident.imageUrl ?? '').trim().isNotEmpty) {
        return resident;
      }

      final String imageUrl =
          imageByKey[_profilePhoneKey(resident.phone)] ??
          imageByKey[_profileEmailKey(resident.email)] ??
          imageByKey[_profileFlatNameKey(resident.flatNo, resident.name)] ??
          '';

      if (imageUrl.isEmpty) {
        return resident;
      }
      return resident.copyWith(imageUrl: imageUrl);
    }).toList();
  }

  String _profilePhoneKey(String? value) {
    final String digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return '';
    }
    final String normalized = digits.length > 10
        ? digits.substring(digits.length - 10)
        : digits;
    return 'phone:$normalized';
  }

  String _profileEmailKey(String? value) {
    final String email = (value ?? '').trim().toLowerCase();
    return email.isEmpty ? '' : 'email:$email';
  }

  String _profileFlatKey(String? value) {
    final String flat = (value ?? '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '')
        .toLowerCase();
    return flat.isEmpty ? '' : 'flat:$flat';
  }

  String _profileFlatNameKey(String? flatValue, String? nameValue) {
    final String flat = _profileFlatKey(flatValue);
    final String name = (nameValue ?? '')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
    if (flat.isEmpty || name.isEmpty) {
      return '';
    }
    return '$flat|name:$name';
  }

  Future<void> _toggleResident(ResidentRecord resident) async {
    try {
      if (resident.status) {
        await SocietyService.inactivateResident(resident.id);
      } else {
        await SocietyService.activateResident(resident.id);
      }
      _showMessage('Resident status updated.');
      await _loadAll();
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openResidentSlotsSheet({required bool renewal}) async {
    if (_societyId.isEmpty) {
      _showMessage('Society information is not available yet.');
      return;
    }

    final int minimumRenewalCount = _minimumRenewalResidentsCount();
    final int purchasedCount = _societyInfo?.purchasedResidentsCount ?? 0;
    final int initialCount = renewal
        ? (purchasedCount > 0
              ? purchasedCount
              : (minimumRenewalCount > 0 ? minimumRenewalCount : 1))
        : 1;
    final TextEditingController countController = TextEditingController(
      text: '$initialCount',
    );
    SocietyResidentsCalculationData? calculation;
    String? errorMessage;
    bool calculating = false;
    bool purchasing = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            int parseCount() {
              return int.tryParse(countController.text.trim()) ?? 0;
            }

            Future<void> calculate() async {
              final int count = parseCount();
              if (count < 1) {
                setModalState(() {
                  errorMessage = 'Enter at least one resident slot.';
                });
                return;
              }
              final String? renewalLimitMessage = renewal
                  ? _residentRenewalLimitMessage(count)
                  : null;
              if (renewalLimitMessage != null) {
                setModalState(() {
                  calculation = null;
                  errorMessage = renewalLimitMessage;
                });
                return;
              }

              setModalState(() {
                calculating = true;
                errorMessage = null;
              });

              try {
                final SocietyResidentsCalculationData result = renewal
                    ? await SocietyService.calculateResidentsRenewal(
                        societyId: _societyId,
                        numberOfResidents: count,
                      )
                    : await SocietyService.calculateResidents(
                        societyId: _societyId,
                        numberOfResidents: count,
                      );
                if (!mounted) {
                  return;
                }
                setModalState(() {
                  calculation = result;
                });
              } catch (error) {
                setModalState(() {
                  errorMessage = error.toString().replaceFirst(
                    'Exception: ',
                    '',
                  );
                });
              } finally {
                if (mounted) {
                  setModalState(() {
                    calculating = false;
                  });
                }
              }
            }

            Future<void> purchase() async {
              if (calculation == null) {
                await calculate();
                if (calculation == null) {
                  return;
                }
              }

              final int count = parseCount();
              final String? renewalLimitMessage = renewal
                  ? _residentRenewalLimitMessage(count)
                  : null;
              if (renewalLimitMessage != null) {
                setModalState(() {
                  calculation = null;
                  errorMessage = renewalLimitMessage;
                });
                return;
              }
              setModalState(() {
                purchasing = true;
                errorMessage = null;
              });

              try {
                final SocietyResidentsPurchaseData response = renewal
                    ? await SocietyService.renewResidents(
                        societyId: _societyId,
                        numberOfResidents: count,
                      )
                    : await SocietyService.purchaseResidents(
                        societyId: _societyId,
                        numberOfResidents: count,
                      );

                if (response.isFreePurchase || response.amount <= 0) {
                  if (!mounted) {
                    return;
                  }
                  Navigator.of(context).pop();
                  _showMessage(
                    renewal
                        ? 'Resident slots renewed successfully.'
                        : 'Resident slots added successfully.',
                  );
                  await _loadAll();
                  return;
                }

                VendorData? vendor;
                try {
                  vendor = await VendorService.fetchVendorInfo();
                } catch (_) {
                  vendor = null;
                }

                final RazorpayCheckoutResult
                checkoutResult = await RazorpayCheckoutService.openCheckout(
                  keyId: response.razorpayKeyId ?? '',
                  amountInPaise: (response.amount * 100).round(),
                  name: 'Urban Easy Flats',
                  description: renewal
                      ? 'Renew $count resident slot${count == 1 ? '' : 's'}'
                      : 'Purchase $count resident slot${count == 1 ? '' : 's'}',
                  orderId: response.razorpayOrderId ?? '',
                  currency: response.currency,
                  prefillName: vendor?.fullName,
                  prefillEmail: vendor?.email,
                  prefillContact: vendor?.phone,
                );

                if (!checkoutResult.success) {
                  throw Exception(
                    checkoutResult.message ??
                        'Resident slot payment was not completed.',
                  );
                }

                if (!mounted) {
                  return;
                }
                Navigator.of(context).pop();
                _showMessage(
                  renewal
                      ? 'Payment completed. Resident slot renewal is being processed.'
                      : 'Payment completed. Resident slots are being processed.',
                );
                await _loadAll();
              } catch (error) {
                setModalState(() {
                  errorMessage = error.toString().replaceFirst(
                    'Exception: ',
                    '',
                  );
                });
              } finally {
                if (mounted) {
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
                      renewal
                          ? 'Renew Resident Slots'
                          : 'Purchase Resident Slots',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      renewal
                          ? 'Extend society resident capacity using the same renewal calculation and checkout flow as the website.'
                          : 'Add more resident creation slots using the same calculation and checkout flow as the website.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        ToneBadge(
                          label:
                              'Available ${_societyInfo?.availableResidentsCreationCount ?? 0}',
                          tone: UiTone.success,
                        ),
                        ToneBadge(
                          label:
                              'Used ${_societyInfo?.usedResidentsCreationCount ?? _residents.length}',
                          tone: UiTone.warning,
                        ),
                        if (renewal && minimumRenewalCount > 0)
                          ToneBadge(
                            label: 'Minimum $minimumRenewalCount',
                            tone: UiTone.danger,
                          ),
                        if ((_societyInfo?.purchasedResidentsExpiryDate ?? '')
                            .isNotEmpty)
                          ToneBadge(
                            label:
                                'Expiry ${_societyInfo!.purchasedResidentsExpiryDate!}',
                            tone: UiTone.neutral,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: countController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: renewal
                            ? 'Residents to renew'
                            : 'Residents to purchase',
                      ),
                      onChanged: (_) {
                        setModalState(() {
                          calculation = null;
                          errorMessage = renewal
                              ? _residentRenewalLimitMessage(parseCount())
                              : null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (calculation != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: CustomCard(
                          padding: CustomCardPadding.sm,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Calculation',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 12),
                              _DetailRow(
                                label: 'Residents',
                                value: '${calculation!.numberOfResidents}',
                              ),
                              _DetailRow(
                                label: 'Per resident',
                                value:
                                    'Rs ${calculation!.amountPerResident.toStringAsFixed(0)}',
                              ),
                              _DetailRow(
                                label: 'Subtotal',
                                value:
                                    'Rs ${calculation!.subtotal.toStringAsFixed(0)}',
                              ),
                              _DetailRow(
                                label: 'GST',
                                value:
                                    '${calculation!.gstPercentage.toStringAsFixed(0)}% (Rs ${calculation!.gstAmount.toStringAsFixed(0)})',
                              ),
                              _DetailRow(
                                label: 'Total',
                                value:
                                    'Rs ${calculation!.totalAmount.toStringAsFixed(0)}',
                              ),
                              if (calculation!.residentsCountDifference != null)
                                _DetailRow(
                                  label: 'Difference',
                                  value:
                                      '${calculation!.residentsCountDifference}',
                                ),
                              if ((calculation!.validityEndDate ?? '')
                                  .isNotEmpty)
                                _DetailRow(
                                  label: 'Valid till',
                                  value: calculation!.validityEndDate!,
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.toneSoft(UiTone.danger),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSmall,
                            ),
                            border: Border.all(
                              color: AppTheme.toneContainer(UiTone.danger),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: AppTheme.toneColor(UiTone.danger),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppTheme.toneColor(
                                          UiTone.danger,
                                        ),
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: CustomButton(
                            label: 'Calculate',
                            variant: CustomButtonVariant.outline,
                            isLoading: calculating,
                            onPressed: calculating || purchasing
                                ? null
                                : calculate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomButton(
                            label: renewal ? 'Renew Now' : 'Purchase Now',
                            isLoading: purchasing,
                            onPressed: calculating || purchasing
                                ? null
                                : purchase,
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

    _disposeTextControllersAfterSheet(<TextEditingController>[countController]);
  }

  Future<void> _openResidentSheet({ResidentRecord? resident}) async {
    final TextEditingController nameController = TextEditingController(
      text: resident?.name ?? '',
    );
    final TextEditingController phoneController = TextEditingController(
      text: resident?.phone ?? '',
    );
    final TextEditingController emailController = TextEditingController(
      text: resident?.email ?? '',
    );
    final TextEditingController flatController = TextEditingController(
      text: resident?.flatNo ?? '',
    );
    final TextEditingController rentController = TextEditingController(
      text: resident?.rent?.toStringAsFixed(0) ?? '',
    );

    String buildingId = resident?.buildingId ?? _firstBuildingId();
    int residentType = switch (resident?.residentType) {
      ResidentType.owner => 1,
      ResidentType.pgResident => 3,
      _ => 2,
    };
    int flatType = _flatTypeToApi(resident?.flatType) ?? 1;
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            Future<void> submit() async {
              if (nameController.text.trim().isEmpty ||
                  phoneController.text.trim().isEmpty ||
                  flatController.text.trim().isEmpty ||
                  buildingId.isEmpty) {
                _showMessage(
                  'Name, phone, flat number, and building are required.',
                );
                return;
              }

              setModalState(() {
                isSubmitting = true;
              });

              final Map<String, dynamic> payload = <String, dynamic>{
                if (resident != null) 'Society_ResidentID': resident.id,
                if (resident == null) 'BuildingID': buildingId,
                'Name': nameController.text.trim(),
                'CountryCode': '+91',
                'PhoneNumber': phoneController.text.trim(),
                'EmailID': emailController.text.trim(),
                'Flat_No': flatController.text.trim(),
                'Resident_Type': residentType,
                'Monthly_Rent':
                    double.tryParse(rentController.text.trim()) ?? 0,
                'Flat_Type': flatType,
              };

              try {
                if (resident == null) {
                  await SocietyService.createResident(payload);
                } else {
                  await SocietyService.editResident(payload);
                }
                if (!mounted) {
                  return;
                }
                Navigator.of(context).pop();
                _showMessage(
                  resident == null
                      ? 'Resident created successfully.'
                      : 'Resident updated successfully.',
                );
                await _loadAll();
              } catch (error) {
                _showMessage(error.toString().replaceFirst('Exception: ', ''));
                setModalState(() {
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
                      resident == null ? 'Add Resident' : 'Edit Resident',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Full name'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: buildingId.isEmpty ? null : buildingId,
                      decoration: const InputDecoration(labelText: 'Building'),
                      items: _buildings.map((BuildingData building) {
                        final String blockName =
                            _blockNameForBuilding(building.blockId) ?? 'Block';
                        return DropdownMenuItem<String>(
                          value: building.buildingId,
                          child: Text('$blockName - ${building.name}'),
                        );
                      }).toList(),
                      onChanged: resident == null
                          ? (String? value) {
                              setModalState(() {
                                buildingId = value ?? '';
                              });
                            }
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: flatController,
                      decoration: const InputDecoration(
                        labelText: 'Flat number',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: residentType,
                      decoration: const InputDecoration(
                        labelText: 'Resident type',
                      ),
                      items: const <DropdownMenuItem<int>>[
                        DropdownMenuItem(value: 1, child: Text('Owner')),
                        DropdownMenuItem(value: 2, child: Text('Tenant')),
                        DropdownMenuItem(value: 3, child: Text('PG Resident')),
                      ],
                      onChanged: (int? value) {
                        setModalState(() {
                          residentType = value ?? 2;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: flatType,
                      decoration: const InputDecoration(labelText: 'Flat type'),
                      items: const <DropdownMenuItem<int>>[
                        DropdownMenuItem(value: 1, child: Text('1 BHK')),
                        DropdownMenuItem(value: 2, child: Text('2 BHK')),
                        DropdownMenuItem(value: 3, child: Text('3 BHK')),
                        DropdownMenuItem(value: 4, child: Text('4 BHK')),
                        DropdownMenuItem(value: 8, child: Text('Villa')),
                      ],
                      onChanged: (int? value) {
                        setModalState(() {
                          flatType = value ?? 1;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: rentController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Monthly Maintenance',
                        prefixText: 'Rs ',
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: CustomButton(
                        label: resident == null
                            ? 'Save Resident'
                            : 'Update Resident',
                        isLoading: isSubmitting,
                        onPressed: isSubmitting ? null : submit,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    _disposeTextControllersAfterSheet(<TextEditingController>[
      nameController,
      phoneController,
      emailController,
      flatController,
      rentController,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int activeCount = _residents
        .where((ResidentRecord item) => item.status)
        .length;
    final int availableSlots =
        _societyInfo?.availableResidentsCreationCount ?? 0;
    final int usedSlots =
        _societyInfo?.usedResidentsCreationCount ?? _residents.length;
    final bool canAddResident = _buildings.isNotEmpty && availableSlots > 0;
    final bool canRenewResidents =
        (_societyInfo?.purchasedResidentsCount ?? 0) > 0 ||
        ((_societyInfo?.purchasedResidentsExpiryDate ?? '').isNotEmpty);
    final int slotExpiryUrgency = _slotExpiryUrgency(
      _societyInfo?.purchasedResidentsExpiryDate,
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Text('Residents'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.border),
        ),
      ),
      floatingActionButton: _societyId.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _buildings.isEmpty
                  ? null
                  : (canAddResident
                        ? _openResidentSheet
                        : () => _openResidentSlotsSheet(renewal: false)),
              icon: Icon(
                canAddResident
                    ? Icons.person_add_alt_1_outlined
                    : Icons.shopping_cart_checkout_rounded,
              ),
              label: Text(canAddResident ? 'Add Resident' : 'Buy Slots'),
            ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: AppTheme.pagePadding,
          children: <Widget>[
            const PageHeader(
              title: 'Resident Management',
              description:
                  'Directory, create/edit actions, and active-state controls using the society resident APIs.',
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _SummaryCard(
                    label: 'Residents',
                    value: '${_residents.length}',
                    tone: UiTone.brand,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    label: 'Active',
                    value: '$activeCount',
                    tone: UiTone.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_societyInfo != null) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: _SummaryCard(
                      label: 'Available Slots',
                      value: '$availableSlots',
                      tone: UiTone.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Used Slots',
                      value: '$usedSlots',
                      tone: UiTone.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CustomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Resident slot setup',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      availableSlots > 0
                          ? 'You can keep adding residents while slots are available. Purchase or renew capacity here when you need more.'
                          : 'All available resident creation slots are used. Purchase or renew slots before adding more residents.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        if ((_societyInfo?.totalResidentsCreationCount ?? 0) >
                            0)
                          ToneBadge(
                            label:
                                'Capacity ${_societyInfo!.totalResidentsCreationCount}',
                            tone: UiTone.brand,
                          ),
                        if ((_societyInfo?.purchasedResidentsCount ?? 0) > 0)
                          ToneBadge(
                            label:
                                'Purchased ${_societyInfo!.purchasedResidentsCount}',
                            tone: UiTone.neutral,
                          ),
                        if ((_societyInfo?.purchasedResidentsExpiryDate ?? '')
                            .isNotEmpty)
                          ToneBadge(
                            label:
                                'Expiry ${_societyInfo!.purchasedResidentsExpiryDate!}',
                            tone: _slotExpiryTone(slotExpiryUrgency),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: CustomButton(
                            label: 'Purchase Slots',
                            onPressed: () =>
                                _openResidentSlotsSheet(renewal: false),
                          ),
                        ),
                        if (canRenewResidents) ...<Widget>[
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomButton(
                              label: 'Renew Slots',
                              variant: _renewSlotsButtonVariant(
                                slotExpiryUrgency,
                              ),
                              onPressed: () =>
                                  _openResidentSlotsSheet(renewal: true),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search resident',
                suffixIcon: IconButton(
                  onPressed: () {
                    _searchDebounce?.cancel();
                    setState(() {
                      _skip = 0;
                    });
                    _loadAll();
                  },
                  icon: const Icon(Icons.search_rounded),
                ),
              ),
              onChanged: (String _) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                  setState(() {
                    _skip = 0;
                  });
                  _loadAll();
                });
              },
              onSubmitted: (_) {
                _searchDebounce?.cancel();
                setState(() {
                  _skip = 0;
                });
                _loadAll();
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _blockFilter.isEmpty ? null : _blockFilter,
              decoration: const InputDecoration(labelText: 'Filter by block'),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('All Blocks'),
                ),
                ..._blocks.map((BlockData block) {
                  return DropdownMenuItem<String>(
                    value: block.blockId,
                    child: Text(block.name),
                  );
                }),
              ],
              onChanged: (String? value) {
                setState(() {
                  _blockFilter = value ?? '';
                  _skip = 0;
                  if (_blockFilter.isNotEmpty &&
                      _buildingFilter.isNotEmpty &&
                      !_buildings.any(
                        (BuildingData item) =>
                            item.buildingId == _buildingFilter &&
                            item.blockId == _blockFilter,
                      )) {
                    _buildingFilter = '';
                  }
                });
                _loadAll();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _buildingFilter.isEmpty ? null : _buildingFilter,
              decoration: const InputDecoration(
                labelText: 'Filter by building',
              ),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('All Buildings'),
                ),
                ..._buildings
                    .where(
                      (BuildingData item) =>
                          _blockFilter.isEmpty || item.blockId == _blockFilter,
                    )
                    .map((BuildingData building) {
                      return DropdownMenuItem<String>(
                        value: building.buildingId,
                        child: Text(building.name),
                      );
                    }),
              ],
              onChanged: (String? value) {
                setState(() {
                  _buildingFilter = value ?? '';
                  _skip = 0;
                });
                _loadAll();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              value: _residentTypeFilter,
              decoration: const InputDecoration(labelText: 'Resident type'),
              items: const <DropdownMenuItem<int?>>[
                DropdownMenuItem<int?>(value: null, child: Text('All Types')),
                DropdownMenuItem<int?>(value: 1, child: Text('Owner')),
                DropdownMenuItem<int?>(value: 2, child: Text('Tenant')),
                DropdownMenuItem<int?>(value: 3, child: Text('PG Resident')),
              ],
              onChanged: (int? value) {
                setState(() {
                  _residentTypeFilter = value;
                  _skip = 0;
                });
                _loadAll();
              },
            ),
            const SizedBox(height: 16),
            CustomTabBar(
              style: CustomTabBarStyle.pill,
              currentIndex: _statusFilter == null
                  ? 0
                  : (_statusFilter! ? 1 : 2),
              onChanged: (int index) {
                setState(() {
                  _statusFilter = switch (index) {
                    1 => true,
                    2 => false,
                    _ => null,
                  };
                  _skip = 0;
                });
                _loadAll();
              },
              tabs: const <CustomTabItem>[
                CustomTabItem(label: 'All'),
                CustomTabItem(label: 'Active'),
                CustomTabItem(label: 'Inactive'),
              ],
            ),
            const SizedBox(height: 16),
            if (_blockFilter.isNotEmpty &&
                !_isLoading &&
                _totalCount > 0) ...<Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(color: AppTheme.primaryTone),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.apartment_outlined,
                      size: 16,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_blocks.where((BlockData b) => b.blockId == _blockFilter).map((BlockData b) => b.name).firstOrNull ?? 'Selected block'}'
                        ': $_totalCount resident${_totalCount == 1 ? '' : 's'} total',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 64),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              _ErrorCard(message: _errorMessage!, onRetry: _loadAll)
            else if (_residents.isEmpty)
              const CustomCard(
                child: Text('No residents found for the current filters.'),
              )
            else
              ..._residents.map(
                (ResidentRecord resident) =>
                    _buildResidentCard(resident, theme),
              ),
            if (!_isLoading &&
                _errorMessage == null &&
                _totalCount > _pageSize) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: CustomButton(
                      label: 'Previous',
                      variant: CustomButtonVariant.outline,
                      onPressed: _skip == 0
                          ? null
                          : () {
                              setState(() {
                                _skip = (_skip - _pageSize).clamp(
                                  0,
                                  _totalCount,
                                );
                              });
                              _loadAll();
                            },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Showing ${_skip + 1}–${_skip + _residents.length} of $_totalCount',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      label: 'Next',
                      variant: CustomButtonVariant.outline,
                      onPressed: _skip + _pageSize >= _totalCount
                          ? null
                          : () {
                              setState(() {
                                _skip += _pageSize;
                              });
                              _loadAll();
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

  int? _flatTypeToApi(String? flatType) {
    return switch (flatType) {
      '1 BHK' => 1,
      '2 BHK' => 2,
      '3 BHK' => 3,
      '4 BHK' => 4,
      'Villa' => 8,
      _ => null,
    };
  }

  String _firstBuildingId() {
    return _buildings.isEmpty ? '' : _buildings.first.buildingId;
  }

  String? _blockNameForBuilding(String? blockId) {
    for (final BlockData block in _blocks) {
      if (block.blockId == blockId) {
        return block.name;
      }
    }
    return null;
  }

  int _slotExpiryUrgency(String? value) {
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

  int _activeResidentCountForRenewal() {
    final int apiActiveResidents = _societyInfo?.activeResidents ?? 0;
    if (apiActiveResidents > 0) {
      return apiActiveResidents;
    }
    return _residents.where((ResidentRecord item) => item.status).length;
  }

  int _minimumRenewalResidentsCount() {
    final int activeResidents = _activeResidentCountForRenewal();
    final int freeResidents = _societyInfo?.freeResidentsCount ?? 0;
    final int requiredPurchasedResidents = activeResidents - freeResidents;
    return requiredPurchasedResidents > 0 ? requiredPurchasedResidents : 0;
  }

  String? _residentRenewalLimitMessage(int count) {
    final int minimumRenewalCount = _minimumRenewalResidentsCount();
    if (minimumRenewalCount <= 0 || count >= minimumRenewalCount) {
      return null;
    }

    final int activeResidents = _activeResidentCountForRenewal();
    final int freeResidents = _societyInfo?.freeResidentsCount ?? 0;
    return 'Insufficient Residents. There are $activeResidents active residents. You have $freeResidents free residents, so you need to purchase at least $minimumRenewalCount extra residents.';
  }

  UiTone _slotExpiryTone(int urgency) {
    return switch (urgency) {
      2 => UiTone.danger,
      1 => UiTone.warning,
      _ => UiTone.neutral,
    };
  }

  CustomButtonVariant _renewSlotsButtonVariant(int urgency) {
    return switch (urgency) {
      2 => CustomButtonVariant.danger,
      1 => CustomButtonVariant.secondary,
      _ => CustomButtonVariant.outline,
    };
  }

  Widget _buildResidentCard(ResidentRecord resident, ThemeData theme) {
    final String blockName = _residentBlockName(resident);
    final String buildingName = _residentBuildingName(resident);

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
                _ResidentAvatar(imageUrl: resident.imageUrl),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            resident.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          ToneBadge(
                            label: resident.status ? 'Active' : 'Inactive',
                            tone: resident.status
                                ? UiTone.success
                                : UiTone.danger,
                          ),
                          ToneBadge(
                            label: resident.residentType.label,
                            tone: resident.residentType.tone,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (resident.flatNo.trim().isNotEmpty)
                        _residentInfoLine(
                          theme,
                          Icons.home_outlined,
                          resident.flatNo,
                        ),
                      if (resident.phone.trim().isNotEmpty)
                        _residentInfoLine(
                          theme,
                          Icons.phone_outlined,
                          resident.phone,
                        ),
                      if ((resident.email ?? '').trim().isNotEmpty)
                        _residentInfoLine(
                          theme,
                          Icons.mail_outline,
                          resident.email!.trim(),
                        ),
                      if (blockName.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        _residentContextLine(theme, 'Block: $blockName'),
                      ],
                      if (buildingName.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        _residentContextLine(theme, 'Building: $buildingName'),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if ((resident.flatType ?? '').isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: ToneBadge(label: resident.flatType!, tone: UiTone.brand),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: CustomButton(
                    label: 'Edit',
                    icon: const Icon(Icons.edit_outlined),
                    variant: CustomButtonVariant.outline,
                    onPressed: () => _openResidentSheet(resident: resident),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    label: resident.status ? 'Deactivate' : 'Activate',
                    icon: Icon(
                      resident.status
                          ? Icons.cancel_outlined
                          : Icons.check_circle_outline,
                    ),
                    variant: resident.status
                        ? CustomButtonVariant.danger
                        : CustomButtonVariant.primary,
                    onPressed: () => _toggleResident(resident),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _residentInfoLine(ThemeData theme, IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: AppTheme.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _residentContextLine(ThemeData theme, String value) {
    return Padding(
      padding: const EdgeInsets.only(left: 28),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _residentBlockName(ResidentRecord resident) {
    final String direct = resident.blockName?.trim() ?? '';
    if (direct.isNotEmpty) {
      return direct;
    }

    final String blockId = resident.blockId?.trim() ?? '';
    if (blockId.isNotEmpty) {
      final String? blockName = _blockNameForBuilding(blockId);
      if ((blockName ?? '').isNotEmpty) {
        return blockName!;
      }
    }

    final String buildingId = resident.buildingId?.trim() ?? '';
    if (buildingId.isNotEmpty) {
      for (final BuildingData building in _buildings) {
        if (building.buildingId == buildingId) {
          return _blockNameForBuilding(building.blockId) ?? '';
        }
      }
    }

    return '';
  }

  String _residentBuildingName(ResidentRecord resident) {
    final String direct = resident.buildingName?.trim() ?? '';
    if (direct.isNotEmpty) {
      return direct;
    }

    final String buildingId = resident.buildingId?.trim() ?? '';
    if (buildingId.isNotEmpty) {
      for (final BuildingData building in _buildings) {
        if (building.buildingId == buildingId) {
          return building.name;
        }
      }
    }

    return '';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _disposeTextControllersAfterSheet(
    List<TextEditingController> controllers,
  ) {
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        for (final TextEditingController controller in controllers) {
          controller.dispose();
        }
      }),
    );
  }
}

class _ResidentAvatar extends StatefulWidget {
  const _ResidentAvatar({this.imageUrl});

  final String? imageUrl;

  @override
  State<_ResidentAvatar> createState() => _ResidentAvatarState();
}

class _ResidentAvatarState extends State<_ResidentAvatar> {
  String? _resolvedUrl;
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    _resolveImageId();
  }

  @override
  void didUpdateWidget(covariant _ResidentAvatar oldWidget) {
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
        width: 76,
        height: 76,
        color: AppTheme.primaryTone,
        child: _isResolving
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : url.isEmpty
            ? const Icon(
                Icons.person_outline,
                color: AppTheme.primary,
                size: 38,
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.person_outline,
                  color: AppTheme.primary,
                  size: 38,
                ),
              ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextStyle? valueStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value, textAlign: TextAlign.right, style: valueStyle),
          ),
        ],
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
    return CustomCard(
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
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Unable to load residents',
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
