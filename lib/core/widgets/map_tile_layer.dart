// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/connectivity_providers.dart';
import '../map_config.dart';
import '../safe_lat_lng.dart';
import '../theme.dart';

/// Base tile layer for every map surface. Resolves the tile source through
/// [MapConfig] (Mapbox, MapTiler, CARTO or the style's own template) and
/// rebuilds itself when [MapConfig.terrainFallbackActive] flips, so a refused
/// MapTiler key moves the terrain style onto OpenTopoMap without the screen
/// having to know about it.
///
/// While the device is offline, or when [offlineSource] is set, the layer
/// resolves to the offline source instead: the URLs the region downloader
/// wrote, which are never a keyed provider because Mapbox and MapTiler
/// prohibit bulk download. That is what lets a downloaded terrain region show
/// on the live map with no connection even though the online terrain comes
/// from MapTiler.
///
/// The layer is keyed on the resolved URL: flutter_map does not reload tiles
/// when only the template changes, so a style or source switch must replace
/// the layer to load the new tiles immediately.
class StyledTileLayer extends ConsumerWidget {
  const StyledTileLayer({
    super.key,
    required this.style,
    required this.satelliteLabelsOn,
    this.offlineSource = false,
    this.tileBuilder,
  });

  final MapTileStyle style;
  final bool satelliteLabelsOn;

  /// Always use the offline source, regardless of connectivity. Set by the
  /// offline-regions screen so it shows exactly what was downloaded.
  final bool offlineSource;

  final TileBuilder? tileBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useOfflineSource = offlineSource || !ref.watch(isOnlineProvider);
    return ValueListenableBuilder<bool>(
      valueListenable: MapConfig.terrainFallbackActive,
      builder: (context, _, _) {
        final url = MapConfig.urlForStyle(
          style,
          satelliteLabelsOn: satelliteLabelsOn,
          offlineSource: useOfflineSource,
        );
        return TileLayer(
          key: ValueKey<String>(url),
          urlTemplate: url,
          subdomains: MapConfig.subdomainsForStyle(
            style,
            offlineSource: useOfflineSource,
          ),
          // Overzoom past the source's native cap (raw OpenTopoMap terrain
          // tops out at z17) by upscaling the last real tiles instead of
          // requesting a tile the server does not have.
          maxNativeZoom: MapConfig.maxNativeZoomForStyle(
            style,
            offlineSource: useOfflineSource,
          ),
          userAgentPackageName: MapConfig.userAgentPackageName,
          // Retina only for sources that serve real @2x tiles (resolved URL
          // has {r}). Simulated retina shifts requested tile coordinates and
          // would desync the offline cache, so it is never used.
          retinaMode: MapConfig.resolvedRetinaMode(
            style,
            satelliteLabelsOn: satelliteLabelsOn,
            offlineSource: useOfflineSource,
          ),
          tileProvider: MapConfig.networkTileProvider(),
          evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
          errorTileCallback: MapConfig.onTileError,
          tileUpdateTransformer: finiteCameraTileUpdateTransformer,
          tileBuilder: tileBuilder,
        );
      },
    );
  }
}

/// Attribution pill for the resolved tile source. Follows the same
/// resolution as [StyledTileLayer], including the terrain fallback and the
/// offline source, so the credit line always names the provider whose tiles
/// are on screen. Tapping opens the provider's attribution page, which Mapbox
/// and MapTiler require.
class MapAttributionChip extends ConsumerWidget {
  const MapAttributionChip({
    super.key,
    required this.style,
    required this.satelliteLabelsOn,
    this.offlineSource = false,
  });

  final MapTileStyle style;
  final bool satelliteLabelsOn;
  final bool offlineSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useOfflineSource = offlineSource || !ref.watch(isOnlineProvider);
    return ValueListenableBuilder<bool>(
      valueListenable: MapConfig.terrainFallbackActive,
      builder: (context, _, _) {
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            launchUrl(
              Uri.parse(
                MapConfig.attributionUrl(
                  style,
                  satelliteLabelsOn: satelliteLabelsOn,
                  offlineSource: useOfflineSource,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing6,
              vertical: AppTheme.spacing3,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppTheme.radius4),
            ),
            child: Text(
              MapConfig.attributionLabel(
                style,
                satelliteLabelsOn: satelliteLabelsOn,
                offlineSource: useOfflineSource,
              ),
              style: const TextStyle(color: Colors.white70, fontSize: 9),
            ),
          ),
        );
      },
    );
  }
}
