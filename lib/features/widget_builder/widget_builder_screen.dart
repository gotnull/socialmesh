// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:socialmesh/core/logging.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../core/widgets/premium_gating.dart';
import '../../models/subscription_models.dart';
import '../../providers/help_providers.dart';
import '../../providers/subscription_providers.dart';
import 'models/widget_schema.dart';
import 'storage/widget_storage_service.dart';
import 'wizard/widget_wizard_screen.dart';
import 'marketplace/widget_marketplace_screen.dart';
import 'marketplace/widget_marketplace_service.dart';
import 'marketplace/marketplace_providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/widget_preview_card.dart';
import '../../providers/auth_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/share_utils.dart';
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

      AppLogging.widgetBuilder(
        '[WidgetBuilder] Loaded ${widgets.length} widgets from local storage',
      );
      AppLogging.widgetBuilder(
        '[WidgetBuilder] Local widget IDs: ${widgets.map((w) => w.id).toList()}',
      );
      AppLogging.widgetBuilder(
        '[WidgetBuilder] Installed marketplace IDs: $installedIds',
      );

      // Check profile for installed widgets that might need restoration
      final profile = ref.read(userProfileProvider).value;
      AppLogging.widgetBuilder(
        '[WidgetBuilder] Profile installedWidgetIds: ${profile?.installedWidgetIds ?? []}',
      );

      if (profile != null && profile.installedWidgetIds.isNotEmpty) {
        // Compare against marketplace IDs (not schema IDs) since profile stores marketplace IDs
        final installedMarketplaceIds = installedIds.toSet();
        final missingIds = profile.installedWidgetIds
            .where((id) => !installedMarketplaceIds.contains(id))
            .toList();

        AppLogging.widgetBuilder(
          '[WidgetBuilder] Missing IDs (in profile but not local): $missingIds',
        );

        if (missingIds.isNotEmpty) {
          AppLogging.widgetBuilder(
            '[WidgetBuilder] Found ${missingIds.length} widgets to restore from cloud',
          );
          // Restore missing widgets from marketplace
          await _restoreMissingWidgets(missingIds);
          // Reload after restoration
          final updatedWidgets = await _storageService.getWidgets();
          final updatedInstalledIds = await _storageService
              .getInstalledMarketplaceIds();
          AppLogging.widgetBuilder(
            '[WidgetBuilder] After restore: ${updatedWidgets.length} widgets',
          );
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
      AppLogging.widgetBuilder('[WidgetBuilder] Error loading widgets: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Restore widgets from marketplace that are in profile but not local storage
  Future<void> _restoreMissingWidgets(List<String> widgetIds) async {
    final service = ref.read(marketplaceServiceProvider);
    final failedIds = <String>[];

    for (final marketplaceId in widgetIds) {
      try {
        AppLogging.widgetBuilder(
          '[WidgetBuilder] Restoring widget with marketplace ID: $marketplaceId',
        );
        // Use previewWidget to NOT increment install count (user already owns this)
        final schema = await service.previewWidget(marketplaceId);
        // Pass the marketplace ID so it's tracked correctly
        await _storageService.installMarketplaceWidget(
          schema,
          marketplaceId: marketplaceId,
        );
        AppLogging.widgetBuilder(
          '[WidgetBuilder] Restored widget: ${schema.name} (marketplace ID: $marketplaceId)',
        );
      } catch (e) {
        AppLogging.widgetBuilder(
          '[WidgetBuilder] Failed to restore widget $marketplaceId: $e - removing from profile',
        );
        failedIds.add(marketplaceId);
      }
    }

    // Clean up any widgets that couldn't be restored (deleted from marketplace, etc.)
    for (final failedId in failedIds) {
      try {
        await ref
            .read(userProfileProvider.notifier)
            .removeInstalledWidget(failedId);
        AppLogging.widgetBuilder(
          '[WidgetBuilder] Removed unrestorable widget $failedId from profile',
        );
      } catch (e) {
        AppLogging.widgetBuilder(
          '[WidgetBuilder] Failed to remove $failedId from profile: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return HelpTourController(
      topicId: 'widget_builder_overview',
      stepKeys: const {},
      child: Scaffold(
        backgroundColor: context.background,
        appBar: AppBar(
          backgroundColor: context.background,
          title: Text(
            'My Widgets',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_box),
              onPressed: _createNewWidget,
              tooltip: 'Create Widget',
            ),
            AppBarOverflowMenu<String>(
              onSelected: (value) {
                switch (value) {
                  case 'marketplace':
                    _openMarketplace();
                  case 'help':
                    ref
                        .read(helpProvider.notifier)
                        .startTour('widget_builder_overview');
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'marketplace',
                  child: ListTile(
                    leading: Icon(Icons.store, color: context.accentColor),
                    title: const Text('Marketplace'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'help',
                  child: ListTile(
                    leading: Icon(Icons.help_outline),
                    title: Text('Help'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        body: _isLoading ? const ScreenLoadingIndicator() : _buildWidgetList(),
      ),
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: _createNewWidget,
                  icon: Icon(Icons.add, color: Colors.white),
                  label: Text(
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
              ],
            ),
            SizedBox(height: 12),
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
          : AppBarOverflowMenu<String>(
              color: context.card,
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
                            : context.textSecondary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        isOnDashboard
                            ? 'Remove from Dashboard'
                            : 'Add to Dashboard',
                        style: TextStyle(
                          color: isOnDashboard
                              ? AppTheme.errorRed
                              : context.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18, color: context.textPrimary),
                      SizedBox(width: 8),
                      Text(
                        'Edit',
                        style: TextStyle(color: context.textPrimary),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'duplicate',
                  child: Row(
                    children: [
                      Icon(Icons.copy, size: 18, color: context.textPrimary),
                      SizedBox(width: 8),
                      Text(
                        'Duplicate',
                        style: TextStyle(color: context.textPrimary),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.share, size: 18, color: context.textPrimary),
                      SizedBox(width: 8),
                      Text(
                        'Export',
                        style: TextStyle(color: context.textPrimary),
                      ),
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
                        SizedBox(width: 8),
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
              SizedBox(height: 24),
              Text(
                title,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(color: context.textSecondary, fontSize: 14),
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
    AppLogging.widgetBuilder('[WidgetBuilder] _createNewWidget called');

    // Check premium before allowing widget creation
    final hasPremium = ref.read(hasFeatureProvider(PremiumFeature.homeWidgets));
    if (!hasPremium) {
      showPremiumInfoSheet(
        context: context,
        ref: ref,
        feature: PremiumFeature.homeWidgets,
      );
      return;
    }

    final result = await Navigator.push<WidgetWizardResult>(
      context,
      MaterialPageRoute(
        builder: (context) => WidgetWizardScreen(
          onSave: (schema) async {
            AppLogging.widgetBuilder(
              '[WidgetBuilder] onSave callback - saving new widget: ${schema.id}',
            );
            await _storageService.saveWidget(schema);
            AppLogging.widgetBuilder(
              '[WidgetBuilder] New widget saved successfully',
            );
          },
        ),
      ),
    );

    AppLogging.widgetBuilder(
      '[WidgetBuilder] Wizard returned, result: $result',
    );

    // Always reload widgets after returning from wizard
    // The save happens inside the wizard, so we should reload regardless
    await _loadWidgets();
    AppLogging.widgetBuilder('[WidgetBuilder] Widgets reloaded');

    // Add to dashboard if requested
    if (result != null && result.addToDashboard) {
      AppLogging.widgetBuilder(
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
    AppLogging.widgetBuilder(
      '[WidgetBuilder] _editWidget called for: ${schema.id}',
    );

    final result = await Navigator.push<WidgetWizardResult>(
      context,
      MaterialPageRoute(
        builder: (context) => WidgetWizardScreen(
          initialSchema: schema,
          onSave: (updated) async {
            AppLogging.widgetBuilder(
              '[WidgetBuilder] onSave callback - saving widget: ${updated.id}',
            );
            await _storageService.saveWidget(updated);
            AppLogging.widgetBuilder(
              '[WidgetBuilder] Widget saved successfully',
            );
          },
        ),
      ),
    );

    AppLogging.widgetBuilder(
      '[WidgetBuilder] Wizard returned, result: $result',
    );

    // Always reload widgets after returning from wizard
    await _loadWidgets();
    AppLogging.widgetBuilder('[WidgetBuilder] Widgets reloaded');
  }

  void _useTemplate(WidgetSchema template) async {
    AppLogging.widgetBuilder(
      '[WidgetBuilder] _useTemplate called for: ${template.name}',
    );

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
            AppLogging.widgetBuilder(
              '[WidgetBuilder] onSave callback - saving template copy: ${schema.id}',
            );
            await _storageService.saveWidget(schema);
            AppLogging.widgetBuilder(
              '[WidgetBuilder] Template copy saved successfully',
            );
          },
        ),
      ),
    );

    AppLogging.widgetBuilder(
      '[WidgetBuilder] Template wizard returned, result: $result',
    );

    // Always reload widgets after returning from wizard
    await _loadWidgets();
    AppLogging.widgetBuilder('[WidgetBuilder] Widgets reloaded');
  }

  void _handleAction(String action, WidgetSchema schema) async {
    AppLogging.widgetBuilder(
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
        AppLogging.widgetBuilder(
          '[WidgetBuilder] Duplicating widget: ${schema.id}',
        );
        await _storageService.duplicateWidget(schema.id);
        await _loadWidgets();
        AppLogging.widgetBuilder('[WidgetBuilder] Widget duplicated');
        break;
      case 'export':
        AppLogging.widgetBuilder(
          '[WidgetBuilder] Exporting widget: ${schema.id}',
        );
        // Capture share position before async gap
        final sharePosition = getSafeSharePosition(context);
        final json = await _storageService.exportWidget(schema.id);
        await Share.share(
          json,
          subject: '${schema.name} Widget',
          sharePositionOrigin: sharePosition,
        );
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
        backgroundColor: context.card,
        title: Row(
          children: [
            if (isOnDashboard) ...[
              Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.warningYellow,
                size: 24,
              ),
              SizedBox(width: 8),
            ],
            Text(
              'Delete Widget?',
              style: TextStyle(color: context.textPrimary),
            ),
          ],
        ),
        content: Text(
          warningMessage,
          style: TextStyle(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
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
              // Delete from local storage and get marketplace ID
              final marketplaceId = await _storageService.deleteWidget(
                schema.id,
              );
              AppLogging.widgetBuilder(
                '[WidgetBuilder] Deleted widget ${schema.id}, marketplaceId=$marketplaceId',
              );
              // Remove from user profile using marketplace ID (or schema ID as fallback)
              final idToRemoveFromProfile = marketplaceId ?? schema.id;
              await ref
                  .read(userProfileProvider.notifier)
                  .removeInstalledWidget(idToRemoveFromProfile);
              AppLogging.widgetBuilder(
                '[WidgetBuilder] Removed $idToRemoveFromProfile from profile',
              );
              // Update state directly without reload (avoids restore logic)
              setState(() {
                _myWidgets.removeWhere((w) => w.id == schema.id);
                _marketplaceIds.remove(marketplaceId ?? schema.id);
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
        backgroundColor: context.card,
        title: Text(
          'Submit to Marketplace',
          style: TextStyle(color: context.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Submit "${schema.name}" for marketplace approval?',
              style: TextStyle(color: context.textSecondary),
            ),
            SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.border),
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
                      SizedBox(width: 8),
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
                  SizedBox(height: 8),
                  Text(
                    '• Widget will be reviewed for quality\n'
                    '• Similar widgets may be rejected\n'
                    '• You\'ll be credited as the author',
                    style: TextStyle(
                      color: context.textTertiary,
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
              style: TextStyle(color: context.textSecondary),
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
              backgroundColor: context.card,
              title: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.warningYellow,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Similar Widget Found',
                    style: TextStyle(color: context.textPrimary),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A similar widget already exists in the marketplace:',
                    style: TextStyle(color: context.textSecondary),
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          duplicateCheck.duplicateName ?? 'Unknown',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (duplicateCheck.similarityScore != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Similarity: ${(duplicateCheck.similarityScore! * 100).toInt()}%',
                            style: TextStyle(
                              color: context.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Consider making your widget more unique before submitting.',
                    style: TextStyle(color: context.textTertiary, fontSize: 13),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'OK',
                    style: TextStyle(color: context.accentColor),
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
