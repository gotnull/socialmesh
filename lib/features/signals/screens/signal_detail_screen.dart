import 'dart:async';
import 'dart:ui';

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
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          kToolbarHeight + MediaQuery.of(context).padding.top,
        ),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: context.card.withValues(alpha: 0.7),
              ),
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: kToolbarHeight,
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: context.textPrimary,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Text(
                        'Signal',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Main content - with top padding for AppBar and bottom for reply input
          ListView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + kToolbarHeight + 16,
              16,
              100,
            ),
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

          // Reply input - positioned at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: context.card,
                border: Border(
                  top: BorderSide(color: context.border.withValues(alpha: 0.5)),
                ),
              ),
              child: SafeArea(
                top: false,
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
                                hintStyle: TextStyle(
                                  color: context.textTertiary,
                                ),
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
                                    color:
                                        _replyController.text.trim().isNotEmpty
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
          ),

          // Sticky header overlay - slides in/out from top with blur
          // Positioned 1px higher to overlap with AppBar and hide seam
          Positioned(
            top: MediaQuery.of(context).padding.top + kToolbarHeight,
            left: 0,
            right: 0,
            child: _StickySignalHeader(
              signal: signal,
              isVisible: _showStickyHeader,
              onTap: _scrollToTop,
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

  static const double _avatarSize = 24.0;
  static const double _indentWidth = 16.0;
  static const int _maxVisualDepth = 5; // Cap indentation like Reddit

  @override
  Widget build(BuildContext context) {
    // Cap the visual depth to prevent cramping
    final visualDepth = depth.clamp(0, _maxVisualDepth);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thread bars for each depth level (capped)
            for (int i = 0; i < visualDepth; i++)
              GestureDetector(
                onTap: () {}, // Could collapse thread on tap
                child: Container(
                  width: _indentWidth,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),

            // Avatar
            Container(
              width: _avatarSize,
              height: _avatarSize,
              margin: const EdgeInsets.only(top: 2, right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.accentColor.withValues(alpha: 0.15),
              ),
              child: Icon(
                Icons.person_rounded,
                size: _avatarSize * 0.6,
                color: context.accentColor.withValues(alpha: 0.7),
              ),
            ),

            // Content - Reddit style: flat, no card
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row - username and time inline
                  Row(
                    children: [
                      Text(
                        response.authorName ?? 'Anonymous',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (response.isLocal) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: context.accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'you',
                            style: TextStyle(
                              color: context.accentColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 4),
                      Text(
                        '· ${_timeAgo(response.createdAt)}',
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Content text
                  Text(
                    response.content,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Actions row
                  Row(
                    children: [
                      _ActionButton(
                        icon: Icons.arrow_upward_rounded,
                        onTap: () {}, // Vote up
                        context: context,
                      ),
                      const SizedBox(width: 4),
                      _ActionButton(
                        icon: Icons.arrow_downward_rounded,
                        onTap: () {}, // Vote down
                        context: context,
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: onReplyTap,
                        child: Row(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 14,
                              color: context.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Reply',
                              style: TextStyle(
                                color: context.textTertiary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

/// Small action button for vote actions.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.onTap,
    required this.context,
  });

  final IconData icon;
  final VoidCallback onTap;
  final BuildContext context;

  @override
  Widget build(BuildContext _) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: context.textTertiary),
      ),
    );
  }
}

/// Sticky header showing compact signal info when scrolled.
class _StickySignalHeader extends StatefulWidget {
  const _StickySignalHeader({
    required this.signal,
    required this.isVisible,
    this.onTap,
  });

  final Post signal;
  final bool isVisible;
  final VoidCallback? onTap;

  @override
  State<_StickySignalHeader> createState() => _StickySignalHeaderState();
}

class _StickySignalHeaderState extends State<_StickySignalHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    // Start with correct state
    if (widget.isVisible) {
      _slideController.forward();
    }
  }

  @override
  void didUpdateWidget(_StickySignalHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _slideController.forward();
      } else {
        _slideController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signal = widget.signal;
    final hasImage = signal.mediaUrls.isNotEmpty;
    final imageUrl = hasImage ? signal.mediaUrls.first : null;

    return IgnorePointer(
      ignoring: !widget.isVisible,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: GestureDetector(
                onTap: widget.onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: context.card.withValues(alpha: 0.7),
                    border: Border(
                      bottom: BorderSide(
                        color: context.accentColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    boxShadow: [
                      // Upward shadow to blend with AppBar junction
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Thumbnail
                      _buildThumbnail(context, hasImage, imageUrl),

                      const SizedBox(width: 12),

                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  signal.authorSnapshot?.displayName ??
                                      'Anonymous',
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '· ${_timeAgo(signal.createdAt)}',
                                  style: TextStyle(
                                    color: context.textTertiary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              signal.content,
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Response count
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
                              Icons.chat_bubble_outline_rounded,
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

                      // Scroll up
                      Icon(
                        Icons.expand_less_rounded,
                        size: 24,
                        color: context.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(
    BuildContext context,
    bool hasImage,
    String? imageUrl,
  ) {
    if (hasImage && imageUrl != null) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: context.accentColor.withValues(alpha: 0.3),
            width: 1,
          ),
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
                size: 18,
                color: context.accentColor,
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      width: 40,
      height: 40,
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
          width: 1,
        ),
      ),
      child: Icon(
        Icons.signal_cellular_alt_rounded,
        size: 18,
        color: context.accentColor,
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
