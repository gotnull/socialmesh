// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../providers/mesh_beacon_providers.dart';
import '../../../services/haptic_service.dart';

/// A compact entry point to review newly received Mesh Beacon offers.
class MeshBeaconNotice extends ConsumerWidget {
  const MeshBeaconNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayed = ref.watch(meshBeaconNoticesProvider);
    if (displayed.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing8,
      ),
      child: StatusBanner.accent(
        icon: Icons.cell_tower,
        title: context.l10n.meshBeaconNoticeTitle(displayed.length),
        subtitle: context.l10n.meshBeaconNoticeSubtitle,
        onTap: () {
          ref.haptics.buttonTap();
          ref.read(meshBeaconNoticesProvider.notifier).dismiss(displayed);
          Navigator.of(context).pushNamed('/mesh-beacon');
        },
        trailing: IconButton(
          icon: const Icon(Icons.close),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () {
            ref.haptics.buttonTap();
            ref.read(meshBeaconNoticesProvider.notifier).dismiss(displayed);
          },
        ),
      ),
    );
  }
}
