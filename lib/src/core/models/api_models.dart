import 'app_models.dart';

const String _uploadBucketRoot =
    'https://urbaneasyflats.s3.ap-south-1.amazonaws.com/';
const String _uploadBucketFolder = 'dev/';

String? _normalizeUploadUrl(String? value) {
  final String text = value?.trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  if (text.startsWith('http://') || text.startsWith('https://')) {
    return text;
  }
  if (text.startsWith('//')) {
    return 'https:$text';
  }
  String path = text.replaceFirst(RegExp(r'^/+'), '');
  final String fileName = path.split('/').last;
  if (!fileName.contains('.') && !fileName.endsWith('_Original')) {
    path = '${path}_Original.png';
  }
  if (path.startsWith(_uploadBucketFolder)) {
    return '$_uploadBucketRoot$path';
  }
  return '$_uploadBucketRoot$_uploadBucketFolder$path';
}

bool _looksLikeImageStringKey(String key) {
  if (_looksLikeImageIdKey(key)) {
    return false;
  }

  final String normalized = key.toLowerCase();
  return normalized.contains('url') ||
      normalized.contains('generation') ||
      normalized.contains('original') ||
      normalized.contains('image') ||
      normalized.contains('photo') ||
      normalized.contains('picture') ||
      normalized.contains('avatar');
}

bool _looksLikeImageContainerKey(String key) {
  final String normalized = key.toLowerCase();
  return normalized == 'data' ||
      normalized.contains('image') ||
      normalized.contains('photo') ||
      normalized.contains('picture') ||
      normalized.contains('avatar') ||
      normalized.contains('profile') ||
      normalized.contains('vendor') ||
      normalized.contains('tenant') ||
      normalized.contains('resident') ||
      normalized.contains('user');
}

bool _looksLikeImageIdKey(String key) {
  final String normalized = key.toLowerCase();
  return (normalized.contains('image') ||
          normalized.contains('photo') ||
          normalized.contains('picture') ||
          normalized.contains('avatar') ||
          normalized.contains('profile')) &&
      normalized.contains('id');
}

bool? _readBool(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final String normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
  }
  return null;
}

int _readIntValue(dynamic value, {int fallback = 0}) {
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    final String text = value.trim();
    return int.tryParse(text) ?? double.tryParse(text)?.toInt() ?? fallback;
  }
  return fallback;
}

int? _readOptionalInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is String && value.trim().isEmpty) {
    return null;
  }
  return _readIntValue(value);
}

int? _firstOptionalInt(List<dynamic> values) {
  for (final dynamic value in values) {
    final int? parsed = _readOptionalInt(value);
    if (parsed != null) {
      return parsed;
    }
  }
  return null;
}

DateTime? _parseApiTimestamp(String? value) {
  final String text = value?.trim() ?? '';
  if (text.isEmpty) {
    return null;
  }

  final DateTime? parsed = DateTime.tryParse(text);
  if (parsed == null) {
    return null;
  }

  final bool hasTime = text.contains('T') || RegExp(r'\d\s+\d').hasMatch(text);
  final bool hasTimezone = RegExp(r'(?:[zZ]|[+-]\d{2}:?\d{2})$').hasMatch(text);
  if (parsed.isUtc || hasTimezone) {
    return parsed.toLocal();
  }

  if (hasTime) {
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    ).toLocal();
  }

  return parsed;
}

const Duration _indiaTimeOffset = Duration(hours: 5, minutes: 30);

DateTime? _parseApiTimestampAsIndiaTime(String? value) {
  final String text = value?.trim() ?? '';
  if (text.isEmpty) {
    return null;
  }

  final DateTime? parsed = DateTime.tryParse(text);
  if (parsed == null) {
    return null;
  }

  final bool hasTime = text.contains('T') || RegExp(r'\d\s+\d').hasMatch(text);
  final bool hasTimezone = RegExp(r'(?:[zZ]|[+-]\d{2}:?\d{2})$').hasMatch(text);
  if (!hasTime) {
    return parsed;
  }

  final DateTime utcDate = hasTimezone || parsed.isUtc
      ? parsed.toUtc()
      : DateTime.utc(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
          parsed.millisecond,
          parsed.microsecond,
        );
  final DateTime indiaDate = utcDate.add(_indiaTimeOffset);
  return DateTime(
    indiaDate.year,
    indiaDate.month,
    indiaDate.day,
    indiaDate.hour,
    indiaDate.minute,
    indiaDate.second,
    indiaDate.millisecond,
    indiaDate.microsecond,
  );
}

String? _readImageUrl(dynamic value, {int depth = 0}) {
  if (value == null) {
    return null;
  }
  if (depth > 8) {
    return null;
  }

  if (value is String) {
    final String trimmed = value.trim();
    return _normalizeUploadUrl(trimmed);
  }

  if (value is List) {
    for (final dynamic item in value) {
      final String? url = _readImageUrl(item, depth: depth + 1);
      if (url != null) {
        return url;
      }
    }
    return null;
  }

  if (value is Map) {
    for (final String key in <String>[
      'Image_Original_URL',
      'Image_URL',
      'Image_250_URL',
      'Image_500_URL',
      'Image_750_URL',
      'Image_Generation_Name',
      'Image_Original_Name',
      'Image_Name',
      'ImageUrl',
      'URL',
      'url',
      'Profile_Image_URL',
      'Profile_Image_Original_URL',
      'Profile_Image_250_URL',
      'Profile_Image_500_URL',
      'Profile_Image_Generation_Name',
      'Profile_Photo_URL',
      'Profile_Photo_Information',
      'Profile_Photo_Data',
      'Photo_URL',
      'Photo_Information',
      'Photo_Data',
      'Avatar_URL',
      'Avatar_Information',
      'Avatar_Data',
      'Tenant_Profile_Image_URL',
      'Tenant_Image_URL',
      'Tenant_Vendor_Image_URL',
      'Tenant_Profile_Image_Generation_Name',
      'Tenant_Image_Generation_Name',
      'Tenant_Profile_Photo_Information',
      'Tenant_Photo_Information',
      'Resident_Profile_Image_URL',
      'Resident_Image_URL',
      'Resident_Profile_Image_Generation_Name',
      'Resident_Image_Generation_Name',
      'Resident_Profile_Photo_Information',
      'Resident_Photo_Information',
      'Resident_Profile_Photo_Data',
      'Image_Information',
      'Image_Information_Data',
      'Image_Data',
      'Image_Details',
      'Images',
      'Image_Array',
      'Image_Information_Array',
      'Profile_Image_Information',
      'Profile_Image_Data',
      'Resident_Profile_Image_Information',
      'Resident_Image_Information',
      'Tenant_Profile_Image_Information',
      'Tenant_Image_Information',
      'Tenant_Vendor_Image_Information',
      'Vendor_Image_Information',
      'Vendor_Image_Data',
      'Vendor_Profile_Image_Information',
      'Vendor_Profile_Image_Data',
      'User_Image_Information',
      'User_Profile_Image_Information',
      'User_Profile_Image_Data',
      'Resident_User_Data',
      'Vendor_Data',
      'Tenant_Vendor_Data',
      'Resident_Vendor_Data',
      'User_Data',
      'Data',
    ]) {
      final dynamic raw = value[key];
      if (raw is String && !_looksLikeImageStringKey(key)) {
        continue;
      }
      final String? url = _readImageUrl(raw, depth: depth + 1);
      if (url != null) {
        return url;
      }
    }

    for (final MapEntry<dynamic, dynamic> entry in value.entries) {
      final String key = entry.key?.toString() ?? '';
      final dynamic raw = entry.value;
      String? url;
      if (raw is String) {
        if (_looksLikeImageStringKey(key)) {
          url = _normalizeUploadUrl(raw);
        }
      } else if (_looksLikeImageContainerKey(key)) {
        url = _readImageUrl(raw, depth: depth + 1);
      }
      if (url != null) {
        return url;
      }
    }
  }

  return null;
}

String? _readImageId(dynamic value, {int depth = 0}) {
  if (value == null) {
    return null;
  }
  if (depth > 8) {
    return null;
  }

  if (value is List) {
    for (final dynamic item in value) {
      final String? imageId = _readImageId(item, depth: depth + 1);
      if (imageId != null) {
        return imageId;
      }
    }
    return null;
  }

  if (value is Map) {
    for (final String key in <String>[
      'ImageID',
      'Image_ID',
      'Profile_ImageID',
      'Profile_Image_ID',
      'Resident_Profile_ImageID',
      'Resident_Profile_Image_ID',
      'Resident_ImageID',
      'Resident_Image_ID',
      'Tenant_Profile_ImageID',
      'Tenant_Profile_Image_ID',
      'Tenant_ImageID',
      'Tenant_Image_ID',
      'Vendor_ImageID',
      'Vendor_Profile_ImageID',
      'Vendor_Image_ID',
      'User_ImageID',
      'User_Profile_ImageID',
      'Profile_PhotoID',
      'Profile_Photo_ID',
      'Resident_Profile_PhotoID',
      'Tenant_Profile_PhotoID',
      'Image_Information',
      'Image_Information_Data',
      'Image_Data',
      'Image_Details',
      'Images',
      'Image_Array',
      'Image_Information_Array',
      'Profile_Image_Information',
      'Profile_Image_Data',
      'Resident_Profile_Image_Information',
      'Resident_Image_Information',
      'Resident_Profile_Image_Data',
      'Tenant_Profile_Image_Information',
      'Tenant_Image_Information',
      'Tenant_Vendor_Image_Information',
      'Tenant_Profile_Image_Data',
      'Vendor_Image_Information',
      'Vendor_Profile_Image_Information',
      'Vendor_Image_Data',
      'User_Profile_Image_Information',
      'Resident_User_Data',
      'Vendor_Data',
      'Tenant_Vendor_Data',
      'Resident_Vendor_Data',
      'User_Data',
      'Data',
    ]) {
      final dynamic raw = value[key];
      if (raw is String) {
        final String text = raw.trim();
        if (text.isNotEmpty && _looksLikeImageIdKey(key)) {
          return text;
        }
      }
      final String? nested = _readImageId(raw, depth: depth + 1);
      if (nested != null) {
        return nested;
      }
    }

    for (final MapEntry<dynamic, dynamic> entry in value.entries) {
      final String key = entry.key?.toString() ?? '';
      final dynamic raw = entry.value;
      if (raw is String) {
        final String text = raw.trim();
        if (text.isNotEmpty && _looksLikeImageIdKey(key)) {
          return text;
        }
      } else if (_looksLikeImageContainerKey(key)) {
        final String? nested = _readImageId(raw, depth: depth + 1);
        if (nested != null) {
          return nested;
        }
      }
    }
  }

  return null;
}

String? _firstImageUrl(Map<String, dynamic> json, List<String> keys) {
  for (final String key in keys) {
    final String? url = _readImageUrl(json[key]);
    if (url != null) {
      return url;
    }
  }
  return null;
}

String? _firstImageId(Map<String, dynamic> json, List<String> keys) {
  for (final String key in keys) {
    final String? imageId = _readImageId(json[key]);
    if (imageId != null) {
      return imageId;
    }
  }
  return null;
}

String? _imageIdReference(String? imageId) {
  final String text = imageId?.trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  return 'imageid:$text';
}

// ---------------------------------------------------------------------------
// Vendor
// ---------------------------------------------------------------------------

class VendorData {
  const VendorData({
    required this.vendorId,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.vendorType,
    this.imageUrl,
    this.imageId,
    this.societyId,
    this.propertyId,
    this.whetherAccountBlockedByAdmin = false,
    this.accountBlockReason,
    this.whetherAccountDeleteRequested = false,
    this.billCollectionSummary,
    this.supportTicketSummary,
    this.propertySummary,
    this.rentalContractSummary,
    this.walletInfo,
  });

  factory VendorData.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? imageInformation =
        json['Image_Information'] as Map<String, dynamic>?;

    return VendorData(
      vendorId: json['VendorID'] as String? ?? '',
      fullName: json['Full_Name'] as String? ?? '',
      phone: json['Phone'] as String? ?? json['PhoneNumber'] as String? ?? '',
      email: json['EmailID'] as String? ?? '',
      vendorType: json['Vendor_Type'] as int? ?? 0,
      imageUrl:
          json['Image_Original_URL'] as String? ??
          imageInformation?['Image_Original_URL'] as String?,
      imageId:
          imageInformation?['ImageID'] as String? ??
          imageInformation?['Image_ID'] as String?,
      societyId: json['SocietyID'] as String?,
      propertyId: json['PropertyID'] as String?,
      whetherAccountBlockedByAdmin:
          _readBool(
            json['Whether_Account_Blocked_By_Admin'] ??
                json['whether_account_blocked_by_admin'],
          ) ??
          false,
      accountBlockReason:
          json['Account_Block_Reason'] as String? ??
          json['account_block_reason'] as String?,
      whetherAccountDeleteRequested:
          _readBool(
            json['Whether_Account_Delete_Requested'] ??
                json['whether_account_delete_requested'],
          ) ??
          false,
      billCollectionSummary:
          json['Bill_Collection_Summary'] is Map<String, dynamic>
          ? BillCollectionSummaryData.fromJson(
              json['Bill_Collection_Summary'] as Map<String, dynamic>,
            )
          : null,
      supportTicketSummary:
          json['Support_Ticket_Summary'] is Map<String, dynamic>
          ? SupportTicketSummaryData.fromJson(
              json['Support_Ticket_Summary'] as Map<String, dynamic>,
            )
          : null,
      propertySummary: json['Property_Summary'] is Map<String, dynamic>
          ? PropertySummaryData.fromJson(
              json['Property_Summary'] as Map<String, dynamic>,
            )
          : null,
      rentalContractSummary:
          json['Rental_Contract_Summary'] is Map<String, dynamic>
          ? RentalContractSummaryData.fromJson(
              json['Rental_Contract_Summary'] as Map<String, dynamic>,
            )
          : null,
      walletInfo: json['Wallet_Information'] is Map<String, dynamic>
          ? WalletSummaryData.fromJson(
              json['Wallet_Information'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  final String vendorId;
  final String fullName;
  final String phone;
  final String email;
  final int vendorType;
  final String? imageUrl;
  final String? imageId;
  final String? societyId;
  final String? propertyId;
  final bool whetherAccountBlockedByAdmin;
  final String? accountBlockReason;
  final bool whetherAccountDeleteRequested;
  final BillCollectionSummaryData? billCollectionSummary;
  final SupportTicketSummaryData? supportTicketSummary;
  final PropertySummaryData? propertySummary;
  final RentalContractSummaryData? rentalContractSummary;
  final WalletSummaryData? walletInfo;
}

class WalletSummaryData {
  const WalletSummaryData({
    required this.availableAmount,
    required this.creditedAmount,
    required this.debitedAmount,
  });

  factory WalletSummaryData.fromJson(Map<String, dynamic> json) {
    return WalletSummaryData(
      availableAmount: (json['Available_Amount'] as num?)?.toDouble() ?? 0,
      creditedAmount: (json['Credited_Amount'] as num?)?.toDouble() ?? 0,
      debitedAmount: (json['Debited_Amount'] as num?)?.toDouble() ?? 0,
    );
  }

  final double availableAmount;
  final double creditedAmount;
  final double debitedAmount;
}

class BillCollectionSummaryData {
  const BillCollectionSummaryData({
    required this.totalCollectedAmount,
    required this.totalPendingAmount,
    required this.totalOverdueAmount,
    required this.currentMonthCollected,
    required this.currentMonthPending,
    required this.currentMonthOverdue,
    required this.todaysCollection,
    this.totalSecurityBillAmount,
    this.pendingSecurityAmount,
    this.collectedSecurityAmount,
  });

  factory BillCollectionSummaryData.fromJson(Map<String, dynamic> json) {
    return BillCollectionSummaryData(
      totalCollectedAmount:
          (json['Total_Collected_Amount'] as num?)?.toDouble() ?? 0,
      totalPendingAmount:
          (json['Total_Pending_Amount'] as num?)?.toDouble() ?? 0,
      totalOverdueAmount:
          (json['Total_Overdue_Amount'] as num?)?.toDouble() ?? 0,
      currentMonthCollected:
          (json['Current_Month_Collected'] as num?)?.toDouble() ?? 0,
      currentMonthPending:
          (json['Current_Month_Pending'] as num?)?.toDouble() ?? 0,
      currentMonthOverdue:
          (json['Current_Month_Overdue'] as num?)?.toDouble() ?? 0,
      todaysCollection: (json['Todays_Collection'] as num?)?.toDouble() ?? 0,
      totalSecurityBillAmount: (json['Total_Security_Bill_Amount'] as num?)
          ?.toDouble(),
      pendingSecurityAmount: (json['Pending_Security_Amount'] as num?)
          ?.toDouble(),
      collectedSecurityAmount: (json['Collected_Security_Amount'] as num?)
          ?.toDouble(),
    );
  }

  final double totalCollectedAmount;
  final double totalPendingAmount;
  final double totalOverdueAmount;
  final double currentMonthCollected;
  final double currentMonthPending;
  final double currentMonthOverdue;
  final double todaysCollection;
  final double? totalSecurityBillAmount;
  final double? pendingSecurityAmount;
  final double? collectedSecurityAmount;
}

class SupportTicketSummaryData {
  const SupportTicketSummaryData({
    required this.openTicketsCount,
    required this.inProgressTicketsCount,
    required this.resolvedTicketsCount,
    required this.criticalOpenTicketsCount,
  });

  factory SupportTicketSummaryData.fromJson(Map<String, dynamic> json) {
    return SupportTicketSummaryData(
      openTicketsCount: json['Open_Tickets_Count'] as int? ?? 0,
      inProgressTicketsCount: json['InProgress_Tickets_Count'] as int? ?? 0,
      resolvedTicketsCount: json['Resolved_Tickets_Count'] as int? ?? 0,
      criticalOpenTicketsCount:
          json['Critical_Open_Tickets_Count'] as int? ?? 0,
    );
  }

  final int openTicketsCount;
  final int inProgressTicketsCount;
  final int resolvedTicketsCount;
  final int criticalOpenTicketsCount;
}

class PropertySummaryData {
  const PropertySummaryData({
    required this.totalPropertiesCount,
    required this.approvedPropertiesCount,
    required this.rejectedPropertiesCount,
    required this.pendingPropertiesCount,
    this.newEnquiriesCount = 0,
  });

  factory PropertySummaryData.fromJson(Map<String, dynamic> json) {
    int readInt(List<String> keys) {
      for (final String key in keys) {
        if (json.containsKey(key)) {
          return _readIntValue(json[key]);
        }
      }
      return 0;
    }

    return PropertySummaryData(
      totalPropertiesCount: readInt(<String>['Total_Properties_Count']),
      approvedPropertiesCount: readInt(<String>['Approved_Properties_Count']),
      rejectedPropertiesCount: readInt(<String>['Rejected_Properties_Count']),
      pendingPropertiesCount: readInt(<String>['Pending_Properties_Count']),
      newEnquiriesCount: readInt(<String>[
        'New_Enquiries_Count',
        'Open_Enquiries_Count',
        'Unresolved_Enquiries_Count',
        'Total_Unseen_Leads',
        'Total_Unseen_Enquiries',
        'Pending_Enquiries_Count',
        'Total_Leads',
        'Total_Enquiries_Count',
      ]),
    );
  }

  final int totalPropertiesCount;
  final int approvedPropertiesCount;
  final int rejectedPropertiesCount;
  final int pendingPropertiesCount;
  final int newEnquiriesCount;
}

class RentalContractSummaryData {
  const RentalContractSummaryData({
    required this.activeContractsCount,
    required this.expiredContractsCount,
    required this.pendingRenewalCount,
    required this.totalMonthlyRent,
  });

  factory RentalContractSummaryData.fromJson(Map<String, dynamic> json) {
    return RentalContractSummaryData(
      activeContractsCount: json['Active_Contracts_Count'] as int? ?? 0,
      expiredContractsCount: json['Expired_Contracts_Count'] as int? ?? 0,
      pendingRenewalCount: json['Pending_Renewal_Count'] as int? ?? 0,
      totalMonthlyRent: (json['Total_Monthly_Rent'] as num?)?.toDouble() ?? 0,
    );
  }

  final int activeContractsCount;
  final int expiredContractsCount;
  final int pendingRenewalCount;
  final double totalMonthlyRent;
}

// ---------------------------------------------------------------------------
// Public Discovery
// ---------------------------------------------------------------------------

class PublicBannerData {
  const PublicBannerData({
    required this.bannerId,
    this.title,
    this.subtitle,
    this.buttonText,
    this.imageUrl,
    this.navigationUrl,
    this.displayCount = 1,
  });

  factory PublicBannerData.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? webImage =
        json['Web_Image_Information'] as Map<String, dynamic>?;
    final Map<String, dynamic>? mobileImage =
        json['Mobile_Image_Information'] as Map<String, dynamic>?;

    return PublicBannerData(
      bannerId:
          json['Mobile_BannerID'] as String? ??
          json['Popup_BannerID'] as String? ??
          json['BannerID'] as String? ??
          json['_id'] as String? ??
          '',
      title:
          json['Mobile_Banner_Title'] as String? ??
          json['Popup_Banner_Title'] as String? ??
          json['Banner_Title'] as String? ??
          json['Title'] as String?,
      subtitle:
          json['Mobile_Banner_Subtitle'] as String? ??
          json['Popup_Banner_Subtitle'] as String?,
      buttonText: json['Button_Text'] as String?,
      imageUrl:
          mobileImage?['Image_Original_URL'] as String? ??
          webImage?['Image_Original_URL'] as String?,
      navigationUrl:
          json['Redirect_URL'] as String? ??
          json['URL'] as String? ??
          json['Link'] as String? ??
          json['Banner_URL'] as String? ??
          json['Navigation_URL'] as String? ??
          json['Redirect_URL'] as String?,
      displayCount: _readOptionalInt(json['Display_Count']) ?? 1,
    );
  }

  final String bannerId;
  final String? title;
  final String? subtitle;
  final String? buttonText;
  final String? imageUrl;
  final String? navigationUrl;
  final int displayCount;
}

class PublicCityData {
  const PublicCityData({required this.cityId, required this.cityName});

  factory PublicCityData.fromJson(Map<String, dynamic> json) {
    return PublicCityData(
      cityId: json['CityID'] as String? ?? '',
      cityName: json['City_Name'] as String? ?? '',
    );
  }

  final String cityId;
  final String cityName;
}

class PropertyStateData {
  const PropertyStateData({required this.stateId, required this.stateName});

  factory PropertyStateData.fromJson(Map<String, dynamic> json) {
    return PropertyStateData(
      stateId: json['StateID'] as String? ?? '',
      stateName: json['State_Name'] as String? ?? '',
    );
  }

  final String stateId;
  final String stateName;
}

class PropertyCityData {
  const PropertyCityData({required this.cityId, required this.cityName});

  factory PropertyCityData.fromJson(Map<String, dynamic> json) {
    return PropertyCityData(
      cityId: json['CityID'] as String? ?? '',
      cityName: json['City_Name'] as String? ?? '',
    );
  }

  final String cityId;
  final String cityName;
}

class SubscriptionPlanData {
  const SubscriptionPlanData({
    required this.subscriptionId,
    required this.subscriptionType,
    required this.title,
    required this.description,
    required this.price,
    required this.duration,
    required this.isActive,
  });

  factory SubscriptionPlanData.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanData(
      subscriptionId: json['SubscriptionID'] as String? ?? '',
      subscriptionType: json['Subscription_Type'] as int? ?? 0,
      title: json['Title'] as String? ?? '',
      description: json['Description'] as String? ?? '',
      price: (json['Price'] as num?)?.toDouble() ?? 0,
      duration: json['Duration'] as int? ?? 0,
      isActive: json['Status'] as bool? ?? true,
    );
  }

  final String subscriptionId;
  final int subscriptionType;
  final String title;
  final String description;
  final double price;
  final int duration;
  final bool isActive;
}

class SubscriptionCalculationData {
  const SubscriptionCalculationData({
    required this.subscriptionPrice,
    required this.activeRentalContractsCount,
    required this.freeContractsCount,
    required this.extraContractsCount,
    required this.totalAvailableContracts,
    required this.amountPerContract,
    required this.subscriptionMonths,
    required this.remainingSubscriptionMonths,
    required this.pricingMode,
    required this.extraContractsAmount,
    required this.subtotal,
    required this.gstPercentage,
    required this.gstAmount,
    required this.totalAmount,
  });

  factory SubscriptionCalculationData.fromJson(Map<String, dynamic> json) {
    int readInt(String key) => _readIntValue(json[key]);

    return SubscriptionCalculationData(
      subscriptionPrice: (json['Subscription_Price'] as num?)?.toDouble() ?? 0,
      activeRentalContractsCount: readInt('Active_Rental_Contracts_Count'),
      freeContractsCount: readInt('Free_Contracts_Count'),
      extraContractsCount: readInt('Extra_Contracts_Count'),
      totalAvailableContracts: readInt('Total_Available_Contracts'),
      amountPerContract: (json['Amount_Per_Contract'] as num?)?.toDouble() ?? 0,
      subscriptionMonths: readInt('Subscription_Months'),
      remainingSubscriptionMonths: readInt('Remaining_Subscription_Months'),
      pricingMode: json['Pricing_Mode'] as String? ?? '',
      extraContractsAmount:
          (json['Extra_Contracts_Amount'] as num?)?.toDouble() ?? 0,
      subtotal: (json['Subtotal'] as num?)?.toDouble() ?? 0,
      gstPercentage: (json['GST_Percentage'] as num?)?.toDouble() ?? 0,
      gstAmount: (json['GST_Amount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['Total_Amount'] as num?)?.toDouble() ?? 0,
    );
  }

  final double subscriptionPrice;
  final int activeRentalContractsCount;
  final int freeContractsCount;
  final int extraContractsCount;
  final int totalAvailableContracts;
  final double amountPerContract;
  final int subscriptionMonths;
  final int remainingSubscriptionMonths;
  final String pricingMode;
  final double extraContractsAmount;
  final double subtotal;
  final double gstPercentage;
  final double gstAmount;
  final double totalAmount;
}

class ResidentContractsCalculationData {
  const ResidentContractsCalculationData({
    required this.amountPerContract,
    required this.numberOfContracts,
    required this.subscriptionMonths,
    required this.remainingSubscriptionMonths,
    required this.pricingMode,
    required this.subtotal,
    required this.gstPercentage,
    required this.gstAmount,
    required this.totalAmount,
  });

  factory ResidentContractsCalculationData.fromJson(Map<String, dynamic> json) {
    return ResidentContractsCalculationData(
      amountPerContract: (json['Amount_Per_Contract'] as num?)?.toDouble() ?? 0,
      numberOfContracts: json['No_Of_Contracts'] as int? ?? 0,
      subscriptionMonths: _readIntValue(json['Subscription_Months']),
      remainingSubscriptionMonths:
          _readIntValue(json['Remaining_Subscription_Months']),
      pricingMode: json['Pricing_Mode'] as String? ?? '',
      subtotal: (json['Subtotal'] as num?)?.toDouble() ?? 0,
      gstPercentage: (json['GST_Percentage'] as num?)?.toDouble() ?? 0,
      gstAmount: (json['GST_Amount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['Total_Amount'] as num?)?.toDouble() ?? 0,
    );
  }

  final double amountPerContract;
  final int numberOfContracts;
  final int subscriptionMonths;
  final int remainingSubscriptionMonths;
  final String pricingMode;
  final double subtotal;
  final double gstPercentage;
  final double gstAmount;
  final double totalAmount;
}

class ResidentContractsPurchaseData {
  const ResidentContractsPurchaseData({
    required this.purchaseId,
    required this.amount,
    required this.currency,
    required this.calculation,
    required this.isFreePurchase,
    this.razorpayOrderId,
    this.razorpayKeyId,
  });

  factory ResidentContractsPurchaseData.fromJson(Map<String, dynamic> json) {
    return ResidentContractsPurchaseData(
      purchaseId: json['Vendor_Property_Contract_PurchaseID'] as String? ?? '',
      amount: (json['Amount'] as num?)?.toDouble() ?? 0,
      currency: json['Currency'] as String? ?? 'INR',
      calculation: ResidentContractsCalculationData.fromJson(
        (json['Calculation_Data'] as Map<String, dynamic>?) ??
            <String, dynamic>{},
      ),
      isFreePurchase: json['Is_Free_Purchase'] as bool? ?? false,
      razorpayOrderId: json['Razorpay_Order_ID'] as String?,
      razorpayKeyId: json['Razorpay_Key_ID'] as String?,
    );
  }

  final String purchaseId;
  final double amount;
  final String currency;
  final ResidentContractsCalculationData calculation;
  final bool isFreePurchase;
  final String? razorpayOrderId;
  final String? razorpayKeyId;
}

class SocietyResidentsCalculationData {
  const SocietyResidentsCalculationData({
    required this.amountPerResident,
    required this.numberOfResidents,
    required this.subtotal,
    required this.gstPercentage,
    required this.gstAmount,
    required this.totalAmount,
    this.residentsCountDifference,
    this.validityEndDate,
  });

  factory SocietyResidentsCalculationData.fromJson(Map<String, dynamic> json) {
    return SocietyResidentsCalculationData(
      amountPerResident: (json['Amount_Per_Resident'] as num?)?.toDouble() ?? 0,
      numberOfResidents: json['No_Of_Residents'] as int? ?? 0,
      residentsCountDifference: json['Residents_Count_Difference'] as int?,
      subtotal: (json['Subtotal'] as num?)?.toDouble() ?? 0,
      gstPercentage: (json['GST_Percentage'] as num?)?.toDouble() ?? 0,
      gstAmount: (json['GST_Amount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['Total_Amount'] as num?)?.toDouble() ?? 0,
      validityEndDate: json['Validity_End_Date'] as String?,
    );
  }

  final double amountPerResident;
  final int numberOfResidents;
  final int? residentsCountDifference;
  final double subtotal;
  final double gstPercentage;
  final double gstAmount;
  final double totalAmount;
  final String? validityEndDate;
}

class SocietyResidentsPurchaseData {
  const SocietyResidentsPurchaseData({
    required this.purchaseId,
    required this.amount,
    required this.currency,
    required this.calculation,
    required this.isFreePurchase,
    this.razorpayOrderId,
    this.razorpayKeyId,
  });

  factory SocietyResidentsPurchaseData.fromJson(Map<String, dynamic> json) {
    return SocietyResidentsPurchaseData(
      purchaseId: json['Society_Resident_PurchaseID'] as String? ?? '',
      amount: (json['Amount'] as num?)?.toDouble() ?? 0,
      currency: json['Currency'] as String? ?? 'INR',
      calculation: SocietyResidentsCalculationData.fromJson(
        (json['Calculation_Data'] as Map<String, dynamic>?) ??
            <String, dynamic>{},
      ),
      isFreePurchase: json['Is_Free_Purchase'] as bool? ?? false,
      razorpayOrderId: json['Razorpay_Order_ID'] as String?,
      razorpayKeyId: json['Razorpay_Key_ID'] as String?,
    );
  }

  final String purchaseId;
  final double amount;
  final String currency;
  final SocietyResidentsCalculationData calculation;
  final bool isFreePurchase;
  final String? razorpayOrderId;
  final String? razorpayKeyId;
}

// ---------------------------------------------------------------------------
// Bill
// ---------------------------------------------------------------------------

class BillData {
  const BillData({
    required this.billId,
    required this.billTitle,
    required this.amount,
    required this.dueDate,
    required this.billStatus,
    this.billType,
    this.unitLabel,
    this.note,
    this.paidDate,
    required this.payload,
  });

  factory BillData.fromJson(Map<String, dynamic> json) {
    return BillData(
      billId: json['BillID'] as String? ?? json['_id'] as String? ?? '',
      billTitle:
          json['Bill_Title'] as String? ?? json['Title'] as String? ?? 'Bill',
      amount:
          _toDouble(json['Bill_Final_Amount']) ??
          _toDouble(json['Amount']) ??
          _toDouble(json['Bill_Amount']) ??
          0,
      dueDate:
          DateTime.tryParse(
            json['Due_Date'] as String? ??
                json['Bill_Due_Date'] as String? ??
                '',
          ) ??
          DateTime.now(),
      billStatus: json['Bill_Status'] as int? ?? 1,
      billType: json['Bill_Type'] as int?,
      unitLabel:
          json['Flat_Or_Unit_No'] as String? ?? json['Flat_No'] as String?,
      note: json['Description'] as String? ?? json['Note'] as String?,
      paidDate: json['Paid_Date'] as String?,
      payload: json,
    );
  }

  final String billId;
  final String billTitle;
  final double amount;
  final DateTime dueDate;
  final int billStatus;
  final int? billType;
  final String? unitLabel;
  final String? note;
  final String? paidDate;
  final Map<String, dynamic> payload;

  BillRecord toBillRecord() {
    final Map<String, dynamic>? residentInfo =
        payload['Society_Resident_Information'] is Map<String, dynamic>
        ? payload['Society_Resident_Information'] as Map<String, dynamic>
        : null;
    final Map<String, dynamic>? contractInfo =
        payload['Property_Rental_Contract_Information'] is Map<String, dynamic>
        ? payload['Property_Rental_Contract_Information']
              as Map<String, dynamic>
        : null;
    final Map<String, dynamic>? paymentImageInfo =
        payload['Bill_Payment_Image_Information'] is Map<String, dynamic>
        ? payload['Bill_Payment_Image_Information'] as Map<String, dynamic>
        : null;
    final Map<String, dynamic>? societyData =
        payload['Society_Data'] is Map<String, dynamic>
        ? payload['Society_Data'] as Map<String, dynamic>
        : null;
    final Map<String, dynamic>? blockData =
        payload['Block_Data'] is Map<String, dynamic>
        ? payload['Block_Data'] as Map<String, dynamic>
        : null;
    final Map<String, dynamic>? buildingData =
        payload['Building_Data'] is Map<String, dynamic>
        ? payload['Building_Data'] as Map<String, dynamic>
        : null;

    // Treat empty strings as absent so fallback chain works properly.
    String? readString(Map<String, dynamic>? source, String key) {
      final dynamic value = source?[key];
      if (value == null) {
        return null;
      }
      return value.toString();
    }

    String? firstNonEmpty(List<String?> values) {
      for (final String? value in values) {
        final String trimmed = value?.trim() ?? '';
        if (trimmed.isNotEmpty) {
          return trimmed;
        }
      }
      return null;
    }

    final String resolvedUnit =
        firstNonEmpty(<String?>[
          unitLabel,
          readString(residentInfo, 'Flat_No'),
          readString(contractInfo, 'Flat_Or_Unit_No'),
          readString(payload, 'Flat_Or_Unit_No'),
        ]) ??
        'N/A';
    final String? tenantImageUrl = _firstImageUrl(
      <String, dynamic>{
        ...?contractInfo,
        'Tenant_Data': payload['Tenant_Data'],
        'Tenant_Vendor_Data': payload['Tenant_Vendor_Data'],
        'Top_Level_Tenant_Image_Information':
            payload['Tenant_Image_Information'],
        'Top_Level_Tenant_Profile_Image_Information':
            payload['Tenant_Profile_Image_Information'],
        'Top_Level_Tenant_Vendor_Image_Information':
            payload['Tenant_Vendor_Image_Information'],
      },
      <String>[
        'Tenant_Profile_Image_Information',
        'Tenant_Image_Information',
        'Tenant_Vendor_Image_Information',
        'Tenant_Profile_Image',
        'Tenant_Image',
        'Tenant_Profile_Photo',
        'Tenant_Photo',
        'Tenant_Profile_Picture',
        'Profile_Photo',
        'Profile_Picture',
        'Avatar',
        'Tenant_Profile_Image_URL',
        'Tenant_Image_URL',
        'Tenant_Profile_Photo_URL',
        'Tenant_Photo_URL',
        'Profile_Photo_URL',
        'Tenant_Vendor_Data',
        'Tenant_Data',
        'Profile_Image_Information',
        'Profile_Image_Data',
        'Profile_Photo_Information',
        'Profile_Photo_Data',
        'Profile_Image_URL',
        'Top_Level_Tenant_Image_Information',
        'Top_Level_Tenant_Profile_Image_Information',
        'Top_Level_Tenant_Vendor_Image_Information',
      ],
    );

    return BillRecord(
      id: billId,
      title: billTitle,
      unitLabel: resolvedUnit,
      amount: amount,
      dueDate: dueDate,
      status: _mapBillStatus(billStatus),
      category: _mapBillType(billType),
      note: note,
      billTypeCode: billType,
      finalAmount: _toDouble(payload['Bill_Final_Amount']) ?? amount,
      billDate: _parseDate(
        payload['Bill_Date'] as String? ?? payload['Created_At'] as String?,
      ),
      paidDate: _parseDate(payload['Bill_Paid_Date'] as String? ?? paidDate),
      paymentType: payload['Bill_Payment_Type'] as int?,
      manualOnlinePaymentMode:
          payload['Bill_Manual_Online_Payment_Mode'] as int?,
      paymentNote:
          payload['Bill_Payment_Description'] as String? ??
          payload['Description'] as String?,
      billAmount:
          _toDouble(payload['Bill_Amount']) ?? _toDouble(payload['Amount']),
      maintenanceAmount: _toDouble(payload['Bill_Maintainance_Amount']),
      tokenAmount: _toDouble(payload['Bill_Token_Amount']),
      paymentImageUrl: _normalizeUploadUrl(
        firstNonEmpty(<String?>[
          readString(paymentImageInfo, 'Image_Original_URL'),
          readString(paymentImageInfo, 'Image_URL'),
          readString(paymentImageInfo, 'Image_250_URL'),
          readString(paymentImageInfo, 'Image_500_URL'),
          readString(payload, 'Bill_Payment_Image_URL'),
        ]),
      ),
      tenantImageUrl: tenantImageUrl,
      rentalContractId: firstNonEmpty(<String?>[
        readString(contractInfo, 'Rental_ContractID'),
        readString(payload, 'Rental_ContractID'),
        readString(payload, 'Property_Rental_ContractID'),
      ]),
      propertyId: firstNonEmpty(<String?>[
        readString(contractInfo, 'PropertyID'),
        readString(payload, 'PropertyID'),
      ]),
      walletCredited:
          payload['Whether_Bill_Amount_Credited_To_Wallet'] as bool?,
      walletCreditTime: _parseDate(
        payload['Bill_Amount_Wallet_Credit_Time'] as String?,
      ),
      walletCreditedTime: _parseDate(
        payload['Bill_Amount_Wallet_Credited_Time'] as String?,
      ),
      residentName: firstNonEmpty(<String?>[
        readString(residentInfo, 'Name'),
        readString(payload, 'Resident_Name'),
        readString(contractInfo, 'Tenant_Name'),
        readString(payload, 'Tenant_Name'),
      ]),
      residentPhone: firstNonEmpty(<String?>[
        readString(residentInfo, 'PhoneNumber'),
        readString(payload, 'Resident_PhoneNumber'),
        readString(payload, 'PhoneNumber'),
        readString(contractInfo, 'Tenant_PhoneNumber'),
        readString(payload, 'Tenant_PhoneNumber'),
      ]),
      residentEmail: firstNonEmpty(<String?>[
        readString(residentInfo, 'EmailID'),
        readString(payload, 'Resident_EmailID'),
        readString(contractInfo, 'Tenant_EmailID'),
        readString(payload, 'Tenant_EmailID'),
      ]),
      residentTypeLabel: _residentTypeLabel(
        residentInfo?['Resident_Type'] as int?,
      ),
      societyName: firstNonEmpty(<String?>[
        readString(residentInfo, 'Society_Name'),
        readString(payload, 'Society_Name'),
        readString(societyData, 'Name'),
      ]),
      blockName: firstNonEmpty(<String?>[
        readString(residentInfo, 'Block_Name'),
        readString(payload, 'Block_Name'),
        readString(blockData, 'Name'),
      ]),
      buildingName: firstNonEmpty(<String?>[
        readString(residentInfo, 'Building_Name'),
        readString(payload, 'Building_Name'),
        readString(buildingData, 'Name'),
      ]),
      propertyTitle: contractInfo?['Property_Title'] as String?,
      ownerName: contractInfo?['Owner_Name'] as String?,
      ownerPhone: contractInfo?['Owner_PhoneNumber'] as String?,
      ownerEmail: contractInfo?['Owner_EmailID'] as String?,
      contractStartDate: _parseDate(
        contractInfo?['Contract_Start_Date'] as String?,
      ),
      contractEndDate: _parseDate(
        contractInfo?['Contract_End_Date'] as String?,
      ),
      rentAmount: _toDouble(contractInfo?['Monthly_Rent']),
      depositAmount: _toDouble(contractInfo?['Security_Deposit']),
      vacateDate: _parseDate(contractInfo?['Vacate_Date'] as String?),
    );
  }

  static BillStatus _mapBillStatus(int status) {
    return switch (status) {
      1 => BillStatus.pending,
      2 => BillStatus.paid,
      3 => BillStatus.overdue,
      4 => BillStatus.partial,
      _ => BillStatus.pending,
    };
  }

  static String _mapBillType(int? type) {
    return switch (type) {
      1 => 'Maintenance',
      2 => 'Rental Amount',
      3 => 'Security Deposit',
      4 => 'Other',
      _ => 'Bill',
    };
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  static double? _toDouble(dynamic value) {
    return (value as num?)?.toDouble();
  }

  static String? _residentTypeLabel(int? residentType) {
    return switch (residentType) {
      1 => 'Owner',
      2 => 'Tenant',
      3 => 'PG Resident',
      _ => null,
    };
  }
}

// ---------------------------------------------------------------------------
// Support Ticket
// ---------------------------------------------------------------------------

class SupportTicketData {
  const SupportTicketData({
    required this.ticketId,
    required this.title,
    required this.description,
    required this.ticketStatus,
    required this.priority,
    required this.category,
    this.updatedAt,
    this.assignee,
    this.createdAt,
    this.targetName,
    this.imageUrl,
    this.residentImageUrl,
    this.societyName,
    this.blockName,
    this.buildingName,
    this.flatNo,
    this.residentName,
    this.residentPhone,
    this.residentEmail,
    this.propertyTitle,
    this.propertyFlatNo,
    this.tenantName,
    this.tenantPhone,
    this.tenantImageUrl,
  });

  factory SupportTicketData.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? imageInfo =
        json['Image_Information'] is Map<String, dynamic>
        ? json['Image_Information'] as Map<String, dynamic>
        : null;
    final Map<String, dynamic>? vendorTypeData =
        json['Vendor_Ticket_Type_Data'] is Map<String, dynamic>
        ? json['Vendor_Ticket_Type_Data'] as Map<String, dynamic>
        : null;
    final Map<String, dynamic>? societyData =
        json['Society_Data'] is Map<String, dynamic>
        ? json['Society_Data'] as Map<String, dynamic>
        : null;
    final Map<String, dynamic>? blockData =
        json['Block_Data'] is Map<String, dynamic>
        ? json['Block_Data'] as Map<String, dynamic>
        : null;
    final Map<String, dynamic>? buildingData =
        json['Building_Data'] is Map<String, dynamic>
        ? json['Building_Data'] as Map<String, dynamic>
        : null;
    final Map<String, dynamic>? residentData =
        json['Resident_Data'] is Map<String, dynamic>
        ? json['Resident_Data'] as Map<String, dynamic>
        : null;
    final Map<String, dynamic> residentImageSource = <String, dynamic>{
      ...?residentData,
      'Vendor_Data': json['Vendor_Data'],
      'Tenant_Vendor_Data': json['Tenant_Vendor_Data'],
      'Resident_Vendor_Data': json['Resident_Vendor_Data'],
      'User_Data': json['User_Data'],
      'Resident_User_Data': json['Resident_User_Data'],
      'Top_Level_Resident_Image_Information':
          json['Resident_Image_Information'],
      'Top_Level_Profile_Image_Information': json['Profile_Image_Information'],
      'Top_Level_Resident_Profile_Image_Information':
          json['Resident_Profile_Image_Information'],
    };
    final List<String> residentImageKeys = <String>[
      'Profile_Image_Information',
      'Resident_Profile_Image_Information',
      'Resident_Image_Information',
      'Profile_Image',
      'Profile_Photo',
      'Profile_Picture',
      'Avatar',
      'Resident_Profile_Photo',
      'Resident_Photo',
      'Resident_Profile_Picture',
      'Profile_Image_URL',
      'Profile_Photo_URL',
      'Resident_Profile_Image_URL',
      'Resident_Image_URL',
      'Resident_Profile_Photo_URL',
      'Resident_Photo_URL',
      'Image_Information',
      'Image_Information_Data',
      'Image_Data',
      'Profile_Image_Data',
      'Profile_Photo_Information',
      'Profile_Photo_Data',
      'Resident_Profile_Image_Data',
      'Resident_Profile_Photo_Information',
      'Resident_Profile_Photo_Data',
      'Vendor_Data',
      'Tenant_Vendor_Data',
      'Resident_Vendor_Data',
      'User_Data',
      'Resident_User_Data',
      'Top_Level_Resident_Image_Information',
      'Top_Level_Profile_Image_Information',
      'Top_Level_Resident_Profile_Image_Information',
    ];
    final String? residentProfileImageUrl = _firstImageUrl(
      residentImageSource,
      residentImageKeys,
    );
    final String? residentProfileImageId = _firstImageId(
      residentImageSource,
      residentImageKeys,
    );
    // For property manager tickets: Property_Data and Rental_Contract_Data
    final Map<String, dynamic>? propertyData =
        json['Property_Data'] is Map<String, dynamic>
        ? json['Property_Data'] as Map<String, dynamic>
        : null;
    final Map<String, dynamic>? contractData =
        json['Rental_Contract_Data'] is Map<String, dynamic>
        ? json['Rental_Contract_Data'] as Map<String, dynamic>
        : null;
    final Map<String, dynamic> tenantImageSource = <String, dynamic>{
      ...?contractData,
      'Tenant_Data': json['Tenant_Data'],
      'Tenant_Vendor_Data': json['Tenant_Vendor_Data'],
      'Vendor_Data': json['Vendor_Data'],
      'User_Data': json['User_Data'],
      'Top_Level_Tenant_Image_Information': json['Tenant_Image_Information'],
      'Top_Level_Tenant_Profile_Image_Information':
          json['Tenant_Profile_Image_Information'],
      'Top_Level_Tenant_Vendor_Image_Information':
          json['Tenant_Vendor_Image_Information'],
    };
    final List<String> tenantImageKeys = <String>[
      'Tenant_Profile_Image_Information',
      'Tenant_Image_Information',
      'Tenant_Vendor_Image_Information',
      'Tenant_Profile_Image',
      'Tenant_Profile_Photo',
      'Tenant_Photo',
      'Tenant_Profile_Picture',
      'Profile_Photo',
      'Profile_Picture',
      'Avatar',
      'Tenant_Profile_Image_URL',
      'Tenant_Image_URL',
      'Tenant_Profile_Photo_URL',
      'Tenant_Photo_URL',
      'Profile_Image_Information',
      'Profile_Image_Data',
      'Profile_Photo_Information',
      'Profile_Photo_Data',
      'Profile_Image_URL',
      'Profile_Photo_URL',
      'Image_Information',
      'Image_Information_Data',
      'Image_Data',
      'Tenant_Data',
      'Tenant_Vendor_Data',
      'Vendor_Data',
      'User_Data',
      'Top_Level_Tenant_Image_Information',
      'Top_Level_Tenant_Profile_Image_Information',
      'Top_Level_Tenant_Vendor_Image_Information',
    ];
    final String? tenantProfileImageUrl = _firstImageUrl(
      tenantImageSource,
      tenantImageKeys,
    );
    final String? tenantProfileImageId = _firstImageId(
      tenantImageSource,
      tenantImageKeys,
    );

    String? readString(Map<String, dynamic>? source, String key) {
      final dynamic value = source?[key];
      if (value == null) {
        return null;
      }
      return value.toString();
    }

    String? firstNonEmpty(List<String?> values) {
      for (final String? value in values) {
        final String trimmed = value?.trim() ?? '';
        if (trimmed.isNotEmpty) {
          return trimmed;
        }
      }
      return null;
    }

    return SupportTicketData(
      ticketId:
          json['Support_TicketID'] as String? ?? json['_id'] as String? ?? '',
      title: json['Title'] as String? ?? '',
      description: json['Description'] as String? ?? '',
      ticketStatus: json['Ticket_Status'] as int? ?? 1,
      priority: json['Priority'] as int? ?? 1,
      category: json['Category'] as int? ?? 1,
      updatedAt:
          json['updatedAt'] as String? ??
          json['updated_at'] as String? ??
          json['UpdatedAt'] as String? ??
          json['Updated_At'] as String? ??
          json['Updated_Time'] as String? ??
          json['Time'] as String?,
      assignee: json['Assignee_Name'] as String?,
      createdAt:
          json['createdAt'] as String? ??
          json['created_at'] as String? ??
          json['CreatedAt'] as String? ??
          json['Created_At'] as String? ??
          json['Created_Time'] as String? ??
          json['Time'] as String?,
      targetName: vendorTypeData?['Name'] as String?,
      imageUrl: imageInfo?['Image_Original_URL'] as String?,
      residentImageUrl:
          residentProfileImageUrl ?? _imageIdReference(residentProfileImageId),
      societyName: societyData?['Name'] as String?,
      blockName: blockData?['Name'] as String?,
      buildingName: buildingData?['Name'] as String?,
      flatNo: firstNonEmpty(<String?>[
        readString(residentData, 'Flat_No'),
        readString(residentData, 'Flat_Or_Unit_No'),
        json['Flat_No'] as String?,
      ]),
      residentName: firstNonEmpty(<String?>[
        readString(residentData, 'Name'),
        readString(residentData, 'Full_Name'),
        json['Resident_Name'] as String?,
        json['Name'] as String?,
      ]),
      residentPhone: firstNonEmpty(<String?>[
        readString(residentData, 'PhoneNumber'),
        readString(residentData, 'Phone'),
        readString(residentData, 'Mobile'),
        json['Resident_PhoneNumber'] as String?,
        json['PhoneNumber'] as String?,
      ]),
      residentEmail: firstNonEmpty(<String?>[
        readString(residentData, 'EmailID'),
        readString(residentData, 'Email'),
        json['Resident_EmailID'] as String?,
        json['EmailID'] as String?,
      ]),
      propertyTitle: propertyData?['Property_Title'] as String?,
      propertyFlatNo:
          contractData?['Flat_Or_Unit_No'] as String? ??
          propertyData?['Flat_Or_Unit_No'] as String?,
      tenantName: contractData?['Tenant_Name'] as String?,
      tenantPhone: contractData?['Tenant_PhoneNumber'] as String?,
      tenantImageUrl:
          tenantProfileImageUrl ?? _imageIdReference(tenantProfileImageId),
    );
  }

  final String ticketId;
  final String title;
  final String description;
  final int ticketStatus;
  final int priority;
  final int category;
  final String? updatedAt;
  final String? assignee;
  final String? createdAt;
  final String? targetName;
  final String? imageUrl;
  final String? residentImageUrl;
  final String? societyName;
  final String? blockName;
  final String? buildingName;
  final String? flatNo;
  final String? residentName;
  final String? residentPhone;
  final String? residentEmail;
  final String? propertyTitle;
  final String? propertyFlatNo;
  final String? tenantName;
  final String? tenantPhone;
  final String? tenantImageUrl;

  TicketRecord toTicketRecord() {
    return TicketRecord(
      id: ticketId,
      title: title,
      description: description,
      status: _mapTicketStatus(ticketStatus),
      priority: _mapPriority(priority),
      category: _mapCategory(category),
      updatedAt: _parseApiTimestamp(updatedAt) ?? DateTime.now(),
      assignee: assignee,
      createdAt: _parseApiTimestamp(createdAt),
      targetName: targetName,
      imageUrl: imageUrl,
      residentImageUrl: residentImageUrl,
      societyName: societyName,
      blockName: blockName,
      buildingName: buildingName,
      flatNo: flatNo,
      residentName: residentName,
      residentPhone: residentPhone,
      residentEmail: residentEmail,
      propertyTitle: propertyTitle,
      propertyFlatNo: propertyFlatNo,
      tenantName: tenantName,
      tenantPhone: tenantPhone,
      tenantImageUrl: tenantImageUrl,
    );
  }

  static TicketStatus _mapTicketStatus(int status) {
    return switch (status) {
      1 => TicketStatus.open,
      2 => TicketStatus.inProgress,
      3 => TicketStatus.resolved,
      4 => TicketStatus.rejected,
      _ => TicketStatus.open,
    };
  }

  static TicketPriority _mapPriority(int priority) {
    return switch (priority) {
      1 => TicketPriority.low,
      2 => TicketPriority.medium,
      3 => TicketPriority.high,
      4 => TicketPriority.urgent,
      _ => TicketPriority.low,
    };
  }

  static String _mapCategory(int category) {
    return switch (category) {
      1 => 'Maintenance',
      2 => 'Billing',
      3 => 'Security',
      4 => 'Amenities',
      5 => 'Others',
      6 => 'Others',
      _ => 'Others',
    };
  }
}

// ---------------------------------------------------------------------------
// Announcement
// ---------------------------------------------------------------------------

class AnnouncementData {
  const AnnouncementData({
    required this.announcementId,
    required this.title,
    required this.description,
    required this.priority,
    this.createdAt,
    this.isRead = false,
    this.blockIds = const <String>[],
    this.buildingIds = const <String>[],
    this.blockNames = const <String>[],
    this.buildingNames = const <String>[],
  });

  factory AnnouncementData.fromJson(Map<String, dynamic> json) {
    final List<dynamic> blockIdArray =
        (json['BlockID_Array'] as List<dynamic>?) ?? const <dynamic>[];
    final List<dynamic> buildingIdArray =
        (json['BuildingID_Array'] as List<dynamic>?) ?? const <dynamic>[];
    final List<dynamic> blockDataArray =
        (json['Block_Array_Data'] as List<dynamic>?) ?? const <dynamic>[];
    final List<dynamic> buildingDataArray =
        (json['Building_Array_Data'] as List<dynamic>?) ?? const <dynamic>[];

    return AnnouncementData(
      announcementId:
          json['Society_AnnouncementID'] as String? ??
          json['Vendor_AnnouncementID'] as String? ??
          json['_id'] as String? ??
          '',
      title: json['Title'] as String? ?? '',
      description: json['Description'] as String? ?? '',
      priority: json['Priority'] as int? ?? 1,
      createdAt:
          json['created_at'] as String? ??
          json['createdAt'] as String? ??
          json['CreatedAt'] as String? ??
          json['Created_At'] as String? ??
          json['Announcement_Created_At'] as String? ??
          json['Announcement_Date'] as String? ??
          json['Created_Time'] as String? ??
          json['Time'] as String?,
      isRead:
          json['Is_Read'] as bool? ?? json['Whether_Read'] as bool? ?? false,
      blockIds: blockIdArray.map((dynamic item) => '$item').toList(),
      buildingIds: buildingIdArray.map((dynamic item) => '$item').toList(),
      blockNames: blockDataArray
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> item) => item['Name'] as String? ?? '')
          .where((String item) => item.isNotEmpty)
          .toList(),
      buildingNames: buildingDataArray
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> item) => item['Name'] as String? ?? '')
          .where((String item) => item.isNotEmpty)
          .toList(),
    );
  }

  final String announcementId;
  final String title;
  final String description;
  final int priority;
  final String? createdAt;
  final bool isRead;
  final List<String> blockIds;
  final List<String> buildingIds;
  final List<String> blockNames;
  final List<String> buildingNames;

  AnnouncementRecord toAnnouncementRecord() {
    return AnnouncementRecord(
      id: announcementId,
      title: title,
      message: description,
      category: AnnouncementCategory.maintenance,
      createdAt: _parseApiTimestampAsIndiaTime(createdAt) ?? DateTime.now(),
      unread: !isRead,
      priorityLabel: _mapPriorityLabel(priority),
      blockIds: blockIds,
      buildingIds: buildingIds,
      blockNames: blockNames,
      buildingNames: buildingNames,
    );
  }

  static String _mapPriorityLabel(int priority) {
    return switch (priority) {
      1 => 'Low',
      2 => 'Medium',
      3 => 'High',
      _ => 'Low',
    };
  }
}

// ---------------------------------------------------------------------------
// Incident
// ---------------------------------------------------------------------------

class IncidentData {
  const IncidentData({
    required this.incidentId,
    required this.title,
    required this.description,
    required this.incidentStatus,
    required this.priority,
    required this.isActive,
    this.location,
    this.createdAt,
    this.blockName,
    this.buildingName,
    this.imageUrl,
  });

  factory IncidentData.fromJson(Map<String, dynamic> json) {
    return IncidentData(
      incidentId:
          json['Society_IncidentID'] as String? ?? json['_id'] as String? ?? '',
      title: json['Title'] as String? ?? '',
      description: json['Description'] as String? ?? '',
      incidentStatus: json['Incident_Status'] as int? ?? 1,
      priority: json['Priority'] as int? ?? 1,
      isActive: json['Status'] as bool? ?? true,
      location: json['Location'] as String?,
      createdAt: json['createdAt'] as String? ?? json['Created_At'] as String?,
      blockName: json['Block_Data'] is Map<String, dynamic>
          ? (json['Block_Data'] as Map<String, dynamic>)['Name'] as String?
          : json['Block_Name'] as String?,
      buildingName: json['Building_Data'] is Map<String, dynamic>
          ? (json['Building_Data'] as Map<String, dynamic>)['Name'] as String?
          : json['Building_Name'] as String?,
      imageUrl: json['Image_Information'] is Map<String, dynamic>
          ? (json['Image_Information']
                    as Map<String, dynamic>)['Image_Original_URL']
                as String?
          : null,
    );
  }

  final String incidentId;
  final String title;
  final String description;
  final int incidentStatus;
  final int priority;
  final bool isActive;
  final String? location;
  final String? createdAt;
  final String? blockName;
  final String? buildingName;
  final String? imageUrl;

  TicketRecord toTicketRecord() {
    return TicketRecord(
      id: incidentId,
      title: title,
      description: description,
      status: _mapIncidentStatus(incidentStatus),
      priority: _mapPriority(priority),
      category: 'Incident${location != null ? ' - $location' : ''}',
      updatedAt: _parseApiTimestamp(createdAt) ?? DateTime.now(),
    );
  }

  IncidentRecord toIncidentRecord() {
    return IncidentRecord(
      id: incidentId,
      title: title,
      description: description,
      status: _mapIncidentRecordStatus(incidentStatus),
      priority: _mapIncidentRecordPriority(priority),
      createdAt: _parseApiTimestamp(createdAt) ?? DateTime.now(),
      isActive: isActive,
      location: location,
      blockName: blockName,
      buildingName: buildingName,
      imageUrl: imageUrl,
    );
  }

  static TicketStatus _mapIncidentStatus(int status) {
    return switch (status) {
      1 => TicketStatus.open,
      2 => TicketStatus.inProgress,
      3 => TicketStatus.resolved,
      _ => TicketStatus.open,
    };
  }

  static TicketPriority _mapPriority(int priority) {
    return switch (priority) {
      1 => TicketPriority.low,
      2 => TicketPriority.medium,
      3 => TicketPriority.high,
      4 => TicketPriority.urgent,
      _ => TicketPriority.low,
    };
  }

  static IncidentStatus _mapIncidentRecordStatus(int status) {
    return switch (status) {
      1 => IncidentStatus.open,
      2 => IncidentStatus.investigating,
      3 => IncidentStatus.resolved,
      _ => IncidentStatus.open,
    };
  }

  static IncidentPriority _mapIncidentRecordPriority(int priority) {
    return switch (priority) {
      1 => IncidentPriority.low,
      2 => IncidentPriority.medium,
      3 => IncidentPriority.high,
      4 => IncidentPriority.critical,
      _ => IncidentPriority.low,
    };
  }
}

// ---------------------------------------------------------------------------
// Property
// ---------------------------------------------------------------------------

class PropertyData {
  const PropertyData({
    required this.propertyId,
    required this.title,
    required this.description,
    required this.propertyType,
    required this.propertyStatus,
    this.isActive = true,
    this.rent = 0,
    this.deposit = 0,
    this.imageUrl,
    this.locationAddress,
    this.address,
    this.bedrooms,
    this.bathrooms,
    this.balconies,
    this.floor,
    this.area,
    this.furnishedType,
    this.facing,
    this.facingDirectionType,
    this.amenities,
    this.category,
    this.subType,
    this.pgSharingType,
    this.flatUnitNo,
    this.maintenance,
    this.brokerage,
    this.availableFrom,
    this.ownerName,
    this.ownerPhone,
    this.ownerEmail,
    this.state,
    this.city,
    this.images,
    this.imageIds,
    this.noOfVacancy,
    this.latitude,
    this.longitude,
    this.stateId,
    this.cityId,
    this.amenityIds,
    this.propertyRulesDescription,
    this.floorPlanDocumentId,
    this.floorPlanDocumentUrl,
    this.isSubscribed = false,
    this.wasSubscribedAtLeastOnce = false,
    this.currentVendorSubscriptionId,
    this.currentSubscriptionId,
    this.currentSubscriptionTitle,
    this.currentSubscriptionDescription,
    this.currentSubscriptionPrice,
    this.currentSubscriptionDuration,
    this.currentSubscriptionExpiryDate,
    this.currentSubscriptionExtraResidentContracts,
    this.currentSubscriptionPaymentStatus,
    this.currentSubscriptionPaymentDate,
    this.currentSubscriptionPaymentMethod,
    this.currentSubscriptionCalculation,
    this.totalPurchasedResidentContractsCreationCount,
    this.availableResidentContractsCreationCount,
    this.freeResidentContractsCount,
    this.usedResidentContractsCount,
    this.totalResidentContractsCount,
    this.carpetArea,
    this.noOfFloors,
    this.gender,
    this.locality,
    this.pincode,
    this.ownerAddress,
    this.electricityBillType,
    this.waterBillType,
    this.gasBillType,
    this.internetBillType,
    this.whetherParkingAvailable,
    this.parkingType,
    this.parkingSlots,
    this.parkingCharges,
    this.metroOrBusStation,
    this.hospital,
    this.schoolOrCollege,
    this.shoppingMall,
    this.restaurant,
    this.atmOrBank,
    this.preferredTenantType,
    this.petPolicy,
    this.smokingPolicy,
    this.visitorsPolicy,
    this.subscriptionExpired,
    this.whetherVerifiedPlus,
    this.totalLeads,
    this.totalUnseenLeads,
  });

  factory PropertyData.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? rawImages =
        (json['Images'] as List<dynamic>?) ??
        (json['Property_Image_Array_Information'] as List<dynamic>?);
    final List<String>? imagesList = rawImages
        ?.map((dynamic e) {
          if (e is Map<String, dynamic>) {
            return e['Image_Original_URL'] as String? ??
                e['Image_URL'] as String? ??
                '';
          }
          return e.toString();
        })
        .where((String value) => value.isNotEmpty)
        .toList();
    final List<String>? imageIds = rawImages
        ?.map((dynamic e) {
          if (e is Map<String, dynamic>) {
            return e['ImageID'] as String? ?? '';
          }
          return '';
        })
        .where((String value) => value.isNotEmpty)
        .toList();
    final List<int>? amenityIds = (json['Amenities'] as List<dynamic>?)
        ?.map((dynamic e) => (e as num?)?.toInt() ?? 0)
        .where((int value) => value > 0)
        .toList();
    final String? amenitiesValue = switch (json['Amenities']) {
      String value => value,
      List<dynamic> value => value.map((dynamic item) => '$item').join(', '),
      _ => null,
    };
    final Map<String, dynamic>? floorPlanDocument =
        json['Floor_Plan_Document_Information'] as Map<String, dynamic>?;
    final Map<String, dynamic>? currentSubscription =
        json['Current_Subscription_Data'] as Map<String, dynamic>?;
    final Map<String, dynamic>? subscriptionData =
        currentSubscription?['Subsciption_Data'] as Map<String, dynamic>? ??
        currentSubscription?['Subscription_Data'] as Map<String, dynamic>?;

    return PropertyData(
      propertyId: json['PropertyID'] as String? ?? json['_id'] as String? ?? '',
      title:
          json['Title'] as String? ?? json['Property_Title'] as String? ?? '',
      description:
          json['Description'] as String? ??
          json['Property_Description'] as String? ??
          '',
      propertyType: json['Property_Type'] as int? ?? 1,
      propertyStatus: json['Property_Status'] as int? ?? 1,
      isActive:
          (json['Status'] as bool?) ?? (json['Is_Active'] as bool?) ?? true,
      rent:
          (json['Rent'] as num?)?.toDouble() ??
          (json['Monthly_Rent'] as num?)?.toDouble() ??
          0,
      deposit:
          (json['Deposit'] as num?)?.toDouble() ??
          (json['Security_Deposit'] as num?)?.toDouble() ??
          0,
      imageUrl:
          json['Image_Original_URL'] as String? ??
          (imagesList != null && imagesList.isNotEmpty
              ? imagesList.first
              : null),
      locationAddress: json['Location_Address'] as String?,
      address:
          json['Address'] as String? ??
          json['Full_Address'] as String? ??
          json['Owner_Address'] as String?,
      bedrooms: json['Bedrooms'] as int?,
      bathrooms: json['Bathrooms'] as int?,
      balconies: json['Balconies'] as int?,
      floor: json['Floor'] as int? ?? json['Floor_No'] as int?,
      area:
          (json['Area'] as num?)?.toDouble() ??
          (json['Total_Area'] as num?)?.toDouble() ??
          (json['Carpet_Area'] as num?)?.toDouble(),
      furnishedType: json['Furnished_Type'] as int?,
      facing: json['Facing'] as String?,
      facingDirectionType: json['Facing_Direction_Type'] as int?,
      amenities: amenitiesValue,
      category: json['Category'] as int? ?? json['Category_Type'] as int?,
      subType: json['Sub_Type'] as int?,
      pgSharingType: json['PG_Sharing_Type'] as int?,
      flatUnitNo: json['Flat_Or_Unit_No'] as String?,
      maintenance:
          (json['Maintenance'] as num?)?.toDouble() ??
          (json['Maintainance_Charge'] as num?)?.toDouble(),
      brokerage:
          (json['Brokerage'] as num?)?.toDouble() ??
          (json['Brokerage_Percentage'] as num?)?.toDouble(),
      availableFrom: json['Available_From'] as String?,
      ownerName: json['Owner_Name'] as String?,
      ownerPhone: json['Owner_Phone'] as String?,
      ownerEmail: json['Owner_Email'] as String?,
      state:
          json['State'] as String? ??
          (json['State_Information'] as Map<String, dynamic>?)?['State_Name']
              as String?,
      city:
          json['City'] as String? ??
          (json['City_Information'] as Map<String, dynamic>?)?['City_Name']
              as String?,
      images: imagesList,
      imageIds: imageIds,
      noOfVacancy:
          json['No_Of_Vacancy'] as int? ??
          json['Available_Resident_Contracts_Creation_Count'] as int?,
      latitude: (json['Latitude'] as num?)?.toDouble(),
      longitude: (json['Longitude'] as num?)?.toDouble(),
      stateId: json['StateID'] as String?,
      cityId: json['CityID'] as String?,
      amenityIds: amenityIds,
      propertyRulesDescription: json['Property_Rules_Description'] as String?,
      floorPlanDocumentId: floorPlanDocument?['DocumentID'] as String?,
      floorPlanDocumentUrl: floorPlanDocument?['Document_URL'] as String?,
      isSubscribed:
          _readBool(json['Whether_Subscribed']) ??
          _readBool(json['Whether_Currently_Subscribed']) ??
          false,
      wasSubscribedAtLeastOnce:
          _readBool(json['Whether_Subscribed_Atleast_Once']) ?? false,
      currentVendorSubscriptionId:
          currentSubscription?['Vendor_SubscriptionID'] as String?,
      currentSubscriptionId:
          currentSubscription?['SubscriptionID'] as String? ??
          subscriptionData?['SubscriptionID'] as String? ??
          currentSubscription?['Vendor_SubscriptionID'] as String?,
      currentSubscriptionTitle: subscriptionData?['Title'] as String?,
      currentSubscriptionDescription:
          subscriptionData?['Description'] as String?,
      currentSubscriptionPrice: (subscriptionData?['Price'] as num?)
          ?.toDouble(),
      currentSubscriptionDuration: (subscriptionData?['Duration'] as num?)
          ?.toInt(),
      currentSubscriptionExpiryDate:
          currentSubscription?['Subscription_Expiry_Date'] as String?,
      currentSubscriptionExtraResidentContracts:
          _firstOptionalInt(<dynamic>[
            currentSubscription?['Extra_Resident_Contracts'],
            currentSubscription?['Extra_Resident_Contracts_Count'],
            currentSubscription?['Extra_Contracts_Count'],
            currentSubscription?['Purchased_Resident_Contracts_Count'],
          ]),
      currentSubscriptionPaymentStatus:
          (currentSubscription?['Payment_Status'] as num?)?.toInt(),
      currentSubscriptionPaymentDate:
          currentSubscription?['Payment_Date'] as String?,
      currentSubscriptionPaymentMethod:
          currentSubscription?['Payment_Method'] as String?,
      currentSubscriptionCalculation:
          currentSubscription?['Calculation_Data'] is Map<String, dynamic>
          ? SubscriptionCalculationData.fromJson(
              currentSubscription!['Calculation_Data'] as Map<String, dynamic>,
            )
          : null,
      totalPurchasedResidentContractsCreationCount:
          _firstOptionalInt(<dynamic>[
            json['Total_Purchased_Resident_Contracts_Creation_Count'],
            json['Total_Purchased_Resident_Contracts_Count'],
            json['Purchased_Resident_Contracts_Count'],
            json['Extra_Resident_Contracts'],
            json['Extra_Resident_Contracts_Count'],
            json['Extra_Contracts_Count'],
          ]),
      availableResidentContractsCreationCount:
          _firstOptionalInt(<dynamic>[
            json['Available_Resident_Contracts_Creation_Count'],
            json['Available_Resident_Contracts_Count'],
            json['Available_Contracts_Count'],
            json['Total_Available_Contracts'],
          ]),
      freeResidentContractsCount:
          _firstOptionalInt(<dynamic>[
            json['Total_Free_Resident_Contracts_Count'],
            json['Free_Resident_Contracts_Count'],
            json['Free_Contracts_Count'],
          ]),
      usedResidentContractsCount:
          _firstOptionalInt(<dynamic>[
            json['Used_Resident_Contracts_Creation_Count'],
            json['Used_Resident_Contracts_Count'],
            json['Active_Rental_Contracts_Count'],
            json['Active_Resident_Contracts_Count'],
            json['Used_Contracts_Count'],
          ]),
      totalResidentContractsCount:
          _firstOptionalInt(<dynamic>[
            json['Total_Resident_Contracts_Creation_Count'],
            json['Total_Resident_Contracts_Count'],
            json['Total_Available_Contracts'],
            json['Total_Contracts_Count'],
          ]),
      carpetArea: (json['Carpet_Area'] as num?)?.toDouble(),
      noOfFloors: json['No_Of_Floors'] as int?,
      gender: json['Gender'] as int?,
      locality: json['Locality'] as String?,
      pincode: json['Pincode'] as String?,
      ownerAddress: json['Owner_Address'] as String?,
      electricityBillType: json['Electricity_Bill_Type'] as int?,
      waterBillType: json['Water_Bill_Type'] as int?,
      gasBillType: json['Gas_Bill_Type'] as int?,
      internetBillType: json['Internet_Bill_Type'] as int?,
      whetherParkingAvailable: _readBool(json['Whether_Parking_Available']),
      parkingType: json['Parking_Type'] as int?,
      parkingSlots: json['Parking_Slots'] as int?,
      parkingCharges: (json['Parking_Charges'] as num?)?.toDouble(),
      metroOrBusStation: json['Metro_Or_Bus_Station'] as String?,
      hospital: json['Hospital'] as String?,
      schoolOrCollege: json['School_Or_College'] as String?,
      shoppingMall: json['Shopping_Mall'] as String?,
      restaurant: json['Restaurant'] as String?,
      atmOrBank: json['ATM_Or_Bank'] as String?,
      preferredTenantType: json['Preferred_Tenant_Type'] as int?,
      petPolicy: json['Pet_Policy'] as int?,
      smokingPolicy: json['Smoking_Policy'] as int?,
      visitorsPolicy: json['Visitors_Policy'] as int?,
      subscriptionExpired: _readBool(json['Subscription_Expired']),
      whetherVerifiedPlus: _readBool(json['Whether_Verified_Plus']),
      totalLeads: json['Total_Leads'] as int?,
      totalUnseenLeads: json['Total_Unseen_Leads'] as int?,
    );
  }

  final String propertyId;
  final String title;
  final String description;
  final int propertyType;
  final int propertyStatus;
  final bool isActive;
  final double rent;
  final double deposit;
  final String? imageUrl;
  final String? locationAddress;
  final String? address;
  final int? bedrooms;
  final int? bathrooms;
  final int? balconies;
  final int? floor;
  final double? area;
  final int? furnishedType;
  final String? facing;
  final int? facingDirectionType;
  final String? amenities;
  final int? category;
  final int? subType;
  final int? pgSharingType;
  final String? flatUnitNo;
  final double? maintenance;
  final double? brokerage;
  final String? availableFrom;
  final String? ownerName;
  final String? ownerPhone;
  final String? ownerEmail;
  final String? state;
  final String? city;
  final List<String>? images;
  final List<String>? imageIds;
  final int? noOfVacancy;
  final double? latitude;
  final double? longitude;
  final String? stateId;
  final String? cityId;
  final List<int>? amenityIds;
  final String? propertyRulesDescription;
  final String? floorPlanDocumentId;
  final String? floorPlanDocumentUrl;
  final bool isSubscribed;
  final bool wasSubscribedAtLeastOnce;
  final String? currentVendorSubscriptionId;
  final String? currentSubscriptionId;
  final String? currentSubscriptionTitle;
  final String? currentSubscriptionDescription;
  final double? currentSubscriptionPrice;
  final int? currentSubscriptionDuration;
  final String? currentSubscriptionExpiryDate;
  final int? currentSubscriptionExtraResidentContracts;
  final int? currentSubscriptionPaymentStatus;
  final String? currentSubscriptionPaymentDate;
  final String? currentSubscriptionPaymentMethod;
  final SubscriptionCalculationData? currentSubscriptionCalculation;
  final int? totalPurchasedResidentContractsCreationCount;
  final int? availableResidentContractsCreationCount;
  final int? freeResidentContractsCount;
  final int? usedResidentContractsCount;
  final int? totalResidentContractsCount;
  final double? carpetArea;
  final int? noOfFloors;
  final int? gender;
  final String? locality;
  final String? pincode;
  final String? ownerAddress;
  final int? electricityBillType;
  final int? waterBillType;
  final int? gasBillType;
  final int? internetBillType;
  final bool? whetherParkingAvailable;
  final int? parkingType;
  final int? parkingSlots;
  final double? parkingCharges;
  final String? metroOrBusStation;
  final String? hospital;
  final String? schoolOrCollege;
  final String? shoppingMall;
  final String? restaurant;
  final String? atmOrBank;
  final int? preferredTenantType;
  final int? petPolicy;
  final int? smokingPolicy;
  final int? visitorsPolicy;
  final bool? subscriptionExpired;
  final bool? whetherVerifiedPlus;
  final int? totalLeads;
  final int? totalUnseenLeads;

  PropertyRecord toPropertyRecord() {
    return PropertyRecord(
      id: propertyId,
      title: title,
      type: _mapPropertyType(propertyType),
      status: _mapPropertyStatus(propertyStatus),
      isActive: isActive,
      rent: rent,
      deposit: deposit,
      imageUrl:
          imageUrl ??
          (images != null && images!.isNotEmpty ? images!.first : null),
      address: address,
      bedrooms: bedrooms,
      bathrooms: bathrooms,
      isSubscribed: isSubscribed,
      subscriptionExpired: subscriptionExpired,
      whetherVerifiedPlus: whetherVerifiedPlus,
      noOfVacancy: noOfVacancy,
      currentSubscriptionTitle: currentSubscriptionTitle,
      currentSubscriptionPrice: currentSubscriptionPrice,
      currentSubscriptionDuration: currentSubscriptionDuration,
      currentSubscriptionExpiryDate: currentSubscriptionExpiryDate,
      totalLeads: totalLeads,
      totalUnseenLeads: totalUnseenLeads,
      totalPurchasedResidentContractsCreationCount:
          totalPurchasedResidentContractsCreationCount,
      freeResidentContractsCount: freeResidentContractsCount,
      usedResidentContractsCount: usedResidentContractsCount,
      totalResidentContractsCount: totalResidentContractsCount,
      availableResidentContractsCreationCount:
          availableResidentContractsCreationCount,
    );
  }

  static PropertyStatus _mapPropertyStatus(int status) {
    return switch (status) {
      1 => PropertyStatus.pending,
      2 => PropertyStatus.approved,
      3 => PropertyStatus.rejected,
      4 => PropertyStatus.inactive,
      _ => PropertyStatus.pending,
    };
  }

  static String _mapPropertyType(int type) {
    return switch (type) {
      1 => 'Apartment',
      2 => 'Villa',
      3 => 'PG',
      4 => 'Commercial',
      _ => 'Property',
    };
  }
}

// ---------------------------------------------------------------------------
// Rental Contract
// ---------------------------------------------------------------------------

class ContractDocumentData {
  const ContractDocumentData({
    required this.documentId,
    required this.documentName,
    required this.documentUrl,
  });

  factory ContractDocumentData.fromJson(Map<String, dynamic> json) {
    return ContractDocumentData(
      documentId: json['DocumentID'] as String? ?? '',
      documentName: json['Document_Name'] as String? ?? 'Document',
      documentUrl: json['Document_URL'] as String? ?? '',
    );
  }

  final String documentId;
  final String documentName;
  final String documentUrl;

  ContractDocumentRecord toRecord() {
    return ContractDocumentRecord(
      documentId: documentId,
      documentName: documentName,
      documentUrl: documentUrl,
    );
  }
}

class WhatsAppTemplateData {
  const WhatsAppTemplateData({
    required this.templateId,
    required this.templateName,
    required this.templateCode,
    required this.templateDescription,
    required this.templateVariables,
  });

  factory WhatsAppTemplateData.fromJson(Map<String, dynamic> json) {
    return WhatsAppTemplateData(
      templateId: json['Template_ID'] as int? ?? 0,
      templateName: json['Template_Name'] as String? ?? '',
      templateCode: json['Template_Code'] as String? ?? '',
      templateDescription: json['Template_Description'] as String? ?? '',
      templateVariables:
          ((json['Template_Variables'] as List<dynamic>?) ?? const <dynamic>[])
              .map((dynamic item) => item.toString())
              .toList(),
    );
  }

  final int templateId;
  final String templateName;
  final String templateCode;
  final String templateDescription;
  final List<String> templateVariables;
}

class RentalContractData {
  const RentalContractData({
    required this.contractId,
    required this.tenantName,
    required this.ownerName,
    required this.propertyTitle,
    required this.rent,
    required this.deposit,
    required this.startDate,
    required this.endDate,
    required this.contractStatus,
    required this.isActive,
    this.flatNo,
    this.tenantPhone,
    this.tenantEmail,
    this.tenantImageUrl,
    this.ownerPhone,
    this.ownerEmail,
    this.ownerAddress,
    this.tokenAmount,
    this.maintenanceAmount,
    this.billDay,
    this.specialTerms,
    this.propertyId,
    this.tenantStatus,
    this.vacateDate,
    this.tenantIdProof,
    this.tenantAddressProof,
    this.ownerIdProof,
    this.ownerPropertyOwnershipProof,
    this.ownerBankProof,
    this.whetherMaintenanceIncluded,
    this.whetherFirstMonthRentPaid,
    this.whetherSecurityDepositPaid,
  });

  factory RentalContractData.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? readMap(String key) {
      final dynamic value = json[key];
      return value is Map<String, dynamic> ? value : null;
    }

    final Map<String, dynamic>? propertyData = readMap('Property_Data');
    final Map<String, dynamic>? tenantData =
        readMap('Tenant_Data') ??
        readMap('Tenant_Vendor_Data') ??
        readMap('Tenant_Vendor_Information') ??
        readMap('Tenant_Information') ??
        readMap('Tenant_User_Data') ??
        readMap('User_Information') ??
        readMap('Vendor_Information');
    final Map<String, dynamic> tenantImageSource = <String, dynamic>{
      ...?tenantData,
      'Tenant_Data': json['Tenant_Data'],
      'Tenant_Vendor_Data': json['Tenant_Vendor_Data'],
      'Tenant_Vendor_Information': json['Tenant_Vendor_Information'],
      'Tenant_Vendor_Details': json['Tenant_Vendor_Details'],
      'Tenant_Information': json['Tenant_Information'],
      'Tenant_User_Data': json['Tenant_User_Data'],
      'Tenant_User_Information': json['Tenant_User_Information'],
      'Vendor_Data': json['Vendor_Data'],
      'Vendor_Information': json['Vendor_Information'],
      'User_Data': json['User_Data'],
      'User_Information': json['User_Information'],
      'Profile_Information': json['Profile_Information'],
      'Tenant_Profile_ImageID': json['Tenant_Profile_ImageID'],
      'Tenant_Profile_Image_ID': json['Tenant_Profile_Image_ID'],
      'Tenant_ImageID': json['Tenant_ImageID'],
      'Tenant_Image_ID': json['Tenant_Image_ID'],
      'Tenant_Profile_PhotoID': json['Tenant_Profile_PhotoID'],
      'Tenant_Profile_Photo_ID': json['Tenant_Profile_Photo_ID'],
      'Profile_ImageID': json['Profile_ImageID'],
      'Profile_Image_ID': json['Profile_Image_ID'],
      'Profile_PhotoID': json['Profile_PhotoID'],
      'Profile_Photo_ID': json['Profile_Photo_ID'],
      'Tenant_Profile_Image_URL': json['Tenant_Profile_Image_URL'],
      'Tenant_Image_URL': json['Tenant_Image_URL'],
      'Tenant_Profile_Photo_URL': json['Tenant_Profile_Photo_URL'],
      'Tenant_Photo_URL': json['Tenant_Photo_URL'],
      'Tenant_Profile_Image_Generation_Name':
          json['Tenant_Profile_Image_Generation_Name'],
      'Tenant_Image_Generation_Name': json['Tenant_Image_Generation_Name'],
      'Profile_Image_URL': json['Profile_Image_URL'],
      'Profile_Photo_URL': json['Profile_Photo_URL'],
      'Top_Level_Tenant_Image_Information': json['Tenant_Image_Information'],
      'Top_Level_Tenant_Profile_Image_Information':
          json['Tenant_Profile_Image_Information'],
      'Top_Level_Tenant_Vendor_Image_Information':
          json['Tenant_Vendor_Image_Information'],
      'Profile_Image_Information': json['Profile_Image_Information'],
      'Profile_Photo_Information': json['Profile_Photo_Information'],
      'Profile_Photo_Data': json['Profile_Photo_Data'],
    };
    final List<String> tenantImageKeys = <String>[
      'Tenant_Profile_Image_Information',
      'Tenant_Image_Information',
      'Tenant_Vendor_Image_Information',
      'Tenant_Profile_Image_Data',
      'Tenant_Vendor_Profile_Image_Information',
      'Tenant_Vendor_Profile_Image_Data',
      'Tenant_Profile_Photo_Information',
      'Tenant_Profile_Photo_Data',
      'Tenant_Vendor_Profile_Photo_Information',
      'Tenant_Vendor_Profile_Photo_Data',
      'Tenant_Profile_Image',
      'Tenant_Image',
      'Tenant_Profile_Photo',
      'Tenant_Photo',
      'Tenant_Profile_Picture',
      'Profile_Photo',
      'Profile_Picture',
      'Avatar',
      'Tenant_Profile_Image_URL',
      'Tenant_Image_URL',
      'Tenant_Profile_Photo_URL',
      'Tenant_Photo_URL',
      'Profile_Photo_URL',
      'Tenant_Vendor_Information',
      'Tenant_Vendor_Details',
      'Tenant_Vendor_Data',
      'Tenant_Information',
      'Tenant_User_Data',
      'Tenant_User_Information',
      'Tenant_Data',
      'Vendor_Information',
      'Vendor_Data',
      'User_Information',
      'User_Data',
      'Profile_Information',
      'Profile_Image_Information',
      'Profile_Image_Data',
      'Profile_Photo_Information',
      'Profile_Photo_Data',
      'Profile_Image_URL',
      'Top_Level_Tenant_Image_Information',
      'Top_Level_Tenant_Profile_Image_Information',
      'Top_Level_Tenant_Vendor_Image_Information',
    ];
    final String? tenantImageUrl =
        _firstImageUrl(tenantImageSource, tenantImageKeys) ??
        _readImageUrl(tenantImageSource);
    final String? tenantImageId =
        _firstImageId(tenantImageSource, tenantImageKeys) ??
        _readImageId(tenantImageSource);
    return RentalContractData(
      contractId:
          json['Rental_ContractID'] as String? ?? json['_id'] as String? ?? '',
      tenantName: json['Tenant_Name'] as String? ?? '',
      ownerName: json['Owner_Name'] as String? ?? '',
      propertyTitle:
          json['Property_Title'] as String? ??
          propertyData?['Property_Title'] as String? ??
          json['Title'] as String? ??
          '',
      rent:
          (json['Rent'] as num?)?.toDouble() ??
          (json['Monthly_Rent'] as num?)?.toDouble() ??
          0,
      deposit:
          (json['Deposit'] as num?)?.toDouble() ??
          (json['Security_Deposit'] as num?)?.toDouble() ??
          0,
      startDate:
          DateTime.tryParse(
            json['Contract_Start_Date'] as String? ??
                json['Start_Date'] as String? ??
                '',
          ) ??
          DateTime.now(),
      endDate:
          DateTime.tryParse(
            json['Contract_End_Date'] as String? ??
                json['End_Date'] as String? ??
                '',
          ) ??
          DateTime.now(),
      contractStatus:
          (json['Rental_Contract_Status'] as num?)?.toInt() ??
          (json['Contract_Status'] as num?)?.toInt() ??
          1,
      isActive:
          (json['Status'] as bool?) ?? (json['Is_Active'] as bool?) ?? true,
      flatNo:
          json['Flat_Or_Unit_No'] as String? ??
          propertyData?['Flat_Or_Unit_No'] as String?,
      tenantPhone:
          json['Tenant_PhoneNumber'] as String? ??
          json['Tenant_Phone'] as String?,
      tenantEmail: json['Tenant_EmailID'] as String?,
      tenantImageUrl: tenantImageUrl ?? _imageIdReference(tenantImageId),
      ownerPhone:
          json['Owner_PhoneNumber'] as String? ??
          json['Owner_Phone'] as String?,
      ownerEmail: json['Owner_EmailID'] as String?,
      ownerAddress: json['Owner_Address'] as String?,
      tokenAmount: (json['Token_Amount'] as num?)?.toDouble(),
      maintenanceAmount:
          (json['Maintainance_Charge'] as num?)?.toDouble() ??
          (json['Maintenance_Amount'] as num?)?.toDouble(),
      billDay: json['Bill_Day'] as int?,
      specialTerms: json['Special_Terms'] as String?,
      propertyId: json['PropertyID'] as String?,
      tenantStatus: json['Tenant_Status'] as int?,
      vacateDate: DateTime.tryParse(json['Vacate_Date'] as String? ?? ''),
      tenantIdProof: _parseDocument(
        json['Tenant_ID_Proof_Information'] as Map<String, dynamic>?,
      ),
      tenantAddressProof: _parseDocument(
        json['Tenant_Address_Proof_Information'] as Map<String, dynamic>?,
      ),
      ownerIdProof: _parseDocument(
        json['Owner_ID_Proof_Information'] as Map<String, dynamic>?,
      ),
      ownerPropertyOwnershipProof: _parseDocument(
        json['Owner_Property_Ownership_Proof_Information']
            as Map<String, dynamic>?,
      ),
      ownerBankProof: _parseDocument(
        json['Owner_Bank_Proof_Information'] as Map<String, dynamic>?,
      ),
      whetherMaintenanceIncluded:
          json['Whether_Maintainance_Included'] as bool?,
      whetherFirstMonthRentPaid: json['Whether_First_Month_Rent_Paid'] as bool?,
      whetherSecurityDepositPaid: json['Whether_Secrity_Deposit_Paid'] as bool?,
    );
  }

  final String contractId;
  final String tenantName;
  final String ownerName;
  final String propertyTitle;
  final double rent;
  final double deposit;
  final DateTime startDate;
  final DateTime endDate;
  final int contractStatus;
  final bool isActive;
  final String? flatNo;
  final String? tenantPhone;
  final String? tenantEmail;
  final String? tenantImageUrl;
  final String? ownerPhone;
  final String? ownerEmail;
  final String? ownerAddress;
  final double? tokenAmount;
  final double? maintenanceAmount;
  final int? billDay;
  final String? specialTerms;
  final String? propertyId;
  final int? tenantStatus;
  final DateTime? vacateDate;
  final ContractDocumentData? tenantIdProof;
  final ContractDocumentData? tenantAddressProof;
  final ContractDocumentData? ownerIdProof;
  final ContractDocumentData? ownerPropertyOwnershipProof;
  final ContractDocumentData? ownerBankProof;
  final bool? whetherMaintenanceIncluded;
  final bool? whetherFirstMonthRentPaid;
  final bool? whetherSecurityDepositPaid;

  RentalContractRecord toContractRecord() {
    return RentalContractRecord(
      id: contractId,
      tenantName: tenantName,
      ownerName: ownerName,
      propertyTitle: propertyTitle,
      rent: rent,
      deposit: deposit,
      startDate: startDate,
      endDate: endDate,
      status: _mapContractStatus(contractStatus, tenantStatus: tenantStatus),
      isActive: isActive,
      flatNo: flatNo,
      tenantPhone: tenantPhone,
      tenantEmail: tenantEmail,
      tenantImageUrl: tenantImageUrl,
      ownerPhone: ownerPhone,
      ownerEmail: ownerEmail,
      ownerAddress: ownerAddress,
      tokenAmount: tokenAmount,
      maintenanceAmount: maintenanceAmount,
      billDay: billDay,
      specialTerms: specialTerms,
      propertyId: propertyId,
      tenantStatus: tenantStatus,
      vacateDate: vacateDate,
      tenantIdProof: tenantIdProof?.toRecord(),
      tenantAddressProof: tenantAddressProof?.toRecord(),
      ownerIdProof: ownerIdProof?.toRecord(),
      ownerPropertyOwnershipProof: ownerPropertyOwnershipProof?.toRecord(),
      ownerBankProof: ownerBankProof?.toRecord(),
      whetherMaintenanceIncluded: whetherMaintenanceIncluded,
      whetherFirstMonthRentPaid: whetherFirstMonthRentPaid,
      whetherSecurityDepositPaid: whetherSecurityDepositPaid,
    );
  }

  static ContractDocumentData? _parseDocument(Map<String, dynamic>? json) {
    if (json == null || (json['Document_URL'] as String? ?? '').isEmpty) {
      return null;
    }
    return ContractDocumentData.fromJson(json);
  }

  static ContractStatus _mapContractStatus(int status, {int? tenantStatus}) {
    if (status == 3) {
      return ContractStatus.closed;
    }
    if (status == 2) {
      return ContractStatus.expired;
    }
    if (tenantStatus == 1 || status == 4) {
      return ContractStatus.readyToVacate;
    }
    return switch (status) {
      1 => ContractStatus.active,
      _ => ContractStatus.active,
    };
  }
}

// ---------------------------------------------------------------------------
// Block & Building
// ---------------------------------------------------------------------------

class BlockData {
  const BlockData({
    required this.blockId,
    required this.name,
    required this.societyId,
    this.status = true,
  });

  factory BlockData.fromJson(Map<String, dynamic> json) {
    return BlockData(
      blockId: json['BlockID'] as String? ?? json['_id'] as String? ?? '',
      name: json['Name'] as String? ?? '',
      societyId: json['SocietyID'] as String? ?? '',
      status: json['Status'] as bool? ?? (json['Is_Active'] as bool? ?? true),
    );
  }

  final String blockId;
  final String name;
  final String societyId;
  final bool status;
}

class BuildingData {
  const BuildingData({
    required this.buildingId,
    required this.name,
    required this.societyId,
    this.blockId,
    this.status = true,
  });

  factory BuildingData.fromJson(Map<String, dynamic> json) {
    return BuildingData(
      buildingId: json['BuildingID'] as String? ?? json['_id'] as String? ?? '',
      name: json['Name'] as String? ?? '',
      societyId: json['SocietyID'] as String? ?? '',
      blockId: json['BlockID'] as String?,
      status: json['Status'] as bool? ?? (json['Is_Active'] as bool? ?? true),
    );
  }

  final String buildingId;
  final String name;
  final String societyId;
  final String? blockId;
  final bool status;
}

// ---------------------------------------------------------------------------
// Resident
// ---------------------------------------------------------------------------

class ResidentData {
  const ResidentData({
    required this.residentId,
    required this.name,
    required this.phone,
    required this.flatNo,
    required this.residentType,
    required this.isActive,
    this.email,
    this.flatType,
    this.rent,
    this.blockName,
    this.buildingName,
    this.blockId,
    this.buildingId,
    this.imageUrl,
  });

  factory ResidentData.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? blockData =
        json['Block_Data'] is Map<String, dynamic>
        ? json['Block_Data'] as Map<String, dynamic>
        : null;
    final Map<String, dynamic>? buildingData =
        json['Building_Data'] is Map<String, dynamic>
        ? json['Building_Data'] as Map<String, dynamic>
        : null;
    final Map<String, dynamic> residentImageSource = <String, dynamic>{
      ...json,
      'Resident_Data': json['Resident_Data'],
      'Vendor_Data': json['Vendor_Data'],
      'Vendor_Information': json['Vendor_Information'],
      'Tenant_Vendor_Data': json['Tenant_Vendor_Data'],
      'Tenant_Vendor_Information': json['Tenant_Vendor_Information'],
      'Tenant_Vendor_Details': json['Tenant_Vendor_Details'],
      'Resident_Vendor_Data': json['Resident_Vendor_Data'],
      'Resident_Vendor_Information': json['Resident_Vendor_Information'],
      'User_Data': json['User_Data'],
      'User_Information': json['User_Information'],
      'Resident_User_Data': json['Resident_User_Data'],
      'Resident_User_Information': json['Resident_User_Information'],
      'Tenant_Data': json['Tenant_Data'],
      'Tenant_Information': json['Tenant_Information'],
      'Tenant_User_Data': json['Tenant_User_Data'],
      'Tenant_User_Information': json['Tenant_User_Information'],
      'Profile_Data': json['Profile_Data'],
      'Profile_Information': json['Profile_Information'],
      'Top_Level_Profile_Image_Information': json['Profile_Image_Information'],
      'Top_Level_Resident_Profile_Image_Information':
          json['Resident_Profile_Image_Information'],
      'Top_Level_Resident_Image_Information':
          json['Resident_Image_Information'],
      'Top_Level_Tenant_Profile_Image_Information':
          json['Tenant_Profile_Image_Information'],
      'Top_Level_Tenant_Image_Information': json['Tenant_Image_Information'],
      'Top_Level_Vendor_Image_Information': json['Vendor_Image_Information'],
    };
    final List<String> residentImageKeys = <String>[
      'Profile_Image_Information',
      'Resident_Profile_Image_Information',
      'Resident_Image_Information',
      'Tenant_Profile_Image_Information',
      'Tenant_Image_Information',
      'Vendor_Image_Information',
      'User_Profile_Image_Information',
      'Profile_Image',
      'Profile_Photo',
      'Profile_Picture',
      'Avatar',
      'Resident_Profile_Photo',
      'Resident_Photo',
      'Resident_Profile_Picture',
      'Tenant_Profile_Photo',
      'Tenant_Photo',
      'Tenant_Profile_Picture',
      'Profile_Image_URL',
      'Profile_Photo_URL',
      'Resident_Profile_Image_URL',
      'Resident_Image_URL',
      'Resident_Profile_Photo_URL',
      'Resident_Photo_URL',
      'Tenant_Profile_Image_URL',
      'Tenant_Image_URL',
      'Tenant_Profile_Photo_URL',
      'Tenant_Photo_URL',
      'Image_Information',
      'Image_Information_Data',
      'Image_Data',
      'Images',
      'Image_Array',
      'Image_Information_Array',
      'Profile_Image_Data',
      'Profile_Photo_Information',
      'Profile_Photo_Data',
      'Resident_Profile_Image_Data',
      'Resident_Profile_Photo_Information',
      'Resident_Profile_Photo_Data',
      'Tenant_Profile_Image_Data',
      'Tenant_Profile_Photo_Information',
      'Tenant_Profile_Photo_Data',
      'Vendor_Data',
      'Vendor_Information',
      'Vendor_Profile_Image_Information',
      'Vendor_Profile_Image_Data',
      'Vendor_Profile_Photo_Information',
      'Vendor_Profile_Photo_Data',
      'Tenant_Vendor_Data',
      'Tenant_Vendor_Information',
      'Tenant_Vendor_Details',
      'Tenant_Vendor_Profile_Image_Information',
      'Tenant_Vendor_Profile_Photo_Information',
      'Resident_Vendor_Data',
      'Resident_Vendor_Information',
      'User_Data',
      'User_Information',
      'User_Profile_Image_Data',
      'User_Profile_Photo_Information',
      'User_Profile_Photo_Data',
      'Resident_User_Data',
      'Resident_User_Information',
      'Tenant_Data',
      'Tenant_Information',
      'Tenant_User_Data',
      'Tenant_User_Information',
      'Resident_Data',
      'Profile_Data',
      'Profile_Information',
      'Top_Level_Profile_Image_Information',
      'Top_Level_Resident_Profile_Image_Information',
      'Top_Level_Resident_Image_Information',
      'Top_Level_Tenant_Profile_Image_Information',
      'Top_Level_Tenant_Image_Information',
      'Top_Level_Vendor_Image_Information',
    ];
    final String? profileImageUrl = _firstImageUrl(
      residentImageSource,
      residentImageKeys,
    ) ?? _readImageUrl(residentImageSource);
    final String? profileImageId = _firstImageId(
      residentImageSource,
      residentImageKeys,
    ) ?? _readImageId(residentImageSource);

    String? readString(Map<String, dynamic>? source, String key) {
      final dynamic value = source?[key];
      if (value == null) {
        return null;
      }
      return value.toString();
    }

    String? firstNonEmpty(List<String?> values) {
      for (final String? value in values) {
        final String trimmed = value?.trim() ?? '';
        if (trimmed.isNotEmpty) {
          return trimmed;
        }
      }
      return null;
    }

    return ResidentData(
      residentId:
          json['Society_ResidentID'] as String? ?? json['_id'] as String? ?? '',
      name: json['Full_Name'] as String? ?? json['Name'] as String? ?? '',
      phone: json['Phone'] as String? ?? json['PhoneNumber'] as String? ?? '',
      flatNo:
          json['Flat_No'] as String? ??
          json['Flat_Or_Unit_No'] as String? ??
          '',
      residentType: json['Resident_Type'] as int? ?? 1,
      isActive: json['Is_Active'] as bool? ?? (json['Status'] as bool? ?? true),
      email: json['EmailID'] as String?,
      flatType: json['Flat_Type'] as int?,
      rent: (json['Monthly_Rent'] as num?)?.toDouble(),
      blockName: firstNonEmpty(<String?>[
        readString(json, 'Block_Name'),
        readString(blockData, 'Name'),
      ]),
      buildingName: firstNonEmpty(<String?>[
        readString(json, 'Building_Name'),
        readString(buildingData, 'Name'),
      ]),
      blockId: firstNonEmpty(<String?>[
        readString(json, 'BlockID'),
        readString(json, 'Block_ID'),
        readString(blockData, 'BlockID'),
        readString(blockData, '_id'),
        readString(buildingData, 'BlockID'),
        readString(buildingData, 'Block_ID'),
      ]),
      buildingId: firstNonEmpty(<String?>[
        readString(json, 'BuildingID'),
        readString(json, 'Building_ID'),
        readString(buildingData, 'BuildingID'),
        readString(buildingData, '_id'),
      ]),
      imageUrl: profileImageUrl ?? _imageIdReference(profileImageId),
    );
  }

  final String residentId;
  final String name;
  final String phone;
  final String flatNo;
  final int residentType;
  final bool isActive;
  final String? email;
  final int? flatType;
  final double? rent;
  final String? blockName;
  final String? buildingName;
  final String? blockId;
  final String? buildingId;
  final String? imageUrl;

  ResidentRecord toResidentRecord() {
    return ResidentRecord(
      id: residentId,
      name: name,
      phone: phone,
      flatNo: flatNo,
      residentType: residentType == 1
          ? ResidentType.owner
          : residentType == 3
          ? ResidentType.pgResident
          : ResidentType.tenant,
      status: isActive,
      email: email,
      flatType: _mapFlatType(flatType),
      rent: rent,
      blockName: blockName,
      buildingName: buildingName,
      blockId: blockId,
      buildingId: buildingId,
      imageUrl: imageUrl,
    );
  }

  static String? _mapFlatType(int? type) {
    return switch (type) {
      1 => '1 BHK',
      2 => '2 BHK',
      3 => '3 BHK',
      4 => '4 BHK',
      5 => 'Studio',
      6 => 'Duplex',
      7 => 'Penthouse',
      8 => 'Villa',
      _ => null,
    };
  }
}

// ---------------------------------------------------------------------------
// Bank Account
// ---------------------------------------------------------------------------

class BankAccountData {
  const BankAccountData({
    required this.accountId,
    required this.accountType,
    required this.holderName,
    required this.isDefault,
    required this.isActive,
    this.accountNumber,
    this.ifscCode,
    this.upiId,
    this.bankName,
    this.branchName,
    this.isVerified,
    this.createdAt,
  });

  factory BankAccountData.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? ifscDetails =
        json['IFSC_Details'] as Map<String, dynamic>?;

    return BankAccountData(
      accountId:
          json['BankAccountID'] as String? ??
          json['Bank_AccountID'] as String? ??
          json['_id'] as String? ??
          '',
      accountType: json['Account_Type'] as int? ?? 1,
      holderName:
          json['Account_Holder_Name'] as String? ??
          json['Holder_Name'] as String? ??
          '',
      isDefault:
          json['Whether_Default'] as bool? ??
          json['Is_Default'] as bool? ??
          false,
      isActive: json['Status'] as bool? ?? json['Is_Active'] as bool? ?? true,
      accountNumber: json['Account_Number'] as String?,
      ifscCode: json['IFSC_Code'] as String?,
      upiId: json['UPI_ID'] as String?,
      bankName:
          json['Bank_Name'] as String? ?? ifscDetails?['Bank_Name'] as String?,
      branchName:
          json['Branch_Name'] as String? ??
          ifscDetails?['Branch_Name'] as String?,
      isVerified: json['Whether_Verified'] as bool?,
      createdAt: DateTime.tryParse(
        json['createdAt'] as String? ?? json['created_at'] as String? ?? '',
      ),
    );
  }

  final String accountId;
  final int accountType; // 1=bank, 2=upi
  final String holderName;
  final bool isDefault;
  final bool isActive;
  final String? accountNumber;
  final String? ifscCode;
  final String? upiId;
  final String? bankName;
  final String? branchName;
  final bool? isVerified;
  final DateTime? createdAt;

  BankAccountRecord toBankAccountRecord() {
    final String masked = accountNumber != null && accountNumber!.length > 4
        ? '****${accountNumber!.substring(accountNumber!.length - 4)}'
        : accountNumber ?? '';

    return BankAccountRecord(
      id: accountId,
      type: accountType == 2 ? 'upi' : 'bank',
      holderName: holderName,
      isDefault: isDefault,
      status: isActive,
      maskedNumber: masked,
      ifscCode: ifscCode,
      upiId: upiId,
      bankName: bankName,
    );
  }
}

// ---------------------------------------------------------------------------
// Wallet Transaction
// ---------------------------------------------------------------------------

class WalletTransactionData {
  const WalletTransactionData({
    required this.transactionId,
    required this.type,
    required this.amount,
    required this.previousBalance,
    required this.newBalance,
    this.date,
    this.description,
  });

  factory WalletTransactionData.fromJson(Map<String, dynamic> json) {
    final String? rawTimestamp = json['created_at'] as String? ??
        json['createdAt'] as String? ??
        json['Transaction_Date'] as String? ??
        json['Date'] as String?;
    final DateTime? parsedTimestamp = _parseApiTimestamp(rawTimestamp);
    return WalletTransactionData(
      transactionId:
          json['TransactionID'] as String? ?? json['_id'] as String? ?? '',
      type: json['Transaction_Type'] as int? ?? 1,
      amount: (json['Amount'] as num?)?.toDouble() ?? 0,
      previousBalance: (json['Previous_Balance'] as num?)?.toDouble() ?? 0,
      newBalance: (json['New_Balance'] as num?)?.toDouble() ?? 0,
      date: parsedTimestamp,
      description: json['Description'] as String?,
    );
  }

  final String transactionId;
  final int type; // 1=credit, 2=debit
  final double amount;
  final double previousBalance;
  final double newBalance;
  final DateTime? date;
  final String? description;
}

// ---------------------------------------------------------------------------
// Withdrawal
// ---------------------------------------------------------------------------

class WithdrawalData {
  const WithdrawalData({
    required this.withdrawalId,
    required this.amount,
    required this.status,
    this.date,
    this.processedAt,
    this.previousBalance,
    this.newBalance,
    this.utr,
    this.failureReason,
    this.payoutMode,
    this.bankAccountName,
    this.bankAccountNumber,
    this.bankName,
    this.upiId,
    this.bankAccountType,
  });

  factory WithdrawalData.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? bankAccountDetails =
        json['Bank_Account_Details'] as Map<String, dynamic>?;
    final String? rawCreatedAt = json['created_at'] as String? ??
        json['createdAt'] as String? ??
        json['Withdrawal_Date'] as String? ??
        json['Date'] as String?;
    final String? rawProcessedAt = json['processed_at'] as String? ??
        json['Payout_Processed_At'] as String? ??
        json['payout_completed_at'] as String? ??
        json['updated_at'] as String?;

    return WithdrawalData(
      withdrawalId:
          json['WithdrawalID'] as String? ?? json['_id'] as String? ?? '',
      amount: (json['Amount'] as num?)?.toDouble() ?? 0,
      status: json['Withdrawal_Status'] as int? ?? 1,
      date: _parseApiTimestamp(rawCreatedAt),
      processedAt: _parseApiTimestamp(rawProcessedAt),
      previousBalance: (json['Previous_Balance'] as num?)?.toDouble(),
      newBalance: (json['New_Balance'] as num?)?.toDouble(),
      utr: json['UTR'] as String?,
      failureReason: json['Failure_Reason'] as String?,
      payoutMode: json['Payout_Mode'] as String?,
      bankAccountName:
          json['Bank_Account_Name'] as String? ??
          bankAccountDetails?['Account_Holder_Name'] as String?,
      bankAccountNumber:
          json['Bank_Account_Number'] as String? ??
          bankAccountDetails?['Account_Number'] as String?,
      bankName: bankAccountDetails?['Bank_Name'] as String?,
      upiId: bankAccountDetails?['UPI_ID'] as String?,
      bankAccountType: bankAccountDetails?['Account_Type'] as int?,
    );
  }

  final String withdrawalId;
  final double amount;
  final int status; // 1=pending, 2=success, 3=failed
  final DateTime? date;
  final DateTime? processedAt;
  final double? previousBalance;
  final double? newBalance;
  final String? utr;
  final String? failureReason;
  final String? payoutMode;
  final String? bankAccountName;
  final String? bankAccountNumber;
  final String? bankName;
  final String? upiId;
  final int? bankAccountType;
}

// ---------------------------------------------------------------------------
// Notification
// ---------------------------------------------------------------------------

class NotificationData {
  const NotificationData({
    required this.notificationId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.referenceType = '',
    this.referenceId = '',
    this.data = const <String, dynamic>{},
  });

  factory NotificationData.fromPropertyEnquiry(PropertyEnquiryData enquiry) {
    final String enquiryId = enquiry.enquiryId.trim();
    final String propertyTitle = enquiry.propertyTitle?.trim() ?? '';
    final String name = enquiry.name.trim();
    final String propertyTypeLabel = _propertyTypeLabel(enquiry.propertyType);
    final String subTypeLabel = _propertySubTypeLabel(
      enquiry.propertyType,
      enquiry.subType,
    );
    final String sharingTypeLabel = _pgSharingTypeLabel(enquiry.pgSharingType);
    final String propertyDisplayLabel = <String>[
      if (propertyTitle.isNotEmpty) propertyTitle,
      if (propertyTypeLabel.isNotEmpty) propertyTypeLabel,
      if (subTypeLabel.isNotEmpty) subTypeLabel,
      if (enquiry.propertyType == 3 && sharingTypeLabel.isNotEmpty)
        sharingTypeLabel,
    ].join(' - ');
    final String title = name.isEmpty
        ? 'New Property Enquiry'
        : 'New Property Enquiry - $name';

    final List<String> messageParts = <String>[
      if (name.isNotEmpty) 'Name: $name',
      if (enquiry.phone.trim().isNotEmpty) 'Mobile: ${enquiry.phone.trim()}',
      if ((enquiry.email ?? '').trim().isNotEmpty)
        'Email: ${(enquiry.email ?? '').trim()}',
      if (propertyDisplayLabel.isNotEmpty) 'Property: $propertyDisplayLabel',
      if ((enquiry.ownerName ?? '').trim().isNotEmpty)
        'Owner: ${(enquiry.ownerName ?? '').trim()}',
      'Status: ${enquiry.status == 2 ? 'Resolved' : 'New'}',
    ];

    return NotificationData(
      notificationId:
          'local-property-enquiry:${enquiryId.isNotEmpty ? enquiryId : '${name}_${enquiry.createdAt?.millisecondsSinceEpoch ?? 0}'}',
      title: title,
      message: messageParts.join('\n'),
      type: 'enquiry',
      isRead: false,
      createdAt: enquiry.createdAt ?? DateTime.now(),
      referenceType: 'property_enquiry',
      referenceId: enquiryId,
      data: <String, dynamic>{
        'Name': name,
        'FinalPhoneNumber': enquiry.phone.trim(),
        if ((enquiry.email ?? '').trim().isNotEmpty)
          'EmailID': (enquiry.email ?? '').trim(),
        if ((enquiry.propertyId ?? '').trim().isNotEmpty)
          'PropertyID': (enquiry.propertyId ?? '').trim(),
        if (propertyTitle.isNotEmpty) 'Property_Title': propertyTitle,
        if (enquiry.propertyType != null) 'Property_Type': enquiry.propertyType,
        if (propertyTypeLabel.isNotEmpty)
          'Property_Type_Label': propertyTypeLabel,
        if (enquiry.subType != null) 'Sub_Type': enquiry.subType,
        if (subTypeLabel.isNotEmpty) 'Sub_Type_Label': subTypeLabel,
        if (enquiry.pgSharingType != null)
          'PG_Sharing_Type': enquiry.pgSharingType,
        if (sharingTypeLabel.isNotEmpty)
          'PG_Sharing_Type_Label': sharingTypeLabel,
        if (propertyDisplayLabel.isNotEmpty)
          'Property_Display_Label': propertyDisplayLabel,
        if ((enquiry.ownerName ?? '').trim().isNotEmpty)
          'Owner_Name': (enquiry.ownerName ?? '').trim(),
        'Enquiry_Status': enquiry.status,
      },
    );
  }

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    final String referenceType = '${json['Reference_Type'] ?? ''}';
    final String rawType =
        '${json['Notification_Type'] ?? json['Type'] ?? 'general'}';
    final String normalizedType = _normalizeNotificationType(
      rawType,
      referenceType,
    );

    return NotificationData(
      notificationId:
          json['Vendor_NotificationID'] as String? ??
          json['NotificationID'] as String? ??
          json['_id'] as String? ??
          '',
      title: json['Title'] as String? ?? '',
      message: json['Message'] as String? ?? json['Body'] as String? ?? '',
      type: normalizedType,
      isRead:
          json['Whether_Read'] as bool? ?? json['Is_Read'] as bool? ?? false,
      createdAt:
          _parseApiTimestamp(
            json['createdAt'] as String? ??
                json['Created_At'] as String? ??
                json['created_at'] as String?,
          ) ??
          DateTime.now(),
      referenceType: referenceType,
      referenceId: '${json['Reference_ID'] ?? ''}',
      data: json['Data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['Data'] as Map<String, dynamic>)
          : const <String, dynamic>{},
    );
  }

  final String notificationId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final String referenceType;
  final String referenceId;
  final Map<String, dynamic> data;

  bool get isLocalPropertyEnquiry =>
      notificationId.startsWith('local-property-enquiry:');

  NotificationData copyWith({
    String? notificationId,
    String? title,
    String? message,
    String? type,
    bool? isRead,
    DateTime? createdAt,
    String? referenceType,
    String? referenceId,
    Map<String, dynamic>? data,
  }) {
    return NotificationData(
      notificationId: notificationId ?? this.notificationId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      referenceType: referenceType ?? this.referenceType,
      referenceId: referenceId ?? this.referenceId,
      data: data ?? this.data,
    );
  }

  NotificationRecord toNotificationRecord() {
    return NotificationRecord(
      id: notificationId,
      title: title,
      message: message,
      type: type,
      isRead: isRead,
      createdAt: createdAt,
    );
  }

  static String _normalizeNotificationType(
    String rawType,
    String referenceType,
  ) {
    final String normalizedReference = referenceType.toLowerCase().trim();
    final String normalizedRaw = rawType.toLowerCase().trim();

    if (normalizedReference.contains('incident') ||
        normalizedRaw.contains('security_alert') ||
        normalizedRaw.contains('securityalert')) {
      return 'security_alert';
    }
    if (normalizedReference.contains('bill')) return 'billing';
    if (normalizedReference.contains('rental_contract')) return 'contract';
    if (normalizedReference.contains('announcement')) return 'announcement';
    if (normalizedReference.contains('support_ticket')) return 'support';
    if (normalizedReference.contains('property_enquiry') ||
        normalizedReference.contains('enquiry') ||
        normalizedReference.contains('lead')) {
      return 'enquiry';
    }

    return switch (normalizedRaw) {
      '1' || '5' => 'billing',
      '2' => 'contract',
      '3' => 'announcement',
      '4' => 'support',
      '6' => 'enquiry',
      '7' => 'system',
      _ => normalizedRaw.isEmpty ? 'general' : normalizedRaw,
    };
  }
}

// ---------------------------------------------------------------------------
// Property Enquiry
// ---------------------------------------------------------------------------

class PropertyEnquiryData {
  const PropertyEnquiryData({
    required this.enquiryId,
    required this.name,
    required this.phone,
    required this.status,
    this.email,
    this.propertyId,
    this.propertyTitle,
    this.ownerName,
    this.ownerPhone,
    this.propertyImageUrl,
    this.propertyDisplayLabel,
    this.propertyType,
    this.subType,
    this.pgSharingType,
    this.createdAt,
  });

  factory PropertyEnquiryData.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? propertyData =
        json['Property_Data'] is Map<String, dynamic>
        ? json['Property_Data'] as Map<String, dynamic>
        : null;
    return PropertyEnquiryData(
      enquiryId:
          json['Property_EnquiryID'] as String? ??
          json['EnquiryID'] as String? ??
          json['_id'] as String? ??
          '',
      name: json['Name'] as String? ?? json['Full_Name'] as String? ?? '',
      phone:
          json['FinalPhoneNumber'] as String? ??
          json['PhoneNumber'] as String? ??
          json['Phone'] as String? ??
          '',
      // Website uses Enquiry_Status (1=New, 2=Resolved); legacy field is Status (bool)
      status: _readEnquiryStatus(json),
      email: json['EmailID'] as String? ?? json['Email'] as String?,
      propertyId:
          json['PropertyID'] as String? ??
          propertyData?['PropertyID'] as String? ??
          propertyData?['_id'] as String?,
      propertyTitle:
          json['Property_Title'] as String? ??
          json['Property_Name'] as String? ??
          json['Title'] as String? ??
          propertyData?['Property_Title'] as String? ??
          propertyData?['Title'] as String?,
      ownerName:
          json['Property_Owner_Name'] as String? ??
          json['Owner_Name'] as String? ??
          json['OwnerName'] as String? ??
          json['Owner'] as String? ??
          propertyData?['Owner_Name'] as String? ??
          propertyData?['OwnerName'] as String?,
      ownerPhone:
          json['Property_Owner_Phone'] as String? ??
          propertyData?['Owner_Phone'] as String?,
      propertyImageUrl:
          json['Property_Image_URL'] as String? ??
          json['Image_URL'] as String? ??
          propertyData?['Image_URL'] as String?,
      propertyDisplayLabel:
          json['Property_Display_Label'] as String? ??
          json['Property_Type_Label'] as String?,
      propertyType:
          _readOptionalInt(json['Property_Type']) ??
          _readOptionalInt(propertyData?['Property_Type']),
      subType:
          _readOptionalInt(json['Sub_Type']) ??
          _readOptionalInt(propertyData?['Sub_Type']),
      pgSharingType:
          _readOptionalInt(json['PG_Sharing_Type']) ??
          _readOptionalInt(propertyData?['PG_Sharing_Type']),
      createdAt: _parseApiTimestamp(
        json['Time'] as String? ??
            json['created_at'] as String? ??
            json['createdAt'] as String? ??
            json['Created_At'] as String? ??
            '',
      ),
    );
  }

  static int _readEnquiryStatus(Map<String, dynamic> json) {
    final int? explicitStatus = _readOptionalInt(
      json['Enquiry_Status'] ?? json['EnquiryStatus'],
    );
    if (explicitStatus == 1 || explicitStatus == 2) {
      return explicitStatus!;
    }

    final int? legacyNumericStatus = _readOptionalInt(json['Status']);
    if (legacyNumericStatus == 1 || legacyNumericStatus == 2) {
      return legacyNumericStatus!;
    }

    return 1;
  }

  final String enquiryId;
  final String name;
  final String phone;
  final int status;
  final String? email;
  final String? propertyId;
  final String? propertyTitle;
  final String? ownerName;
  final String? ownerPhone;
  final String? propertyImageUrl;
  final String? propertyDisplayLabel;
  final int? propertyType;
  final int? subType;
  final int? pgSharingType;
  final DateTime? createdAt;
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

String _propertySubTypeLabel(int? propertyType, int? subType) {
  return switch (propertyType) {
    1 => switch (subType) {
      1 => '1 BHK',
      2 => '2 BHK',
      3 => '3 BHK',
      4 => '4 BHK',
      5 => 'Studio',
      _ => '',
    },
    2 => switch (subType) {
      1 => '2 BHK Villa',
      2 => '3 BHK Villa',
      3 => '4 BHK Villa',
      4 => 'Duplex Villa',
      _ => '',
    },
    3 => switch (subType) {
      1 => 'Mens PG',
      2 => 'Womens PG',
      3 => 'Coliving',
      _ => '',
    },
    4 => switch (subType) {
      1 => 'Office',
      2 => 'Retail',
      3 => 'Ware House',
      4 => 'Show Room',
      _ => '',
    },
    _ => '',
  };
}

String _pgSharingTypeLabel(int? pgSharingType) {
  return switch (pgSharingType) {
    1 => 'Single Sharing',
    2 => 'Double Sharing',
    3 => 'Triple Sharing',
    4 => 'Quad Sharing',
    5 => 'Dorm',
    _ => '',
  };
}

// ---------------------------------------------------------------------------
// Society
// ---------------------------------------------------------------------------

class SocietyMaintenanceRates {
  const SocietyMaintenanceRates({
    this.oneBhk = 0,
    this.twoBhk = 0,
    this.threeBhk = 0,
    this.fourBhk = 0,
    this.villa = 0,
  });

  factory SocietyMaintenanceRates.fromJson(Map<String, dynamic>? json) {
    return SocietyMaintenanceRates(
      oneBhk: (json?['OneBHK'] as num?)?.toDouble() ?? 0,
      twoBhk: (json?['TwoBHK'] as num?)?.toDouble() ?? 0,
      threeBhk: (json?['ThreeBHK'] as num?)?.toDouble() ?? 0,
      fourBhk: (json?['FourBHK'] as num?)?.toDouble() ?? 0,
      villa: (json?['Villa'] as num?)?.toDouble() ?? 0,
    );
  }

  final double oneBhk;
  final double twoBhk;
  final double threeBhk;
  final double fourBhk;
  final double villa;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'OneBHK': oneBhk,
      'TwoBHK': twoBhk,
      'ThreeBHK': threeBhk,
      'FourBHK': fourBhk,
      'Villa': villa,
    };
  }
}

class SocietyBillingConfig {
  const SocietyBillingConfig({
    this.billGenerationDate = 1,
    this.paymentDueDays = 15,
  });

  factory SocietyBillingConfig.fromJson(Map<String, dynamic>? json) {
    return SocietyBillingConfig(
      billGenerationDate: json?['Bill_Generation_Date'] as int? ?? 1,
      paymentDueDays: json?['Payment_Due_Days'] as int? ?? 15,
    );
  }

  final int billGenerationDate;
  final int paymentDueDays;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'Bill_Generation_Date': billGenerationDate,
      'Payment_Due_Days': paymentDueDays,
    };
  }
}

class SocietyData {
  const SocietyData({
    required this.societyId,
    required this.name,
    required this.address,
    this.countryCode,
    this.phone,
    this.email,
    this.estYear,
    this.latitude,
    this.longitude,
    this.locationAddress,
    this.maintenanceRates = const SocietyMaintenanceRates(),
    this.billingConfig = const SocietyBillingConfig(),
    this.isActive = true,
    this.freeResidentsCount,
    this.purchasedResidentsCount,
    this.totalResidentsCreationCount,
    this.availableResidentsCreationCount,
    this.usedResidentsCreationCount,
    this.purchasedResidentsExpiryDate,
    this.totalResidents,
    this.activeResidents,
    this.walletInfo,
    this.updatedAt,
  });

  factory SocietyData.fromJson(Map<String, dynamic> json) {
    return SocietyData(
      societyId: json['SocietyID'] as String? ?? json['_id'] as String? ?? '',
      name: json['Name'] as String? ?? '',
      address: json['Address'] as String? ?? '',
      countryCode: json['CountryCode'] as String?,
      phone: json['PhoneNumber'] as String?,
      email: json['EmailID'] as String?,
      estYear: json['Est_Year']?.toString(),
      latitude: (json['Latitude'] as num?)?.toDouble(),
      longitude: (json['Longitude'] as num?)?.toDouble(),
      locationAddress: json['Location_Address'] as String?,
      maintenanceRates: SocietyMaintenanceRates.fromJson(
        json['Maintenance_Rates'] as Map<String, dynamic>?,
      ),
      billingConfig: SocietyBillingConfig.fromJson(
        json['Billing_Config'] as Map<String, dynamic>?,
      ),
      isActive: json['Status'] as bool? ?? true,
      freeResidentsCount: json['Total_Free_Society_Residents_Count'] as int?,
      purchasedResidentsCount:
          json['Total_Purchased_Residents_Creation_Count'] as int?,
      totalResidentsCreationCount:
          json['Total_Residents_Creation_Count'] as int?,
      availableResidentsCreationCount:
          json['Available_Residents_Creation_Count'] as int?,
      usedResidentsCreationCount: json['Used_Residents_Creation_Count'] as int?,
      purchasedResidentsExpiryDate:
          json['Purchased_Residents_Expiry_Date'] as String?,
      totalResidents: json['Total_Residents'] as int?,
      activeResidents: json['Active_Residents'] as int?,
      walletInfo: json['Wallet_Information'] is Map<String, dynamic>
          ? WalletSummaryData.fromJson(
              json['Wallet_Information'] as Map<String, dynamic>,
            )
          : null,
      updatedAt: _parseApiTimestamp(
        (json['updated_at'] ?? json['Updated_At'] ?? '').toString(),
      ),
    );
  }

  final String societyId;
  final String name;
  final String address;
  final String? countryCode;
  final String? phone;
  final String? email;
  final String? estYear;
  final double? latitude;
  final double? longitude;
  final String? locationAddress;
  final SocietyMaintenanceRates maintenanceRates;
  final SocietyBillingConfig billingConfig;
  final bool isActive;
  final int? freeResidentsCount;
  final int? purchasedResidentsCount;
  final int? totalResidentsCreationCount;
  final int? availableResidentsCreationCount;
  final int? usedResidentsCreationCount;
  final String? purchasedResidentsExpiryDate;
  final int? totalResidents;
  final int? activeResidents;
  final WalletSummaryData? walletInfo;
  final DateTime? updatedAt;
}
