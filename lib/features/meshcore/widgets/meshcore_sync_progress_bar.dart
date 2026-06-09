// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../providers/meshcore_providers.dart';

// Thin cross-tab progress bar shown on the MeshCore shell while the initial
// roster sync (contacts, then channels) drains after a connect. It fills as
// frames arrive (determinate when the firmware reports a total, indeterminate
// otherwise) and collapses to nothing once both syncs settle. Mounted once on
// the shell rather than per screen.
class MeshCoreSyncProgressBar extends ConsumerWidget {
  const MeshCoreSyncProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(meshCoreSyncProgressProvider);
    if (!progress.active) {
      return const SizedBox.shrink();
    }

    final accent = context.accentColor;
    return Semantics(
      label: context.l10n.meshcoreSyncingData,
      container: true,
      child: LinearProgressIndicator(
        value: progress.value,
        minHeight: AppTheme.spacing3,
        backgroundColor: accent.withValues(alpha: 0.12),
        valueColor: AlwaysStoppedAnimation<Color>(accent),
      ),
    );
  }
}
