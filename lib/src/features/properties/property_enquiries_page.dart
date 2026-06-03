import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/property_service.dart';
import '../../core/models/api_models.dart';
import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/contact_launcher.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_card.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/tone_badge.dart';

const Map<int, String> _propertyOptionFlatTypeLabels = <int, String>{
  1: '1 BHK',
  2: '2 BHK',
  3: '3 BHK',
  4: '4 BHK',
  5: 'Studio',
  6: 'Duplex',
  7: 'Penthouse',
  8: 'Villa',
};

const Map<int, Map<int, String>> _propertyOptionSubtypeLabels =
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

class PropertyEnquiriesPage extends StatefulWidget {
  const PropertyEnquiriesPage({
    super.key,
    this.initialPropertyId,
    this.onEnquiryStatusChanged,
  });

  final String? initialPropertyId;
  final Future<void> Function()? onEnquiryStatusChanged;

  @override
  State<PropertyEnquiriesPage> createState() => _PropertyEnquiriesPageState();
}

class _PropertyEnquiriesPageState extends State<PropertyEnquiriesPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  bool _isLoadingProperties = true;
  bool _isLoadingEnquiries = false;
  String? _errorMessage;

  String? _selectedPropertyId;
  List<_PropertyOption> _properties = <_PropertyOption>[];

  List<PropertyEnquiryData> _enquiries = <PropertyEnquiryData>[];
  int _totalCount = 0;
  int _newCount = 0;
  int _resolvedCount = 0;

  // Filters
  int? _statusFilter = 1; // null=All, 1=New, 2=Resolved
  DateTime? _startDate;
  DateTime? _endDate;

  // Pagination
  static const int _pageSize = 20;
  int _skip = 0;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------
  Future<void> _loadProperties() async {
    setState(() {
      _isLoadingProperties = true;
      _errorMessage = null;
    });
    try {
      final result = await PropertyService.filterPropertiesLite(limit: 500);
      if (!mounted) {
        return;
      }
      final List<Map<String, dynamic>> lite = result.properties;
      final List<_PropertyOption> props = lite
          .map(_PropertyOption.fromJson)
          .where((_PropertyOption property) => property.id.isNotEmpty)
          .toList();

      setState(() {
        _properties = props;
        _isLoadingProperties = false;
        if (_selectedPropertyId == null && props.isNotEmpty) {
          // Use initialPropertyId if provided and valid
          if (widget.initialPropertyId != null &&
              props.any((p) => p.id == widget.initialPropertyId)) {
            _selectedPropertyId = widget.initialPropertyId;
          }
        }
      });
      if (props.isNotEmpty) {
        await _loadEnquiries(reset: true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _isLoadingProperties = false;
      });
    }
  }

  Future<void> _loadEnquiries({bool reset = false}) async {
    if (!mounted) {
      return;
    }
    final int skip = reset ? 0 : _skip;
    setState(() {
      _isLoadingEnquiries = true;
      if (reset) {
        _errorMessage = null;
      }
    });

    try {
      final result = await PropertyService.filterPropertyEnquiries(
        _selectedPropertyId,
        skip: skip,
        limit: _pageSize,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        enquiryStatus: _statusFilter,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (!mounted) {
        return;
      }
      final List<PropertyEnquiryData> visibleEnquiries =
          _applyLocalEnquiryFilters(result.enquiries);
      final int calculatedNewCount = result.enquiries
          .where((PropertyEnquiryData enquiry) => enquiry.status == 1)
          .length;
      final int calculatedResolvedCount = result.enquiries
          .where((PropertyEnquiryData enquiry) => enquiry.status == 2)
          .length;
      setState(() {
        if (reset) {
          _enquiries = visibleEnquiries;
        } else {
          _enquiries = <PropertyEnquiryData>[
            ..._enquiries,
            ...visibleEnquiries,
          ];
        }
        _totalCount = result.count;
        _newCount = result.newCount > 0 ? result.newCount : calculatedNewCount;
        _resolvedCount = result.resolvedCount > 0
            ? result.resolvedCount
            : calculatedResolvedCount;
        _skip = skip + result.enquiries.length;
        _hasMore = (_skip) < result.count;
        _isLoadingEnquiries = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _isLoadingEnquiries = false;
      });
    }
  }

  List<PropertyEnquiryData> _applyLocalEnquiryFilters(
    List<PropertyEnquiryData> enquiries,
  ) {
    final String selectedPropertyId = _selectedPropertyId?.trim() ?? '';
    final String search = _searchController.text.trim().toLowerCase();
    final DateTime? start = _startDate == null
        ? null
        : DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
    final DateTime? end = _endDate == null
        ? null
        : DateTime(
            _endDate!.year,
            _endDate!.month,
            _endDate!.day,
            23,
            59,
            59,
          );

    return enquiries.where((PropertyEnquiryData enquiry) {
      if (_statusFilter != null && enquiry.status != _statusFilter) {
        return false;
      }

      final String enquiryPropertyId = (enquiry.propertyId ?? '').trim();
      if (selectedPropertyId.isNotEmpty &&
          enquiryPropertyId.isNotEmpty &&
          enquiryPropertyId != selectedPropertyId) {
        return false;
      }

      if (search.isNotEmpty) {
        final String haystack = <String>[
          enquiry.name,
          enquiry.phone,
          enquiry.email ?? '',
          enquiry.propertyTitle ?? '',
          enquiry.ownerName ?? '',
        ].join(' ').toLowerCase();
        if (!haystack.contains(search)) {
          return false;
        }
      }

      final DateTime? createdAt = enquiry.createdAt;
      if (createdAt != null) {
        if (start != null && createdAt.isBefore(start)) {
          return false;
        }
        if (end != null && createdAt.isAfter(end)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 400),
      () => _loadEnquiries(reset: true),
    );
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _statusFilter = 1;
      _selectedPropertyId = widget.initialPropertyId;
      _startDate = null;
      _endDate = null;
    });
    _loadEnquiries(reset: true);
  }

  bool get _hasActiveFilters =>
      _searchController.text.isNotEmpty ||
      _selectedPropertyId != null ||
      _statusFilter != 1 ||
      _startDate != null ||
      _endDate != null;

  // ---------------------------------------------------------------------------
  // Date picker helpers
  // ---------------------------------------------------------------------------
  Future<void> _pickStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        // Reset end date if it's before start
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
        }
      });
      if (_endDate != null) {
        _loadEnquiries(reset: true);
      }
    }
  }

  Future<void> _pickEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? (_startDate ?? DateTime.now()),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
      if (_startDate != null) {
        _loadEnquiries(reset: true);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  Future<void> _resolveEnquiry(PropertyEnquiryData enquiry) async {
    try {
      await PropertyService.updateEnquiryStatus(enquiry.enquiryId, 2);
      _showMessage('Enquiry marked as resolved.');
      await _loadEnquiries(reset: true);
      await widget.onEnquiryStatusChanged?.call();
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Text('Property Enquiries'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.border),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadEnquiries(reset: true),
        child: ListView(
          padding: AppTheme.pagePadding,
          children: <Widget>[
            const PageHeader(
              title: 'Enquiries',
              description:
                  'Lead queue and follow-up status updates for property listings.',
            ),
            const SizedBox(height: 16),

            // ── Property selector ──────────────────────────────────────────
            if (_isLoadingProperties)
              const Center(child: CircularProgressIndicator())
            else if (_properties.isEmpty)
              const CustomCard(
                child: Text(
                  'Create a property first to start receiving enquiries.',
                ),
              )
            else ...<Widget>[
              DropdownButtonFormField<String?>(
                value: _selectedPropertyId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Property'),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All Properties'),
                  ),
                  ..._properties.map((_PropertyOption p) {
                    return DropdownMenuItem<String?>(
                      value: p.id,
                      child: Text(
                        p.displayLabel,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: (String? value) {
                  setState(() {
                    _selectedPropertyId = value;
                    _enquiries = <PropertyEnquiryData>[];
                    _skip = 0;
                  });
                  _loadEnquiries(reset: true);
                },
              ),
              const SizedBox(height: 12),

              // ── Summary bar ──────────────────────────────────────────────
              if (!_isLoadingEnquiries || _enquiries.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      _SummaryTile(
                        label: 'Total',
                        count: _totalCount,
                        tone: UiTone.brand,
                      ),
                      const SizedBox(width: 12),
                      _SummaryTile(
                        label: 'New',
                        count: _newCount,
                        tone: UiTone.warning,
                      ),
                      const SizedBox(width: 12),
                      _SummaryTile(
                        label: 'Resolved',
                        count: _resolvedCount,
                        tone: UiTone.success,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // ── Search ───────────────────────────────────────────────────
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search',
                  hintText: 'Name, email or phone…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _loadEnquiries(reset: true);
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _loadEnquiries(reset: true),
              ),
              const SizedBox(height: 12),

              // ── Status filter ────────────────────────────────────────────
              DropdownButtonFormField<int?>(
                value: _statusFilter,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const <DropdownMenuItem<int?>>[
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All Status'),
                  ),
                  DropdownMenuItem<int?>(value: 1, child: Text('New')),
                  DropdownMenuItem<int?>(value: 2, child: Text('Resolved')),
                ],
                onChanged: (int? value) {
                  setState(() {
                    _statusFilter = value;
                  });
                  _loadEnquiries(reset: true);
                },
              ),
              const SizedBox(height: 12),

              // ── Date range ───────────────────────────────────────────────
              Row(
                children: <Widget>[
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickStartDate,
                      child: AbsorbPointer(
                        child: TextField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'From',
                            hintText: 'Start date',
                            prefixIcon: const Icon(
                              Icons.calendar_today_outlined,
                            ),
                            suffixIcon: _startDate != null
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: () {
                                      setState(() {
                                        _startDate = null;
                                      });
                                      _loadEnquiries(reset: true);
                                    },
                                  )
                                : null,
                          ),
                          controller: TextEditingController(
                            text: _startDate == null
                                ? ''
                                : _formatDate(_startDate!),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickEndDate,
                      child: AbsorbPointer(
                        child: TextField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'To',
                            hintText: 'End date',
                            prefixIcon: const Icon(
                              Icons.calendar_today_outlined,
                            ),
                            suffixIcon: _endDate != null
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: () {
                                      setState(() {
                                        _endDate = null;
                                      });
                                      _loadEnquiries(reset: true);
                                    },
                                  )
                                : null,
                          ),
                          controller: TextEditingController(
                            text: _endDate == null
                                ? ''
                                : _formatDate(_endDate!),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Clear filters ────────────────────────────────────────────
              if (_hasActiveFilters) ...<Widget>[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                    label: const Text('Clear Filters'),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // ── Error ────────────────────────────────────────────────────
              if (_errorMessage != null && _enquiries.isEmpty)
                CustomCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Unable to load enquiries',
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
                        onPressed: () => _loadEnquiries(reset: true),
                      ),
                    ],
                  ),
                ),

              // ── Loading (initial) ────────────────────────────────────────
              if (_isLoadingEnquiries && _enquiries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),

              // ── Empty ────────────────────────────────────────────────────
              if (!_isLoadingEnquiries &&
                  _errorMessage == null &&
                  _enquiries.isEmpty)
                CustomCard(
                  child: Text(
                    _hasActiveFilters
                        ? 'No unresolved enquiries match the current filters.'
                        : 'No enquiries found.',
                  ),
                ),

              // ── Enquiry cards ────────────────────────────────────────────
              ..._enquiries.map((PropertyEnquiryData enquiry) {
                final bool isNew = enquiry.status == 1;
                final _PropertyOption? property =
                    _propertyFor(enquiry.propertyId) ??
                    _propertyFor(_selectedPropertyId);
                final String propertyTitle = _firstNonEmpty(<String?>[
                  enquiry.propertyTitle,
                  property?.title,
                ]);
                final String ownerName = _firstNonEmpty(<String?>[
                  enquiry.ownerName,
                  property?.ownerName,
                ]);
                final String displayLabel = _firstNonEmpty(<String?>[
                  enquiry.propertyDisplayLabel,
                  _propertyTypeLabel(enquiry.propertyType),
                ]);
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
                                    enquiry.name,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  if (enquiry.createdAt != null) ...<Widget>[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Received: ${_formatDateTime(enquiry.createdAt!)}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: AppTheme.textMuted),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            ToneBadge(
                              label: isNew ? 'New' : 'Resolved',
                              tone: isNew ? UiTone.warning : UiTone.success,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _EnquiryPropertySummary(
                          imageUrl: enquiry.propertyImageUrl,
                          title: propertyTitle.isEmpty
                              ? 'Unknown property'
                              : propertyTitle,
                          subtitle: displayLabel,
                        ),
                        const SizedBox(height: 8),
                        _EnquiryDetailLine(
                          icon: Icons.person_outline_rounded,
                          label: 'Owner',
                          value: ownerName.isEmpty
                              ? 'Not available'
                              : ownerName,
                        ),
                        if ((enquiry.ownerPhone ?? '').isNotEmpty) ...<Widget>[
                          const SizedBox(height: 8),
                          _EnquiryDetailLine(
                            icon: Icons.phone_outlined,
                            label: 'Owner mobile',
                            value: enquiry.ownerPhone!,
                            contactType: _EnquiryContactType.phone,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            if (enquiry.phone.isNotEmpty)
                              ContactTextButton.phone(
                                value: enquiry.phone,
                                label: enquiry.phone,
                              ),
                            if ((enquiry.email ?? '').isNotEmpty)
                              ContactTextButton.email(
                                value: enquiry.email!,
                                label: enquiry.email!,
                              ),
                          ],
                        ),
                        if (isNew) ...<Widget>[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: CustomButton(
                              label: 'Mark Resolved',
                              icon: const Icon(Icons.check_circle_outline),
                              onPressed: () => _resolveEnquiry(enquiry),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),

              // ── Load more ────────────────────────────────────────────────
              if (_hasMore) ...<Widget>[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoadingEnquiries
                        ? null
                        : () => _loadEnquiries(reset: false),
                    icon: _isLoadingEnquiries
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more_rounded),
                    label: Text(
                      'Load More (${_totalCount - _enquiries.length} remaining)',
                    ),
                  ),
                ),
              ] else if (_enquiries.isNotEmpty &&
                  !_isLoadingEnquiries) ...<Widget>[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'All ${_enquiries.length} enquiries loaded',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dt) {
    final DateTime local = dt.toLocal();
    return '${_formatDate(local)} ${formatClock(local)}';
  }

  _PropertyOption? _propertyFor(String? propertyId) {
    if (propertyId == null || propertyId.isEmpty) {
      return null;
    }
    for (final _PropertyOption property in _properties) {
      if (property.id == propertyId) {
        return property;
      }
    }
    return null;
  }

  String _firstNonEmpty(List<String?> values) {
    for (final String? value in values) {
      final String text = value?.trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
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
class _PropertyOption {
  const _PropertyOption({
    required this.id,
    required this.title,
    required this.flatType,
    required this.ownerName,
  });

  factory _PropertyOption.fromJson(Map<String, dynamic> json) {
    final String title = _readString(<dynamic>[
      json['Property_Title'],
      json['Title'],
      json['Name'],
    ]);
    return _PropertyOption(
      id: _readString(<dynamic>[json['PropertyID'], json['_id']]),
      title: title.isEmpty ? 'Untitled' : title,
      flatType: _readFlatType(json),
      ownerName: _readString(<dynamic>[
        json['Owner_Name'],
        json['OwnerName'],
        json['Owner'],
      ]),
    );
  }

  final String id;
  final String title;
  final String flatType;
  final String ownerName;

  String get displayLabel {
    if (flatType.isEmpty) {
      return title;
    }
    return '$title - $flatType';
  }

  static String _readString(List<dynamic> values) {
    for (final dynamic value in values) {
      final String text = '${value ?? ''}'.trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  static String _readFlatType(Map<String, dynamic> json) {
    final String explicit = _readString(<dynamic>[
      json['Flat_Type_Label'],
      json['Property_Sub_Type_Label'],
      json['Sub_Type_Label'],
    ]);
    if (explicit.isNotEmpty) {
      return explicit;
    }

    final int? flatType = _readInt(json['Flat_Type']);
    if (flatType != null) {
      return _propertyOptionFlatTypeLabels[flatType] ?? '';
    }

    final int? propertyType = _readInt(json['Property_Type']);
    final int? subType = _readInt(json['Sub_Type']);
    if (propertyType == null || subType == null) {
      return '';
    }
    return _propertyOptionSubtypeLabels[propertyType]?[subType] ?? '';
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}

String _propertyTypeLabel(int? propertyType) {
  return switch (propertyType) {
    1 => 'Apartment',
    2 => 'Villa',
    3 => 'PG',
    4 => 'Commercial',
    _ => '',
  };
}

class _EnquiryPropertySummary extends StatelessWidget {
  const _EnquiryPropertySummary({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
  });

  final String? imageUrl;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String resolvedImageUrl = (imageUrl ?? '').trim();
    return Row(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 52,
            height: 52,
            child: resolvedImageUrl.isEmpty
                ? Container(
                    color: AppTheme.surfaceMuted,
                    child: const Icon(Icons.home_work_outlined),
                  )
                : Image.network(
                    resolvedImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.surfaceMuted,
                      child: const Icon(Icons.home_work_outlined),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EnquiryDetailLine extends StatelessWidget {
  const _EnquiryDetailLine({
    required this.icon,
    required this.label,
    required this.value,
    this.contactType = _EnquiryContactType.none,
  });

  final IconData icon;
  final String label;
  final String value;
  final _EnquiryContactType contactType;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: AppTheme.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: contactType == _EnquiryContactType.phone
              ? ContactTextButton.phone(value: value, label: '$label: $value')
              : contactType == _EnquiryContactType.email
                  ? ContactTextButton.email(value: value, label: '$label: $value')
                  : RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                        children: <InlineSpan>[
                          TextSpan(
                            text: '$label: ',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: value),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }
}

enum _EnquiryContactType { none, phone, email }

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.count,
    required this.tone,
  });

  final String label;
  final int count;
  final UiTone tone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: CustomCard(
        padding: CustomCardPadding.sm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ToneBadge(label: label, tone: tone, size: ToneBadgeSize.small),
            const SizedBox(height: 10),
            Text(
              '$count',
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
