// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/presence_confidence.dart';
import '../../../utils/number_format.dart';

/// Displays presence context for a signal card.
///
/// Shows:
/// - Intent chip (icon + label) when available
/// - Encounter count ("Seen X times") when meaningful
/// - Last-seen bucket label when available
/// - Short status quote when set
///
/// Uses Wrap layout to prevent truncation on narrow screens.
/// All data is passed as parameters - no provider reads inside.
class SignalPresenceContext extends StatelessWidget {
  const SignalPresenceContext({
    super.key,
    this.intent,
    this.shortStatus,
    this.encounterCount,
    this.lastSeenBucket,
    this.isBackNearby = false,
  });

  /// The sender's intent at time of signal (e.g., Available, Camping)
  final PresenceIntent? intent;

  /// Short status message from the sender
  final String? shortStatus;

  /// How many times we've encountered this node
  final int? encounterCount;

  /// Last-seen bucket label (e.g., "Active recently", "Seen today")
  final LastSeenBucket? lastSeenBucket;

  /// Whether node recently reappeared after >48h absence
  final bool isBackNearby;

  @override
  Widget build(BuildContext context) {
    final hasChips = _hasAnyChips;
    final hasStatus = shortStatus != null && shortStatus!.isNotEmpty;

    if (!hasChips && !hasStatus) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chips row (intent, encounter, last-seen, back nearby)
          if (hasChips)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (_showIntent) _buildIntentChip(context),
                if (_showEncounter) _buildEncounterBadge(context),
                if (_showLastSeen) _buildLastSeenBadge(context),
                if (isBackNearby) _buildBackNearbyBadge(context),
              ],
            ),
          // Short status quote
          if (hasStatus) ...[
            if (hasChips) const SizedBox(height: 4),
            _buildStatusLine(context),
          ],
        ],
      ),
    );
  }

  bool get _hasAnyChips =>
      _showIntent || _showEncounter || _showLastSeen || isBackNearby;

  bool get _showIntent => intent != null && intent != PresenceIntent.unknown;

  bool get _showEncounter => encounterCount != null && encounterCount! >= 2;

  bool get _showLastSeen => lastSeenBucket != null;

  Widget _buildIntentChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PresenceIntentIcons.iconFor(intent!),
            size: 12,
            color: context.accentColor,
          ),
          const SizedBox(width: 3),
          Text(
            intent!.label,
            style: TextStyle(
              color: context.accentColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEncounterBadge(BuildContext context) {
    final formattedCount = NumberFormatUtils.formatCount(
      encounterCount!,
      suffix: 'x',
    );
    return Text(
      'Seen $formattedCount',
      style: TextStyle(color: context.textTertiary, fontSize: 11),
    );
  }

  Widget _buildLastSeenBadge(BuildContext context) {
    return Text(
      lastSeenBucket!.label,
      style: TextStyle(color: context.textTertiary, fontSize: 11),
    );
  }

  Widget _buildBackNearbyBadge(BuildContext context) {
    return Text(
      'Back nearby',
      style: TextStyle(
        color: AccentColors.cyan,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildStatusLine(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.format_quote, size: 14, color: context.textTertiary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            shortStatus!,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
