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
  bool _isSubmittingReply = false;
  Post? _currentSignal; // Track updated signal with current commentCount
  List<SignalResponse>? _responses;
  bool _isLoadingResponses = true;
  StreamSubscription<ContentRefreshEvent>? _refreshSubscription;
  StreamSubscription<String>? _responseUpdateSubscription;

  @override
  void initState() {
    super.initState();
    _currentSignal = widget.signal;
    _loadResponses();
    _setupRefreshListeners();

    // Ensure the Firestore comments listener is active for this signal
    ref.read(signalServiceProvider).ensureCommentsListener(widget.signal.id);
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
    _replyController.dispose();
    super.dispose();
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
        '📝 SignalDetailScreen: Submitting response to signal ${widget.signal.id}',
      );
      final response = await service.createResponse(
        signalId: widget.signal.id,
        content: content,
        authorName: profile?.displayName,
      );

      if (response != null) {
        AppLogging.signals(
          '📝 SignalDetailScreen: Response created: ${response.id}',
        );
        _replyController.clear();

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
      return Center(
        child: CircularProgressIndicator(
          color: context.accentColor,
          strokeWidth: 2,
        ),
      );
    }

    final replies = _responses ?? [];

    if (replies.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Icon(Icons.forum_outlined, size: 32, color: context.textTertiary),
            const SizedBox(height: 8),
            Text(
              'No responses yet',
              style: TextStyle(color: context.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Column(
      children: replies.map((response) {
        return _ResponseTile(response: response);
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SignalCard(
                  signal: _currentSignal ?? widget.signal,
                  showActions: false,
                ),
                const SizedBox(height: 24),

                // Replies header
                Row(
                  children: [
                    Icon(Icons.reply, size: 18, color: context.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Responses',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Replies list
                _buildResponsesList(context),
              ],
            ),
          ),

          // Reply input
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: context.card,
              border: Border(
                top: BorderSide(color: context.border.withValues(alpha: 0.5)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    enabled: !_isSubmittingReply,
                    style: TextStyle(color: context.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Respond to this signal...',
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
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed:
                      _replyController.text.trim().isNotEmpty &&
                          !_isSubmittingReply
                      ? _submitReply
                      : null,
                  icon: _isSubmittingReply
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.accentColor,
                          ),
                        )
                      : Icon(
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
    );
  }
}

class _ResponseTile extends StatelessWidget {
  const _ResponseTile({required this.response});

  final SignalResponse response;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person, size: 18, color: context.accentColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      response.authorName ?? 'Anonymous',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
            ],
          ),
          const SizedBox(height: 8),
          Text(
            response.content,
            style: TextStyle(color: context.textPrimary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
