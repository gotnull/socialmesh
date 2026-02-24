// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../models/incident.dart';
import '../models/incident_transition.dart';

/// Vertical timeline showing the immutable transition history of an incident.
///
/// Each entry displays fromState -> toState, actor, timestamp, and optional
/// note. Superseded transitions are labeled with muted styling. Terminal
/// state transitions (closed/cancelled) display with visual finality.
///
/// Spec: Sprint 008/W3.3, INCIDENT_LIFECYCLE.md.
class TransitionTimeline extends StatelessWidget {
  final List<IncidentTransition> transitions;

  const TransitionTimeline({super.key, required this.transitions});

  @override
  Widget build(BuildContext context) {
    if (transitions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text('No transition history', style: context.bodyMutedStyle),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < transitions.length; i++)
          _TimelineEntry(
            transition: transitions[i],
            isFirst: i == 0,
            isLast: i == transitions.length - 1,
          ),
      ],
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final IncidentTransition transition;
  final bool isFirst;
  final bool isLast;

  const _TimelineEntry({
    required this.transition,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final isSuperseded = transition.supersededBy != null;
    final isTerminal = transition.toState.isTerminal;
    final isMuted = isSuperseded || isTerminal;

    final dotColor = isSuperseded
        ? context.textTertiary
        : _stateColor(transition.toState);

    final textOpacity = isSuperseded ? 0.5 : 1.0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -- Timeline rail --
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // Top connector
                if (!isFirst)
                  Container(width: 2, height: 8, color: context.border),
                // Dot
                Container(
                  width: isTerminal ? 16 : 12,
                  height: isTerminal ? 16 : 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                    border: isTerminal
                        ? Border.all(color: dotColor, width: 3)
                        : null,
                  ),
                ),
                // Bottom connector
                if (!isLast)
                  Expanded(child: Container(width: 2, color: context.border)),
              ],
            ),
          ),

          // -- Content --
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16, right: 16),
              child: Opacity(
                opacity: textOpacity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // State change
                    Row(
                      children: [
                        _StateBadge(
                          state: transition.fromState,
                          muted: isMuted,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.arrow_forward,
                            size: 14,
                            color: context.textTertiary,
                          ),
                        ),
                        _StateBadge(state: transition.toState, muted: isMuted),
                        if (isSuperseded) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.textTertiary.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'superseded',
                              style: TextStyle(
                                fontSize: 10,
                                color: context.textTertiary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Actor + timestamp
                    Text(
                      '${transition.actorRole ?? 'unknown'} '
                      '(${transition.actorId.length > 8 ? '${transition.actorId.substring(0, 8)}...' : transition.actorId})'
                      '  •  '
                      '${_formatTimestamp(transition.timestamp)}',
                      style: context.captionMutedStyle,
                    ),

                    // Note
                    if (transition.note != null &&
                        transition.note!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        transition.note!,
                        style: context.bodySmallStyle?.copyWith(
                          color: context.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],

                    // Terminal finality indicator
                    if (isTerminal && !isSuperseded) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 12,
                            color: context.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Final state — no further transitions',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textTertiary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color _stateColor(IncidentState state) {
    return switch (state) {
      IncidentState.draft => Colors.grey,
      IncidentState.open => Colors.blue,
      IncidentState.assigned => Colors.orange,
      IncidentState.escalated => Colors.red,
      IncidentState.resolved => Colors.green,
      IncidentState.closed => Colors.blueGrey,
      IncidentState.cancelled => Colors.brown,
    };
  }

  static String _formatTimestamp(DateTime ts) {
    return DateFormat('d MMM yyyy HH:mm').format(ts);
  }
}

/// Small badge showing an incident state name with color coding.
class _StateBadge extends StatelessWidget {
  final IncidentState state;
  final bool muted;

  const _StateBadge({required this.state, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final color = _TimelineEntry._stateColor(state);
    final effectiveColor = muted ? color.withValues(alpha: 0.5) : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        state.name,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: effectiveColor,
        ),
      ),
    );
  }
}
