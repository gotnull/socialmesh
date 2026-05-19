// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../dashboard/widgets/dashboard_widget.dart';
import '../../navigation/meshcore_shell.dart';
import 'models/meshcore_dashboard_widget_config.dart';
import 'providers/meshcore_dashboard_providers.dart';
import 'widgets/meshcore_dashboard_widget_frame.dart';
import 'widgets/meshcore_nearby_contacts_content.dart';
import 'widgets/meshcore_network_overview_content.dart';
import 'widgets/meshcore_quick_actions_content.dart';
import 'widgets/meshcore_recent_messages_content.dart';

// MeshCore-side Dashboard screen. Full 1:1 mirror of the Meshtastic
// `WidgetDashboardScreen`: ReorderableListView body, edit-mode toggle,
// drag-handle, favorites, remove confirmation, add-widget sheet,
// context menu, and dashed edit-mode add tile. Content comes from
// MeshCore providers (`meshCoreContactsProvider`,
// `meshCoreChannelsProvider`, `linkStatusProvider`) but every frame
// primitive matches the Meshtastic side.
class MeshCoreDashboardScreen extends ConsumerStatefulWidget {
  const MeshCoreDashboardScreen({super.key});

  @override
  ConsumerState<MeshCoreDashboardScreen> createState() =>
      _MeshCoreDashboardScreenState();
}

class _MeshCoreDashboardScreenState
    extends ConsumerState<MeshCoreDashboardScreen>
    with LifecycleSafeMixin {
  bool _editMode = false;

  @override
  Widget build(BuildContext context) {
    final widgetConfigs = ref.watch(meshCoreDashboardWidgetsProvider);
    final l10n = context.l10n;

    return GlassScaffold.body(
      hasScrollBody: true,
      leading: const MeshCoreHamburgerMenuButton(),
      centerTitle: true,
      title: _editMode ? l10n.dashboardEditTitle : l10n.meshcoreDashboardTitle,
      actions: [
        IconButton(
          icon: Icon(Icons.add, color: context.accentColor),
          onPressed: () => _showAddWidgetSheet(context),
          tooltip: l10n.dashboardAddWidget,
        ),
        if (!_editMode) ...[
          const MeshCoreDeviceStatusButton(),
        ] else ...[
          TextButton(
            onPressed: () => safeSetState(() => _editMode = false),
            child: Text(
              l10n.dashboardDone,
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
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    List<MeshCoreDashboardWidgetConfig> widgetConfigs,
  ) {
    final enabledWidgets = widgetConfigs.where((w) => w.isVisible).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    if (enabledWidgets.isEmpty && !_editMode) {
      return _buildEmptyDashboard(context);
    }

    final showEditAddTile =
        _editMode &&
        enabledWidgets.length < MeshCoreDashboardWidgetsNotifier.maxWidgets &&
        enabledWidgets.length < MeshCoreDashboardWidgetType.values.length;

    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            padding: EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              AppTheme.spacing16,
              AppTheme.spacing16,
              showEditAddTile ? AppTheme.spacing8 : AppTheme.spacing16,
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
                  .read(meshCoreDashboardWidgetsProvider.notifier)
                  .reorder(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final config = enabledWidgets[index];
              return Padding(
                key: ValueKey(config.id),
                padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
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
        if (showEditAddTile) _buildEditModeAddTile(context),
      ],
    );
  }

  Widget _buildEditModeAddTile(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing8,
        AppTheme.spacing16,
        AppTheme.spacing16,
      ),
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

  Widget _buildWidgetCard(
    MeshCoreDashboardWidgetConfig config, {
    int? reorderIndex,
  }) {
    return MeshCoreDashboardWidgetFrame(
      config: config,
      isEditMode: _editMode,
      reorderIndex: reorderIndex,
      onFavorite: () {
        ref
            .read(meshCoreDashboardWidgetsProvider.notifier)
            .toggleFavorite(config.id);
      },
      onRemove: () {
        ref
            .read(meshCoreDashboardWidgetsProvider.notifier)
            .removeWidget(config.id);
      },
      child: _getWidgetContent(config),
    );
  }

  Widget _getWidgetContent(MeshCoreDashboardWidgetConfig config) {
    switch (config.type) {
      case MeshCoreDashboardWidgetType.networkOverview:
        return const MeshCoreNetworkOverviewContent();
      case MeshCoreDashboardWidgetType.quickActions:
        return const MeshCoreQuickActionsContent();
      case MeshCoreDashboardWidgetType.nearbyContacts:
        return const MeshCoreNearbyContactsContent();
      case MeshCoreDashboardWidgetType.recentMessages:
        return const MeshCoreRecentMessagesContent();
    }
  }

  Widget _buildEmptyDashboard(BuildContext context) {
    final l10n = context.l10n;
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
              l10n.meshcoreDashboardEmptyTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              l10n.meshcoreDashboardEmptyMessage,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.textSecondary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppTheme.spacing24),
            ElevatedButton.icon(
              onPressed: () => _showAddWidgetSheet(context),
              icon: Icon(Icons.add, size: 20),
              label: Text(l10n.dashboardAddWidgets),
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

  void _showAddWidgetSheet(BuildContext context) {
    AppBottomSheet.showScrollable(
      context: context,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (scrollController) =>
          _MeshCoreAddWidgetSheet(scrollController: scrollController),
    );
  }

  void _showWidgetContextMenu(
    BuildContext context,
    MeshCoreDashboardWidgetConfig config,
  ) {
    final info = MeshCoreWidgetRegistry.getInfo(config.type);
    final l10n = context.l10n;

    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                  child: Icon(info.icon, color: context.accentColor, size: 20),
                ),
                SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Text(
                    _localizedWidgetName(context, config.type),
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
          ListTile(
            leading: Icon(
              config.isFavorite ? Icons.star : Icons.star_border,
              color: config.isFavorite
                  ? AppTheme.warningYellow
                  : context.textPrimary,
            ),
            title: Text(
              config.isFavorite
                  ? l10n.dashboardRemoveFromFavorites
                  : l10n.dashboardAddToFavorites,
              style: TextStyle(color: context.textPrimary),
            ),
            onTap: () {
              ref
                  .read(meshCoreDashboardWidgetsProvider.notifier)
                  .toggleFavorite(config.id);
              safeNavigatorPop();
            },
          ),
          ListTile(
            leading: Icon(
              Icons.dashboard_customize,
              color: context.textPrimary,
            ),
            title: Text(
              l10n.dashboardEditTitle,
              style: TextStyle(color: context.textPrimary),
            ),
            onTap: () {
              safeNavigatorPop();
              safeSetState(() => _editMode = true);
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.remove_circle_outline,
              color: AppTheme.errorRed,
            ),
            title: Text(
              l10n.dashboardRemoveWidget,
              style: TextStyle(color: AppTheme.errorRed),
            ),
            onTap: () async {
              safeNavigatorPop();
              final shouldRemove = await AppBottomSheet.showConfirm(
                context: context,
                title: l10n.dashboardRemoveWidgetTitle,
                message: l10n.dashboardRemoveWidgetMessage(
                  _localizedWidgetName(context, config.type),
                ),
                confirmLabel: l10n.dashboardRemoveConfirm,
                isDestructive: true,
              );
              if (!mounted) return;
              if (shouldRemove == true) {
                ref
                    .read(meshCoreDashboardWidgetsProvider.notifier)
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

String _localizedWidgetName(
  BuildContext context,
  MeshCoreDashboardWidgetType type,
) {
  final l10n = context.l10n;
  switch (type) {
    case MeshCoreDashboardWidgetType.networkOverview:
      return l10n.meshcoreWidgetNetworkOverviewName;
    case MeshCoreDashboardWidgetType.quickActions:
      return l10n.meshcoreWidgetQuickActionsName;
    case MeshCoreDashboardWidgetType.nearbyContacts:
      return l10n.meshcoreWidgetNearbyContactsName;
    case MeshCoreDashboardWidgetType.recentMessages:
      return l10n.meshcoreWidgetRecentMessagesName;
  }
}

String _localizedWidgetDescription(
  BuildContext context,
  MeshCoreDashboardWidgetType type,
) {
  final l10n = context.l10n;
  switch (type) {
    case MeshCoreDashboardWidgetType.networkOverview:
      return l10n.meshcoreWidgetNetworkOverviewDescription;
    case MeshCoreDashboardWidgetType.quickActions:
      return l10n.meshcoreWidgetQuickActionsDescription;
    case MeshCoreDashboardWidgetType.nearbyContacts:
      return l10n.meshcoreWidgetNearbyContactsDescription;
    case MeshCoreDashboardWidgetType.recentMessages:
      return l10n.meshcoreWidgetRecentMessagesDescription;
  }
}

class _MeshCoreAddWidgetSheet extends ConsumerWidget {
  final ScrollController scrollController;

  const _MeshCoreAddWidgetSheet({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentConfigs = ref.watch(meshCoreDashboardWidgetsProvider);
    final enabledTypes = currentConfigs
        .where((c) => c.isVisible)
        .map((c) => c.type)
        .toSet();
    final l10n = context.l10n;

    final sortedTypes = MeshCoreDashboardWidgetType.values.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.meshcoreDashboardManageWidgetsTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  l10n.dashboardDone,
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.meshcoreDashboardManageWidgetsHint,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.textSecondary),
                ),
              ),
              Text(
                '${currentConfigs.length}/${MeshCoreDashboardWidgetsNotifier.maxWidgets}',
                style: TextStyle(
                  fontSize: 13,
                  color:
                      currentConfigs.length >=
                          MeshCoreDashboardWidgetsNotifier.maxWidgets
                      ? AppTheme.errorRed
                      : context.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: EdgeInsets.only(
              left: AppTheme.spacing16,
              right: AppTheme.spacing16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            itemCount: sortedTypes.length,
            itemBuilder: (context, index) {
              final type = sortedTypes[index];
              final isAdded = enabledTypes.contains(type);

              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
                child: _MeshCoreWidgetOption(
                  type: type,
                  isAdded: isAdded,
                  onTap: () {
                    if (isAdded) {
                      final config = currentConfigs.firstWhere(
                        (c) => c.type == type && c.isVisible,
                      );
                      ref
                          .read(meshCoreDashboardWidgetsProvider.notifier)
                          .removeWidget(config.id);
                    } else {
                      if (currentConfigs.length >=
                          MeshCoreDashboardWidgetsNotifier.maxWidgets) {
                        return;
                      }
                      ref
                          .read(meshCoreDashboardWidgetsProvider.notifier)
                          .addWidget(type);
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
}

class _MeshCoreWidgetOption extends StatelessWidget {
  final MeshCoreDashboardWidgetType type;
  final bool isAdded;
  final VoidCallback onTap;

  const _MeshCoreWidgetOption({
    required this.type,
    required this.isAdded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final info = MeshCoreWidgetRegistry.getInfo(type);
    final name = _localizedWidgetName(context, type);
    final description = _localizedWidgetDescription(context, type);

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
                  color: isAdded
                      ? context.accentColor.withValues(alpha: 0.15)
                      : context.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radius10),
                ),
                child: Icon(
                  info.icon,
                  color: isAdded ? context.accentColor : context.textSecondary,
                  size: 22,
                ),
              ),
              SizedBox(width: AppTheme.spacing14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isAdded
                            ? context.textPrimary
                            : context.textSecondary,
                      ),
                    ),
                    SizedBox(height: AppTheme.spacing2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isAdded ? context.accentColor : context.border,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAdded ? Icons.check : Icons.add,
                  color: isAdded ? Colors.black : context.textTertiary,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
