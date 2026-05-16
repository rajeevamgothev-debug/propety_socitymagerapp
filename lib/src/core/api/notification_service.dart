import '../models/api_models.dart';
import 'api_client.dart';
import 'api_config.dart';
import 'property_service.dart';

class NotificationService {
  NotificationService._();

  static final Set<String> _locallyReadNotificationIds = <String>{};
  static DateTime? _backendMarkedAllReadAt;

  static Future<
    ({List<NotificationData> notifications, int count, int unreadCount})
  >
  filterNotifications({
    int skip = 0,
    int limit = 10,
    bool? read,
    String? search,
  }) async {
    final ApiResponse response = await ApiClient.instance
        .post(ApiConfig.filterNotifications, <String, dynamic>{
          'Skip': skip,
          'Limit': limit,
          'Whether_Read_Filter': read != null,
          if (read != null) 'Whether_Read': read,
          'Whether_Search_Filter': search != null && search.isNotEmpty,
          if (search != null) 'Search': search,
        });

    if (!response.success || response.data == null) {
      return (notifications: <NotificationData>[], count: 0, unreadCount: 0);
    }

    final List<dynamic> dataList = response.data as List<dynamic>;
    final List<NotificationData> notifications = dataList
        .map(
          (dynamic item) =>
              NotificationData.fromJson(item as Map<String, dynamic>),
        )
        .map(_applyLocalReadState)
        .map(_applyBackendMarkAllReadState)
        .toList();

    final int calculatedUnreadCount =
        notifications.where((NotificationData n) => !n.isRead).length;
    return (
      notifications: notifications,
      count: response.count ?? notifications.length,
      unreadCount:
          _backendMarkedAllReadAt == null
              ? ((response.extras['Unread_Count'] as num?)?.toInt() ??
                    calculatedUnreadCount)
              : calculatedUnreadCount,
    );
  }

  static Future<({List<NotificationData> notifications, int count})>
  filterOpenPropertyEnquiryNotifications({
    int limit = 50,
    String? search,
  }) async {
    final result = await PropertyService.filterPropertyEnquiries(
      null,
      limit: limit,
      search: search,
      enquiryStatus: 1,
    );
    final List<NotificationData> notifications = result.enquiries
        .where((PropertyEnquiryData enquiry) => enquiry.status == 1)
        .map(NotificationData.fromPropertyEnquiry)
        .map(_applyLocalReadState)
        .toList();

    return (
      notifications: notifications,
      count: notifications.length,
    );
  }

  static List<NotificationData> mergePropertyEnquiryNotifications(
    List<NotificationData> backendNotifications,
    List<NotificationData> enquiryNotifications,
  ) {
    final Set<String> backendEnquiryIds = backendNotifications
        .where(_isPropertyEnquiryNotification)
        .map(_notificationEnquiryKey)
        .where((String value) => value.isNotEmpty)
        .toSet();

    final List<NotificationData> merged =
        <NotificationData>[
          ...backendNotifications,
          ...enquiryNotifications.where((NotificationData notification) {
            final String key = _notificationEnquiryKey(notification);
            return key.isEmpty || !backendEnquiryIds.contains(key);
          }),
        ]..sort(
          (NotificationData a, NotificationData b) =>
              b.createdAt.compareTo(a.createdAt),
        );

    return merged;
  }

  static bool _isPropertyEnquiryNotification(NotificationData notification) {
    final String referenceType = notification.referenceType.toLowerCase();
    return referenceType.contains('property_enquiry') ||
        referenceType.contains('enquiry') ||
        referenceType.contains('lead') ||
        notification.type.toLowerCase() == 'enquiry';
  }

  static String _notificationEnquiryKey(NotificationData notification) {
    final String referenceId = notification.referenceId.trim();
    if (referenceId.isNotEmpty) {
      return referenceId;
    }
    final dynamic propertyEnquiryId =
        notification.data['Property_EnquiryID'] ??
        notification.data['EnquiryID'] ??
        notification.data['_id'];
    return '${propertyEnquiryId ?? ''}'.trim();
  }

  static Future<ApiResponse> markAsRead(String notificationId) async {
    if (notificationId.startsWith('local-property-enquiry:')) {
      markLocalAsRead(notificationId);
      return ApiResponse(success: true, extras: const <String, dynamic>{});
    }
    final ApiResponse response = await ApiClient.instance.post(
      ApiConfig.markNotificationAsRead,
      <String, dynamic>{'Vendor_NotificationID': notificationId},
    );
    if (response.success) {
      markLocalAsRead(notificationId);
    }
    return response;
  }

  static Future<ApiResponse> markAllAsRead() async {
    final ApiResponse response = await ApiClient.instance.post(
      ApiConfig.markAllNotificationsAsRead,
    );
    if (response.success) {
      _backendMarkedAllReadAt = DateTime.now();
    }
    return response;
  }

  static void markLocalAsRead(String notificationId) {
    final String id = notificationId.trim();
    if (id.isNotEmpty) {
      _locallyReadNotificationIds.add(id);
    }
  }

  static void markLocalPropertyEnquiriesAsRead(
    Iterable<NotificationData> notifications,
  ) {
    for (final NotificationData notification in notifications) {
      if (notification.isLocalPropertyEnquiry) {
        markLocalAsRead(notification.notificationId);
      }
    }
  }

  static NotificationData _applyLocalReadState(NotificationData notification) {
    if (_locallyReadNotificationIds.contains(notification.notificationId)) {
      return notification.copyWith(isRead: true);
    }
    return notification;
  }

  static NotificationData _applyBackendMarkAllReadState(
    NotificationData notification,
  ) {
    final DateTime? markedAt = _backendMarkedAllReadAt;
    if (markedAt == null || notification.isLocalPropertyEnquiry) {
      return notification;
    }
    if (notification.createdAt.isBefore(markedAt.add(const Duration(seconds: 5)))) {
      return notification.copyWith(isRead: true);
    }
    return notification;
  }
}
