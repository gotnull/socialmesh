import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/world_mesh_node.dart';
import '../../models/presence_confidence.dart';
import '../../providers/node_favorites_provider.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../utils/presence_utils.dart';
import 'node_analytics_screen.dart';
import 'node_comparison_screen.dart';
import 'services/node_favorites_service.dart';

/// A favorite item combining metadata with optional live node data.
class _FavoriteItem {
  final FavoriteNodeMetadata metadata;
  final WorldMeshNode? liveNode;

  _FavoriteItem({required this.metadata, this.liveNode});

  String get displayName =>
      liveNode?.displayName ??
      (metadata.longName.isNotEmpty
          ? metadata.longName
          : metadata.shortName.isNotEmpty
          ? metadata.shortName
          : '!${metadata.nodeId}');

  PresenceConfidence get presence =>
      liveNode?.presenceConfidence ?? PresenceConfidence.unknown;
  bool get hasLiveData => liveNode != null;
}

/// Screen displaying all favorited mesh nodes with quick access.
class FavoritesScreen extends ConsumerStatefulWidget {
  final Map<int, WorldMeshNode>? allNodes;
  final void Function(WorldMeshNode node)? onShowOnMap;

  const FavoritesScreen({super.key, this.allNodes, this.onShowOnMap});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  bool _isCompareMode = false;
  _FavoriteItem? _selectedForCompare;

  /// Build favorite items from provider state, merging with live node data
  List<_FavoriteItem> _buildFavoriteItems(NodeFavoritesData data) {
    final items = <_FavoriteItem>[];
    for (final meta in data.favorites) {
      final nodeNum = int.tryParse(meta.nodeId, radix: 16);
      WorldMeshNode? freshNode;
      if (nodeNum != null && widget.allNodes != null) {
        freshNode = widget.allNodes![nodeNum];
      }
      items.add(_FavoriteItem(metadata: meta, liveNode: freshNode));
    }
    return items;
  }

  Future<void> _removeFavorite(_FavoriteItem item) async {
    await ref
        .read(nodeFavoritesProvider.notifier)
        .removeFavorite(item.metadata.nodeId);
    HapticFeedback.mediumImpact();
  }

  Future<void> _confirmRemoveFavorite(_FavoriteItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.card,
        title: Text(
          'Remove Favorite?',
          style: TextStyle(color: context.textPrimary),
        ),
        content: Text(
          'Remove ${item.displayName} from your favorites?',
          style: TextStyle(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _removeFavorite(item);
    }
  }

  void _openNodeAnalytics(_FavoriteItem item) {
    final node = item.liveNode;
    if (node == null) {
      showWarningSnackBar(
        context,
        'Node not currently in mesh. Check back later.',
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => NodeAnalyticsScreen(
          node: node,
          onShowOnMap: widget.onShowOnMap != null
              ? () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                  widget.onShowOnMap!(node);
                }
              : null,
        ),
      ),
    );
  }

  void _toggleCompareMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _isCompareMode = !_isCompareMode;
      _selectedForCompare = null;
    });
  }

  void _handleItemTap(_FavoriteItem item) {
    if (!_isCompareMode) {
      _openNodeAnalytics(item);
      return;
    }

    if (item.liveNode == null) {
      showWarningSnackBar(context, 'Cannot compare nodes not in mesh');
      return;
    }

    if (_selectedForCompare == null) {
      // First selection
      HapticFeedback.selectionClick();
      setState(() => _selectedForCompare = item);
    } else if (_selectedForCompare!.metadata.nodeId == item.metadata.nodeId) {
      // Deselect
      HapticFeedback.selectionClick();
      setState(() => _selectedForCompare = null);
    } else {
      // Second selection - open comparison
      HapticFeedback.mediumImpact();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => NodeComparisonScreen(
            nodeA: _selectedForCompare!.liveNode!,
            nodeB: item.liveNode!,
          ),
        ),
      ).then((_) {
        setState(() {
          _isCompareMode = false;
          _selectedForCompare = null;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final favoritesAsync = ref.watch(nodeFavoritesProvider);

    return favoritesAsync.when(
      loading: () => Scaffold(
        backgroundColor: context.background,
        appBar: AppBar(
          backgroundColor: context.background,
          title: Text(
            'Favorite Nodes',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
        ),
        body: const ScreenLoadingIndicator(),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: context.background,
        appBar: AppBar(
          backgroundColor: context.background,
          title: Text(
            'Favorite Nodes',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppTheme.errorRed,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading favorites',
                style: TextStyle(color: context.textPrimary),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    ref.read(nodeFavoritesProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (favoritesData) {
        final favorites = _buildFavoriteItems(favoritesData);
        final hasEnoughForCompare =
            favorites.where((f) => f.hasLiveData).length >= 2;

        return Scaffold(
          backgroundColor: context.background,
          appBar: AppBar(
            backgroundColor: context.background,
            title: Text(
              _isCompareMode
                  ? (_selectedForCompare == null
                        ? 'Select first node'
                        : 'Select second node')
                  : 'Favorite Nodes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            actions: [
              // Compare toggle
              if (favorites.length >= 2 && hasEnoughForCompare)
                IconButton(
                  icon: Icon(
                    _isCompareMode ? Icons.close : Icons.compare_arrows,
                    color: _isCompareMode ? AccentColors.green : null,
                  ),
                  tooltip: _isCompareMode ? 'Cancel compare' : 'Compare nodes',
                  onPressed: _toggleCompareMode,
                ),
              if (favorites.isNotEmpty && !_isCompareMode)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${favorites.length}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.accentColor,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: favorites.isEmpty
              ? _buildEmptyState()
              : _buildFavoritesList(favorites),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: context.card,
                shape: BoxShape.circle,
                border: Border.all(color: context.border),
              ),
              child: Icon(
                Icons.star_border,
                size: 40,
                color: context.textTertiary,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No Favorites Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the star icon on any node to add it to your favorites for quick access.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesList(List<_FavoriteItem> favorites) {
    return RefreshIndicator(
      onRefresh: () => ref.read(nodeFavoritesProvider.notifier).refresh(),
      color: context.accentColor,
      backgroundColor: context.card,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: favorites.length,
        itemBuilder: (context, index) {
          final item = favorites[index];
          return _buildDismissibleCard(item);
        },
      ),
    );
  }

  Widget _buildDismissibleCard(_FavoriteItem item) {
    const borderRadius = BorderRadius.all(Radius.circular(12));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Dismissible(
          key: Key(item.metadata.nodeId),
          direction: DismissDirection.endToStart,
          background: Container(
            decoration: BoxDecoration(color: AppTheme.errorRed),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete, color: Colors.white, size: 24),
                SizedBox(width: 8),
                Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: context.card,
                    title: Text(
                      'Remove Favorite?',
                      style: TextStyle(color: context.textPrimary),
                    ),
                    content: Text(
                      'Remove ${item.displayName} from your favorites?',
                      style: TextStyle(color: context.textSecondary),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.errorRed,
                        ),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                ) ??
                false;
          },
          onDismissed: (_) => _removeFavorite(item),
          child: _buildFavoriteCard(item),
        ),
      ),
    );
  }

  Widget _buildFavoriteCard(_FavoriteItem item) {
    final lastSeenAge = item.liveNode?.lastSeen != null
        ? DateTime.now().difference(item.liveNode!.lastSeen!)
        : null;
    final statusColor = _presenceColor(context, item.presence);
    final statusText = item.hasLiveData
        ? presenceStatusText(item.presence, lastSeenAge)
        : 'Not in mesh';

    final isSelected =
        _isCompareMode &&
        _selectedForCompare?.metadata.nodeId == item.metadata.nodeId;

    const borderRadius = BorderRadius.all(Radius.circular(12));

    return Material(
      color: context.card,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () => _handleItemTap(item),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(
              color: isSelected
                  ? AccentColors.green
                  : (_isCompareMode && !item.hasLiveData
                        ? context.textTertiary.withValues(alpha: 0.3)
                        : context.border),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Selection checkbox in compare mode
              if (_isCompareMode) ...[
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: item.hasLiveData
                          ? (isSelected
                                ? AccentColors.green
                                : context.textTertiary)
                          : context.textTertiary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    color: isSelected ? AccentColors.green : Colors.transparent,
                  ),
                  child: isSelected
                      ? Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
              ],
              // Status indicator
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: statusColor, width: 2),
                ),
                child: Center(
                  child: Icon(
                    item.hasLiveData
                        ? _presenceIcon(item.presence)
                        : Icons.cloud_off,
                    color: statusColor,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Node info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: TextStyle(fontSize: 12, color: statusColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '!${item.metadata.nodeId}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textTertiary,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                        if (item.metadata.role.isNotEmpty) ...[
                          Text(
                            ' • ',
                            style: TextStyle(color: context.textTertiary),
                          ),
                          Expanded(
                            child: Text(
                              item.metadata.role,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textTertiary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (item.liveNode?.batteryLevel != null) ...[
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            _getBatteryIcon(item.liveNode!.batteryLevel!),
                            size: 14,
                            color: _getBatteryColor(
                              item.liveNode!.batteryLevel!,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.liveNode!.batteryLevel! > 100
                                ? 'Charging'
                                : '${item.liveNode!.batteryLevel}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: _getBatteryColor(
                                item.liveNode!.batteryLevel!,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Actions
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Delete button - obvious red trash icon
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppTheme.errorRed,
                      size: 22,
                    ),
                    onPressed: () => _confirmRemoveFavorite(item),
                    tooltip: 'Remove from favorites',
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.chevron_right,
                      color: item.hasLiveData
                          ? context.textTertiary
                          : context.textTertiary.withValues(alpha: 0.3),
                      size: 22,
                    ),
                    onPressed: () => _openNodeAnalytics(item),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _presenceColor(BuildContext context, PresenceConfidence confidence) {
    switch (confidence) {
      case PresenceConfidence.active:
        return AccentColors.green;
      case PresenceConfidence.fading:
        return AppTheme.warningYellow;
      case PresenceConfidence.stale:
        return context.textSecondary;
      case PresenceConfidence.unknown:
        return context.textTertiary;
    }
  }

  IconData _presenceIcon(PresenceConfidence confidence) {
    switch (confidence) {
      case PresenceConfidence.active:
        return Icons.wifi;
      case PresenceConfidence.fading:
        return Icons.wifi_1_bar;
      case PresenceConfidence.stale:
        return Icons.wifi_off;
      case PresenceConfidence.unknown:
        return Icons.help_outline;
    }
  }

  IconData _getBatteryIcon(int level) {
    if (level > 100) return Icons.battery_charging_full;
    if (level > 80) return Icons.battery_full;
    if (level > 60) return Icons.battery_5_bar;
    if (level > 40) return Icons.battery_4_bar;
    if (level > 20) return Icons.battery_2_bar;
    return Icons.battery_alert;
  }

  Color _getBatteryColor(int level) {
    if (level > 100) return AccentColors.green;
    if (level > 20) return context.textSecondary;
    return AppTheme.errorRed;
  }
}
