import '../models/api_models.dart';
import '../models/app_models.dart';
import 'api_client.dart';
import 'api_config.dart';

class BillingService {
  BillingService._();

  /// Filter bills for the current tenant/vendor.
  static Future<({List<BillRecord> bills, int count})> filterTenantBills({
    int skip = 0,
    int limit = 50,
    BillStatus? statusFilter,
    String? search,
    int? billType,
  }) async {
    final result = await filterTenantBillsDetailed(
      skip: skip,
      limit: limit,
      statusFilter: statusFilter,
      search: search,
      billType: billType,
    );
    return (bills: result.bills, count: result.count);
  }

  static Future<
      ({
        List<BillRecord> bills,
        int count,
        double pendingAmount,
        double paidAmount,
        double overdueAmount,
      })> filterTenantBillsDetailed({
    int skip = 0,
    int limit = 50,
    BillStatus? statusFilter,
    String? search,
    int? billType,
  }) async {
    final ApiResponse response = await ApiClient.instance.post(
      ApiConfig.filterTenantBills,
      <String, dynamic>{
        'Skip': skip,
        'Limit': limit,
        'Whether_Bill_Status_Filter': statusFilter != null,
        if (statusFilter != null)
          'Bill_Status': _billStatusToApi(statusFilter),
        'Whether_Search_Filter': search != null && search.isNotEmpty,
        if (search != null && search.isNotEmpty) 'Search': search,
        'Whether_Bill_Type_Filter': billType != null,
        if (billType != null) 'Bill_Type': billType,
      },
    );

    final ({List<BillRecord> bills, int count}) parsed =
        _parseBillResponse(response);
    return (
      bills: parsed.bills,
      count: parsed.count,
      pendingAmount:
          (response.extras['Total_Pending_To_Pay'] as num?)?.toDouble() ?? 0,
      paidAmount: (response.extras['Total_Paid'] as num?)?.toDouble() ?? 0,
      overdueAmount:
          (response.extras['Total_Overdue_To_Pay'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Filter society resident bills with summary totals (for society manager,
  /// treasurer, president roles — supports bill type, block, building, search).
  static Future<
      ({
        List<BillRecord> bills,
        int count,
        double pendingAmount,
        double collectedAmount,
        double overdueAmount,
        double todayCollection,
        double monthCollection,
        double monthOverdue,
        double monthPending,
      })> filterSocietyResidentBills({
    required String societyId,
    int skip = 0,
    int limit = 10,
    BillStatus? statusFilter,
    int? billType,
    String? blockId,
    String? buildingId,
    String? search,
    String? selectedVendorId,
  }) async {
    final ApiResponse response = await ApiClient.instance.post(
      ApiConfig.filterResidentBills,
      <String, dynamic>{
        'SocietyID': societyId,
        'Whether_Society_Filter': societyId.isNotEmpty,
        'Whether_SocietyID_Filter': societyId.isNotEmpty,
        if (societyId.isNotEmpty) 'SocietyID_Array': <String>[societyId],
        'Skip': skip,
        'Limit': limit,
        'Whether_Bill_Status_Filter': statusFilter != null,
        if (statusFilter != null)
          'Bill_Status': _billStatusToApi(statusFilter),
        'Whether_Bill_Type_Filter': billType != null,
        'Bill_Type': billType ?? 1,
        'Whether_Block_Filter': blockId != null && blockId.isNotEmpty,
        'BlockID': blockId ?? '',
        'Whether_Building_Filter': buildingId != null && buildingId.isNotEmpty,
        'BuildingID': buildingId ?? '',
        'Whether_Selected_Vendor_Filter':
            selectedVendorId != null && selectedVendorId.isNotEmpty,
        'Selected_VendorID': selectedVendorId ?? '',
        'Whether_Search_Filter': search != null && search.isNotEmpty,
        'Search': search ?? '',
      },
    );

    final ({List<BillRecord> bills, int count}) parsed =
        _parseBillResponse(response, societyId: societyId);
    return (
      bills: parsed.bills,
      count: parsed.count,
      pendingAmount:
          (response.extras['Total_Pending_Amount'] as num?)?.toDouble() ?? 0,
      collectedAmount:
          (response.extras['Total_Collected_Amount'] as num?)?.toDouble() ?? 0,
      overdueAmount:
          (response.extras['Total_Overdue_Amount'] as num?)?.toDouble() ?? 0,
      todayCollection:
          (response.extras['Today_Collection'] as num?)?.toDouble() ?? 0,
      monthCollection:
          (response.extras['Current_Month_Collection'] as num?)?.toDouble() ??
              0,
      monthOverdue:
          (response.extras['Current_Month_Overdue_Amount'] as num?)
              ?.toDouble() ??
              0,
      monthPending:
          (response.extras['Current_Month_Pending_Amount'] as num?)
              ?.toDouble() ??
              0,
    );
  }

  /// Filter property contract bills (for property owners).
  static Future<({List<BillRecord> bills, int count})>
      filterPropertyContractBills({
    String? propertyId,
    int skip = 0,
    int limit = 50,
    BillStatus? statusFilter,
  }) async {
    final result = await filterPropertyContractBillsDetailed(
      propertyId: propertyId,
      skip: skip,
      limit: limit,
      statusFilter: statusFilter,
    );
    return (bills: result.bills, count: result.count);
  }

  /// Filter property contract bills with summary totals (for property manager
  /// billing page direct fetch with search + contract filter).
  static Future<
      ({
        List<BillRecord> bills,
        int count,
        double pendingAmount,
        double collectedAmount,
        double overdueAmount,
        double todayCollection,
        double monthCollection,
        double monthOverdue,
        double monthPending,
        double totalSecurityBill,
        double pendingSecurity,
        double collectedSecurity,
      })> filterPropertyContractBillsDetailed({
    String? propertyId,
    int skip = 0,
    int limit = 50,
    BillStatus? statusFilter,
    String? contractId,
    String? search,
    int? billType,
    String? propertyVendorId,
  }) async {
    final bool hasPropertyFilter =
        propertyId != null && propertyId.isNotEmpty;
    final bool hasContractFilter = contractId != null && contractId.isNotEmpty;
    final ApiResponse response = await ApiClient.instance.post(
      ApiConfig.filterPropertyContractBills,
      <String, dynamic>{
        'Whether_Property_Filter': hasPropertyFilter,
        'PropertyID': hasPropertyFilter ? propertyId : '',
        'Skip': skip,
        'Limit': limit,
        'Whether_Bill_Status_Filter': statusFilter != null,
        if (statusFilter != null)
          'Bill_Status': _billStatusToApi(statusFilter),
        'Whether_Bill_Type_Filter': billType != null,
        if (billType != null) 'Bill_Type': billType,
        'Whether_Property_Vendor_Filter':
            propertyVendorId != null && propertyVendorId.isNotEmpty,
        if (propertyVendorId != null && propertyVendorId.isNotEmpty)
          'Property_VendorID': propertyVendorId,
        'Whether_Rental_Contract_Filter': hasContractFilter,
        'Whether_Contract_Filter': hasContractFilter,
        'Rental_ContractID': hasContractFilter ? contractId : '',
        'Whether_Search_Filter': search != null && search.isNotEmpty,
        if (search != null && search.isNotEmpty) 'Search': search,
      },
    );

    final ({List<BillRecord> bills, int count}) parsed =
        _parseBillResponse(response);
    return (
      bills: parsed.bills,
      count: parsed.count,
      pendingAmount:
          (response.extras['Total_Pending_Amount'] as num?)?.toDouble() ?? 0,
      collectedAmount:
          (response.extras['Total_Collected_Amount'] as num?)?.toDouble() ?? 0,
      overdueAmount:
          (response.extras['Total_Overdue_Amount'] as num?)?.toDouble() ?? 0,
      todayCollection:
          (response.extras['Today_Collection'] as num?)?.toDouble() ?? 0,
      monthCollection:
          (response.extras['Current_Month_Collection'] as num?)?.toDouble() ??
              0,
      monthOverdue:
          (response.extras['Current_Month_Overdue_Amount'] as num?)
              ?.toDouble() ??
              0,
      monthPending:
          (response.extras['Current_Month_Pending_Amount'] as num?)
              ?.toDouble() ??
              0,
      totalSecurityBill:
          (response.extras['Total_Security_Bill_Amount'] as num?)?.toDouble() ??
              0,
      pendingSecurity:
          (response.extras['Pending_Security_Amount'] as num?)?.toDouble() ?? 0,
      collectedSecurity:
          (response.extras['Collected_Security_Amount'] as num?)?.toDouble() ??
              0,
    );
  }

  /// Fetch complete information for a single bill.
  static Future<BillRecord?> fetchBillInfo(String billId) async {
    final ApiResponse response = await ApiClient.instance.post(
      ApiConfig.fetchBillInfo,
      <String, dynamic>{'BillID': billId},
    );

    if (response.success && response.data != null) {
      return BillData.fromJson(response.data as Map<String, dynamic>)
          .toBillRecord();
    }
    return null;
  }

  static ({List<BillRecord> bills, int count}) _parseBillResponse(
    ApiResponse response, {
    String? societyId,
  }) {
    if (!response.success || response.data == null) {
      return (bills: <BillRecord>[], count: 0);
    }

    final List<dynamic> dataList = response.data as List<dynamic>;
    final List<Map<String, dynamic>> billMaps = dataList
        .whereType<Map<String, dynamic>>()
        .where((Map<String, dynamic> item) => _isBillForSociety(item, societyId))
        .toList();
    final List<BillRecord> bills = billMaps
        .map(
          (Map<String, dynamic> item) =>
              BillData.fromJson(item).toBillRecord(),
        )
        .toList();

    final bool locallyFiltered =
        (societyId ?? '').trim().isNotEmpty &&
        billMaps.length != dataList.length;
    return (
      bills: bills,
      count: locallyFiltered ? bills.length : response.count ?? bills.length,
    );
  }

  static bool _isBillForSociety(
    Map<String, dynamic> json,
    String? requestedSocietyId,
  ) {
    final String requested = requestedSocietyId?.trim() ?? '';
    if (requested.isEmpty) {
      return true;
    }

    final String recordSocietyId = _readNestedString(json, <List<String>>[
      <String>['SocietyID'],
      <String>['Society_ID'],
      <String>['SocietyId'],
      <String>['Society_Data', 'SocietyID'],
      <String>['Society_Data', 'Society_ID'],
      <String>['Society_Data', '_id'],
      <String>['Society_Information', 'SocietyID'],
      <String>['Society_Information', '_id'],
      <String>['Society_Resident_Information', 'SocietyID'],
      <String>['Society_Resident_Information', 'Society_ID'],
      <String>['Resident_Data', 'SocietyID'],
      <String>['Resident_Data', 'Society_ID'],
    ]);

    return recordSocietyId.isEmpty || recordSocietyId == requested;
  }

  static String _readNestedString(
    Map<String, dynamic> json,
    List<List<String>> paths,
  ) {
    for (final List<String> path in paths) {
      dynamic value = json;
      for (final String key in path) {
        if (value is! Map<String, dynamic>) {
          value = null;
          break;
        }
        value = value[key];
      }
      final String text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  /// Collect bill amount (payment).
  static Future<ApiResponse> collectBillPayment(
    String billId, {
    required int paymentType,
  }) async {
    return ApiClient.instance.post(
      ApiConfig.collectBillAmount,
      <String, dynamic>{
        'BillID': billId,
        'Payment_Type': paymentType,
      },
    );
  }

  /// Collect bill amount with manual online payment.
  static Future<ApiResponse> collectBillManualOnline(
    String billId, {
    required int paymentType,
    int? manualOnlinePaymentMode,
    String? paymentDescription,
    bool whetherPaymentImageAvailable = false,
    String? imageId,
  }) async {
    return ApiClient.instance.post(
      ApiConfig.collectBillManualOnline,
      <String, dynamic>{
        'BillID': billId,
        'Payment_Type': paymentType,
        if (manualOnlinePaymentMode != null)
          'Manual_Online_Payment_Mode': manualOnlinePaymentMode,
        if (paymentDescription != null && paymentDescription.isNotEmpty)
          'Bill_Payment_Description': paymentDescription,
        'Whether_Bill_Payment_Image_Available': whetherPaymentImageAvailable,
        if (whetherPaymentImageAvailable && imageId != null)
          'ImageID': imageId,
      },
    );
  }

  /// Generate bills for all society residents.
  static Future<ApiResponse> generateSocietyBills(String societyId) async {
    return ApiClient.instance.post(
      ApiConfig.generateSocietyBills,
      <String, dynamic>{'SocietyID': societyId},
    );
  }

  /// Generate bills for property rental contracts.
  static Future<ApiResponse> generatePropertyBills(
    String propertyId, {
    bool whetherPaid = false,
  }) async {
    return ApiClient.instance.post(
      ApiConfig.generatePropertyBills,
      <String, dynamic>{
        'PropertyID': propertyId,
        'Whether_Paid': whetherPaid,
      },
    );
  }

  /// Send bill WhatsApp reminder.
  static Future<ApiResponse> sendBillWhatsAppReminder(String billId) async {
    return ApiClient.instance.post(
      ApiConfig.sendBillWhatsAppReminder,
      <String, dynamic>{'BillID': billId},
    );
  }

  static int _billStatusToApi(BillStatus status) {
    return switch (status) {
      BillStatus.pending => 1,
      BillStatus.paid => 2,
      BillStatus.overdue => 3,
      BillStatus.partial => 4,
    };
  }
}
