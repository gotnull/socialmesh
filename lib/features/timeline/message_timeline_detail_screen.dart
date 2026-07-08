// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../core/widgets/animated_avatar_stack.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../../utils/time_format.dart';
import '../nodedex/widgets/sigil_painter.dart';
import 'domain/timeline_item.dart';

/// Detail screen for a timeline session, shown when tapping a card on the
/// message timeline. Displays session metadata, participant sigils, and
/// the actual messages from the session, with a bottom action to open the
/// conversation.
class MessageTimelineDetailScreen extends ConsumerWidget {
  final TimelineItem item;

  /// Accent color matching the card's DM/channel color.
  final Color accentColor;

  /// Called when the user taps "Open conversation". Receives the detail
  /// screen's own [BuildContext] so navigation uses the correct route.
  final void Function(BuildContext context) onOpenChat;

  const MessageTimelineDetailScreen({
    super.key,
    required this.item,
    required this.accentColor,
    required this.onOpenChat,
  });

  bool get _isDm => item.id.startsWith('dm_');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final timeFmt = AppTimeFormat.timeOnly(context);
    final dateFmt = DateFormat.MMMEd(
      Localizations.localeOf(context).toString(),
    );
    final actualDuration = item.trackedDuration ?? item.duration;
    final actualEnd = item.start.add(actualDuration);
    final headerNodeNum = _isDm && item.participantIds.isNotEmpty
        ? int.tryParse(item.participantIds.first)
        : null;

    // Resolve session messages from the provider.
    final sessionMessages = _resolveSessionMessages(ref);

    return GlassScaffold.body(
      title: item.title,
      centerTitle: true,
      hasScrollBody: true,
      body: Column(
        children: [
          // Fixed header section
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              AppTheme.spacing16,
              AppTheme.spacing16,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderCard(
                  isDm: _isDm,
                  title: item.title,
                  accentColor: accentColor,
                  nodeNum: headerNodeNum,
                ),
                const SizedBox(height: AppTheme.spacing16),
                _InfoRow(
                  icon: Icons.category_outlined,
                  label: l10n.messageTimelineDetailType,
                  value: _isDm
                      ? l10n.messageTimelineDetailTypeDm
                      : l10n.messageTimelineDetailTypeChannel,
                ),
                const SizedBox(height: AppTheme.spacing12),
                _InfoRow(
                  icon: Icons.access_time_outlined,
                  label: l10n.messageTimelineDetailTime,
                  value:
                      '${dateFmt.format(item.start)}  '
                      '${timeFmt.format(item.start)} – '
                      '${timeFmt.format(actualEnd)}',
                ),
                const SizedBox(height: AppTheme.spacing12),
                _InfoRow(
                  icon: Icons.timer_outlined,
                  label: l10n.messageTimelineDetailDuration,
                  value: l10n.messageTimelineDetailDurationMinutes(
                    actualDuration.inMinutes,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing12),
                _InfoRow(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: l10n.messageTimelineDetailMessages,
                  value: l10n.messageTimelineSessionMessages(item.messageCount),
                ),
                if (item.hasParticipants) ...[
                  const SizedBox(height: AppTheme.spacing24),
                  Text(
                    l10n.messageTimelineDetailParticipants,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing12),
                  AnimatedAvatarStack(
                    items: item.participantIds
                        .map((id) {
                          final nodeNum = int.tryParse(id);
                          if (nodeNum == null) return null;
                          return AvatarStackItem(
                            id: id,
                            child: SigilWidget(nodeNum: nodeNum, size: 32),
                          );
                        })
                        .whereType<AvatarStackItem>()
                        .toList(),
                    avatarSize: 40,
                  ),
                ],
                if (sessionMessages.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacing24),
                  Text(
                    l10n.messageTimelineDetailMessages,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing12),
                ],
              ],
            ),
          ),

          // Scrollable messages
          Expanded(
            child: sessionMessages.isEmpty
                ? const SizedBox.shrink()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing16,
                    ),
                    itemCount: sessionMessages.length,
                    itemBuilder: (context, index) => _MessageRow(
                      message: sessionMessages[index],
                      accentColor: accentColor,
                    ),
                  ),
          ),

          // Fixed bottom button
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onOpenChat(context);
                  },
                  icon: Icon(
                    _isDm
                        ? Icons.person_outline_rounded
                        : Icons.cell_tower_rounded,
                  ),
                  label: Text(l10n.messageTimelineDetailOpenChat),
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spacing16,
                      horizontal: AppTheme.spacing24,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Filters messages from the provider that belong to this session.
  List<Message> _resolveSessionMessages(WidgetRef ref) {
    final allMessages = ref.watch(messagesProvider);
    if (item.messageIds.isNotEmpty) {
      final messagesById = {
        for (final message in allMessages) message.id: message,
      };
      final resolved = item.messageIds
          .map((id) => messagesById[id])
          .whereType<Message>()
          .toList(growable: false);
      if (resolved.isNotEmpty) {
        return resolved;
      }
    }

    final myNodeNum = ref.watch(myNodeNumProvider);
    if (myNodeNum == null) return const [];

    final sessionEnd = item.trackedDuration != null
        ? item.start.add(item.trackedDuration!)
        : item.end;

    final parts = item.id.split('_');
    if (parts.length < 2) return const [];

    final isDm = parts[0] == 'dm';
    final key = int.tryParse(parts[1]);
    if (key == null) return const [];

    return allMessages.where((m) {
      if (m.isCanonicalTapback) return false;
      if (m.timestamp.isBefore(item.start)) return false;
      if (m.timestamp.isAfter(sessionEnd)) return false;

      if (isDm) {
        if (!m.isDirect) return false;
        final peer = m.from == myNodeNum ? m.to : m.from;
        return peer == key;
      } else {
        return m.isBroadcast && m.channel == key;
      }
    }).toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }
}

/// A single message row in the session detail message list.
class _MessageRow extends StatelessWidget {
  final Message message;
  final Color accentColor;

  const _MessageRow({required this.message, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final timeFmt = AppTimeFormat.timeOnly(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: SigilWidget(nodeNum: message.from, size: 24),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        message.senderDisplayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      timeFmt.format(message.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  message.text,
                  style: TextStyle(fontSize: 13, color: context.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Large header card with type icon and session title.
class _HeaderCard extends StatelessWidget {
  final bool isDm;
  final String title;
  final Color accentColor;
  final int? nodeNum;

  const _HeaderCard({
    required this.isDm,
    required this.title,
    required this.accentColor,
    this.nodeNum,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            accentColor.withValues(alpha: 0.15),
            context.card.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: isDm && nodeNum != null
                ? Center(child: SigilWidget(nodeNum: nodeNum!, size: 34))
                : Icon(Icons.cell_tower_rounded, size: 28, color: accentColor),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single info row with icon, label, and value.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: context.textTertiary),
        const SizedBox(width: AppTheme.spacing8),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
