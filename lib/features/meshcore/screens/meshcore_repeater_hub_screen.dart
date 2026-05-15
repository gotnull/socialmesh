// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D49-A: admin-mode landing screen for a repeater contact.
//
// Reached from the repeater admin login dialog after a successful
// `PUSH_CODE_LOGIN_SUCCESS 0x85` with `admin_flag = 1`. Lists the
// admin tools as canonical `SettingsTile` rows:
//   - Status -> [MeshCoreRepeaterStatusScreen] (D49-A, shipped).
//   - CLI    -> [MeshCoreRepeaterCliScreen] (D49-B, shipped).
//   - Settings -> [MeshCoreRepeaterAdminSettingsScreen] (D49-C, shipped).
//
// Lifecycle: stateless ConsumerWidget. The admin session itself
// persists implicitly on the firmware side while the radio
// connection is up; the hub does not own session state. Closing
// the hub does NOT log out.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/settings_primitives.dart';
import '../../../models/meshcore_contact.dart';
import 'meshcore_repeater_admin_settings_screen.dart';
import 'meshcore_repeater_cli_screen.dart';
import 'meshcore_repeater_status_screen.dart';

class MeshCoreRepeaterHubScreen extends ConsumerWidget {
  final MeshCoreContact contact;
  const MeshCoreRepeaterHubScreen({super.key, required this.contact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return GlassScaffold(
      title: l10n.meshcoreRepeaterAdminHubTitle(contact.name),
      slivers: [
        SliverList(delegate: SliverChildListDelegate(_tools(context, l10n))),
      ],
    );
  }

  List<Widget> _tools(BuildContext context, dynamic l10n) {
    return [
      const SizedBox(height: AppTheme.spacing8),
      SettingsSectionHeader(
        title: l10n.meshcoreRepeaterAdminHubToolsHeader as String,
      ),
      SettingsTile(
        key: const ValueKey('meshcore-repeater-hub-status'),
        icon: Icons.analytics_outlined,
        iconColor: AccentColors.blue,
        title: l10n.meshcoreRepeaterAdminHubStatusTile as String,
        subtitle: l10n.meshcoreRepeaterAdminHubStatusTileSubtitle as String,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MeshCoreRepeaterStatusScreen(contact: contact),
            ),
          );
        },
      ),
      SettingsTile(
        key: const ValueKey('meshcore-repeater-hub-cli'),
        icon: Icons.terminal_rounded,
        iconColor: AccentColors.green,
        title: l10n.meshcoreRepeaterAdminHubCliTile as String,
        subtitle: l10n.meshcoreRepeaterAdminHubCliTileSubtitle as String,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MeshCoreRepeaterCliScreen(contact: contact),
            ),
          );
        },
      ),
      SettingsTile(
        key: const ValueKey('meshcore-repeater-hub-settings'),
        icon: Icons.tune_rounded,
        iconColor: AccentColors.orange,
        title: l10n.meshcoreRepeaterAdminHubSettingsTile as String,
        subtitle: l10n.meshcoreRepeaterAdminHubSettingsTileSubtitle as String,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  MeshCoreRepeaterAdminSettingsScreen(contact: contact),
            ),
          );
        },
      ),
    ];
  }
}
