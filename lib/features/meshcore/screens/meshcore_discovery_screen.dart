// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D34b-A1 — MeshCore discovered/heard nodes screen.
//
// Recent-heard feed driven by `meshCoreDiscoveredAdvertsProvider`. Lists
// every peer we've heard via `PUSH_CODE_NEW_ADVERT (0x8A)` or
// `PUSH_CODE_ADVERT (0x80)` in receive order, capped at 100 in-memory
// entries (FIFO eviction, oldest `lastHeard` first). Cross-references
// the live contact list to render an "Imported" / "Heard" badge.
//
// Hard rules carried forward from the slice spec:
//   - No firmware autoadd toggle UI (separate D34b-B slice).
//   - No persisted heard-list — buffer is in-memory and lost on app
//     restart by design.
//   - Self pubkey is filtered out at the notifier layer.
//   - No log line surfaces full pubkey, path bytes, or message
//     plaintext. The notifier already redacts via
//     `AppLogging.publicKeyFingerprint`; this screen never logs at all.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/meshcore_contact.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../utils/snackbar.dart';
import '../widgets/meshcore_sigil_avatar.dart';
import 'meshcore_contact_detail_screen.dart';

enum _SortMode { recent, alphabetical }

class MeshCoreDiscoveryScreen extends ConsumerStatefulWidget {
  const MeshCoreDiscoveryScreen({super.key});

  @override
  ConsumerState<MeshCoreDiscoveryScreen> createState() =>
      _MeshCoreDiscoveryScreenState();
}

class _MeshCoreDiscoveryScreenState
    extends ConsumerState<MeshCoreDiscoveryScreen>
    with LifecycleSafeMixin {
  final _searchController = TextEditingController();
  String _query = '';
  _SortMode _sort = _SortMode.recent;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final adverts = ref.watch(meshCoreDiscoveredAdvertsProvider);
    final contacts = ref.watch(meshCoreContactsProvider).contacts;
    final importedKeys = contacts
        .map((c) => c.publicKeyHex.toLowerCase())
        .toSet();
    final filtered = _applyFilter(adverts);
    final sorted = _applySort(filtered);

    return GlassScaffold.body(
      title: l10n.meshcoreDiscoveryTitle,
      hasScrollBody: true,
      actions: [
        if (adverts.isNotEmpty)
          IconButton(
            key: const ValueKey('meshcore-discovery-clear-all'),
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: l10n.meshcoreDiscoveryClearAll,
            onPressed: () => _confirmClearAll(context),
          ),
      ],
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            _SearchSortBar(
              controller: _searchController,
              sort: _sort,
              onQueryChanged: (q) => setState(() => _query = q),
              onSortChanged: (m) => setState(() => _sort = m),
              l10n: l10n,
            ),
            Expanded(
              child: sorted.isEmpty
                  ? _emptyState(context, l10n)
                  : ListView.builder(
                      key: const ValueKey('meshcore-discovery-list'),
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spacing16,
                        AppTheme.spacing8,
                        AppTheme.spacing16,
                        AppTheme.spacing24,
                      ),
                      itemCount: sorted.length,
                      itemBuilder: (context, index) {
                        final advert = sorted[index];
                        final imported = importedKeys.contains(
                          advert.publicKeyHex,
                        );
                        return _AdvertRow(
                          key: ValueKey(
                            'meshcore-discovery-row-${advert.publicKeyHex}',
                          ),
                          advert: advert,
                          imported: imported,
                          onTap: () => _onTap(context, advert, imported),
                          onLongPress: () =>
                              _onLongPress(context, advert, imported),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<HeardAdvert> _applyFilter(List<HeardAdvert> adverts) {
    if (_query.isEmpty) return adverts;
    final q = _query.toLowerCase();
    return adverts
        .where((a) {
          final name = a.name.toLowerCase();
          final hex = a.publicKeyHex;
          return name.contains(q) || hex.contains(q);
        })
        .toList(growable: false);
  }

  List<HeardAdvert> _applySort(List<HeardAdvert> adverts) {
    if (_sort == _SortMode.recent) return adverts;
    final copy = List<HeardAdvert>.of(adverts);
    copy.sort((a, b) {
      final an = a.displayName.toLowerCase();
      final bn = b.displayName.toLowerCase();
      return an.compareTo(bn);
    });
    return copy;
  }

  Widget _emptyState(BuildContext context, AppLocalizations l10n) {
    return AnimatedEmptyState(
      config: AnimatedEmptyStateConfig(
        icons: const [
          Icons.podcasts_rounded,
          Icons.cell_tower_rounded,
          Icons.search_rounded,
        ],
        taglines: [
          l10n.meshcoreDiscoveryTagline1,
          l10n.meshcoreDiscoveryTagline2,
          l10n.meshcoreDiscoveryTagline3,
        ],
        titlePrefix: l10n.meshcoreDiscoveryEmptyTitlePrefix,
        titleKeyword: l10n.meshcoreDiscoveryEmptyTitleKeyword,
        titleSuffix: l10n.meshcoreDiscoveryEmptyTitleSuffix,
      ),
    );
  }

  Future<void> _onTap(
    BuildContext context,
    HeardAdvert advert,
    bool imported,
  ) async {
    HapticFeedback.selectionClick();
    if (imported) {
      // Find the live contact and route to the canonical D34c-A
      // detail screen.
      final contact = ref
          .read(meshCoreContactsProvider)
          .contacts
          .firstWhere(
            (c) => c.publicKeyHex.toLowerCase() == advert.publicKeyHex,
            orElse: () => _buildContactStub(advert),
          );
      await openMeshCoreContactDetail(context, contact: contact);
      return;
    }
    if (!advert.hasFullInfo || advert.advType == null) {
      showInfoSnackBar(context, context.l10n.meshcoreDiscoveryNeedFullAdvert);
      return;
    }
    await _addContact(context, advert);
  }

  void _onLongPress(BuildContext context, HeardAdvert advert, bool imported) {
    final l10n = context.l10n;
    HapticFeedback.mediumImpact();
    AppBottomSheet.showActions<void>(
      context: context,
      header: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            advert.displayName.isNotEmpty
                ? advert.displayName
                : l10n.meshcoreContactUnknownName,
            style: TextStyle(
              color: context.textPrimary,
              fontFamily: AppTheme.fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      actions: [
        if (imported)
          BottomSheetAction<void>(
            icon: Icons.info_outline_rounded,
            label: l10n.meshcoreContactDetailViewDetails,
            onTap: () {
              final contact = ref
                  .read(meshCoreContactsProvider)
                  .contacts
                  .firstWhere(
                    (c) => c.publicKeyHex.toLowerCase() == advert.publicKeyHex,
                    orElse: () => _buildContactStub(advert),
                  );
              openMeshCoreContactDetail(context, contact: contact);
            },
          ),
        if (!imported && advert.hasFullInfo && advert.advType != null)
          BottomSheetAction<void>(
            icon: Icons.person_add_alt_1_rounded,
            label: l10n.meshcoreDiscoveryAddContact,
            onTap: () => _addContact(context, advert),
          ),
        if (advert.hasFullInfo)
          BottomSheetAction<void>(
            icon: Icons.copy_rounded,
            label: l10n.meshcoreDiscoveryCopyContactCode,
            onTap: () => _copyContactCode(context, advert),
          ),
        BottomSheetAction<void>(
          icon: Icons.delete_outline_rounded,
          label: l10n.meshcoreDiscoveryDeleteEntry,
          isDestructive: true,
          onTap: () {
            ref
                .read(meshCoreDiscoveredAdvertsProvider.notifier)
                .remove(advert.publicKeyHex);
          },
        ),
      ],
    );
  }

  Future<void> _addContact(BuildContext context, HeardAdvert advert) async {
    final l10n = context.l10n;
    if (!advert.hasFullInfo || advert.advType == null) {
      showInfoSnackBar(context, l10n.meshcoreDiscoveryNeedFullAdvert);
      return;
    }
    final contact = MeshCoreContact(
      publicKey: advert.publicKey,
      name: advert.name,
      type: advert.advType!,
      pathLength: -1,
      path: Uint8List(0),
      lastSeen: advert.lastHeard,
    );
    final ok = await ref
        .read(meshCoreContactsProvider.notifier)
        .addContact(contact);
    if (!context.mounted) return;
    final name = advert.displayName.isNotEmpty
        ? advert.displayName
        : l10n.meshcoreContactUnknownName;
    if (ok) {
      showSuccessSnackBar(
        context,
        l10n.meshcoreDiscoveryAddContactSuccess(name),
      );
    } else {
      showErrorSnackBar(context, l10n.meshcoreDiscoveryAddContactFailed(name));
    }
  }

  Future<void> _copyContactCode(
    BuildContext context,
    HeardAdvert advert,
  ) async {
    final stub = _buildContactStub(advert);
    final code = generateContactCode(stub);
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    showSuccessSnackBar(context, context.l10n.meshcoreContactCodeCopied);
  }

  /// Build a transient `MeshCoreContact` from a `HeardAdvert`. Used for
  /// the "View Details on imported entry" path (when we know the
  /// contact exists but a refresh race left it missing locally) and
  /// for the "Copy contact code" action.
  MeshCoreContact _buildContactStub(HeardAdvert advert) {
    return MeshCoreContact(
      publicKey: advert.publicKey,
      name: advert.name,
      type: advert.advType ?? MeshCoreAdvType.chat,
      pathLength: -1,
      path: Uint8List(0),
      lastSeen: advert.lastHeard,
    );
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.meshcoreDiscoveryClearAll,
      message: context.l10n.meshcoreDiscoveryClearAllConfirm,
      confirmLabel: context.l10n.meshcoreDiscoveryClearAll,
      isDestructive: true,
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    ref.read(meshCoreDiscoveredAdvertsProvider.notifier).clearAll();
  }
}

/// Search field + sort toggle row above the list.
class _SearchSortBar extends StatelessWidget {
  final TextEditingController controller;
  final _SortMode sort;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_SortMode> onSortChanged;
  final AppLocalizations l10n;

  const _SearchSortBar({
    required this.controller,
    required this.sort,
    required this.onQueryChanged,
    required this.onSortChanged,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing12,
        AppTheme.spacing16,
        AppTheme.spacing8,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('meshcore-discovery-search-field'),
              controller: controller,
              maxLength: 64,
              autocorrect: false,
              onChanged: onQueryChanged,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: l10n.meshcoreDiscoverySearchHint,
                hintStyle: TextStyle(color: SemanticColors.muted),
                filled: true,
                fillColor: context.background,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing12,
                  vertical: AppTheme.spacing12,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: context.textSecondary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  borderSide: BorderSide(color: context.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  borderSide: BorderSide(color: context.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  borderSide: BorderSide(color: accent),
                ),
                counterText: '',
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          IconButton(
            key: const ValueKey('meshcore-discovery-sort-toggle'),
            icon: Icon(
              sort == _SortMode.recent
                  ? Icons.schedule_rounded
                  : Icons.sort_by_alpha_rounded,
              color: accent,
            ),
            tooltip: sort == _SortMode.recent
                ? l10n.meshcoreDiscoverySortRecent
                : l10n.meshcoreDiscoverySortAlpha,
            onPressed: () => onSortChanged(
              sort == _SortMode.recent
                  ? _SortMode.alphabetical
                  : _SortMode.recent,
            ),
          ),
        ],
      ),
    );
  }
}

/// One row in the discovery list. Renders identity (name / fingerprint),
/// adv-type label, relative last-heard, and the "Imported" / "Heard"
/// badge derived from cross-referencing the live contact list.
class _AdvertRow extends StatelessWidget {
  final HeardAdvert advert;
  final bool imported;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _AdvertRow({
    super.key,
    required this.advert,
    required this.imported,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = context.accentColor;
    final name = advert.displayName.isNotEmpty
        ? advert.displayName
        : advert.shortPubKeyHex;
    final typeLabel = _advTypeLabel(context, advert.advType);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing12,
        ),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // D-S5: pubkey-derived sigil for visual identity. The
            // advert type (repeater / chat node) is still surfaced as
            // text in the meta row below, so swapping the leading icon
            // to a sigil does not lose type discrimination - it adds
            // identity-glance on top of it.
            if (advert.publicKey.length >= 4)
              MeshCoreSigilAvatar(pubKey: advert.publicKey, size: 32)
            else
              Icon(
                advert.advType == MeshCoreAdvType.repeater
                    ? Icons.cell_tower_rounded
                    : Icons.person_rounded,
                color: imported ? accent : context.textSecondary,
              ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing2),
                  Wrap(
                    spacing: AppTheme.spacing8,
                    runSpacing: 2,
                    children: [
                      Text(
                        typeLabel,
                        style: TextStyle(
                          color: context.textTertiary,
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        advert.shortPubKeyHex,
                        style: TextStyle(
                          color: context.textTertiary,
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        l10n.meshcoreDiscoveryLastHeard(
                          _relativeTime(context, advert.lastHeard),
                        ),
                        style: TextStyle(
                          color: context.textTertiary,
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spacing8),
            _Badge(
              label: imported
                  ? l10n.meshcoreDiscoveryBadgeImported
                  : l10n.meshcoreDiscoveryBadgeHeard,
              accent: imported ? accent : context.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  String _advTypeLabel(BuildContext context, int? type) {
    final l10n = context.l10n;
    switch (type) {
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

  String _relativeTime(BuildContext context, DateTime ts) {
    final l10n = context.l10n;
    final delta = DateTime.now().difference(ts);
    if (delta.inSeconds < 60) return l10n.meshcoreDiscoveryJustNow;
    if (delta.inMinutes < 60) return '${delta.inMinutes}m';
    if (delta.inHours < 24) return '${delta.inHours}h';
    return '${delta.inDays}d';
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color accent;

  const _Badge({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: accent,
          fontFamily: AppTheme.fontFamily,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Convenience launcher mirroring `openMeshCoreContactDetail`.
Future<void> openMeshCoreDiscoveryScreen(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const MeshCoreDiscoveryScreen()),
  );
}
