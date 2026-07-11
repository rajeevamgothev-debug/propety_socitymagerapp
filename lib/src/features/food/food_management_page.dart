import 'package:flutter/material.dart';

import '../../core/api/food_service.dart';
import '../../core/api/property_service.dart';
import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tone_badge.dart';

class FoodManagementPage extends StatefulWidget {
  const FoodManagementPage({super.key});

  @override
  State<FoodManagementPage> createState() => _FoodManagementPageState();
}

class _FoodManagementPageState extends State<FoodManagementPage> {
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  bool _savingMeal = false;
  String _selectedPropertyId = '';
  List<Map<String, dynamic>> _propertyScope = <Map<String, dynamic>>[];
  List<FoodMenuItem> _liveMenus = <FoodMenuItem>[];

  static const List<String> _days = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  void initState() {
    super.initState();
    _loadFoodData();
  }

  int get _selectedDay => _selectedDate.weekday - 1;

  String get _selectedMenuDateKey => _menuDateKey(_selectedDate);

  List<_FoodMetric> get _metrics {
    final List<FoodMenuItem> currentMenus = _displayMenus;
    final int voteCount = currentMenus.fold<int>(
      0,
      (int total, FoodMenuItem item) => total + item.voteCount,
    );
    final int pending = currentMenus
        .where((FoodMenuItem item) => item.whetherVotingLive)
        .length;
    final int chefSpecial = currentMenus
        .where((FoodMenuItem item) => item.chefSpecial)
        .length;
    return <_FoodMetric>[
      _FoodMetric(
        'Menus',
        '${currentMenus.length}',
        Icons.restaurant_menu_rounded,
        const Color(0xFF4F46E5),
      ),
      _FoodMetric(
        'Votes',
        '$voteCount',
        Icons.how_to_vote_rounded,
        const Color(0xFF10B981),
      ),
      _FoodMetric(
        'Live',
        '$pending',
        Icons.pending_actions_rounded,
        const Color(0xFFF59E0B),
      ),
      _FoodMetric(
        'Special',
        '$chefSpecial',
        Icons.star_rounded,
        const Color(0xFFEF4444),
      ),
    ];
  }

  List<_FoodProperty> get _properties {
    return _propertyScope.map(_mapPropertyCard).toList();
  }

  List<_MealItem> get _meals {
    return _displayMenus.map(_mapMealItem).toList();
  }

  List<FoodMenuItem> get _liveVotingMenus {
    final List<FoodMenuItem> candidates = _displayMenus
        .where(
          (FoodMenuItem item) =>
              item.whetherVotingLive &&
              item.options.length > 1 &&
              _matchesSelectedDay(item),
        )
        .toList()
      ..sort((FoodMenuItem a, FoodMenuItem b) {
        final int mealCompare = a.mealType.compareTo(b.mealType);
        if (mealCompare != 0) {
          return mealCompare;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
    return candidates;
  }

  List<FoodMenuItem> get _chefSpecialMenus {
    return _displayMenus.where((FoodMenuItem item) => item.chefSpecial).toList();
  }

  bool _matchesSelectedDay(FoodMenuItem item) {
    return item.dayIndex == -1 || item.dayIndex == _selectedDay;
  }

  List<FoodMenuItem> get _displayMenus {
    final List<FoodMenuItem> sortedMenus = <FoodMenuItem>[
      ..._liveMenus,
    ]..sort(
        (FoodMenuItem a, FoodMenuItem b) => b.createdAt.compareTo(a.createdAt),
      );
    final List<FoodMenuItem> matchingDay = sortedMenus
        .where(_matchesSelectedDay)
        .toList();
    final List<FoodMenuItem> source = matchingDay.isNotEmpty
        ? matchingDay
        : sortedMenus;
    final Map<String, FoodMenuItem> latestBySlot = <String, FoodMenuItem>{};
    for (final FoodMenuItem item in source) {
      final int normalizedDay = item.dayIndex >= 0 ? item.dayIndex : _selectedDay;
      final String slotKey = '$normalizedDay-${item.mealType}';
      latestBySlot.putIfAbsent(slotKey, () => item);
    }
    final List<FoodMenuItem> displayMenus = latestBySlot.values.toList()
      ..sort((FoodMenuItem a, FoodMenuItem b) {
        final int mealCompare = a.mealType.compareTo(b.mealType);
        if (mealCompare != 0) {
          return mealCompare;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
    return displayMenus;
  }

  Future<void> _loadFoodData() async {
    setState(() => _loading = true);
    try {
      final result = await PropertyService.filterProperties(
        limit: 200,
        typeFilter: 3,
      );
      final List<Map<String, dynamic>> properties = result.properties
          .map(
            (PropertyRecord item) => <String, dynamic>{
              'PropertyID': item.id,
              'Property_Title': item.title,
              'Address': item.address ?? '',
            },
          )
          .where(
            (Map<String, dynamic> item) =>
                (item['PropertyID'] as String? ?? '').isNotEmpty,
          )
          .toList();
      final bool hasSelectedProperty = properties.any(
        (Map<String, dynamic> item) =>
            (item['PropertyID'] as String? ?? '') == _selectedPropertyId,
      );
      final String propertyId = hasSelectedProperty
          ? _selectedPropertyId
          : (properties.isNotEmpty
                ? properties.first['PropertyID'] as String? ?? ''
                : '');
      final List<FoodMenuItem> menus = await FoodService.filterMenus(
        propertyId: propertyId.isEmpty ? null : propertyId,
        menuDateKey: _selectedMenuDateKey,
        limit: 60,
      );
      if (!mounted) return;
      setState(() {
        _propertyScope = properties;
        _selectedPropertyId = propertyId;
        _liveMenus = menus;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  _FoodProperty _mapPropertyCard(Map<String, dynamic> item) {
    final String propertyId = item['PropertyID'] as String? ?? '';
    final bool selected = propertyId == _selectedPropertyId;
    final String title =
        item['Property_Title'] as String? ??
        item['Property_Display_Label'] as String? ??
        'Property';
    return _FoodProperty(
      name: title,
      residents: 0,
      cook: selected ? 'Selected property' : 'Tap to switch',
      timing: selected ? 'Food menus synced' : 'Load food dashboard',
      status: selected ? 'Active' : 'Available',
      image:
          'https://images.unsplash.com/photo-1560185008-b033106af5c3?auto=format&fit=crop&w=900&q=80',
    );
  }

  _MealItem _mapMealItem(FoodMenuItem menu) {
    final String subtitle = menu.options
        .map((FoodMenuOption item) => item.text)
        .join(', ');
    return _MealItem(
      id: menu.id,
      name: menu.menuTitle.isEmpty ? menu.winningOptionText : menu.menuTitle,
      meal: menu.mealLabel.isEmpty ? 'Meal' : menu.mealLabel,
      items: subtitle,
      image: _imageForMealType(menu.mealType),
      votes: menu.voteCount,
      rating: menu.chefSpecial ? 5.0 : 4.6,
      tone: _toneForMealType(menu.mealType),
    );
  }

  Color _toneForMealType(int mealType) {
    switch (mealType) {
      case 1:
        return const Color(0xFF4F46E5);
      case 2:
        return const Color(0xFF10B981);
      case 3:
        return const Color(0xFFF59E0B);
      case 4:
        return const Color(0xFF8B5CF6);
      default:
        return AppTheme.primary;
    }
  }

  String _imageForMealType(int mealType) {
    switch (mealType) {
      case 1:
        return 'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?auto=format&fit=crop&w=900&q=80';
      case 2:
        return 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?auto=format&fit=crop&w=900&q=80';
      case 3:
        return 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?auto=format&fit=crop&w=900&q=80';
      case 4:
        return 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?auto=format&fit=crop&w=900&q=80';
      default:
        return 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=900&q=80';
    }
  }

  Future<void> _openAddMealSheet() async {
    final String fallbackPropertyId = _selectedPropertyId.isNotEmpty
        ? _selectedPropertyId
        : (_propertyScope.isNotEmpty
              ? _propertyScope.first['PropertyID'] as String? ?? ''
              : '');
    if (fallbackPropertyId.isNotEmpty && fallbackPropertyId != _selectedPropertyId) {
      setState(() => _selectedPropertyId = fallbackPropertyId);
    }
    final _AddMealDraft? draft = await showModalBottomSheet<_AddMealDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        return _AddMealSheet(selectedDate: _selectedDate);
      },
    );
    if (draft == null) {
      return;
    }
    await _persistMealDraft(draft);
  }

  Future<void> _openEditMealSheet(String menuId) async {
    final FoodMenuItem? menu = _liveMenus
        .where((FoodMenuItem item) => item.id == menuId)
        .cast<FoodMenuItem?>()
        .firstWhere((FoodMenuItem? item) => item != null, orElse: () => null);
    if (menu == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meal data is not available to edit.')),
      );
      return;
    }
    final _AddMealDraft? draft = await showModalBottomSheet<_AddMealDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        return _AddMealSheet(
          selectedDate: _selectedDate,
          initialDraft: _AddMealDraft(
            menuId: menu.id,
            mealType: menu.mealType > 0 ? menu.mealType - 1 : 0,
            menuTitle: menu.menuTitle,
            options: menu.options.map((FoodMenuOption item) => item.text).toList(),
            calories: menu.calories,
            chefSpecial: menu.chefSpecial,
            copyToWeek: menu.copyToWeek,
          ),
        );
      },
    );
    if (draft == null) {
      return;
    }
    await _persistMealDraft(draft);
  }

  Future<void> _persistMealDraft(_AddMealDraft draft) async {
    final String targetPropertyId = _selectedPropertyId.isNotEmpty
        ? _selectedPropertyId
        : (_propertyScope.isNotEmpty
              ? _propertyScope.first['PropertyID'] as String? ?? ''
              : '');
    if (targetPropertyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No PG property is available to save this meal menu.'),
        ),
      );
      return;
    }
    setState(() => _savingMeal = true);
    try {
      if (draft.menuId == null || draft.menuId!.isEmpty) {
        await FoodService.createMenu(
          propertyId: targetPropertyId,
          mealType: draft.mealType + 1,
          menuTitle: draft.menuTitle,
          options: draft.options,
          dayIndex: _selectedDay,
          dayLabel: _days[_selectedDay],
          menuDateKey: _selectedMenuDateKey,
          calories: draft.calories,
          chefSpecial: draft.chefSpecial,
          copyToWeek: draft.copyToWeek,
          whetherVotingLive: true,
        );
      } else {
        await FoodService.editMenu(
          menuId: draft.menuId!,
          propertyId: targetPropertyId,
          mealType: draft.mealType + 1,
          menuTitle: draft.menuTitle,
          options: draft.options,
          dayIndex: _selectedDay,
          dayLabel: _days[_selectedDay],
          menuDateKey: _selectedMenuDateKey,
          calories: draft.calories,
          chefSpecial: draft.chefSpecial,
          copyToWeek: draft.copyToWeek,
          whetherVotingLive: true,
        );
      }
      await _loadFoodData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            draft.menuId == null || draft.menuId!.isEmpty
                ? 'Meal menu saved successfully.'
                : 'Meal menu updated successfully.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingMeal = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        titleSpacing: 16,
        title: const Text('Food Management'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: <Widget>[
          if (_loading || _savingMeal) ...<Widget>[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 16),
          ],
          _HeroHeader(),
          const SizedBox(height: 18),
          _MetricStrip(metrics: _metrics),
          const SizedBox(height: 22),
          const _SectionTitle(title: 'Properties', action: 'View all'),
          const SizedBox(height: 12),
          if (_properties.isEmpty)
            const _EmptyFoodState(
              icon: Icons.apartment_outlined,
              title: 'No PG properties',
              subtitle: 'No PG property is available for food management.',
            )
          else
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (BuildContext context, int index) {
                  final String propertyId = _propertyScope[index]['PropertyID']
                          as String? ??
                      '';
                  return _PropertyFoodCard(
                    property: _properties[index],
                    selected:
                        propertyId.isNotEmpty &&
                        propertyId == _selectedPropertyId,
                    onTap: propertyId.isEmpty
                        ? null
                        : () async {
                            setState(() => _selectedPropertyId = propertyId);
                            await _loadFoodData();
                          },
                  );
                },
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemCount: _properties.length,
              ),
            ),
          const SizedBox(height: 24),
          _WeeklyCalendar(
            selectedDate: _selectedDate,
            onSelected: (DateTime value) async {
              setState(() => _selectedDate = value);
              await _loadFoodData();
            },
          ),
          const SizedBox(height: 22),
          _SectionTitle(
            title: 'Meal Plan',
            action: 'Add meal',
            onAction: _openAddMealSheet,
          ),
          const SizedBox(height: 12),
          if (_meals.isEmpty)
            const _EmptyFoodState(
              icon: Icons.restaurant_menu_outlined,
              title: 'No meals yet',
              subtitle: 'Create a meal menu to start food management.',
            )
          else
            for (final _MealItem meal in _meals) ...<Widget>[
              _MealManagementRow(
                meal: meal,
                onEdit: meal.id.isEmpty ? null : () => _openEditMealSheet(meal.id),
              ),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 10),
          _VotingPanel(menus: _liveVotingMenus),
          const SizedBox(height: 18),
          _ResultPanel(menus: _liveVotingMenus),
          const SizedBox(height: 18),
          _SpecialMenuPanel(menus: _chefSpecialMenus),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddMealSheet,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Meal'),
      ),
    );
  }

  String _menuDateKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}

class _HeroHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      height: 218,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        image: const DecorationImage(
          image: NetworkImage(
            'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80',
          ),
          fit: BoxFit.cover,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x220F172A),
            blurRadius: 28,
            offset: Offset(0, 18),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0x330F172A), Color(0xA6111827)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const ToneBadge(label: 'PG Food OS', tone: UiTone.brand),
              const Spacer(),
              Text(
                'Run menus,\nvoting and feedback',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create weekly meals, collect resident votes, finalize winners and notify everyone.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.metrics});

  final List<_FoodMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.border),
          bottom: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < metrics.length; i++) ...<Widget>[
            Expanded(child: _MetricItem(metric: metrics[i])),
            if (i < metrics.length - 1)
              const SizedBox(
                height: 54,
                child: VerticalDivider(width: 1, color: AppTheme.border),
              ),
          ],
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({required this.metric});

  final _FoodMetric metric;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      children: <Widget>[
        Icon(metric.icon, color: metric.color, size: 22),
        const SizedBox(height: 8),
        Text(
          metric.value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          metric.label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        if (action != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                action!,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: onAction == null
                      ? AppTheme.textSecondary
                      : AppTheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PropertyFoodCard extends StatelessWidget {
  const _PropertyFoodCard({
    required this.property,
    this.selected = false,
    this.onTap,
  });

  final _FoodProperty property;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 276,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x12111827),
              blurRadius: 20,
              offset: Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Image.network(
                property.image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: AppTheme.primarySoft,
                  child: Icon(Icons.apartment_rounded, size: 48),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.black.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.72),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ToneBadge(
                    label: property.status,
                    tone: selected ? UiTone.brand : UiTone.success,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    property.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.groups_2_outlined,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${property.residents} residents',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Icon(
                        Icons.schedule_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          property.timing,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyCalendar extends StatelessWidget {
  const _WeeklyCalendar({
    required this.selectedDate,
    required this.onSelected,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final DateTime today = DateTime.now();
    final DateTime todayOnly = DateTime(today.year, today.month, today.day);
    final List<DateTime> dates = List<DateTime>.generate(
      7,
      (int index) => todayOnly.add(Duration(days: index)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionTitle(title: 'Menu Date'),
        const SizedBox(height: 4),
        Text(
          'Dates update automatically every day. Select a date to create that day menu.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (BuildContext context, int index) {
              final DateTime date = dates[index];
              final bool selected = _sameDate(date, selectedDate);
              final bool isToday = _sameDate(date, todayOnly);
              return InkWell(
                onTap: () => onSelected(date),
                borderRadius: BorderRadius.circular(22),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 72,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primary : AppTheme.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: selected ? AppTheme.primary : AppTheme.border,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        _weekdayLabel(date),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: selected ? Colors.white : AppTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${date.day}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: selected ? Colors.white : AppTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isToday ? 'Today' : _monthLabel(date),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: selected
                              ? Colors.white.withValues(alpha: 0.82)
                              : AppTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemCount: dates.length,
          ),
        ),
      ],
    );
  }

  bool _sameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String _weekdayLabel(DateTime date) {
    const List<String> labels = <String>[
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    return labels[date.weekday - 1];
  }

  String _monthLabel(DateTime date) {
    const List<String> labels = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return labels[date.month - 1];
  }
}

class _MealManagementRow extends StatelessWidget {
  const _MealManagementRow({required this.meal, this.onEdit});

  final _MealItem meal;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.network(
              meal.image,
              width: 78,
              height: 78,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 78,
                height: 78,
                color: AppTheme.primarySoft,
                child: const Icon(Icons.restaurant_rounded),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  meal.meal,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: meal.tone,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  meal.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  meal.items,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Icon(Icons.how_to_vote_rounded, size: 15, color: meal.tone),
                    const SizedBox(width: 4),
                    Text(
                      '${meal.votes} votes',
                      style: theme.textTheme.labelSmall,
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.star_rounded,
                      size: 15,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 4),
                    Text('${meal.rating}', style: theme.textTheme.labelSmall),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'edit') {
                if (onEdit != null) {
                  onEdit!();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Edit data is not available for this meal yet.'),
                    ),
                  );
                }
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${value[0].toUpperCase()}${value.substring(1)} action is UI-only for now.',
                  ),
                ),
              );
            },
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                  PopupMenuItem<String>(
                    value: 'duplicate',
                    child: Text('Duplicate'),
                  ),
                  PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
                ],
          ),
        ],
      ),
    );
  }
}

class _AddMealSheet extends StatefulWidget {
  const _AddMealSheet({required this.selectedDate, this.initialDraft});

  final DateTime selectedDate;
  final _AddMealDraft? initialDraft;

  @override
  State<_AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealDraft {
  const _AddMealDraft({
    this.menuId,
    required this.mealType,
    required this.menuTitle,
    required this.options,
    required this.calories,
    required this.chefSpecial,
    required this.copyToWeek,
  });

  final String? menuId;
  final int mealType;
  final String menuTitle;
  final List<String> options;
  final int calories;
  final bool chefSpecial;
  final bool copyToWeek;
}

class _AddMealSheetState extends State<_AddMealSheet> {
  static const int _minVotingChoices = 2;
  static const int _maxVotingChoices = 10;
  static const List<String> _dayLabels = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  late final TextEditingController _mealNameController;
  late final List<TextEditingController> _optionControllers;
  late final TextEditingController _caloriesController;
  late int _mealType;
  late bool _chefSpecial;
  late bool _copyToWeek;

  static const List<String> _mealTypes = <String>[
    'Breakfast',
    'Lunch',
    'Snacks',
    'Dinner',
  ];

  @override
  void initState() {
    super.initState();
    final _AddMealDraft? initialDraft = widget.initialDraft;
    _mealNameController = TextEditingController(
      text: initialDraft?.menuTitle ?? '',
    );
    final List<String> initialOptions = List<String>.from(
      initialDraft?.options ?? <String>[],
    );
    while (initialOptions.length < _minVotingChoices) {
      initialOptions.add('');
    }
    _optionControllers = initialOptions
        .take(_maxVotingChoices)
        .map((String value) => TextEditingController(text: value))
        .toList();
    _caloriesController = TextEditingController(
      text: '${initialDraft?.calories ?? 650}',
    );
    _mealType = initialDraft?.mealType ?? 1;
    _chefSpecial = initialDraft?.chefSpecial ?? false;
    _copyToWeek = initialDraft?.copyToWeek ?? false;
  }

  @override
  void dispose() {
    _mealNameController.dispose();
    for (final TextEditingController controller in _optionControllers) {
      controller.dispose();
    }
    _caloriesController.dispose();
    super.dispose();
  }

  void _saveDraft() {
    final String menuTitle = _mealNameController.text.trim();
    final List<String> options = _optionControllers
        .map((TextEditingController controller) => controller.text.trim())
        .where((String value) => value.isNotEmpty)
        .toList();
    if (menuTitle.isEmpty) {
      _showUiOnlyMessage('Enter a menu title.');
      return;
    }
    if (options.length < 2) {
      _showUiOnlyMessage('Enter at least two separate voting choices.');
      return;
    }
    Navigator.of(context).pop(
      _AddMealDraft(
        menuId: widget.initialDraft?.menuId,
        mealType: _mealType,
        menuTitle: menuTitle,
        options: options,
        calories: int.tryParse(_caloriesController.text.trim()) ?? 0,
        chefSpecial: _chefSpecial,
        copyToWeek: _copyToWeek,
      ),
    );
  }

  void _showUiOnlyMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _addVotingChoice() {
    if (_optionControllers.length >= _maxVotingChoices) {
      _showUiOnlyMessage('Maximum $_maxVotingChoices voting choices allowed.');
      return;
    }
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeVotingChoice(int index) {
    if (_optionControllers.length <= _minVotingChoices) {
      _showUiOnlyMessage('At least $_minVotingChoices choices are required.');
      return;
    }
    final TextEditingController controller = _optionControllers.removeAt(index);
    controller.dispose();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String mealTypeLabel = _mealTypes[_mealType];
    final int selectedDay = widget.selectedDate.weekday - 1;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.58,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController scrollController) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              18,
              12,
              18,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            children: <Widget>[
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.borderStrong,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0xFFF8FAFF), Colors.white],
                  ),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.restaurant_menu_rounded,
                            color: AppTheme.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                widget.initialDraft == null
                                    ? 'Create meal menu'
                                    : 'Edit meal menu',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Keep this simple and clear so residents understand the meal instantly.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _AddMealHighlight(
                            icon: Icons.schedule_rounded,
                            label: 'Meal type',
                            value: mealTypeLabel,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _AddMealHighlight(
                            icon: Icons.edit_calendar_outlined,
                            label: 'Menu date',
                            value: _dateLabel(widget.selectedDate, selectedDay),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _AddMealSection(
                title: 'Meal type',
                subtitle: 'Choose where this menu belongs.',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List<Widget>.generate(_mealTypes.length, (int index) {
                    final bool selected = _mealType == index;
                    return _MealTypeChip(
                      label: _mealTypes[index],
                      selected: selected,
                      icon: _mealTypeIcon(index),
                      onTap: () => setState(() => _mealType = index),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 14),
              _AddMealSection(
                title: 'Meal details',
                subtitle: 'Add a title and separate choices residents can vote on.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextField(
                      controller: _mealNameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Menu title',
                        hintText: 'Example: Monday Lunch Menu',
                        prefixIcon: Icon(Icons.restaurant_menu_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _MealOptionsEditor(
                      controllers: _optionControllers,
                      maxChoices: _maxVotingChoices,
                      onAddChoice: _addVotingChoice,
                      onRemoveChoice: _removeVotingChoice,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _caloriesController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Calories',
                              hintText: '650',
                              prefixIcon: Icon(
                                Icons.local_fire_department_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            _showUiOnlyMessage(
                              'Photo picker UI is ready. Connect upload API to save images.',
                            );
                          },
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('Photo'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 56),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _AddMealSection(
                title: 'Visibility',
                subtitle: 'Decide how this menu should appear in the app.',
                child: Column(
                  children: <Widget>[
                    _InlineToggleTile(
                      value: _chefSpecial,
                      onChanged: (bool value) {
                        setState(() => _chefSpecial = value);
                      },
                      icon: Icons.workspace_premium_outlined,
                      title: 'Chef special',
                      subtitle: 'Highlight this meal in the resident view.',
                    ),
                    const Divider(height: 1, color: AppTheme.border),
                    _InlineToggleTile(
                      value: _copyToWeek,
                      onChanged: (bool value) {
                        setState(() => _copyToWeek = value);
                      },
                      icon: Icons.auto_awesome_motion_outlined,
                      title: 'Copy to remaining week',
                      subtitle: 'Reuse this menu for later days.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        _showUiOnlyMessage('Meal duplicated in draft UI.');
                      },
                      icon: const Icon(Icons.content_copy_outlined),
                      label: const Text('Duplicate'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saveDraft,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save Meal'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _daysLabel(int dayIndex) {
    if (dayIndex < 0 || dayIndex >= _dayLabels.length) {
      return 'This week';
    }
    return _dayLabels[dayIndex];
  }

  String _dateLabel(DateTime date, int dayIndex) {
    return '${_daysLabel(dayIndex)} ${date.day}/${date.month}';
  }

  IconData _mealTypeIcon(int index) {
    switch (index) {
      case 0:
        return Icons.wb_sunny_outlined;
      case 1:
        return Icons.lunch_dining_outlined;
      case 2:
        return Icons.icecream_outlined;
      case 3:
        return Icons.nightlight_round_outlined;
      default:
        return Icons.restaurant_outlined;
    }
  }
}

class _AddMealHighlight extends StatelessWidget {
  const _AddMealHighlight({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddMealSection extends StatelessWidget {
  const _AddMealSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MealTypeChip extends StatelessWidget {
  const _MealTypeChip({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 18,
              color: selected ? AppTheme.primary : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: selected ? AppTheme.primary : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineToggleTile extends StatelessWidget {
  const _InlineToggleTile({
    required this.value,
    required this.onChanged,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: AppTheme.textPrimary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch.adaptive(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _MealOptionsEditor extends StatelessWidget {
  const _MealOptionsEditor({
    required this.controllers,
    required this.maxChoices,
    required this.onAddChoice,
    required this.onRemoveChoice,
  });

  final List<TextEditingController> controllers;
  final int maxChoices;
  final VoidCallback onAddChoice;
  final ValueChanged<int> onRemoveChoice;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.restaurant_outlined,
                color: Color(0xFF2563EB),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Voting choices',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Add every voting option separately. Residents will choose one option.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (int index = 0; index < controllers.length; index++) ...<Widget>[
          _MealOptionField(
            controller: controllers[index],
            number: index + 1,
            canRemove: controllers.length > 2,
            label: _optionLabel(index),
            hint: _optionHint(index),
            isLast: index == controllers.length - 1,
            onRemove: () => onRemoveChoice(index),
          ),
          if (index < controllers.length - 1) const SizedBox(height: 10),
        ],
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: controllers.length >= maxChoices
                    ? null
                    : onAddChoice,
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  controllers.length >= maxChoices
                      ? 'Maximum choices added'
                      : 'Add Choice',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${controllers.length}/$maxChoices',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _optionHint(int index) {
    const List<String> hints = <String>[
      'Roti',
      'Chapati',
      'Paratha',
      'Paneer curry',
      'Dal rice',
      'Veg biryani',
      'Curd rice',
      'Idli sambar',
      'Puri bhaji',
      'Fried rice',
    ];
    return hints[index.clamp(0, hints.length - 1)];
  }

  static String _optionLabel(int index) {
    const List<String> labels = <String>[
      'Choice A',
      'Choice B',
      'Choice C',
      'Choice D',
      'Choice E',
      'Choice F',
      'Choice G',
      'Choice H',
      'Choice I',
      'Choice J',
    ];
    return labels[index.clamp(0, labels.length - 1)];
  }
}

class _MealOptionField extends StatelessWidget {
  const _MealOptionField({
    required this.controller,
    required this.number,
    required this.canRemove,
    required this.label,
    required this.hint,
    required this.isLast,
    required this.onRemove,
  });

  final TextEditingController controller;
  final int number;
  final bool canRemove;
  final String label;
  final String hint;
  final bool isLast;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: isLast
                ? TextInputAction.done
                : TextInputAction.next,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              helperText: number <= 2
                  ? 'Required for resident voting.'
                  : 'Optional voting choice.',
              prefixIcon: const Icon(Icons.radio_button_unchecked_rounded),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: canRemove ? 'Remove choice' : 'Minimum two choices required',
          child: IconButton.filledTonal(
            onPressed: canRemove ? onRemove : null,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ],
    );
  }
}

class _VotingPanel extends StatelessWidget {
  const _VotingPanel({required this.menus});

  final List<FoodMenuItem> menus;

  @override
  Widget build(BuildContext context) {
    if (menus.isEmpty) {
      return const _SoftPanel(
        title: 'Live Voting',
        subtitle: 'No live voting is available right now.',
        icon: Icons.poll_outlined,
        child: _EmptyFoodState(
          icon: Icons.how_to_vote_outlined,
          title: 'No active voting',
          subtitle: 'Create a meal with multiple options to start voting.',
          compact: true,
        ),
      );
    }
    return _SoftPanel(
      title: 'Live Voting',
      subtitle: 'Breakfast, lunch, snacks and dinner voting from live data',
      icon: Icons.poll_outlined,
      child: Column(
        children: <Widget>[
          for (int index = 0; index < menus.length; index++) ...<Widget>[
            _MealVotingResult(menu: menus[index]),
            if (index < menus.length - 1)
              const Divider(height: 28, color: AppTheme.border),
          ],
        ],
      ),
    );
  }
}

class _MealVotingResult extends StatelessWidget {
  const _MealVotingResult({required this.menu});

  final FoodMenuItem menu;

  @override
  Widget build(BuildContext context) {
    final int totalVotes = menu.voteCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                menu.mealLabel.isEmpty ? _mealTypeLabel(menu.mealType) : menu.mealLabel,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            ToneBadge(
              label: '$totalVotes votes',
              tone: totalVotes == 0 ? UiTone.neutral : UiTone.brand,
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (int index = 0; index < menu.options.length; index++) ...<Widget>[
          _VoteBar(
            label: menu.options[index].text,
            value: totalVotes == 0 ? 0 : menu.options[index].voteCount / totalVotes,
            votes: menu.options[index].voteCount,
          ),
          if (index < menu.options.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  String _mealTypeLabel(int mealType) {
    switch (mealType) {
      case 1:
        return 'Breakfast';
      case 2:
        return 'Lunch';
      case 3:
        return 'Snacks';
      case 4:
        return 'Dinner';
      default:
        return 'Meal';
    }
  }
}

class _CreateVotingSheet extends StatefulWidget {
  const _CreateVotingSheet();

  @override
  State<_CreateVotingSheet> createState() => _CreateVotingSheetState();
}

class _CreateVotingSheetState extends State<_CreateVotingSheet> {
  int _propertyIndex = 0;
  bool _multipleVotes = false;
  bool _allowSkip = true;
  bool _allowComments = true;

  static const List<String> _properties = <String>[
    'Urban Nest PG',
    'Lakeview Hostel',
  ];

  static const List<_VotingMealConfig> _configs = <_VotingMealConfig>[
    _VotingMealConfig(
      meal: 'Breakfast',
      count: 5,
      options: <String>[
        'Masala Dosa',
        'Poha',
        'Idli Sambar',
        'Aloo Paratha',
        'Upma',
      ],
    ),
    _VotingMealConfig(
      meal: 'Lunch',
      count: 5,
      options: <String>[
        'Paneer Rice Bowl',
        'Veg Biryani',
        'Rajma Chawal',
        'Curd Rice',
        'Chole Rice',
      ],
    ),
    _VotingMealConfig(
      meal: 'Snacks',
      count: 4,
      options: <String>['Veg Sandwich', 'Samosa', 'Corn Chaat', 'Masala Maggi'],
    ),
    _VotingMealConfig(
      meal: 'Dinner',
      count: 5,
      options: <String>[
        'Paneer Butter Masala',
        'Dal Tadka Thali',
        'Veg Pulao',
        'Aloo Gobi',
        'Khichdi Bowl',
      ],
    ),
  ];

  void _publishVoting() {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voting draft prepared. Connect API to publish live.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.65,
      maxChildSize: 0.96,
      builder: (BuildContext context, ScrollController scrollController) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            children: <Widget>[
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.borderStrong,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.primarySoft,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.how_to_vote_outlined,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Create Voting',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Choose meal options residents can vote for tomorrow.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SheetPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Property',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<int>(
                      segments: List<ButtonSegment<int>>.generate(
                        _properties.length,
                        (int index) => ButtonSegment<int>(
                          value: index,
                          label: Text(_properties[index]),
                        ),
                      ),
                      selected: <int>{_propertyIndex},
                      onSelectionChanged: (Set<int> selected) {
                        setState(() => _propertyIndex = selected.first);
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _VotingMetaTile(
                            icon: Icons.schedule_rounded,
                            title: 'Deadline',
                            value: 'Tomorrow 8 PM',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _VotingMetaTile(
                            icon: Icons.people_outline_rounded,
                            title: 'Residents',
                            value: '124 invited',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              for (final _VotingMealConfig config in _configs) ...<Widget>[
                _MealVotingOptions(config: config),
                const SizedBox(height: 12),
              ],
              _SheetPanel(
                child: Column(
                  children: <Widget>[
                    SwitchListTile.adaptive(
                      value: _multipleVotes,
                      onChanged: (bool value) {
                        setState(() => _multipleVotes = value);
                      },
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Allow multiple option selection'),
                      subtitle: const Text('Default is one option per meal.'),
                    ),
                    const Divider(height: 1, color: AppTheme.border),
                    SwitchListTile.adaptive(
                      value: _allowSkip,
                      onChanged: (bool value) {
                        setState(() => _allowSkip = value);
                      },
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable skip option'),
                      subtitle: const Text('Residents can skip a meal vote.'),
                    ),
                    const Divider(height: 1, color: AppTheme.border),
                    SwitchListTile.adaptive(
                      value: _allowComments,
                      onChanged: (bool value) {
                        setState(() => _allowComments = value);
                      },
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable comments'),
                      subtitle: const Text('Collect food preference notes.'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _publishVoting,
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('Publish Voting'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SheetPanel extends StatelessWidget {
  const _SheetPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
      ),
      child: child,
    );
  }
}

class _VotingMetaTile extends StatelessWidget {
  const _VotingMetaTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _MealVotingOptions extends StatelessWidget {
  const _MealVotingOptions({required this.config});

  final _VotingMealConfig config;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return _SheetPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  config.meal,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              ToneBadge(
                label: '${config.count} options',
                tone: UiTone.neutral,
                size: ToneBadgeSize.small,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: config.options
                .map(
                  (String option) => FilterChip(
                    selected: true,
                    showCheckmark: false,
                    label: Text(option),
                    avatar: const Icon(Icons.restaurant_rounded, size: 16),
                    onSelected: (_) {},
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _VoteBar extends StatelessWidget {
  const _VoteBar({
    required this.label,
    required this.value,
    required this.votes,
  });

  final String label;
  final double value;
  final int votes;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int percentage = (value * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$percentage%  $votes',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 9,
            backgroundColor: AppTheme.primarySoft,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
          ),
        ),
      ],
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.menus});

  final List<FoodMenuItem> menus;

  @override
  Widget build(BuildContext context) {
    if (menus.isEmpty) {
      return const _SoftPanel(
        title: 'Voting Result',
        subtitle: 'No meal result is available yet.',
        icon: Icons.emoji_events_outlined,
        child: _EmptyFoodState(
          icon: Icons.analytics_outlined,
          title: 'No result yet',
          subtitle: 'Results will appear after residents start voting.',
          compact: true,
        ),
      );
    }
    return _SoftPanel(
      title: 'Voting Result',
      subtitle: 'Current winners based on live resident votes',
      icon: Icons.emoji_events_outlined,
      child: Column(
        children: <Widget>[
          for (int index = 0; index < menus.length; index++) ...<Widget>[
            _MealWinnerRow(menu: menus[index]),
            if (index < menus.length - 1)
              const Divider(height: 24, color: AppTheme.border),
          ],
        ],
      ),
    );
  }
}

class _MealWinnerRow extends StatelessWidget {
  const _MealWinnerRow({required this.menu});

  final FoodMenuItem menu;

  @override
  Widget build(BuildContext context) {
    final FoodMenuOption winner = menu.options.reduce(
      (FoodMenuOption a, FoodMenuOption b) =>
          b.voteCount > a.voteCount ? b : a,
    );
    final String mealLabel = menu.mealLabel.isEmpty
        ? _mealTypeLabel(menu.mealType)
        : menu.mealLabel;
    return Row(
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.workspace_premium_rounded,
            color: Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                mealLabel,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                '${winner.text} - ${winner.voteCount} votes',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _mealTypeLabel(int mealType) {
    switch (mealType) {
      case 1:
        return 'Breakfast';
      case 2:
        return 'Lunch';
      case 3:
        return 'Snacks';
      case 4:
        return 'Dinner';
      default:
        return 'Meal';
    }
  }
}

class _SpecialMenuPanel extends StatelessWidget {
  const _SpecialMenuPanel({required this.menus});

  final List<FoodMenuItem> menus;

  @override
  Widget build(BuildContext context) {
    if (menus.isEmpty) {
      return const _SoftPanel(
        title: 'Special Menu',
        subtitle: 'No chef special menu is available.',
        icon: Icons.celebration_outlined,
        child: _EmptyFoodState(
          icon: Icons.workspace_premium_outlined,
          title: 'No special menu',
          subtitle: 'Mark a meal as chef special to show it here.',
          compact: true,
        ),
      );
    }
    return _SoftPanel(
      title: 'Special Menu',
      subtitle: 'Chef special meals from live food data',
      icon: Icons.celebration_outlined,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: menus
                  .map(
                    (FoodMenuItem item) => ToneBadge(
                      label: item.menuTitle.isEmpty
                          ? item.mealLabel
                          : item.menuTitle,
                      tone: item.whetherVotingLive
                          ? UiTone.brand
                          : UiTone.success,
                    ),
                  )
                  .toList(),
            ),
          ),
          IconButton.filledTonal(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Special menu editor is UI-only until backend is connected.',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }
}

class _SoftPanel extends StatelessWidget {
  const _SoftPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _EmptyFoodState extends StatelessWidget {
  const _EmptyFoodState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets padding = compact
        ? const EdgeInsets.all(8)
        : const EdgeInsets.symmetric(vertical: 18, horizontal: 12);
    return Padding(
      padding: padding,
      child: Column(
        children: <Widget>[
          Icon(icon, size: compact ? 26 : 34, color: AppTheme.textMuted),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FoodMetric {
  const _FoodMetric(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _FoodProperty {
  const _FoodProperty({
    required this.name,
    required this.residents,
    required this.cook,
    required this.timing,
    required this.status,
    required this.image,
  });

  final String name;
  final int residents;
  final String cook;
  final String timing;
  final String status;
  final String image;
}

class _MealItem {
  const _MealItem({
    required this.id,
    required this.name,
    required this.meal,
    required this.items,
    required this.image,
    required this.votes,
    required this.rating,
    required this.tone,
  });

  final String id;
  final String name;
  final String meal;
  final String items;
  final String image;
  final int votes;
  final double rating;
  final Color tone;
}

class _VotingMealConfig {
  const _VotingMealConfig({
    required this.meal,
    required this.count,
    required this.options,
  });

  final String meal;
  final int count;
  final List<String> options;
}
