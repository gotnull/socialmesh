// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// "What is this?" sheet for the MeshCanvas viewer.
//
// Spec anchor: dev S7.B productization brief — "concise, retro,
// hacker, community-oriented explainer; no onboarding modal spam,
// no enterprise dashboard chrome." Surfaces via the (i) icon in the
// viewer's app bar.
//
// Uses the canonical [HelpSheet] + [HelpSheetItem] primitives from
// `lib/core/widgets/help_sheet.dart` so it looks and reads like
// every other in-app help sheet (Settings, Signals, NodeDex, etc.).
// HelpSheet handles the title, optional intro paragraph, and a
// vertical list of icon-tagged title/body rows in a glass bottom
// sheet — exactly the shape this feature needs.
//
// Tone rules: retro / BBS voice, no corporate hedging. Four
// interaction rows + one community-philosophy row keep the sheet
// short enough that a first-time user can dismiss in under 30s.
library;

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/help_sheet.dart';

/// Open the MeshCanvas help sheet as a content-heavy glass bottom
/// sheet. The sheet is purely informational — it does not return a
/// value and dismisses on drag-down / tap-outside.
Future<void> showCanvasHelpSheet({required BuildContext context}) {
  return AppBottomSheet.showScrollable<void>(
    context: context,
    initialChildSize: 0.7,
    minChildSize: 0.4,
    maxChildSize: 0.9,
    builder: (controller) {
      final l = context.l10n;
      return HelpSheet(
        scrollController: controller,
        title: l.meshCanvasHelpTitle,
        intro: l.meshCanvasHelpIntro,
        items: [
          // The Local Device Canvas is intentionally NOT explained
          // in user help. It is a developer / debug surface; the
          // product is the per-channel mesh canvas. Help anchors
          // the IA mesh-first.
          HelpSheetItem(
            icon: Icons.share_outlined,
            title: l.meshCanvasHelpMeshCanvasTitle,
            description: l.meshCanvasHelpMeshCanvasBody,
          ),
          // First paint wakes the board — /r/place dormancy.
          HelpSheetItem(
            icon: Icons.bolt_outlined,
            title: l.meshCanvasHelpFirstPaintTitle,
            description: l.meshCanvasHelpFirstPaintBody,
          ),
          // Gestures — primary then secondary.
          HelpSheetItem(
            icon: Icons.touch_app_outlined,
            title: l.meshCanvasHelpTapToPaintTitle,
            description: l.meshCanvasHelpTapToPaintBody,
          ),
          HelpSheetItem(
            icon: Icons.pan_tool_outlined,
            title: l.meshCanvasHelpPanZoomTitle,
            description: l.meshCanvasHelpPanZoomBody,
          ),
          // Tempo — set expectations about LoRa pace.
          HelpSheetItem(
            icon: Icons.timer_outlined,
            title: l.meshCanvasHelpTempoTitle,
            description: l.meshCanvasHelpTempoBody,
          ),
          // Overwrites — /r/place conflict philosophy.
          HelpSheetItem(
            icon: Icons.layers_outlined,
            title: l.meshCanvasHelpOverwriteTitle,
            description: l.meshCanvasHelpOverwriteBody,
          ),
          // Etiquette + community.
          HelpSheetItem(
            icon: Icons.groups_outlined,
            title: l.meshCanvasHelpCommunityTitle,
            description: l.meshCanvasHelpCommunityBody,
          ),
          // Status pill explainer — covers every hydration +
          // transmission HUD label so the user has a mental model
          // for the chrome that appears while painting.
          HelpSheetItem(
            icon: Icons.info_outline,
            title: l.meshCanvasHelpStatusTitle,
            description: l.meshCanvasHelpStatusBody,
          ),
          // Sharing-off-by-default privacy beat. Mirrors the
          // participation onboarding sheet so a user who skipped
          // the onboarding still discovers the toggle here.
          HelpSheetItem(
            icon: Icons.shield_outlined,
            title: l.meshCanvasHelpSharingTitle,
            description: l.meshCanvasHelpSharingBody,
          ),
        ],
      );
    },
  );
}
