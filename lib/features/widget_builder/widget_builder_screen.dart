import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'models/widget_schema.dart';
import 'models/grid_widget_schema.dart';
import 'storage/widget_storage_service.dart';
import 'storage/grid_widget_storage_service.dart';
import 'editor/simple_widget_builder.dart';
import 'editor/grid_widget_builder.dart';
import 'marketplace/widget_marketplace_screen.dart';
import 'marketplace/widget_marketplace_service.dart';
import 'renderer/widget_renderer.dart';
import 'renderer/grid_widget_renderer.dart';
import '../../core/theme.dart';
import '../../providers/auth_providers.dart';
import '../../utils/snackbar.dart';
import '../dashboard/models/dashboard_widget_config.dart';
import '../dashboard/providers/dashboard_providers.dart';

/// Main widget builder screen - list and manage custom widgets
class WidgetBuilderScreen extends ConsumerStatefulWidget {
  const WidgetBuilderScreen({super.key});

  @override
  ConsumerState<WidgetBuilderScreen> createState() =>
      _WidgetBuilderScreenState();
}

class _WidgetBuilderScreenState extends ConsumerState<WidgetBuilderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _storageService = WidgetStorageService();
  final _gridStorageService = GridWidgetStorageService();
  List<WidgetSchema> _myWidgets = [];
  List<GridWidgetSchema> _myGridWidgets = [];
  List<GridWidgetSchema> _gridTemplates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadWidgets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWidgets() async {
    setState(() => _isLoading = true);

    try {
      await _storageService.init();
      await _gridStorageService.init();
      final widgets = await _storageService.getWidgets();
      final gridWidgets = await _gridStorageService.getWidgets();

      setState(() {
        _myWidgets = widgets;
        _myGridWidgets = gridWidgets;
        _gridTemplates = GridWidgetTemplates.all();
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
          'Widget Builder',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: context.accentColor),
            onPressed: _createNewWidget,
            tooltip: 'Create Widget',
          ),
          IconButton(
            icon: Icon(Icons.store, color: context.accentColor),
            onPressed: _openMarketplace,
            tooltip: 'Marketplace',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: context.accentColor,
          labelColor: context.accentColor,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'My Widgets'),
            Tab(text: 'Templates'),
            Tab(text: 'Installed'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMyWidgetsTab(),
                _buildTemplatesTab(),
                _buildInstalledTab(),
              ],
            ),
    );
  }

  Widget _buildMyWidgetsTab() {
    // Only show grid widgets (legacy widgets are hidden)
    if (_myGridWidgets.isEmpty) {
      return _buildEmptyState(
        icon: Icons.widgets_outlined,
        title: 'No Custom Widgets',
        subtitle: 'Create your first custom widget or use a template',
        action: TextButton.icon(
          onPressed: _createNewWidget,
          icon: Icon(Icons.add, color: context.accentColor),
          label: Text(
            'Create Widget',
            style: TextStyle(color: context.accentColor),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadWidgets,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myGridWidgets.length,
        itemBuilder: (context, index) {
          return _buildGridWidgetCard(_myGridWidgets[index], isTemplate: false);
        },
      ),
    );
  }

  Widget _buildTemplatesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _gridTemplates.length,
      itemBuilder: (context, index) {
        return _buildGridWidgetCard(_gridTemplates[index], isTemplate: true);
      },
    );
  }

  Widget _buildInstalledTab() {
    return FutureBuilder<List<String>>(
      future: _storageService.getInstalledMarketplaceIds(),
      builder: (context, snapshot) {
        final installedIds = snapshot.data ?? [];
        final installed = _myWidgets
            .where((w) => installedIds.contains(w.id))
            .toList();

        if (installed.isEmpty) {
          return _buildEmptyState(
            icon: Icons.download_outlined,
            title: 'No Installed Widgets',
            subtitle: 'Browse the marketplace to discover community widgets',
            action: TextButton.icon(
              onPressed: _openMarketplace,
              icon: Icon(Icons.store, color: context.accentColor),
              label: Text(
                'Open Marketplace',
                style: TextStyle(color: context.accentColor),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: installed.length,
          itemBuilder: (context, index) {
            return _buildWidgetCard(installed[index], isTemplate: false);
          },
        );
      },
    );
  }

  Widget _buildWidgetCard(WidgetSchema schema, {required bool isTemplate}) {
    // Check if this widget is already on the dashboard
    final dashboardWidgets = ref.watch(dashboardWidgetsProvider);
    final isOnDashboard = dashboardWidgets.any(
      (w) => w.schemaId == schema.id && w.isVisible,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Widget preview with placeholder data
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: SizedBox(
              height: 100,
              child: WidgetRenderer(
                schema: schema,
                node: null,
                allNodes: null,
                accentColor: context.accentColor,
                usePlaceholderData: true,
              ),
            ),
          ),
          // Info section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schema.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (schema.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          schema.description!,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
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
                  FilledButton(
                    onPressed: () => _useTemplate(schema),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.accentColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Use'),
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
                            Text(
                              'Export',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'submit_marketplace',
                        child: Row(
                          children: [
                            Icon(
                              Icons.cloud_upload,
                              size: 18,
                              color: Colors.white,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Submit to Marketplace',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete,
                              size: 18,
                              color: AppTheme.errorRed,
                            ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildGridWidgetCard(
    GridWidgetSchema schema, {
    required bool isTemplate,
  }) {
    // Check if this widget is already on the dashboard
    final dashboardWidgets = ref.watch(dashboardWidgetsProvider);
    final isOnDashboard = dashboardWidgets.any(
      (w) => w.schemaId == schema.id && w.isVisible,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Widget preview with placeholder data
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: SizedBox(
              height: 100,
              child: GridWidgetRenderer(
                schema: schema,
                node: null,
                allNodes: null,
                accentColor: context.accentColor,
                usePlaceholderData: true,
              ),
            ),
          ),
          // Info section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            schema.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.accentColor.withAlpha(30),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              schema.size.label.toUpperCase(),
                              style: TextStyle(
                                color: context.accentColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (schema.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          schema.description!,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
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
                  FilledButton(
                    onPressed: () => _useGridTemplate(schema),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.accentColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Use'),
                  )
                else
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: AppTheme.textSecondary),
                    color: AppTheme.darkCard,
                    onSelected: (action) =>
                        _handleGridAction(action, schema, isOnDashboard),
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
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete,
                              size: 18,
                              color: AppTheme.errorRed,
                            ),
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
          ),
        ],
      ),
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
    final result = await Navigator.push<GridWidgetSchema>(
      context,
      MaterialPageRoute(
        builder: (context) => GridWidgetBuilder(
          onSave: (schema) async {
            await _gridStorageService.saveWidget(schema);
          },
        ),
      ),
    );

    if (result != null) {
      await _loadWidgets();
    }
  }

  void _editGridWidget(GridWidgetSchema schema) async {
    final result = await Navigator.push<GridWidgetSchema>(
      context,
      MaterialPageRoute(
        builder: (context) => GridWidgetBuilder(
          initialSchema: schema,
          onSave: (updated) async {
            await _gridStorageService.saveWidget(updated);
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
        builder: (context) => SimpleWidgetBuilder(
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
        builder: (context) => SimpleWidgetBuilder(
          initialSchema: copy,
          onSave: (schema) async {
            await _storageService.saveWidget(schema);
          },
        ),
      ),
    );

    if (result != null) {
      await _loadWidgets();
      _tabController.animateTo(0); // Switch to My Widgets tab
    }
  }

  void _useGridTemplate(GridWidgetSchema template) async {
    // Create a copy of the template
    final copy = template.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${template.name} (Copy)',
    );

    final result = await Navigator.push<GridWidgetSchema>(
      context,
      MaterialPageRoute(
        builder: (context) => GridWidgetBuilder(
          initialSchema: copy,
          onSave: (schema) async {
            await _gridStorageService.saveWidget(schema);
          },
        ),
      ),
    );

    if (result != null) {
      await _loadWidgets();
      _tabController.animateTo(0); // Switch to My Widgets tab
    }
  }

  void _handleGridAction(
    String action,
    GridWidgetSchema schema,
    bool isOnDashboard,
  ) async {
    switch (action) {
      case 'add_to_dashboard':
        _addGridToDashboard(schema);
        break;
      case 'remove_from_dashboard':
        _removeGridFromDashboard(schema);
        break;
      case 'edit':
        _editGridWidget(schema);
        break;
      case 'duplicate':
        await _gridStorageService.duplicateWidget(schema.id);
        await _loadWidgets();
        break;
      case 'delete':
        final confirm = await _showDeleteConfirmation();
        if (confirm) {
          await _gridStorageService.deleteWidget(schema.id);
          await _loadWidgets();
        }
        break;
    }
  }

  void _addGridToDashboard(GridWidgetSchema schema) {
    final config = DashboardWidgetConfig(
      id: 'grid_${DateTime.now().millisecondsSinceEpoch}',
      type: DashboardWidgetType.custom,
      schemaId: schema.id,
    );

    ref.read(dashboardWidgetsProvider.notifier).addCustomWidget(config);

    if (mounted) {
      showSuccessSnackBar(context, '${schema.name} added to Dashboard');
    }
  }

  void _removeGridFromDashboard(GridWidgetSchema schema) {
    final dashboardNotifier = ref.read(dashboardWidgetsProvider.notifier);
    final widgets = ref.read(dashboardWidgetsProvider);
    final widget = widgets.cast<DashboardWidgetConfig?>().firstWhere(
      (w) => w?.schemaId == schema.id,
      orElse: () => null,
    );
    if (widget != null) {
      dashboardNotifier.removeWidget(widget.id);
      showSuccessSnackBar(context, 'Removed from dashboard');
    }
  }

  Future<bool> _showDeleteConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.darkCard,
            title: const Text(
              'Delete Widget',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to delete this widget? This cannot be undone.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.errorRed,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
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
      case 'submit_marketplace':
        _submitToMarketplace(schema);
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

    if (mounted) {
      showSuccessSnackBar(context, '${schema.name} added to Dashboard');
    }
  }

  void _removeFromDashboard(WidgetSchema schema) {
    final dashboardWidgets = ref.read(dashboardWidgetsProvider);
    final widgetToRemove = dashboardWidgets.firstWhere(
      (w) => w.schemaId == schema.id && w.isVisible,
      orElse: () => throw StateError('Widget not found on dashboard'),
    );

    ref.read(dashboardWidgetsProvider.notifier).removeWidget(widgetToRemove.id);

    if (mounted) {
      showInfoSnackBar(context, '${schema.name} removed from Dashboard');
    }
  }

  void _submitToMarketplace(WidgetSchema schema) {
    // Show confirmation dialog with category selection
    String selectedCategory = 'general';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.darkCard,
          title: const Text(
            'Submit to Marketplace',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share "${schema.name}" with the community?',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              Text(
                'Category',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                dropdownColor: AppTheme.darkCard,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.darkBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'status',
                    child: Text(
                      'Status',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'sensors',
                    child: Text(
                      'Sensors',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'connectivity',
                    child: Text(
                      'Connectivity',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'navigation',
                    child: Text(
                      'Navigation',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'network',
                    child: Text(
                      'Network',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'messaging',
                    child: Text(
                      'Messaging',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'general',
                    child: Text(
                      'General',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setDialogState(() => selectedCategory = value ?? 'general');
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _doSubmitToMarketplace(schema, selectedCategory);
              },
              child: Text(
                'Submit',
                style: TextStyle(color: this.context.accentColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doSubmitToMarketplace(
    WidgetSchema schema,
    String category,
  ) async {
    // Get the Firebase auth token
    final authService = ref.read(authServiceProvider);

    // If user is not signed in, sign in anonymously
    if (!authService.isSignedIn) {
      try {
        await authService.signInAnonymously();
      } catch (e) {
        if (mounted) {
          showErrorSnackBar(context, 'Failed to authenticate: $e');
        }
        return;
      }
    }

    final authToken = await authService.getIdToken();
    if (authToken == null) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to get authentication token');
      }
      return;
    }

    if (!mounted) return;

    try {
      showLoadingSnackBar(context, 'Submitting ${schema.name}...');

      final marketplaceService = WidgetMarketplaceService();

      // Create a schema with the selected category
      await marketplaceService.uploadWidget(schema, authToken);

      if (mounted) {
        showSuccessSnackBar(
          context,
          '${schema.name} submitted! It will appear after review.',
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to submit: $e');
      }
    }
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

  void _openMarketplace() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WidgetMarketplaceScreen()),
    ).then((_) => _loadWidgets());
  }
}
