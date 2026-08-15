// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: scaffold — nav shell root scaffold owning the bottom bar; each
// tab brings its own GlassScaffold

// Hosts NodeDex's three views behind a bottom bar.
//
// NodeDex is opened as its own full-screen route, so it has no bottom bar
// of its own to inherit. Its map and its groups screen used to be reached
// from a drawer sub-item and a button buried in the list; a bar puts the
// three ways of reading the same collection at the same level.
//
// Tabs are built on first visit and then kept alive: the map is expensive
// to construct and should not be paid for by someone who never opens it,
// and rebuilding it on every switch would lose the camera position.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../services/haptic_service.dart';
import '../../map/map_screen.dart';
import '../../navigation/widgets/nav_bar_item.dart';
import 'manage_node_groups_screen.dart';
import 'nodedex_screen.dart';

/// The views NodeDex's bottom bar switches between, in bar order.
enum NodeDexTab { dex, map, groups }

class NodeDexShellScreen extends ConsumerStatefulWidget {
  const NodeDexShellScreen({super.key, this.initialTab = NodeDexTab.dex});

  final NodeDexTab initialTab;

  @override
  ConsumerState<NodeDexShellScreen> createState() => _NodeDexShellScreenState();
}

class _NodeDexShellScreenState extends ConsumerState<NodeDexShellScreen> {
  late NodeDexTab _tab = widget.initialTab;

  /// Tabs the user has visited, so an unvisited one is never built.
  late final Set<NodeDexTab> _built = {widget.initialTab};

  void _select(NodeDexTab tab) {
    if (tab == _tab) return;
    ref.haptics.tabChange();
    AppLogging.nodeDex('Shell: tab ${_tab.name} -> ${tab.name}');
    setState(() {
      _tab = tab;
      _built.add(tab);
    });
  }

  Widget _bodyFor(NodeDexTab tab) {
    switch (tab) {
      case NodeDexTab.dex:
        return const NodeDexScreen();
      case NodeDexTab.map:
        return const MapScreen(nodedexMode: true);
      case NodeDexTab.groups:
        return const ManageNodeGroupsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Scaffold(
      // Each tab brings its own GlassScaffold, so this shell paints only
      // the bar. Transparent here would let the tab underneath show
      // through the safe-area inset.
      backgroundColor: theme.scaffoldBackgroundColor,
      body: IndexedStack(
        index: NodeDexTab.values.indexOf(_tab),
        children: [
          for (final tab in NodeDexTab.values)
            if (_built.contains(tab))
              _bodyFor(tab)
            else
              const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: theme.dividerColor.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.1 : 0.2,
              ),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.darkBackground.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: NavBarItem(
                    icon: _tab == NodeDexTab.dex
                        ? Icons.auto_stories
                        : Icons.auto_stories_outlined,
                    label: l10n.navigationNodeDex,
                    isSelected: _tab == NodeDexTab.dex,
                    onTap: () => _select(NodeDexTab.dex),
                  ),
                ),
                Expanded(
                  child: NavBarItem(
                    icon: _tab == NodeDexTab.map
                        ? Icons.map
                        : Icons.map_outlined,
                    label: l10n.navigationMap,
                    isSelected: _tab == NodeDexTab.map,
                    onTap: () => _select(NodeDexTab.map),
                  ),
                ),
                Expanded(
                  child: NavBarItem(
                    icon: _tab == NodeDexTab.groups
                        ? Icons.folder_shared
                        : Icons.folder_shared_outlined,
                    label: l10n.nodedexTabGroups,
                    isSelected: _tab == NodeDexTab.groups,
                    onTap: () => _select(NodeDexTab.groups),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
