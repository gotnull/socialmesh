// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../l10n/l10n_extension.dart';
import '../theme.dart';
import '../units/byte_format.dart';
import 'status_banner.dart';

/// Names the remote node a screen's commands go to while remote
/// administration is active, and renders nothing otherwise.
class RemoteAdminTargetBanner extends ConsumerWidget {
  const RemoteAdminTargetBanner({
    super.key,
    this.margin = const EdgeInsets.fromLTRB(
      AppTheme.spacing16,
      AppTheme.spacing8,
      AppTheme.spacing16,
      0,
    ),
  });

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remote = ref.watch(remoteAdminProvider);
    final nodeNum = remote.targetNodeNum;
    if (nodeNum == null) return const SizedBox.shrink();
    return StatusBanner.info(
      title: context.l10n.settingsRemoteAdminConfiguringTitle,
      subtitle: context.l10n.deviceMgmtRemoteTargetBanner(
        remote.targetNodeName ?? formatNodeId(nodeNum),
      ),
      margin: margin,
    );
  }
}
