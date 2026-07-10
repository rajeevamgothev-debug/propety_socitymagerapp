import '../models/api_models.dart';
import 'api_client.dart';
import 'api_config.dart';

class VendorService {
  VendorService._();

  static Future<VendorData?> fetchVendorInfo() async {
    final ApiResponse response = await ApiClient.instance.post(
      ApiConfig.fetchVendorInfo,
    );

    if (response.success && response.data != null) {
      return VendorData.fromJson(response.data as Map<String, dynamic>);
    }
    return null;
  }

  static Future<ApiResponse> setVendorProfile({
    required String fullName,
    required String email,
    String? imageId,
  }) async {
    return ApiClient.instance
        .post(ApiConfig.setVendorProfile, <String, dynamic>{
          'Full_Name': fullName,
          'EmailID': email,
          'Whether_Image_Available': imageId != null,
          if (imageId != null) 'ImageID': imageId,
        });
  }

  static Future<ApiResponse> requestAccountDeletion({String reason = ''}) {
    return ApiClient.instance.post(
      ApiConfig.requestAccountDeletion,
      <String, dynamic>{'Reason': reason},
    );
  }

  static Future<ApiResponse> requestAccountUnlock({String reason = ''}) {
    return ApiClient.instance.post(
      ApiConfig.requestAccountUnlock,
      <String, dynamic>{'Reason': reason},
    );
  }

  static Future<RentReminderSettingsData?> fetchRentReminderSettings() async {
    final ApiResponse response = await ApiClient.instance.post(
      ApiConfig.fetchRentReminderSettings,
    );
    if (response.success && response.data is Map<String, dynamic>) {
      return RentReminderSettingsData.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    return null;
  }

  static Future<ApiResponse> updateRentReminderSettings({
    required bool enabled,
    required int reminderDay,
    required String reminderTime,
  }) {
    return ApiClient.instance
        .post(ApiConfig.updateRentReminderSettings, <String, dynamic>{
          'Whether_Enabled': enabled,
          'Reminder_Day': reminderDay,
          'Reminder_Time': reminderTime,
        });
  }

  static Future<BillingDefaultScheduleData?>
  fetchBillingDefaultSchedule() async {
    final ApiResponse response = await ApiClient.instance.post(
      ApiConfig.fetchBillingDefaultSchedule,
    );
    if (response.success && response.data is Map<String, dynamic>) {
      return BillingDefaultScheduleData.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    return null;
  }

  static Future<ApiResponse> updateBillingDefaultSchedule({
    required bool whetherBillGenerationDayAvailable,
    required int billGenerationDay,
    required bool whetherDueScheduleAvailable,
    required int dueDay,
    required String dueTime,
  }) {
    return ApiClient.instance
        .post(ApiConfig.updateBillingDefaultSchedule, <String, dynamic>{
          'Whether_Bill_Generation_Day_Available':
              whetherBillGenerationDayAvailable,
          'Bill_Generation_Day': billGenerationDay,
          'Whether_Due_Schedule_Available': whetherDueScheduleAvailable,
          'Due_Day': dueDay,
          'Due_Time': dueTime,
        });
  }
}
