import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/splash_mesh_provider.dart';
import '../../widget_builder/models/widget_schema.dart';
import '../../widget_builder/models/grid_widget_schema.dart';
import '../../widget_builder/renderer/widget_renderer.dart';
import '../../widget_builder/renderer/grid_widget_renderer.dart';
import '../../widget_builder/storage/widget_storage_service.dart';
import '../../widget_builder/storage/grid_widget_storage_service.dart';
import '../../map/map_screen.dart';
import 'dashboard_widget.dart';

/// Content widget that renders a schema-based custom widget with live data
/// Supports both legacy WidgetSchema and new GridWidgetSchema
class SchemaWidgetContent extends ConsumerStatefulWidget {
  final String schemaId;

  const SchemaWidgetContent({super.key, required this.schemaId});

  @override
  ConsumerState<SchemaWidgetContent> createState() =>
      _SchemaWidgetContentState();
}

class _SchemaWidgetContentState extends ConsumerState<SchemaWidgetContent> {
  final _storageService = WidgetStorageService();
  final _gridStorageService = GridWidgetStorageService();
  WidgetSchema? _schema;
  GridWidgetSchema? _gridSchema;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSchema();
  }

  Future<void> _loadSchema() async {
    try {
      // Try loading from grid widget storage first (new system)
      await _gridStorageService.init();
      final gridSchema = await _gridStorageService.getWidget(widget.schemaId);
      if (gridSchema != null) {
        if (mounted) {
          setState(() {
            _gridSchema = gridSchema;
            _isLoading = false;
          });
        }
        return;
      }

      // Fall back to legacy widget storage
      await _storageService.init();
      final schema = await _storageService.getWidget(widget.schemaId);
      if (mounted) {
        setState(() {
          _schema = schema;
          _isLoading = false;
          _error = schema == null ? 'Widget not found' : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load widget';
        });
      }
    }
  }

  /// Get the height constraint based on widget size
  double _getWidgetHeight(CustomWidgetSize size) {
    switch (size) {
      case CustomWidgetSize.small:
        return 120; // Compact for dashboard
      case CustomWidgetSize.medium:
        return 160;
      case CustomWidgetSize.large:
        return 280;
      case CustomWidgetSize.custom:
        return 200; // Default height for custom size
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 160,
        child: Center(child: MeshLoadingIndicator(size: 20)),
      );
    }

    // Handle grid widgets (new system)
    if (_gridSchema != null) {
      return _buildGridWidget(context);
    }

    if (_error != null || _schema == null) {
      return const SizedBox(
        height: 120,
        child: WidgetEmptyState(
          icon: Icons.error_outline,
          message: 'Widget not found',
        ),
      );
    }

    // Get live node data from Riverpod
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;

    // Get live signal data from protocol streams
    final rssiAsync = ref.watch(currentRssiProvider);
    final snrAsync = ref.watch(currentSnrProvider);
    final channelUtilAsync = ref.watch(currentChannelUtilProvider);

    final height = _getWidgetHeight(_schema!.size);

    // Build the base widget content
    Widget content = SizedBox(
      height: height,
      child: WidgetRenderer(
        schema: _schema!,
        node: myNode,
        allNodes: nodes,
        accentColor: context.accentColor,
        isPreview: false,
        deviceRssi: rssiAsync.value,
        deviceSnr: snrAsync.value,
        deviceChannelUtil: channelUtilAsync.value,
      ),
    );

    // Add tap-to-navigate for GPS widgets (detect by tags or name)
    if (_isGpsWidget(_schema!)) {
      content = GestureDetector(
        onTap: () => _navigateToMap(context, myNodeNum),
        child: content,
      );
    }

    return content;
  }

  /// Build a grid widget with live data
  Widget _buildGridWidget(BuildContext context) {
    // Get live node data from Riverpod
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;

    final height = _getGridWidgetHeight(_gridSchema!.size);

    Widget content = SizedBox(
      height: height,
      child: GridWidgetRenderer(
        schema: _gridSchema!,
        node: myNode,
        allNodes: nodes,
        accentColor: context.accentColor,
      ),
    );

    // Add tap-to-navigate for GPS widgets
    if (_isGridGpsWidget(_gridSchema!)) {
      content = GestureDetector(
        onTap: () => _navigateToMap(context, myNodeNum),
        child: content,
      );
    }

    return content;
  }

  /// Get the height for a grid widget based on its size
  double _getGridWidgetHeight(GridWidgetSize size) {
    switch (size) {
      case GridWidgetSize.small:
        return 120;
      case GridWidgetSize.medium:
        return 120;
      case GridWidgetSize.large:
        return 180;
    }
  }

  /// Check if a grid widget is a GPS/location widget
  bool _isGridGpsWidget(GridWidgetSchema schema) {
    final lowerName = schema.name.toLowerCase();
    return lowerName.contains('gps') ||
        lowerName.contains('position') ||
        lowerName.contains('location');
  }

  /// Check if widget is a GPS/location widget based on tags or name
  bool _isGpsWidget(WidgetSchema schema) {
    final lowerName = schema.name.toLowerCase();
    final tags = schema.tags.map((t) => t.toLowerCase()).toSet();

    return lowerName.contains('gps') ||
        lowerName.contains('position') ||
        lowerName.contains('location') ||
        tags.contains('gps') ||
        tags.contains('location') ||
        tags.contains('position') ||
        tags.contains('coordinates');
  }

  /// Navigate to the mesh map, optionally centering on the current node
  void _navigateToMap(BuildContext context, int? nodeNum) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MapScreen(initialNodeNum: nodeNum)),
    );
  }
}

/// Provider for custom widgets stored in widget builder
final customWidgetsProvider = FutureProvider<List<WidgetSchema>>((ref) async {
  final storageService = WidgetStorageService();
  await storageService.init();
  return storageService.getWidgets();
});

/// Provider for a specific custom widget
final customWidgetProvider = FutureProvider.family<WidgetSchema?, String>((
  ref,
  schemaId,
) async {
  final storageService = WidgetStorageService();
  await storageService.init();
  return storageService.getWidget(schemaId);
});
