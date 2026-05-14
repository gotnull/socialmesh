// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D34c-A — MeshCore contact detail screen.
//
// Read-only view of a single MeshCore contact's identity + routing +
// activity + location metadata, with safe actions (Trace Path, Path
// Override, Reset Path) gated by canonical primitives.
//
// D34c-B-A added the Path Override tile: tapping it opens an
// `AppBottomSheet.showActions` with Force Flood / Force Direct /
// Reset to Auto. Force Direct fires a confirmation sheet with the
// "out of range = silent failure" warning before applying.
//
// Hard rules:
//   - No manual N-hop entry. The only way to write an N-hop path is
//     via the trace flow ("Save as Contact Path" in the trace
//     result sheet, D28).
//   - The routing card stays read-only `InfoTable` — override
//     actions live exclusively in the bottom sheet.
//   - No log lines emit the full pubkey or the full path bytes.
//     Pubkey is shown via the existing `<8B…8T>` redacted
//     fingerprint; path bytes are surfaced in the UI only.
//   - Uses canonical primitives only — `GlassScaffold`,
//     `SectionTitle`, `InfoTable` / `InfoTableRow`,
//     `AppBottomSheet.showActions`, `AppBottomSheet.showConfirm`. No
//     hand-rolled `Row(Icon + Spacer + Text)` rows.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/info_table.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/settings_primitives.dart';
import '../../../models/meshcore_contact.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../utils/snackbar.dart';
import '../contact_l10n.dart';
import 'meshcore_map_screen.dart';
import 'meshcore_neighbors_sheet.dart';
import 'meshcore_path_history_sheet.dart';
import 'meshcore_telemetry_sheet.dart';
import 'meshcore_tools_screen.dart' show showMeshCoreTracePathSheet;

/// MeshCore-only read-only contact detail screen.
///
/// Watches [meshCoreContactsProvider] for live updates so a path
/// reset / trace-save / advert-name heal performed elsewhere is
/// reflected immediately. Falls back to the [initialContact] when the
/// contact is no longer in the live list (rare — only happens if the
/// contact was removed from the radio while this screen was open).
class MeshCoreContactDetailScreen extends ConsumerWidget {
  final MeshCoreContact initialContact;

  const MeshCoreContactDetailScreen({super.key, required this.initialContact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final contactsState = ref.watch(meshCoreContactsProvider);
    final live = contactsState.contacts.firstWhere(
      (c) => c.publicKeyHex == initialContact.publicKeyHex,
      orElse: () => initialContact,
    );

    return GlassScaffold(
      title: live.displayName.isNotEmpty
          ? live.displayName
          : l10n.meshcoreContactUnknownName,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing16,
            AppTheme.spacing16,
            AppTheme.spacing24,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _identitySection(context, live),
              const SizedBox(height: AppTheme.spacing16),
              _routingSection(context, live),
              const SizedBox(height: AppTheme.spacing16),
              _activitySection(context, live),
              if (live.hasLocation) ...[
                const SizedBox(height: AppTheme.spacing16),
                _locationSection(context, live),
              ],
              const SizedBox(height: AppTheme.spacing24),
              _actionsSection(context, ref, live),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _identitySection(BuildContext context, MeshCoreContact c) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: l10n.meshcoreContactDetailIdentity),
        InfoTable(
          rows: [
            InfoTableRow(
              label: l10n.meshcoreContactDetailName,
              value: c.name.isNotEmpty
                  ? c.name
                  : l10n.meshcoreContactUnknownName,
            ),
            InfoTableRow(
              label: l10n.meshcoreContactDetailType,
              value: _typeLabel(context, c),
            ),
            InfoTableRow(
              label: l10n.meshcoreContactDetailPublicKey,
              // Redacted 8-head + 8-tail fingerprint mirrors the log
              // channel's pubkey format. Tap copies the FULL pubkey
              // to the clipboard — that's a deliberate user action,
              // not a passive reveal.
              value: c.shortPubKeyHex,
              icon: Icons.copy_rounded,
              onTap: () => _copyPubKey(context, c),
            ),
          ],
        ),
      ],
    );
  }

  Widget _routingSection(BuildContext context, MeshCoreContact c) {
    final l10n = context.l10n;
    final rows = <InfoTableRow>[
      InfoTableRow(
        label: l10n.meshcoreContactDetailPath,
        value: c.localizedPathLabel(l10n),
      ),
      InfoTableRow(
        label: l10n.meshcoreContactDetailHops,
        // pathLength == -1 means flood (no fixed hop count) — show
        // a dash rather than a misleading negative number.
        value: c.pathLength < 0 ? '—' : '${c.pathLength}',
      ),
      // Show saved path bytes when present. These are the firmware-
      // resolved hops; never the full pubkey of any repeater.
      if (c.path.isNotEmpty)
        InfoTableRow(
          label: l10n.meshcoreContactDetailPathBytes,
          value: _hexBytes(c.path),
        ),
      if (c.snrDb != null)
        InfoTableRow(
          label: l10n.meshcoreContactDetailSnr,
          value: l10n.meshcoreSnrLabel(c.snrDb!.toStringAsFixed(1)),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: l10n.meshcoreContactDetailRouting),
        InfoTable(rows: rows),
      ],
    );
  }

  Widget _activitySection(BuildContext context, MeshCoreContact c) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: l10n.meshcoreContactDetailActivity),
        InfoTable(
          rows: [
            InfoTableRow(
              label: l10n.meshcoreContactDetailLastSeen,
              value: _formatTimestamp(context, c.lastSeen),
            ),
          ],
        ),
      ],
    );
  }

  Widget _locationSection(BuildContext context, MeshCoreContact c) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: l10n.meshcoreContactDetailLocation),
        InfoTable(
          rows: [
            InfoTableRow(
              label: l10n.meshcoreContactDetailLatitude,
              value: c.latitude!.toStringAsFixed(5),
            ),
            InfoTableRow(
              label: l10n.meshcoreContactDetailLongitude,
              value: c.longitude!.toStringAsFixed(5),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionsSection(
    BuildContext context,
    WidgetRef ref,
    MeshCoreContact c,
  ) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: l10n.meshcoreContactDetailActions),
        SettingsTile(
          key: const ValueKey('meshcore-contact-detail-trace-path'),
          icon: Icons.route_rounded,
          iconColor: context.accentColor,
          title: l10n.meshcoreTracePathTitle,
          subtitle: l10n.meshcoreContactDetailTracePathSubtitle,
          onTap: () => showMeshCoreTracePathSheet(context),
        ),
        SettingsTile(
          key: const ValueKey('meshcore-contact-detail-path-override'),
          icon: Icons.alt_route_rounded,
          iconColor: context.accentColor,
          title: l10n.meshcorePathOverrideTitle,
          subtitle: l10n.meshcorePathOverrideSubtitle,
          onTap: () => _openPathOverrideSheet(context, ref, c),
        ),
        // D39-A: Path History tile. Hidden when the contact has no
        // saved paths. Tap opens the history sheet; the sheet itself
        // handles activation confirmation, View, and Delete.
        _PathHistoryTile(contact: c),
        // D42-A: Show on map tile. Hidden when the contact has no
        // usable path data (flood path or all hops unresolved).
        _ShowOnMapTile(contact: c),
        // D42-B-A: Show inferred path tile. Always visible; the
        // notifier returns false (and the snackbar fires) when no
        // app-local evidence exists for this contact.
        _ShowInferredPathTile(contact: c),
        // D41-A: Telemetry tile. Always visible for chat and
        // repeater contacts; the sheet handles the no-data /
        // timeout / cooling states internally.
        SettingsTile(
          key: const ValueKey('meshcore-contact-detail-telemetry'),
          icon: Icons.sensors_rounded,
          iconColor: context.accentColor,
          title: l10n.meshcoreTelemetryTileTitle,
          subtitle: l10n.meshcoreTelemetryTileSubtitle,
          onTap: () => showMeshCoreTelemetrySheet(context, contact: c),
        ),
        // D36-A: Neighbours query is repeater-only. The chat-type
        // contacts can't be queried this way (they aren't repeaters)
        // so the tile is hidden entirely; we don't show a greyed-out
        // disabled variant.
        if (c.type == MeshCoreAdvType.repeater)
          SettingsTile(
            key: const ValueKey('meshcore-contact-detail-neighbors'),
            icon: Icons.hub_rounded,
            iconColor: context.accentColor,
            title: l10n.meshcoreNeighborsTileTitle,
            subtitle: l10n.meshcoreNeighborsTileSubtitle,
            onTap: () => showMeshCoreNeighborsSheet(context, repeater: c),
          ),
        SettingsTile(
          key: const ValueKey('meshcore-contact-detail-reset-path'),
          icon: Icons.refresh_rounded,
          iconColor: context.accentColor,
          title: l10n.meshcoreResetPath,
          subtitle: l10n.meshcoreContactDetailResetPathSubtitle,
          onTap: () => _resetPath(context, ref, c),
        ),
      ],
    );
  }

  Future<void> _copyPubKey(BuildContext context, MeshCoreContact c) async {
    await Clipboard.setData(ClipboardData(text: c.publicKeyHex));
    if (!context.mounted) return;
    showSuccessSnackBar(
      context,
      context.l10n.meshcoreContactDetailPubKeyCopied,
    );
  }

  Future<void> _resetPath(
    BuildContext context,
    WidgetRef ref,
    MeshCoreContact c,
  ) async {
    final ok = await ref
        .read(meshCoreContactsProvider.notifier)
        .resetPath(c.publicKeyHex);
    if (!context.mounted) return;
    if (ok) {
      showSuccessSnackBar(
        context,
        context.l10n.meshcoreResetPathSuccess(
          c.displayName.isNotEmpty
              ? c.displayName
              : context.l10n.meshcoreContactUnknownName,
        ),
      );
    } else {
      showErrorSnackBar(
        context,
        context.l10n.meshcoreResetPathFailed(
          c.displayName.isNotEmpty
              ? c.displayName
              : context.l10n.meshcoreContactUnknownName,
        ),
      );
    }
  }

  /// D34c-B-A: presents Force Flood / Force Direct / Reset to Auto
  /// as discrete actions. Force Direct routes through a confirm
  /// sheet (`_confirmForceDirect`) so the user must opt in twice
  /// before delivery is constrained to the direct route.
  Future<void> _openPathOverrideSheet(
    BuildContext context,
    WidgetRef ref,
    MeshCoreContact c,
  ) async {
    final l10n = context.l10n;
    final accent = context.accentColor;
    await AppBottomSheet.showActions<void>(
      context: context,
      actions: [
        BottomSheetAction<void>(
          icon: Icons.broadcast_on_personal_rounded,
          iconColor: accent,
          label: l10n.meshcorePathOverrideForceFlood,
          subtitle: l10n.meshcorePathOverrideForceFloodSubtitle,
          onTap: () =>
              _applyOverride(context, ref, c, PathOverrideMode.forceFlood),
        ),
        BottomSheetAction<void>(
          icon: Icons.near_me_rounded,
          iconColor: accent,
          label: l10n.meshcorePathOverrideForceDirect,
          subtitle: l10n.meshcorePathOverrideForceDirectSubtitle,
          onTap: () => _confirmForceDirect(context, ref, c),
        ),
        BottomSheetAction<void>(
          icon: Icons.refresh_rounded,
          iconColor: accent,
          label: l10n.meshcorePathOverrideResetToAuto,
          onTap: () => _resetPath(context, ref, c),
        ),
      ],
    );
  }

  /// D34c-B-A: two-step gate for Force Direct. Direct delivery is
  /// safe only when the peer is in radio range; this confirm sheet
  /// makes the failure mode explicit so the user opts in
  /// deliberately.
  Future<void> _confirmForceDirect(
    BuildContext context,
    WidgetRef ref,
    MeshCoreContact c,
  ) async {
    final l10n = context.l10n;
    final name = c.displayName.isNotEmpty
        ? c.displayName
        : l10n.meshcoreContactUnknownName;
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.meshcorePathOverrideForceDirectConfirmTitle,
      message: l10n.meshcorePathOverrideForceDirectConfirmMessage(name),
      confirmLabel: l10n.meshcorePathOverrideConfirmApply,
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    await _applyOverride(context, ref, c, PathOverrideMode.forceDirect);
  }

  Future<void> _applyOverride(
    BuildContext context,
    WidgetRef ref,
    MeshCoreContact c,
    PathOverrideMode mode,
  ) async {
    final l10n = context.l10n;
    final ok = await ref
        .read(meshCoreContactsProvider.notifier)
        .setPathOverride(publicKeyHex: c.publicKeyHex, mode: mode);
    if (!context.mounted) return;
    final name = c.displayName.isNotEmpty
        ? c.displayName
        : l10n.meshcoreContactUnknownName;
    final successMsg = mode == PathOverrideMode.forceFlood
        ? l10n.meshcorePathOverrideForceFloodSuccess(name)
        : l10n.meshcorePathOverrideForceDirectSuccess(name);
    final failedMsg = mode == PathOverrideMode.forceFlood
        ? l10n.meshcorePathOverrideForceFloodFailed(name)
        : l10n.meshcorePathOverrideForceDirectFailed(name);
    if (ok) {
      showSuccessSnackBar(context, successMsg);
    } else {
      showErrorSnackBar(context, failedMsg);
    }
  }

  String _typeLabel(BuildContext context, MeshCoreContact c) {
    final l10n = context.l10n;
    switch (c.type) {
      case MeshCoreAdvType.chat:
        return l10n.meshcoreContactTypeChat;
      case MeshCoreAdvType.repeater:
        return l10n.meshcoreContactTypeRepeater;
      case MeshCoreAdvType.room:
        return l10n.meshcoreContactTypeRoom;
      case MeshCoreAdvType.sensor:
        return l10n.meshcoreContactTypeSensor;
      default:
        return l10n.meshcoreContactTypeUnknown;
    }
  }

  String _hexBytes(Uint8List bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }

  String _formatTimestamp(BuildContext context, DateTime ts) {
    final now = DateTime.now();
    final localTs = ts.toLocal();
    final ymd =
        '${localTs.year.toString().padLeft(4, '0')}-'
        '${localTs.month.toString().padLeft(2, '0')}-'
        '${localTs.day.toString().padLeft(2, '0')}';
    final hms =
        '${localTs.hour.toString().padLeft(2, '0')}:'
        '${localTs.minute.toString().padLeft(2, '0')}';
    final isToday =
        localTs.year == now.year &&
        localTs.month == now.month &&
        localTs.day == now.day;
    if (isToday) return hms;
    return '$ymd $hms';
  }
}

/// Convenience launcher mirroring the existing `showMeshCore*Sheet`
/// helpers in the MeshCore feature module.
Future<void> openMeshCoreContactDetail(
  BuildContext context, {
  required MeshCoreContact contact,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => MeshCoreContactDetailScreen(initialContact: contact),
    ),
  );
}

/// D39-A: Path History tile in the Contact Detail actions section.
/// Subscribes to the per-contact path-history notifier and renders
/// the tile only when at least one entry exists.
class _PathHistoryTile extends ConsumerWidget {
  final MeshCoreContact contact;
  const _PathHistoryTile({required this.contact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final entries = ref.watch(
      meshCorePathHistoryProvider(contact.publicKeyHex),
    );
    if (entries.isEmpty) return const SizedBox.shrink();
    return SettingsTile(
      key: const ValueKey('meshcore-contact-detail-path-history'),
      icon: Icons.history_rounded,
      iconColor: context.accentColor,
      title: l10n.meshcorePathHistoryTileTitle,
      subtitle: l10n.meshcorePathHistoryTileSubtitle(entries.length),
      onTap: () => showMeshCorePathHistorySheet(context, contact: contact),
    );
  }
}

/// D42-A: Show-on-map tile in the Contact Detail actions section.
/// Hidden when the contact has no usable path data:
///   - flood route (pathLength == -1 with no override),
///   - direct route AND no contact location AND no self location,
///   - all hops unresolved AND no endpoint coords.
///
/// Tap builds the overlay via [meshCorePathOverlayProvider] then
/// pushes the map. Snackbar fallback when no coordinate data
/// resolves at activation time.
class _ShowOnMapTile extends ConsumerWidget {
  final MeshCoreContact contact;
  const _ShowOnMapTile({required this.contact});

  bool _isFloodOnly() {
    if (contact.pathOverride != null) {
      return contact.pathOverride! < 0;
    }
    return contact.pathLength < 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Flood routes have no fixed path - hide the tile entirely.
    if (_isFloodOnly()) return const SizedBox.shrink();
    final l10n = context.l10n;
    return SettingsTile(
      key: const ValueKey('meshcore-contact-detail-show-on-map'),
      icon: Icons.map_outlined,
      iconColor: context.accentColor,
      title: l10n.meshcorePathOverlayShowOnMap,
      subtitle: l10n.meshcorePathOverlayShowOnMapSubtitle,
      onTap: () => _activate(context, ref),
    );
  }

  void _activate(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ok = ref
        .read(meshCorePathOverlayProvider.notifier)
        .setActive(contact);
    if (!ok) {
      showInfoSnackBar(context, l10n.meshcorePathOverlayNoData);
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MeshCoreMapScreen()));
  }
}

/// D42-B-A: Contact-detail tile that surfaces an inferred path overlay
/// built from app-local evidence (D39 saved entries + persisted
/// inbound message paths). Always visible; the notifier returns false
/// when no usable evidence exists, and the tap handler surfaces a
/// quiet info snackbar in that case.
class _ShowInferredPathTile extends ConsumerWidget {
  final MeshCoreContact contact;

  const _ShowInferredPathTile({required this.contact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SettingsTile(
      key: const ValueKey('meshcore-contact-detail-show-inferred-path'),
      icon: Icons.auto_fix_high_rounded,
      iconColor: context.accentColor,
      title: l10n.meshcorePathOverlayShowInferred,
      subtitle: l10n.meshcorePathOverlayShowInferredSubtitle,
      onTap: () => _activate(context, ref),
    );
  }

  Future<void> _activate(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    final ok = await ref
        .read(meshCorePathOverlayProvider.notifier)
        .setInferred(contact);
    if (!context.mounted) return;
    if (!ok) {
      showInfoSnackBar(context, l10n.meshcorePathOverlayInferredUnavailable);
      return;
    }
    navigator.push(
      MaterialPageRoute(builder: (_) => const MeshCoreMapScreen()),
    );
  }
}
