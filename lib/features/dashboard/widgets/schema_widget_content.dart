import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../providers/app_providers.dart';
import '../../widget_builder/models/widget_schema.dart';
import '../../widget_builder/renderer/widget_renderer.dart';
import '../../widget_builder/storage/widget_storage_service.dart';
import 'dashboard_widget.dart';

/// Content widget that renders a schema-based custom widget with live data
class SchemaWidgetContent extends ConsumerStatefulWidget {
  final String schemaId;

  const SchemaWidgetContent({super.key, required this.schemaId});

  @override
  ConsumerState<SchemaWidgetContent> createState() =>
      _SchemaWidgetContentState();
}

class _SchemaWidgetContentState extends ConsumerState<SchemaWidgetContent> {
  final _storageService = WidgetStorageService();
  WidgetSchema? _schema;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSchema();
  }

  Future<void> _loadSchema() async {
    try {
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_error != null || _schema == null) {
      return WidgetEmptyState(
        icon: Icons.error_outline,
        message: _error ?? 'Widget not found',
      );
    }

    // Get live node data from Riverpod
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;

    // Just render the widget content directly - no card wrapper
    return WidgetRenderer(
      schema: _schema!,
      node: myNode,
      allNodes: nodes,
      accentColor: context.accentColor,
      isPreview: false,
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
