// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Canvas presence bottom sheet (P5, Variant A).
//
// Source of truth: docs/canvas/CANVAS_PRESENCE_V0_1.md §7.2.
//
// Opens from the HUD presence strip's tap target. Renders the live
// remote-peer list — one row per peer — for the canvas the user is
// viewing. Canonical AppBottomSheet.showScrollable + scrollController
// shape per `lib/features/device/device_sheet.dart`.
//
// Visual rules (P9 + §7.6):
//   - No motion past the bottom-sheet open/close transition (owned by
//     the host AppBottomSheet, not this widget).
//   - No sound, no haptics on row interaction. Tapping a row opens
//     the NodeDex detail screen via TappableSigilAvatar's default
//     behaviour — same as every other sigil tap target in the app.
//   - SectionTitle uses the approved "Here right now" copy — never
//     "Users collaborating" / "Active members" / similar SaaS lines.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/section_header.dart';
import '../../../services/canvas/presence_models.dart';
import '../../nodedex/widgets/tappable_sigil_avatar.dart';
import '../providers/presence_providers.dart';

class CanvasPresenceSheet extends ConsumerWidget {
  /// The canvas whose presence is being inspected.
  final int canvasLocalId;

  /// Scroll controller injected by `AppBottomSheet.showScrollable`.
  /// MUST be wired into the inner scrollable so drag-to-dismiss
  /// works (per the canonical sheet pattern; see CLAUDE.md
  /// "Bottom Sheet Variant Choice").
  final ScrollController scrollController;

  const CanvasPresenceSheet({
    super.key,
    required this.canvasLocalId,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEntries = ref.watch(canvasPresenceProvider(canvasLocalId));
    final entries = asyncEntries.asData?.value ?? const <PresenceEntry>[];
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing8,
            AppTheme.spacing16,
            AppTheme.spacing8,
          ),
          child: SectionTitle(title: context.l10n.meshCanvasPresenceSheetTitle),
        ),
        Divider(
          height: 1,
          thickness: 0.5,
          color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
        ),
        Expanded(
          child: ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing8,
            ),
            itemCount: entries.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppTheme.spacing8),
            itemBuilder: (context, index) =>
                _PresenceRow(entry: entries[index], nowMs: nowMs),
          ),
        ),
      ],
    );
  }
}

class _PresenceRow extends StatelessWidget {
  final PresenceEntry entry;
  final int nowMs;

  const _PresenceRow({required this.entry, required this.nowMs});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ageMs = nowMs - entry.lastSeenMs;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Row(
        children: [
          TappableSigilAvatar(nodeNum: entry.nodeNum, size: 36),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayNameHint ??
                      context.l10n.meshCanvasPresenceUnknownAuthor(
                        _hex8(entry.nodeNum),
                      ),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  _relativeAge(ageMs),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.textTertiary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ],
            ),
          ),
          _StateBadge(state: entry.state),
        ],
      ),
    );
  }

  String _hex8(int nodeNum) {
    final masked = nodeNum & 0xFFFFFFFF;
    return masked.toRadixString(16).padLeft(8, '0');
  }

  String _relativeAge(int ageMs) {
    final s = ageMs ~/ 1000;
    if (s < 5) return 'now';
    if (s < 60) return '${s}s ago';
    final m = s ~/ 60;
    return '${m}m ago';
  }
}

class _StateBadge extends StatelessWidget {
  final PresenceState state;

  const _StateBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _labelFor(context, state);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.4),
          width: 0.6,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: context.textSecondary,
          letterSpacing: 0.3,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }

  String _labelFor(BuildContext context, PresenceState s) {
    final l10n = context.l10n;
    switch (s) {
      case PresenceState.viewing:
        return l10n.meshCanvasPresenceStateViewing;
      case PresenceState.active:
        return l10n.meshCanvasPresenceStateActive;
      case PresenceState.painting:
        return l10n.meshCanvasPresenceStatePainting;
      case PresenceState.leaving:
        // Leaving is never stored, so this case is unreachable for
        // any entry the sheet renders. Fall back defensively.
        return l10n.meshCanvasPresenceStateViewing;
    }
  }
}
