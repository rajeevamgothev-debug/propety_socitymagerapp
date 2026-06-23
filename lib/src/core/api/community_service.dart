import 'api_client.dart';
import 'api_config.dart';

enum CommunityContentType { post, poll }

class CommunityItem {
  const CommunityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.propertyName,
    required this.locationLabel,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.liked,
    this.images = const <String>[],
    this.options = const <CommunityPollOption>[],
    this.userVoteOptionId,
    this.voteCount = 0,
    this.endsAt,
    this.pinned = false,
    this.important = false,
    this.emergency = false,
  });

  final String id;
  final CommunityContentType type;
  final String title;
  final String description;
  final String propertyName;
  final String locationLabel;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final bool liked;
  final List<String> images;
  final List<CommunityPollOption> options;
  final String? userVoteOptionId;
  final int voteCount;
  final DateTime? endsAt;
  final bool pinned;
  final bool important;
  final bool emergency;

  factory CommunityItem.fromJson(Map<String, dynamic> json) {
    final int contentType = (json['Content_Type'] as num?)?.toInt() ?? 1;
    final Map<String, dynamic> property =
        (json['Property_Info'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final Map<String, dynamic> society =
        (json['Society_Info'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final List<dynamic> rawImages =
        json['Image_Array_Information'] as List<dynamic>? ?? <dynamic>[];
    return CommunityItem(
      id: contentType == 2
          ? json['Community_PollID'] as String? ?? ''
          : json['Community_PostID'] as String? ?? '',
      type: contentType == 2
          ? CommunityContentType.poll
          : CommunityContentType.post,
      title: contentType == 2
          ? json['Question'] as String? ?? ''
          : json['Title'] as String? ?? '',
      description: json['Description'] as String? ?? '',
      propertyName:
          property['Property_Display_Label'] as String? ??
          property['Property_Title'] as String? ??
          society['Name'] as String? ??
          '',
      locationLabel: json['Location_Label'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      likeCount: (json['Like_Count'] as num?)?.toInt() ?? 0,
      commentCount: (json['Comment_Count'] as num?)?.toInt() ?? 0,
      liked: json['User_Reaction'] != null,
      images: rawImages
          .whereType<Map<String, dynamic>>()
          .map(
            (Map<String, dynamic> item) =>
                item['Image_Original_URL'] as String? ?? '',
          )
          .where((String item) => item.isNotEmpty)
          .toList(),
      options: (json['Options'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(CommunityPollOption.fromJson)
          .toList(),
      userVoteOptionId:
          (json['User_Vote'] as Map<String, dynamic>?)?['OptionID'] as String?,
      voteCount: (json['Vote_Count'] as num?)?.toInt() ?? 0,
      endsAt: DateTime.tryParse(json['Ends_At'] as String? ?? ''),
      pinned: json['Pinned'] as bool? ?? false,
      important: json['Important'] as bool? ?? false,
      emergency: json['Emergency'] as bool? ?? false,
    );
  }
}

class CommunityPollOption {
  const CommunityPollOption({
    required this.id,
    required this.text,
    required this.voteCount,
  });

  final String id;
  final String text;
  final int voteCount;

  factory CommunityPollOption.fromJson(Map<String, dynamic> json) {
    return CommunityPollOption(
      id: json['OptionID'] as String? ?? '',
      text: json['Text'] as String? ?? '',
      voteCount: (json['Vote_Count'] as num?)?.toInt() ?? 0,
    );
  }
}

class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.comment,
    required this.createdAt,
    required this.replyCount,
  });

  final String id;
  final String comment;
  final DateTime createdAt;
  final int replyCount;

  factory CommunityComment.fromJson(Map<String, dynamic> json) {
    return CommunityComment(
      id: json['Community_CommentID'] as String? ?? '',
      comment: json['Comment'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      replyCount: (json['Reply_Count'] as num?)?.toInt() ?? 0,
    );
  }
}

class CommunityService {
  CommunityService._();

  static Future<List<CommunityItem>> filterFeed({
    int skip = 0,
    int limit = 30,
    String? propertyId,
  }) async {
    final ApiResponse response = await ApiClient.instance
        .post(ApiConfig.filterCommunityFeed, <String, dynamic>{
          'Skip': skip,
          'Limit': limit,
          if (propertyId != null && propertyId.isNotEmpty)
            'PropertyID': propertyId,
        });
    if (!response.success || response.data is! List<dynamic>) {
      return <CommunityItem>[];
    }
    return (response.data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(CommunityItem.fromJson)
        .toList();
  }

  static Future<void> createPost({
    String propertyId = '',
    String societyId = '',
    String blockId = '',
    String buildingId = '',
    required String title,
    required String description,
    required List<String> imageIds,
    String locationType = '',
    String locationId = '',
    String locationLabel = '',
    bool pinned = false,
    bool important = false,
    bool emergency = false,
    bool draft = false,
  }) async {
    final ApiResponse response = await ApiClient.instance
        .post(ApiConfig.createCommunityPost, <String, dynamic>{
          'PropertyID': propertyId,
          'SocietyID': societyId,
          'BlockID': blockId,
          'BuildingID': buildingId,
          'Location_Type': locationType,
          'LocationID': locationId,
          'Location_Label': locationLabel,
          'Title': title,
          'Description': description,
          'ImageID_Array': imageIds,
          'Pinned': pinned,
          'Important': important,
          'Emergency': emergency,
          'Draft': draft,
        });
    _throwIfFailed(response, 'Unable to create post.');
  }

  static Future<void> createPoll({
    String propertyId = '',
    String societyId = '',
    String blockId = '',
    String buildingId = '',
    required String question,
    required List<String> options,
    required int durationDays,
    String locationType = '',
    String locationId = '',
    String locationLabel = '',
  }) async {
    final ApiResponse response = await ApiClient.instance
        .post(ApiConfig.createCommunityPoll, <String, dynamic>{
          'PropertyID': propertyId,
          'SocietyID': societyId,
          'BlockID': blockId,
          'BuildingID': buildingId,
          'Location_Type': locationType,
          'LocationID': locationId,
          'Location_Label': locationLabel,
          'Question': question,
          'Options': options,
          'Duration_Days': durationDays,
        });
    _throwIfFailed(response, 'Unable to create poll.');
  }

  static Future<void> toggleReaction(CommunityItem item) async {
    final ApiResponse response = await ApiClient.instance
        .post(ApiConfig.toggleCommunityReaction, <String, dynamic>{
          'Content_Type': item.type == CommunityContentType.poll ? 2 : 1,
          'ContentID': item.id,
        });
    _throwIfFailed(response, 'Unable to update like.');
  }

  static Future<void> vote(String pollId, String optionId) async {
    final ApiResponse response = await ApiClient.instance.post(
      ApiConfig.voteCommunityPoll,
      <String, dynamic>{'Community_PollID': pollId, 'OptionID': optionId},
    );
    _throwIfFailed(response, 'Unable to vote.');
  }

  static Future<void> createComment({
    required CommunityItem item,
    required String comment,
    String parentCommentId = '',
  }) async {
    final ApiResponse response = await ApiClient.instance
        .post(ApiConfig.createCommunityComment, <String, dynamic>{
          'Content_Type': item.type == CommunityContentType.poll ? 2 : 1,
          'ContentID': item.id,
          'Parent_CommentID': parentCommentId,
          'Comment': comment,
        });
    _throwIfFailed(response, 'Unable to add comment.');
  }

  static Future<List<CommunityComment>> filterComments({
    required CommunityItem item,
    String parentCommentId = '',
  }) async {
    final ApiResponse response = await ApiClient.instance
        .post(ApiConfig.filterCommunityComments, <String, dynamic>{
          'Content_Type': item.type == CommunityContentType.poll ? 2 : 1,
          'ContentID': item.id,
          'Parent_CommentID': parentCommentId,
          'Skip': 0,
          'Limit': 100,
        });
    if (!response.success || response.data is! List<dynamic>) {
      return <CommunityComment>[];
    }
    return (response.data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(CommunityComment.fromJson)
        .toList();
  }

  static void _throwIfFailed(ApiResponse response, String fallback) {
    if (!response.success) {
      throw Exception(response.message ?? response.status ?? fallback);
    }
  }
}
