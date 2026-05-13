// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/gradient_border_container.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../providers/help_providers.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../utils/snackbar.dart';
import '../navigation/main_shell.dart';

import '../widget_builder/widget_sync_providers.dart';
import '../widget_builder/wizard/widget_wizard_screen.dart';
import 'models/dashboard_widget_config.dart';
import 'providers/dashboard_providers.dart';
import 'widgets/dashboard_widget.dart';
import 'widgets/network_overview_widget.dart';
import 'widgets/recent_messages_widget.dart';
import 'widgets/nearby_nodes_widget.dart';
import 'widgets/quick_actions_widget.dart';
import 'widgets/signal_strength_widget.dart';
import 'widgets/channel_activity_widget.dart';
import 'widgets/mesh_health_widget.dart';
import 'widgets/node_map_widget.dart';
import 'widgets/environment_metrics_widget.dart';
import 'widgets/schema_widget_content.dart';
import '../../config/revenuecat_config.dart';
import '../../models/subscription_models.dart';
import '../../providers/subscription_providers.dart';
import '../settings/subscription_screen.dart';
import '../../core/widgets/loading_indicator.dart';

/// Widgets available for free.
///
/// Must stay in sync with the first-launch default dashboard
/// (`DashboardWidgetsNotifier._getDefaultWidgets`) — any widget that
/// ships on the default dashboard must also be re-addable from the
/// picker without purchasing, otherwise removing then re-adding
/// triggers a paywall the user did not see when the widget was first
/// installed.
const _freeWidgetTypes = {
  DashboardWidgetType.signalStrength,
  DashboardWidgetType.networkOverview,
  DashboardWidgetType.recentMessages,
  DashboardWidgetType.custom, // Custom widgets are free
};

// Single source of truth for what the picker treats as "addable". Custom
// widgets are excluded — those are added from the Widget Builder, not here.
// Both _buildDashboard and _AddWidgetSheet.build consume this so the
// dashboard's "unused premium count" can never drift from the picker's list.
Iterable<DashboardWidgetType> _addableWidgetTypes() =>
    DashboardWidgetType.values.where((t) => t != DashboardWidgetType.custom);

// Count of premium widget types the user owns but hasn't added yet.
// `addedTypes` is the set of currently-visible widget configs' types.
int _unusedPremiumCount(Set<DashboardWidgetType> addedTypes) =>
    _addableWidgetTypes()
        .where((t) => !_freeWidgetTypes.contains(t) && !addedTypes.contains(t))
        .length;

// Live store-fetched display name for the Widgets Pack, with a sensible
// fallback when storeProductsProvider hasn't resolved yet.
String _packTitle(WidgetRef ref) {
  final storeProductsAsync = ref.watch(storeProductsProvider);
  final storeProducts = storeProductsAsync.when(
    data: (data) => data,
    loading: () => <String, StoreProductInfo>{},
    error: (_, _) => <String, StoreProductInfo>{},
  );
  return storeProducts[RevenueCatConfig.widgetPackProductId]?.title ??
      'Widget Pack'; // lint-allow: hardcoded-string
}

/// Customizable widget dashboard with drag/reorder/favorites
class WidgetDashboardScreen extends ConsumerStatefulWidget {
  final bool autoOpenPicker;

  const WidgetDashboardScreen({super.key, this.autoOpenPicker = false});

  @override
  ConsumerState<WidgetDashboardScreen> createState() =>
      _WidgetDashboardScreenState();
}

class _WidgetDashboardScreenState extends ConsumerState<WidgetDashboardScreen>
    with LifecycleSafeMixin {
  bool _editMode = false;
  bool _didAutoOpenPicker = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoOpenPicker) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didAutoOpenPicker) return;
        _didAutoOpenPicker = true;
        AppLogging.widgets('[Dashboard] autoOpenPicker fired (post-purchase)');
        _showAddWidgetSheet(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final widgetConfigs = ref.watch(dashboardWidgetsProvider);

    // Check if this screen was pushed (can pop) - show back button instead of hamburger
    final canPop = Navigator.of(context).canPop();

    return HelpTourController(
      topicId: 'dashboard_overview',
      stepKeys: const {},
      child: GlassScaffold.body(
        hasScrollBody: true,
        leading: canPop ? const BackButton() : const HamburgerMenuButton(),
        centerTitle: true,
        title: _editMode
            ? context.l10n.dashboardEditTitle
            : context.l10n.dashboardTitle,
        actions: [
          // Add widget button - always visible
          IconButton(
            icon: Icon(Icons.add, color: context.accentColor),
            onPressed: () => _showAddWidgetSheet(context),
            tooltip: context.l10n.dashboardAddWidget,
          ),
          if (!_editMode) ...[
            // Device button
            const DeviceStatusButton(),
            // Settings
            AppBarOverflowMenu<String>(
              onSelected: (value) {
                switch (value) {
                  case 'help':
                    ref
                        .read(helpProvider.notifier)
                        .startTour('dashboard_overview');
                  case 'settings':
                    Navigator.of(context).pushNamed('/settings');
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'help',
                  child: ListTile(
                    leading: Icon(Icons.help_outline),
                    title: Text(context.l10n.dashboardHelp),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'settings',
                  child: ListTile(
                    leading: Icon(Icons.settings_outlined),
                    title: Text(context.l10n.dashboardSettings),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ] else ...[
            // Done button
            TextButton(
              onPressed: () => setState(() => _editMode = false),
              child: Text(
                context.l10n.dashboardDone,
                style: TextStyle(
                  color: context.accentColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ],
        body: _buildDashboard(context, widgetConfigs),
      ),
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    List<DashboardWidgetConfig> widgetConfigs,
  ) {
    final purchaseState = ref.watch(purchaseStateProvider);
    final hasWidgetPack = purchaseState.hasFeature(PremiumFeature.homeWidgets);

    final enabledWidgets = widgetConfigs.where((w) => w.isVisible).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    if (enabledWidgets.isEmpty && !_editMode) {
      return _buildEmptyDashboard(context);
    }

    // Calculate how many more widgets are available
    final totalWidgetTypes = DashboardWidgetType.values.length;
    final freeWidgetCount = _freeWidgetTypes.length;
    final premiumWidgetCount = totalWidgetTypes - freeWidgetCount;

    // Owner-aware discovery state. Sourced from the same helper the picker
    // uses so the count and the picker's addable list never drift.
    final addedTypes = enabledWidgets.map((c) => c.type).toSet();
    final unusedPremiumCount = _unusedPremiumCount(addedTypes);
    // Once a paid user has interacted with customization (tapped the
    // discovery card OR entered edit mode at least once), the card stays
    // hidden so it stops crowding the dashboard. The non-owner upsell
    // card is a separate paywall surface and remains unaffected.
    final discoveryDismissed =
        ref.watch(dashboardDiscoveryAckProvider).value ?? false;
    final showOwnerDiscovery =
        hasWidgetPack &&
        !_editMode &&
        unusedPremiumCount > 0 &&
        !discoveryDismissed;
    final showUpsell = !hasWidgetPack && !_editMode;
    // Sticky edit-mode add tile gating uses the visible widget list — hidden
    // persisted configs must not suppress the tile.
    final showEditAddTile =
        _editMode &&
        enabledWidgets.length < DashboardWidgetsNotifier.maxWidgets;

    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              (showUpsell || showOwnerDiscovery || showEditAddTile) ? 8 : 16,
            ),
            buildDefaultDragHandles: false,
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final elevation = lerpDouble(0, 8, animation.value) ?? 0;
                  return Material(
                    elevation: elevation,
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.radius16),
                    child: child,
                  );
                },
                child: child,
              );
            },
            itemCount: enabledWidgets.length,
            onReorder: (oldIndex, newIndex) {
              ref
                  .read(dashboardWidgetsProvider.notifier)
                  .reorder(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final config = enabledWidgets[index];
              return Padding(
                key: ValueKey(config.id),
                padding: const EdgeInsets.only(bottom: 16),
                child: _editMode
                    ? _buildWidgetCard(config, reorderIndex: index)
                    : GestureDetector(
                        onLongPress: () {
                          HapticFeedback.mediumImpact();
                          _showWidgetContextMenu(context, config);
                        },
                        child: _buildWidgetCard(config),
                      ),
              );
            },
          ),
        ),
        // Sticky edit-mode add-another-widget tile (visible-count gated)
        if (showEditAddTile) _buildEditModeAddTile(context),
        // Owner-aware footer card: upsell for non-owners, discovery for
        // owners with unused premium widgets, nothing once everything is
        // added (or in edit mode).
        if (showUpsell) _buildWidgetUpsellCard(premiumWidgetCount),
        if (showOwnerDiscovery)
          _buildPackOwnerDiscoveryCard(context, unusedPremiumCount),
      ],
    );
  }

  Widget _buildWidgetUpsellCard(int premiumWidgetCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppTheme.spacing16, 8, 16, 16),
      child: GradientBorderContainer(
        borderRadius: 16,
        borderWidth: 2,
        accentOpacity: 0.4,
        backgroundColor: context.card,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            },
            borderRadius: BorderRadius.circular(AppTheme.radius16),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          context.accentColor.withValues(alpha: 0.3),
                          context.accentColor.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                      border: Border.all(
                        color: context.accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.widgets_rounded,
                      color: context.accentColor,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: AppTheme.spacing16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unlock $premiumWidgetCount More Widgets', // lint-allow: hardcoded-string
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.accentColor,
                          ),
                        ),
                        SizedBox(height: AppTheme.spacing4),
                        Text(
                          'Battery, messages, map, and more', // lint-allow: hardcoded-string
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: context.accentColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPackOwnerDiscoveryCard(BuildContext context, int unusedCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppTheme.spacing16, 8, 16, 16),
      child: GradientBorderContainer(
        borderRadius: 16,
        borderWidth: 2,
        accentOpacity: 0.4,
        backgroundColor: context.card,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              AppLogging.widgets(
                '[Dashboard] Owner discovery card tapped → opening picker',
              );
              ref
                  .read(dashboardDiscoveryAckProvider.notifier)
                  .dismiss(reason: 'card_tap');
              _showAddWidgetSheet(context);
            },
            borderRadius: BorderRadius.circular(AppTheme.radius16),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          context.accentColor.withValues(alpha: 0.3),
                          context.accentColor.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                      border: Border.all(
                        color: context.accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.dashboard_customize,
                      color: context.accentColor,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: AppTheme.spacing16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.dashboardOwnerDiscoveryTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.accentColor,
                          ),
                        ),
                        SizedBox(height: AppTheme.spacing4),
                        Text(
                          context.l10n.dashboardOwnerDiscoverySubtitle(
                            unusedCount,
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: context.accentColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditModeAddTile(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppTheme.spacing16, 8, 16, 16),
      height: 56,
      child: CustomPaint(
        painter: DashedBorderPainter(
          color: context.accentColor.withValues(alpha: 0.6),
          strokeWidth: 2,
          dashWidth: 8,
          dashSpace: 4,
          borderRadius: AppTheme.radius16,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              AppLogging.widgets(
                '[Dashboard] Edit-mode add tile tapped → opening picker',
              );
              _showAddWidgetSheet(context);
            },
            borderRadius: BorderRadius.circular(AppTheme.radius16),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    color: context.accentColor,
                    size: 20,
                  ),
                  SizedBox(width: AppTheme.spacing8),
                  Text(
                    context.l10n.dashboardAddAnotherWidget,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.accentColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWidgetCard(DashboardWidgetConfig config, {int? reorderIndex}) {
    // Custom widgets render with minimal wrapper - just the content with edit mode support
    if (config.type == DashboardWidgetType.custom && config.schemaId != null) {
      return _buildCustomWidgetCard(config, reorderIndex: reorderIndex);
    }

    final content = _getWidgetContent(config);
    final trailing = config.type == DashboardWidgetType.signalStrength
        ? buildLiveIndicator(context)
        : null;

    return DashboardWidget(
      config: config,
      isEditMode: _editMode,
      reorderIndex: reorderIndex,
      trailing: trailing,
      onFavorite: () {
        ref.read(dashboardWidgetsProvider.notifier).toggleFavorite(config.id);
      },
      onRemove: () {
        ref.read(dashboardWidgetsProvider.notifier).removeWidget(config.id);
      },
      child: content,
    );
  }

  /// Build a custom widget with edit mode support using the same DashboardWidget wrapper
  Widget _buildCustomWidgetCard(
    DashboardWidgetConfig config, {
    int? reorderIndex,
  }) {
    return Consumer(
      builder: (context, ref, _) {
        final schemaAsync = ref.watch(customWidgetProvider(config.schemaId!));

        return schemaAsync.when(
          data: (schema) {
            if (schema == null) {
              // Schema not found - auto-remove orphaned widget from dashboard
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref
                    .read(dashboardWidgetsProvider.notifier)
                    .removeWidget(config.id);
              });
              // Return empty container while removal is processed
              return const SizedBox.shrink();
            }

            // Use DashboardWidget wrapper with the schema's name and icon
            return DashboardWidget(
              config: config,
              isEditMode: _editMode,
              reorderIndex: reorderIndex,
              customName: schema.name,
              customIcon: _getIconForTemplate(schema.tags),
              showHeader: true, // Always show header like native widgets
              onFavorite: () {
                ref
                    .read(dashboardWidgetsProvider.notifier)
                    .toggleFavorite(config.id);
              },
              onRemove: () {
                ref
                    .read(dashboardWidgetsProvider.notifier)
                    .removeWidget(config.id);
              },
              child: SchemaWidgetContent(schemaId: config.schemaId!),
            );
          },
          loading: () => const SizedBox(
            height: 160,
            child: Center(child: LoadingIndicator(size: 20)),
          ),
          error: (e, _) => DashboardWidget(
            config: config,
            isEditMode: _editMode,
            reorderIndex: reorderIndex,
            customName: 'Error Loading Widget', // lint-allow: hardcoded-string
            customIcon: Icons.error_outline,
            onRemove: () {
              ref
                  .read(dashboardWidgetsProvider.notifier)
                  .removeWidget(config.id);
            },
            child: const SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'Failed to load widget', // lint-allow: hardcoded-string
                  style: TextStyle(color: SemanticColors.disabled),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _getWidgetContent(DashboardWidgetConfig config) {
    // Handle custom schema-based widgets
    if (config.type == DashboardWidgetType.custom && config.schemaId != null) {
      return SchemaWidgetContent(schemaId: config.schemaId!);
    }

    switch (config.type) {
      case DashboardWidgetType.networkOverview:
        return const NetworkOverviewContent();
      case DashboardWidgetType.recentMessages:
        return const RecentMessagesContent();
      case DashboardWidgetType.nearbyNodes:
        return const NearbyNodesContent();
      case DashboardWidgetType.quickCompose:
        return const QuickActionsContent();
      case DashboardWidgetType.channelActivity:
        return const ChannelActivityContent();
      case DashboardWidgetType.meshHealth:
        return const MeshHealthContent();
      case DashboardWidgetType.signalStrength:
        return const SignalStrengthContent();
      case DashboardWidgetType.nodeMap:
        return const NodeMapContent();
      case DashboardWidgetType.environmentMetrics:
        return const EnvironmentMetricsContent();
      case DashboardWidgetType.custom:
        // If no schemaId, show error
        return const Center(
          child: Text(
            'Widget not found', // lint-allow: hardcoded-string
            style: TextStyle(color: SemanticColors.disabled),
          ),
        );
    }
  }

  /// Get the appropriate icon for a custom widget based on its template tags
  IconData _getIconForTemplate(List<String> tags) {
    if (tags.contains('actions')) return Icons.touch_app;
    if (tags.contains('gauge')) return Icons.speed;
    if (tags.contains('info')) return Icons.info_outline;
    if (tags.contains('location')) return Icons.location_on;
    if (tags.contains('environment')) return Icons.thermostat;
    if (tags.contains('status')) return Icons.dashboard;
    return Icons.widgets; // Default fallback
  }

  Widget _buildEmptyDashboard(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.dashboard_customize,
              size: 64,
              color: context.textTertiary.withValues(alpha: 0.5),
            ),
            SizedBox(height: AppTheme.spacing16),
            Text(
              'No Widgets Added', // lint-allow: hardcoded-string
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              'Customize your dashboard with widgets that matter to you', // lint-allow: hardcoded-string
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.textSecondary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppTheme.spacing24),
            ElevatedButton.icon(
              onPressed: () => _showAddWidgetSheet(context),
              icon: Icon(Icons.add, size: 20),
              label: Text(context.l10n.dashboardAddWidgets),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editCustomWidget(String? schemaId) async {
    if (schemaId == null) return;

    final storageService = await ref.read(widgetStorageServiceProvider.future);
    if (!mounted) return;
    final schema = await storageService.getWidget(schemaId);

    if (schema == null || !mounted) return;

    await Navigator.push<WidgetWizardResult>(
      context,
      MaterialPageRoute(
        builder: (context) => WidgetWizardScreen(
          initialSchema: schema,
          onSave: (updated) async {
            await storageService.saveWidget(updated);
          },
        ),
      ),
    );

    // Refresh dashboard to pick up any changes
    safeSetState(() {});
  }

  void _showAddWidgetSheet(BuildContext context) {
    AppBottomSheet.showScrollable(
      context: context,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (scrollController) => _AddWidgetSheet(
        scrollController: scrollController,
        widgetsNotifier: ref.read(dashboardWidgetsProvider.notifier),
        widgetsProvider: dashboardWidgetsProvider,
      ),
    );
  }

  void _showWidgetContextMenu(
    BuildContext context,
    DashboardWidgetConfig config,
  ) {
    final isCustomWidget =
        config.type == DashboardWidgetType.custom && config.schemaId != null;
    final widgetInfo = WidgetRegistry.getInfo(config.type);

    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing8),
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  child: Icon(
                    isCustomWidget ? Icons.widgets : widgetInfo.icon,
                    color: context.accentColor,
                    size: 20,
                  ),
                ),
                SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Text(
                    isCustomWidget
                        ? 'Custom Widget'
                        : widgetInfo.name, // lint-allow: hardcoded-string
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.border),
          // Edit option (only for custom widgets)
          if (isCustomWidget)
            ListTile(
              leading: Icon(Icons.edit, color: context.accentColor),
              title: Text(
                'Edit Widget', // lint-allow: hardcoded-string
                style: TextStyle(color: context.textPrimary),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _editCustomWidget(config.schemaId);
                if (!mounted) return;
              },
            ),
          // Toggle favorite
          ListTile(
            leading: Icon(
              config.isFavorite ? Icons.star : Icons.star_border,
              color: config.isFavorite
                  ? AppTheme.warningYellow
                  : context.textPrimary,
            ),
            title: Text(
              config.isFavorite
                  ? context.l10n.dashboardRemoveFromFavorites
                  : context.l10n.dashboardAddToFavorites,
              style: TextStyle(color: context.textPrimary),
            ),
            onTap: () {
              ref
                  .read(dashboardWidgetsProvider.notifier)
                  .toggleFavorite(config.id);
              Navigator.pop(context);
            },
          ),
          // Edit dashboard mode
          ListTile(
            leading: Icon(
              Icons.dashboard_customize,
              color: context.textPrimary,
            ),
            title: Text(
              'Edit Dashboard', // lint-allow: hardcoded-string
              style: TextStyle(color: context.textPrimary),
            ),
            onTap: () {
              Navigator.pop(context);
              ref
                  .read(dashboardDiscoveryAckProvider.notifier)
                  .dismiss(reason: 'edit_mode_entered');
              setState(() => _editMode = true);
            },
          ),
          // Remove widget
          ListTile(
            leading: const Icon(
              Icons.remove_circle_outline,
              color: AppTheme.errorRed,
            ),
            title: Text(
              context.l10n.dashboardRemoveWidget,
              style: TextStyle(color: AppTheme.errorRed),
            ),
            onTap: () async {
              Navigator.pop(context);
              final shouldRemove = await AppBottomSheet.showConfirm(
                context: context,
                title: context.l10n.dashboardRemoveWidgetTitle,
                message: context.l10n.dashboardRemoveWidgetMessage(
                  widgetInfo.name,
                ),
                confirmLabel: context.l10n.dashboardRemoveConfirm,
                isDestructive: true,
              );
              if (shouldRemove == true) {
                ref
                    .read(dashboardWidgetsProvider.notifier)
                    .removeWidget(config.id);
              }
            },
          ),
          const SizedBox(height: AppTheme.spacing16),
        ],
      ),
    );
  }
}

/// Bottom sheet to add/remove widgets - stays open for multiple operations
class _AddWidgetSheet extends ConsumerWidget {
  final ScrollController scrollController;
  final DashboardWidgetsNotifier widgetsNotifier;
  final NotifierProvider<DashboardWidgetsNotifier, List<DashboardWidgetConfig>>
  widgetsProvider;

  const _AddWidgetSheet({
    required this.scrollController,
    required this.widgetsNotifier,
    required this.widgetsProvider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentConfigs = ref.watch(widgetsProvider);
    final enabledTypes = currentConfigs
        .where((c) => c.isVisible)
        .map((c) => c.type)
        .toSet();
    final hasWidgetPack = ref.watch(
      hasPurchasedProvider(RevenueCatConfig.widgetPackProductId),
    );

    final unusedPremiumCount = _unusedPremiumCount(enabledTypes);
    final showOwnerHint = hasWidgetPack && unusedPremiumCount > 0;

    // Sort widgets: free first, then premium. Source the addable list from
    // the shared helper so the dashboard's "unused premium count" is derived
    // from the same source as what the picker actually offers.
    final sortedTypes = _addableWidgetTypes().toList()
      ..sort((a, b) {
        final aFree = _freeWidgetTypes.contains(a);
        final bFree = _freeWidgetTypes.contains(b);
        if (aFree && !bFree) return -1;
        if (!aFree && bFree) return 1;
        return a.index.compareTo(b.index);
      });

    return Column(
      children: [
        // Header with title and done button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Manage Widgets', // lint-allow: hardcoded-string
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Done',
                  style: TextStyle(
                    color: context.accentColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showOwnerHint)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              AppTheme.spacing4,
              20,
              AppTheme.spacing4,
            ),
            child: Row(
              children: [
                Icon(Icons.lock_open, size: 14, color: context.accentColor),
                SizedBox(width: AppTheme.spacing6),
                Expanded(
                  child: Text(
                    context.l10n.dashboardManageWidgetsPackHint(
                      unusedPremiumCount,
                      _packTitle(ref),
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: context.accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Tap to add or remove widgets from your dashboard', // lint-allow: hardcoded-string
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.textSecondary),
                ),
              ),
              Text(
                '${currentConfigs.length}/${DashboardWidgetsNotifier.maxWidgets}',
                style: TextStyle(
                  fontSize: 13,
                  color:
                      currentConfigs.length >=
                          DashboardWidgetsNotifier.maxWidgets
                      ? AppTheme.errorRed
                      : context.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),
        // Widget list
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            itemCount:
                sortedTypes.length +
                (hasWidgetPack ? 0 : 1), // +1 for upsell card
            itemBuilder: (context, index) {
              // Show upsell card after free widgets
              if (!hasWidgetPack && index == _freeWidgetTypes.length) {
                return _buildUpsellCard(context, ref);
              }

              // Adjust index for items after upsell card
              final typeIndex =
                  !hasWidgetPack && index > _freeWidgetTypes.length
                  ? index - 1
                  : index;
              final type = sortedTypes[typeIndex];
              final isAdded = enabledTypes.contains(type);
              final isFree = _freeWidgetTypes.contains(type);
              final isLocked = !isFree && !hasWidgetPack;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _WidgetOption(
                  type: type,
                  isAdded: isAdded,
                  isLocked: isLocked,
                  onTap: () {
                    // One gate-decision log per user action. Logging
                    // per-itemBuilder-call would emit O(visible widgets)
                    // lines on every list rebuild — too noisy.
                    final entitled = isFree || hasWidgetPack;
                    AppLogging.purchase(
                      'WIDGET_GATE: ${type.name} enabled=$isAdded '
                      'entitled=$entitled isFree=$isFree '
                      'hasWidgetPack=$hasWidgetPack source=picker',
                    );

                    // Locked widgets do nothing - user should tap Unlock button
                    if (isLocked) {
                      AppLogging.purchase(
                        'WIDGET_GATE: blocked reason=isLocked type=${type.name} '
                        'isFree=$isFree hasWidgetPack=$hasWidgetPack',
                      );
                      return;
                    }
                    if (isAdded) {
                      // Find the config and remove it
                      final config = currentConfigs.firstWhere(
                        (c) => c.type == type && c.isVisible,
                      );
                      widgetsNotifier.removeWidget(config.id);
                    } else {
                      // Check limit before adding
                      if (currentConfigs.length >=
                          DashboardWidgetsNotifier.maxWidgets) {
                        showErrorSnackBar(
                          context,
                          'Widget limit reached (${DashboardWidgetsNotifier.maxWidgets} max)', // lint-allow: hardcoded-string
                        );
                        return;
                      }
                      widgetsNotifier.addWidget(type);
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUpsellCard(BuildContext context, WidgetRef ref) {
    final widgetPackName = _packTitle(ref);

    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 8),
      child: GradientBorderContainer(
        borderRadius: 12,
        borderWidth: 2,
        accentOpacity: 0.3,
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                context.accentColor.withValues(alpha: 0.15),
                context.accentColor.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radius12),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radius10),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: context.accentColor,
                  size: 22,
                ),
              ),
              SizedBox(width: AppTheme.spacing14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unlock All Widgets', // lint-allow: hardcoded-string
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    Text(
                      'Get $widgetPackName for ${DashboardWidgetType.values.length - _freeWidgetTypes.length} more widgets', // lint-allow: hardcoded-string
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionScreen(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  backgroundColor: context.accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                ),
                child: Text(
                  'Unlock',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WidgetOption extends StatelessWidget {
  final DashboardWidgetType type;
  final bool isAdded;
  final bool isLocked;
  final VoidCallback onTap;

  const _WidgetOption({
    required this.type,
    required this.isAdded,
    required this.onTap,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final info = WidgetRegistry.getInfo(type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          decoration: BoxDecoration(
            color: context.background,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            border: Border.all(
              color: isAdded
                  ? context.accentColor.withValues(alpha: 0.3)
                  : context.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isLocked
                      ? context.surface.withValues(alpha: 0.5)
                      : isAdded
                      ? context.accentColor.withValues(alpha: 0.15)
                      : context.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radius10),
                ),
                child: Icon(
                  isLocked ? Icons.lock_outline : info.icon,
                  color: isLocked
                      ? context.textTertiary
                      : isAdded
                      ? context.accentColor
                      : context.textSecondary,
                  size: 22,
                ),
              ),
              SizedBox(width: AppTheme.spacing14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            info.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isLocked
                                  ? context.textTertiary
                                  : isAdded
                                  ? context.textPrimary
                                  : context.textSecondary,
                            ),
                          ),
                        ),
                        if (isLocked) ...[
                          SizedBox(width: AppTheme.spacing6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.accentColor.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius4,
                              ),
                            ),
                            child: Text(
                              'PRO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: context.accentColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: AppTheme.spacing2),
                    Text(
                      info.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isLocked
                            ? context.textTertiary
                            : context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Toggle switch style indicator
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isLocked
                      ? context.border.withValues(alpha: 0.5)
                      : isAdded
                      ? context.accentColor
                      : context.border,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isLocked
                      ? Icons.lock
                      : isAdded
                      ? Icons.check
                      : Icons.add,
                  color: isLocked
                      ? context.textTertiary
                      : isAdded
                      ? Colors.black
                      : context.textTertiary,
                  size: isLocked ? 14 : 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
