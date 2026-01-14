import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
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

class _SignalDetailScreenState extends ConsumerState<SignalDetailScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isSubmittingReply = false;
  Post? _currentSignal; // Track updated signal with current commentCount
  List<SignalResponse>? _comments;
  bool _isLoadingComments = true;
  StreamSubscription<ContentRefreshEvent>? _refreshSubscription;
  StreamSubscription<String>? _commentUpdateSubscription;
  Timer? _expiryTimer;

  // Reply-to state
  String? _replyingToId;
  String? _replyingToAuthor;

  // Vote tracking - maps responseId to vote value (1=up, -1=down)
  Map<String, int> _myVotes = {};

  // Sticky header state
  bool _showStickyHeader = false;
  static const double _stickyThreshold = 150.0;

  // Animation controller for entry animations
  late AnimationController _entryController;
  late Animation<double> _cardFadeAnimation;
  late Animation<Offset> _cardSlideAnimation;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;

  @override
  void initState() {
    super.initState();
    _currentSignal = widget.signal;
    _loadComments();
    _setupRefreshListeners();
    _scrollController.addListener(_onScroll);

    // Entry animation setup
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _cardFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _cardSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
          ),
        );

    _headerFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
      ),
    );

    _headerSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    // Start entry animation
    _entryController.forward();

    // Setup expiry timer to pop when signal expires
    _setupExpiryTimer();

    // Ensure the Firestore comments listener is active for this signal
    ref.read(signalServiceProvider).ensureCommentsListener(widget.signal.id);
  }

  void _setupExpiryTimer() {
    _expiryTimer?.cancel();
    final expiresAt = widget.signal.expiresAt;
    if (expiresAt == null) return;

    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) {
      // Already expired - pop immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showInfoSnackBar(context, 'This signal has faded');
          Navigator.of(context).pop();
        }
      });
    } else {
      // Schedule pop for when it expires
      _expiryTimer = Timer(remaining, () {
        if (mounted) {
          showInfoSnackBar(context, 'This signal has faded');
          Navigator.of(context).pop();
        }
      });
    }
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

    // Listen for Firestore comment updates (more reliable than push)
    _commentUpdateSubscription = ref
        .read(signalServiceProvider)
        .onCommentUpdate
        .listen(_onCommentUpdate);
  }

  void _onCommentUpdate(String signalId) {
    if (signalId == widget.signal.id) {
      AppLogging.signals(
        '🔔 Firestore comment update for signal ${widget.signal.id}',
      );
      // Refresh without showing loading indicator to preserve scroll position
      _refreshComments();
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
      _loadComments();
    } else {
      AppLogging.signals(
        '🔔 Ignoring event - expected signal_response for ${widget.signal.id}',
      );
    }
  }

  Future<void> _loadComments() async {
    if (!mounted) return;
    setState(() => _isLoadingComments = true);

    try {
      final signalService = ref.read(signalServiceProvider);
      final responses = await signalService.getComments(widget.signal.id);

      // Get user's votes from the service cache (populated by Firestore listener)
      // Make a mutable copy since the service returns an unmodifiable view
      final votes = Map<String, int>.from(
        signalService.getMyVotesForSignal(widget.signal.id),
      );

      if (mounted) {
        setState(() {
          _comments = responses;
          _myVotes = votes;
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      AppLogging.signals('Error loading comments: $e');
      if (mounted) {
        setState(() {
          _comments = [];
          _myVotes = {};
          _isLoadingComments = false;
        });
      }
    }
  }

  /// Refresh comments without showing loading indicator (preserves scroll position).
  Future<void> _refreshComments() async {
    if (!mounted) return;

    try {
      final signalService = ref.read(signalServiceProvider);
      final responses = await signalService.getComments(widget.signal.id);
      final votes = Map<String, int>.from(
        signalService.getMyVotesForSignal(widget.signal.id),
      );

      if (mounted) {
        setState(() {
          _comments = responses;
          _myVotes = votes;
        });
      }
    } catch (e) {
      AppLogging.signals('Error refreshing comments: $e');
    }
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _refreshSubscription?.cancel();
    _commentUpdateSubscription?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _replyController.dispose();
    _replyFocusNode.dispose();
    _entryController.dispose();
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

  Future<void> _handleVote(SignalResponse response, int value) async {
    // Auth gating check
    final isAuthenticated = ref.read(isSignedInProvider);
    if (!isAuthenticated) {
      AppLogging.signals('🔒 Vote blocked: user not authenticated');
      if (mounted) {
        showErrorSnackBar(context, 'Sign in required to vote');
      }
      return;
    }

    final currentVote = _myVotes[response.id];

    if (currentVote == value) {
      // Toggle off - remove vote
      await _removeVote(response);
    } else {
      // Set new vote
      await _setVote(response, value);
    }
  }

  Future<void> _setVote(SignalResponse response, int value) async {
    // Optimistic update
    final previousVote = _myVotes[response.id];
    setState(() {
      _myVotes[response.id] = value;
    });

    try {
      await ref
          .read(signalServiceProvider)
          .setVote(
            signalId: widget.signal.id,
            commentId: response.id,
            value: value,
          );
      // Vote counts will be updated via Firestore listener and _loadComments
    } catch (e) {
      // Revert on error
      AppLogging.signals('Vote error: $e');
      if (mounted) {
        setState(() {
          if (previousVote != null) {
            _myVotes[response.id] = previousVote;
          } else {
            _myVotes.remove(response.id);
          }
        });
        showErrorSnackBar(context, 'Failed to submit vote');
      }
    }
  }

  Future<void> _removeVote(SignalResponse response) async {
    // Optimistic update
    final previousVote = _myVotes[response.id];
    setState(() {
      _myVotes.remove(response.id);
    });

    try {
      await ref
          .read(signalServiceProvider)
          .clearVote(signalId: widget.signal.id, commentId: response.id);
      // Vote counts will be updated via Firestore listener and _loadComments
    } catch (e) {
      // Revert on error
      AppLogging.signals('Clear vote error: $e');
      if (mounted) {
        if (previousVote != null) {
          setState(() {
            _myVotes[response.id] = previousVote;
          });
        }
        showErrorSnackBar(context, 'Failed to remove vote');
      }
    }
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
        await _loadComments();
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

  Widget _buildCommentsList(BuildContext context) {
    if (_isLoadingComments) {
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
              'Loading comments...',
              style: TextStyle(color: context.textTertiary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final allResponses = _comments ?? [];

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
              'No comments yet',
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
    final visitedIds = <String>{}; // Cycle detection
    const maxDepth = 50; // Prevent infinite recursion
    const maxItems = 500; // Hard limit on total items

    void addWithReplies(
      SignalResponse response,
      int depth,
      List<bool> ancestorHasMoreSiblings,
      bool isFirstChild,
      bool isLastChild,
    ) {
      // Safety checks to prevent infinite loops/overflow
      if (depth > maxDepth) return;
      if (displayList.length >= maxItems) return;
      if (visitedIds.contains(response.id)) return; // Cycle detected
      visitedIds.add(response.id);

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
        if (displayList.length >= maxItems) break;
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

        return _AnimatedCommentItem(
          key: ValueKey('animated_${item.response.id}'),
          index: index,
          child: _ResponseTile(
            key: ValueKey(item.response.id),
            response: item.response,
            depth: item.depth,
            hasReplies: item.hasReplies,
            hasDirectReplyBelow: hasDirectReplyBelow,
            isFirstChild: item.isFirstChild,
            isLastChild: item.isLastChild,
            ancestorHasMoreSiblings: item.ancestorHasMoreSiblings,
            onReplyTap: () => _handleReplyTo(item.response),
            onUpvote: () => _handleVote(item.response, 1),
            onDownvote: () => _handleVote(item.response, -1),
            myVote: _myVotes[item.response.id],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSignalMenu(BuildContext context, Post signal) {
    final currentUser = ref.watch(currentUserProvider);
    final isOwnSignal =
        currentUser != null && signal.authorId == currentUser.uid;
    final canReport = currentUser != null && !isOwnSignal;

    if (!isOwnSignal && !canReport) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: context.textPrimary),
      onSelected: (value) {
        switch (value) {
          case 'delete':
            _deleteSignal(signal);
          case 'report':
            _reportSignal(signal);
        }
      },
      itemBuilder: (context) => [
        if (isOwnSignal)
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline,
                  color: context.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text('Delete', style: TextStyle(color: context.textPrimary)),
              ],
            ),
          ),
        if (canReport)
          PopupMenuItem<String>(
            value: 'report',
            child: Row(
              children: [
                Icon(
                  Icons.flag_outlined,
                  color: context.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text('Report', style: TextStyle(color: context.textPrimary)),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _deleteSignal(Post signal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.card,
        title: Text(
          'Delete Signal?',
          style: TextStyle(color: context.textPrimary),
        ),
        content: Text(
          'This signal will fade immediately.',
          style: TextStyle(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(signalFeedProvider.notifier).deleteSignal(signal.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _reportSignal(Post signal) async {
    final reason = await AppBottomSheet.showActions<String>(
      context: context,
      header: Text(
        'Why are you reporting this signal?',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: context.textPrimary,
        ),
      ),
      actions: [
        BottomSheetAction(
          icon: Icons.warning_outlined,
          label: 'Spam or misleading',
          value: 'spam',
        ),
        BottomSheetAction(
          icon: Icons.person_off_outlined,
          label: 'Harassment or bullying',
          value: 'harassment',
        ),
        BottomSheetAction(
          icon: Icons.dangerous_outlined,
          label: 'Violence or dangerous content',
          value: 'violence',
        ),
        BottomSheetAction(
          icon: Icons.no_adult_content,
          label: 'Nudity or sexual content',
          value: 'nudity',
        ),
        BottomSheetAction(
          icon: Icons.copyright,
          label: 'Copyright violation',
          value: 'copyright',
        ),
        BottomSheetAction(
          icon: Icons.more_horiz,
          label: 'Other',
          value: 'other',
        ),
      ],
    );

    if (reason != null && mounted) {
      try {
        final socialService = ref.read(socialServiceProvider);
        await socialService.reportSignal(
          signalId: signal.id,
          reason: reason,
          authorId: signal.authorId,
          content: signal.content,
          imageUrl: signal.mediaUrls.isNotEmpty ? signal.mediaUrls.first : null,
        );
        if (mounted) {
          showSuccessSnackBar(context, 'Report submitted. Thank you.');
        }
      } catch (e) {
        if (mounted) {
          showErrorSnackBar(context, 'Failed to report: $e');
        }
      }
    }
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
                      Expanded(
                        child: Text(
                          'Signal',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      _buildSignalMenu(context, signal),
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
            key: PageStorageKey('signal_detail_${widget.signal.id}'),
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + kToolbarHeight + 16,
              16,
              100,
            ),
            children: [
              // Animated signal card
              SlideTransition(
                position: _cardSlideAnimation,
                child: FadeTransition(
                  opacity: _cardFadeAnimation,
                  child: SignalCard(signal: signal, showActions: false),
                ),
              ),
              const SizedBox(height: 24),

              // Animated responses header
              SlideTransition(
                position: _headerSlideAnimation,
                child: FadeTransition(
                  opacity: _headerFadeAnimation,
                  child: Container(
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
                              if (_comments != null && _comments!.isNotEmpty)
                                Text(
                                  '${_comments!.length} ${_comments!.length == 1 ? 'comment' : 'comments'}',
                                  style: TextStyle(
                                    color: context.textTertiary,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_isLoadingComments)
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
                ),
              ),
              const SizedBox(height: 20),

              // Animated responses list
              FadeTransition(
                opacity: _headerFadeAnimation,
                child: _buildCommentsList(context),
              ),
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
    this.onUpvote,
    this.onDownvote,
    this.myVote,
  });

  final SignalResponse response;
  final int depth;
  final bool hasReplies;
  final bool hasDirectReplyBelow;
  final bool isFirstChild;
  final bool isLastChild;
  final List<bool> ancestorHasMoreSiblings;
  final VoidCallback? onReplyTap;
  final VoidCallback? onUpvote;
  final VoidCallback? onDownvote;
  final int? myVote; // 1=upvoted, -1=downvoted, null=no vote

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

                  // Content text (use displayContent for soft-deleted support)
                  Text(
                    response.displayContent,
                    style: TextStyle(
                      color: response.isDeleted
                          ? context.textTertiary
                          : context.textPrimary,
                      fontSize: 14,
                      height: 1.4,
                      fontStyle: response.isDeleted
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Actions row
                  Row(
                    children: [
                      _VoteButton(
                        icon: Icons.arrow_upward_rounded,
                        isActive: myVote == 1,
                        onTap: onUpvote,
                        activeColor: Colors.orange,
                      ),
                      if (response.score != 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            response.score > 0
                                ? '+${response.score}'
                                : '${response.score}',
                            style: TextStyle(
                              color: response.score > 0
                                  ? Colors.orange
                                  : response.score < 0
                                  ? Colors.blue
                                  : context.textTertiary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      _VoteButton(
                        icon: Icons.arrow_downward_rounded,
                        isActive: myVote == -1,
                        onTap: onDownvote,
                        activeColor: Colors.blue,
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
                              response.replyCount > 0
                                  ? 'Reply (${response.replyCount})'
                                  : 'Reply',
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

/// Vote button with active state highlighting.
class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.icon,
    required this.isActive,
    this.onTap,
    this.activeColor,
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback? onTap;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? (activeColor ?? context.accentColor)
        : context.textTertiary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 18, color: color),
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
    final hasRemoteImage = signal.mediaUrls.isNotEmpty;
    final hasLocalImage = signal.imageLocalPath != null;
    final hasImage = hasRemoteImage || hasLocalImage;

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
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Thumbnail
                      _buildThumbnail(
                        context,
                        hasImage,
                        hasRemoteImage ? signal.mediaUrls.first : null,
                        hasLocalImage ? signal.imageLocalPath : null,
                      ),

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
    String? localPath,
  ) {
    if (hasImage) {
      Widget imageWidget;

      if (localPath != null) {
        // Local file image
        imageWidget = Image.file(
          File(localPath),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: context.accentColor.withValues(alpha: 0.1),
            child: Icon(
              Icons.image_outlined,
              size: 18,
              color: context.accentColor,
            ),
          ),
        );
      } else if (imageUrl != null) {
        // Remote URL image
        imageWidget = Image.network(
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
        );
      } else {
        // Fallback - shouldn't reach here if hasImage is true
        return _buildPlaceholderThumbnail(context);
      }

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
          child: imageWidget,
        ),
      );
    }
    return _buildPlaceholderThumbnail(context);
  }

  Widget _buildPlaceholderThumbnail(BuildContext context) {
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

/// Animated wrapper for comment items with staggered entrance
class _AnimatedCommentItem extends StatefulWidget {
  const _AnimatedCommentItem({
    super.key,
    required this.child,
    required this.index,
  });

  final Widget child;
  final int index;

  @override
  State<_AnimatedCommentItem> createState() => _AnimatedCommentItemState();
}

class _AnimatedCommentItemState extends State<_AnimatedCommentItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // Staggered entrance with delay based on index
    Future<void>.delayed(Duration(milliseconds: 50 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(opacity: _fadeAnimation, child: widget.child),
    );
  }
}
