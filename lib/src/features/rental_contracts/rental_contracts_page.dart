import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/property_service.dart';
import '../../core/api/razorpay_checkout_service.dart';
import '../../core/api/rental_contract_service.dart';
import '../../core/api/upload_service.dart';
import '../../core/api/vendor_service.dart';
import '../../core/models/api_models.dart';
import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/rental_contract_pdf_service.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_card.dart';
import '../../core/widgets/custom_tab_bar.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/tone_badge.dart';

const Map<int, Map<int, String>> _contractPropertySubTypeLabels =
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

const Map<int, String> _contractPgSharingLabels = <int, String>{
  1: 'Single',
  2: 'Double',
  3: 'Triple',
  4: 'Quad',
  5: 'Dorm',
};

String _contractStatusLabel(RentalContractRecord contract) {
  return contract.isActive ? contract.status.label : 'Inactive';
}

UiTone _contractStatusTone(RentalContractRecord contract) {
  return contract.isActive ? contract.status.tone : UiTone.danger;
}

class RentalContractsPage extends StatefulWidget {
  const RentalContractsPage({super.key});

  @override
  State<RentalContractsPage> createState() => _RentalContractsPageState();
}

class _RentalContractsPageState extends State<RentalContractsPage> {
  bool _isLoading = true;
  String? _errorMessage;
  ContractStatus? _statusFilter;
  String _propertyFilterId = '';
  String _searchTerm = '';
  final TextEditingController _searchController = TextEditingController();
  List<PropertyRecord> _properties = <PropertyRecord>[];
  List<RentalContractRecord> _contracts = <RentalContractRecord>[];
  List<Map<String, dynamic>> _liteProperties = <Map<String, dynamic>>[];

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('$value');
  }

  String _propertyDisplayLabel(PropertyRecord property) {
    final Map<String, dynamic>? lite = _liteProperties
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (Map<String, dynamic>? item) => item?['PropertyID'] == property.id,
          orElse: () => null,
        );

    if (lite == null) {
      return property.title;
    }

    final int? propertyType = _asInt(lite['Property_Type']);
    final int? subType = _asInt(lite['Sub_Type']);
    final int? pgSharingType = _asInt(lite['PG_Sharing_Type']);
    final String title =
        (lite['Property_Title'] as String?)?.trim().isNotEmpty == true
        ? (lite['Property_Title'] as String).trim()
        : property.title;
    final String subtypeLabel = propertyType != null && subType != null
        ? (_contractPropertySubTypeLabels[propertyType]?[subType] ?? '')
        : '';
    final String pgSharingLabel = propertyType == 3 && pgSharingType != null
        ? (_contractPgSharingLabels[pgSharingType] ?? '')
        : '';

    if (subtypeLabel.isEmpty) {
      return title;
    }

    if (pgSharingLabel.isEmpty) {
      return '$title ($subtypeLabel)';
    }

    return '$title ($subtypeLabel - $pgSharingLabel)';
  }

  String _availableContractsLabel(PropertyRecord property) {
    final int available =
        property.availableResidentContractsCreationCount ??
        property.noOfVacancy ??
        0;
    return available == 0
        ? 'Available rental contracts: No'
        : 'Available rental contracts: $available';
  }

  Widget _propertyDropdownMenuItem(
    BuildContext context,
    PropertyRecord property,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            _propertyDisplayLabel(property),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 3),
          Text(
            _availableContractsLabel(property),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _propertyDropdownSelectedItem(
    BuildContext context,
    PropertyRecord property,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        _propertyDisplayLabel(property),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadContracts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContracts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        PropertyService.filterProperties(limit: 200),
        RentalContractService.filterRentalContracts(
          status: _statusFilter,
          propertyId: _propertyFilterId.isEmpty ? null : _propertyFilterId,
          limit: 200,
        ),
        PropertyService.filterPropertiesLite(limit: 200),
      ]);

      if (!mounted) {
        return;
      }

      final propertiesResult =
          results[0] as ({List<PropertyRecord> properties, int count});
      final contractsResult =
          results[1] as ({List<RentalContractRecord> contracts, int count});
      final liteResult =
          results[2] as ({List<Map<String, dynamic>> properties, int count});
      final bool hasSelectedProperty =
          _propertyFilterId.isEmpty ||
          propertiesResult.properties.any(
            (PropertyRecord property) => property.id == _propertyFilterId,
          );

      setState(() {
        if (!hasSelectedProperty) {
          _propertyFilterId = '';
        }
        _properties = propertiesResult.properties;
        _contracts = contractsResult.contracts;
        _liteProperties = liteResult.properties;
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

  Future<void> _openContractSheet({RentalContractRecord? contract}) async {
    String propertyId = _propertyIdForContract(contract) ?? '';
    final TextEditingController unitController = TextEditingController(
      text: contract?.flatNo ?? '',
    );
    final TextEditingController tenantNameController = TextEditingController(
      text: contract?.tenantName ?? '',
    );
    final TextEditingController tenantPhoneController = TextEditingController(
      text: contract?.tenantPhone ?? '',
    );
    final TextEditingController tenantEmailController = TextEditingController(
      text: contract?.tenantEmail ?? '',
    );
    final TextEditingController ownerNameController = TextEditingController(
      text: contract?.ownerName ?? '',
    );
    final TextEditingController ownerPhoneController = TextEditingController(
      text: contract?.ownerPhone ?? '',
    );
    final TextEditingController ownerEmailController = TextEditingController(
      text: contract?.ownerEmail ?? '',
    );
    final TextEditingController ownerAddressController = TextEditingController(
      text: contract?.ownerAddress ?? '',
    );
    final TextEditingController rentController = TextEditingController(
      text: contract?.rent.toStringAsFixed(0) ?? '',
    );
    final TextEditingController depositController = TextEditingController(
      text: contract?.deposit.toStringAsFixed(0) ?? '',
    );
    final TextEditingController maintenanceController = TextEditingController(
      text: contract?.maintenanceAmount?.toStringAsFixed(0) ?? '',
    );
    final TextEditingController specialTermsController = TextEditingController(
      text: contract?.specialTerms ?? '',
    );
    final TextEditingController tokenAmountController = TextEditingController(
      text: contract?.tokenAmount?.toStringAsFixed(0) ?? '0',
    );
    DateTime startDate = contract?.startDate ?? DateTime.now();
    DateTime endDate =
        contract?.endDate ?? DateTime.now().add(const Duration(days: 365));
    bool maintenanceIncluded = contract?.whetherMaintenanceIncluded ?? false;
    bool firstMonthRentPaid = contract?.whetherFirstMonthRentPaid ?? false;
    bool securityDepositPaid = contract?.whetherSecurityDepositPaid ?? false;
    bool isSubmitting = false;
    bool isUploadingDoc = false;

    // KYC document state — null means no doc, non-null means uploaded/existing
    ContractDocumentRecord? tenantIdProof = contract?.tenantIdProof;
    ContractDocumentRecord? tenantAddressProof = contract?.tenantAddressProof;
    ContractDocumentRecord? ownerIdProof = contract?.ownerIdProof;
    ContractDocumentRecord? ownerPropertyProof =
        contract?.ownerPropertyOwnershipProof;
    ContractDocumentRecord? ownerBankProof = contract?.ownerBankProof;
    bool isSheetOpen = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            void safeSetModalState(VoidCallback fn) {
              if (!context.mounted || !isSheetOpen) {
                return;
              }
              setModalState(fn);
            }

            Future<void> pickDate({required bool isStart}) async {
              final DateTime initialDate = isStart ? startDate : endDate;
              final DateTime? selected = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );

              if (selected == null) {
                return;
              }

              safeSetModalState(() {
                if (isStart) {
                  startDate = selected;
                } else {
                  endDate = selected;
                }
              });
            }

            Future<void> uploadKycDoc({
              required String label,
              required void Function(ContractDocumentRecord?) onDone,
            }) async {
              final FilePickerResult? result = await FilePicker.platform
                  .pickFiles(
                    allowMultiple: false,
                    type: FileType.custom,
                    allowedExtensions: <String>[
                      'pdf',
                      'png',
                      'jpg',
                      'jpeg',
                      'webp',
                    ],
                  );
              if (result == null ||
                  result.files.isEmpty ||
                  (result.files.single.path ?? '').isEmpty) {
                return;
              }
              if (!context.mounted || !isSheetOpen) {
                return;
              }
              safeSetModalState(() {
                isUploadingDoc = true;
              });
              try {
                final String? docId = await UploadService.uploadDocument(
                  File(result.files.single.path!),
                );
                if (docId == null || docId.isEmpty) {
                  throw Exception('Failed to upload $label.');
                }
                final String? docUrl = await UploadService.fetchDocumentInfo(
                  docId,
                );
                if (!context.mounted || !isSheetOpen) {
                  return;
                }
                onDone(
                  ContractDocumentRecord(
                    documentId: docId,
                    documentName: result.files.single.name,
                    documentUrl: docUrl ?? '',
                  ),
                );
              } catch (error) {
                _showMessage(error.toString().replaceFirst('Exception: ', ''));
              } finally {
                safeSetModalState(() {
                  isUploadingDoc = false;
                });
              }
            }

            Future<void> submit() async {
              if (propertyId.isEmpty ||
                  tenantNameController.text.trim().isEmpty ||
                  unitController.text.trim().isEmpty) {
                _showMessage(
                  'Property, tenant name, and flat number are required.',
                );
                return;
              }

              safeSetModalState(() {
                isSubmitting = true;
              });

              final Map<String, dynamic> payload = <String, dynamic>{
                if (contract != null) 'Rental_ContractID': contract.id,
                'PropertyID': propertyId,
                'Flat_Or_Unit_No': unitController.text.trim(),
                'Tenant_Name': tenantNameController.text.trim(),
                'Tenant_EmailID': tenantEmailController.text.trim(),
                'Tenant_PhoneNumber': tenantPhoneController.text.trim(),
                'Owner_Name': ownerNameController.text.trim(),
                'Owner_EmailID': ownerEmailController.text.trim(),
                'Owner_Address': ownerAddressController.text.trim(),
                'Owner_PhoneNumber': ownerPhoneController.text.trim(),
                'Contract_Start_Date': _formatDate(startDate),
                'Contract_End_Date': _formatDate(endDate),
                'Monthly_Rent':
                    double.tryParse(rentController.text.trim()) ?? 0,
                'Security_Deposit':
                    double.tryParse(depositController.text.trim()) ?? 0,
                'Token_Amount':
                    double.tryParse(tokenAmountController.text.trim()) ?? 0,
                'Whether_Maintainance_Included': maintenanceIncluded,
                'Maintainance_Charge': maintenanceIncluded
                    ? (double.tryParse(maintenanceController.text.trim()) ?? 0)
                    : 0,
                'Whether_First_Month_Rent_Paid': firstMonthRentPaid,
                'Whether_Security_Deposit_Paid': securityDepositPaid,
                'Special_Terms': specialTermsController.text.trim(),
                'Whether_Tenant_ID_Proof_Available': tenantIdProof != null,
                'Tenant_ID_Proof_DocumentID': tenantIdProof?.documentId ?? '',
                'Whether_Tenant_Address_Proof_Available':
                    tenantAddressProof != null,
                'Tenant_Address_Proof_DocumentID':
                    tenantAddressProof?.documentId ?? '',
                'Whether_Owner_ID_Proof_Available': ownerIdProof != null,
                'Owner_ID_Proof_DocumentID': ownerIdProof?.documentId ?? '',
                'Whether_Owner_Property_Ownership_Proof_Available':
                    ownerPropertyProof != null,
                'Owner_Property_Ownership_Proof_DocumentID':
                    ownerPropertyProof?.documentId ?? '',
                'Whether_Owner_Bank_Proof_Available': ownerBankProof != null,
                'Owner_Bank_Proof_DocumentID': ownerBankProof?.documentId ?? '',
              };

              try {
                final ApiResponse response = contract == null
                    ? await RentalContractService.createRentalContract(payload)
                    : await RentalContractService.editRentalContract(payload);

                if (!mounted || !context.mounted || !isSheetOpen) {
                  return;
                }

                if (!response.success) {
                  final String errorMsg =
                      response.message ??
                      response.status ??
                      'Unable to save contract.';
                  final String errLower = errorMsg.toLowerCase();

                  // Auto-trigger purchase slots sheet
                  if (errLower.contains('slot') ||
                      errLower.contains('available_resident') ||
                      errLower.contains('resident_contract')) {
                    Navigator.of(context).pop();
                    isSheetOpen = false;
                    setState(() {
                      _propertyFilterId = propertyId;
                    });
                    _showMessage(
                      'No contract slots available. Please purchase slots first.',
                    );
                    await _openPurchaseResidentContractsSheet();
                    return;
                  }

                  // Auto-trigger subscription guidance
                  if (errLower.contains('subscription') ||
                      errLower.contains('subscri') ||
                      errLower.contains('plan')) {
                    Navigator.of(context).pop();
                    isSheetOpen = false;
                    _showMessage(
                      'No active subscription for this property. Go to Properties → Manage Plan.',
                    );
                    return;
                  }

                  throw Exception(errorMsg);
                }

                Navigator.of(context).pop();
                isSheetOpen = false;
                _showMessage(
                  contract == null
                      ? 'Contract created successfully.'
                      : 'Contract updated successfully.',
                );
                await _loadContracts();
              } catch (error) {
                if (!context.mounted || !isSheetOpen) {
                  return;
                }
                _showMessage(error.toString().replaceFirst('Exception: ', ''));
                safeSetModalState(() {
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
                      contract == null ? 'Add Contract' : 'Edit Contract',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: propertyId.isEmpty ? null : propertyId,
                      decoration: const InputDecoration(labelText: 'Property'),
                      isExpanded: true,
                      itemHeight: null,
                      menuMaxHeight: MediaQuery.of(context).size.height * 0.65,
                      selectedItemBuilder: (BuildContext context) {
                        return _properties
                            .map(
                              (PropertyRecord property) =>
                                  _propertyDropdownSelectedItem(
                                    context,
                                    property,
                                  ),
                            )
                            .toList();
                      },
                      items: _properties.map((PropertyRecord property) {
                        return DropdownMenuItem<String>(
                          value: property.id,
                          child: _propertyDropdownMenuItem(context, property),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        setModalState(() {
                          propertyId = value ?? '';
                        });
                        // Auto-populate owner details from property
                        if (value != null && value.isNotEmpty) {
                          final Map<String, dynamic>? lite = _liteProperties
                              .cast<Map<String, dynamic>?>()
                              .firstWhere(
                                (Map<String, dynamic>? p) =>
                                    p?['PropertyID'] == value,
                                orElse: () => null,
                              );
                          if (lite != null) {
                            setModalState(() {
                              unitController.text =
                                  (lite['Flat_Or_Unit_No'] as String?) ??
                                  unitController.text;
                              ownerNameController.text =
                                  (lite['Owner_Name'] as String?) ??
                                  ownerNameController.text;
                              ownerPhoneController.text =
                                  (lite['Owner_Phone'] as String?) ??
                                  (lite['Owner_PhoneNumber'] as String?) ??
                                  ownerPhoneController.text;
                              ownerEmailController.text =
                                  (lite['Owner_Email'] as String?) ??
                                  (lite['Owner_EmailID'] as String?) ??
                                  ownerEmailController.text;
                              ownerAddressController.text =
                                  (lite['Owner_Address'] as String?) ??
                                  ownerAddressController.text;
                              rentController.text = lite['Monthly_Rent'] != null
                                  ? '${(lite['Monthly_Rent'] as num).toInt()}'
                                  : rentController.text;
                              depositController.text =
                                  lite['Security_Deposit'] != null
                                  ? '${(lite['Security_Deposit'] as num).toInt()}'
                                  : depositController.text;
                            });
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: unitController,
                      decoration: const InputDecoration(
                        labelText: 'Flat or unit no',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: tenantNameController,
                      decoration: const InputDecoration(
                        labelText: 'Tenant name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: tenantPhoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Tenant phone',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: tenantEmailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Tenant email',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ownerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Owner name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: ownerPhoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Owner phone',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: ownerEmailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Owner email',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ownerAddressController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Owner address',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _DateField(
                            label: 'Start date',
                            value: _formatDate(startDate),
                            onTap: () => pickDate(isStart: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateField(
                            label: 'End date',
                            value: _formatDate(endDate),
                            onTap: () => pickDate(isStart: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: rentController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Rent',
                              prefixText: 'Rs ',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: depositController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Deposit',
                              prefixText: 'Rs ',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Maintenance included',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Switch(
                          value: maintenanceIncluded,
                          onChanged: (bool v) => setModalState(() {
                            maintenanceIncluded = v;
                          }),
                        ),
                      ],
                    ),
                    if (maintenanceIncluded) ...<Widget>[
                      const SizedBox(height: 8),
                      TextField(
                        controller: maintenanceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Maintenance charge',
                          prefixText: 'Rs ',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'First month rent paid',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Switch(
                          value: firstMonthRentPaid,
                          onChanged: (bool v) => setModalState(() {
                            firstMonthRentPaid = v;
                          }),
                        ),
                      ],
                    ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Security deposit paid',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Switch(
                          value: securityDepositPaid,
                          onChanged: (bool v) => setModalState(() {
                            securityDepositPaid = v;
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: specialTermsController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Special terms',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'KYC Documents',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Upload ID proof, address proof, and ownership documents.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _KycDocRow(
                      label: 'Tenant ID Proof',
                      doc: tenantIdProof,
                      isUploading: isUploadingDoc,
                      onUpload: () => uploadKycDoc(
                        label: 'Tenant ID Proof',
                        onDone: (ContractDocumentRecord? doc) =>
                            setModalState(() {
                              tenantIdProof = doc;
                            }),
                      ),
                      onRemove: () => setModalState(() => tenantIdProof = null),
                    ),
                    const SizedBox(height: 8),
                    _KycDocRow(
                      label: 'Tenant Address Proof',
                      doc: tenantAddressProof,
                      isUploading: isUploadingDoc,
                      onUpload: () => uploadKycDoc(
                        label: 'Tenant Address Proof',
                        onDone: (ContractDocumentRecord? doc) =>
                            setModalState(() {
                              tenantAddressProof = doc;
                            }),
                      ),
                      onRemove: () =>
                          setModalState(() => tenantAddressProof = null),
                    ),
                    const SizedBox(height: 8),
                    _KycDocRow(
                      label: 'Owner ID Proof',
                      doc: ownerIdProof,
                      isUploading: isUploadingDoc,
                      onUpload: () => uploadKycDoc(
                        label: 'Owner ID Proof',
                        onDone: (ContractDocumentRecord? doc) =>
                            setModalState(() {
                              ownerIdProof = doc;
                            }),
                      ),
                      onRemove: () => setModalState(() => ownerIdProof = null),
                    ),
                    const SizedBox(height: 8),
                    _KycDocRow(
                      label: 'Owner Property Ownership Proof',
                      doc: ownerPropertyProof,
                      isUploading: isUploadingDoc,
                      onUpload: () => uploadKycDoc(
                        label: 'Owner Property Proof',
                        onDone: (ContractDocumentRecord? doc) =>
                            setModalState(() {
                              ownerPropertyProof = doc;
                            }),
                      ),
                      onRemove: () =>
                          setModalState(() => ownerPropertyProof = null),
                    ),
                    const SizedBox(height: 8),
                    _KycDocRow(
                      label: 'Owner Bank Proof',
                      doc: ownerBankProof,
                      isUploading: isUploadingDoc,
                      onUpload: () => uploadKycDoc(
                        label: 'Owner Bank Proof',
                        onDone: (ContractDocumentRecord? doc) =>
                            setModalState(() {
                              ownerBankProof = doc;
                            }),
                      ),
                      onRemove: () =>
                          setModalState(() => ownerBankProof = null),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: CustomButton(
                        label: contract == null
                            ? 'Save Contract'
                            : 'Update Contract',
                        isLoading: isSubmitting,
                        onPressed: isSubmitting || isUploadingDoc
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
    );
    isSheetOpen = false;
  }

  Future<void> _openKycUpdateSheet(RentalContractRecord contract) async {
    bool isUploadingDoc = false;
    bool isSaving = false;

    ContractDocumentRecord? tenantIdProof = contract.tenantIdProof;
    ContractDocumentRecord? tenantAddressProof = contract.tenantAddressProof;
    ContractDocumentRecord? ownerIdProof = contract.ownerIdProof;
    ContractDocumentRecord? ownerPropertyProof =
        contract.ownerPropertyOwnershipProof;
    ContractDocumentRecord? ownerBankProof = contract.ownerBankProof;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            Future<void> uploadDoc({
              required String label,
              required void Function(ContractDocumentRecord?) onDone,
            }) async {
              final FilePickerResult? result = await FilePicker.platform
                  .pickFiles(
                    allowMultiple: false,
                    type: FileType.custom,
                    allowedExtensions: <String>[
                      'pdf',
                      'png',
                      'jpg',
                      'jpeg',
                      'webp',
                    ],
                  );
              if (result == null ||
                  result.files.isEmpty ||
                  (result.files.single.path ?? '').isEmpty) {
                return;
              }
              setModalState(() => isUploadingDoc = true);
              try {
                final String? docId = await UploadService.uploadDocument(
                  File(result.files.single.path!),
                );
                if (docId == null || docId.isEmpty) {
                  throw Exception('Failed to upload $label.');
                }
                final String? docUrl = await UploadService.fetchDocumentInfo(
                  docId,
                );
                onDone(
                  ContractDocumentRecord(
                    documentId: docId,
                    documentName: result.files.single.name,
                    documentUrl: docUrl ?? '',
                  ),
                );
              } catch (error) {
                _showMessage(error.toString().replaceFirst('Exception: ', ''));
              } finally {
                if (mounted) {
                  setModalState(() => isUploadingDoc = false);
                }
              }
            }

            Future<void> save() async {
              setModalState(() => isSaving = true);
              try {
                final ApiResponse response =
                    await RentalContractService.updateTenantDocuments(
                      contractId: contract.id,
                      whetherTenantIdProofAvailable: tenantIdProof != null,
                      tenantIdProofDocumentId: tenantIdProof?.documentId ?? '',
                      whetherTenantAddressProofAvailable:
                          tenantAddressProof != null,
                      tenantAddressProofDocumentId:
                          tenantAddressProof?.documentId ?? '',
                      whetherOwnerIdProofAvailable: ownerIdProof != null,
                      ownerIdProofDocumentId: ownerIdProof?.documentId ?? '',
                      whetherOwnerPropertyOwnershipProofAvailable:
                          ownerPropertyProof != null,
                      ownerPropertyOwnershipProofDocumentId:
                          ownerPropertyProof?.documentId ?? '',
                      whetherOwnerBankProofAvailable: ownerBankProof != null,
                      ownerBankProofDocumentId:
                          ownerBankProof?.documentId ?? '',
                    );
                if (!context.mounted) {
                  return;
                }
                if (!response.success) {
                  throw Exception(
                    response.message ??
                        response.status ??
                        'Unable to update documents.',
                  );
                }
                Navigator.of(context).pop();
                _showMessage('KYC documents updated.');
                await _loadContracts();
              } catch (error) {
                _showMessage(error.toString().replaceFirst('Exception: ', ''));
                setModalState(() => isSaving = false);
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    Text(
                      'KYC Documents',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contract.tenantName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _KycDocRow(
                      label: 'Tenant ID Proof',
                      doc: tenantIdProof,
                      isUploading: isUploadingDoc,
                      onUpload: () => uploadDoc(
                        label: 'Tenant ID Proof',
                        onDone: (ContractDocumentRecord? doc) =>
                            setModalState(() => tenantIdProof = doc),
                      ),
                      onRemove: () => setModalState(() => tenantIdProof = null),
                    ),
                    const SizedBox(height: 8),
                    _KycDocRow(
                      label: 'Tenant Address Proof',
                      doc: tenantAddressProof,
                      isUploading: isUploadingDoc,
                      onUpload: () => uploadDoc(
                        label: 'Tenant Address Proof',
                        onDone: (ContractDocumentRecord? doc) =>
                            setModalState(() => tenantAddressProof = doc),
                      ),
                      onRemove: () =>
                          setModalState(() => tenantAddressProof = null),
                    ),
                    const SizedBox(height: 8),
                    _KycDocRow(
                      label: 'Owner ID Proof',
                      doc: ownerIdProof,
                      isUploading: isUploadingDoc,
                      onUpload: () => uploadDoc(
                        label: 'Owner ID Proof',
                        onDone: (ContractDocumentRecord? doc) =>
                            setModalState(() => ownerIdProof = doc),
                      ),
                      onRemove: () => setModalState(() => ownerIdProof = null),
                    ),
                    const SizedBox(height: 8),
                    _KycDocRow(
                      label: 'Owner Property Ownership Proof',
                      doc: ownerPropertyProof,
                      isUploading: isUploadingDoc,
                      onUpload: () => uploadDoc(
                        label: 'Owner Property Proof',
                        onDone: (ContractDocumentRecord? doc) =>
                            setModalState(() => ownerPropertyProof = doc),
                      ),
                      onRemove: () =>
                          setModalState(() => ownerPropertyProof = null),
                    ),
                    const SizedBox(height: 8),
                    _KycDocRow(
                      label: 'Owner Bank Proof',
                      doc: ownerBankProof,
                      isUploading: isUploadingDoc,
                      onUpload: () => uploadDoc(
                        label: 'Owner Bank Proof',
                        onDone: (ContractDocumentRecord? doc) =>
                            setModalState(() => ownerBankProof = doc),
                      ),
                      onRemove: () =>
                          setModalState(() => ownerBankProof = null),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: CustomButton(
                            label: 'Close',
                            variant: CustomButtonVariant.outline,
                            onPressed: isSaving
                                ? null
                                : () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomButton(
                            label: 'Save',
                            isLoading: isSaving,
                            onPressed: isSaving || isUploadingDoc ? null : save,
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

  Future<void> _openPurchaseResidentContractsSheet() async {
    if (_properties.isEmpty) {
      _showMessage(
        'Create a property first before purchasing resident contracts.',
      );
      return;
    }

    String propertyId = _propertyFilterId.isNotEmpty
        ? _propertyFilterId
        : _properties.first.id;
    final TextEditingController contractsController = TextEditingController(
      text: '1',
    );
    ResidentContractsCalculationData? calculation;
    String? errorMessage;
    bool calculating = false;
    bool purchasing = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            PropertyRecord selectedProperty = _properties.firstWhere(
              (PropertyRecord property) => property.id == propertyId,
              orElse: () => _properties.first,
            );

            int parseCount() {
              return int.tryParse(contractsController.text.trim()) ?? 0;
            }

            void syncCount(int nextValue) {
              final int safeValue = nextValue < 1 ? 1 : nextValue;
              final String text = '$safeValue';
              contractsController.value = TextEditingValue(
                text: text,
                selection: TextSelection.collapsed(offset: text.length),
              );
              setModalState(() {
                calculation = null;
                errorMessage = null;
              });
            }

            Future<void> calculate() async {
              final int count = parseCount();
              if (count < 1) {
                setModalState(() {
                  errorMessage =
                      'Enter at least one resident contract to continue.';
                });
                return;
              }

              setModalState(() {
                calculating = true;
                errorMessage = null;
              });

              try {
                final ResidentContractsCalculationData result =
                    await RentalContractService.calculateResidentContracts(
                      propertyId: propertyId,
                      numberOfContracts: count,
                    );
                if (!context.mounted) {
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
              setModalState(() {
                purchasing = true;
                errorMessage = null;
              });

              try {
                final ResidentContractsPurchaseData response =
                    await RentalContractService.purchaseResidentContracts(
                      propertyId: propertyId,
                      numberOfContracts: count,
                    );

                if (response.isFreePurchase || response.amount <= 0) {
                  if (!context.mounted) {
                    return;
                  }
                  Navigator.of(context).pop();
                  _showMessage('Resident contract slots added successfully.');
                  await _loadContracts();
                  return;
                }

                final VendorData? vendor =
                    await VendorService.fetchVendorInfo();
                final RazorpayCheckoutResult
                checkoutResult = await RazorpayCheckoutService.openCheckout(
                  keyId: response.razorpayKeyId ?? '',
                  amountInPaise: (response.amount * 100).round(),
                  name: 'Urban Easy Flats',
                  description:
                      'Purchase $count resident contract${count == 1 ? '' : 's'}',
                  orderId: response.razorpayOrderId ?? '',
                  currency: response.currency,
                  prefillName: vendor?.fullName,
                  prefillEmail: vendor?.email,
                  prefillContact: vendor?.phone,
                );

                if (!checkoutResult.success) {
                  throw Exception(
                    checkoutResult.message ??
                        'Resident contract payment was not completed.',
                  );
                }

                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pop();
                _showMessage(
                  'Payment completed. Resident contract slots are being processed.',
                );
                await _loadContracts();
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
                      'Purchase Resident Contracts',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add more rental-contract creation slots for a property, using the same calculation and purchase endpoints as the website.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: propertyId,
                      decoration: const InputDecoration(labelText: 'Property'),
                      isExpanded: true,
                      itemHeight: null,
                      menuMaxHeight: MediaQuery.of(context).size.height * 0.65,
                      selectedItemBuilder: (BuildContext context) {
                        return _properties
                            .map(
                              (PropertyRecord property) =>
                                  _propertyDropdownSelectedItem(
                                    context,
                                    property,
                                  ),
                            )
                            .toList();
                      },
                      items: _properties.map((PropertyRecord property) {
                        return DropdownMenuItem<String>(
                          value: property.id,
                          child: _propertyDropdownMenuItem(context, property),
                        );
                      }).toList(),
                      onChanged: purchasing || calculating
                          ? null
                          : (String? value) {
                              if (value == null || value.isEmpty) {
                                return;
                              }
                              setModalState(() {
                                propertyId = value;
                                calculation = null;
                                errorMessage = null;
                              });
                            },
                    ),
                    const SizedBox(height: 12),
                    CustomCard(
                      padding: CustomCardPadding.sm,
                      color: AppTheme.primarySoft,
                      borderColor: AppTheme.primaryTone,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            selectedProperty.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if ((selectedProperty.address ?? '')
                              .isNotEmpty) ...<Widget>[
                            const SizedBox(height: 6),
                            Text(
                              selectedProperty.address!,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppTheme.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Contracts to Purchase',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        IconButton(
                          onPressed: purchasing || calculating
                              ? null
                              : () => syncCount(parseCount() - 1),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Expanded(
                          child: TextField(
                            controller: contractsController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            onChanged: (_) {
                              setModalState(() {
                                calculation = null;
                                errorMessage = null;
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'Count',
                              hintText: '1',
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: purchasing || calculating
                              ? null
                              : () => syncCount(parseCount() + 1),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    if (errorMessage != null) ...<Widget>[
                      const SizedBox(height: 12),
                      CustomCard(
                        padding: CustomCardPadding.sm,
                        color: const Color(0xFFFEF2F2),
                        borderColor: const Color(0xFFFECACA),
                        child: Text(
                          errorMessage!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xFFB91C1C)),
                        ),
                      ),
                    ],
                    if (calculation != null) ...<Widget>[
                      const SizedBox(height: 12),
                      CustomCard(
                        padding: CustomCardPadding.sm,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Purchase Summary',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            _PurchaseSummaryRow(
                              label: 'Amount per contract',
                              value:
                                  'Rs ${calculation!.amountPerContract.toStringAsFixed(0)}',
                            ),
                            _PurchaseSummaryRow(
                              label: 'Contracts',
                              value: '${calculation!.numberOfContracts}',
                            ),
                            _PurchaseSummaryRow(
                              label: 'Subtotal',
                              value:
                                  'Rs ${calculation!.subtotal.toStringAsFixed(0)}',
                            ),
                            _PurchaseSummaryRow(
                              label:
                                  'GST (${calculation!.gstPercentage.toStringAsFixed(0)}%)',
                              value:
                                  'Rs ${calculation!.gstAmount.toStringAsFixed(0)}',
                            ),
                            const Divider(height: 24),
                            _PurchaseSummaryRow(
                              label: 'Total',
                              value:
                                  'Rs ${calculation!.totalAmount.toStringAsFixed(0)}',
                              emphasize: true,
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
                            label: 'Calculate',
                            variant: CustomButtonVariant.outline,
                            isLoading: calculating,
                            onPressed: purchasing ? null : calculate,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CustomButton(
                            label: calculation == null
                                ? 'Review & Pay'
                                : 'Proceed',
                            isLoading: purchasing,
                            onPressed: calculating ? null : purchase,
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

    contractsController.dispose();
  }

  Future<void> _markReadyToVacate(RentalContractRecord contract) async {
    final bool? confirmed = await _confirmAction(
      title: 'Mark Ready to Vacate',
      message:
          'This will set the vacate date to 30 days from today for "${contract.tenantName}". Continue?',
      confirmLabel: 'Confirm',
    );
    if (confirmed != true) return;
    try {
      await RentalContractService.markReadyToVacate(
        contract.id,
        _formatDate(DateTime.now().add(const Duration(days: 30))),
      );
      _showMessage('Ready-to-vacate status updated.');
      await _loadContracts();
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _closeContract(RentalContractRecord contract) async {
    final bool? confirmed = await _confirmAction(
      title: 'Close Contract',
      message:
          'Closing this contract for "${contract.tenantName}" is permanent. Are you sure?',
      confirmLabel: 'Close Contract',
    );
    if (confirmed != true) return;
    try {
      await RentalContractService.closeContract(contract.id);
      _showMessage('Contract closed.');
      await _loadContracts();
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _toggleContract(RentalContractRecord contract) async {
    final bool isDeactivating = contract.isActive;
    if (isDeactivating) {
      final bool? confirmed = await _confirmAction(
        title: 'Deactivate Contract',
        message:
            'Deactivating this contract will suspend billing for "${contract.tenantName}". Continue?',
        confirmLabel: 'Deactivate',
      );
      if (confirmed != true) return;
    }
    try {
      if (isDeactivating) {
        await RentalContractService.inactivateContract(contract.id);
      } else {
        await RentalContractService.activateContract(contract.id);
      }
      _showMessage(
        isDeactivating ? 'Contract deactivated.' : 'Contract activated.',
      );
      await _loadContracts();
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

  Future<void> _shareContractPdf(RentalContractRecord contract) async {
    try {
      await RentalContractPdfService.shareContractPdf(contract);
    } catch (_) {
      _showMessage('Unable to generate the rental contract PDF.');
    }
  }

  Future<bool?> _askBillPaidStatus() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Bill Payment Status'),
        content: const Text('Has this bill already been paid?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Future<void> _openBillActionsSheet(RentalContractRecord contract) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        bool loadingSecurity = false;
        bool loadingFirstMonth = false;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            Future<void> createSecurityBill() async {
              final bool? isPaid = await _askBillPaidStatus();
              if (isPaid == null) return;
              setModalState(() {
                loadingSecurity = true;
              });
              try {
                final response =
                    await RentalContractService.createSecurityDepositBill(
                      contract.id,
                      isPaid: isPaid,
                    );
                if (!response.success) {
                  throw Exception(
                    response.message ??
                        response.status ??
                        'Unable to generate the security deposit bill.',
                  );
                }
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pop();
                _showMessage('Security deposit bill generated successfully.');
              } catch (error) {
                _showMessage(error.toString().replaceFirst('Exception: ', ''));
                setModalState(() {
                  loadingSecurity = false;
                });
              }
            }

            Future<void> createFirstMonthBill() async {
              final bool? isPaid = await _askBillPaidStatus();
              if (isPaid == null) return;
              setModalState(() {
                loadingFirstMonth = true;
              });
              try {
                final response =
                    await RentalContractService.createFirstMonthBill(
                      contract.id,
                      isPaid: isPaid,
                    );
                if (!response.success) {
                  throw Exception(
                    response.message ??
                        response.status ??
                        'Unable to generate the first month bill.',
                  );
                }
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pop();
                _showMessage('First month bill generated successfully.');
              } catch (error) {
                _showMessage(error.toString().replaceFirst('Exception: ', ''));
                setModalState(() {
                  loadingFirstMonth = false;
                });
              }
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Bill Actions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Generate contract-linked bills for ${contract.propertyTitle}.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CustomButton(
                      label: 'Generate Security Deposit Bill',
                      isLoading: loadingSecurity,
                      onPressed: loadingSecurity ? null : createSecurityBill,
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      label: 'Generate First Month Bill',
                      variant: CustomButtonVariant.outline,
                      isLoading: loadingFirstMonth,
                      onPressed: loadingFirstMonth
                          ? null
                          : createFirstMonthBill,
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

  Future<void> _openWhatsAppSheet(RentalContractRecord contract) async {
    List<WhatsAppTemplateData> templates = <WhatsAppTemplateData>[];
    String? errorMessage;

    try {
      templates = await RentalContractService.filterWhatsAppTemplates();
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            Future<void> sendTemplate(WhatsAppTemplateData template) async {
              setModalState(() {
                errorMessage = null;
              });
              try {
                final response =
                    await RentalContractService.sendWhatsAppTemplate(
                      contractId: contract.id,
                      templateId: template.templateId,
                    );
                if (!response.success) {
                  throw Exception(
                    response.message ??
                        response.status ??
                        'Unable to send the WhatsApp template.',
                  );
                }
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pop();
                _showMessage(
                  response.message ??
                      response.status ??
                      'WhatsApp message sent successfully.',
                );
              } catch (error) {
                setModalState(() {
                  errorMessage = error.toString().replaceFirst(
                    'Exception: ',
                    '',
                  );
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
                      'Send WhatsApp Message',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Choose a WhatsApp template for ${contract.tenantName}.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (errorMessage != null) ...<Widget>[
                      const SizedBox(height: 16),
                      CustomCard(
                        child: Text(
                          errorMessage!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppTheme.toneColor(UiTone.danger),
                              ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (templates.isEmpty)
                      const CustomCard(
                        child: Text('No WhatsApp templates are available yet.'),
                      )
                    else
                      ...templates.map((WhatsAppTemplateData template) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: CustomCard(
                            padding: CustomCardPadding.sm,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  template.templateName,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  template.templateDescription.isEmpty
                                      ? template.templateCode
                                      : template.templateDescription,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: AppTheme.textSecondary),
                                ),
                                if (template
                                    .templateVariables
                                    .isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: template.templateVariables
                                        .map(
                                          (String variable) => ToneBadge(
                                            label: variable,
                                            tone: UiTone.neutral,
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: CustomButton(
                                    label: 'Send Template',
                                    onPressed: () => sendTemplate(template),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDetails(RentalContractRecord contract) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ContractDetailPage(
          contract: contract,
          onSharePdf: () => _shareContractPdf(contract),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String normalizedSearch = _searchTerm.trim().toLowerCase();
    final List<RentalContractRecord> visibleContracts = _contracts.where((
      RentalContractRecord item,
    ) {
      if (normalizedSearch.isEmpty) {
        return true;
      }

      final String haystack = <String>[
        item.propertyTitle,
        item.tenantName,
        item.ownerName,
        item.flatNo ?? '',
        item.tenantPhone ?? '',
        item.ownerPhone ?? '',
      ].join(' ').toLowerCase();

      return haystack.contains(normalizedSearch);
    }).toList();

    final int activeCount = visibleContracts
        .where(
          (RentalContractRecord item) =>
              item.isActive && item.status == ContractStatus.active,
        )
        .length;
    final int expiredCount = visibleContracts
        .where(
          (RentalContractRecord item) =>
              item.isActive && item.status == ContractStatus.expired,
        )
        .length;
    final int closedCount = visibleContracts
        .where(
          (RentalContractRecord item) => item.status == ContractStatus.closed,
        )
        .length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Text('Rental Contracts'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.border),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openContractSheet,
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('Add Contract'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadContracts,
        child: ListView(
          padding: AppTheme.pagePadding,
          children: <Widget>[
            const PageHeader(
              title: 'Rental Contracts',
              description:
                  'Contract list, property filtering, resident-contract purchase, create/edit flow, billing helpers, PDF generation, and WhatsApp actions backed by the property rental APIs.',
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _ContractMetricCard(
                    label: 'Active',
                    value: '$activeCount',
                    tone: UiTone.success,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ContractMetricCard(
                    label: 'Expired',
                    value: '$expiredCount',
                    tone: UiTone.warning,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ContractMetricCard(
                    label: 'Closed',
                    value: '$closedCount',
                    tone: UiTone.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomCard(
              padding: CustomCardPadding.sm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Filters',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: (String value) {
                      setState(() {
                        _searchTerm = value;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Search contracts',
                      hintText: 'Property, tenant, owner, or unit',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _propertyFilterId,
                    decoration: const InputDecoration(
                      labelText: 'Property filter',
                    ),
                    isExpanded: true,
                    items: <DropdownMenuItem<String>>[
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('All properties'),
                      ),
                      ..._properties.map((PropertyRecord property) {
                        return DropdownMenuItem<String>(
                          value: property.id,
                          child: Text(
                            _propertyDisplayLabel(property),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (String? value) {
                      setState(() {
                        _propertyFilterId = value ?? '';
                      });
                      _loadContracts();
                    },
                  ),
                  if (_propertyFilterId.isNotEmpty ||
                      _searchTerm.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: CustomButton(
                          label: 'Clear Filters',
                          variant: CustomButtonVariant.ghost,
                          onPressed: () {
                            setState(() {
                              _propertyFilterId = '';
                              _searchTerm = '';
                            });
                            _searchController.clear();
                            _loadContracts();
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CustomCard(
              padding: CustomCardPadding.sm,
              color: AppTheme.primarySoft,
              borderColor: AppTheme.primaryTone,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Need more contract slots?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This matches the website purchase flow for additional resident contracts on a property.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      label: 'Purchase Resident Contracts',
                      icon: const Icon(Icons.shopping_cart_checkout_outlined),
                      onPressed: _isLoading || _properties.isEmpty
                          ? null
                          : _openPurchaseResidentContractsSheet,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CustomTabBar(
              style: CustomTabBarStyle.pill,
              currentIndex: _statusFilter == null
                  ? 0
                  : ContractStatus.values.indexOf(_statusFilter!) + 1,
              onChanged: (int index) {
                setState(() {
                  _statusFilter = index == 0
                      ? null
                      : ContractStatus.values[index - 1];
                });
                _loadContracts();
              },
              tabs: <CustomTabItem>[
                const CustomTabItem(label: 'All'),
                ...ContractStatus.values.map(
                  (ContractStatus status) => CustomTabItem(label: status.label),
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
              _ContractErrorCard(
                message: _errorMessage!,
                onRetry: _loadContracts,
              )
            else if (visibleContracts.isEmpty)
              const CustomCard(
                child: Text(
                  'No rental contracts match the current filters or search.',
                ),
              )
            else
              ...visibleContracts.map((RentalContractRecord contract) {
                final int daysLeft = contract.endDate
                    .difference(DateTime.now())
                    .inDays;
                final bool isClosed = contract.status == ContractStatus.closed;

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
                                    contract.propertyTitle.isNotEmpty
                                        ? contract.propertyTitle
                                        : 'Untitled Property',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${contract.tenantName} | ${contract.flatNo ?? 'Unit'}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                  ),
                                  if ((contract.tenantPhone ?? '')
                                      .isNotEmpty) ...<Widget>[
                                    const SizedBox(height: 2),
                                    Text(
                                      contract.tenantPhone!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppTheme.textSecondary,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                ToneBadge(
                                  label: _contractStatusLabel(contract),
                                  tone: _contractStatusTone(contract),
                                ),
                                if (contract.isActive &&
                                    contract.status == ContractStatus.active &&
                                    daysLeft > 0 &&
                                    daysLeft <= 30) ...<Widget>[
                                  const SizedBox(height: 4),
                                  ToneBadge(
                                    label: '$daysLeft days left',
                                    tone: UiTone.warning,
                                    size: ToneBadgeSize.small,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            ToneBadge(
                              label:
                                  'Rent Rs ${contract.rent.toStringAsFixed(0)}',
                              tone: UiTone.neutral,
                            ),
                            ToneBadge(
                              label:
                                  'Deposit Rs ${contract.deposit.toStringAsFixed(0)}',
                              tone: UiTone.neutral,
                            ),
                            ToneBadge(
                              label:
                                  '${formatCompactDate(contract.startDate)} to ${formatCompactDate(contract.endDate)}',
                              tone: UiTone.brand,
                            ),
                          ],
                        ),
                        if (contract.vacateDate != null) ...<Widget>[
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 16,
                                color: Color(0xFFEA580C),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Vacating ${formatCompactDate(contract.vacateDate!)}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: const Color(0xFFEA580C),
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: CustomButton(
                                label: 'Details',
                                variant: CustomButtonVariant.outline,
                                onPressed: () => _showDetails(contract),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CustomButton(
                                label: 'PDF',
                                variant: CustomButtonVariant.outline,
                                onPressed: () => _shareContractPdf(contract),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: CustomButton(
                                label: 'WhatsApp',
                                variant: CustomButtonVariant.outline,
                                onPressed: () => _openWhatsAppSheet(contract),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CustomButton(
                                label: 'Bill Actions',
                                variant: CustomButtonVariant.outline,
                                onPressed: () =>
                                    _openBillActionsSheet(contract),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: CustomButton(
                                label: 'Edit',
                                variant: CustomButtonVariant.outline,
                                onPressed: isClosed
                                    ? null
                                    : () => _openContractSheet(
                                        contract: contract,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CustomButton(
                                label:
                                    contract.status ==
                                        ContractStatus.readyToVacate
                                    ? 'Close'
                                    : 'Vacate',
                                onPressed: () {
                                  if (contract.status ==
                                      ContractStatus.readyToVacate) {
                                    _closeContract(contract);
                                  } else {
                                    _markReadyToVacate(contract);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: CustomButton(
                            label: 'KYC Docs',
                            variant: CustomButtonVariant.outline,
                            onPressed: () => _openKycUpdateSheet(contract),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: CustomButton(
                            label: contract.isActive
                                ? 'Deactivate'
                                : 'Activate',
                            variant: contract.isActive
                                ? CustomButtonVariant.danger
                                : CustomButtonVariant.primary,
                            onPressed: () => _toggleContract(contract),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  String? _propertyIdForContract(RentalContractRecord? contract) {
    if (contract == null) {
      if (_propertyFilterId.isNotEmpty) {
        return _propertyFilterId;
      }
      return _properties.isEmpty ? null : _properties.first.id;
    }

    if ((contract.propertyId ?? '').isNotEmpty) {
      return contract.propertyId;
    }

    for (final PropertyRecord property in _properties) {
      if (property.title == contract.propertyTitle) {
        return property.id;
      }
    }
    return _properties.isEmpty ? null : _properties.first.id;
  }

  String _formatDate(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ContractDetailPage extends StatelessWidget {
  const _ContractDetailPage({required this.contract, required this.onSharePdf});

  final RentalContractRecord contract;
  final VoidCallback onSharePdf;

  @override
  Widget build(BuildContext context) {
    final int daysUntilExpiry = contract.endDate
        .difference(DateTime.now())
        .inDays;
    final bool showExpiry =
        contract.isActive &&
        contract.status == ContractStatus.active &&
        daysUntilExpiry > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(contract.propertyTitle, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Download PDF',
            onPressed: onSharePdf,
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // Header — status + contract ID
          Row(
            children: <Widget>[
              ToneBadge(
                label: _contractStatusLabel(contract),
                tone: _contractStatusTone(contract),
              ),
              if (showExpiry) ...<Widget>[
                const SizedBox(width: 8),
                ToneBadge(
                  label: '$daysUntilExpiry days left',
                  tone: daysUntilExpiry <= 30 ? UiTone.warning : UiTone.neutral,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Property Details — grey
          _DetailSection(
            title: 'Property Details',
            color: const Color(0xFFF3F4F6),
            children: <Widget>[
              _DetailRow(
                label: 'Property',
                value: contract.propertyTitle.isNotEmpty
                    ? contract.propertyTitle
                    : 'N/A',
              ),
              _DetailRow(label: 'Flat / Unit', value: contract.flatNo ?? 'N/A'),
            ],
          ),
          const SizedBox(height: 12),

          // Tenant Information — blue
          _DetailSection(
            title: 'Tenant Information',
            color: const Color(0xFFEFF6FF),
            children: <Widget>[
              _DetailRow(label: 'Name', value: contract.tenantName),
              _DetailRow(label: 'Phone', value: contract.tenantPhone ?? 'N/A'),
              _DetailRow(label: 'Email', value: contract.tenantEmail ?? 'N/A'),
            ],
          ),
          const SizedBox(height: 12),

          // Owner Information — green
          _DetailSection(
            title: 'Owner Information',
            color: const Color(0xFFF0FDF4),
            children: <Widget>[
              _DetailRow(label: 'Name', value: contract.ownerName),
              _DetailRow(label: 'Phone', value: contract.ownerPhone ?? 'N/A'),
              _DetailRow(label: 'Email', value: contract.ownerEmail ?? 'N/A'),
              _DetailRow(
                label: 'Address',
                value: contract.ownerAddress ?? 'N/A',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Financial Details — amber
          _DetailSection(
            title: 'Financial Details',
            color: const Color(0xFFFFFBEB),
            children: <Widget>[
              _DetailRow(
                label: 'Monthly Rent',
                value: 'Rs ${contract.rent.toStringAsFixed(0)}',
              ),
              _DetailRow(
                label: 'Security Deposit',
                value: 'Rs ${contract.deposit.toStringAsFixed(0)}',
              ),
              _DetailRow(
                label: 'Maintenance',
                value: (contract.whetherMaintenanceIncluded ?? false)
                    ? 'Rs ${(contract.maintenanceAmount ?? 0).toStringAsFixed(0)}'
                    : 'Not Included',
              ),
              if (contract.billDay != null)
                _DetailRow(label: 'Bill Day', value: '${contract.billDay}'),
            ],
          ),
          const SizedBox(height: 12),

          // Contract Terms — purple
          _DetailSection(
            title: 'Contract Terms',
            color: const Color(0xFFF5F3FF),
            children: <Widget>[
              _DetailRow(
                label: 'Start Date',
                value: formatCompactDate(contract.startDate),
              ),
              _DetailRow(
                label: 'End Date',
                value: formatCompactDate(contract.endDate),
              ),
              if (showExpiry)
                _DetailRow(
                  label: 'Days Until Expiry',
                  value: '$daysUntilExpiry',
                ),
              if ((contract.specialTerms ?? '').isNotEmpty)
                _DetailRow(
                  label: 'Special Terms',
                  value: contract.specialTerms!,
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Payment Status — grey
          _DetailSection(
            title: 'Payment Status',
            color: const Color(0xFFF3F4F6),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'First Month Rent',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    ToneBadge(
                      label: (contract.whetherFirstMonthRentPaid ?? false)
                          ? 'Paid'
                          : 'Pending',
                      tone: (contract.whetherFirstMonthRentPaid ?? false)
                          ? UiTone.success
                          : UiTone.warning,
                      size: ToneBadgeSize.small,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'Security Deposit',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    ToneBadge(
                      label: (contract.whetherSecurityDepositPaid ?? false)
                          ? 'Paid'
                          : 'Pending',
                      tone: (contract.whetherSecurityDepositPaid ?? false)
                          ? UiTone.success
                          : UiTone.warning,
                      size: ToneBadgeSize.small,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Vacate Notice — orange (conditional)
          if (contract.vacateDate != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(color: const Color(0xFFFDBA74)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFEA580C),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tenant is ready to vacate on ${formatCompactDate(contract.vacateDate!)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFEA580C),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // KYC Documents
          const SizedBox(height: 12),
          _DetailSection(
            title: 'KYC Documents',
            color: Colors.white,
            children: <Widget>[
              Text(
                'Tenant Documents',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _KycStatusRow(label: 'ID Proof', doc: contract.tenantIdProof),
              _KycStatusRow(
                label: 'Address Proof',
                doc: contract.tenantAddressProof,
              ),
              const SizedBox(height: 12),
              Text(
                'Owner Documents',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _KycStatusRow(label: 'ID Proof', doc: contract.ownerIdProof),
              _KycStatusRow(
                label: 'Property Ownership Proof',
                doc: contract.ownerPropertyOwnershipProof,
              ),
              _KycStatusRow(label: 'Bank Proof', doc: contract.ownerBankProof),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.color,
    required this.children,
  });

  final String title;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _KycStatusRow extends StatelessWidget {
  const _KycStatusRow({required this.label, this.doc});

  final String label;
  final ContractDocumentRecord? doc;

  @override
  Widget build(BuildContext context) {
    final bool uploaded = doc != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Icon(
            uploaded ? Icons.check_circle : Icons.cancel_outlined,
            size: 16,
            color: uploaded ? const Color(0xFF16A34A) : AppTheme.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          if (uploaded)
            Text(
              'Uploaded',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF16A34A),
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Text(
              'Not uploaded',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
            ),
        ],
      ),
    );
  }
}

class _PurchaseSummaryRow extends StatelessWidget {
  const _PurchaseSummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final TextStyle baseStyle =
        Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
          color: emphasize ? AppTheme.textPrimary : AppTheme.textSecondary,
        ) ??
        TextStyle(
          fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
          color: emphasize ? AppTheme.textPrimary : AppTheme.textSecondary,
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: baseStyle)),
          const SizedBox(width: 12),
          Text(value, style: baseStyle.copyWith(color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value),
      ),
    );
  }
}

class _ContractMetricCard extends StatelessWidget {
  const _ContractMetricCard({
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

class _KycDocRow extends StatelessWidget {
  const _KycDocRow({
    required this.label,
    required this.doc,
    required this.isUploading,
    required this.onUpload,
    required this.onRemove,
  });

  final String label;
  final ContractDocumentRecord? doc;
  final bool isUploading;
  final VoidCallback onUpload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              if (doc != null)
                Text(
                  doc!.documentName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF16A34A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (doc != null)
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: isUploading ? null : onRemove,
            tooltip: 'Remove',
          )
        else
          TextButton.icon(
            onPressed: isUploading ? null : onUpload,
            icon: isUploading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_outlined, size: 18),
            label: const Text('Upload'),
          ),
      ],
    );
  }
}

class _ContractErrorCard extends StatelessWidget {
  const _ContractErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Unable to load rental contracts',
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
