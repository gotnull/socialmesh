// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Ambient presence strip for the MeshCanvas viewer HUD (P5, Variant A).
//
// Source of truth: docs/canvas/CANVAS_PRESENCE_V0_1.md §7.1 + the
// P4.5 visual composition review.
//
// Design contract:
//   - HIDDEN entirely when there are zero remote peers. Absence
//     communicates solitude; we do NOT render an "alone" string.
//   - HIDDEN entirely on Local Device Canvas (mount site enforces).
//   - Avatar cluster is the canonical `AnimatedAvatarStack` from
//     `lib/core/widgets/animated_avatar_stack.dart` — same primitive
//     NodeDex co-seen uses. ClipOval + per-avatar border + dark-aware
//     fill = the crisp NodeDex aesthetic. We pass `animationEnabled:
//     false` to suppress its 5 s cycling because §7.6 bans persistent
//     motion in this surface; the static layout still benefits from
//     the primitive's clean rendering and overflow handling.
//   - LayoutBuilder selects the collapse mode based on available
//     width:
//       width >= 220 pt :  avatars + textual pill
//       width >= 150 pt :  avatars + count-only pill
//       width  <  150 pt :  pill only
//   - Tap target opens an `AppBottomSheet.showScrollable` listing of
//     every present peer.
//
// This file deliberately uses NO new color literals. Every visible
// surface composes from `Theme.of(context).colorScheme` + the
// existing `BuildContext` color extensions in `lib/core/theme.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_avatar_stack.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../services/canvas/presence_models.dart';
import '../../../services/haptic_service.dart';
import '../../nodedex/widgets/tappable_sigil_avatar.dart';
import '../providers/presence_providers.dart';
import 'canvas_presence_sheet.dart';

/// Visible-width thresholds for the collapse modes. Constants live
/// in-file so a future tweak does not ripple through a separate
/// design-token surface.
const double _kNormalMinWidth = 220;
const double _kTightMinWidth = 150;

/// Maximum stacked avatars before overflow "+N" kicks in.
const int _kMaxAvatarSlots = 4;

/// Avatar diameter in points. Matches NodeDex co-seen.
const double _kAvatarSize = AvatarStackDefaults.avatarSize;

class CanvasPresenceStrip extends ConsumerWidget {
  /// The canvas this strip reflects. P5 mount site (the viewer body)
  /// guarantees that strip only mounts when the canvas is mesh-scoped.
  final int canvasLocalId;

  const CanvasPresenceStrip({super.key, required this.canvasLocalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEntries = ref.watch(canvasPresenceProvider(canvasLocalId));
    final entries = asyncEntries.asData?.value ?? const <PresenceEntry>[];
    if (entries.isEmpty) {
      // Zero remote peers: unmount. Absence communicates solitude.
      return const SizedBox.shrink();
    }

    final paintingCount = entries
        .where((e) => e.state == PresenceState.painting)
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : _kNormalMinWidth;
        final mode = _modeForWidth(width);
        return _StripBody(
          canvasLocalId: canvasLocalId,
          entries: entries,
          paintingCount: paintingCount,
          mode: mode,
        );
      },
    );
  }

  static _CollapseMode _modeForWidth(double width) {
    if (width >= _kNormalMinWidth) return _CollapseMode.normal;
    if (width >= _kTightMinWidth) return _CollapseMode.tight;
    return _CollapseMode.extreme;
  }
}

enum _CollapseMode { normal, tight, extreme }

class _StripBody extends ConsumerWidget {
  final int canvasLocalId;
  final List<PresenceEntry> entries;
  final int paintingCount;
  final _CollapseMode mode;

  const _StripBody({
    required this.canvasLocalId,
    required this.entries,
    required this.paintingCount,
    required this.mode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // Standard tap haptic — same as palette swatch select and
        // every other one-tap UI affordance. The P9 / §7.6 ban on
        // haptics applies to presence-change events (inbound frames,
        // state transitions), not to a deliberate user tap on a UI
        // target.
        ref.haptics.itemSelect();
        _openSheet(context);
      },
      child: _buildForMode(context),
    );
  }

  Widget _buildForMode(BuildContext context) {
    switch (mode) {
      case _CollapseMode.normal:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AvatarCluster(entries: entries),
            const SizedBox(width: AppTheme.spacing8),
            _Pill(text: _normalText(context)),
          ],
        );
      case _CollapseMode.tight:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AvatarCluster(entries: entries),
            const SizedBox(width: AppTheme.spacing8),
            _Pill(text: _tightText(context)),
          ],
        );
      case _CollapseMode.extreme:
        return _Pill(text: _normalText(context));
    }
  }

  String _normalText(BuildContext context) {
    final l10n = context.l10n;
    if (paintingCount > 0) {
      return l10n.meshCanvasPresenceWithPainting(entries.length, paintingCount);
    }
    return l10n.meshCanvasPresenceCount(entries.length);
  }

  String _tightText(BuildContext context) {
    final l10n = context.l10n;
    if (paintingCount > 0) {
      return l10n.meshCanvasPresenceWithPaintingTight(
        entries.length,
        paintingCount,
      );
    }
    return l10n.meshCanvasPresenceCountTight(entries.length);
  }

  void _openSheet(BuildContext context) {
    AppBottomSheet.showScrollable<void>(
      context: context,
      initialChildSize: 0.55,
      minChildSize: 0.40,
      maxChildSize: 0.85,
      builder: (controller) => CanvasPresenceSheet(
        canvasLocalId: canvasLocalId,
        scrollController: controller,
      ),
    );
  }
}

/// Wrapper that maps the presence entries into the canonical
/// [AnimatedAvatarStack] used by NodeDex co-seen. Cycling animation
/// is disabled to comply with §7.6 (no persistent motion in this
/// surface), but the visual contract — bordered ClipOval, dark-aware
/// fill, +N overflow — comes for free.
class _AvatarCluster extends StatelessWidget {
  final List<PresenceEntry> entries;

  const _AvatarCluster({required this.entries});

  @override
  Widget build(BuildContext context) {
    final items = entries
        .map(
          (e) => AvatarStackItem(
            id: e.nodeNum.toString(),
            child: TappableSigilAvatar(
              nodeNum: e.nodeNum,
              size: _kAvatarSize - AvatarStackDefaults.borderWidth * 2,
              enableTap: false,
            ),
          ),
        )
        .toList(growable: false);

    return AnimatedAvatarStack(
      items: items,
      maxVisible: _kMaxAvatarSlots,
      avatarSize: _kAvatarSize,
      animationEnabled: false,
      showOverflowCount: true,
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;

  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.25),
          width: 0.6,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: context.textPrimary,
          letterSpacing: 0.3,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }
}
