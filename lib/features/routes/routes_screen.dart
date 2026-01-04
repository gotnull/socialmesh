import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../models/route.dart' as route_model;
import '../../providers/app_providers.dart';
import '../../providers/telemetry_providers.dart';
import '../../utils/share_utils.dart';
import '../../utils/snackbar.dart';
import '../navigation/main_shell.dart';

/// Screen showing saved routes and route recording
class RoutesScreen extends ConsumerStatefulWidget {
  const RoutesScreen({super.key});

  @override
  ConsumerState<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends ConsumerState<RoutesScreen> {
  @override
  Widget build(BuildContext context) {
    final routes = ref.watch(routesProvider);
    final activeRoute = ref.watch(activeRouteProvider);

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        leading: const HamburgerMenuButton(),
        centerTitle: true,
        title: Text(
          'Routes',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Import GPX',
            onPressed: _importRoute,
          ),
        ],
      ),
      body: Column(
        children: [
          // Active recording banner
          if (activeRoute != null) _ActiveRouteBanner(route: activeRoute),

          // Routes list
          Expanded(
            child: routes.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: routes.length,
                    itemBuilder: (context, index) {
                      final route = routes[index];
                      final animationsEnabled = ref.watch(
                        animationsEnabledProvider,
                      );
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
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: activeRoute == null
          ? FloatingActionButton.extended(
              onPressed: _startRecording,
              backgroundColor: AccentColors.green,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Route'),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.route_outlined, size: 80, color: context.textTertiary),
          const SizedBox(height: 24),
          Text(
            'No Routes Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Record your first route or import a GPX file',
            style: TextStyle(fontSize: 14, color: context.textTertiary),
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
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: 'Delete Route?',
      message:
          'Are you sure you want to delete "${route.name}"? This cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirmed == true) {
      ref.read(routesProvider.notifier).deleteRoute(route.id);
    }
  }

  void _exportRoute(route_model.Route route) async {
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
        text: 'Route: ${route.name}',
        sharePositionOrigin: safePosition,
      );
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Export failed: $e');
      }
    }
  }

  Future<void> _importRoute() async {
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
          showErrorSnackBar(context, 'Failed to read file');
        }
        return;
      }

      final gpxContent = String.fromCharCodes(file.bytes!);
      final storageAsync = ref.read(routeStorageProvider);
      final storage = storageAsync.value;
      if (storage == null) return;

      final importedRoute = storage.importRouteFromGpx(gpxContent);
      if (importedRoute != null) {
        await ref.read(routesProvider.notifier).saveRoute(importedRoute);
        if (mounted) {
          showSuccessSnackBar(context, 'Imported: ${importedRoute.name}');
        }
      } else {
        if (mounted) {
          showErrorSnackBar(context, 'Invalid GPX file');
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Import failed: $e');
      }
    }
  }
}

class _ActiveRouteBanner extends ConsumerWidget {
  final route_model.Route route;

  const _ActiveRouteBanner({required this.route});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AccentColors.green.withValues(alpha: 0.3),
            AccentColors.teal.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AccentColors.green.withValues(alpha: 0.5)),
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
              const SizedBox(width: 8),
              const Text(
                'Recording',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AccentColors.green,
                ),
              ),
              const Spacer(),
              Text(
                '${route.locations.length} points',
                style: TextStyle(fontSize: 12, color: context.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            route.name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatDistance(route.totalDistance)} • ${_formatDuration(DateTime.now().difference(route.createdAt))}',
            style: TextStyle(fontSize: 14, color: context.textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    ref.read(activeRouteProvider.notifier).cancelRecording();
                  },
                  icon: const Icon(Icons.close, size: 18, color: Colors.white),
                  label: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.errorRed,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    final completed = await ref
                        .read(activeRouteProvider.notifier)
                        .stopRecording();
                    if (completed != null) {
                      ref.read(routesProvider.notifier).refresh();
                    }
                  },
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('Stop'),
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
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}m';
    }
    return '${(meters / 1000).toStringAsFixed(2)}km';
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    }
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    }
    return '${duration.inHours}h ${duration.inMinutes % 60}m';
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
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(width: 12),
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
                          const SizedBox(height: 2),
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
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: context.textTertiary),
                      color: context.card,
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
                              SizedBox(width: 8),
                              Text('Export GPX'),
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
                              SizedBox(width: 8),
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.straighten,
                      value: _formatDistance(route.totalDistance),
                    ),
                    const SizedBox(width: 16),
                    if (route.duration != null)
                      _StatChip(
                        icon: Icons.timer_outlined,
                        value: _formatDuration(route.duration!),
                      ),
                    const SizedBox(width: 16),
                    _StatChip(
                      icon: Icons.terrain,
                      value: '${route.elevationGain.toStringAsFixed(0)}m ↑',
                    ),
                    const SizedBox(width: 16),
                    _StatChip(
                      icon: Icons.location_on,
                      value: '${route.locations.length} pts',
                    ),
                  ],
                ),
                if (route.notes != null && route.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
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

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}m';
    }
    return '${(meters / 1000).toStringAsFixed(2)}km';
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes}min';
    }
    return '${duration.inHours}h ${duration.inMinutes % 60}m';
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
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(fontSize: 12, color: context.textSecondary),
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
        const BottomSheetHeader(
          icon: Icons.route,
          iconColor: AccentColors.green,
          title: 'New Route',
          subtitle: 'Start recording your GPS track',
        ),
        const SizedBox(height: 24),
        BottomSheetTextField(
          controller: _nameController,
          label: 'Route Name',
          hint: 'Morning hike',
          autofocus: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        BottomSheetTextField(
          controller: _notesController,
          label: 'Notes (optional)',
          hint: 'Trail conditions, weather, etc.',
          maxLines: 2,
        ),
        const SizedBox(height: 20),
        Text(
          'Color',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _colors.map((color) {
            final isSelected = color == _selectedColor;
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = color),
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
        const SizedBox(height: 24),
        BottomSheetButtons(
          cancelLabel: 'Cancel',
          confirmLabel: 'Start',
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
