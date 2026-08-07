// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../../core/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/edge_fade.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../core/widgets/premium_gating.dart';
import '../../models/subscription_models.dart';
import '../../providers/help_providers.dart';
import '../../providers/subscription_providers.dart';
import 'models/widget_schema.dart';
import 'storage/widget_storage_service.dart';
import 'widget_sync_providers.dart';
import 'wizard/widget_wizard_screen.dart';
import 'widget_share_utils.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/widget_preview_card.dart';
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

class _WidgetBuilderScreenState extends ConsumerState<WidgetBuilderScreen>
    with LifecycleSafeMixin<WidgetBuilderScreen> {
  Future<void> _refreshList() =>
      ref.read(widgetBuilderListProvider.notifier).refresh();

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(widgetBuilderListProvider);

    return HelpTourController(
      topicId: 'widget_builder_overview',
      stepKeys: const {},
      child: GlassScaffold.body(
        hasScrollBody: true,
        title: context.l10n.widgetBuilderMyWidgets,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createNewWidget,
            tooltip: context.l10n.widgetBuilderCreateWidgetTooltip,
          ),
          AppBarOverflowMenu<String>(
            onSelected: (value) {
              switch (value) {
                case 'help':
                  ref
                      .read(helpProvider.notifier)
                      .startTour('widget_builder_overview');
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'help',
                child: ListTile(
                  leading: Icon(Icons.help_outline),
                  title: Text(context.l10n.widgetBuilderHelp),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        body: listAsync.when(
          loading: () {
            AppLogging.widgets('screen RENDER -> LOADING');
            return const ScreenLoadingIndicator();
          },
          error: (e, _) {
            AppLogging.widgets('screen RENDER -> ERROR ($e)');
            return _buildDetailedEmptyState();
          },
          data: (widgets) {
            if (widgets.isEmpty) {
              AppLogging.widgets('screen RENDER -> EMPTY (Quick Start)');
            } else {
              AppLogging.widgets(
                'screen RENDER -> LIST '
                '(count=${widgets.length})',
              );
            }
            return _buildWidgetList(widgets);
          },
        ),
      ),
    );
  }

  Widget _buildWidgetList(List<WidgetSchema> widgets) {
    if (widgets.isEmpty) {
      return _buildDetailedEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshList,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        itemCount: widgets.length,
        itemBuilder: (context, index) {
          final schema = widgets[index];
          return _buildWidgetCard(schema, isTemplate: false);
        },
      ),
    );
  }

  Widget _buildWidgetCard(WidgetSchema schema, {required bool isTemplate}) {
    // Check if this widget is already on the dashboard
    final dashboardWidgets = ref.watch(dashboardWidgetsProvider);
    final isOnDashboard = dashboardWidgets.any(
      (w) => w.schemaId == schema.id && w.isVisible,
    );

    return WidgetPreviewCard(
      schema: schema,
      title: schema.name,
      subtitle: schema.description,
      onShare: isTemplate ? null : () => _shareWidget(schema),
      trailing: isTemplate
          ? TextButton(
              onPressed: () => _useTemplate(schema),
              child: Text(
                context.l10n.widgetBuilderUse,
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
                      SizedBox(width: AppTheme.spacing8),
                      Text(
                        isOnDashboard
                            ? context.l10n.widgetBuilderRemoveFromDashboard
                            : context.l10n.widgetBuilderAddToDashboard,
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
                      SizedBox(width: AppTheme.spacing8),
                      Text(
                        context.l10n.widgetBuilderEdit,
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
                      SizedBox(width: AppTheme.spacing8),
                      Text(
                        context.l10n.widgetBuilderDuplicate,
                        style: TextStyle(color: context.textPrimary),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: AppTheme.errorRed),
                      const SizedBox(width: AppTheme.spacing8),
                      Text(
                        context.l10n.widgetBuilderDeleteAction,
                        style: TextStyle(color: AppTheme.errorRed),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// Build the detailed first-visit/empty state as a guided widget builder
  /// This transforms "empty list" into "invitation to create"
  Widget _buildDetailedEmptyState() {
    final hasWidgetsPack = ref.watch(
      hasFeatureProvider(PremiumFeature.homeWidgets),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero section - What widgets are
          _buildHeroSection(hasWidgetsPack),

          const SizedBox(height: AppTheme.spacing24),

          // Create from scratch CTA - Primary action
          _buildCreateFromScratchCard(hasWidgetsPack),

          const SizedBox(height: AppTheme.spacing24),

          // Quick Start Templates - Secondary inspiration
          _buildTemplatesSection(hasWidgetsPack),

          const SizedBox(height: AppTheme.spacing24),

          // Widget Types - Exploration path
          _buildWidgetTypesSection(hasWidgetsPack),

          // Bottom padding
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  /// Hero section explaining what widgets are
  Widget _buildHeroSection(bool hasWidgetsPack) {
    final accentColor = context.accentColor;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.1),
            accentColor.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius20),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor, accentColor.withValues(alpha: 0.7)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.25),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.widgets, size: 44, color: Colors.white),
          ),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            context.l10n.widgetBuilderCustomDashboardWidgets,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            context.l10n.widgetBuilderHeroDescription,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.textSecondary),
          ),
        ],
      ),
    );
  }

  /// Primary CTA to create from scratch
  Widget _buildCreateFromScratchCard(bool hasWidgetsPack) {
    return BouncyTap(
      onTap: _createNewWidget,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              context.accentColor.withValues(alpha: 0.15),
              context.accentColor.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          border: Border.all(color: context.accentColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppTheme.radius14),
              ),
              child: Icon(Icons.add, size: 28, color: context.accentColor),
            ),
            const SizedBox(width: AppTheme.spacing16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.widgetBuilderCreateFirstWidget,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing4),
                  Text(
                    context.l10n.widgetBuilderCreateFirstWidgetDesc,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.textTertiary),
          ],
        ),
      ),
    );
  }

  /// Quick Start Templates section
  Widget _buildTemplatesSection(bool hasWidgetsPack) {
    final templates = _getQuickStartTemplates();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              Icon(Icons.flash_on, size: 18, color: AppTheme.warningYellow),
              const SizedBox(width: AppTheme.spacing6),
              Text(
                context.l10n.widgetBuilderQuickStartTemplates,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing4),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            context.l10n.widgetBuilderPrebuiltWidgets,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.textTertiary),
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        SizedBox(
          height: 140,
          child: EdgeFade.end(
            fadeSize: 24,
            fadeColor: context.background,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: templates.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppTheme.spacing12),
              itemBuilder: (context, index) {
                final template = templates[index];
                return BouncyTap(
                  onTap: () => _useBuiltInTemplate(template),
                  child: Container(
                    width: 160,
                    padding: const EdgeInsets.all(AppTheme.spacing12),
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                      border: Border.all(color: context.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: template.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius10,
                            ),
                          ),
                          child: Icon(
                            template.icon,
                            size: 20,
                            color: template.color,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          template.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing2),
                        Text(
                          template.description,
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Widget types section for exploration
  Widget _buildWidgetTypesSection(bool hasWidgetsPack) {
    final widgetTypes = _getWidgetTypes();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              Icon(Icons.category, size: 18, color: context.accentColor),
              const SizedBox(width: AppTheme.spacing6),
              Text(
                context.l10n.widgetBuilderWidgetTypes,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing4),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            context.l10n.widgetBuilderChooseStyle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.textTertiary),
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),

        // Build type chips in a wrap
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widgetTypes.map((type) {
            return BouncyTap(
              onTap: () => _createWithType(type.id),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  border: Border.all(color: context.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: type.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                      ),
                      child: Icon(type.icon, size: 18, color: type.color),
                    ),
                    const SizedBox(width: AppTheme.spacing10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          type.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          type.description,
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Get quick start templates
  List<_WidgetTemplateInfo> _getQuickStartTemplates() {
    return [
      _WidgetTemplateInfo(
        id: 'battery',
        name: context.l10n.widgetBuilderTemplateBatteryStatus,
        description: context.l10n.widgetBuilderTemplateBatteryStatusDesc,
        icon: Icons.battery_full,
        color: ChartColors.green,
      ),
      _WidgetTemplateInfo(
        id: 'signal',
        name: context.l10n.widgetBuilderTemplateSignalStrength,
        description: context.l10n.widgetBuilderTemplateSignalStrengthDesc,
        icon: Icons.signal_cellular_alt,
        color: ChartColors.categoryNode,
      ),
      _WidgetTemplateInfo(
        id: 'environment',
        name: context.l10n.widgetBuilderTemplateEnvironment,
        description: context.l10n.widgetBuilderTemplateEnvironmentDesc,
        icon: Icons.thermostat,
        color: ChartColors.cyan,
      ),
      _WidgetTemplateInfo(
        id: 'network',
        name: context.l10n.widgetBuilderTemplateNetworkOverview,
        description: context.l10n.widgetBuilderTemplateNetworkOverviewDesc,
        icon: Icons.hub,
        color: ChartColors.purple,
      ),
      _WidgetTemplateInfo(
        id: 'gps',
        name: context.l10n.widgetBuilderTemplateGpsPosition,
        description: context.l10n.widgetBuilderTemplateGpsPositionDesc,
        icon: Icons.location_on,
        color: ChartColors.orange,
      ),
      _WidgetTemplateInfo(
        id: 'distribution',
        name: context.l10n.widgetBuilderDistributionTemplate,
        description: context.l10n.widgetBuilderDistributionTemplateDesc,
        icon: Icons.bar_chart,
        color: ChartColors.cyan,
      ),
    ];
  }

  /// Get widget types for exploration
  List<_WidgetTypeInfo> _getWidgetTypes() {
    return [
      _WidgetTypeInfo(
        id: 'status',
        name: context.l10n.widgetBuilderTypeStatusDisplay,
        description: context.l10n.widgetBuilderTypeStatusDisplayDesc,
        icon: Icons.speed,
        color: ChartColors.green,
      ),
      _WidgetTypeInfo(
        id: 'gauge',
        name: context.l10n.widgetBuilderTypeGauge,
        description: context.l10n.widgetBuilderTypeGaugeDesc,
        icon: Icons.data_usage,
        color: ChartColors.yellow,
      ),
      _WidgetTypeInfo(
        id: 'graph',
        name: context.l10n.widgetBuilderTypeGraph,
        description: context.l10n.widgetBuilderTypeGraphDesc,
        icon: Icons.show_chart,
        color: ChartColors.orange,
      ),
      _WidgetTypeInfo(
        id: 'actions',
        name: context.l10n.widgetBuilderTypeQuickActions,
        description: context.l10n.widgetBuilderTypeQuickActionsDesc,
        icon: Icons.flash_on,
        color: ChartColors.pink,
      ),
      _WidgetTypeInfo(
        id: 'info',
        name: context.l10n.widgetBuilderTypeInfoCard,
        description: context.l10n.widgetBuilderTypeInfoCardDesc,
        icon: Icons.info_outline,
        color: ChartColors.categoryNode,
      ),
      _WidgetTypeInfo(
        id: 'location',
        name: context.l10n.widgetBuilderTypeLocation,
        description: context.l10n.widgetBuilderTypeLocationDesc,
        icon: Icons.location_on,
        color: ChartColors.purple,
      ),
    ];
  }

  /// Use a built-in template
  void _useBuiltInTemplate(_WidgetTemplateInfo template) async {
    HapticFeedback.selectionClick();
    AppLogging.widgets(
      '[WidgetBuilder] Using built-in template: ${template.id}',
    );

    // Get the actual template schema
    WidgetSchema? schema;
    switch (template.id) {
      case 'battery':
        schema = WidgetTemplates.batteryWidget();
      case 'signal':
        schema = WidgetTemplates.signalWidget();
      case 'environment':
        schema = WidgetTemplates.environmentWidget();
      case 'network':
        schema = WidgetTemplates.networkOverviewWidget();
      case 'gps':
        schema = WidgetTemplates.gpsWidget();
      case 'distribution':
        schema = WidgetTemplates.distributionWidget();
    }

    if (schema != null) {
      _useTemplate(schema);
    } else {
      _createNewWidget();
    }
  }

  /// Create with a specific widget type pre-selected
  void _createWithType(String typeId) {
    HapticFeedback.selectionClick();
    AppLogging.widgets('[WidgetBuilder] Creating with type: $typeId');

    // Navigate to wizard - user will select the type in step 1
    _createNewWidget();
  }

  void _createNewWidget() async {
    AppLogging.widgets('[WidgetBuilder] _createNewWidget called');

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
            AppLogging.widgets(
              '[WidgetBuilder] onSave callback - saving new widget: ${schema.id}',
            );
            AppLogging.sync(
              '[WidgetBuilder] onSave NEW widget — id=${schema.id}, '
              'name=${schema.name}',
            );
            final storage = ref
                .read(widgetStorageServiceProvider)
                .asData
                ?.value;
            if (storage != null) {
              await storage.saveWidget(schema);
              AppLogging.sync(
                '[WidgetBuilder] Widget saved, triggering drainOutboxNow()...',
              );
              // Drain outbox immediately so the widget syncs promptly
              // (matching the pattern used by Automations)
              if (!mounted) return;
              final syncService = ref.read(widgetSyncServiceProvider);
              AppLogging.sync(
                '[WidgetBuilder] syncService=${syncService != null ? "exists(enabled=${syncService.isEnabled})" : "NULL"}',
              );
              await syncService?.drainOutboxNow();
              AppLogging.sync('[WidgetBuilder] drainOutboxNow() complete');
            } else {
              AppLogging.sync(
                '[WidgetBuilder] WARNING: storage is null, widget NOT saved!',
              );
            }
            AppLogging.widgets('[WidgetBuilder] New widget saved successfully');
          },
        ),
      ),
    );

    AppLogging.widgets('[WidgetBuilder] Wizard returned, result: $result');

    // Always reload widgets after returning from wizard
    // The save happens inside the wizard, so we should reload regardless
    await _refreshList();
    AppLogging.widgets('[WidgetBuilder] Widgets reloaded');

    // Add to dashboard if requested
    if (result != null && result.addToDashboard) {
      AppLogging.widgets(
        '[WidgetBuilder] Adding widget to dashboard: ${result.schema.id}',
      );
      if (!mounted) return;
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
          context.l10n.widgetBuilderAddedToDashboard(result.schema.name),
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
    AppLogging.widgets('[WidgetBuilder] _editWidget called for: ${schema.id}');

    final result = await Navigator.push<WidgetWizardResult>(
      context,
      MaterialPageRoute(
        builder: (context) => WidgetWizardScreen(
          initialSchema: schema,
          onSave: (updated) async {
            AppLogging.widgets(
              '[WidgetBuilder] onSave callback - saving widget: ${updated.id}',
            );
            AppLogging.sync(
              '[WidgetBuilder] onSave EDIT widget — id=${updated.id}, '
              'name=${updated.name}',
            );
            final storage = ref
                .read(widgetStorageServiceProvider)
                .asData
                ?.value;
            if (storage != null) {
              await storage.saveWidget(updated);
              AppLogging.sync(
                '[WidgetBuilder] Widget updated, triggering drainOutboxNow()...',
              );
              if (!mounted) return;
              final syncService = ref.read(widgetSyncServiceProvider);
              AppLogging.sync(
                '[WidgetBuilder] syncService=${syncService != null ? "exists(enabled=${syncService.isEnabled})" : "NULL"}',
              );
              await syncService?.drainOutboxNow();
              AppLogging.sync('[WidgetBuilder] drainOutboxNow() complete');
            } else {
              AppLogging.sync(
                '[WidgetBuilder] WARNING: storage is null, widget NOT saved!',
              );
            }
            AppLogging.widgets('[WidgetBuilder] Widget saved successfully');
          },
        ),
      ),
    );

    AppLogging.widgets('[WidgetBuilder] Wizard returned, result: $result');

    // Always reload widgets after returning from wizard
    await _refreshList();
    AppLogging.widgets('[WidgetBuilder] Widgets reloaded');
  }

  void _shareWidget(WidgetSchema schema) {
    showWidgetShareSheet(context, schema, ref: ref);
  }

  void _useTemplate(WidgetSchema template) async {
    AppLogging.widgets(
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
            AppLogging.widgets(
              '[WidgetBuilder] onSave callback - saving template copy: ${schema.id}',
            );
            AppLogging.sync(
              '[WidgetBuilder] onSave TEMPLATE COPY — id=${schema.id}, '
              'name=${schema.name}',
            );
            final storage = ref
                .read(widgetStorageServiceProvider)
                .asData
                ?.value;
            if (storage != null) {
              await storage.saveWidget(schema);
              AppLogging.sync(
                '[WidgetBuilder] Template copy saved, triggering drainOutboxNow()...',
              );
              if (!mounted) return;
              final syncService = ref.read(widgetSyncServiceProvider);
              AppLogging.sync(
                '[WidgetBuilder] syncService=${syncService != null ? "exists(enabled=${syncService.isEnabled})" : "NULL"}',
              );
              await syncService?.drainOutboxNow();
              AppLogging.sync('[WidgetBuilder] drainOutboxNow() complete');
            } else {
              AppLogging.sync(
                '[WidgetBuilder] WARNING: storage is null, template NOT saved!',
              );
            }
            AppLogging.widgets(
              '[WidgetBuilder] Template copy saved successfully',
            );
          },
        ),
      ),
    );

    AppLogging.widgets(
      '[WidgetBuilder] Template wizard returned, result: $result',
    );

    // Always reload widgets after returning from wizard
    await _refreshList();
    AppLogging.widgets('[WidgetBuilder] Widgets reloaded');
  }

  void _handleAction(String action, WidgetSchema schema) async {
    AppLogging.widgets(
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
        AppLogging.widgets('[WidgetBuilder] Duplicating widget: ${schema.id}');
        if (!mounted) return;
        final dupStorage = ref.read(widgetStorageServiceProvider).asData?.value;
        if (dupStorage != null) await dupStorage.duplicateWidget(schema.id);
        await _refreshList();
        AppLogging.widgets('[WidgetBuilder] Widget duplicated');
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

    if (!mounted) return;
    ref.read(dashboardWidgetsProvider.notifier).addCustomWidget(config);

    showSuccessSnackBar(
      context,
      context.l10n.widgetBuilderAddedToDashboard(schema.name),
    );
  }

  void _removeFromDashboard(WidgetSchema schema) {
    final dashboardWidgets = ref.read(dashboardWidgetsProvider);
    final widgetToRemove = dashboardWidgets.firstWhere(
      (w) => w.schemaId == schema.id && w.isVisible,
      orElse: () => throw StateError('Widget not found on dashboard'),
    );

    ref.read(dashboardWidgetsProvider.notifier).removeWidget(widgetToRemove.id);

    showInfoSnackBar(
      context,
      context.l10n.widgetBuilderRemovedFromDashboard(schema.name),
    );
  }

  void _confirmDelete(WidgetSchema schema) {
    // Check if widget is on dashboard
    final dashboardWidgets = ref.read(dashboardWidgetsProvider);
    final isOnDashboard = dashboardWidgets.any(
      (w) => w.schemaId == schema.id && w.isVisible,
    );

    final warningMessage = isOnDashboard
        ? 'This widget is currently on your Dashboard. Deleting it will also remove it from the Dashboard.\n\n' // lint-allow: hardcoded-string
              'Are you sure you want to delete "${schema.name}"? This cannot be undone.' // lint-allow: hardcoded-string
        : 'Are you sure you want to delete "${schema.name}"? This cannot be undone.';

    // Capture refs BEFORE showing dialog (before any await)
    final dashboardNotifier = ref.read(dashboardWidgetsProvider.notifier);
    final delStorage = ref.read(widgetStorageServiceProvider).asData?.value;

    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isOnDashboard) ...[
                Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.warningYellow,
                  size: 24,
                ),
                SizedBox(width: AppTheme.spacing8),
              ],
              Text(
                context.l10n.widgetBuilderDeleteWidgetTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            warningMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacing24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: SemanticColors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: Text(
                    context.l10n.widgetBuilderCancel,
                    style: TextStyle(color: context.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.errorRed,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  onPressed: () async {
                    // Pop bottom sheet immediately
                    Navigator.pop(context);

                    final schemaId = schema.id;
                    final schemaName = schema.name;

                    // Optimistically drop from the in-memory list so the card
                    // disappears immediately, before the storage delete + sync
                    // round-trip completes.
                    ref
                        .read(widgetBuilderListProvider.notifier)
                        .removeWidgetLocally(schemaId);

                    // Remove from dashboard if needed (sync, no await)
                    if (isOnDashboard) {
                      final widgetToRemove = dashboardWidgets.firstWhere(
                        (w) => w.schemaId == schemaId && w.isVisible,
                      );
                      dashboardNotifier.removeWidget(widgetToRemove.id);
                    }

                    // Delete from local storage
                    AppLogging.sync(
                      '[WidgetBuilder] DELETE widget — id=$schemaId, name=$schemaName',
                    );
                    await delStorage?.deleteWidget(schemaId);
                    AppLogging.widgets(
                      '[WidgetBuilder] Deleted widget $schemaId',
                    );
                    AppLogging.sync(
                      '[WidgetBuilder] Widget deleted from storage, '
                      'triggering drainOutboxNow()...',
                    );

                    // Drain outbox immediately so the deletion syncs promptly
                    // (matching the pattern used by Automations)
                    if (!mounted) return;
                    final syncService = ref.read(widgetSyncServiceProvider);
                    AppLogging.sync(
                      '[WidgetBuilder] syncService=${syncService != null ? "exists(enabled=${syncService.isEnabled})" : "NULL"}',
                    );
                    await syncService?.drainOutboxNow();
                    AppLogging.sync(
                      '[WidgetBuilder] drainOutboxNow() complete after delete',
                    );

                    if (!mounted) return;

                    // Reconcile the list with the final storage state.
                    await _refreshList();
                    showGlobalSuccessSnackBar('Deleted "$schemaName"');
                  },
                  child: Text(
                    context.l10n.widgetBuilderDeleteButton,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Helper class for quick start template info
class _WidgetTemplateInfo {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  const _WidgetTemplateInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });
}

/// Helper class for widget type info
class _WidgetTypeInfo {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  const _WidgetTypeInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });
}
