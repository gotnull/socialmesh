// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/map_entity_list_item.dart';
import '../../../../core/widgets/map_node_drawer.dart';
import '../../../../features/meshcore/screens/meshcore_map_marker_staleness.dart';
import '../../../../models/meshcore_contact.dart';

/// Side-panel content for the MeshCore Map screen. Mirrors the
/// Meshtastic map's node-list drawer 1:1 in shape: glass chrome via
/// [MapNodeDrawer], rows via [MapEntityListItem], live search filtering,
/// distance-from-self pill when self position is known.
///
/// Caller responsibilities:
///   - Wrap this in an [AnimatedPositioned] with `left: showPanel ? 0 : -300`.
///   - Provide a [TextEditingController] for the search field.
///   - Handle tap-to-select via [onContactSelected] (typically centers
///     the map on the tapped contact's position).
class MeshCoreContactListPanel extends ConsumerWidget {
  /// Contacts to render. Caller has already filtered to only those
  /// with a valid location (the drawer doesn't render contacts that
  /// can't be shown on the map).
  final List<MeshCoreContact> contacts;

  /// Currently selected contact - drives the row highlight.
  final MeshCoreContact? selectedContact;

  /// Live position of the user's own node, decoded from SELF_INFO.
  /// Null when the user has not set their advertised location yet.
  /// When non-null, drives distance-from-self badges on each row.
  final LatLng? selfPosition;

  /// Fired when a row is tapped. Caller centers the map on the
  /// contact and (typically) opens its info sheet.
  final void Function(MeshCoreContact) onContactSelected;

  /// Fired when the user taps the drawer close button.
  final VoidCallback onClose;

  /// Search field controller owned by the parent so search state
  /// survives drawer slide animations.
  final TextEditingController searchController;

  /// Live search query - typically the same controller's text value,
  /// re-emitted on `onSearchChanged` so the parent can hold state.
  final String searchQuery;

  /// Fires when the search field text changes.
  final ValueChanged<String> onSearchChanged;

  const MeshCoreContactListPanel({
    super.key,
    required this.contacts,
    required this.selectedContact,
    required this.selfPosition,
    required this.onContactSelected,
    required this.onClose,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final query = searchQuery.trim().toLowerCase();

    var filtered = contacts;
    if (query.isNotEmpty) {
      filtered = contacts
          .where(
            (c) =>
                c.displayName.toLowerCase().contains(query) ||
                c.publicKeyHex.toLowerCase().contains(query),
          )
          .toList();
    } else {
      filtered = List<MeshCoreContact>.from(contacts);
    }

    // Sort: closest-to-self first when self position is known,
    // otherwise most-recently-heard first, then alphabetically.
    filtered.sort((a, b) {
      final self = selfPosition;
      if (self != null) {
        final distA = _distanceKm(self, a);
        final distB = _distanceKm(self, b);
        if (distA != null && distB != null) return distA.compareTo(distB);
        if (distA != null) return -1;
        if (distB != null) return 1;
      }
      final cmpLastSeen = b.lastSeen.compareTo(a.lastSeen);
      if (cmpLastSeen != 0) return cmpLastSeen;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return MapNodeDrawer(
      title: l10n.meshcoreMapTitle,
      headerIcon: Icons.hub,
      itemCount: filtered.length,
      onClose: onClose,
      searchController: searchController,
      onSearchChanged: onSearchChanged,
      searchHintText: l10n.mapSearchNodesHint,
      content: Expanded(
        child: filtered.isEmpty
            ? const DrawerEmptyState()
            : ListView.builder(
                padding: EdgeInsets.only(top: 4, bottom: bottomPadding + 8),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final c = filtered[index];
                  final age = now.difference(c.lastSeen);
                  final isFresh = age <= kMeshCoreMarkerFreshThreshold;
                  final isStale = age >= kMeshCoreMarkerVeryStaleThreshold;
                  final statusColor = isFresh
                      ? AppTheme.successGreen
                      : (isStale ? AppTheme.errorRed : context.textSecondary);
                  final distanceText = _formatDistance(
                    selfPosition,
                    c,
                    context,
                  );
                  return StaggeredDrawerTile(
                    index: index,
                    child: MapEntityListItem(
                      displayName: c.displayName,
                      avatarChar: _avatarChar(c),
                      isMyEntity: false,
                      isSelected:
                          selectedContact?.publicKeyHex == c.publicKeyHex,
                      isStale: isStale,
                      isActive: isFresh,
                      statusColor: statusColor,
                      statusText: _statusText(age, context),
                      distanceText: distanceText,
                      onTap: () => onContactSelected(c),
                    ),
                  );
                },
              ),
      ),
    );
  }

  static String _avatarChar(MeshCoreContact c) {
    if (c.name.isNotEmpty) return c.name.characters.first.toUpperCase();
    final hex = c.publicKeyHex;
    if (hex.isNotEmpty) return hex.characters.first.toUpperCase();
    return '?';
  }

  static double? _distanceKm(LatLng self, MeshCoreContact c) {
    if (!c.hasLocation) return null;
    final lat = c.latitude!;
    final lon = c.longitude!;
    if (lat == self.latitude && lon == self.longitude) return 0.0;
    try {
      return const Distance().as(LengthUnit.Kilometer, self, LatLng(lat, lon));
    } catch (_) {
      return null;
    }
  }

  static String? _formatDistance(
    LatLng? self,
    MeshCoreContact c,
    BuildContext context,
  ) {
    if (self == null) return null;
    final km = _distanceKm(self, c);
    if (km == null) return null;
    final l10n = context.l10n;
    if (km < 1) {
      return l10n.mapDistanceMeters('${(km * 1000).round()}');
    }
    if (km < 10) {
      return l10n.mapDistanceKilometers(km.toStringAsFixed(1));
    }
    return l10n.mapDistanceKilometersRound('${km.round()}');
  }

  static String _statusText(Duration age, BuildContext context) {
    final l10n = context.l10n;
    if (age.inMinutes < 1) return l10n.meshcoreContactJustHeard;
    if (age.inMinutes < 60) {
      return l10n.meshcoreContactHeardMinutesAgo('${age.inMinutes}');
    }
    if (age.inHours < 24) {
      return l10n.meshcoreContactHeardHoursAgo('${age.inHours}');
    }
    return l10n.meshcoreContactHeardDaysAgo('${age.inDays}');
  }
}
