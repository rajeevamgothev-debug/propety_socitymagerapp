import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/community_service.dart';
import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tone_badge.dart';
import 'create_post_page.dart';

class CommunityFeedPage extends StatefulWidget {
  const CommunityFeedPage({
    super.key,
    required this.canInteract,
    this.role,
    this.societyId = '',
  });

  final bool canInteract;
  final AppRole? role;
  final String societyId;

  @override
  State<CommunityFeedPage> createState() => _CommunityFeedPageState();
}

class _CommunityFeedPageState extends State<CommunityFeedPage> {
  List<CommunityItem> _items = <CommunityItem>[];
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _refreshSilently(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await CommunityService.filterFeed();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (mounted) setState(() => _loading = false);
      _show(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _refreshSilently() async {
    if (!mounted || _loading) return;
    try {
      final items = await CommunityService.filterFeed();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final pinned = _items.where((item) => item.pinned).take(12).toList();
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        titleSpacing: 12,
        title: const Text('Community'),
        actions: <Widget>[
          if (widget.role == AppRole.societyManager ||
              widget.role == AppRole.propertyManager)
            IconButton(
              tooltip: 'Create',
              onPressed: _openCreateMenu,
              icon: const Icon(Icons.add_rounded),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.borderSoft),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
            ? ListView(
                padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
                children: const <Widget>[
                  Icon(
                    Icons.dynamic_feed_outlined,
                    size: 42,
                    color: AppTheme.textMuted,
                  ),
                  SizedBox(height: 10),
                  Center(
                    child: Text(
                      'No community posts yet',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _items.length + (pinned.isEmpty ? 0 : 1),
                itemBuilder: (context, index) {
                  if (pinned.isNotEmpty && index == 0) {
                    return _PinnedRail(items: pinned);
                  }
                  final itemIndex = index - (pinned.isEmpty ? 0 : 1);
                  return _CommunityCard(
                    item: _items[itemIndex],
                    canInteract: widget.canInteract,
                    onChanged: _load,
                  );
                },
              ),
      ),
    );
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openCreateMenu() async {
    final AppRole? role = widget.role;
    if (role == null) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.surface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _CreateChoice(
                icon: Icons.add_photo_alternate_outlined,
                title: 'Create Post',
                subtitle: 'Share photos, alerts, and updates',
                onTap: () => _openComposer(context, role, 'post'),
              ),
              const SizedBox(height: 8),
              _CreateChoice(
                icon: Icons.poll_outlined,
                title: 'Create Poll',
                subtitle: 'Ask residents to vote',
                onTap: () => _openComposer(context, role, 'poll'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openComposer(BuildContext sheetContext, AppRole role, String mode) {
    Navigator.of(sheetContext).pop();
    Navigator.of(context)
        .push<void>(
          MaterialPageRoute<void>(
            builder: (_) => CreatePostPage(
              role: role,
              societyId: widget.societyId,
              initialMode: mode,
            ),
          ),
        )
        .then((_) => _load());
  }
}

class _CreateChoice extends StatelessWidget {
  const _CreateChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderSoft),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primarySoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _PinnedRail extends StatelessWidget {
  const _PinnedRail({required this.items});

  final List<CommunityItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.borderSoft)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return SizedBox(
            width: 70,
            child: Column(
              children: <Widget>[
                _GradientAvatar(label: item.propertyName, size: 58),
                const SizedBox(height: 5),
                Text(
                  item.title.isEmpty ? 'Pinned' : item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CommunityCard extends StatefulWidget {
  const _CommunityCard({
    required this.item,
    required this.canInteract,
    required this.onChanged,
  });

  final CommunityItem item;
  final bool canInteract;
  final Future<void> Function() onChanged;

  @override
  State<_CommunityCard> createState() => _CommunityCardState();
}

class _CommunityCardState extends State<_CommunityCard> {
  int _imageIndex = 0;

  CommunityItem get item => widget.item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.borderSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _PostHeader(item: item),
          if (item.type == CommunityContentType.post)
            _MediaCarousel(
              item: item,
              imageIndex: _imageIndex,
              onChanged: (value) => setState(() => _imageIndex = value),
            )
          else
            _PollPanel(
              item: item,
              canInteract: widget.canInteract,
              onChanged: widget.onChanged,
            ),
          _ActionRow(
            item: item,
            canInteract: widget.canInteract,
            onComment: () => _openComments(context),
            onChanged: widget.onChanged,
          ),
          _CaptionBlock(item: item),
        ],
      ),
    );
  }

  Future<void> _openComments(BuildContext context) async {
    if (!widget.canInteract) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.surface,
      builder: (_) => _CommentsSheet(item: item),
    );
    await widget.onChanged();
  }
}

class _PostHeader extends StatelessWidget {
  const _PostHeader({required this.item});

  final CommunityItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      child: Row(
        children: <Widget>[
          _GradientAvatar(label: item.propertyName, size: 42),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.propertyName.isEmpty ? 'Community' : item.propertyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                Text(
                  [
                    if (item.locationLabel.isNotEmpty) item.locationLabel,
                    _timeAgo(item.createdAt),
                  ].join(' · '),
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
            const ToneBadge(label: 'Alert', tone: UiTone.danger)
          else if (item.important)
            const ToneBadge(label: 'Important', tone: UiTone.warning),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_horiz_rounded),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _MediaCarousel extends StatelessWidget {
  const _MediaCarousel({
    required this.item,
    required this.imageIndex,
    required this.onChanged,
  });

  final CommunityItem item;
  final int imageIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    if (item.images.isEmpty) {
      return AspectRatio(
        aspectRatio: 1,
        child: Container(
          color: AppTheme.surfaceMuted,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(20),
          child: Text(
            item.title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      );
    }
    return Stack(
      children: <Widget>[
        AspectRatio(
          aspectRatio: 1,
          child: PageView.builder(
            itemCount: item.images.length,
            onPageChanged: onChanged,
            itemBuilder: (context, index) => Image.network(
              item.images[index],
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: AppTheme.surfaceMuted,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
        ),
        if (item.images.length > 1)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0x99000000),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${imageIndex + 1}/${item.images.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.item,
    required this.canInteract,
    required this.onComment,
    required this.onChanged,
  });

  final CommunityItem item;
  final bool canInteract;
  final VoidCallback onComment;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 4, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: canInteract
                ? () async {
                    await CommunityService.toggleReaction(item);
                    await onChanged();
                  }
                : null,
            icon: Icon(
              item.liked ? Icons.favorite_rounded : Icons.favorite_border,
              color: item.liked ? const Color(0xFFE53935) : null,
            ),
          ),
          IconButton(
            onPressed: canInteract ? onComment : null,
            icon: const Icon(Icons.mode_comment_outlined),
          ),
          IconButton(
            onPressed: () => Share.share(item.title),
            icon: const Icon(Icons.send_outlined),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: Icon(
              item.pinned ? Icons.bookmark_rounded : Icons.bookmark_border,
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptionBlock extends StatelessWidget {
  const _CaptionBlock({required this.item});

  final CommunityItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${item.likeCount} like${item.likeCount == 1 ? '' : 's'}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          ),
          const SizedBox(height: 3),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                height: 1.35,
              ),
              children: <TextSpan>[
                TextSpan(
                  text:
                      '${(item.propertyName.isEmpty ? 'community' : item.propertyName).replaceAll(' ', '').toLowerCase()} ',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                TextSpan(text: item.title),
              ],
            ),
          ),
          if (item.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              item.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            item.commentCount == 0
                ? 'Add a comment'
                : 'View all ${item.commentCount} comments',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PollPanel extends StatelessWidget {
  const _PollPanel({
    required this.item,
    required this.canInteract,
    required this.onChanged,
  });

  final CommunityItem item;
  final bool canInteract;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),
            ...item.options.map(
              (option) => _PollOption(
                item: item,
                option: option,
                canInteract: canInteract,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PollOption extends StatelessWidget {
  const _PollOption({
    required this.item,
    required this.option,
    required this.canInteract,
    required this.onChanged,
  });

  final CommunityItem item;
  final CommunityPollOption option;
  final bool canInteract;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = item.userVoteOptionId == option.id;
    final pct = item.voteCount == 0 ? 0.0 : option.voteCount / item.voteCount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: !canInteract || item.userVoteOptionId != null
            ? null
            : () async {
                await CommunityService.vote(item.id, option.id);
                await onChanged();
              },
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: pct.clamp(0, 1),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primaryTone
                        : AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(
                  color: selected ? AppTheme.primary : AppTheme.border,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      option.text,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '${(pct * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w900),
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

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.item});

  final CommunityItem item;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  List<CommunityComment> _comments = <CommunityComment>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final comments = await CommunityService.filterComments(item: widget.item);
    if (!mounted) return;
    setState(() {
      _comments = comments;
      _loading = false;
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await CommunityService.createComment(item: widget.item, comment: text);
    _controller.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          10,
          0,
          10,
          MediaQuery.of(context).viewInsets.bottom + 8,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .78,
          child: Column(
            children: <Widget>[
              const Text(
                'Comments',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        itemCount: _comments.length,
                        separatorBuilder: (context, index) => const Divider(
                          height: 1,
                          color: AppTheme.borderSoft,
                        ),
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: _GradientAvatar(
                              label: comment.comment,
                              size: 34,
                            ),
                            title: Text(comment.comment),
                            subtitle: Text('${comment.replyCount} replies'),
                            trailing: TextButton(
                              onPressed: () => _reply(comment),
                              child: const Text('Reply'),
                            ),
                          );
                        },
                      ),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _reply(CommunityComment parent) async {
    final reply = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reply'),
        content: TextField(
          controller: reply,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Write a reply'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final text = reply.text.trim();
              if (text.isNotEmpty) {
                await CommunityService.createComment(
                  item: widget.item,
                  comment: text,
                  parentCommentId: parent.id,
                );
              }
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
    reply.dispose();
    await _load();
  }
}

class _GradientAvatar extends StatelessWidget {
  const _GradientAvatar({required this.label, required this.size});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final text = label.trim().isEmpty ? 'C' : label.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: <Color>[
            Color(0xFFF58529),
            Color(0xFFDD2A7B),
            Color(0xFF8134AF),
            Color(0xFF515BD4),
          ],
        ),
      ),
      child: CircleAvatar(
        backgroundColor: AppTheme.surface,
        child: Text(
          text,
          style: TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.w900,
            fontSize: size * .34,
          ),
        ),
      ),
    );
  }
}

String _timeAgo(DateTime value) {
  final diff = DateTime.now().difference(value);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${value.day}/${value.month}/${value.year}';
}
