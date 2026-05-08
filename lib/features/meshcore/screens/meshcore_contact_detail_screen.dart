// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D34c-A — MeshCore contact detail screen.
//
// Read-only view of a single MeshCore contact's identity + routing +
// activity + location metadata, with two safe actions (Trace Path,
// Reset Path) that already shipped in D28/D29.
//
// Hard rules:
//   - No force-flood / force-direct / force-N-hop override controls.
//     Those wait for a dedicated D34c-B safety-gated slice. The
//     `pathBytes` row shows the saved hops so the user can verify
//     them, but there is no UI to mutate them in this slice — only
//     "Save as Contact Path" via the Trace flow can write a new path
//     today, and that lives in the Trace result sheet (D28).
//   - No log lines emit the full pubkey or the full path bytes.
//     Pubkey is shown via the existing `<8B…8T>` redacted
//     fingerprint; path bytes are surfaced in the UI only.
//   - Uses canonical primitives only — `GlassScaffold`,
//     `SectionTitle`, `InfoTable` / `InfoTableRow`. No hand-rolled
//     `Row(Icon + Spacer + Text)` rows.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/info_table.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/settings_primitives.dart';
import '../../../models/meshcore_contact.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../utils/snackbar.dart';
import '../contact_l10n.dart';
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

    return GlassScaffold.body(
      title: live.displayName.isNotEmpty
          ? live.displayName
          : l10n.meshcoreContactUnknownName,
      hasScrollBody: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacing16,
          AppTheme.spacing16,
          AppTheme.spacing16,
          AppTheme.spacing24,
        ),
        children: [
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
        ],
      ),
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
