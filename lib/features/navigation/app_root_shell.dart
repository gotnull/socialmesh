// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import 'main_shell.dart';
import 'meshcore_shell.dart';

/// Root shell that routes to protocol-specific shells based on activeProtocol.
///
/// Architecture:
/// - Watches `activeProtocolProvider` as single source of truth
/// - Uses `KeyedSubtree` with `ValueKey(activeProtocol)` for hard unmount
/// - Meshtastic and MeshCore never coexist in the widget tree
///
/// Protocol routing:
/// - `none`: Shows MainShell (default for now, will show scanner later)
/// - `meshtastic`: Shows MainShell (existing Meshtastic app shell)
/// - `meshcore`: Shows MeshCoreShell (new MeshCore-specific shell)
///
/// State isolation:
/// - Each shell is wrapped in KeyedSubtree to force complete rebuild
/// - Previous shell's state is destroyed on protocol switch
/// - No shared UI state between protocols
class AppRootShell extends ConsumerWidget {
  const AppRootShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProtocol = ref.watch(activeProtocolProvider);

    // Use KeyedSubtree with ValueKey to force hard unmount when protocol changes
    // This ensures the previous shell's widget tree is completely destroyed
    // and rebuilt fresh when switching between protocols
    return KeyedSubtree(
      key: ValueKey(activeProtocol),
      child: switch (activeProtocol) {
        // No device connected - show default Meshtastic shell (scanner access)
        ActiveProtocol.none => const MainShell(),

        // Meshtastic protocol active - show existing Meshtastic shell
        ActiveProtocol.meshtastic => const MainShell(),

        // MeshCore protocol active - show MeshCore-specific shell
        ActiveProtocol.meshcore => const MeshCoreShell(),
      },
    );
  }
}
