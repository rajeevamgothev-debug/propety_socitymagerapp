import '../models/api_models.dart';
import 'api_client.dart';
import 'api_config.dart';

class WalletService {
  WalletService._();

  // Bank Accounts
  static Future<({List<BankAccountData> accounts, int count})>
      filterBankAccounts({
    int skip = 0,
    int limit = 50,
    bool? statusFilter,
  }) async {
    final ApiResponse response = await ApiClient.instance.post(
      ApiConfig.filterBankAccounts,
      <String, dynamic>{
        'Skip': skip,
        'Limit': limit,
        'Whether_Status_Filter': statusFilter != null,
        if (statusFilter != null) 'Status': statusFilter,
      },
    );

    if (!response.success || response.data == null) {
      return (accounts: <BankAccountData>[], count: 0);
    }

    final List<dynamic> dataList = response.data as List<dynamic>;
    final List<BankAccountData> accounts = dataList
        .map((dynamic item) =>
            BankAccountData.fromJson(item as Map<String, dynamic>))
        .toList();

    return (accounts: accounts, count: response.count ?? accounts.length);
  }

  static Future<ApiResponse> createBankAccount(
      Map<String, dynamic> accountData) async {
    return ApiClient.instance.post(ApiConfig.createBankAccount, accountData);
  }

  static Future<ApiResponse> editBankAccount(
      Map<String, dynamic> accountData) async {
    return ApiClient.instance.post(ApiConfig.editBankAccount, accountData);
  }

  static Future<ApiResponse> toggleBankAccount(String accountId,
      {required bool active}) async {
    return ApiClient.instance.post(
      active ? ApiConfig.activeBankAccount : ApiConfig.inactiveBankAccount,
      <String, dynamic>{'BankAccountID': accountId},
    );
  }

  static Future<({bool valid, String? bankName, String? branchName})> validateIfsc(
      String ifscCode) async {
    final ApiResponse response = await ApiClient.instance.post(
      ApiConfig.validateIfsc,
      <String, dynamic>{'IFSC_Code': ifscCode},
    );

    if (response.success && response.data != null) {
      final Map<String, dynamic> data =
          response.data as Map<String, dynamic>;
      return (
        valid: true,
        bankName: data['Bank_Name'] as String?,
        branchName: data['Branch_Name'] as String?,
      );
    }
    return (valid: false, bankName: null, branchName: null);
  }

  static Future<({bool valid, String? customerName})> validateUpi(
    String upiId,
  ) async {
    final ApiResponse response = await ApiClient.instance.post(
      ApiConfig.validateUpi,
      <String, dynamic>{'UPI_ID': upiId},
    );
    if (response.success && response.data is Map<String, dynamic>) {
      final Map<String, dynamic> data =
          response.data as Map<String, dynamic>;
      return (
        valid: data['Whether_Valid'] as bool? ?? true,
        customerName: data['Customer_Name'] as String?,
      );
    }

    return (valid: false, customerName: null);
  }

  // Transactions
  static Future<({List<WalletTransactionData> transactions, int count})>
      filterWalletTransactions({
    int skip = 0,
    int limit = 10,
    int? transactionType,
    String? societyId,
    String? propertyId,
  }) async {
    final ApiResponse response = await ApiClient.instance.post(
      ApiConfig.filterWalletTransactions,
      <String, dynamic>{
        'Skip': skip,
        'Limit': limit,
        'Whether_Transaction_Type_Filter': transactionType != null,
        if (transactionType != null) 'Transaction_Type': transactionType,
        'Whether_Society_ID_Filter':
            societyId != null && societyId.isNotEmpty,
        if (societyId != null && societyId.isNotEmpty) 'SocietyID': societyId,
        'Whether_Property_ID_Filter':
            propertyId != null && propertyId.isNotEmpty,
        if (propertyId != null && propertyId.isNotEmpty)
          'PropertyID': propertyId,
      },
    );

    if (!response.success || response.data == null) {
      return (transactions: <WalletTransactionData>[], count: 0);
    }

    final List<dynamic> dataList = response.data as List<dynamic>;
    final List<WalletTransactionData> transactions = dataList
        .map((dynamic item) =>
            WalletTransactionData.fromJson(item as Map<String, dynamic>))
        .toList();

    return (
      transactions: transactions,
      count: response.count ?? transactions.length,
    );
  }

  // Withdrawals
  static Future<WithdrawalAvailability> checkWithdrawalAvailability() async {
    final ApiResponse response = await ApiClient.instance.post(
      ApiConfig.checkWithdrawalAvailability,
      <String, dynamic>{},
    );
    return WithdrawalAvailability.fromResponse(response);
  }

  static Future<({List<WithdrawalData> withdrawals, int count})>
      filterWithdrawals({
    int skip = 0,
    int limit = 10,
    int? statusFilter,
  }) async {
    final ApiResponse response = await ApiClient.instance.post(
      ApiConfig.filterWalletWithdrawals,
      <String, dynamic>{
        'Skip': skip,
        'Limit': limit,
        'Whether_Withdrawal_Status_Filter': statusFilter != null,
        if (statusFilter != null) 'Withdrawal_Status': statusFilter,
      },
    );

    if (!response.success || response.data == null) {
      return (withdrawals: <WithdrawalData>[], count: 0);
    }

    final List<dynamic> dataList = response.data as List<dynamic>;
    final List<WithdrawalData> withdrawals = dataList
        .map((dynamic item) =>
            WithdrawalData.fromJson(item as Map<String, dynamic>))
        .toList();

    return (
      withdrawals: withdrawals,
      count: response.count ?? withdrawals.length,
    );
  }

  static Future<ApiResponse> withdrawAmount(
      String bankAccountId, double amount) async {
    return ApiClient.instance.post(
      ApiConfig.withdrawWalletAmount,
      <String, dynamic>{
        'BankAccountID': bankAccountId,
        'Amount': amount,
      },
    );
  }
}

class WithdrawalAvailability {
  const WithdrawalAvailability({
    required this.allowed,
    required this.message,
    this.availableAfter,
    this.role,
    this.availableAmount,
  });

  factory WithdrawalAvailability.fromResponse(ApiResponse response) {
    final Map<String, dynamic> extras = response.extras;
    final dynamic data = extras['Data'];
    final Map<String, dynamic> dataMap =
        data is Map<String, dynamic> ? data : <String, dynamic>{};
    final bool allowed = (extras['withdrawal_allowed'] as bool?) ??
        (dataMap['withdrawal_allowed'] as bool?) ??
        response.success;
    final String message = (extras['message'] ??
            extras['msg'] ??
            dataMap['message'] ??
            (allowed ? 'Withdrawal available' : 'Withdrawals are disabled.'))
        .toString();
    final String? availableAfter =
        (extras['available_after'] ?? dataMap['available_after'])?.toString();
    final num? amount = dataMap['available_amount'] as num?;
    return WithdrawalAvailability(
      allowed: allowed,
      message: message,
      availableAfter:
          availableAfter == null || availableAfter.isEmpty ? null : availableAfter,
      role: dataMap['role']?.toString(),
      availableAmount: amount?.toDouble(),
    );
  }

  final bool allowed;
  final String message;
  final String? availableAfter;
  final String? role;
  final double? availableAmount;
}
