import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/public_discovery_service.dart';
import '../../core/models/api_models.dart';
import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_card.dart';
import '../../core/widgets/tone_badge.dart';

class PublicDiscoverySection extends StatefulWidget {
  const PublicDiscoverySection({
    super.key,
    this.onOpenAuth,
    this.showIntro = false,
    this.showSearchControls = true,
    this.previewOnly = false,
    this.previewLimit = 4,
  });

  final ValueChanged<AuthSource>? onOpenAuth;
  final bool showIntro;
  final bool showSearchControls;
  final bool previewOnly;
  final int previewLimit;

  @override
  State<PublicDiscoverySection> createState() => PublicDiscoverySectionState();
}

class PublicDiscoverySectionState extends State<PublicDiscoverySection> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  int? _propertyTypeFilter;
  int? _categoryFilter;
  int? _subTypeFilter;
  int? _pgSharingTypeFilter;
  String _cityFilter = 'all';
  String _priceRange = 'all';
  int _page = 1;
  int _totalCount = 0;
  double _latitude = 0;
  double _longitude = 0;

  List<PublicCityData> _cities = <PublicCityData>[];
  List<PropertyData> _properties = <PropertyData>[];

  static const int _pageSize = 15;

  static const Map<int, String> _propertyTypes = <int, String>{
    1: 'Apartment',
    2: 'Villa',
    3: 'PG',
    4: 'Commercial',
  };

  static const Map<int, Map<int, String>> _subTypesByProperty =
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
        3: <int, String>{
          1: 'Mens PG',
          2: 'Womens PG',
          3: 'Coliving',
        },
        4: <int, String>{
          1: 'Office',
          2: 'Retail',
          3: 'Warehouse',
          4: 'Showroom',
        },
      };

  static const Map<int, String> _categoryTypes = <int, String>{
    1: 'Rent',
    2: 'Lease',
  };

  static const Map<int, String> _pgSharingTypes = <int, String>{
    1: 'Single',
    2: 'Double',
    3: 'Triple',
    4: 'Quad',
    5: 'Dorm',
  };

  static const Map<String, String> _priceRanges = <String, String>{
    'all': 'All prices',
    'low': 'Under Rs 15K',
    'mid': 'Rs 15K - Rs 30K',
    'high': 'Above Rs 30K',
  };

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadLocation();
    await reloadAll();
  }

  Future<void> _loadLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (_) {
      // Location is optional for public discovery.
    }
  }

  Future<void> reloadAll() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        PublicDiscoveryService.filterCities(limit: 1000),
        _fetchProperties(),
      ]);

      if (!mounted) {
        return;
      }

      final ({List<PublicCityData> cities, int count}) citiesResult =
          results[0] as ({List<PublicCityData> cities, int count});
      final ({List<PropertyData> properties, int count}) propertiesResult =
          results[1] as ({List<PropertyData> properties, int count});

      setState(() {
        _cities = citiesResult.cities;
        _properties = propertiesResult.properties;
        _totalCount = propertiesResult.count;
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

  Future<void> _loadProperties() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ({List<PropertyData> properties, int count}) result =
          await _fetchProperties();

      if (!mounted) {
        return;
      }

      setState(() {
        _properties = result.properties;
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

  Future<({List<PropertyData> properties, int count})> _fetchProperties() {
    return _fetchAllProperties();
  }

  Future<({List<PropertyData> properties, int count})> _fetchAllProperties()
      async {
    const int serverPageSize = 100;
    final List<PropertyData> allProperties = <PropertyData>[];
    int skip = 0;
    int expectedCount = 0;

    while (true) {
      final ({List<PropertyData> properties, int count}) result =
          await PublicDiscoveryService.filterProperties(
        skip: skip,
        limit: serverPageSize,
        search: _searchController.text,
        propertyType: _propertyTypeFilter,
        categoryType: _categoryFilter,
        subType: _subTypeFilter,
        latitude: _latitude,
        longitude: _longitude,
      );

      if (skip == 0) {
        expectedCount = result.count;
      }

      if (result.properties.isEmpty) {
        break;
      }

      allProperties.addAll(result.properties);
      skip += result.properties.length;

      if (allProperties.length >= expectedCount ||
          result.properties.length < serverPageSize) {
        break;
      }
    }

    final List<PropertyData> filteredProperties =
        _applyClientFilters(allProperties);

    return (
      properties: filteredProperties,
      count: filteredProperties.length,
    );
  }

  List<PropertyData> _applyClientFilters(List<PropertyData> items) {
    return items.where((PropertyData item) {
      if (_cityFilter != 'all' && item.cityId != _cityFilter) {
        return false;
      }
      if (_pgSharingTypeFilter != null && item.pgSharingType != _pgSharingTypeFilter) {
        return false;
      }
      final double rent = item.rent;
      if (_priceRange == 'low' && rent > 15000) {
        return false;
      }
      if (_priceRange == 'mid' && (rent <= 15000 || rent > 30000)) {
        return false;
      }
      if (_priceRange == 'high' && rent <= 30000) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> openFilters() {
    return _openFiltersSheet();
  }

  int get _activeFilterCount {
    int count = 0;
    if (_propertyTypeFilter != null) {
      count += 1;
    }
    if (_subTypeFilter != null) {
      count += 1;
    }
    if (_pgSharingTypeFilter != null) {
      count += 1;
    }
    if (_categoryFilter != null) {
      count += 1;
    }
    if (_cityFilter != 'all') {
      count += 1;
    }
    if (_priceRange != 'all') {
      count += 1;
    }
    return count;
  }

  bool get _hasActiveFilters {
    return _activeFilterCount > 0 || _searchController.text.trim().isNotEmpty;
  }

  String _cityLabel(String cityId) {
    for (final PublicCityData city in _cities) {
      if (city.cityId == cityId) {
        return city.cityName;
      }
    }
    return 'Selected city';
  }

  void _removeSearchTerm() {
    setState(() {
      _searchController.clear();
      _page = 1;
    });
    _loadProperties();
  }

  void _removePropertyType() {
    setState(() {
      _propertyTypeFilter = null;
      _subTypeFilter = null;
      _pgSharingTypeFilter = null;
      _page = 1;
    });
    _loadProperties();
  }

  void _removeSubType() {
    setState(() {
      _subTypeFilter = null;
      _page = 1;
    });
    _loadProperties();
  }

  void _removePgSharing() {
    setState(() {
      _pgSharingTypeFilter = null;
      _page = 1;
    });
    _loadProperties();
  }

  void _removeCategory() {
    setState(() {
      _categoryFilter = null;
      _page = 1;
    });
    _loadProperties();
  }

  void _removeCity() {
    setState(() {
      _cityFilter = 'all';
      _page = 1;
    });
    _loadProperties();
  }

  void _removePriceRange() {
    setState(() {
      _priceRange = 'all';
      _page = 1;
    });
    _loadProperties();
  }

  Future<void> _openMap(PropertyData property) async {
    final double? latitude = property.latitude;
    final double? longitude = property.longitude;
    if (latitude == null || longitude == null) {
      return;
    }

    final Uri uri = Uri.parse('https://www.google.com/maps?q=$latitude,$longitude');
    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      _showMessage('Could not open maps.');
    }
  }

  void _applyFilters() {
    setState(() {
      _page = 1;
    });
    _loadProperties();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _propertyTypeFilter = null;
      _categoryFilter = null;
      _subTypeFilter = null;
      _pgSharingTypeFilter = null;
      _cityFilter = 'all';
      _priceRange = 'all';
      _page = 1;
    });
    _loadProperties();
  }

  String _propertyTypeLabel(int type) {
    return _propertyTypes[type] ?? 'Property';
  }

  String _subTypeLabel(int propertyType, int? subType) {
    if (subType == null) {
      return 'Sub type';
    }
    return _subTypesByProperty[propertyType]?[subType] ?? 'Sub type $subType';
  }

  String _propertyAddress(PropertyData property) {
    return (property.locationAddress ?? property.address ?? '').trim();
  }

  String _compactAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }

  String _furnishedLabel(int type) {
    return switch (type) {
      1 => 'Unfurnished',
      2 => 'Semi-furnished',
      3 => 'Fully Furnished',
      _ => '',
    };
  }

  String _amenityLabel(int amenityId) {
    return switch (amenityId) {
      1 => 'AC',
      2 => 'Parking',
      3 => 'Meals Included',
      4 => '24/7 Security',
      5 => 'Gym',
      6 => 'Television',
      9 => 'WiFi',
      10 => 'Power Backup',
      11 => 'Laundry',
      12 => 'Housekeeping',
      14 => 'Study Room',
      21 => 'Swimming Pool',
      _ => 'Amenity $amenityId',
    };
  }

  // ignore: unused_element
  void _openPropertyDetails(PropertyData property) {
    final List<String> imageUrls = <String>[
      if ((property.imageUrl ?? '').trim().isNotEmpty) property.imageUrl!,
      ...?property.images,
    ].toSet().toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        final ThemeData theme = Theme.of(context);
        final String address = _propertyAddress(property);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  property.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                if (imageUrls.isEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    child: _PropertyImage(
                      imageUrl: property.imageUrl,
                      height: 220,
                    ),
                  )
                else
                  SizedBox(
                    height: 220,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: imageUrls.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (BuildContext context, int index) {
                        return ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMedium),
                          child: SizedBox(
                            width: 280,
                            child: _PropertyImage(
                              imageUrl: imageUrls[index],
                              height: 220,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ToneBadge(
                      label: _propertyTypeLabel(property.propertyType),
                      tone: UiTone.brand,
                    ),
                    if (property.subType != null)
                      ToneBadge(
                        label: _subTypeLabel(
                          property.propertyType,
                          property.subType,
                        ),
                        tone: UiTone.neutral,
                      ),
                    if (property.category != null)
                      ToneBadge(
                        label: property.category == 1 ? 'Rent' : 'Lease',
                        tone: UiTone.brand,
                      ),
                    ToneBadge(
                      label: property.rent > 0
                          ? 'Rent ₹${_compactAmount(property.rent)}/mo'
                          : 'Rent on request',
                      tone: UiTone.success,
                    ),
                    if (property.deposit > 0)
                      ToneBadge(
                        label: 'Deposit ₹${_compactAmount(property.deposit)}',
                        tone: UiTone.neutral,
                      ),
                    if ((property.noOfVacancy ?? 0) > 0)
                      ToneBadge(
                        label: '${property.noOfVacancy} vacancies',
                        tone: UiTone.warning,
                      ),
                    if (property.whetherVerifiedPlus == true)
                      const ToneBadge(
                        label: 'Verified+',
                        tone: UiTone.warning,
                      ),
                  ],
                ),
                if (address.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Text(
                    'Address',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    address,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
                if (property.latitude != null && property.longitude != null) ...<Widget>[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => _openMap(property),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Open in maps'),
                  ),
                ],
                // Property specs
                if ((property.bedrooms != null && property.bedrooms! > 0) ||
                    (property.bathrooms != null && property.bathrooms! > 0) ||
                    (property.area != null && property.area! > 0) ||
                    (property.furnishedType != null &&
                        property.furnishedType! > 0)) ...<Widget>[
                  const SizedBox(height: 16),
                  Text(
                    'Property specs',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: <Widget>[
                      if (property.bedrooms != null && property.bedrooms! > 0)
                        _SpecChip(
                          icon: Icons.bed_outlined,
                          label:
                              '${property.bedrooms} Bedroom${property.bedrooms! > 1 ? 's' : ''}',
                        ),
                      if (property.bathrooms != null &&
                          property.bathrooms! > 0)
                        _SpecChip(
                          icon: Icons.shower_outlined,
                          label:
                              '${property.bathrooms} Bathroom${property.bathrooms! > 1 ? 's' : ''}',
                        ),
                      if (property.area != null && property.area! > 0)
                        _SpecChip(
                          icon: Icons.square_foot_outlined,
                          label:
                              '${property.area!.toStringAsFixed(0)} sq ft',
                        ),
                      if (property.furnishedType != null &&
                          property.furnishedType! > 0)
                        _SpecChip(
                          icon: Icons.chair_outlined,
                          label: _furnishedLabel(property.furnishedType!),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Description',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  property.description.trim().isEmpty
                      ? 'No description was provided for this property.'
                      : property.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (property.propertyType == 3 &&
                    property.pgSharingType != null) ...<Widget>[
                  const SizedBox(height: 16),
                  Text(
                    'PG sharing',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _pgSharingTypes[property.pgSharingType] ??
                        'Shared accommodation',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
                if ((property.amenityIds ?? <int>[]).isNotEmpty) ...<Widget>[
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: property.amenityIds!
                        .take(10)
                        .map(
                          (int amenityId) => ToneBadge(
                            label: _amenityLabel(amenityId),
                            tone: UiTone.neutral,
                            size: ToneBadgeSize.small,
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    label: 'Enquire',
                    icon: const Icon(Icons.message_outlined),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _openEnquirySheet(property);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openPropertyDetailsPage(PropertyData property) {
    final List<String> imageUrls = <String>[
      if ((property.imageUrl ?? '').trim().isNotEmpty) property.imageUrl!,
      ...?property.images,
    ].toSet().toList();

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PublicPropertyDetailsPage(
          property: property,
          imageUrls: imageUrls,
          address: _propertyAddress(property),
          propertyTypeLabel: _propertyTypeLabel(property.propertyType),
          subTypeLabel: property.subType == null
              ? null
              : _subTypeLabel(property.propertyType, property.subType),
          furnishedLabel:
              property.furnishedType != null && property.furnishedType! > 0
                  ? _furnishedLabel(property.furnishedType!)
                  : null,
          pgSharingLabel:
              property.propertyType == 3 && property.pgSharingType != null
                  ? (_pgSharingTypes[property.pgSharingType] ??
                      'Shared accommodation')
                  : null,
          amenityLabels: (property.amenityIds ?? <int>[])
              .take(10)
              .map(_amenityLabel)
              .toList(),
          compactAmountBuilder: _compactAmount,
          onOpenMap: property.latitude != null && property.longitude != null
              ? () => _openMap(property)
              : null,
          onEnquire: () => _openEnquirySheet(property),
        ),
      ),
    );
  }

  Future<void> _openEnquirySheet(PropertyData property) async {
    final String? successMessage = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => _PropertyEnquirySheet(
        property: property,
      ),
    );

    if (!mounted || successMessage == null || successMessage.isEmpty) {
      return;
    }

    await _showEnquirySubmittedDialog(successMessage);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int totalPages = ((_totalCount / _pageSize).ceil()).clamp(1, 99999);
    final List<PropertyData> visibleProperties = widget.previewOnly
        ? _properties.take(widget.previewLimit).toList()
        : _properties
            .skip((_page - 1) * _pageSize)
            .take(_pageSize)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.showIntro) ...<Widget>[
          _buildSectionLead(theme),
          const SizedBox(height: 16),
        ],
        if (widget.showSearchControls) ...<Widget>[
          _buildSearchToolbar(theme),
          if (_hasActiveFilters) ...<Widget>[
            const SizedBox(height: 12),
            _buildActiveFilterChips(theme),
          ],
          const SizedBox(height: 16),
        ],
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_errorMessage != null)
          _buildErrorCard(theme)
        else if (visibleProperties.isEmpty)
          _buildEmptyCard(theme)
        else ...<Widget>[
          if (!widget.previewOnly) ...<Widget>[
            CustomCard(
              child: Text(
                'Showing page $_page of $totalPages. Total results: $_totalCount',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          ...visibleProperties.map(_buildPropertyCard),
          if (!widget.previewOnly)
            Row(
              children: <Widget>[
                Expanded(
                  child: CustomButton(
                    label: 'Previous',
                    variant: CustomButtonVariant.outline,
                    onPressed: _page <= 1
                        ? null
                        : () {
                            setState(() {
                              _page -= 1;
                            });
                          },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CustomButton(
                    label: 'Next',
                    onPressed: _page >= totalPages
                        ? null
                        : () {
                            setState(() {
                              _page += 1;
                            });
                          },
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }

  Widget _buildSectionLead(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFFEFF6FF),
            Colors.white,
            Color(0xFFF0FDFA),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Search public listings',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Use search and filters to find apartments, villas, PG, and commercial spaces without the old banner-style landing clutter.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _LeadTag(label: 'Apartments'),
              _LeadTag(label: 'PG'),
              _LeadTag(label: 'Commercial'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchToolbar(ThemeData theme) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.border),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x12111827),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.search_rounded, color: AppTheme.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _applyFilters(),
                    decoration: const InputDecoration(
                      hintText: 'Search by property name or area',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                Material(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: _applyFilters,
                    borderRadius: BorderRadius.circular(14),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: AppTheme.primaryHover,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openFiltersSheet,
                borderRadius: BorderRadius.circular(18),
                child: Ink(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x12111827),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: AppTheme.primaryHover,
                  ),
                ),
              ),
            ),
            if (_activeFilterCount > 0)
              Positioned(
                right: -2,
                top: -4,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppTheme.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _activeFilterCount.toString(),
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
    );
  }

  Widget _buildActiveFilterChips(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        if (_searchController.text.trim().isNotEmpty)
          _ActiveFilterChip(
            label: 'Search: ${_searchController.text.trim()}',
            onDeleted: _removeSearchTerm,
          ),
        if (_propertyTypeFilter != null)
          _ActiveFilterChip(
            label: _propertyTypeLabel(_propertyTypeFilter!),
            onDeleted: _removePropertyType,
          ),
        if (_subTypeFilter != null && _propertyTypeFilter != null)
          _ActiveFilterChip(
            label: _subTypeLabel(_propertyTypeFilter!, _subTypeFilter),
            onDeleted: _removeSubType,
          ),
        if (_pgSharingTypeFilter != null)
          _ActiveFilterChip(
            label: _pgSharingTypes[_pgSharingTypeFilter] ?? 'PG sharing',
            onDeleted: _removePgSharing,
          ),
        if (_categoryFilter != null)
          _ActiveFilterChip(
            label: _categoryTypes[_categoryFilter] ?? 'Category',
            onDeleted: _removeCategory,
          ),
        if (_cityFilter != 'all')
          _ActiveFilterChip(
            label: _cityLabel(_cityFilter),
            onDeleted: _removeCity,
          ),
        if (_priceRange != 'all')
          _ActiveFilterChip(
            label: _priceRanges[_priceRange] ?? 'Price',
            onDeleted: _removePriceRange,
          ),
        if (_hasActiveFilters)
          ActionChip(
            label: const Text('Clear all'),
            onPressed: _clearFilters,
            backgroundColor: AppTheme.primarySoft,
            labelStyle: theme.textTheme.labelMedium?.copyWith(
              color: AppTheme.primaryHover,
              fontWeight: FontWeight.w700,
            ),
            side: const BorderSide(color: AppTheme.primaryTone),
          ),
      ],
    );
  }

  Future<void> _openFiltersSheet() async {
    int? selectedPropertyType = _propertyTypeFilter;
    int? selectedCategory = _categoryFilter;
    int? selectedSubType = _subTypeFilter;
    int? selectedPgSharingType = _pgSharingTypeFilter;
    String selectedCity = _cityFilter;
    String selectedPriceRange = _priceRange;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bottomSheetContext) {
        return StatefulBuilder(
          builder: (
            BuildContext modalContext,
            void Function(void Function()) setModalState,
          ) {
            final Map<int, String> subtypeOptions =
                _subTypesByProperty[selectedPropertyType] ??
                    const <int, String>{};

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  MediaQuery.of(modalContext).viewInsets.bottom + 24,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Filters',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Refine by property type, category, city, and price.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              selectedPropertyType = null;
                              selectedCategory = null;
                              selectedSubType = null;
                              selectedPgSharingType = null;
                              selectedCity = 'all';
                              selectedPriceRange = 'all';
                            });
                          },
                          child: const Text('Clear all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int?>(
                      value: selectedPropertyType,
                      decoration: const InputDecoration(
                        labelText: 'Property type',
                        prefixIcon: Icon(Icons.home_work_outlined),
                      ),
                      items: <DropdownMenuItem<int?>>[
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All property types'),
                        ),
                        ..._propertyTypes.entries.map(
                          (MapEntry<int, String> entry) => DropdownMenuItem<int?>(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        ),
                      ],
                      onChanged: (int? value) {
                        setModalState(() {
                          selectedPropertyType = value;
                          selectedSubType = null;
                          if (value != 3) {
                            selectedPgSharingType = null;
                          }
                        });
                      },
                    ),
                    if (selectedPropertyType != null) ...<Widget>[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        value: selectedSubType,
                        decoration: const InputDecoration(
                          labelText: 'Sub type',
                          prefixIcon: Icon(Icons.layers_outlined),
                        ),
                        items: <DropdownMenuItem<int?>>[
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All sub types'),
                          ),
                          ...subtypeOptions.entries.map(
                            (MapEntry<int, String> entry) =>
                                DropdownMenuItem<int?>(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          ),
                        ],
                        onChanged: (int? value) {
                          setModalState(() {
                            selectedSubType = value;
                          });
                        },
                      ),
                    ],
                    if (selectedPropertyType == 3) ...<Widget>[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        value: selectedPgSharingType,
                        decoration: const InputDecoration(
                          labelText: 'PG sharing type',
                          prefixIcon: Icon(Icons.groups_2_outlined),
                        ),
                        items: <DropdownMenuItem<int?>>[
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All PG sharing types'),
                          ),
                          ..._pgSharingTypes.entries.map(
                            (MapEntry<int, String> entry) =>
                                DropdownMenuItem<int?>(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          ),
                        ],
                        onChanged: (int? value) {
                          setModalState(() {
                            selectedPgSharingType = value;
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.sell_outlined),
                      ),
                      items: <DropdownMenuItem<int?>>[
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All categories'),
                        ),
                        ..._categoryTypes.entries.map(
                          (MapEntry<int, String> entry) => DropdownMenuItem<int?>(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        ),
                      ],
                      onChanged: (int? value) {
                        setModalState(() {
                          selectedCategory = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCity,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(
                          value: 'all',
                          child: Text('All cities'),
                        ),
                        ..._cities.map(
                          (PublicCityData city) => DropdownMenuItem<String>(
                            value: city.cityId,
                            child: Text(city.cityName),
                          ),
                        ),
                      ],
                      onChanged: (String? value) {
                        setModalState(() {
                          selectedCity = value ?? 'all';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedPriceRange,
                      decoration: const InputDecoration(
                        labelText: 'Price range',
                        prefixIcon: Icon(Icons.currency_rupee_outlined),
                      ),
                      items: _priceRanges.entries
                          .map(
                            (MapEntry<String, String> entry) =>
                                DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: (String? value) {
                        setModalState(() {
                          selectedPriceRange = value ?? 'all';
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: CustomButton(
                            label: 'Cancel',
                            variant: CustomButtonVariant.outline,
                            onPressed: () =>
                                Navigator.of(bottomSheetContext).pop(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CustomButton(
                            label: 'Show results',
                            icon: const Icon(Icons.search_rounded),
                            onPressed: () {
                              setState(() {
                                _propertyTypeFilter = selectedPropertyType;
                                _categoryFilter = selectedCategory;
                                _subTypeFilter = selectedSubType;
                                _pgSharingTypeFilter = selectedPgSharingType;
                                _cityFilter = selectedCity;
                                _priceRange = selectedPriceRange;
                                _page = 1;
                              });
                              Navigator.of(bottomSheetContext).pop();
                              _loadProperties();
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

  Widget _buildPropertyCard(PropertyData property) {
    final ThemeData theme = Theme.of(context);
    final String address = _propertyAddress(property);
    final String priceText = property.rent > 0
        ? '\u20B9${property.rent.toStringAsFixed(0)}/mo'
        : 'Price on request';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () => _openPropertyDetailsPage(property),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x0C111827),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
              BoxShadow(
                color: Color(0x06111827),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // ── Image ──
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: SizedBox(
                  height: 170,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      _PropertyImage(
                        imageUrl: property.imageUrl,
                        height: 170,
                      ),
                      // Type badge
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _propertyTypeLabel(property.propertyType),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      // Favorite button
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.favorite_border_rounded,
                            size: 17,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                      // Verified+ badge
                      if (property.whetherVerifiedPlus == true)
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: const Color(0xFFF59E0B),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 11,
                                  color: Color(0xFFD97706),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Verified+',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFFD97706),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Price overlay
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x1A000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            priceText,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ── Details ──
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      property.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (address.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.location_on_rounded,
                            size: 14,
                            color: AppTheme.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Bed / bath row
                    if ((property.bedrooms != null && property.bedrooms! > 0) ||
                        (property.bathrooms != null &&
                            property.bathrooms! > 0)) ...<Widget>[
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          if (property.bedrooms != null &&
                              property.bedrooms! > 0) ...<Widget>[
                            const Icon(
                              Icons.bed_outlined,
                              size: 13,
                              color: AppTheme.textMuted,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${property.bedrooms} bed',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                          if (property.bedrooms != null &&
                              property.bedrooms! > 0 &&
                              property.bathrooms != null &&
                              property.bathrooms! > 0)
                            const SizedBox(width: 10),
                          if (property.bathrooms != null &&
                              property.bathrooms! > 0) ...<Widget>[
                            const Icon(
                              Icons.shower_outlined,
                              size: 13,
                              color: AppTheme.textMuted,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${property.bathrooms} bath',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: <Widget>[
                        if (property.subType != null)
                          _CompactTag(
                            label: _subTypeLabel(
                              property.propertyType,
                              property.subType,
                            ),
                          ),
                        if (property.deposit > 0)
                          _CompactTag(
                            label: 'Dep ₹${_compactAmount(property.deposit)}',
                            color: const Color(0xFF7C3AED),
                            bgColor: const Color(0xFFF5F3FF),
                          ),
                        if ((property.noOfVacancy ?? 0) > 0)
                          _CompactTag(
                            label: '${property.noOfVacancy} vacant',
                            color: const Color(0xFF059669),
                            bgColor: const Color(0xFFECFDF5),
                          ),
                        if (property.propertyType == 3 &&
                            property.pgSharingType != null)
                          _CompactTag(
                            label: _pgSharingTypes[
                                    property.pgSharingType] ??
                                'Shared',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(ThemeData theme) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Unable to load public properties',
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
            onPressed: _loadProperties,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(ThemeData theme) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'No properties found',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different property type, city, search term, or price range.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEnquirySubmittedDialog(String statusMessage) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          title: const Text('Enquiry submitted'),
          content: Text(
            statusMessage.isEmpty
                ? 'Thanks. Your property enquiry was submitted successfully.'
                : statusMessage,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _CompactTag extends StatelessWidget {
  const _CompactTag({
    required this.label,
    this.color = AppTheme.textSecondary,
    this.bgColor = AppTheme.surfaceMuted,
  });

  final String label;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _LeadTag extends StatelessWidget {
  const _LeadTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.primaryHover,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({
    required this.label,
    required this.onDeleted,
  });

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      onDeleted: onDeleted,
      side: const BorderSide(color: AppTheme.borderStrong),
      backgroundColor: Colors.white,
      deleteIcon: const Icon(Icons.close_rounded, size: 18),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _PropertyImage extends StatelessWidget {
  const _PropertyImage({required this.imageUrl, required this.height});

  final String? imageUrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      return Container(
        height: height,
        width: double.infinity,
        color: AppTheme.surfaceMuted,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_not_supported_outlined,
          size: 40,
          color: AppTheme.textMuted,
        ),
      );
    }

    return Image.network(
      imageUrl!,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Container(
          height: height,
          width: double.infinity,
          color: AppTheme.surfaceMuted,
          alignment: Alignment.center,
          child: const Icon(
            Icons.broken_image_outlined,
            size: 40,
            color: AppTheme.textMuted,
          ),
        );
      },
      loadingBuilder: (
        BuildContext context,
        Widget child,
        ImageChunkEvent? loadingProgress,
      ) {
        if (loadingProgress == null) {
          return child;
        }

        return Container(
          height: height,
          width: double.infinity,
          color: AppTheme.surfaceMuted,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(),
        );
      },
    );
  }
}

class _SpecChip extends StatelessWidget {
  const _SpecChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

class _PublicPropertyDetailsPage extends StatelessWidget {
  const _PublicPropertyDetailsPage({
    required this.property,
    required this.imageUrls,
    required this.address,
    required this.propertyTypeLabel,
    required this.amenityLabels,
    required this.compactAmountBuilder,
    required this.onEnquire,
    this.subTypeLabel,
    this.furnishedLabel,
    this.pgSharingLabel,
    this.onOpenMap,
  });

  final PropertyData property;
  final List<String> imageUrls;
  final String address;
  final String propertyTypeLabel;
  final String? subTypeLabel;
  final String? furnishedLabel;
  final String? pgSharingLabel;
  final List<String> amenityLabels;
  final String Function(double amount) compactAmountBuilder;
  final VoidCallback onEnquire;
  final VoidCallback? onOpenMap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          property.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: <Widget>[
          if (imageUrls.isEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: _PropertyImage(
                imageUrl: property.imageUrl,
                height: 240,
              ),
            )
          else
            SizedBox(
              height: 240,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: imageUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (BuildContext context, int index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    child: SizedBox(
                      width: 320,
                      child: _PropertyImage(
                        imageUrl: imageUrls[index],
                        height: 240,
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ToneBadge(
                label: propertyTypeLabel,
                tone: UiTone.brand,
              ),
              if (subTypeLabel != null)
                ToneBadge(
                  label: subTypeLabel!,
                  tone: UiTone.neutral,
                ),
              if (property.category != null)
                ToneBadge(
                  label: property.category == 1 ? 'Rent' : 'Lease',
                  tone: UiTone.brand,
                ),
              ToneBadge(
                label: property.rent > 0
                    ? 'Rent Rs ${compactAmountBuilder(property.rent)}/mo'
                    : 'Rent on request',
                tone: UiTone.success,
              ),
              if (property.deposit > 0)
                ToneBadge(
                  label: 'Deposit Rs ${compactAmountBuilder(property.deposit)}',
                  tone: UiTone.neutral,
                ),
              if ((property.noOfVacancy ?? 0) > 0)
                ToneBadge(
                  label: '${property.noOfVacancy} vacancies',
                  tone: UiTone.warning,
                ),
              if (property.whetherVerifiedPlus == true)
                const ToneBadge(
                  label: 'Verified+',
                  tone: UiTone.warning,
                ),
            ],
          ),
          if (address.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              'Address',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              address,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          if (onOpenMap != null) ...<Widget>[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onOpenMap,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Open in maps'),
            ),
          ],
          if ((property.bedrooms != null && property.bedrooms! > 0) ||
              (property.bathrooms != null && property.bathrooms! > 0) ||
              (property.area != null && property.area! > 0) ||
              furnishedLabel != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              'Property specs',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: <Widget>[
                if (property.bedrooms != null && property.bedrooms! > 0)
                  _SpecChip(
                    icon: Icons.bed_outlined,
                    label:
                        '${property.bedrooms} Bedroom${property.bedrooms! > 1 ? 's' : ''}',
                  ),
                if (property.bathrooms != null && property.bathrooms! > 0)
                  _SpecChip(
                    icon: Icons.shower_outlined,
                    label:
                        '${property.bathrooms} Bathroom${property.bathrooms! > 1 ? 's' : ''}',
                  ),
                if (property.area != null && property.area! > 0)
                  _SpecChip(
                    icon: Icons.square_foot_outlined,
                    label: '${property.area!.toStringAsFixed(0)} sq ft',
                  ),
                if (furnishedLabel != null)
                  _SpecChip(
                    icon: Icons.chair_outlined,
                    label: furnishedLabel!,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Description',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            property.description.trim().isEmpty
                ? 'No description was provided for this property.'
                : property.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          if (pgSharingLabel != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              'PG sharing',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              pgSharingLabel!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          if (amenityLabels.isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: amenityLabels
                  .map(
                    (String label) => ToneBadge(
                      label: label,
                      tone: UiTone.neutral,
                      size: ToneBadgeSize.small,
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              label: 'Enquire',
              icon: const Icon(Icons.message_outlined),
              onPressed: onEnquire,
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyEnquirySheet extends StatefulWidget {
  const _PropertyEnquirySheet({required this.property});

  final PropertyData property;

  @override
  State<_PropertyEnquirySheet> createState() => _PropertyEnquirySheetState();
}

class _PropertyEnquirySheetState extends State<_PropertyEnquirySheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _otpSent = false;
  bool _isSubmitting = false;
  bool _isClosing = false;
  String? _localError;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _phoneController.text.trim().length != 10) {
      setState(() {
        _localError =
            'Name, email, and a valid 10-digit phone number are required.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _localError = null;
    });

    try {
      await PublicDiscoveryService.generateUserOtp(_phoneController.text.trim());
      if (!mounted) {
        return;
      }
      setState(() {
        _otpSent = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _localError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _submitEnquiry() async {
    if (_otpController.text.trim().isEmpty) {
      setState(() {
        _localError = 'Enter the OTP sent to your phone.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _localError = null;
    });

    try {
      final String status = await PublicDiscoveryService.createPropertyEnquiry(
        propertyId: widget.property.propertyId,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        otp: _otpController.text.trim(),
      );

      if (!mounted) {
        return;
      }
      _isClosing = true;
      Navigator.of(context).pop(status);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _localError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted && !_isClosing) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              _otpSent ? 'Verify and submit' : 'Property enquiry',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.property.title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            if (!_otpSent) ...<Widget>[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  prefixText: '+91 ',
                  prefixIcon: Icon(Icons.phone_outlined),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
            ] else
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'OTP',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
            if (_localError != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _localError!,
                style: const TextStyle(color: Color(0xFFB91C1C)),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                if (_otpSent) ...<Widget>[
                  Expanded(
                    child: CustomButton(
                      label: 'Back',
                      variant: CustomButtonVariant.outline,
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              setState(() {
                                _otpSent = false;
                                _localError = null;
                              });
                            },
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: CustomButton(
                    label: _otpSent ? 'Submit enquiry' : 'Send OTP',
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting
                        ? null
                        : (_otpSent ? _submitEnquiry : _sendOtp),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
