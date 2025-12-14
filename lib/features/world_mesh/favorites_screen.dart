import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../models/world_mesh_node.dart';
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

  bool get isOnline => liveNode?.isOnline ?? false;
  bool get isIdle => liveNode?.isIdle ?? false;
  bool get hasLiveData => liveNode != null;
}

/// Screen displaying all favorited mesh nodes with quick access.
class FavoritesScreen extends StatefulWidget {
  final Map<int, WorldMeshNode>? allNodes;
  final void Function(WorldMeshNode node)? onShowOnMap;

  const FavoritesScreen({super.key, this.allNodes, this.onShowOnMap});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final NodeFavoritesService _favoritesService = NodeFavoritesService();
  List<_FavoriteItem> _favorites = [];
  bool _isLoading = true;
  bool _isCompareMode = false;
  _FavoriteItem? _selectedForCompare;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);

    final savedMeta = await _favoritesService.getFavorites();

    // Try to get fresh data from allNodes if available
    final List<_FavoriteItem> items = [];
    for (final meta in savedMeta) {
      // Parse nodeId hex back to int
      final nodeNum = int.tryParse(meta.nodeId, radix: 16);
      WorldMeshNode? freshNode;
      if (nodeNum != null && widget.allNodes != null) {
        freshNode = widget.allNodes![nodeNum];
      }
      items.add(_FavoriteItem(metadata: meta, liveNode: freshNode));
    }

    if (mounted) {
      setState(() {
        _favorites = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFavorite(_FavoriteItem item) async {
    await _favoritesService.removeFavorite(item.metadata.nodeId);
    HapticFeedback.mediumImpact();
    await _loadFavorites();
  }

  void _openNodeAnalytics(_FavoriteItem item) {
    final node = item.liveNode;
    if (node == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Node not currently in mesh. Check back later.'),
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot compare nodes not in mesh'),
        ),
      );
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
    final hasEnoughForCompare = _favorites.where((f) => f.hasLiveData).length >= 2;

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: Text(
          _isCompareMode
              ? (_selectedForCompare == null
                    ? 'Select first node'
                    : 'Select second node')
              : 'Favorite Nodes',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          // Compare toggle
          if (_favorites.length >= 2 && hasEnoughForCompare)
            IconButton(
              icon: Icon(
                _isCompareMode ? Icons.close : Icons.compare_arrows,
                color: _isCompareMode ? AccentColors.green : null,
              ),
              tooltip: _isCompareMode ? 'Cancel compare' : 'Compare nodes',
              onPressed: _toggleCompareMode,
            ),
          if (_favorites.isNotEmpty && !_isCompareMode)
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
                    '${_favorites.length}',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
          ? _buildEmptyState()
          : _buildFavoritesList(),
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
                color: AppTheme.darkCard,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: const Icon(
                Icons.star_border,
                size: 40,
                color: AppTheme.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Favorites Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the star icon on any node to add it to your favorites for quick access.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesList() {
    return RefreshIndicator(
      onRefresh: _loadFavorites,
      color: context.accentColor,
      backgroundColor: AppTheme.darkCard,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          final item = _favorites[index];
          return _buildFavoriteCard(item);
        },
      ),
    );
  }

  Widget _buildFavoriteCard(_FavoriteItem item) {
    final statusColor = item.isOnline
        ? AccentColors.green
        : (item.isIdle ? AppTheme.warningYellow : AppTheme.textTertiary);
    final statusText = item.hasLiveData
        ? (item.isOnline ? 'Online' : (item.isIdle ? 'Idle' : 'Offline'))
        : 'Not in mesh';

    final isSelected = _isCompareMode &&
        _selectedForCompare?.metadata.nodeId == item.metadata.nodeId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _handleItemTap(item),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AccentColors.green
                    : (_isCompareMode && !item.hasLiveData
                          ? AppTheme.textTertiary.withValues(alpha: 0.3)
                          : AppTheme.darkBorder),
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
                                  : AppTheme.textTertiary)
                            : AppTheme.textTertiary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      color: isSelected
                          ? AccentColors.green
                          : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          )
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
                          ? (item.isOnline
                                ? Icons.wifi
                                : (item.isIdle
                                      ? Icons.wifi_1_bar
                                      : Icons.wifi_off))
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
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
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
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textTertiary,
                              fontFamily: 'monospace',
                            ),
                          ),
                          if (item.metadata.role.isNotEmpty) ...[
                            const Text(
                              ' • ',
                              style: TextStyle(color: AppTheme.textTertiary),
                            ),
                            Expanded(
                              child: Text(
                                item.metadata.role,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textTertiary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (item.liveNode?.batteryLevel != null) ...[
                        const SizedBox(height: 6),
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
                    IconButton(
                      icon: const Icon(
                        Icons.star,
                        color: Color(0xFFFFD700),
                        size: 22,
                      ),
                      onPressed: () => _removeFavorite(item),
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
                            ? AppTheme.textTertiary
                            : AppTheme.textTertiary.withValues(alpha: 0.3),
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
      ),
    );
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
    if (level > 20) return AppTheme.textSecondary;
    return AppTheme.errorRed;
  }
}
