import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/content_moderation_warning.dart';
import '../../../utils/snackbar.dart';
import '../../../models/social.dart';
import '../../../providers/profile_providers.dart';
import '../../../providers/signal_providers.dart';
import '../../../providers/social_providers.dart';
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

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _submitReply() async {
    final content = _replyController.text.trim();
    if (content.isEmpty) return;

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
        // Refresh replies
        if (mounted) setState(() {});
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
                SignalCard(signal: widget.signal, showActions: false),
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
                FutureBuilder<List<SignalResponse>>(
                  future: ref
                      .read(signalServiceProvider)
                      .getResponses(widget.signal.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: context.accentColor,
                          strokeWidth: 2,
                        ),
                      );
                    }

                    final replies = snapshot.data ?? [];

                    if (replies.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: context.border.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.forum_outlined,
                              size: 32,
                              color: context.textTertiary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No responses yet',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 14,
                              ),
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
                  },
                ),
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
