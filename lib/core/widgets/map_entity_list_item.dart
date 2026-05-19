// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';
import '../theme.dart';

/// Protocol-agnostic list-row used by both the Meshtastic node-list
/// drawer and the MeshCore contact-list drawer on the map screen. The
/// caller resolves protocol-specific shapes (Meshtastic [MeshNode] or
/// MeshCore [MeshCoreContact]) into the input fields below.
///
/// Visual: 36pt circular avatar with a single-character initial, the
/// entity's display name on the first line, a coloured presence dot +
/// status text on the second line, an optional distance-from-me pill,
/// and a trailing chevron. A "YOU" badge renders inline when the row
/// is the user's own entity. A small "?" stale badge overlays the
/// avatar when the position is from cache rather than a live fix.
///
/// Stays inside `lib/core/widgets/` per the project's protocol
/// isolation rule - no imports from `lib/features/` or
/// `lib/services/` are permitted from this file.
class MapEntityListItem extends StatelessWidget {
  /// Display name shown on the first line. Already truncated by the
  /// caller if needed (we still apply ellipsis as a safety net).
  final String displayName;

  /// Single character rendered inside the avatar circle. Caller
  /// supplies whatever's most identifying (short name initial,
  /// node-num initial hex char, etc.).
  final String avatarChar;

  /// "You are here" tinting. When true, the avatar uses the accent
  /// colour and a "YOU" pill renders next to the name.
  final bool isMyEntity;

  /// Tile is the currently-selected entity on the map. Highlights the
  /// background and tints the chevron.
  final bool isSelected;

  /// Position is from cache (no recent fix). Renders a "?" overlay on
  /// the avatar + a "Last known" pill on the second line.
  final bool isStale;

  /// True for active/online presence. Drives the green presence dot
  /// and full-opacity name. False renders the dot grey and dims the
  /// name to `textSecondary`.
  final bool isActive;

  /// Pre-coloured status text (e.g. "Online", "Heard 3m ago"). Caller
  /// picks the colour to match the protocol's status semantics.
  final String statusText;
  final Color statusColor;

  /// Optional pre-formatted distance string (e.g. "1.2 km" or "850m").
  /// Caller does the unit conversion; this widget only renders.
  final String? distanceText;

  /// Optional tooltip shown when long-pressing the status text. Used
  /// by Meshtastic to explain presence inference; MeshCore can leave
  /// this null.
  final String? statusTooltip;

  /// Pill shown next to the display name when [isMyEntity]. Defaults
  /// to the localised "YOU" badge string.
  final String? myEntityBadgeText;

  /// Pill shown on the second line when [isStale]. Defaults to the
  /// localised "Last known" string.
  final String? staleBadgeText;

  final VoidCallback onTap;

  const MapEntityListItem({
    super.key,
    required this.displayName,
    required this.avatarChar,
    required this.isMyEntity,
    required this.isSelected,
    required this.isStale,
    required this.isActive,
    required this.statusText,
    required this.statusColor,
    required this.onTap,
    this.distanceText,
    this.statusTooltip,
    this.myEntityBadgeText,
    this.staleBadgeText,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final baseColor = isMyEntity ? context.accentColor : statusColor;
    final youBadge = myEntityBadgeText ?? l10n.mapYouBadge;
    final lastKnownBadge = staleBadgeText ?? l10n.mapLastKnown;

    return Material(
      color: isSelected
          ? context.accentColor.withValues(alpha: 0.15)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _Avatar(
                avatarChar: avatarChar,
                baseColor: baseColor,
                isStale: isStale,
              ),
              const SizedBox(width: AppTheme.spacing10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (isActive
                                        ? context.textPrimary
                                        : context.textSecondary),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isMyEntity) ...[
                          SizedBox(width: AppTheme.spacing6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: context.accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius3,
                              ),
                            ),
                            child: Text(
                              youBadge,
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: context.accentColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: AppTheme.spacing2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppTheme.successGreen
                                : context.textTertiary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: AppTheme.spacing4),
                        if (statusTooltip != null)
                          Tooltip(
                            message: statusTooltip!,
                            child: Text(
                              statusText,
                              style: context.captionStyle?.copyWith(
                                color: statusColor,
                              ),
                            ),
                          )
                        else
                          Text(
                            statusText,
                            style: context.captionStyle?.copyWith(
                              color: statusColor,
                            ),
                          ),
                        if (isStale) ...[
                          SizedBox(width: AppTheme.spacing6),
                          Text(
                            lastKnownBadge,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.warningYellow.withValues(
                                alpha: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (distanceText != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.background,
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                  child: Text(
                    distanceText!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary,
                    ),
                  ),
                ),
                SizedBox(width: AppTheme.spacing4),
              ],
              Icon(
                Icons.chevron_right,
                size: 18,
                color: isSelected
                    ? context.accentColor
                    : context.textTertiary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String avatarChar;
  final Color baseColor;
  final bool isStale;

  const _Avatar({
    required this.avatarChar,
    required this.baseColor,
    required this.isStale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: isStale ? 0.3 : 0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: baseColor.withValues(alpha: isStale ? 0.4 : 0.6),
          width: 1.5,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            avatarChar,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: baseColor,
            ),
          ),
          if (isStale)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.warningYellow,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.card, width: 1.5),
                ),
                child: const Center(
                  child: Text(
                    '?',
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
