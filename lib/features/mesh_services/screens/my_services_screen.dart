// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// My Services management screen.
///
/// Lists all local service instances with status badges. Provides
/// create, stop, and delete actions. Entry point from the drawer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/search_filter_header.dart';
import '../../../core/widgets/status_filter_chip.dart';
import '../../../services/haptic_service.dart';
import '../models/mesh_service_instance.dart';
import '../models/mesh_service_template.dart';
import '../providers/mesh_service_providers.dart';
import '../widgets/mesh_service_instance_card.dart';
import '../widgets/mesh_service_status_badge.dart';
import 'service_creation_wizard.dart';

/// My Services screen — manage local service instances.
class MyServicesScreen extends ConsumerStatefulWidget {
  const MyServicesScreen({super.key});

  @override
  ConsumerState<MyServicesScreen> createState() => _MyServicesScreenState();
}

/// Filter options for the My Services list.
enum _ServiceFilter { all, active, expired, stopped }

class _MyServicesScreenState extends ConsumerState<MyServicesScreen>
    with LifecycleSafeMixin {
  String _searchQuery = '';
  _ServiceFilter _activeFilter = _ServiceFilter.all;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final instancesAsync = ref.watch(meshServiceInstancesProvider);

    return GlassScaffold(
      title: l10n.meshServicesTitle,
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => _onCreateTap(context),
          tooltip: l10n.meshServicesCreateAction,
        ),
      ],
      slivers: [
        instancesAsync.when(
          data: (instances) {
            if (instances.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(context, l10n),
              );
            }

            // Compute counts before filtering.
            final activeCount = instances
                .where((i) => i.effectiveStatus == MeshServiceStatus.active)
                .length;
            final expiredCount = instances
                .where((i) => i.effectiveStatus == MeshServiceStatus.expired)
                .length;
            final stoppedCount = instances
                .where((i) => i.effectiveStatus == MeshServiceStatus.stopped)
                .length;

            // Apply filter.
            var filtered = _applyFilter(instances);

            // Apply search.
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              filtered = filtered
                  .where((i) => i.title.toLowerCase().contains(query))
                  .toList();
            }

            return SliverMainAxisGroup(
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: SearchFilterHeaderDelegate(
                    searchController: _searchController,
                    searchQuery: _searchQuery,
                    onSearchChanged: (value) =>
                        setState(() => _searchQuery = value),
                    hintText: l10n.meshServicesSearchHint,
                    textScaler: MediaQuery.textScalerOf(context),
                    rebuildKey: Object.hashAll([
                      _activeFilter,
                      instances.length,
                      activeCount,
                      expiredCount,
                      stoppedCount,
                    ]),
                    filterChips: [
                      StatusFilterChip(
                        label: l10n.meshServicesFilterAll,
                        count: instances.length,
                        isSelected: _activeFilter == _ServiceFilter.all,
                        onTap: () =>
                            setState(() => _activeFilter = _ServiceFilter.all),
                      ),
                      StatusFilterChip(
                        label: l10n.meshServicesFilterActive,
                        count: activeCount,
                        isSelected: _activeFilter == _ServiceFilter.active,
                        color: AccentColors.green,
                        onTap: () => setState(
                          () => _activeFilter = _ServiceFilter.active,
                        ),
                      ),
                      StatusFilterChip(
                        label: l10n.meshServicesFilterExpired,
                        count: expiredCount,
                        isSelected: _activeFilter == _ServiceFilter.expired,
                        color: AccentColors.orange,
                        onTap: () => setState(
                          () => _activeFilter = _ServiceFilter.expired,
                        ),
                      ),
                      StatusFilterChip(
                        label: l10n.meshServicesFilterStopped,
                        count: stoppedCount,
                        isSelected: _activeFilter == _ServiceFilter.stopped,
                        color: AccentColors.slate,
                        onTap: () => setState(
                          () => _activeFilter = _ServiceFilter.stopped,
                        ),
                      ),
                    ],
                  ),
                ),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        l10n.meshServicesNoResults,
                        style: context.bodySmallStyle?.copyWith(
                          color: context.textTertiary,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing16,
                      vertical: AppTheme.spacing8,
                    ),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppTheme.spacing8),
                      itemBuilder: (context, index) {
                        final instance = filtered[index];
                        return MeshServiceInstanceCard(
                          instance: instance,
                          onTap: () => _onInstanceTap(context, instance),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
          loading: () => const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const SliverFillRemaining(
            hasScrollBody: false,
            child: SizedBox.shrink(),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacing48)),
      ],
    );
  }

  List<MeshServiceInstance> _applyFilter(List<MeshServiceInstance> instances) {
    switch (_activeFilter) {
      case _ServiceFilter.all:
        return instances;
      case _ServiceFilter.active:
        return instances
            .where((i) => i.effectiveStatus == MeshServiceStatus.active)
            .toList();
      case _ServiceFilter.expired:
        return instances
            .where((i) => i.effectiveStatus == MeshServiceStatus.expired)
            .toList();
      case _ServiceFilter.stopped:
        return instances
            .where((i) => i.effectiveStatus == MeshServiceStatus.stopped)
            .toList();
    }
  }

  Widget _buildEmptyState(BuildContext context, dynamic l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.miscellaneous_services_outlined,
              size: 40,
              color: context.textTertiary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              l10n.meshServicesEmpty as String,
              style: context.bodyStyle?.copyWith(color: context.textSecondary),
            ),
            const SizedBox(height: AppTheme.spacing4),
            Text(
              l10n.meshServicesEmptyDescription as String,
              style: context.bodySmallStyle?.copyWith(
                color: context.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing16),
            FilledButton(
              onPressed: () => _onCreateTap(context),
              child: Text(l10n.meshServicesCreateAction as String),
            ),
          ],
        ),
      ),
    );
  }

  void _onCreateTap(BuildContext context) {
    ref.read(hapticServiceProvider).trigger(HapticType.light);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ServiceCreationWizard()),
    );
  }

  void _onInstanceTap(BuildContext context, MeshServiceInstance instance) {
    ref.read(hapticServiceProvider).trigger(HapticType.light);
    AppBottomSheet.show(
      context: context,
      child: _InstanceDetailSheet(instance: instance),
    );
  }
}

/// Bottom sheet showing instance details with actions.
class _InstanceDetailSheet extends ConsumerWidget {
  final MeshServiceInstance instance;

  const _InstanceDetailSheet({required this.instance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final resolved = MeshServiceCatalog.resolve(
      canonicalType: instance.canonicalType,
      presetId: instance.presetId,
    );
    final accent = resolved.accentColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header: icon + title + status
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radius12),
              ),
              child: Icon(resolved.icon, size: 24, color: accent),
            ),
            const SizedBox(width: AppTheme.spacing16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    instance.title,
                    style: context.titleSmallStyle?.copyWith(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppTheme.spacing4),
                  Row(
                    children: [
                      MeshServiceStatusBadge(status: instance.effectiveStatus),
                      if (instance.remainingDuration != null &&
                          instance.isActive) ...[
                        const SizedBox(width: AppTheme.spacing8),
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: context.textTertiary,
                        ),
                        const SizedBox(width: AppTheme.spacing4),
                        Text(
                          _formatDuration(instance.remainingDuration!, l10n),
                          style: context.bodySmallStyle?.copyWith(
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        // Description
        if (instance.description.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacing16),
          Text(
            instance.description,
            style: context.bodySecondaryStyle?.copyWith(
              color: context.textSecondary,
              height: 1.4,
            ),
          ),
        ],

        const SizedBox(height: AppTheme.spacing24),

        // Actions section label
        Text(
          l10n.meshServicesActionsLabel.toUpperCase(),
          style: context.bodySmallStyle?.copyWith(
            color: context.textTertiary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AppTheme.spacing8),

        // Actions
        if (instance.isActive)
          _ActionRow(
            icon: Icons.stop_outlined,
            label: l10n.meshServicesStopAction,
            color: SemanticColors.error,
            onTap: () => _onStop(context, ref),
          ),
        _ActionRow(
          icon: Icons.delete_outline,
          label: l10n.meshServicesDeleteAction,
          color: SemanticColors.error,
          onTap: () => _onDelete(context, ref),
        ),
      ],
    );
  }

  Future<void> _onStop(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final engine = ref.read(meshServiceEngineProvider);
    final haptics = ref.read(hapticServiceProvider);

    final confirmed = await AppBottomSheet.show<bool>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.meshServicesStopConfirm,
            style: context.bodySecondaryStyle?.copyWith(
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.meshServicesCancelAction),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.meshServicesConfirmAction),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop(); // Pop the detail sheet
      await haptics.destructive();
      await engine?.stopInstance(instance.instanceId);
    }
  }

  Future<void> _onDelete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final engine = ref.read(meshServiceEngineProvider);
    final haptics = ref.read(hapticServiceProvider);

    final confirmed = await AppBottomSheet.show<bool>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.meshServicesDeleteConfirm,
            style: context.bodySecondaryStyle?.copyWith(
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.meshServicesCancelAction),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.meshServicesConfirmAction),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop(); // Pop the detail sheet
      await haptics.destructive();
      await engine?.deleteInstance(instance.instanceId);
    }
  }

  String _formatDuration(Duration duration, dynamic l10n) {
    if (duration.inHours > 0) {
      return l10n.meshServicesDurationHours(duration.inHours) as String;
    }
    return l10n.meshServicesDurationMinutes(duration.inMinutes) as String;
  }
}

/// Styled action row matching the Mesh Explorer detail sheet pattern.
class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.spacing10,
            horizontal: AppTheme.spacing4,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color.withValues(alpha: 0.8)),
              const SizedBox(width: AppTheme.spacing12),
              Text(
                label,
                style: context.bodyStyle?.copyWith(
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
