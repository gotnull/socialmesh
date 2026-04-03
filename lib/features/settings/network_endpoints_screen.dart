// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../scanner/widgets/network_connection_section.dart';

/// Settings screen for managing saved network (TCP/IP) endpoints.
///
/// mDNS discovery lives in the scanner screen only — this screen
/// is for CRUD on manually saved host:port endpoints.
class NetworkEndpointsScreen extends ConsumerWidget {
  const NetworkEndpointsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassScaffold(
      title: context.l10n.settingsNetworkEndpointsTitle,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing16,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const NetworkConnectionSection(),
            ]),
          ),
        ),
      ],
    );
  }
}
