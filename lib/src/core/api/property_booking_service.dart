import 'api_client.dart';
import 'api_config.dart';

class PropertyBookingService {
  PropertyBookingService._();

  static Future<({List<PropertyBookingData> bookings, int count})>
      filterManagerBookings({
    int skip = 0,
    int limit = 50,
    String? status,
    String? statusGroup,
    String search = '',
  }) async {
    final ApiResponse response = await ApiClient.instance.post(
      ApiConfig.filterManagerPropertyBookings,
      <String, dynamic>{
        'Skip': skip,
        'Limit': limit,
        'Whether_Booking_Status_Filter': status != null && status.isNotEmpty,
        'Booking_Status': status ?? '',
        if (statusGroup != null && statusGroup.isNotEmpty)
          'Booking_Status_Group': statusGroup,
        'Whether_Search_Filter': search.trim().isNotEmpty,
        'Search': search.trim(),
      },
    );
    if (!response.success) {
      throw Exception(response.message ?? 'Unable to fetch bookings.');
    }
    final List<dynamic> data =
        response.extras['Data'] as List<dynamic>? ?? <dynamic>[];
    return (
      bookings: data
          .whereType<Map<String, dynamic>>()
          .map(PropertyBookingData.fromJson)
          .toList(),
      count: response.count ?? 0,
    );
  }

  static Future<PropertyBookingData> managerAccept(String bookingId) async {
    final ApiResponse response = await ApiClient.instance.post(
      ApiConfig.managerAcceptPropertyBooking,
      <String, dynamic>{'BookingID': bookingId},
    );
    if (!response.success) {
      throw Exception(response.message ?? 'Unable to accept booking.');
    }
    return PropertyBookingData.fromJson(
      response.data as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  static Future<PropertyBookingData> managerReject({
    required String bookingId,
    required String reason,
  }) async {
    final ApiResponse response = await ApiClient.instance.post(
      ApiConfig.managerRejectPropertyBooking,
      <String, dynamic>{'BookingID': bookingId, 'Reason': reason.trim()},
    );
    if (!response.success) {
      throw Exception(response.message ?? 'Unable to reject booking.');
    }
    return PropertyBookingData.fromJson(
      response.data as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }
}

class PropertyBookingData {
  const PropertyBookingData({
    required this.bookingId,
    required this.bookingNumber,
    required this.bookingAmount,
    required this.paymentStatus,
    required this.bookingStatus,
    required this.propertyInfo,
    required this.tenantInfo,
    this.razorpayPaymentId = '',
    this.refundStatus = '',
  });

  factory PropertyBookingData.fromJson(Map<String, dynamic> json) {
    return PropertyBookingData(
      bookingId: json['BookingID'] as String? ?? '',
      bookingNumber: json['Booking_Number'] as String? ?? '',
      bookingAmount: (json['Booking_Amount'] as num?)?.toDouble() ?? 0,
      paymentStatus: json['Payment_Status'] as String? ?? '',
      bookingStatus: json['Booking_Status'] as String? ?? '',
      razorpayPaymentId: json['Razorpay_Payment_ID'] as String? ?? '',
      refundStatus: json['Refund_Status'] as String? ?? '',
      propertyInfo: _readMap(json['Property_Info']),
      tenantInfo: _readMap(json['Tenant_Info']),
    );
  }

  final String bookingId;
  final String bookingNumber;
  final double bookingAmount;
  final String paymentStatus;
  final String bookingStatus;
  final String razorpayPaymentId;
  final String refundStatus;
  final Map<String, dynamic> propertyInfo;
  final Map<String, dynamic> tenantInfo;

  String get propertyTitle => propertyInfo['Property_Title'] as String? ?? '';
  String get propertyImageUrl => _readImageUrl(propertyInfo);
  String get propertyTypeLabel =>
      propertyInfo['Property_Type_Label'] as String? ?? 'Property';
  int get propertyType => (propertyInfo['Property_Type'] as num?)?.toInt() ?? 1;
  String get location => propertyInfo['Location_Address'] as String? ?? '';
  String get tenantName => tenantInfo['Full_Name'] as String? ?? '';
  String get tenantPhone => tenantInfo['PhoneNumber'] as String? ?? '';
  String get tenantEmail => tenantInfo['EmailID'] as String? ?? '';
}

Map<String, dynamic> _readMap(dynamic value) {
  return value is Map<String, dynamic> ? value : <String, dynamic>{};
}

String _readImageUrl(Map<String, dynamic> source) {
  const List<String> directKeys = <String>[
    'Image_URL',
    'imageUrl',
    'image',
    'Property_Image_URL',
    'Property_Image',
    'Property_Image_1',
    'Property_Image_2',
    'Property_Image_3',
    'Property_Image_Document',
    'Notification_Image',
    'Cover_Image',
    'Thumbnail_URL',
  ];

  for (final String key in directKeys) {
    final String value = _readImageValue(source[key]);
    if (_isNetworkImage(value)) return value;
  }

  const List<String> collectionKeys = <String>[
    'Images',
    'Property_Images',
    'Property_Image_Documents',
    'Gallery',
    'Documents',
  ];
  for (final String key in collectionKeys) {
    final dynamic value = source[key];
    if (value is List) {
      for (final dynamic item in value) {
        final String image = _readImageValue(item);
        if (_isNetworkImage(image)) return image;
      }
    }
  }

  return '';
}

String _readImageValue(dynamic value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  if (value is Map) {
    for (final String key in <String>[
      'url',
      'URL',
      'Url',
      'Location',
      'location',
      'File_URL',
      'FileURL',
      'Image_URL',
      'Document_URL',
      'secure_url',
    ]) {
      final String nested = _readImageValue(value[key]);
      if (nested.isNotEmpty) return nested;
    }
  }
  return '';
}

bool _isNetworkImage(String value) {
  final Uri? uri = Uri.tryParse(value.trim());
  return uri != null &&
      uri.hasScheme &&
      uri.host.isNotEmpty &&
      (uri.scheme == 'http' || uri.scheme == 'https');
}
