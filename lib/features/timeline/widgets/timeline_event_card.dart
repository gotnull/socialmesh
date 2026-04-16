// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_avatar_stack.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/timeline_item.dart';

/// Renders a single event card on the weekly timeline board.
///
/// Matches the reference design: rounded card with priority badge, title,
/// subtitle, avatar stack, and duration/message-count footer.
///
/// For break items, delegates to [TimelineBreakCard].
class TimelineEventCard extends StatelessWidget {
  final TimelineItem item;
  final List<AvatarStackItem> participantAvatars;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double height;

  const TimelineEventCard({
    super.key,
    required this.item,
    this.participantAvatars = const [],
    this.onTap,
    this.onLongPress,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (item.isBreak) {
      return TimelineBreakCard(
        height: height,
        label: context.l10n.timelineBreakTime,
      );
    }

    final cardColor = _cardColor(context);
    final isCompact = height < 80;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onLongPress?.call();
      },
      child: AnimatedOpacity(
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 300),
        opacity: item.isCompleted ? 0.65 : 1.0,
        child: Container(
          height: height,
          padding: const EdgeInsets.all(AppTheme.spacing12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(AppTheme.radius16),
          ),
          child: isCompact
              ? _buildCompactLayout(context)
              : _buildFullLayout(context),
        ),
      ),
    );
  }

  Widget _buildCompactLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _PriorityBadge(priority: item.priority),
        const SizedBox(height: AppTheme.spacing4),
        Flexible(
          child: Text(
            item.title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFullLayout(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Priority badge
        _PriorityBadge(priority: item.priority),
        const SizedBox(height: AppTheme.spacing8),

        // Title
        Text(
          item.title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        // Subtitle
        if (item.subtitle != null) ...[
          const SizedBox(height: AppTheme.spacing4),
          Expanded(
            child: Text(
              item.subtitle!,
              style: TextStyle(fontSize: 12, color: context.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ] else
          const Spacer(),

        // Participants avatar stack
        if (participantAvatars.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacing8),
          AnimatedAvatarStack(
            items: participantAvatars,
            maxVisible: 3,
            avatarSize: 24,
            overlapFraction: 0.3,
            animationEnabled: false,
            showOverflowCount: true,
          ),
        ],

        // Footer: duration + message count
        if (item.trackedDuration != null || item.messageCount > 0) ...[
          const SizedBox(height: AppTheme.spacing8),
          _FooterRow(
            duration: item.trackedDuration,
            messageCount: item.messageCount,
            l10n: l10n,
          ),
        ],
      ],
    );
  }

  Color _cardColor(BuildContext context) {
    switch (item.priority) {
      case TimelinePriority.high:
        return AppTheme.errorRed.withValues(alpha: 0.25);
      case TimelinePriority.medium:
        return AppTheme.warningYellow.withValues(alpha: 0.18);
      case TimelinePriority.low:
        return AppTheme.graphBlue.withValues(alpha: 0.18);
      case TimelinePriority.done:
        return context.card;
    }
  }
}

/// Small colored dot + priority label.
class _PriorityBadge extends StatelessWidget {
  final TimelinePriority priority;

  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (color, label) = switch (priority) {
      TimelinePriority.low => (AppTheme.successGreen, l10n.timelinePriorityLow),
      TimelinePriority.medium => (
        AppTheme.warningYellow,
        l10n.timelinePriorityMedium,
      ),
      TimelinePriority.high => (AppTheme.errorRed, l10n.timelinePriorityHigh),
      TimelinePriority.done => (
        SemanticColors.disabled,
        l10n.timelinePriorityDone,
      ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppTheme.spacing6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Duration badge + message count in the card footer.
class _FooterRow extends StatelessWidget {
  final Duration? duration;
  final int messageCount;
  final AppLocalizations l10n;

  const _FooterRow({this.duration, this.messageCount = 0, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final color = context.textTertiary;
    const iconSize = 13.0;

    return Row(
      children: [
        if (duration != null) ...[
          Icon(Icons.access_time, size: iconSize, color: color),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            _formatDuration(duration!),
            style: TextStyle(fontSize: 11, color: color),
          ),
        ],
        if (duration != null && messageCount > 0)
          const SizedBox(width: AppTheme.spacing12),
        if (messageCount > 0) ...[
          Icon(Icons.chat_bubble_outline, size: iconSize, color: color),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            '$messageCount', // lint-allow: hardcoded-string
            style: TextStyle(fontSize: 11, color: color),
          ),
        ],
      ],
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return l10n.timelineDuration(
        hours.toString().padLeft(2, '0'),
        minutes.toString().padLeft(2, '0'),
      );
    }
    return l10n.timelineDurationMinutesOnly(minutes.toString().padLeft(2, '0'));
  }
}

/// Diagonal-striped break time card.
class TimelineBreakCard extends StatelessWidget {
  final double height;
  final String label;

  const TimelineBreakCard({
    super.key,
    required this.height,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: _StripePainter(
          stripeColor: context.border.withValues(alpha: 0.15),
          spacing: 12.0,
          strokeWidth: 1.0,
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: context.textTertiary.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: context.textTertiary.withValues(alpha: 0.7),
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

/// Paints diagonal stripes for the break-time card background.
class _StripePainter extends CustomPainter {
  final Color stripeColor;
  final double spacing;
  final double strokeWidth;

  _StripePainter({
    required this.stripeColor,
    this.spacing = 12.0,
    this.strokeWidth = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = stripeColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // Draw diagonal lines from bottom-left to top-right.
    final count = ((size.width + size.height) / spacing).ceil();
    for (var i = -count; i < count; i++) {
      final offset = i * spacing;
      canvas.drawLine(
        Offset(offset, size.height),
        Offset(offset + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StripePainter oldDelegate) =>
      stripeColor != oldDelegate.stripeColor ||
      spacing != oldDelegate.spacing ||
      strokeWidth != oldDelegate.strokeWidth;
}
