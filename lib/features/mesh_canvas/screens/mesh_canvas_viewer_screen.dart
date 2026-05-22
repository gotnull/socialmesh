// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Single Mesh-canvas viewer screen.
//
// Scope: one MESH canvas. The Local Device Canvas does NOT use this
// screen — it renders inline inside the overview's Local tab so the
// IA never confuses Local sandbox state with channel-bound canvas
// state (Mesh-only screens like this one keep the app bar title set
// to the CHANNEL name, never "Local Device Canvas").
//
// Layout contract:
//
//   1) App bar title = canvas.name (the channel name). No "Local
//      Device Canvas" framing here — this screen is mesh-only.
//   2) The outer CustomScrollView MUST be non-scrollable so a drag
//      that escapes the InteractiveViewer cannot rubber-band the
//      body. Passing [NeverScrollableScrollPhysics] disables that
//      bubble path.
//   3) The viewport body lives in [CanvasViewportBody], shared with
//      the overview's Local tab.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../services/canvas/canvas_models.dart';
import '../../../services/haptic_service.dart';
import '../widgets/canvas_help_sheet.dart';
import '../widgets/canvas_viewport_body.dart';

class MeshCanvasViewerScreen extends ConsumerWidget {
  /// Canvas to render. The overview screen passes one of its mesh
  /// channel entries here; this screen does not lookup or auto-create.
  final CanvasSummary canvas;

  const MeshCanvasViewerScreen({super.key, required this.canvas});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassScaffold(
      // Canvas name = channel name (Primary / LongFast / etc) for
      // mesh canvases. The "MeshCanvas" brand lives on the overview.
      title: canvas.name,
      // Disable outer scroll so an InteractiveViewer-escaped drag
      // can never rubber-band the body. The viewport body + strip
      // already fill the viewport.
      physics: const NeverScrollableScrollPhysics(),
      actions: [
        IconButton(
          key: const ValueKey('mesh-canvas-help'),
          tooltip: context.l10n.meshCanvasHelpTooltip,
          icon: const Icon(Icons.help_outline_rounded),
          onPressed: () {
            ref.haptics.buttonTap();
            showCanvasHelpSheet(context: context);
          },
        ),
      ],
      slivers: [
        SliverFillRemaining(
          hasScrollBody: true,
          child: CanvasViewportBody(canvas: canvas),
        ),
      ],
    );
  }
}
