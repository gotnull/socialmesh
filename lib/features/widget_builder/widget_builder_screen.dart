import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'models/widget_schema.dart';
import 'storage/widget_storage_service.dart';
import 'wizard/widget_wizard_screen.dart';
import 'marketplace/widget_marketplace_screen.dart';
import 'marketplace/widget_marketplace_service.dart';
import 'marketplace/marketplace_providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/widget_preview_card.dart';
import '../../providers/auth_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/splash_mesh_provider.dart';
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

      // Check profile for installed widgets that might need restoration
      final profile = ref.read(userProfileProvider).value;
      if (profile != null && profile.installedWidgetIds.isNotEmpty) {
        final localWidgetIds = widgets.map((w) => w.id).toSet();
        final missingIds = profile.installedWidgetIds
            .where((id) => !localWidgetIds.contains(id))
            .toList();

        if (missingIds.isNotEmpty) {
          debugPrint(
            '[WidgetBuilder] Found ${missingIds.length} widgets to restore from cloud',
          );
          // Restore missing widgets from marketplace
          await _restoreMissingWidgets(missingIds);
          // Reload after restoration
          final updatedWidgets = await _storageService.getWidgets();
          final updatedInstalledIds = await _storageService
              .getInstalledMarketplaceIds();
          setState(() {
            _myWidgets = updatedWidgets;
            _marketplaceIds = updatedInstalledIds.toSet();
            _isLoading = false;
          });
          return;
        }
      }

      setState(() {
        _myWidgets = widgets;
        _marketplaceIds = installedIds.toSet();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[WidgetBuilder] Error loading widgets: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Restore widgets from marketplace that are in profile but not local storage
  Future<void> _restoreMissingWidgets(List<String> widgetIds) async {
    final service = ref.read(marketplaceServiceProvider);

    for (final id in widgetIds) {
      try {
        debugPrint('[WidgetBuilder] Restoring widget: $id');
        // Use previewWidget to NOT increment install count (user already owns this)
        final schema = await service.previewWidget(id);
        await _storageService.installMarketplaceWidget(schema);
        debugPrint('[WidgetBuilder] Restored widget: ${schema.name}');
      } catch (e) {
        debugPrint('[WidgetBuilder] Failed to restore widget $id: $e');
        // Continue with other widgets even if one fails
      }
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
        action: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: _createNewWidget,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Create Widget',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accentColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _openMarketplace,
              icon: Icon(Icons.store, color: context.accentColor),
              label: Text(
                'Browse Marketplace',
                style: TextStyle(color: context.accentColor),
              ),
            ),
          ],
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
    // Check if this widget is already on the dashboard
    final dashboardWidgets = ref.watch(dashboardWidgetsProvider);
    final isOnDashboard = dashboardWidgets.any(
      (w) => w.schemaId == schema.id && w.isVisible,
    );

    return WidgetPreviewCard(
      schema: schema,
      title: schema.name,
      subtitle: schema.description,
      titleLeading: isFromMarketplace
          ? Icon(Icons.store, size: 14, color: context.accentColor)
          : null,
      trailing: isTemplate
          ? TextButton(
              onPressed: () => _useTemplate(schema),
              child: Text(
                'Use',
                style: TextStyle(
                  color: context.accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : PopupMenuButton<String>(
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
                        color: isOnDashboard ? AppTheme.errorRed : Colors.white,
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
                      Text('Duplicate', style: TextStyle(color: Colors.white)),
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
                if (!isFromMarketplace)
                  PopupMenuItem(
                    value: 'submit_marketplace',
                    child: Row(
                      children: [
                        Icon(
                          Icons.upload_rounded,
                          size: 18,
                          color: context.accentColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Submit to Marketplace',
                          style: TextStyle(color: context.accentColor),
                        ),
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
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return SizedBox.expand(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 48,
                  color: context.accentColor.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
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
        ),
      ),
    );
  }

  void _createNewWidget() async {
    debugPrint('[WidgetBuilder] _createNewWidget called');

    final result = await Navigator.push<WidgetWizardResult>(
      context,
      MaterialPageRoute(
        builder: (context) => WidgetWizardScreen(
          onSave: (schema) async {
            debugPrint(
              '[WidgetBuilder] onSave callback - saving new widget: ${schema.id}',
            );
            await _storageService.saveWidget(schema);
            debugPrint('[WidgetBuilder] New widget saved successfully');
          },
        ),
      ),
    );

    debugPrint('[WidgetBuilder] Wizard returned, result: $result');

    // Always reload widgets after returning from wizard
    // The save happens inside the wizard, so we should reload regardless
    await _loadWidgets();
    debugPrint('[WidgetBuilder] Widgets reloaded');

    // Add to dashboard if requested
    if (result != null && result.addToDashboard) {
      debugPrint(
        '[WidgetBuilder] Adding widget to dashboard: ${result.schema.id}',
      );
      final widgetsNotifier = ref.read(dashboardWidgetsProvider.notifier);
      widgetsNotifier.addCustomWidget(
        DashboardWidgetConfig(
          id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
          type: DashboardWidgetType.custom,
          schemaId: result.schema.id,
          size: _mapSchemaSize(result.schema.size),
        ),
      );

      if (mounted) {
        showSuccessSnackBar(
          context,
          '${result.schema.name} added to dashboard',
        );
      }
    }
  }

  WidgetSize _mapSchemaSize(CustomWidgetSize schemaSize) {
    return switch (schemaSize) {
      CustomWidgetSize.medium => WidgetSize.medium,
      CustomWidgetSize.large => WidgetSize.large,
      CustomWidgetSize.custom => WidgetSize.medium, // Default custom to medium
    };
  }

  void _editWidget(WidgetSchema schema) async {
    debugPrint('[WidgetBuilder] _editWidget called for: ${schema.id}');

    final result = await Navigator.push<WidgetWizardResult>(
      context,
      MaterialPageRoute(
        builder: (context) => WidgetWizardScreen(
          initialSchema: schema,
          onSave: (updated) async {
            debugPrint(
              '[WidgetBuilder] onSave callback - saving widget: ${updated.id}',
            );
            await _storageService.saveWidget(updated);
            debugPrint('[WidgetBuilder] Widget saved successfully');
          },
        ),
      ),
    );

    debugPrint('[WidgetBuilder] Wizard returned, result: $result');

    // Always reload widgets after returning from wizard
    await _loadWidgets();
    debugPrint('[WidgetBuilder] Widgets reloaded');
  }

  void _useTemplate(WidgetSchema template) async {
    debugPrint('[WidgetBuilder] _useTemplate called for: ${template.name}');

    // Create a copy of the template
    final copy = WidgetSchema(
      name: '${template.name} (Copy)',
      description: template.description,
      size: template.size,
      root: template.root,
      tags: template.tags,
    );

    final result = await Navigator.push<WidgetWizardResult>(
      context,
      MaterialPageRoute(
        builder: (context) => WidgetWizardScreen(
          initialSchema: copy,
          onSave: (schema) async {
            debugPrint(
              '[WidgetBuilder] onSave callback - saving template copy: ${schema.id}',
            );
            await _storageService.saveWidget(schema);
            debugPrint('[WidgetBuilder] Template copy saved successfully');
          },
        ),
      ),
    );

    debugPrint('[WidgetBuilder] Template wizard returned, result: $result');

    // Always reload widgets after returning from wizard
    await _loadWidgets();
    debugPrint('[WidgetBuilder] Widgets reloaded');
  }

  void _handleAction(String action, WidgetSchema schema) async {
    debugPrint(
      '[WidgetBuilder] _handleAction: $action for widget: ${schema.id}',
    );

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
        debugPrint('[WidgetBuilder] Duplicating widget: ${schema.id}');
        await _storageService.duplicateWidget(schema.id);
        await _loadWidgets();
        debugPrint('[WidgetBuilder] Widget duplicated');
        break;
      case 'export':
        debugPrint('[WidgetBuilder] Exporting widget: ${schema.id}');
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

    showSuccessSnackBar(context, '${schema.name} added to Dashboard');
  }

  void _removeFromDashboard(WidgetSchema schema) {
    final dashboardWidgets = ref.read(dashboardWidgetsProvider);
    final widgetToRemove = dashboardWidgets.firstWhere(
      (w) => w.schemaId == schema.id && w.isVisible,
      orElse: () => throw StateError('Widget not found on dashboard'),
    );

    ref.read(dashboardWidgetsProvider.notifier).removeWidget(widgetToRemove.id);

    showInfoSnackBar(context, '${schema.name} removed from Dashboard');
  }

  void _confirmDelete(WidgetSchema schema) {
    // Check if widget is on dashboard
    final dashboardWidgets = ref.read(dashboardWidgetsProvider);
    final isOnDashboard = dashboardWidgets.any(
      (w) => w.schemaId == schema.id && w.isVisible,
    );

    final warningMessage = isOnDashboard
        ? 'This widget is currently on your Dashboard. Deleting it will also remove it from the Dashboard.\n\n'
              'Are you sure you want to delete "${schema.name}"? This cannot be undone.'
        : 'Are you sure you want to delete "${schema.name}"? This cannot be undone.';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: Row(
          children: [
            if (isOnDashboard) ...[
              Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.warningYellow,
                size: 24,
              ),
              const SizedBox(width: 8),
            ],
            const Text('Delete Widget?', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          warningMessage,
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
              // Remove from dashboard first if needed
              if (isOnDashboard) {
                final widgetToRemove = dashboardWidgets.firstWhere(
                  (w) => w.schemaId == schema.id && w.isVisible,
                );
                ref
                    .read(dashboardWidgetsProvider.notifier)
                    .removeWidget(widgetToRemove.id);
              }
              // Remove from user profile FIRST to prevent re-download
              await ref
                  .read(userProfileProvider.notifier)
                  .removeInstalledWidget(schema.id);
              // Then delete from local storage
              await _storageService.deleteWidget(schema.id);
              // Update state directly without reload (avoids restore logic)
              setState(() {
                _myWidgets.removeWhere((w) => w.id == schema.id);
                _marketplaceIds.remove(schema.id);
              });
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

  void _submitToMarketplace(WidgetSchema schema) async {
    // Show confirmation dialog with submission requirements
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
              'Submit "${schema.name}" for marketplace approval?',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.darkBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: context.accentColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Review Guidelines',
                        style: TextStyle(
                          color: context.accentColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Widget will be reviewed for quality\n'
                    '• Similar widgets may be rejected\n'
                    '• You\'ll be credited as the author',
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accentColor,
            ),
            child: const Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final service = ref.read(marketplaceServiceProvider);
      final authService = ref.read(authServiceProvider);
      final token = await authService.getIdToken();

      if (token == null) {
        if (mounted) Navigator.pop(context);
        if (mounted) {
          showErrorSnackBar(context, 'Please sign in to submit widgets');
        }
        return;
      }

      // Check for duplicates first
      final duplicateCheck = await service.checkDuplicate(schema, token);

      if (mounted) Navigator.pop(context); // Close loading

      if (duplicateCheck.isDuplicate) {
        // Show duplicate warning
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.darkCard,
              title: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.warningYellow,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Similar Widget Found',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A similar widget already exists in the marketplace:',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          duplicateCheck.duplicateName ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (duplicateCheck.similarityScore != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Similarity: ${(duplicateCheck.similarityScore! * 100).toInt()}%',
                            style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Consider making your widget more unique before submitting.',
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'OK',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Submit to marketplace
      await service.submitWidget(schema, token);

      if (mounted) {
        showSuccessSnackBar(context, '${schema.name} submitted for review');
      }
    } on MarketplaceDuplicateException catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          'Similar widget already exists: ${e.duplicateName}',
        );
      }
    } on MarketplaceException catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e.message);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to submit: $e');
      }
    }
  }
}
