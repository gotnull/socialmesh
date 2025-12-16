import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'models/widget_schema.dart';
import 'storage/widget_storage_service.dart';
import 'editor/widget_editor_screen.dart';
import 'wizard/widget_wizard_screen.dart';
import 'marketplace/widget_marketplace_screen.dart';
import 'renderer/widget_renderer.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../dashboard/models/dashboard_widget_config.dart';
import '../dashboard/providers/dashboard_providers.dart';

/// Main widget builder screen - list and manage custom widgets
class WidgetBuilderScreen extends ConsumerStatefulWidget {
  const WidgetBuilderScreen({super.key});

  @override
  ConsumerState<WidgetBuilderScreen> createState() =>
      _WidgetBuilderScreenState();
}

class _WidgetBuilderScreenState extends ConsumerState<WidgetBuilderScreen> {
  final _storageService = WidgetStorageService();
  List<WidgetSchema> _myWidgets = [];
  Set<String> _marketplaceIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWidgets();
  }

  Future<void> _loadWidgets() async {
    setState(() => _isLoading = true);

    try {
      await _storageService.init();
      final widgets = await _storageService.getWidgets();
      final installedIds = await _storageService.getInstalledMarketplaceIds();

      setState(() {
        _myWidgets = widgets;
        _marketplaceIds = installedIds.toSet();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'My Widgets',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createNewWidget,
            tooltip: 'Create Widget',
          ),
          IconButton(
            icon: Icon(Icons.store, color: context.accentColor),
            onPressed: _openMarketplace,
            tooltip: 'Marketplace',
          ),
        ],
      ),
      body: _isLoading ? const ScreenLoadingIndicator() : _buildWidgetList(),
    );
  }

  Widget _buildWidgetList() {
    if (_myWidgets.isEmpty) {
      return _buildEmptyState(
        icon: Icons.widgets_outlined,
        title: 'No Widgets Yet',
        subtitle: 'Create your own or browse the marketplace',
        action: TextButton.icon(
          onPressed: _openMarketplace,
          icon: Icon(Icons.store, color: context.accentColor),
          label: Text(
            'Browse Marketplace',
            style: TextStyle(color: context.accentColor),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadWidgets,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myWidgets.length,
        itemBuilder: (context, index) {
          final schema = _myWidgets[index];
          final isFromMarketplace = _marketplaceIds.contains(schema.id);
          return _buildWidgetCard(
            schema,
            isTemplate: false,
            isFromMarketplace: isFromMarketplace,
          );
        },
      ),
    );
  }

  Widget _buildWidgetCard(
    WidgetSchema schema, {
    required bool isTemplate,
    bool isFromMarketplace = false,
  }) {
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final node = myNodeNum != null ? nodes[myNodeNum] : null;

    // Check if this widget is already on the dashboard
    final dashboardWidgets = ref.watch(dashboardWidgetsProvider);
    final isOnDashboard = dashboardWidgets.any(
      (w) => w.schemaId == schema.id && w.isVisible,
    );

    // Height based on size - width is always full
    final previewHeight = switch (schema.size) {
      CustomWidgetSize.medium => 120.0,
      CustomWidgetSize.large => 180.0,
      CustomWidgetSize.custom => schema.customHeight ?? 120.0,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Widget preview - full width, variable height
        SizedBox(
          width: double.infinity,
          height: previewHeight,
          child: WidgetRenderer(
            schema: schema,
            node: node,
            allNodes: nodes,
            accentColor: context.accentColor,
            enableActions: false, // Only interactive on dashboard
          ),
        ),
        const SizedBox(height: 8),
        // Info section - no horizontal padding to match widget preview width
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          schema.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isFromMarketplace) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.store, size: 14, color: context.accentColor),
                      ],
                    ],
                  ),
                  if (schema.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      schema.description!,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Actions
            if (isTemplate)
              TextButton(
                onPressed: () => _useTemplate(schema),
                child: Text(
                  'Use',
                  style: TextStyle(
                    color: context.accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: AppTheme.textSecondary),
                color: AppTheme.darkCard,
                onSelected: (action) => _handleAction(action, schema),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: isOnDashboard
                        ? 'remove_from_dashboard'
                        : 'add_to_dashboard',
                    child: Row(
                      children: [
                        Icon(
                          isOnDashboard
                              ? Icons.dashboard_outlined
                              : Icons.dashboard_customize,
                          size: 18,
                          color: isOnDashboard
                              ? AppTheme.errorRed
                              : Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isOnDashboard
                              ? 'Remove from Dashboard'
                              : 'Add to Dashboard',
                          style: TextStyle(
                            color: isOnDashboard
                                ? AppTheme.errorRed
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Edit', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Row(
                      children: [
                        Icon(Icons.copy, size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Duplicate',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(Icons.share, size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Export', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: AppTheme.errorRed),
                        const SizedBox(width: 8),
                        Text(
                          'Delete',
                          style: TextStyle(color: AppTheme.errorRed),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: AppTheme.textTertiary),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 24), action],
        ],
      ),
    );
  }

  void _createNewWidget() async {
    final result = await Navigator.push<WidgetSchema>(
      context,
      MaterialPageRoute(
        builder: (context) => WidgetWizardScreen(
          onSave: (schema) async {
            await _storageService.saveWidget(schema);
          },
        ),
      ),
    );

    if (result != null) {
      await _loadWidgets();
    }
  }

  void _editWidget(WidgetSchema schema) async {
    final result = await Navigator.push<WidgetSchema>(
      context,
      MaterialPageRoute(
        builder: (context) => WidgetEditorScreen(
          initialSchema: schema,
          onSave: (updated) async {
            await _storageService.saveWidget(updated);
          },
        ),
      ),
    );

    if (result != null) {
      await _loadWidgets();
    }
  }

  void _useTemplate(WidgetSchema template) async {
    // Create a copy of the template
    final copy = WidgetSchema(
      name: '${template.name} (Copy)',
      description: template.description,
      size: template.size,
      root: template.root,
      tags: template.tags,
    );

    final result = await Navigator.push<WidgetSchema>(
      context,
      MaterialPageRoute(
        builder: (context) => WidgetEditorScreen(
          initialSchema: copy,
          onSave: (schema) async {
            await _storageService.saveWidget(schema);
          },
        ),
      ),
    );

    if (result != null) {
      await _loadWidgets();
    }
  }

  void _handleAction(String action, WidgetSchema schema) async {
    switch (action) {
      case 'add_to_dashboard':
        _addToDashboard(schema);
        break;
      case 'remove_from_dashboard':
        _removeFromDashboard(schema);
        break;
      case 'edit':
        _editWidget(schema);
        break;
      case 'duplicate':
        await _storageService.duplicateWidget(schema.id);
        await _loadWidgets();
        break;
      case 'export':
        final json = await _storageService.exportWidget(schema.id);
        await Share.share(json, subject: '${schema.name} Widget');
        break;
      case 'delete':
        _confirmDelete(schema);
        break;
    }
  }

  void _addToDashboard(WidgetSchema schema) {
    final config = DashboardWidgetConfig(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      type: DashboardWidgetType.custom,
      schemaId: schema.id,
    );

    ref.read(dashboardWidgetsProvider.notifier).addCustomWidget(config);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${schema.name} added to Dashboard'),
        backgroundColor: AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _removeFromDashboard(WidgetSchema schema) {
    final dashboardWidgets = ref.read(dashboardWidgetsProvider);
    final widgetToRemove = dashboardWidgets.firstWhere(
      (w) => w.schemaId == schema.id && w.isVisible,
      orElse: () => throw StateError('Widget not found on dashboard'),
    );

    ref.read(dashboardWidgetsProvider.notifier).removeWidget(widgetToRemove.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${schema.name} removed from Dashboard'),
        backgroundColor: AppTheme.textSecondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _confirmDelete(WidgetSchema schema) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text(
          'Delete Widget?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${schema.name}"? This cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _storageService.deleteWidget(schema.id);
              await _loadWidgets();
            },
            child: Text('Delete', style: TextStyle(color: AppTheme.errorRed)),
          ),
        ],
      ),
    );
  }

  void _openMarketplace() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const WidgetMarketplaceScreen()),
    );
    await _loadWidgets();
  }
}
