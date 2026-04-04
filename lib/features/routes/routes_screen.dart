// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: keyboard-dismissal — text inputs are only in bottom sheet sub-widget
import 'dart:io';
import 'dart:async';

import 'package:flutter/services.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/time_format.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/animations.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/gradient_border_container.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../models/route.dart' as route_model;
import '../../providers/app_providers.dart';
import '../../providers/telemetry_providers.dart';
import '../../utils/share_utils.dart';
import '../../utils/snackbar.dart';

/// Screen showing saved routes and route recording
class RoutesScreen extends ConsumerStatefulWidget {
  const RoutesScreen({super.key});

  @override
  ConsumerState<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends ConsumerState<RoutesScreen>
    with LifecycleSafeMixin {
  @override
  Widget build(BuildContext context) {
    final routes = ref.watch(routesProvider);
    final activeRoute = ref.watch(activeRouteProvider);
    final animationsEnabled = ref.watch(animationsEnabledProvider);

    return HelpTourController(
      topicId: 'routes_overview',
      stepKeys: const {},
      child: GlassScaffold(
        title: context.l10n.routesScreenTitle,
        actions: [
          IcoHelpAppBarButton(topicId: 'routes_overview'),
          AppBarOverflowMenu<String>(
            onSelected: (value) {
              switch (value) {
                case 'start':
                  _startRecording();
                  break;
                case 'import':
                  _importRoute();
                  break;
              }
            },
            itemBuilder: (context) => [
              if (activeRoute == null)
                PopupMenuItem<String>(
                  value: 'start',
                  child: Row(
                    children: [
                      Icon(
                        Icons.play_arrow,
                        color: AccentColors.green,
                        size: 20,
                      ),
                      const SizedBox(width: AppTheme.spacing12),
                      Text(context.l10n.routesStartRoute),
                    ],
                  ),
                ),
              PopupMenuItem<String>(
                value: 'import',
                child: Row(
                  children: [
                    Icon(
                      Icons.file_upload_outlined,
                      color: context.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.spacing12),
                    Text(context.l10n.routesImportGpx),
                  ],
                ),
              ),
            ],
          ),
        ],
        slivers: [
          // Active recording banner
          if (activeRoute != null)
            SliverToBoxAdapter(child: _ActiveRouteBanner(route: activeRoute)),

          // Routes list or empty state
          if (routes.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final route = routes[index];
                  return Perspective3DSlide(
                    index: index,
                    direction: SlideDirection.left,
                    enabled: animationsEnabled,
                    child: _RouteCard(
                      route: route,
                      onTap: () => _viewRoute(route),
                      onDelete: () => _deleteRoute(route),
                      onExport: () => _exportRoute(route),
                    ),
                  );
                }, childCount: routes.length),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.route_outlined, size: 80, color: context.textTertiary),
          const SizedBox(height: AppTheme.spacing24),
          Text(
            context.l10n.routesEmptyTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            context.l10n.routesEmptyDescription,
            style: context.bodySecondaryStyle?.copyWith(
              color: context.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  void _startRecording() {
    AppBottomSheet.show(
      context: context,
      child: _NewRouteSheet(
        onStart: (name, notes, color) {
          ref
              .read(activeRouteProvider.notifier)
              .startRecording(name, notes: notes, color: color);
        },
      ),
    );
  }

  void _viewRoute(route_model.Route route) {
    Navigator.pushNamed(context, '/route-detail', arguments: route);
  }

  void _deleteRoute(route_model.Route route) async {
    final l10n = context.l10n;
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.routesDeleteConfirmTitle,
      message: l10n.routesDeleteConfirmMessage(route.name),
      confirmLabel: l10n.routesDeleteConfirmAction,
      isDestructive: true,
    );
    if (!mounted) return;

    if (confirmed == true) {
      ref.read(routesProvider.notifier).deleteRoute(route.id);
    }
  }

  void _exportRoute(route_model.Route route) async {
    final l10n = context.l10n;
    final storageAsync = ref.read(routeStorageProvider);
    final storage = storageAsync.value;
    if (storage == null) return;

    // Get the render box for sharePositionOrigin (required on iPad) before async
    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 100, 100);

    final gpx = storage.exportRouteAsGpx(route);
    final fileName =
        '${route.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.gpx';

    // Capture share position before async gap
    final safePosition = getSafeSharePosition(context, sharePositionOrigin);

    try {
      // Save to temp file and share as file for proper save-to-files behavior
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(gpx);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: fileName,
        text: l10n.routesShareText(route.name),
        sharePositionOrigin: safePosition,
      );
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, l10n.routesExportFailed(e.toString()));
      }
    }
  }

  Future<void> _importRoute() async {
    // Capture providers before async gap
    final l10n = context.l10n;
    final storageAsync = ref.read(routeStorageProvider);
    final routesNotifier = ref.read(routesProvider.notifier);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gpx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        if (mounted) {
          showErrorSnackBar(context, l10n.routesFileReadFailed);
        }
        return;
      }

      final gpxContent = String.fromCharCodes(file.bytes!);
      final storage = storageAsync.value;
      if (storage == null) return;

      final importedRoute = storage.importRouteFromGpx(gpxContent);
      if (importedRoute != null) {
        await routesNotifier.saveRoute(importedRoute);
        if (mounted) {
          showSuccessSnackBar(
            context,
            l10n.routesImportSuccess(importedRoute.name),
          );
        }
      } else {
        if (mounted) {
          showErrorSnackBar(context, l10n.routesInvalidGpxFile);
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, l10n.routesImportFailed(e.toString()));
      }
    }
  }
}

class _ActiveRouteBanner extends ConsumerStatefulWidget {
  final route_model.Route route;

  const _ActiveRouteBanner({required this.route});

  @override
  ConsumerState<_ActiveRouteBanner> createState() => _ActiveRouteBannerState();
}

class _ActiveRouteBannerState extends ConsumerState<_ActiveRouteBanner>
    with LifecycleSafeMixin<_ActiveRouteBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Update every second to show live elapsed time
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      safeSetState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    return Container(
      margin: const EdgeInsets.all(AppTheme.spacing16),
      child: GradientBorderContainer(
        borderRadius: 16,
        borderWidth: 2,
        accentColor: AccentColors.green,
        accentOpacity: 0.5,
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AccentColors.green.withValues(alpha: 0.3),
                AccentColors.teal.withValues(alpha: 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radius14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AccentColors.green,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AccentColors.green.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Text(
                    context.l10n.routesRecordingLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AccentColors.green,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    context.l10n.routesPointCount(route.locations.length),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing12),
              Text(
                route.name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spacing4),
              Text(
                context.l10n.routesDistanceDuration(
                  _formatDistance(route.totalDistance),
                  _formatDuration(DateTime.now().difference(route.createdAt)),
                ),
                style: context.bodySecondaryStyle?.copyWith(
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        ref
                            .read(activeRouteProvider.notifier)
                            .cancelRecording();
                      },
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: Text(
                        context.l10n.routesCancelRecording,
                        style: TextStyle(color: Colors.white),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.errorRed,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        final completed = await ref
                            .read(activeRouteProvider.notifier)
                            .stopRecording();
                        if (!mounted) return;
                        if (completed != null) {
                          ref.read(routesProvider.notifier).refresh();
                        }
                      },
                      icon: const Icon(Icons.stop, size: 18),
                      label: Text(context.l10n.routesStopRecording),
                      style: FilledButton.styleFrom(
                        backgroundColor: AccentColors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return context.l10n.routesDistanceMeters(meters.toStringAsFixed(0));
    }
    return context.l10n.routesDistanceKilometers(
      (meters / 1000).toStringAsFixed(2),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return context.l10n.routesDurationSeconds(duration.inSeconds);
    }
    if (duration.inMinutes < 60) {
      return context.l10n.routesDurationMinutesSeconds(
        duration.inMinutes,
        duration.inSeconds % 60,
      );
    }
    return context.l10n.routesDurationHoursMinutes(
      duration.inHours,
      duration.inMinutes % 60,
    );
  }
}

class _RouteCard extends StatelessWidget {
  final route_model.Route route;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onExport;

  const _RouteCard({
    required this.route,
    required this.onTap,
    required this.onDelete,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = AppTimeFormat.fullDateBulletTime(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(route.color),
                        borderRadius: BorderRadius.circular(AppTheme.radius2),
                      ),
                    ),
                    SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            route.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing2),
                          Text(
                            dateFormat.format(route.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppBarOverflowMenu<String>(
                      onSelected: (value) {
                        if (value == 'export') onExport();
                        if (value == 'delete') onDelete();
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'export',
                          child: Row(
                            children: [
                              Icon(Icons.file_download, size: 18),
                              SizedBox(width: AppTheme.spacing8),
                              Text(context.l10n.routesExportGpx),
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
                              SizedBox(width: AppTheme.spacing8),
                              Text(
                                context.l10n.routesDeleteAction,
                                style: TextStyle(color: AppTheme.errorRed),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing12),
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.straighten,
                      value: _formatDistance(context, route.totalDistance),
                    ),
                    const SizedBox(width: AppTheme.spacing16),
                    if (route.duration != null)
                      _StatChip(
                        icon: Icons.timer_outlined,
                        value: _formatDuration(context, route.duration!),
                      ),
                    const SizedBox(width: AppTheme.spacing16),
                    _StatChip(
                      icon: Icons.terrain,
                      value: context.l10n.routesElevationGain(
                        route.elevationGain.toStringAsFixed(0),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing16),
                    _StatChip(
                      icon: Icons.location_on,
                      value: context.l10n.routesPointsShort(
                        route.locations.length,
                      ),
                    ),
                  ],
                ),
                if (route.notes != null && route.notes!.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacing12),
                  Text(
                    route.notes!,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDistance(BuildContext context, double meters) {
    if (meters < 1000) {
      return context.l10n.routesDistanceMeters(meters.toStringAsFixed(0));
    }
    return context.l10n.routesDistanceKilometers(
      (meters / 1000).toStringAsFixed(2),
    );
  }

  String _formatDuration(BuildContext context, Duration duration) {
    if (duration.inMinutes < 60) {
      return context.l10n.routesCardDurationMinutes(duration.inMinutes);
    }
    return context.l10n.routesCardDurationHoursMinutes(
      duration.inHours,
      duration.inMinutes % 60,
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;

  const _StatChip({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AccentColors.blue),
        const SizedBox(width: AppTheme.spacing4),
        Text(
          value,
          style: context.bodySmallStyle?.copyWith(color: context.textSecondary),
        ),
      ],
    );
  }
}

class _NewRouteSheet extends StatefulWidget {
  final void Function(String name, String? notes, int color) onStart;

  const _NewRouteSheet({required this.onStart});

  @override
  State<_NewRouteSheet> createState() => _NewRouteSheetState();
}

class _NewRouteSheetState extends State<_NewRouteSheet> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  int _selectedColor = 0xFF33C758;

  final _colors = [
    0xFF33C758, // Green
    0xFF007AFF, // Blue
    0xFFFF9500, // Orange
    0xFFFF3B30, // Red
    0xFF5856D6, // Purple
    0xFF00C7BE, // Teal
    0xFFFFCC00, // Yellow
    0xFFAF52DE, // Pink
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BottomSheetHeader(
          icon: Icons.route,
          iconColor: AccentColors.green,
          title: context.l10n.routesNewRouteTitle,
          subtitle: context.l10n.routesNewRouteSubtitle,
        ),
        const SizedBox(height: AppTheme.spacing24),
        BottomSheetTextField(
          maxLength: 100,
          controller: _nameController,
          label: context.l10n.routesRouteNameLabel,
          hint: context.l10n.routesRouteNameHint,
          autofocus: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppTheme.spacing16),
        BottomSheetTextField(
          maxLength: 500,
          controller: _notesController,
          label: context.l10n.routesNotesLabel,
          hint: context.l10n.routesNotesHint,
          maxLines: 2,
        ),
        const SizedBox(height: AppTheme.spacing20),
        Text(
          context.l10n.routesColorLabel,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _colors.map((color) {
            final isSelected = color == _selectedColor;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedColor = color);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(color),
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Color(color).withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 20, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppTheme.spacing24),
        BottomSheetButtons(
          cancelLabel: context.l10n.routesCancel,
          confirmLabel: context.l10n.routesStart,
          isConfirmEnabled: _nameController.text.trim().isNotEmpty,
          onConfirm: () {
            widget.onStart(
              _nameController.text.trim(),
              _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
              _selectedColor,
            );
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
