// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodeBoard thread detail screen — premium layout matching NodeDex /
// Signals / Aether card hierarchy. Shows the original post in a
// NodeBoardCardContainer, a replies card grouping every reply tile,
// and a fixed bottom reply composer.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/node_color.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../providers/app_providers.dart';
import '../../../utils/snackbar.dart';
import '../../nodedex/screens/nodedex_detail_screen.dart';
import '../../nodedex/widgets/sigil_painter.dart';
import '../models/nodeboard_thread.dart';
import '../providers/nodeboard_providers.dart';
import '../widgets/nodeboard_card_container.dart';
import '../widgets/nodeboard_reply_composer.dart';
import '../widgets/nodeboard_reply_tile.dart';

class NodeBoardThreadScreen extends ConsumerStatefulWidget {
  final String slug;
  final String threadId;

  const NodeBoardThreadScreen({
    super.key,
    required this.slug,
    required this.threadId,
  });

  @override
  ConsumerState<NodeBoardThreadScreen> createState() =>
      _NodeBoardThreadScreenState();
}

class _NodeBoardThreadScreenState extends ConsumerState<NodeBoardThreadScreen>
    with LifecycleSafeMixin<NodeBoardThreadScreen> {
  final TextEditingController _replyController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    AppLogging.nodeBoard(
      'UI: thread screen opened slug=${widget.slug} threadId=${widget.threadId}',
    );
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  ThreadDetailKey get _detailKey =>
      ThreadDetailKey(slug: widget.slug, threadId: widget.threadId);

  Future<void> _sendReply() async {
    final body = _replyController.text.trim();
    if (body.isEmpty) return;

    final notifier = ref.read(nodeBoardModNotifierProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final failedLabel = context.l10n.nodeboardReplyFailed;

    AppLogging.nodeBoard(
      'UI: submitting reply to thread=${widget.threadId} (${body.length} chars)',
    );
    setState(() => _isSending = true);
    HapticFeedback.mediumImpact();

    try {
      final myNodeNum = ref.read(myNodeNumProvider);
      final nodes = ref.read(nodesProvider);
      final myNode = myNodeNum != null ? nodes[myNodeNum] : null;
      final myHexId = myNodeNum != null
          ? '!${myNodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}'
          : null;
      // lint-allow: hardcoded-string
      final displayName = myNode?.displayName ?? myNode?.shortName ?? 'You';

      await notifier.createReply(_detailKey, {
        'body': body,
        'authorDisplayName': displayName,
        if (myHexId != null) 'authorNodeId': myHexId,
      });

      if (!mounted) return;
      AppLogging.nodeBoard('UI: reply posted');
      _replyController.clear();
      HapticFeedback.lightImpact();
    } catch (e, st) {
      AppLogging.nodeBoard('UI: reply failed: $e\n$st');
      if (!mounted) return;
      messenger.clearSnackBars();
      showErrorSnackBar(context, '$failedLabel: $e');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(nodeBoardThreadDetailProvider(_detailKey));
    final boardAsync = ref.watch(nodeBoardDetailProvider(widget.slug));
    final fallbackNodeId = boardAsync.value?.ownerNodeId;
    final l10n = context.l10n;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        FocusScope.of(context).unfocus();
      },
      child: detailAsync.when(
        data: (detail) {
          if (detail == null) {
            return GlassScaffold.body(
              title: l10n.nodeboardTitle,
              body: _CenteredMessage(
                icon: Icons.forum_outlined,
                message: l10n.nodeboardThreadNotFound,
              ),
            );
          }

          final thread = detail.thread;
          final replies = detail.replies;
          final isLocked = thread.isLocked;

          return GlassScaffold.body(
            title: thread.title.isEmpty ? l10n.nodeboardTitle : thread.title,
            hasScrollBody: true,
            body: SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(
                        top: AppTheme.spacing8,
                        bottom: AppTheme.spacing16,
                      ),
                      children: [
                        NodeBoardEntrance(
                          index: 0,
                          child: _ThreadOpCard(
                            thread: thread,
                            fallbackNodeId: fallbackNodeId,
                          ),
                        ),
                        NodeBoardEntrance(
                          index: 1,
                          child: NodeBoardCardContainer(
                            // lint-allow: hardcoded-string
                            title: 'Replies (${replies.length})',
                            icon: Icons.mode_comment_outlined,
                            child: replies.isEmpty
                                ? _EmptyRepliesBlock()
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (int i = 0; i < replies.length; i++)
                                        NodeBoardReplyTile(
                                          reply: replies[i],
                                          fallbackNodeId: fallbackNodeId,
                                          showDivider: i != replies.length - 1,
                                        ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  NodeBoardReplyComposer(
                    controller: _replyController,
                    isSending: _isSending,
                    onSend: _sendReply,
                    isLocked: isLocked,
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => GlassScaffold.body(
          title: l10n.nodeboardTitle,
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => GlassScaffold.body(
          title: l10n.nodeboardTitle,
          body: _ErrorCard(message: l10n.nodeboardLoadError),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Original post card — renders the thread body inside a NodeBoardCardContainer
// so the screen's card hierarchy is consistent with NodeDex / Aether.
// ---------------------------------------------------------------------------

class _ThreadOpCard extends StatelessWidget {
  final NodeBoardThread thread;
  final String? fallbackNodeId;

  const _ThreadOpCard({required this.thread, this.fallbackNodeId});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final nodeNum =
        _parseNodeHex(thread.authorNodeId) ?? _parseNodeHex(fallbackNodeId);
    final sigilSeed = nodeNum ?? thread.authorDisplayName.hashCode.abs();
    final avatarColor = _avatarColorFor(
      context,
      nodeNum,
      thread.authorDisplayName,
    );
    final tappable = nodeNum != null;

    return NodeBoardCardContainer(
      // lint-allow: hardcoded-string
      title: 'Original post',
      icon: Icons.article_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            thread.title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
              height: 1.25,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: tappable
                    ? () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                NodeDexDetailScreen(nodeNum: nodeNum),
                          ),
                        );
                      }
                    : null,
                child: SigilWidget(
                  nodeNum: sigilSeed,
                  size: 36,
                  showBorder: true,
                  borderColor: avatarColor.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(width: AppTheme.spacing10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author header — Wraps so long display names + hex
                    // IDs don't clip on narrow widths.
                    Wrap(
                      spacing: AppTheme.spacing8,
                      runSpacing: AppTheme.spacing2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          thread.authorDisplayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: avatarColor,
                            letterSpacing: 0.1,
                          ),
                        ),
                        if (tappable)
                          Text(
                            // lint-allow: hardcoded-string
                            '!${nodeNum.toRadixString(16).toUpperCase()}',
                            style: TextStyle(
                              fontSize: 10,
                              color: context.textTertiary,
                              letterSpacing: 0.3,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    Text(
                      _formatTimeAgo(thread.createdAt, l10n),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (thread.isPinned || thread.isLocked) ...[
            const SizedBox(height: AppTheme.spacing12),
            Wrap(
              spacing: AppTheme.spacing8,
              runSpacing: AppTheme.spacing8,
              children: [
                if (thread.isPinned)
                  NodeBoardStatChip(
                    icon: Icons.push_pin,
                    label: l10n.nodeboardPinned,
                    tint: context.accentColor,
                  ),
                if (thread.isLocked)
                  NodeBoardStatChip(
                    icon: Icons.lock,
                    label: l10n.nodeboardLocked,
                    tint: context.textTertiary,
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppTheme.spacing14),
          Divider(
            height: 1,
            thickness: 0.5,
            color: context.border.withValues(alpha: 0.25),
          ),
          const SizedBox(height: AppTheme.spacing14),
          Text(
            thread.body,
            style: TextStyle(
              fontSize: 15,
              color: context.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty-replies placeholder shown inside the replies card.
// ---------------------------------------------------------------------------

class _EmptyRepliesBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
      child: Center(
        child: Text(
          // lint-allow: hardcoded-string
          'No replies yet — be the first.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13,
            color: context.textTertiary,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable centered message block for not-found / missing thread states.
// ---------------------------------------------------------------------------

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _CenteredMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppTheme.spacing48, color: context.textTertiary),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            message,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error card — centered, bordered, uses error tone from SemanticColors.
// ---------------------------------------------------------------------------

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius16),
            border: Border.all(
              color: SemanticColors.error.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 20, color: SemanticColors.error),
              const SizedBox(width: AppTheme.spacing12),
              Flexible(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Time-ago formatter — short, locale-aware via l10n placeholder strings.
// ---------------------------------------------------------------------------

String _formatTimeAgo(DateTime dt, dynamic l10n) {
  final diff = DateTime.now().difference(dt);
  if (diff.inDays > 365) {
    return l10n.nodeboardYearsAgo(diff.inDays ~/ 365) as String;
  }
  if (diff.inDays > 30) {
    return l10n.nodeboardMonthsAgo(diff.inDays ~/ 30) as String;
  }
  if (diff.inDays > 0) {
    return l10n.nodeboardDaysAgo(diff.inDays) as String;
  }
  if (diff.inHours > 0) {
    return l10n.nodeboardHoursAgo(diff.inHours) as String;
  }
  if (diff.inMinutes > 0) {
    return l10n.nodeboardMinutesAgo(diff.inMinutes) as String;
  }
  return l10n.nodeboardJustNow as String;
}

// ---------------------------------------------------------------------------
// Author-identity helpers — shared with nodeboard_reply_tile.dart so thread
// OP and replies render sigils/colors the same way.
// ---------------------------------------------------------------------------

int? _parseNodeHex(String? hexId) {
  if (hexId == null || hexId.isEmpty) return null;
  final clean = hexId.startsWith('!') ? hexId.substring(1) : hexId;
  return int.tryParse(clean, radix: 16);
}

Color _avatarColorFor(BuildContext context, int? nodeNum, String fallbackSeed) {
  // Posts without a node number (e.g. server-side authors) fall back to a
  // stable hash of the author string so the same author keeps one colour.
  return nodeColorFromId(nodeNum ?? fallbackSeed.hashCode.abs());
}
