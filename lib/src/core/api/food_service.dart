import 'api_client.dart';
import 'api_config.dart';

class FoodMenuOption {
  const FoodMenuOption({
    required this.id,
    required this.text,
    required this.voteCount,
  });

  final String id;
  final String text;
  final int voteCount;

  factory FoodMenuOption.fromJson(Map<String, dynamic> json) {
    return FoodMenuOption(
      id: json['OptionID'] as String? ?? '',
      text: json['Text'] as String? ?? '',
      voteCount: (json['Vote_Count'] as num?)?.toInt() ?? 0,
    );
  }
}

class FoodMenuItem {
  const FoodMenuItem({
    required this.id,
    required this.propertyId,
    required this.mealType,
    required this.mealLabel,
    required this.menuTitle,
    required this.menuDateKey,
    required this.dayIndex,
    required this.dayLabel,
    required this.calories,
    required this.chefSpecial,
    required this.copyToWeek,
    required this.whetherVotingLive,
    required this.voteCount,
    required this.options,
    required this.createdAt,
    this.userVoteOptionId,
    this.propertyName = '',
    this.winningOptionText = '',
  });

  final String id;
  final String propertyId;
  final int mealType;
  final String mealLabel;
  final String menuTitle;
  final String menuDateKey;
  final int dayIndex;
  final String dayLabel;
  final int calories;
  final bool chefSpecial;
  final bool copyToWeek;
  final bool whetherVotingLive;
  final int voteCount;
  final List<FoodMenuOption> options;
  final DateTime createdAt;
  final String? userVoteOptionId;
  final String propertyName;
  final String winningOptionText;

  factory FoodMenuItem.fromJson(Map<String, dynamic> json) {
    final List<FoodMenuOption> options =
        (json['Options'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(FoodMenuOption.fromJson)
            .toList();
    final Map<String, dynamic>? winning =
        json['Winning_Option'] as Map<String, dynamic>?;
    final Map<String, dynamic>? property =
        json['Property_Info'] as Map<String, dynamic>?;
    return FoodMenuItem(
      id: json['Property_Food_MenuID'] as String? ?? '',
      propertyId: json['PropertyID'] as String? ?? '',
      mealType: (json['Meal_Type'] as num?)?.toInt() ?? 0,
      mealLabel: json['Meal_Label'] as String? ?? '',
      menuTitle: json['Menu_Title'] as String? ?? '',
      menuDateKey: json['Menu_Date_Key'] as String? ?? '',
      dayIndex: (json['Day_Index'] as num?)?.toInt() ?? -1,
      dayLabel: json['Day_Label'] as String? ?? '',
      calories: (json['Calories'] as num?)?.toInt() ?? 0,
      chefSpecial: json['Chef_Special'] as bool? ?? false,
      copyToWeek: json['Copy_To_Week'] as bool? ?? false,
      whetherVotingLive: json['Whether_Voting_Live'] as bool? ?? false,
      voteCount: (json['Vote_Count'] as num?)?.toInt() ?? 0,
      options: options,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      userVoteOptionId:
          (json['User_Vote'] as Map<String, dynamic>?)?['OptionID'] as String?,
      propertyName:
          property?['Property_Display_Label'] as String? ??
          property?['Property_Title'] as String? ??
          '',
      winningOptionText:
          winning?['Text'] as String? ??
          (options.isNotEmpty ? options.first.text : ''),
    );
  }
}

class FoodService {
  FoodService._();

  static Future<List<FoodMenuItem>> filterMenus({
    String? propertyId,
    int skip = 0,
    int limit = 40,
    int? mealType,
    int? dayIndex,
    String? menuDateKey,
    bool onlyVotingLive = false,
  }) async {
    final ApiResponse response = await ApiClient.instance
        .post(ApiConfig.filterPropertyFoodMenus, <String, dynamic>{
          'Skip': skip,
          'Limit': limit,
          'Whether_PropertyID_Filter':
              propertyId != null && propertyId.isNotEmpty,
          'PropertyID': propertyId ?? '',
          'Whether_Meal_Type_Filter': mealType != null,
          'Meal_Type': mealType ?? 0,
          'Whether_Day_Index_Filter': dayIndex != null,
          'Day_Index': dayIndex ?? 0,
          'Whether_Menu_Date_Key_Filter':
              menuDateKey != null && menuDateKey.isNotEmpty,
          'Menu_Date_Key': menuDateKey ?? '',
          'Whether_Only_Voting_Live': onlyVotingLive,
        });
    if (!response.success || response.data is! List<dynamic>) {
      return <FoodMenuItem>[];
    }
    return (response.data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(FoodMenuItem.fromJson)
        .toList();
  }

  static Future<void> createMenu({
    required String propertyId,
    required int mealType,
    required String menuTitle,
    required List<String> options,
    int? dayIndex,
    String? dayLabel,
    String? menuDateKey,
    int calories = 0,
    bool chefSpecial = false,
    bool copyToWeek = false,
    bool whetherVotingLive = true,
  }) async {
    final ApiResponse response = await ApiClient.instance
        .post(ApiConfig.createPropertyFoodMenu, <String, dynamic>{
          'PropertyID': propertyId,
          'Meal_Type': mealType,
          'Menu_Title': menuTitle,
          'Options': options,
          'Day_Index': dayIndex,
          'Day_Label': dayLabel ?? '',
          'Menu_Date_Key': menuDateKey ?? _todayMenuDateKey(),
          'Calories': calories,
          'Chef_Special': chefSpecial,
          'Copy_To_Week': copyToWeek,
          'Whether_Voting_Live': whetherVotingLive,
        });
    _throwIfFailed(response, 'Unable to save meal menu.');
  }

  static Future<void> editMenu({
    required String menuId,
    required String propertyId,
    required int mealType,
    required String menuTitle,
    required List<String> options,
    int? dayIndex,
    String? dayLabel,
    String? menuDateKey,
    int calories = 0,
    bool chefSpecial = false,
    bool copyToWeek = false,
    bool whetherVotingLive = true,
  }) async {
    final ApiResponse response = await ApiClient.instance
        .post(ApiConfig.editPropertyFoodMenu, <String, dynamic>{
          'Property_Food_MenuID': menuId,
          'PropertyID': propertyId,
          'Meal_Type': mealType,
          'Menu_Title': menuTitle,
          'Options': options,
          'Day_Index': dayIndex,
          'Day_Label': dayLabel ?? '',
          'Menu_Date_Key': menuDateKey ?? _todayMenuDateKey(),
          'Calories': calories,
          'Chef_Special': chefSpecial,
          'Copy_To_Week': copyToWeek,
          'Whether_Voting_Live': whetherVotingLive,
        });
    _throwIfFailed(response, 'Unable to update meal menu.');
  }

  static Future<void> vote(String menuId, String optionId) async {
    final ApiResponse response = await ApiClient.instance.post(
      ApiConfig.votePropertyFoodMenu,
      <String, dynamic>{'Property_Food_MenuID': menuId, 'OptionID': optionId},
    );
    _throwIfFailed(response, 'Unable to submit meal vote.');
  }

  static void _throwIfFailed(ApiResponse response, String fallback) {
    if (!response.success) {
      throw Exception(response.message ?? response.status ?? fallback);
    }
  }

  static String todayMenuDateKey() => _todayMenuDateKey();

  static String _todayMenuDateKey() {
    final DateTime now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
