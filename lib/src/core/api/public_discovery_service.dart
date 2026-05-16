import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/api_models.dart';
import 'api_client.dart';
import 'api_config.dart';
import 'auth_service.dart';
import 'auth_storage.dart';

class PublicDiscoveryService {
  PublicDiscoveryService._();

  static const String _baseUrl = 'https://api.urbaneasyflats.com/user';
  static const String _filterAllProperties = '/Filter_All_Properties';
  static const String _filterAllBanners = '/Filter_All_Banners';
  static const String _filterAllCities = '/Filter_All_Cities';
  static const String _generateUserOtp = '/Generate_User_OTP';
  static const String _createPropertyEnquiry = '/Create_Property_Enquiry';

  static Future<({List<PropertyData> properties, int count})> filterProperties({
    int skip = 0,
    int limit = 20,
    String search = '',
    int? propertyType,
    int? categoryType,
    int? subType,
    double latitude = 0,
    double longitude = 0,
    bool didForceRefresh = false,
  }) async {
    final Map<String, dynamic> requestBody = <String, dynamic>{
      'Latitude': latitude,
      'Longitude': longitude,
      'Skip': skip,
      'Limit': limit,
      'Whether_Status_Filter': true,
      'Status': true,
      'Whether_Property_Type_Filter': propertyType != null,
      'Property_Type': propertyType ?? 1,
      'Whether_Category_Type_Filter': categoryType != null,
      'Category_Type': categoryType ?? 1,
      'Whether_Sub_Type_Filter': subType != null,
      'Sub_Type': subType ?? 1,
      'Whether_Search_Filter': search.trim().isNotEmpty,
      'Search': search.trim(),
    };

    debugPrint(
      '[PublicDiscovery] filterProperties request: '
      '${jsonEncode(requestBody)} '
      'apiKeyPresent=${(AuthStorage.apiKey ?? '').isNotEmpty}',
    );

    final Map<String, dynamic> extras = await _post(
      _filterAllProperties,
      requestBody,
      includeApiKey: true,
    );

    final List<dynamic> dataList = extras['Data'] as List<dynamic>? ?? <dynamic>[];
    debugPrint(
      '[PublicDiscovery] filterProperties response: '
      'count=${extras['Count']} dataLength=${dataList.length} '
      'skip=$skip limit=$limit',
    );

    final bool isDefaultLandingRequest = skip == 0 &&
        search.trim().isEmpty &&
        propertyType == null &&
        categoryType == null &&
        subType == null;

    if (!didForceRefresh &&
        isDefaultLandingRequest &&
        dataList.isEmpty &&
        (extras['Count'] as int? ?? 0) == 0) {
      debugPrint(
        '[PublicDiscovery] Empty default listing result. '
        'Refreshing public session and retrying once.',
      );
      final bool refreshed = await AuthService.refreshPublicSession();
      if (refreshed) {
        return filterProperties(
          skip: skip,
          limit: limit,
          search: search,
          propertyType: propertyType,
          categoryType: categoryType,
          subType: subType,
          latitude: latitude,
          longitude: longitude,
          didForceRefresh: true,
        );
      }
    }

    final List<PropertyData> properties = dataList
        .map(
          (dynamic item) => PropertyData.fromJson(item as Map<String, dynamic>),
        )
        .toList();

    return (
      properties: properties,
      count: extras['Count'] as int? ?? properties.length,
    );
  }

  static Future<({List<PublicBannerData> banners, int count})> filterBanners({
    int skip = 0,
    int limit = 10,
  }) async {
    final Map<String, dynamic> extras = await _post(
      _filterAllBanners,
      <String, dynamic>{
        'Skip': skip,
        'Limit': limit,
      },
      includeApiKey: true,
    );

    final List<dynamic> dataList = extras['Data'] as List<dynamic>? ?? <dynamic>[];
    final List<PublicBannerData> banners = dataList
        .map(
          (dynamic item) =>
              PublicBannerData.fromJson(item as Map<String, dynamic>),
        )
        .where((PublicBannerData item) => (item.imageUrl ?? '').trim().isNotEmpty)
        .toList();

    return (
      banners: banners,
      count: extras['Count'] as int? ?? banners.length,
    );
  }

  static Future<({List<PublicCityData> cities, int count})> filterCities({
    int skip = 0,
    int limit = 1000,
    String? stateId,
    String search = '',
  }) async {
    final Map<String, dynamic> extras = await _post(
      _filterAllCities,
      <String, dynamic>{
        'Skip': skip,
        'Limit': limit,
        'Whether_State_Filter': stateId != null && stateId.isNotEmpty,
        'StateID': stateId ?? '',
        'Whether_Search_Filter': search.trim().isNotEmpty,
        'Search': search.trim(),
      },
    );

    final List<dynamic> dataList = extras['Data'] as List<dynamic>? ?? <dynamic>[];
    final List<PublicCityData> cities = dataList
        .map(
          (dynamic item) => PublicCityData.fromJson(item as Map<String, dynamic>),
        )
        .toList();

    return (
      cities: cities,
      count: extras['Count'] as int? ?? cities.length,
    );
  }

  static Future<String> generateUserOtp(
    String phoneNumber, {
    String countryCode = '+91',
  }) async {
    final Map<String, dynamic> extras = await _post(
      _generateUserOtp,
      <String, dynamic>{
        'CountryCode': _normalizeCountryCode(countryCode),
        'PhoneNumber': _normalizePhoneNumber(phoneNumber),
      },
    );
    return extras['Status'] as String? ?? 'OTP sent successfully.';
  }

  static Future<String> createPropertyEnquiry({
    required String propertyId,
    required String name,
    required String email,
    required String phoneNumber,
    required String otp,
    String countryCode = '+91',
  }) async {
    final Map<String, dynamic> extras = await _post(
      _createPropertyEnquiry,
      <String, dynamic>{
        'PropertyID': propertyId,
        'Name': name.trim(),
        'EmailID': email.trim(),
        'CountryCode': _normalizeCountryCode(countryCode),
        'PhoneNumber': _normalizePhoneNumber(phoneNumber),
        'OTP': otp.trim(),
      },
    );
    return extras['Status'] as String? ?? 'Enquiry submitted successfully.';
  }

  static Future<String> createAuthenticatedPropertyEnquiry({
    required String propertyId,
  }) async {
    final ApiResponse response = await ApiClient.instance.post(
      ApiConfig.createAuthenticatedPropertyEnquiry,
      <String, dynamic>{'PropertyID': propertyId},
    );

    if (!response.success) {
      throw Exception(
        response.message ?? response.status ?? 'Failed to submit enquiry.',
      );
    }

    return response.status ?? 'Enquiry submitted successfully.';
  }

  static Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body, {
    bool includeApiKey = false,
    bool allowDatabaseErrorAsEmpty = false,
    bool didRefreshApiKey = false,
  }) async {
    final Map<String, dynamic> requestBody = <String, dynamic>{...body};
    if (includeApiKey) {
      String? apiKey = AuthStorage.apiKey;
      if (apiKey == null || apiKey.isEmpty) {
        await AuthService.initializeApp();
        apiKey = AuthStorage.apiKey;
      }
      if (apiKey != null && apiKey.isNotEmpty) {
        requestBody['ApiKey'] = apiKey;
      }
    }

    final Uri url = Uri.parse('$_baseUrl$endpoint');
    final http.Response response = await http.post(
      url,
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    final bool success = json['success'] as bool? ?? false;
    final Map<String, dynamic> extras =
        json['extras'] as Map<String, dynamic>? ?? <String, dynamic>{};

    if (!success) {
      final String message = extras['msg'] as String? ??
          extras['Status'] as String? ??
          'Public request failed.';
      final String messageLower = message.toLowerCase();
      if (includeApiKey &&
          !didRefreshApiKey &&
          (messageLower.contains('api key') ||
              messageLower.contains('apikey') ||
              messageLower.contains('session') ||
              messageLower.contains('auth'))) {
        await AuthService.initializeApp();
        return _post(
          endpoint,
          body,
          includeApiKey: includeApiKey,
          allowDatabaseErrorAsEmpty: allowDatabaseErrorAsEmpty,
          didRefreshApiKey: true,
        );
      }
      if (allowDatabaseErrorAsEmpty && message.toLowerCase().contains('database')) {
        return <String, dynamic>{'Count': 0, 'Data': <dynamic>[]};
      }
      throw Exception(message);
    }

    if (endpoint == _filterAllProperties) {
      final List<dynamic> dataList =
          extras['Data'] as List<dynamic>? ?? const <dynamic>[];
      debugPrint(
        '[PublicDiscovery] POST $endpoint success='
        '${json['success']} count=${extras['Count']} dataLength=${dataList.length}',
      );
    }

    return extras;
  }

  static String _normalizeCountryCode(String countryCode) {
    final String normalized = countryCode.trim();
    if (normalized.isEmpty) {
      throw Exception('Country code is required.');
    }
    return normalized;
  }

  static String _normalizePhoneNumber(String phoneNumber) {
    final String normalized = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^\d{10}$').hasMatch(normalized)) {
      throw Exception('Enter a valid 10-digit phone number.');
    }
    return normalized;
  }
}
