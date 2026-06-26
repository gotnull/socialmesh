// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: scaffold — delegates entirely to MapScreen, which owns the
// GlassScaffold; this screen only supplies the route overlay + stats strip.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../models/route.dart' as route_model;
import '../../providers/telemetry_providers.dart';
import '../../utils/share_utils.dart';
import '../../utils/snackbar.dart';
import '../map/map_screen.dart';

/// Route detail view: the canonical mesh [MapScreen] with the saved GPS route
/// drawn on top, plus a compact stats strip. Reusing MapScreen means the route
/// view inherits every map control, layer, toggle, style, clustering, waypoint
/// and node interaction — not a stripped-down clone.
class RouteDetailScreen extends StatelessWidget {
  final route_model.Route route;

  const RouteDetailScreen({super.key, required this.route});

  @override
  Widget build(BuildContext context) {
    return MapScreen(
      routeOverlay: route,
      routeBottomOverlay: _RouteStatsBar(route: route),
    );
  }
}

/// Compact bottom strip shown over the map: distance / duration / elevation /
/// points plus a GPX share action. Floats above the map attribution.
class _RouteStatsBar extends ConsumerStatefulWidget {
  final route_model.Route route;

  const _RouteStatsBar({required this.route});

  @override
  ConsumerState<_RouteStatsBar> createState() => _RouteStatsBarState();
}

class _RouteStatsBarState extends ConsumerState<_RouteStatsBar>
    with LifecycleSafeMixin {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacing16,
          0,
          AppTheme.spacing16,
          AppTheme.spacing12,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing12,
            vertical: AppTheme.spacing8,
          ),
          decoration: BoxDecoration(
            color: context.card.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(AppTheme.radius16),
            border: Border.all(color: context.border.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: Icons.straighten,
                  label: context.l10n.routeDetailDistanceLabel,
                  value: _formatDistance(route.totalDistance),
                ),
              ),
              Expanded(
                child: _StatItem(
                  icon: Icons.timer_outlined,
                  label: context.l10n.routeDetailDurationLabel,
                  value: route.duration != null
                      ? _formatDuration(route.duration!)
                      : context.l10n.routeDetailNoData,
                ),
              ),
              Expanded(
                child: _StatItem(
                  icon: Icons.terrain,
                  label: context.l10n.routeDetailElevationLabel,
                  value: context.l10n.routeDetailElevationValue(
                    route.elevationGain.toStringAsFixed(0),
                  ),
                ),
              ),
              Expanded(
                child: _StatItem(
                  icon: Icons.location_on,
                  label: context.l10n.routeDetailPointsLabel,
                  value: '${route.locations.length}',
                ),
              ),
              IconButton(
                icon: _isExporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.share, color: context.accentColor),
                tooltip: context.l10n.routeDetailShareTooltip,
                onPressed: _isExporting ? null : _exportRoute,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportRoute() async {
    safeSetState(() => _isExporting = true);
    final l10n = context.l10n;

    // sharePositionOrigin (required on iPad) captured before the async gap.
    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 100, 100);

    final storageAsync = ref.read(routeStorageProvider);

    try {
      final storage = storageAsync.value;
      if (storage == null) {
        if (mounted) {
          showErrorSnackBar(context, l10n.routeDetailStorageUnavailable);
        }
        return;
      }

      final gpx = storage.exportRouteAsGpx(widget.route);
      final fileName =
          '${widget.route.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.gpx';

      final tempDir = await getTemporaryDirectory();
      if (!mounted) return;
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(gpx);
      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: fileName,
        text: l10n.routeDetailShareText(widget.route.name),
        sharePositionOrigin: getSafeSharePosition(null, sharePositionOrigin),
      );
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, l10n.routeDetailExportFailed(e.toString()));
      }
    } finally {
      safeSetState(() => _isExporting = false);
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return context.l10n.routeDetailDistanceMeters(meters.toStringAsFixed(0));
    }
    return context.l10n.routeDetailDistanceKilometers(
      (meters / 1000).toStringAsFixed(2),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 60) {
      return context.l10n.routeDetailDurationMinutes(duration.inMinutes);
    }
    return context.l10n.routeDetailDurationHoursMinutes(
      duration.inHours,
      duration.inMinutes % 60,
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AccentColors.blue),
        const SizedBox(height: AppTheme.spacing4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: context.bodySmallStyle?.copyWith(color: context.textSecondary),
        ),
      ],
    );
  }
}
