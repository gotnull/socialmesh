// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Map Node Drawer
//
// A reusable glass-styled slide-out panel for listing nodes across all
// map-like screens (world map, position log, geofence picker, mesh 3D).
//
// The panel provides a consistent outer chrome — backdrop blur, rounded
// right-side corners, accent-colored count badge, and a search field —
// while letting each caller supply its own list content via the [content]
// slot.
//
// Callers wrap this widget in an [AnimatedPositioned] to control slide-in
// animation (left: showPanel ? 0 : -300, width: 300).

import 'dart:ui';

import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';
import '../theme.dart';
import 'search_filter_header.dart';

// ---------------------------------------------------------------------------
// MapNodeDrawer — glass chrome shell
// ---------------------------------------------------------------------------

/// A glass-styled side panel with a consistent header, search field, and
/// a pluggable [content] area for node lists or entity lists.
///
/// The caller is responsible for:
/// - Wrapping this in [AnimatedPositioned] to animate the slide.
/// - Providing list/grid content via the [content] parameter.
/// - Managing the [searchController] lifecycle.
class MapNodeDrawer extends StatelessWidget {
  /// The title shown in the header (e.g. "Nodes", "Select Node").
  final String title;

  /// Icon shown to the left of the title.
  final IconData headerIcon;

  /// The number shown in the accent-colored badge.
  final int itemCount;

  /// Called when the close button is tapped.
  final VoidCallback onClose;

  /// Controller for the search text field.
  final TextEditingController searchController;

  /// Called when the search query changes.
  final ValueChanged<String> onSearchChanged;

  /// The scrollable content below the search field.
  ///
  /// Typically an [Expanded] wrapping a [ListView] or a [Column] with
  /// custom header items and an [Expanded] list.
  final Widget content;

  /// Optional widget inserted between the header and the search field,
  /// such as a tab bar.
  final Widget? headerExtra;

  /// Hint text shown in the search field. Defaults to `'Search nodes...'`.
  final String searchHintText;

  const MapNodeDrawer({
    super.key,
    required this.title,
    this.headerIcon = Icons.hub,
    required this.itemCount,
    required this.onClose,
    required this.searchController,
    required this.onSearchChanged,
    required this.content,
    this.headerExtra,
    this.searchHintText = 'Search nodes...', // lint-allow: hardcoded-string
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    // Dismiss keyboard on tap outside text fields.
    return Listener(
      onPointerDown: (_) => FocusScope.of(context).unfocus(),
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
                _DrawerHeader(
                  title: title,
                  icon: headerIcon,
                  itemCount: itemCount,
                  accentColor: context.accentColor,
                  onClose: onClose,
                ),

                // Optional extra (e.g. tab bar).
                if (headerExtra != null) headerExtra!,

                // Search field.
                _DrawerSearchField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  hintText: searchHintText,
                ),

                // Divider.
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: context.border.withValues(alpha: 0.15),
                ),

                // Caller-provided content.
                content,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _DrawerHeader
// ---------------------------------------------------------------------------

class _DrawerHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final int itemCount;
  final Color accentColor;
  final VoidCallback onClose;

  const _DrawerHeader({
    required this.title,
    required this.icon,
    required this.itemCount,
    required this.accentColor,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 12, 8, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accentColor),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Text(
              title,
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
              borderRadius: BorderRadius.circular(AppTheme.radius10),
            ),
            child: Text(
              '$itemCount',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacing4),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: context.textTertiary,
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
            tooltip: context.l10n.mapNodeDrawerClosePanel,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _DrawerSearchField
// ---------------------------------------------------------------------------

class _DrawerSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  const _DrawerSearchField({
    required this.controller,
    required this.onChanged,
    this.hintText = 'Search nodes...', // lint-allow: hardcoded-string
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacing12, 0, 12, 8),
      child: SizedBox(
        height: 40,
        child: TextField(
          controller: controller,
          maxLength: 64,
          style: TextStyle(color: context.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            counterText: '',
            hintText: hintText,
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
                    tooltip: context.l10n.commonClearSearch,
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
// DrawerEmptyState — shared empty-list placeholder
// ---------------------------------------------------------------------------

/// A centered empty-state widget for use inside [MapNodeDrawer.content].
class DrawerEmptyState extends StatelessWidget {
  /// The icon displayed above the text.
  final IconData icon;

  /// Primary message text.
  final String message;

  /// Optional secondary hint text.
  final String? hint;

  const DrawerEmptyState({
    super.key,
    this.icon = Icons.search_off,
    this.message = 'No nodes found', // lint-allow: hardcoded-string
    this.hint = 'Try a different search term', // lint-allow: hardcoded-string
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 36,
              color: context.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.textTertiary,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: AppTheme.spacing4),
              Text(
                hint!,
                style: TextStyle(
                  fontSize: 12,
                  color: context.textTertiary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// StaggeredDrawerTile — staggered entrance animation for list tiles
// ---------------------------------------------------------------------------

/// Wraps a child widget with a staggered fade+slide entrance animation.
///
/// Use this inside [MapNodeDrawer.content] list builders for a polished
/// entrance effect. The delay is proportional to [index] (40 ms per item,
/// capped at 500 ms).
class StaggeredDrawerTile extends StatefulWidget {
  /// Zero-based index in the list, used to compute entrance delay.
  final int index;

  /// The tile content to animate.
  final Widget child;

  const StaggeredDrawerTile({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  State<StaggeredDrawerTile> createState() => _StaggeredDrawerTileState();
}

class _StaggeredDrawerTileState extends State<StaggeredDrawerTile>
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

    // Stagger the entrance: delay based on index, capped at 500 ms.
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
