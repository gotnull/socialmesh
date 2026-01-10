import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/content_moderation_warning.dart';
import '../../../utils/snackbar.dart';
import '../../../models/social.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/profile_providers.dart';
import '../../../providers/signal_providers.dart';
import '../../../providers/social_providers.dart';
import '../../../services/notifications/push_notification_service.dart';
import '../../../services/signal_service.dart';
import '../widgets/signal_card.dart';

/// Detail screen for a signal with replies.
class SignalDetailScreen extends ConsumerStatefulWidget {
  const SignalDetailScreen({super.key, required this.signal});

  final Post signal;

  @override
  ConsumerState<SignalDetailScreen> createState() => _SignalDetailScreenState();
}

class _SignalDetailScreenState extends ConsumerState<SignalDetailScreen> {
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isSubmittingReply = false;
  Post? _currentSignal; // Track updated signal with current commentCount
  List<SignalResponse>? _responses;
  bool _isLoadingResponses = true;
  StreamSubscription<ContentRefreshEvent>? _refreshSubscription;
  StreamSubscription<String>? _responseUpdateSubscription;

  // Reply-to state
  String? _replyingToId;
  String? _replyingToAuthor;

  // Sticky header state
  bool _showStickyHeader = false;
  static const double _stickyThreshold = 150.0;

  @override
  void initState() {
    super.initState();
    _currentSignal = widget.signal;
    _loadResponses();
    _setupRefreshListeners();
    _scrollController.addListener(_onScroll);

    // Ensure the Firestore comments listener is active for this signal
    ref.read(signalServiceProvider).ensureCommentsListener(widget.signal.id);
  }

  void _onScroll() {
    final shouldShow = _scrollController.offset > _stickyThreshold;
    if (shouldShow != _showStickyHeader) {
      setState(() => _showStickyHeader = shouldShow);
    }
  }

  void _setupRefreshListeners() {
    AppLogging.signals(
      '🔔 Setting up refresh listeners for signal ${widget.signal.id}',
    );

    // Listen for push notification refresh events
    _refreshSubscription = PushNotificationService().onContentRefresh.listen(
      _onContentRefresh,
      onError: (e) => AppLogging.signals('🔔 Refresh listener error: $e'),
    );

    // Listen for Firestore response updates (more reliable than push)
    _responseUpdateSubscription = ref
        .read(signalServiceProvider)
        .onResponseUpdate
        .listen(_onResponseUpdate);
  }

  void _onResponseUpdate(String signalId) {
    if (signalId == widget.signal.id) {
      AppLogging.signals(
        '🔔 Firestore response update for signal ${widget.signal.id}',
      );
      _loadResponses();
    }
  }

  void _onContentRefresh(ContentRefreshEvent event) {
    AppLogging.signals(
      '🔔 Content refresh event: type=${event.contentType}, targetId=${event.targetId}',
    );
    // Only refresh if this is a signal response for the signal we're viewing
    if (event.contentType == 'signal_response' &&
        event.targetId == widget.signal.id) {
      AppLogging.signals(
        '🔔 Received refresh event for signal ${widget.signal.id}',
      );
      _loadResponses();
    } else {
      AppLogging.signals(
        '🔔 Ignoring event - expected signal_response for ${widget.signal.id}',
      );
    }
  }

  Future<void> _loadResponses() async {
    if (!mounted) return;
    setState(() => _isLoadingResponses = true);

    try {
      final responses = await ref
          .read(signalServiceProvider)
          .getResponses(widget.signal.id);
      if (mounted) {
        setState(() {
          _responses = responses;
          _isLoadingResponses = false;
        });
      }
    } catch (e) {
      AppLogging.signals('Error loading responses: $e');
      if (mounted) {
        setState(() {
          _responses = [];
          _isLoadingResponses = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _refreshSubscription?.cancel();
    _responseUpdateSubscription?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  void _handleReplyTo(SignalResponse response) {
    setState(() {
      _replyingToId = response.id;
      _replyingToAuthor = response.authorName ?? 'Someone';
    });
    _replyFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToId = null;
      _replyingToAuthor = null;
    });
  }

  Future<void> _submitReply() async {
    final content = _replyController.text.trim();
    if (content.isEmpty) return;

    // Auth gating check
    final isAuthenticated = ref.read(isSignedInProvider);
    if (!isAuthenticated) {
      AppLogging.signals('🔒 Response blocked: user not authenticated');
      if (mounted) {
        showErrorSnackBar(context, 'Sign in required to comment');
      }
      return;
    }

    setState(() => _isSubmittingReply = true);

    // Content moderation check
    try {
      final moderationService = ref.read(contentModerationServiceProvider);
      final checkResult = await moderationService.checkText(
        content,
        useServerCheck: true,
      );

      if (!checkResult.passed || checkResult.action == 'reject') {
        // Content blocked - show error and allow editing
        if (mounted) {
          final action = await ContentModerationWarning.show(
            context,
            result: ContentModerationCheckResult(
              passed: false,
              action: 'reject',
              categories: checkResult.categories.map((c) => c.name).toList(),
              details: checkResult.details,
            ),
          );
          if (action == ContentModerationAction.edit) {
            // User wants to edit - keep focus on reply field
            setState(() => _isSubmittingReply = false);
            return;
          }
          if (action == ContentModerationAction.cancel) {
            setState(() => _isSubmittingReply = false);
            return;
          }
        }
        return;
      } else if (checkResult.action == 'review' ||
          checkResult.action == 'flag') {
        // Content flagged - show warning but allow to proceed
        if (mounted) {
          final action = await ContentModerationWarning.show(
            context,
            result: ContentModerationCheckResult(
              passed: true,
              action: checkResult.action,
              categories: checkResult.categories.map((c) => c.name).toList(),
              details: checkResult.details,
            ),
          );
          if (action == ContentModerationAction.cancel) {
            setState(() => _isSubmittingReply = false);
            return;
          }
          if (action == ContentModerationAction.edit) {
            // User wants to edit - keep focus on reply field
            setState(() => _isSubmittingReply = false);
            return;
          }
          // If action is proceed, continue with submission
        }
      }
    } catch (e) {
      AppLogging.signals('Content moderation check failed: $e');
      // Continue with submission if moderation service fails
    }

    try {
      final service = ref.read(signalServiceProvider);
      final profile = ref.read(userProfileProvider).value;
      AppLogging.signals(
        '📝 SignalDetailScreen: Submitting response to signal ${widget.signal.id}'
        '${_replyingToId != null ? ' (reply to $_replyingToId)' : ''}',
      );
      final response = await service.createResponse(
        signalId: widget.signal.id,
        content: content,
        authorName: profile?.displayName,
        parentId: _replyingToId,
      );

      if (response != null) {
        AppLogging.signals(
          '📝 SignalDetailScreen: Response created: ${response.id}',
        );
        _replyController.clear();
        _cancelReply();

        // Reload signal from DB to get updated commentCount
        final updatedSignal = await service.getSignalById(widget.signal.id);
        if (updatedSignal != null) {
          _currentSignal = updatedSignal;
        }

        // Reload responses to show the new one
        await _loadResponses();
      } else {
        AppLogging.signals(
          '📝 SignalDetailScreen: Response creation returned null',
        );
        if (mounted) {
          showErrorSnackBar(context, 'Failed to send response');
        }
      }
    } catch (e) {
      AppLogging.signals('Error creating response: $e');
      if (mounted) {
        showErrorSnackBar(context, 'Failed to send response');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingReply = false);
      }
    }
  }

  Widget _buildResponsesList(BuildContext context) {
    if (_isLoadingResponses) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: context.accentColor,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading responses...',
              style: TextStyle(color: context.textTertiary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final allResponses = _responses ?? [];

    if (allResponses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.border.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: context.accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 28,
                color: context.accentColor.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No responses yet',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Be the first to respond to this signal',
              style: TextStyle(color: context.textTertiary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Organize responses into tree structure
    final rootResponses = allResponses
        .where((r) => r.parentId == null)
        .toList();
    final repliesMap = <String, List<SignalResponse>>{};

    for (final r in allResponses) {
      if (r.parentId != null) {
        repliesMap.putIfAbsent(r.parentId!, () => []).add(r);
      }
    }

    // Flatten tree into display list with depth and sibling info
    final displayList = <_ResponseDisplayItem>[];

    void addWithReplies(
      SignalResponse response,
      int depth,
      List<bool> ancestorHasMoreSiblings,
      bool isFirstChild,
      bool isLastChild,
    ) {
      final replies = repliesMap[response.id] ?? [];
      replies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final hasReplies = replies.isNotEmpty;

      displayList.add(
        _ResponseDisplayItem(
          response: response,
          depth: depth,
          hasReplies: hasReplies,
          isFirstChild: isFirstChild,
          isLastChild: isLastChild,
          ancestorHasMoreSiblings: List.from(ancestorHasMoreSiblings),
        ),
      );

      for (var i = 0; i < replies.length; i++) {
        final isFirst = i == 0;
        final isLast = i == replies.length - 1;
        // For children, pass down whether THIS node has more siblings after it
        final newAncestors = List<bool>.from(ancestorHasMoreSiblings);
        newAncestors.add(!isLastChild); // Add current node's sibling status
        addWithReplies(replies[i], depth + 1, newAncestors, isFirst, isLast);
      }
    }

    for (var i = 0; i < rootResponses.length; i++) {
      final isFirst = i == 0;
      final isLast = i == rootResponses.length - 1;
      addWithReplies(rootResponses[i], 0, [], isFirst, isLast);
    }

    return Column(
      children: displayList.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        // Check if next item is a direct reply to this one
        final hasDirectReplyBelow =
            index < displayList.length - 1 &&
            displayList[index + 1].response.parentId == item.response.id;

        return _ResponseTile(
          key: ValueKey(item.response.id),
          response: item.response,
          depth: item.depth,
          hasReplies: item.hasReplies,
          hasDirectReplyBelow: hasDirectReplyBelow,
          isFirstChild: item.isFirstChild,
          isLastChild: item.isLastChild,
          ancestorHasMoreSiblings: item.ancestorHasMoreSiblings,
          onReplyTap: () => _handleReplyTo(item.response),
        );
      }).toList(),
    );
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final signal = _currentSignal ?? widget.signal;

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        title: Text(
          'Signal',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Sticky header - appears when scrolled past threshold
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _showStickyHeader ? null : 0,
            child: AnimatedOpacity(
              opacity: _showStickyHeader ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: _StickySignalHeader(signal: signal, onTap: _scrollToTop),
            ),
          ),

          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                SignalCard(signal: signal, showActions: false),
                const SizedBox(height: 24),

                // Responses header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.accentColor.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: context.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.forum_rounded,
                          size: 16,
                          color: context.accentColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Conversation',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_responses != null && _responses!.isNotEmpty)
                              Text(
                                '${_responses!.length} ${_responses!.length == 1 ? 'response' : 'responses'}',
                                style: TextStyle(
                                  color: context.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_isLoadingResponses)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.accentColor,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Responses list
                _buildResponsesList(context),
              ],
            ),
          ),

          // Reply input
          Container(
            decoration: BoxDecoration(
              color: context.card,
              border: Border(
                top: BorderSide(color: context.border.withValues(alpha: 0.5)),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reply indicator
                  if (_replyingToAuthor != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: context.accentColor.withValues(alpha: 0.1),
                      child: Row(
                        children: [
                          Icon(
                            Icons.reply,
                            size: 16,
                            color: context.accentColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Replying to $_replyingToAuthor',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _cancelReply,
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: context.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Input field
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _replyController,
                            focusNode: _replyFocusNode,
                            enabled: !_isSubmittingReply,
                            style: TextStyle(color: context.textPrimary),
                            decoration: InputDecoration(
                              hintText: _replyingToAuthor != null
                                  ? 'Write a reply...'
                                  : 'Respond to this signal...',
                              hintStyle: TextStyle(color: context.textTertiary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: context.background,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            maxLines: 1,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _submitReply(),
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _isSubmittingReply
                            ? SizedBox(
                                width: 48,
                                height: 48,
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: context.accentColor,
                                    ),
                                  ),
                                ),
                              )
                            : IconButton(
                                onPressed:
                                    _replyController.text.trim().isNotEmpty
                                    ? _submitReply
                                    : null,
                                icon: Icon(
                                  Icons.send,
                                  color: _replyController.text.trim().isNotEmpty
                                      ? context.accentColor
                                      : context.textTertiary,
                                ),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper class for threaded response display.
class _ResponseDisplayItem {
  final SignalResponse response;
  final int depth;
  final bool hasReplies;
  final bool isFirstChild;
  final bool isLastChild;
  final List<bool> ancestorHasMoreSiblings;

  const _ResponseDisplayItem({
    required this.response,
    required this.depth,
    this.hasReplies = false,
    this.isFirstChild = true,
    this.isLastChild = true,
    this.ancestorHasMoreSiblings = const [],
  });
}

class _ResponseTile extends StatelessWidget {
  const _ResponseTile({
    super.key,
    required this.response,
    required this.depth,
    this.hasReplies = false,
    this.hasDirectReplyBelow = false,
    this.isFirstChild = true,
    this.isLastChild = true,
    this.ancestorHasMoreSiblings = const [],
    this.onReplyTap,
  });

  final SignalResponse response;
  final int depth;
  final bool hasReplies;
  final bool hasDirectReplyBelow;
  final bool isFirstChild;
  final bool isLastChild;
  final List<bool> ancestorHasMoreSiblings;
  final VoidCallback? onReplyTap;

  static const double _avatarSize = 36.0;
  static const double _smallAvatarSize = 32.0;
  static const double _lineWidth = 2.0;
  static const double _indentWidth = 28.0;

  @override
  Widget build(BuildContext context) {
    final isReply = depth > 0;
    final avatarSize = isReply ? _smallAvatarSize : _avatarSize;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // For non-first root items, add incoming connector column
          // This aligns with column 0 of nested items
          if (depth == 0 && !isFirstChild)
            SizedBox(
              width: _indentWidth,
              child: CustomPaint(
                painter: _ConnectorPainter(
                  color: context.accentColor.withValues(alpha: 0.3),
                  lineWidth: _lineWidth,
                  avatarSize: avatarSize,
                  showContinuation:
                      !isLastChild, // Continue if more root siblings
                ),
              ),
            ),

          // Thread columns for depth levels (nested items)
          for (int i = 0; i < depth; i++)
            SizedBox(
              width: _indentWidth,
              child: _buildThreadColumn(context, i, avatarSize),
            ),

          // Avatar column
          SizedBox(
            width: avatarSize + 8,
            child: Column(
              children: [
                // Avatar
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.accentColor.withValues(alpha: 0.3),
                        context.accentColor.withValues(alpha: 0.1),
                      ],
                    ),
                    border: Border.all(
                      color: context.accentColor.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.accentColor.withValues(alpha: 0.2),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    size: avatarSize * 0.5,
                    color: context.accentColor,
                  ),
                ),

                // Line below avatar to children (or first root to siblings via children)
                if (hasDirectReplyBelow ||
                    (isFirstChild && !isLastChild && depth == 0))
                  Expanded(
                    child: Center(
                      child: Container(
                        width: _lineWidth,
                        color: context.accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Content
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isReply
                      ? context.accentColor.withValues(alpha: 0.2)
                      : context.border.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  response.authorName ?? 'Anonymous',
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: isReply ? 13 : 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (response.isLocal) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.accentColor.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'You',
                                      style: TextStyle(
                                        color: context.accentColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _timeAgo(response.createdAt),
                              style: TextStyle(
                                color: context.textTertiary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Reply count badge (if has replies)
                      if (hasReplies)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.subdirectory_arrow_right_rounded,
                                size: 12,
                                color: context.accentColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Has replies',
                                style: TextStyle(
                                  color: context.accentColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Content text
                  Text(
                    response.content,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: isReply ? 13 : 14,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Action bar
                  Row(
                    children: [
                      _ActionChip(
                        icon: Icons.reply_rounded,
                        label: 'Reply',
                        onTap: onReplyTap,
                      ),
                      const Spacer(),
                      // Depth indicator
                      if (depth > 0)
                        Text(
                          'Level $depth',
                          style: TextStyle(
                            color: context.textTertiary.withValues(alpha: 0.5),
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a thread column showing vertical/horizontal lines.
  /// For the last column (i == depth - 1), shows an L-connector to the avatar.
  /// For earlier columns, shows a straight line if ancestor has more siblings.
  Widget _buildThreadColumn(
    BuildContext context,
    int columnIndex,
    double avatarSize,
  ) {
    final isLastColumn = columnIndex == depth - 1;
    final ancestorHasSiblings =
        columnIndex < ancestorHasMoreSiblings.length &&
        ancestorHasMoreSiblings[columnIndex];

    if (isLastColumn) {
      // Last column: draw L-shaped connector to avatar.
      // Show continuation below if:
      // - THIS item has more siblings (!isLastChild), OR
      // - The PARENT at this depth level has more siblings (ancestorHasSiblings)
      return CustomPaint(
        painter: _ConnectorPainter(
          color: context.accentColor.withValues(alpha: 0.3),
          lineWidth: _lineWidth,
          avatarSize: avatarSize,
          showContinuation: !isLastChild || ancestorHasSiblings,
        ),
      );
    } else {
      // Earlier columns: show vertical continuation if ancestor at this level
      // has more siblings below its current child.
      if (ancestorHasSiblings) {
        return Center(
          child: Container(
            width: _lineWidth,
            color: context.accentColor.withValues(alpha: 0.3),
          ),
        );
      }
      return const SizedBox.shrink();
    }
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

/// Styled action chip for response actions.
class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: context.textTertiary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: context.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for thread connector lines.
/// Draws an L-shaped connector from the top-center to the right-center (at avatar height).
/// If showContinuation is true, extends the line below as well (T-shape).
class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({
    required this.color,
    required this.lineWidth,
    required this.avatarSize,
    required this.showContinuation,
  });

  final Color color;
  final double lineWidth;
  final double avatarSize;
  final bool showContinuation;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 2;
    final avatarCenterY = avatarSize / 2;

    // Vertical line from top to avatar center
    canvas.drawLine(Offset(centerX, 0), Offset(centerX, avatarCenterY), paint);

    // Horizontal line from center to right edge (towards avatar)
    canvas.drawLine(
      Offset(centerX, avatarCenterY),
      Offset(size.width, avatarCenterY),
      paint,
    );

    // Continue vertical line below if there are more siblings
    if (showContinuation) {
      canvas.drawLine(
        Offset(centerX, avatarCenterY),
        Offset(centerX, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter oldDelegate) =>
      color != oldDelegate.color ||
      lineWidth != oldDelegate.lineWidth ||
      avatarSize != oldDelegate.avatarSize ||
      showContinuation != oldDelegate.showContinuation;
}

/// Sticky header showing compact signal info when scrolled.
class _StickySignalHeader extends StatelessWidget {
  const _StickySignalHeader({required this.signal, this.onTap});

  final Post signal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = signal.mediaUrls.isNotEmpty;
    final imageUrl = hasImage ? signal.mediaUrls.first : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: context.card,
          border: Border(
            bottom: BorderSide(color: context.border.withValues(alpha: 0.3)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            if (hasImage && imageUrl != null)
              Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: context.accentColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.accentColor.withValues(alpha: 0.15),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: context.accentColor.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.image_outlined,
                        size: 20,
                        color: context.accentColor,
                      ),
                    ),
                  ),
                ),
              )
            else
              // Avatar placeholder when no image
              Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.accentColor.withValues(alpha: 0.3),
                      context.accentColor.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: context.accentColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.signal_cellular_alt_rounded,
                  size: 20,
                  color: context.accentColor,
                ),
              ),

            // Content preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Author
                  Row(
                    children: [
                      Text(
                        signal.authorSnapshot?.displayName ?? 'Anonymous',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '•',
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _timeAgo(signal.createdAt),
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Content preview
                  Text(
                    signal.content,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Response count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.forum_rounded,
                    size: 12,
                    color: context.accentColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${signal.commentCount}',
                    style: TextStyle(
                      color: context.accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Scroll up indicator
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: context.textTertiary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 18,
                color: context.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
