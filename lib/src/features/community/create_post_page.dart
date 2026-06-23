import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/api/block_building_service.dart';
import '../../core/api/community_service.dart';
import '../../core/api/property_service.dart';
import '../../core/api/society_service.dart';
import '../../core/api/upload_service.dart';
import '../../core/models/api_models.dart';
import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/tone_badge.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({
    super.key,
    required this.role,
    this.societyId = '',
    this.initialMode = 'post',
  });

  final AppRole role;
  final String societyId;
  final String initialMode;

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _question = TextEditingController();
  final List<TextEditingController> _options = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];

  List<Map<String, dynamic>> _properties = <Map<String, dynamic>>[];
  SocietyData? _society;
  List<BlockData> _blocks = <BlockData>[];
  List<BuildingData> _buildings = <BuildingData>[];
  List<CommunityItem> _previewItems = <CommunityItem>[];
  Map<String, dynamic>? _property;
  String _blockId = '';
  String _buildingId = '';
  String _locationId = '';
  String _locationLabel = '';
  String _mode = 'post';
  int _duration = 1;
  bool _loading = true;
  bool _loadingPreviews = true;
  bool _saving = false;
  bool _uploading = false;
  bool _pinned = false;
  bool _important = false;
  bool _emergency = false;
  Timer? _feedRefreshTimer;
  final List<_UploadedImage> _images = <_UploadedImage>[];

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode == 'poll' ? 'poll' : 'post';
    _loadTargets();
    _feedRefreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _refreshCommunityPostsSilently(),
    );
  }

  @override
  void dispose() {
    _feedRefreshTimer?.cancel();
    _title.dispose();
    _description.dispose();
    _question.dispose();
    for (final controller in _options) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _isSocietyMode => widget.role == AppRole.societyManager;

  Future<void> _loadTargets() async {
    setState(() => _loading = true);
    try {
      if (_isSocietyMode) {
        final SocietyData? society = await SocietyService.fetchSocietyInfo();
        final String societyId = widget.societyId.isNotEmpty
            ? widget.societyId
            : society?.societyId ?? '';
        final blocksResult = societyId.isEmpty
            ? (blocks: <BlockData>[], count: 0)
            : await BlockBuildingService.filterBlocks(
                societyId,
                limit: 200,
                status: true,
              );
        final buildingsResult = societyId.isEmpty
            ? (buildings: <BuildingData>[], count: 0)
            : await BlockBuildingService.filterBuildings(
                societyId,
                limit: 500,
                status: true,
              );
        if (!mounted) return;
        setState(() {
          _society = society;
          _blocks = blocksResult.blocks;
          _buildings = buildingsResult.buildings;
          _locationId = societyId;
          _locationLabel = society?.name ?? 'All society';
          _loading = false;
        });
        await _loadPreviewItems();
        return;
      }
      final result = await PropertyService.filterPropertiesLite(limit: 200);
      if (!mounted) return;
      setState(() {
        _properties = result.properties;
        _loading = false;
      });
      await _loadPreviewItems();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _show(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _loadPreviewItems() async {
    if (mounted) setState(() => _loadingPreviews = true);
    try {
      final items = await CommunityService.filterFeed(limit: 50);
      if (!mounted) return;
      setState(() {
        _previewItems = items;
        _loadingPreviews = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPreviews = false);
    }
  }

  Future<void> _refreshCommunityPostsSilently() async {
    if (!mounted || _loading || _loadingPreviews) return;
    try {
      final items = await CommunityService.filterFeed(limit: 50);
      if (!mounted) return;
      setState(() => _previewItems = items);
    } catch (_) {}
  }

  List<_LocationChoice> get _locations {
    if (_isSocietyMode) {
      final String societyId = _society?.societyId ?? widget.societyId;
      final List<_LocationChoice> items = <_LocationChoice>[
        _LocationChoice(societyId, _society?.name ?? 'All society', 'Society'),
      ];
      for (final block in _blocks) {
        items.add(_LocationChoice(block.blockId, block.name, 'Block'));
      }
      for (final building in _buildings) {
        final String blockName =
            _blocks
                .where((block) => block.blockId == building.blockId)
                .map((block) => block.name)
                .firstOrNull ??
            '';
        items.add(
          _LocationChoice(
            building.buildingId,
            blockName.isEmpty ? building.name : '$blockName - ${building.name}',
            'Building',
          ),
        );
      }
      return items;
    }
    final Map<String, dynamic>? p = _property;
    if (p == null) return <_LocationChoice>[];
    final int type = (p['Property_Type'] as num?)?.toInt() ?? 0;
    final int floors = (p['No_Of_Floors'] as num?)?.toInt() ?? 0;
    final String unit = p['Flat_Or_Unit_No'] as String? ?? '';
    final List<_LocationChoice> items = <_LocationChoice>[
      const _LocationChoice('', 'All property', ''),
    ];
    if (unit.isNotEmpty) {
      items.add(_LocationChoice(unit, unit, 'Unit'));
    }
    for (int i = 1; i <= floors && i <= 80; i++) {
      items.add(_LocationChoice('floor_$i', 'Floor $i', 'Floor'));
    }
    if (type == 2 && unit.isNotEmpty) {
      items.add(_LocationChoice('villa_$unit', 'Villa $unit', 'Villa'));
    }
    return items;
  }

  Future<void> _uploadImages() async {
    if (_images.length >= 10) {
      _show('Maximum 10 images allowed.');
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;
    setState(() => _uploading = true);
    try {
      for (final file in result.files.take(10 - _images.length)) {
        final String? path = file.path;
        if (path == null) continue;
        final String? imageId = await UploadService.uploadImage(File(path));
        if (imageId == null) continue;
        final String? url = await UploadService.fetchImageInfo(imageId);
        _images.add(_UploadedImage(imageId, url ?? '', file.name));
      }
      if (mounted) setState(() => _uploading = false);
    } catch (error) {
      if (mounted) setState(() => _uploading = false);
      _show(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  List<String> _pollOptions() {
    return _options
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  String? _validateDraft() {
    final String propertyId = _property?['PropertyID'] as String? ?? '';
    final String societyId = _society?.societyId ?? widget.societyId;
    if (!_isSocietyMode && propertyId.isEmpty) {
      return 'Select a property.';
    }
    if (_isSocietyMode && societyId.isEmpty) {
      return 'Society profile is required before creating a post.';
    }
    if (_mode == 'post') {
      if (_title.text.trim().isEmpty || _description.text.trim().isEmpty) {
        return 'Title and description are required.';
      }
    } else if (_question.text.trim().isEmpty || _pollOptions().length < 2) {
      return 'Poll question and at least two options are required.';
    }
    return null;
  }

  Future<void> _publish() async {
    final String propertyId = _property?['PropertyID'] as String? ?? '';
    final String societyId = _society?.societyId ?? widget.societyId;
    final String? error = _validateDraft();
    if (error != null) {
      _show(error);
      return;
    }
    setState(() => _saving = true);
    try {
      if (_mode == 'post') {
        await CommunityService.createPost(
          propertyId: propertyId,
          societyId: _isSocietyMode ? societyId : '',
          blockId: _blockId,
          buildingId: _buildingId,
          title: _title.text.trim(),
          description: _description.text.trim(),
          imageIds: _images.map((item) => item.id).toList(),
          locationId: _locationId,
          locationLabel: _locationLabel,
          pinned: _pinned,
          important: _important,
          emergency: _emergency,
        );
      } else {
        final List<String> options = _pollOptions();
        await CommunityService.createPoll(
          propertyId: propertyId,
          societyId: _isSocietyMode ? societyId : '',
          blockId: _blockId,
          buildingId: _buildingId,
          question: _question.text.trim(),
          options: options,
          durationDays: _duration,
          locationId: _locationId,
          locationLabel: _locationLabel,
        );
      }
      if (!mounted) return;
      _show(_mode == 'post' ? 'Post published.' : 'Poll published.');
      _resetComposer();
      await _loadPreviewItems();
    } catch (error) {
      _show(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetComposer() {
    _title.clear();
    _description.clear();
    _question.clear();
    for (final controller in _options) {
      controller.clear();
    }
    setState(() {
      _images.clear();
      _pinned = false;
      _important = false;
      _emergency = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        titleSpacing: 12,
        title: const Text('Community Studio'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 7),
            child: Row(
              children: <Widget>[
                Expanded(child: _modeButton('post', 'Create Post')),
                const SizedBox(width: 8),
                Expanded(child: _modeButton('poll', 'Create Poll')),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 74),
              children: <Widget>[
                _composerHeader(),
                _targetPanel(),
                if (_mode == 'post') _postForm() else _pollForm(),
                _communityPostsBelow(),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 5, 8, 7),
          child: CustomButton(
            label: _mode == 'post' ? 'Publish Post' : 'Publish Poll',
            icon: const Icon(Icons.send_rounded),
            isLoading: _saving,
            onPressed: _saving ? null : _publish,
          ),
        ),
      ),
    );
  }

  Widget _postForm() {
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _title,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Add a clear title',
              prefixIcon: Icon(Icons.title_rounded),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _description,
            onChanged: (_) => setState(() {}),
            minLines: 3,
            maxLines: 7,
            decoration: const InputDecoration(
              hintText: 'What do residents need to know?',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploading ? null : _uploadImages,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text(_uploading ? 'Uploading' : 'Add photos'),
                ),
              ),
              const SizedBox(width: 8),
              ToneBadge(label: '${_images.length}/10', tone: UiTone.neutral),
            ],
          ),
          if (_images.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = _images[index];
                  return Stack(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: item.url.isEmpty
                            ? Container(
                                width: 72,
                                color: AppTheme.primarySoft,
                                child: const Icon(Icons.image_outlined),
                              )
                            : Image.network(
                                item.url,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: InkWell(
                          onTap: () => setState(() => _images.remove(item)),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
          _settingsChips(),
        ],
      ),
    );
  }

  Widget _propertySection() {
    if (_properties.isEmpty) {
      return _panel(
        const Text('No active properties are available for this manager.'),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: _property?['PropertyID'] as String?,
      decoration: const InputDecoration(
        labelText: 'Property',
        prefixIcon: Icon(Icons.home_work_outlined),
      ),
      items: _properties.map((item) {
        final String id = item['PropertyID'] as String? ?? '';
        final String name =
            item['Property_Display_Label'] as String? ??
            item['Property_Title'] as String? ??
            id;
        return DropdownMenuItem<String>(
          value: id,
          child: Text(name, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (value) {
        final match = _properties
            .where((item) => item['PropertyID'] == value)
            .firstOrNull;
        if (match == null) return;
        setState(() {
          _property = match;
          _locationId = '';
          _locationLabel = '';
        });
      },
    );
  }

  Widget _societyTargetSection() {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Society',
        prefixIcon: Icon(Icons.apartment_outlined),
      ),
      child: Text(
        _society?.name ?? 'Society Manager',
        style: const TextStyle(fontWeight: FontWeight.w700),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _targetPanel() {
    return _panel(
      Column(
        children: <Widget>[
          if (_isSocietyMode) _societyTargetSection() else _propertySection(),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _locationId,
            decoration: const InputDecoration(
              labelText: 'Audience location',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            items: _locations
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.id,
                    child: Text(item.label, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) {
              final choice = _locations.firstWhere((item) => item.id == value);
              setState(() {
                _locationId = choice.id;
                _locationLabel = choice.label;
                _blockId = choice.type == 'Block' ? choice.id : '';
                _buildingId = choice.type == 'Building' ? choice.id : '';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _composerHeader() {
    return Container(
      width: double.infinity,
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primarySoft,
            child: Icon(
              _isSocietyMode
                  ? Icons.apartment_rounded
                  : Icons.home_work_rounded,
              size: 18,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _targetName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _locationLabel.isEmpty ? 'Choose audience' : _locationLabel,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ToneBadge(
            label: _mode == 'post' ? 'Post' : 'Poll',
            tone: UiTone.brand,
          ),
        ],
      ),
    );
  }

  Widget _settingsChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: <Widget>[
        _flagChip(
          label: 'Pin',
          icon: Icons.push_pin_outlined,
          selected: _pinned,
          onSelected: (value) => setState(() => _pinned = value),
        ),
        _flagChip(
          label: 'Important',
          icon: Icons.priority_high_rounded,
          selected: _important,
          onSelected: (value) => setState(() => _important = value),
        ),
        _flagChip(
          label: 'Emergency',
          icon: Icons.warning_amber_rounded,
          selected: _emergency,
          onSelected: (value) => setState(() => _emergency = value),
        ),
      ],
    );
  }

  Widget _pollForm() {
    return _panel(
      Column(
        children: <Widget>[
          TextField(
            controller: _question,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Ask a poll question',
              prefixIcon: Icon(Icons.poll_outlined),
            ),
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < _options.length; i++) ...<Widget>[
            TextField(
              controller: _options[i],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Option ${i + 1}',
                prefixIcon: const Icon(Icons.radio_button_unchecked_rounded),
                suffixIcon: _options.length > 2
                    ? IconButton(
                        onPressed: () => setState(() {
                          final controller = _options.removeAt(i);
                          controller.dispose();
                        }),
                        icon: const Icon(Icons.close_rounded),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: <Widget>[
              TextButton.icon(
                onPressed: _options.length >= 10
                    ? null
                    : () =>
                          setState(() => _options.add(TextEditingController())),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add option'),
              ),
              const Spacer(),
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<int>(
                  initialValue: _duration,
                  decoration: const InputDecoration(labelText: 'Duration'),
                  items: const <int>[1, 3, 7, 30]
                      .map(
                        (days) => DropdownMenuItem<int>(
                          value: days,
                          child: Text('$days day${days == 1 ? '' : 's'}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _duration = value ?? 1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _panel(Widget child) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.borderSoft)),
      ),
      child: child,
    );
  }

  Widget _modeButton(String mode, String label) {
    final bool selected = _mode == mode;
    return OutlinedButton(
      onPressed: () => setState(() => _mode = mode),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? AppTheme.primary : AppTheme.surface,
        foregroundColor: selected ? Colors.white : AppTheme.textPrimary,
        padding: const EdgeInsets.symmetric(vertical: 10),
        side: BorderSide(
          color: selected ? AppTheme.primary : AppTheme.border,
          width: 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            mode == 'post' ? Icons.add_photo_alternate_outlined : Icons.poll,
            size: 17,
          ),
          const SizedBox(width: 6),
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _flagChip({
    required String label,
    required IconData icon,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      selected: selected,
      onSelected: onSelected,
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? AppTheme.primary : AppTheme.textSecondary,
      ),
      label: Text(label),
      selectedColor: AppTheme.primarySoft,
      backgroundColor: AppTheme.surface,
      side: BorderSide(
        color: selected ? AppTheme.primaryTone : AppTheme.border,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _communityPostsBelow() {
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.dynamic_feed_outlined, size: 18),
              const SizedBox(width: 6),
              const Text(
                'Community posts',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loadingPreviews ? null : _loadPreviewItems,
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ),
          if (_loadingPreviews)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_previewItems.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'No community posts yet.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            ..._previewItems.take(12).map(_communityPostTile),
        ],
      ),
    );
  }

  Widget _communityPostTile(CommunityItem item) {
    final bool isPoll = item.type == CommunityContentType.poll;
    final String? imageUrl = item.images.isNotEmpty ? item.images.first : null;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.borderSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primarySoft,
                child: Icon(
                  isPoll ? Icons.poll_outlined : Icons.article_outlined,
                  color: AppTheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.propertyName.isEmpty
                          ? 'Community'
                          : item.propertyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      item.locationLabel.isEmpty
                          ? 'All audience'
                          : item.locationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.pinned)
                const ToneBadge(label: 'Pinned', tone: UiTone.brand)
              else if (item.emergency)
                const ToneBadge(label: 'Emergency', tone: UiTone.danger)
              else if (item.important)
                const ToneBadge(label: 'Important', tone: UiTone.warning),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          if (item.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 3),
            Text(
              item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ],
          if (imageUrl != null) ...<Widget>[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          ],
          if (isPoll && item.options.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            ...item.options
                .take(3)
                .map((option) => _pollResultRow(item: item, option: option)),
          ],
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Icon(
                item.liked ? Icons.favorite_rounded : Icons.favorite_border,
                size: 17,
                color: item.liked ? Colors.red : AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                '${item.likeCount}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 14),
              const Icon(
                Icons.mode_comment_outlined,
                size: 17,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                '${item.commentCount}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (isPoll) ...<Widget>[
                const SizedBox(width: 14),
                const Icon(
                  Icons.how_to_vote_outlined,
                  size: 17,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${item.voteCount} votes',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _pollResultRow({
    required CommunityItem item,
    required CommunityPollOption option,
  }) {
    final double pct = item.voteCount == 0
        ? 0
        : option.voteCount / item.voteCount;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct.clamp(0, 1),
              child: const DecoratedBox(
                decoration: BoxDecoration(color: AppTheme.primarySoft),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    option.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${option.voteCount} · ${(pct * 100).round()}%',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
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

  String get _targetName {
    if (_isSocietyMode) return _society?.name ?? 'Society';
    return _property?['Property_Display_Label'] as String? ??
        _property?['Property_Title'] as String? ??
        'Select property';
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _UploadedImage {
  const _UploadedImage(this.id, this.url, this.name);
  final String id;
  final String url;
  final String name;
}

class _LocationChoice {
  const _LocationChoice(this.id, this.label, this.type);
  final String id;
  final String label;
  final String type;
}
