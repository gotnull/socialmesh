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
//   - Up to 4 stacked TappableSigilAvatar (30 % overlap), then a
//     `+N` overflow chip in the 4th slot.
//   - Single soft 1.5 pt ring at 40 % opacity around painters.
//     No continuous motion. The only animation is a 220 ms ease-in
//     opacity fade between render frames; nothing recurs.
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

/// Maximum stacked avatars (slot 4 may be the `+N` overflow chip).
const int _kMaxAvatarSlots = 4;

/// Avatar diameter in points.
const double _kAvatarSize = 28;

/// Horizontal overlap factor between adjacent avatars.
const double _kAvatarOverlap = 0.30;

/// Opacity thresholds. Mirrors the P4.5 token table.
const Duration _kFreshWindow = Duration(seconds: 30);
const Duration _kAgingWindow = Duration(seconds: 120);

const double _kOpacityFresh = 1.00;
const double _kOpacityAging = 0.70;
const double _kOpacityNearExpiry = 0.45;

const double _kPaintingRingOpacity = 0.40;
const double _kPaintingRingWidth = 1.5;

const Duration _kFadeDuration = Duration(milliseconds: 220);

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
      child: AnimatedSwitcher(
        duration: _kFadeDuration,
        switchInCurve: Curves.easeOutCubic,
        child: _buildForMode(context),
      ),
    );
  }

  Widget _buildForMode(BuildContext context) {
    switch (mode) {
      case _CollapseMode.normal:
        return Row(
          key: const ValueKey('presence-mode-normal'),
          mainAxisSize: MainAxisSize.min,
          children: [
            _AvatarStack(entries: entries),
            const SizedBox(width: AppTheme.spacing8),
            _Pill(text: _normalText(context)),
          ],
        );
      case _CollapseMode.tight:
        return Row(
          key: const ValueKey('presence-mode-tight'),
          mainAxisSize: MainAxisSize.min,
          children: [
            _AvatarStack(entries: entries),
            const SizedBox(width: AppTheme.spacing8),
            _Pill(text: _tightText(context)),
          ],
        );
      case _CollapseMode.extreme:
        return _Pill(
          key: const ValueKey('presence-mode-extreme'),
          text: _normalText(context),
        );
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

class _AvatarStack extends StatelessWidget {
  final List<PresenceEntry> entries;

  const _AvatarStack({required this.entries});

  @override
  Widget build(BuildContext context) {
    final visible = entries.length > _kMaxAvatarSlots
        ? entries.take(_kMaxAvatarSlots - 1).toList(growable: false)
        : entries;
    final overflow = entries.length > _kMaxAvatarSlots
        ? entries.length - (_kMaxAvatarSlots - 1)
        : 0;

    final step = _kAvatarSize * (1 - _kAvatarOverlap);
    final slotCount = visible.length + (overflow > 0 ? 1 : 0);
    final stackWidth = slotCount == 0
        ? 0.0
        : _kAvatarSize + step * (slotCount - 1);

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    return SizedBox(
      width: stackWidth,
      height: _kAvatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * step,
              child: _PresenceAvatar(entry: visible[i], nowMs: nowMs),
            ),
          if (overflow > 0)
            Positioned(
              left: visible.length * step,
              child: _OverflowChip(remaining: overflow),
            ),
        ],
      ),
    );
  }
}

class _PresenceAvatar extends StatelessWidget {
  final PresenceEntry entry;
  final int nowMs;

  const _PresenceAvatar({required this.entry, required this.nowMs});

  @override
  Widget build(BuildContext context) {
    final ageMs = nowMs - entry.lastSeenMs;
    final opacity = _opacityForAge(ageMs);
    final isPainting = entry.state == PresenceState.painting;

    final avatar = TappableSigilAvatar(
      nodeNum: entry.nodeNum,
      size: _kAvatarSize,
      enableTap: false,
    );

    return AnimatedOpacity(
      duration: _kFadeDuration,
      curve: Curves.easeOutCubic,
      opacity: opacity,
      child: isPainting
          ? Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  width: _kPaintingRingWidth,
                  color: context.textPrimary.withValues(
                    alpha: _kPaintingRingOpacity,
                  ),
                ),
              ),
              padding: EdgeInsets.zero,
              child: avatar,
            )
          : avatar,
    );
  }

  double _opacityForAge(int ageMs) {
    if (ageMs < _kFreshWindow.inMilliseconds) return _kOpacityFresh;
    if (ageMs < _kAgingWindow.inMilliseconds) return _kOpacityAging;
    return _kOpacityNearExpiry;
  }
}

class _OverflowChip extends StatelessWidget {
  final int remaining;

  const _OverflowChip({required this.remaining});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: _kAvatarSize,
      height: _kAvatarSize,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.72),
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.4),
          width: 0.6,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '+$remaining',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.textSecondary,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;

  const _Pill({super.key, required this.text});

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
