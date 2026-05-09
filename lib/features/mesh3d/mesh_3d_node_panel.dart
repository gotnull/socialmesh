// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Mesh 3D Node Panel
//
// The node panel for the 3D mesh visualization. Uses [MapNodeDrawer] for
// the glass-styled slide-out chrome and provides its own node-tile
// rendering with presence-based coloring and SNR badges.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../core/widgets/map_node_drawer.dart';
import '../../models/mesh_models.dart';
import '../../models/presence_confidence.dart';
import '../../providers/presence_providers.dart';
import '../../utils/presence_utils.dart';

// ---------------------------------------------------------------------------
// Mesh3DNodePanel
// ---------------------------------------------------------------------------

/// A glass-styled side panel listing nodes in the current 3D visualization.
///
/// Slides in from the left. The caller controls visibility via
/// [AnimatedPositioned] and provides a dismiss callback. Internally the panel
/// manages its own search state and delegates node selection back via
/// [onNodeSelected].
class Mesh3DNodePanel extends StatefulWidget {
  /// All nodes currently visible (post-filter) in the 3D view.
  final Map<int, MeshNode> visibleNodes;

  /// The full, unfiltered node map (used for "N of M" count display).
  final Map<int, MeshNode> allNodes;

  /// The user's own node number, if known.
  final int? myNodeNum;

  /// The currently selected node number, if any.
  final int? selectedNodeNum;

  /// Current presence data for all nodes.
  final Map<int, NodePresence> presenceMap;

  /// Called when the user taps a node in the list.
  final ValueChanged<int> onNodeSelected;

  /// Called when the panel requests to close.
  final VoidCallback onClose;

  const Mesh3DNodePanel({
    super.key,
    required this.visibleNodes,
    required this.allNodes,
    required this.myNodeNum,
    required this.selectedNodeNum,
    required this.presenceMap,
    required this.onNodeSelected,
    required this.onClose,
  });

  @override
  State<Mesh3DNodePanel> createState() => _Mesh3DNodePanelState();
}

class _Mesh3DNodePanelState extends State<Mesh3DNodePanel> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MeshNode> _filteredSortedNodes() {
    var nodes = widget.visibleNodes.values.toList();

    // Apply search filter.
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      nodes = nodes.where((node) {
        return node.displayName.toLowerCase().contains(query) ||
            node.shortName?.toLowerCase().contains(query) == true ||
            node.nodeNum.toRadixString(16).contains(query);
      }).toList();
    }

    // Sort: my node first, then online, then alphabetical.
    nodes.sort((a, b) {
      if (a.nodeNum == widget.myNodeNum) return -1;
      if (b.nodeNum == widget.myNodeNum) return 1;
      final aActive = presenceConfidenceFor(widget.presenceMap, a).isActive;
      final bActive = presenceConfidenceFor(widget.presenceMap, b).isActive;
      if (aActive && !bActive) return -1;
      if (!aActive && bActive) return 1;
      return a.displayName.compareTo(b.displayName);
    });

    return nodes;
  }

  @override
  Widget build(BuildContext context) {
    final filteredNodes = _filteredSortedNodes();
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return MapNodeDrawer(
      title: context.l10n.mesh3dNodesDrawerTitle,
      headerIcon: Icons.hub,
      itemCount: filteredNodes.length,
      onClose: widget.onClose,
      searchController: _searchController,
      onSearchChanged: (value) => setState(() => _searchQuery = value),
      content: Expanded(
        child: filteredNodes.isEmpty
            ? const DrawerEmptyState()
            : ListView.builder(
                padding: EdgeInsets.only(top: 4, bottom: bottomPadding + 8),
                itemCount: filteredNodes.length,
                itemBuilder: (context, index) {
                  final node = filteredNodes[index];
                  final isMyNode = node.nodeNum == widget.myNodeNum;
                  final isSelected = widget.selectedNodeNum == node.nodeNum;

                  return StaggeredDrawerTile(
                    index: index,
                    child: _NodeListTile(
                      node: node,
                      isMyNode: isMyNode,
                      isSelected: isSelected,
                      presenceMap: widget.presenceMap,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onNodeSelected(node.nodeNum);
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _NodeListTile
// ---------------------------------------------------------------------------

class _NodeListTile extends StatelessWidget {
  final MeshNode node;
  final bool isMyNode;
  final bool isSelected;
  final Map<int, NodePresence> presenceMap;
  final VoidCallback onTap;

  const _NodeListTile({
    required this.node,
    required this.isMyNode,
    required this.isSelected,
    required this.presenceMap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final presence = presenceConfidenceFor(presenceMap, node);
    final baseColor = isMyNode
        ? context.accentColor
        : (presence.isActive
              ? AppTheme.primaryPurple
              : (presence.isFading
                    ? AppTheme.warningYellow
                    : (presence.isStale
                          ? context.textSecondary
                          : context.textTertiary)));

    return Material(
      color: isSelected
          ? context.accentColor.withValues(alpha: 0.12)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: context.accentColor.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Node avatar.
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: baseColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: baseColor.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    node.shortName?.isNotEmpty == true
                        ? node.shortName!.characters.first.toUpperCase()
                        : node.nodeNum
                              .toRadixString(16)
                              .characters
                              .first
                              .toUpperCase(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: baseColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),

              // Node info.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isMyNode)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: context.accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius4,
                              ),
                            ),
                            child: Text(
                              context.l10n.mesh3dMyNodeBadge,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: context.accentColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            node.displayName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: context.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing3),
                    Row(
                      children: [
                        // Presence dot.
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: presence.isActive
                                ? AppTheme.successGreen
                                : (presence.isFading
                                      ? AppTheme.warningYellow
                                      : context.textTertiary.withValues(
                                          alpha: 0.5,
                                        )),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            presenceStatusText(
                              presence,
                              lastHeardAgeFor(presenceMap, node),
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (node.snr != null) ...[
                          const SizedBox(width: AppTheme.spacing6),
                          Icon(
                            Icons.signal_cellular_alt,
                            size: 11,
                            color: _snrColor(node.snr!.toDouble()),
                          ),
                          const SizedBox(width: AppTheme.spacing2),
                          Text(
                            '${node.snr}dB',
                            style: TextStyle(
                              fontSize: 10,
                              color: context.textTertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Chevron.
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: context.textTertiary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _snrColor(double snr) {
    if (snr >= 5) return AccentColors.cyan;
    if (snr >= 0) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }
}
