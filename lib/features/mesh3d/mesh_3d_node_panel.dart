// SPDX-License-Identifier: GPL-3.0-or-later

// Mesh 3D Node Panel
//
// A glass-styled slide-out panel that lists nodes visible in the 3D
// visualization. Supports search filtering, presence-based sorting,
// and staggered list animations matching the NodeDex visual language.
//
// The panel slides in from the left edge of the viewport and includes
// proper SafeArea insets for notched / Dynamic Island devices.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../core/widgets/search_filter_header.dart';
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
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: context.card.withValues(alpha: 0.92),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border(
                right: BorderSide(color: context.border.withValues(alpha: 0.2)),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(4, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top safe area spacer.
                SizedBox(height: topPadding),

                // Header.
                _PanelHeader(
                  nodeCount: filteredNodes.length,
                  accentColor: context.accentColor,
                  onClose: widget.onClose,
                ),

                // Search field.
                _PanelSearchField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),

                // Divider.
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: context.border.withValues(alpha: 0.15),
                ),

                // Node list.
                Expanded(
                  child: filteredNodes.isEmpty
                      ? _EmptyNodeList()
                      : ListView.builder(
                          padding: EdgeInsets.only(
                            top: 4,
                            bottom: bottomPadding + 8,
                          ),
                          itemCount: filteredNodes.length,
                          itemBuilder: (context, index) {
                            final node = filteredNodes[index];
                            final isMyNode = node.nodeNum == widget.myNodeNum;
                            final isSelected =
                                widget.selectedNodeNum == node.nodeNum;

                            return _StaggeredNodeTile(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PanelHeader
// ---------------------------------------------------------------------------

class _PanelHeader extends StatelessWidget {
  final int nodeCount;
  final Color accentColor;
  final VoidCallback onClose;

  const _PanelHeader({
    required this.nodeCount,
    required this.accentColor,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          Icon(Icons.hub, size: 18, color: accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Nodes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$nodeCount',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: context.textTertiary,
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
            tooltip: 'Close panel',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PanelSearchField
// ---------------------------------------------------------------------------

class _PanelSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _PanelSearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: SizedBox(
        height: 40,
        child: TextField(
          controller: controller,
          maxLength: 64,
          style: TextStyle(color: context.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Search nodes...',
            hintStyle: TextStyle(color: context.textTertiary, fontSize: 13),
            prefixIcon: Icon(
              Icons.search,
              size: 18,
              color: context.textTertiary,
            ),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    color: context.textTertiary,
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  )
                : null,
            filled: true,
            fillColor: context.background.withValues(alpha: 0.6),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                SearchFilterLayout.searchFieldRadius,
              ),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: onChanged,
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
              const SizedBox(width: 12),

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
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ME',
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
                    const SizedBox(height: 3),
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
                          const SizedBox(width: 6),
                          Icon(
                            Icons.signal_cellular_alt,
                            size: 11,
                            color: _snrColor(node.snr!.toDouble()),
                          ),
                          const SizedBox(width: 2),
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

// ---------------------------------------------------------------------------
// _EmptyNodeList
// ---------------------------------------------------------------------------

class _EmptyNodeList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 36,
              color: context.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'No nodes found',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try a different search term',
              style: TextStyle(
                fontSize: 12,
                color: context.textTertiary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _StaggeredNodeTile — staggered entrance animation for list tiles
// ---------------------------------------------------------------------------

class _StaggeredNodeTile extends StatefulWidget {
  final int index;
  final Widget child;

  const _StaggeredNodeTile({required this.index, required this.child});

  @override
  State<_StaggeredNodeTile> createState() => _StaggeredNodeTileState();
}

class _StaggeredNodeTileState extends State<_StaggeredNodeTile>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  bool _hasAnimated = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(-0.15, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // Stagger the entrance: delay based on index, capped at 500ms.
    final delay = Duration(milliseconds: (widget.index * 40).clamp(0, 500));
    Future<void>.delayed(delay, () {
      if (mounted && !_hasAnimated) {
        _hasAnimated = true;
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
