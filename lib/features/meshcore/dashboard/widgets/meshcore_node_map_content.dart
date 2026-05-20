// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/map_config.dart';
import '../../../../core/safe_lat_lng.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/mesh_map_widget.dart';
import '../../../../models/meshcore_contact.dart';
import '../../../../providers/app_providers.dart';
import '../../../../providers/meshcore_providers.dart';
import '../../../navigation/meshcore_shell.dart';
import '../../widgets/meshcore_sigil_avatar.dart';

/// MeshCore-flavoured equivalent of `NodeMapContent`. Compact map embed
/// that renders contacts with a known location. Tapping the surface
/// pushes the MeshCore Map tab so the full map UI takes over.
class MeshCoreNodeMapContent extends ConsumerWidget {
  const MeshCoreNodeMapContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsState = ref.watch(meshCoreContactsProvider);
    final mapStyle = ref
        .watch(settingsServiceProvider)
        .maybeWhen(
          data: (settings) {
            final index = settings.mapTileStyleIndex;
            if (index >= 0 && index < MapTileStyle.values.length) {
              return MapTileStyle.values[index];
            }
            return MapTileStyle.dark;
          },
          orElse: () => MapTileStyle.dark,
        );

    final positioned = contactsState.contacts
        .where((c) => c.hasLocation)
        .toList();

    if (positioned.isEmpty) {
      return _buildEmptyState(context);
    }

    final center = _calculateCenter(positioned);

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : constraints.maxWidth * 0.6;
        return SizedBox(
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            child: Stack(
              children: [
                MeshMapWidget(
                  mapStyle: mapStyle,
                  initialCenter: center,
                  initialZoom: 12.0,
                  minZoom: 2,
                  maxZoom: 16,
                  interactive: false,
                  animateTiles: false,
                  onTap: (_, _) => _openFullMap(context, ref),
                  additionalLayers: [
                    MarkerLayer(
                      markers: finiteMarkers(
                        positioned.map((contact) {
                          final point = safeLatLng(
                            contact.latitude,
                            contact.longitude,
                          );
                          if (point == null) return null;
                          return Marker(
                            point: point,
                            width: 24,
                            height: 24,
                            child: _MeshCoreMiniMarker(contact: contact),
                          );
                        }).whereType<Marker>(),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: AppTheme.spacing8,
                  top: AppTheme.spacing8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing8,
                      vertical: AppTheme.spacing4,
                    ),
                    decoration: BoxDecoration(
                      color: context.card.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                      border: Border.all(
                        color: context.border.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AccentColors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing6),
                        Text(
                          '${positioned.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: AppTheme.spacing8,
                  bottom: AppTheme.spacing8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing8,
                      vertical: AppTheme.spacing4,
                    ),
                    decoration: BoxDecoration(
                      color: context.card.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.open_in_full_rounded,
                          size: 12,
                          color: context.textTertiary,
                        ),
                        const SizedBox(width: AppTheme.spacing4),
                        Text(
                          context.l10n.meshcoreWidgetNodeMapTapToExpand,
                          style: TextStyle(
                            fontSize: 10,
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openFullMap(context, ref),
                      splashColor: context.accentColor.withValues(alpha: 0.1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  LatLng _calculateCenter(List<MeshCoreContact> contacts) {
    double sumLat = 0;
    double sumLon = 0;
    int count = 0;
    for (final c in contacts) {
      if (c.latitude != null && c.longitude != null) {
        sumLat += c.latitude!;
        sumLon += c.longitude!;
        count++;
      }
    }
    if (count == 0) return const LatLng(0, 0);
    return safeLatLng(sumLat / count, sumLon / count) ?? const LatLng(0, 0);
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.map_outlined,
            size: 32,
            color: context.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            l10n.meshcoreWidgetNodeMapEmptyTitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            l10n.meshcoreWidgetNodeMapEmptySubtitle,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: context.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _openFullMap(BuildContext context, WidgetRef ref) {
    // Route the user to the MeshCore Map tab in the bottom-nav shell.
    // Index 1 is the Map tab in `MeshCoreShell._buildScreen`.
    ref.read(meshCoreShellIndexProvider.notifier).setIndex(1);
  }
}

class _MeshCoreMiniMarker extends StatelessWidget {
  final MeshCoreContact contact;
  const _MeshCoreMiniMarker({required this.contact});

  @override
  Widget build(BuildContext context) {
    final hasPubkey = contact.publicKey.length >= 4;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: context.card, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4),
        ],
      ),
      child: hasPubkey
          ? MeshCoreSigilAvatar(pubKey: contact.publicKey, size: 20)
          : Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AccentColors.cyan.withValues(alpha: 0.85),
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 12,
                color: Colors.white,
              ),
            ),
    );
  }
}
