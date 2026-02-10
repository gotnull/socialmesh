// Vendored from vs_node_view v2.1.1 — BSD-3-Clause
// Import paths rewritten for Socialmesh vendoring.
// Modified: Replaced plain Card with glass morphism styled container matching
// Socialmesh sci-fi aesthetic.
// Modified: Added category icons and accent-colored section headers.
// Modified: Back navigation button for subgroup menus.
// Modified: Constrained width for mobile readability.

import 'package:flutter/material.dart';

import '../data/vs_node_data_provider.dart';

class VSContextMenu extends StatefulWidget {
  /// Base context menu for creating new nodes.
  ///
  /// Used in [VSNodeView] to present available node builders to the user.
  /// Styled with glass morphism to match the Socialmesh sci-fi design
  /// language.
  const VSContextMenu({required this.nodeBuilders, super.key});

  /// A map of all nodeBuilders. In this format:
  ///
  /// ```
  /// {
  ///   Subgroup: {
  ///     nodeName: NodeBuilder,
  ///   },
  ///   nodeName: NodeBuilder,
  /// }
  /// ```
  final Map<String, dynamic> nodeBuilders;

  @override
  State<VSContextMenu> createState() => _VSContextMenuState();
}

class _VSContextMenuState extends State<VSContextMenu> {
  late Map<String, dynamic> nodeBuilders;

  /// Stack of (label, map) pairs so the user can navigate back through
  /// subgroup levels.
  final List<MapEntry<String, Map<String, dynamic>>> _navigationStack = [];

  @override
  void initState() {
    super.initState();
    nodeBuilders = widget.nodeBuilders;
  }

  void _navigateInto(String label, Map<String, dynamic> subgroup) {
    _navigationStack.add(MapEntry(label, nodeBuilders));
    setState(() {
      nodeBuilders = subgroup;
    });
  }

  void _navigateBack() {
    if (_navigationStack.isNotEmpty) {
      setState(() {
        nodeBuilders = _navigationStack.removeLast().value;
      });
    }
  }

  /// Returns an icon for known subgroup names. Falls back to a generic icon
  /// for unknown categories.
  IconData _iconForCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('trigger')) return Icons.bolt;
    if (lower.contains('condition')) return Icons.filter_alt_outlined;
    if (lower.contains('logic')) return Icons.account_tree_outlined;
    if (lower.contains('action')) return Icons.play_arrow;
    if (lower.contains('query') || lower.contains('nodedex')) {
      return Icons.search;
    }
    return Icons.widgets_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final entries = nodeBuilders.entries.toList();

    final List<Widget> children = [];

    // Back button when inside a subgroup.
    if (_navigationStack.isNotEmpty) {
      final parentLabel = _navigationStack.last.key;
      children.add(
        _ContextMenuItem(
          onTap: _navigateBack,
          child: Row(
            children: [
              Icon(
                Icons.arrow_back_ios,
                size: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  parentLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      );
      children.add(_GlassDivider(color: colorScheme.onSurface));
    }

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];

      if (entry.value is Map) {
        // Subgroup — show with category icon and chevron.
        children.add(
          _ContextMenuItem(
            onTap: () =>
                _navigateInto(entry.key, entry.value as Map<String, dynamic>),
            child: Row(
              children: [
                Icon(
                  _iconForCategory(entry.key),
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                      letterSpacing: 0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        );
      } else {
        // Leaf node builder — tappable to create the node.
        children.add(
          _ContextMenuItem(
            onTap: () {
              final dataProvider = VSNodeDataProvider.of(context);
              dataProvider.createNodeFromContext(entry.value);
              dataProvider.closeContextMenu();
            },
            child: Text(
              entry.key,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface,
                letterSpacing: 0.2,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        );
      }

      // Divider between items (not after the last one).
      if (i < entries.length - 1) {
        children.add(_GlassDivider(color: colorScheme.onSurface));
      }
    }

    // Empty state — shouldn't happen in practice but handles gracefully.
    if (children.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Text(
            'No nodes available',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    // Glass morphism container matching the node card aesthetic.
    final surfaceColor = isDark
        ? colorScheme.surface.withValues(alpha: 0.88)
        : colorScheme.surface.withValues(alpha: 0.94);

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    return GestureDetector(
      // Prevent taps inside the menu from propagating to the canvas
      // (which would close the menu).
      onTap: () {},
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 160,
          maxWidth: 220,
          maxHeight: 360,
        ),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            // Subtle accent glow at the top edge.
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// A single tappable row in the context menu with generous touch targets
/// for mobile usability.
class _ContextMenuItem extends StatelessWidget {
  const _ContextMenuItem({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          // Height of at least 44dp for Material Design touch target
          // compliance.
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: child,
        ),
      ),
    );
  }
}

/// Subtle gradient divider matching the sci-fi node title divider style.
class _GlassDivider extends StatelessWidget {
  const _GlassDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.0),
            color.withValues(alpha: 0.1),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}
