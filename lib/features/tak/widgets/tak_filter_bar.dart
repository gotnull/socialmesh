// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/tak_filter_provider.dart';
import '../utils/cot_affiliation.dart';

/// Horizontal filter bar for TAK entities.
///
/// Displays affiliation toggle chips, stale mode button, and a search field.
/// Filter state is shared via [takFilterProvider] so it persists across
/// navigation between TakScreen and TakMapScreen.
class TakFilterBar extends ConsumerStatefulWidget {
  const TakFilterBar({super.key});

  @override
  ConsumerState<TakFilterBar> createState() => _TakFilterBarState();
}

class _TakFilterBarState extends ConsumerState<TakFilterBar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(takFilterProvider).searchQuery,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = ref.watch(takFilterProvider);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Affiliation chips + stale mode
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Affiliation chips for all affiliations
                  ..._primaryAffiliations.map(
                    (aff) => _buildAffiliationChip(
                      context,
                      aff,
                      filter.affiliations.contains(aff),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Stale mode toggle
                  _buildStaleModeChip(context, filter.staleMode),
                  // Clear all button
                  if (filter.isActive) ...[
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: Icon(
                        Icons.clear_all,
                        size: 16,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      label: const Text('Clear'),
                      labelStyle: theme.textTheme.labelSmall,
                      onPressed: () =>
                          ref.read(takFilterProvider.notifier).clearAll(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Search field
            SizedBox(
              height: 36,
              child: TextField(
                controller: _searchController,
                maxLength: 64,
                decoration: InputDecoration(
                  hintText: 'Search callsign or UID...',
                  hintStyle: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close,
                            size: 16,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          onPressed: () {
                            _searchController.clear();
                            ref
                                .read(takFilterProvider.notifier)
                                .setSearchQuery('');
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  isDense: true,
                  counter: const SizedBox.shrink(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    ),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface.withValues(alpha: 0.5),
                ),
                style: theme.textTheme.bodySmall,
                onChanged: (query) {
                  ref.read(takFilterProvider.notifier).setSearchQuery(query);
                  setState(() {}); // Rebuild for suffix icon
                },
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildAffiliationChip(
    BuildContext context,
    CotAffiliation affiliation,
    bool isActive,
  ) {
    final color = affiliation.color;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isActive,
        label: Text(affiliation.label),
        labelStyle: TextStyle(
          fontSize: 12,
          color: isActive ? Colors.white : color,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
        ),
        avatar: isActive
            ? null
            : Icon(Icons.shield_outlined, size: 14, color: color),
        selectedColor: color.withValues(alpha: 0.8),
        backgroundColor: color.withValues(alpha: 0.1),
        side: BorderSide(color: color.withValues(alpha: isActive ? 0.0 : 0.4)),
        showCheckmark: false,
        onSelected: (_) =>
            ref.read(takFilterProvider.notifier).toggleAffiliation(affiliation),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildStaleModeChip(BuildContext context, TakStaleMode mode) {
    final theme = Theme.of(context);
    final label = switch (mode) {
      TakStaleMode.all => 'All',
      TakStaleMode.activeOnly => 'Active',
      TakStaleMode.staleOnly => 'Stale',
    };
    final icon = switch (mode) {
      TakStaleMode.all => Icons.filter_list,
      TakStaleMode.activeOnly => Icons.timer,
      TakStaleMode.staleOnly => Icons.timer_off,
    };

    return ActionChip(
      avatar: Icon(icon, size: 16, color: theme.colorScheme.onSurface),
      label: Text(label),
      labelStyle: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      onPressed: () => ref.read(takFilterProvider.notifier).cycleStaleMode(),
      visualDensity: VisualDensity.compact,
    );
  }

  /// All affiliations shown as filter chips.
  static const _primaryAffiliations = [
    CotAffiliation.friendly,
    CotAffiliation.hostile,
    CotAffiliation.neutral,
    CotAffiliation.unknown,
    CotAffiliation.assumedFriend,
    CotAffiliation.suspect,
    CotAffiliation.pending,
  ];
}
