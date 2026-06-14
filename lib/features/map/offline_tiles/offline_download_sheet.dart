// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Offline Download Sheet — region tile pre-download UI. Lets the user pick a
// detail level for the current map viewport, shows a tile-count + storage
// estimate, and runs the download with live progress.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/map_config.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/chip_selector.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../utils/byte_format.dart';
import '../../../utils/snackbar.dart';
import 'offline_download_notifier.dart';
import 'tile_math.dart';

/// Tile count above which the sheet warns the user about storage/data use.
const int kRegionTileWarnThreshold = 8000;

/// Present the offline region download sheet for the given [bounds] + [style].
Future<void> showOfflineDownloadSheet({
  required BuildContext context,
  required LatLngBounds bounds,
  required MapTileStyle style,
}) {
  return AppBottomSheet.show<void>(
    context: context,
    child: _OfflineDownloadSheet(bounds: bounds, style: style),
  );
}

class _OfflineDownloadSheet extends ConsumerStatefulWidget {
  final LatLngBounds bounds;
  final MapTileStyle style;

  const _OfflineDownloadSheet({required this.bounds, required this.style});

  @override
  ConsumerState<_OfflineDownloadSheet> createState() =>
      _OfflineDownloadSheetState();
}

class _OfflineDownloadSheetState extends ConsumerState<_OfflineDownloadSheet>
    with LifecycleSafeMixin<_OfflineDownloadSheet> {
  // Detail presets: the max zoom to download down to. The min zoom is derived
  // a few levels above so the region is usable both zoomed out and in.
  static const List<int> _detailZooms = [14, 15, 16, 17];
  int _maxZoom = 15;

  int get _minZoom => (_maxZoom - 4).clamp(MapConfig.minZoom.toInt(), _maxZoom);

  int get _tileCount => countTilesForBounds(widget.bounds, _minZoom, _maxZoom);

  String _detailLabel(BuildContext context, int z) => switch (z) {
    14 => context.l10n.offlineDownloadDetailOverview,
    15 => context.l10n.offlineDownloadDetailStandard,
    16 => context.l10n.offlineDownloadDetailDetailed,
    _ => context.l10n.offlineDownloadDetailMax,
  };

  void _start() {
    ref
        .read(offlineDownloadProvider.notifier)
        .start(
          bounds: widget.bounds,
          style: widget.style,
          minZoom: _minZoom,
          maxZoom: _maxZoom,
        );
  }

  @override
  Widget build(BuildContext context) {
    // React to terminal states: toast + close.
    ref.listen<OfflineDownloadState>(offlineDownloadProvider, (prev, next) {
      switch (next) {
        case OfflineDownloadCompleted(:final downloaded, :final skipped):
          showSuccessSnackBar(
            context,
            context.l10n.offlineDownloadComplete(downloaded + skipped),
          );
          safeNavigatorPop();
        case OfflineDownloadCancelled():
          showWarningSnackBar(context, context.l10n.offlineDownloadCancelled);
          ref.read(offlineDownloadProvider.notifier).reset();
        case OfflineDownloadFailed():
          showErrorSnackBar(context, context.l10n.offlineDownloadFailed);
          ref.read(offlineDownloadProvider.notifier).reset();
        case OfflineDownloadIdle():
        case OfflineDownloadRunning():
          break;
      }
    });

    final state = ref.watch(offlineDownloadProvider);
    final running = state is OfflineDownloadRunning;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.offlineDownloadTitle,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        SizedBox(height: AppTheme.spacing4),
        Text(
          context.l10n.offlineDownloadAreaSummary,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13,
            color: context.textTertiary,
          ),
        ),
        SizedBox(height: AppTheme.spacing20),
        if (running)
          _ProgressBody(state: state)
        else ...[
          Text(
            context.l10n.offlineDownloadDetailLabel,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.textSecondary,
            ),
          ),
          SizedBox(height: AppTheme.spacing12),
          ChipSelector<int>(
            value: _maxZoom,
            options: [
              for (final z in _detailZooms)
                ChipOption<int>(
                  value: z,
                  label: _detailLabel(context, z),
                  icon: Icons.zoom_in,
                  color: context.accentColor,
                ),
            ],
            onChanged: (z) => safeSetState(() => _maxZoom = z),
          ),
          SizedBox(height: AppTheme.spacing16),
          Text(
            context.l10n.offlineDownloadEstimate(
              _tileCount,
              formatByteSize(estimateBytes(_tileCount)),
            ),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              color: context.textPrimary,
            ),
          ),
          if (_tileCount > kRegionTileWarnThreshold) ...[
            SizedBox(height: AppTheme.spacing12),
            StatusBanner.warning(
              title: context.l10n.offlineDownloadLargeTitle,
              subtitle: context.l10n.offlineDownloadLargeSubtitle,
            ),
          ],
          SizedBox(height: AppTheme.spacing20),
          PrimaryGradientButton(
            label: context.l10n.offlineDownloadStart(
              formatByteSize(estimateBytes(_tileCount)),
            ),
            icon: Icons.download,
            enabled: _tileCount > 0,
            onPressed: _start,
          ),
        ],
      ],
    );
  }
}

class _ProgressBody extends StatelessWidget {
  final OfflineDownloadRunning state;

  const _ProgressBody({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radius4),
          child: LinearProgressIndicator(
            value: state.fraction,
            minHeight: 8,
            backgroundColor: context.border.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(context.accentColor),
          ),
        ),
        SizedBox(height: AppTheme.spacing12),
        Text(
          context.l10n.offlineDownloadProgress(state.done, state.total),
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 14,
            color: context.textPrimary,
          ),
        ),
        SizedBox(height: AppTheme.spacing4),
        Text(
          formatByteSize(state.bytes),
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13,
            color: context.textTertiary,
          ),
        ),
        SizedBox(height: AppTheme.spacing20),
        Consumer(
          builder: (context, ref, _) => OutlinedButton.icon(
            onPressed: () =>
                ref.read(offlineDownloadProvider.notifier).cancel(),
            icon: const Icon(Icons.stop_circle_outlined),
            label: Text(context.l10n.offlineDownloadCancel),
          ),
        ),
      ],
    );
  }
}
