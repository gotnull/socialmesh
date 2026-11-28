// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Hand-built route for the MeshCore Trace Path sheet. The user taps known
// repeaters in the order the trace should travel, or types a key prefix
// for one the radio has not heard, then reorders, reverses, and chooses
// whether the trace comes back the same way. The route is held for the app
// session so it survives closing the sheet between attempts.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/chip_selector.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/settings_primitives.dart';
import '../../../models/meshcore_contact.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../services/haptic_service.dart';
import '../../../services/meshcore/routing/meshcore_trace_path.dart';
import '../../../utils/encoding.dart';

/// One hop on a hand-built trace route.
class MeshCoreTraceRouteHop {
  MeshCoreTraceRouteHop({required this.key, this.contact});

  /// The full public key of a known repeater, or the prefix bytes typed
  /// for an unknown one.
  final Uint8List key;

  /// The known repeater or room server, when there is one.
  final MeshCoreContact? contact;

  /// The hop's hash at [size] bytes, or null when a typed prefix is
  /// shorter than that.
  Uint8List? hashAt(int size) =>
      key.length < size ? null : Uint8List.fromList(key.sublist(0, size));
}

/// The route being built in the Trace Path sheet.
class MeshCoreTraceRouteDraft {
  const MeshCoreTraceRouteDraft({
    this.hops = const [],
    this.returnSameWay = true,
    this.hashSize = 1,
  });

  final List<MeshCoreTraceRouteHop> hops;
  final bool returnSameWay;

  /// Bytes of key prefix per hop: 1, 2 or 4.
  final int hashSize;

  /// The request for this route, or null when it cannot be sent: empty,
  /// a typed hop shorter than [hashSize], or over the payload limit.
  MeshCoreTraceRequest? get request {
    final hashes = <Uint8List>[];
    for (final hop in hops) {
      final hash = hop.hashAt(hashSize);
      if (hash == null) return null;
      hashes.add(hash);
    }
    return buildMeshCoreRouteTraceRequest(
      hops: hashes,
      hashSize: hashSize,
      returnSameWay: returnSameWay,
    );
  }

  MeshCoreTraceRouteDraft copyWith({
    List<MeshCoreTraceRouteHop>? hops,
    bool? returnSameWay,
    int? hashSize,
  }) => MeshCoreTraceRouteDraft(
    hops: hops ?? this.hops,
    returnSameWay: returnSameWay ?? this.returnSameWay,
    hashSize: hashSize ?? this.hashSize,
  );
}

class MeshCoreTraceRouteNotifier extends Notifier<MeshCoreTraceRouteDraft> {
  String? _radio;

  @override
  MeshCoreTraceRouteDraft build() {
    // A route is made of one mesh's repeaters: start again when a
    // different radio connects, but keep it across a reconnect of the same
    // one (the prefix is empty while disconnected).
    ref.listen<String>(meshCoreSelfPubKeyPrefixProvider, (_, next) {
      if (next.isEmpty) return;
      if (_radio != null && _radio != next) {
        state = const MeshCoreTraceRouteDraft();
      }
      _radio = next;
    }, fireImmediately: true);
    return const MeshCoreTraceRouteDraft();
  }

  void add(MeshCoreTraceRouteHop hop) =>
      state = state.copyWith(hops: [...state.hops, hop]);

  void removeAt(int index) =>
      state = state.copyWith(hops: [...state.hops]..removeAt(index));

  /// Moves a hop, with [ReorderableListView]'s indices: [newIndex] counts
  /// the moved hop's old slot.
  void move(int oldIndex, int newIndex) {
    final hops = [...state.hops];
    final hop = hops.removeAt(oldIndex);
    hops.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, hop);
    state = state.copyWith(hops: hops);
  }

  void reverse() => state = state.copyWith(hops: state.hops.reversed.toList());

  void clear() => state = state.copyWith(hops: const []);

  void setReturnSameWay(bool value) =>
      state = state.copyWith(returnSameWay: value);

  void setHashSize(int value) => state = state.copyWith(hashSize: value);
}

final meshCoreTraceRouteProvider =
    NotifierProvider<MeshCoreTraceRouteNotifier, MeshCoreTraceRouteDraft>(
      MeshCoreTraceRouteNotifier.new,
    );

/// A key prefix typed in search: 1, 2 or 4 bytes of hex. Null otherwise.
Uint8List? parseMeshCoreTraceHopPrefix(String query) {
  final hex = query.replaceAll(RegExp(r'\s'), '');
  if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) return null;
  if (!kMeshCoreTraceHashSizes.contains(hex.length ~/ 2) || hex.length.isOdd) {
    return null;
  }
  return HexUtils.fromHex(hex);
}

/// Upper-case hex of [bytes], the way repeater prefixes are written.
String meshCoreTraceHex(List<int> bytes) => HexUtils.toHex(bytes).toUpperCase();

/// Name for a trace hop hash: the known repeater when exactly one matches,
/// otherwise null.
String? meshCoreTraceHopName(List<int> hash, List<MeshCoreContact> contacts) {
  final matches = meshCoreTraceHopCandidates(hash, contacts);
  return matches.length == 1 ? matches.single.displayName : null;
}

/// The route editor and repeater list for the custom-route mode of the
/// Trace Path sheet. Lays out as children of the sheet's list, which gives
/// it no horizontal padding: rows that carry no inset of their own get
/// [AppTheme.spacing16] here.
class MeshCoreTraceRouteBuilder extends ConsumerWidget {
  const MeshCoreTraceRouteBuilder({
    super.key,
    required this.searchQuery,
    required this.onHopAdded,
  });

  /// The sheet's search text, which filters the repeater list and can be
  /// a key prefix to add directly.
  final String searchQuery;

  /// Called after a hop is added, so the sheet can clear its search.
  final VoidCallback onHopAdded;

  static const _inset = EdgeInsets.symmetric(horizontal: AppTheme.spacing16);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final draft = ref.watch(meshCoreTraceRouteProvider);
    final notifier = ref.read(meshCoreTraceRouteProvider.notifier);
    final contacts = ref.watch(meshCoreContactsProvider).contacts;
    final haptics = ref.read(hapticServiceProvider);

    void setReturn(bool value) {
      haptics.trigger(HapticType.selection);
      notifier.setReturnSameWay(value);
    }

    void addHop(MeshCoreTraceRouteHop hop) {
      haptics.trigger(HapticType.selection);
      notifier.add(hop);
      onHopAdded();
    }

    final query = searchQuery.trim().toLowerCase();
    final repeaters =
        contacts
            .where((c) => c.isRepeater || c.isRoom)
            .where(
              (c) =>
                  query.isEmpty ||
                  c.displayName.toLowerCase().contains(query) ||
                  c.publicKeyHex.startsWith(query),
            )
            .toList()
          ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    final typedPrefix = parseMeshCoreTraceHopPrefix(query);
    final offerTyped = typedPrefix != null && repeaters.isEmpty;

    final maxHops = meshCoreRouteTraceMaxHops(
      hashSize: draft.hashSize,
      returnSameWay: draft.returnSameWay,
    );
    final overLimit = draft.hops.length > maxHops;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // While searching, the route shrinks to its one-line sequence so the
        // matches stay above the keyboard; it comes back once a hop is added.
        if (query.isNotEmpty && draft.hops.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              0,
              AppTheme.spacing16,
              AppTheme.spacing8,
            ),
            child: Text(
              _routeSequence(context, draft, [
                for (final h in draft.hops) _hopName(context, h, contacts),
              ]),
              style: context.bodySmallStyle?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
        if (query.isEmpty) ...[
          Padding(
            padding: _inset,
            child: SectionTitle(
              title: l.meshcoreTraceRouteTitle,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: l.meshcoreTraceRouteReverse,
                    icon: const Icon(Icons.swap_vert_rounded),
                    onPressed: draft.hops.length < 2
                        ? null
                        : () {
                            haptics.trigger(HapticType.light);
                            notifier.reverse();
                          },
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: l.meshcoreTraceRouteClear,
                    icon: const Icon(Icons.clear_all_rounded),
                    onPressed: draft.hops.isEmpty
                        ? null
                        : () {
                            haptics.trigger(HapticType.light);
                            notifier.clear();
                          },
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: _inset,
            child: _RouteCard(draft: draft, contacts: contacts),
          ),
          if (draft.hops.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                AppTheme.spacing8,
                AppTheme.spacing16,
                0,
              ),
              child: Text(
                overLimit
                    ? l.meshcoreTraceRouteTooLong(maxHops)
                    : l.meshcoreTraceRouteCapacity(draft.hops.length, maxHops),
                style: context.bodySmallStyle?.copyWith(
                  color: overLimit
                      ? SemanticColors.error
                      : context.textTertiary,
                ),
              ),
            ),
          const SizedBox(height: AppTheme.spacing12),
          SettingsTile(
            icon: Icons.u_turn_left_rounded,
            title: l.meshcoreTraceRouteReturnTitle,
            subtitle: draft.returnSameWay
                ? l.meshcoreTraceRouteReturnOn
                : l.meshcoreTraceRouteReturnOff,
            crossAxisAlignment: CrossAxisAlignment.start,
            // The whole row toggles, not only the switch.
            onTap: () => setReturn(!draft.returnSameWay),
            trailing: ThemedSwitch(
              value: draft.returnSameWay,
              onChanged: setReturn,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          Padding(
            padding: _inset,
            child: SectionTitle(title: l.meshcoreTraceRouteHashSize),
          ),
          Padding(
            padding: _inset,
            child: ChipSelector<int>(
              value: draft.hashSize,
              alignment: WrapAlignment.start,
              options: [
                for (final size in kMeshCoreTraceHashSizes)
                  ChipOption(
                    value: size,
                    label: l.meshcoreTraceRouteHashBytes(size),
                    color: context.accentColor,
                  ),
              ],
              onChanged: (v) {
                haptics.trigger(HapticType.selection);
                notifier.setHashSize(v);
              },
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
        ],
        Padding(
          padding: _inset,
          child: SectionTitle(title: l.meshcoreTraceRouteAddTitle),
        ),
        if (offerTyped)
          Padding(
            padding: _inset,
            child: _PickRow(
              icon: Icons.add_rounded,
              title: l.meshcoreTraceRouteAddPrefix(
                meshCoreTraceHex(typedPrefix),
              ),
              subtitle: l.meshcoreTraceRouteUnknownHop,
              onTap: () => addHop(MeshCoreTraceRouteHop(key: typedPrefix)),
            ),
          ),
        if (repeaters.isEmpty && !offerTyped)
          Padding(
            padding: _inset,
            child: Text(
              l.meshcoreTraceRouteNoRepeaters,
              style: context.bodySmallStyle?.copyWith(
                color: context.textTertiary,
              ),
            ),
          ),
        for (final c in repeaters)
          Padding(
            padding: _inset,
            child: _PickRow(
              icon: c.isRoom ? Icons.forum_rounded : Icons.cell_tower_rounded,
              title: c.displayName.isNotEmpty
                  ? c.displayName
                  : l.meshcoreContactUnknownName,
              subtitle: meshCoreTraceHex(
                c.publicKey.sublist(0, draft.hashSize),
              ),
              onTap: () =>
                  addHop(MeshCoreTraceRouteHop(key: c.publicKey, contact: c)),
            ),
          ),
      ],
    );
  }
}

String _hopName(
  BuildContext context,
  MeshCoreTraceRouteHop hop,
  List<MeshCoreContact> contacts,
) {
  final l = context.l10n;
  final contact = hop.contact;
  if (contact != null) {
    return contact.displayName.isNotEmpty
        ? contact.displayName
        : l.meshcoreContactUnknownName;
  }
  return meshCoreTraceHopName(hop.key, contacts) ??
      l.meshcoreTraceRouteUnknownHop;
}

// The whole journey as sent, starting and ending at the user's radio:
// "You -> A -> B -> A -> You".
String _routeSequence(
  BuildContext context,
  MeshCoreTraceRouteDraft draft,
  List<String> names,
) {
  final you = context.l10n.meshcoreTraceRouteYou;
  return [
    you,
    ...names,
    if (draft.returnSameWay && names.length > 1)
      ...names.sublist(0, names.length - 1).reversed,
    you,
  ].join(' \u2192 ');
}

class _RouteCard extends ConsumerWidget {
  const _RouteCard({required this.draft, required this.contacts});

  final MeshCoreTraceRouteDraft draft;
  final List<MeshCoreContact> contacts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final notifier = ref.read(meshCoreTraceRouteProvider.notifier);
    final haptics = ref.read(hapticServiceProvider);
    final hops = draft.hops;

    final names = [for (final h in hops) _hopName(context, h, contacts)];

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hops.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Text(
                l.meshcoreTraceRouteEmpty,
                style: context.bodySmallStyle?.copyWith(
                  color: context.textSecondary,
                ),
              ),
            )
          else ...[
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: hops.length,
              onReorder: (from, to) {
                haptics.trigger(HapticType.selection);
                notifier.move(from, to);
              },
              itemBuilder: (context, i) => _HopRow(
                key: ObjectKey(hops[i]),
                index: i,
                hop: hops[i],
                name: names[i],
                hashSize: draft.hashSize,
                contacts: contacts,
                onRemove: () {
                  haptics.trigger(HapticType.light);
                  notifier.removeAt(i);
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              child: Text(
                _routeSequence(context, draft, names),
                style: context.bodySmallStyle?.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HopRow extends StatelessWidget {
  const _HopRow({
    super.key,
    required this.index,
    required this.hop,
    required this.name,
    required this.hashSize,
    required this.contacts,
    required this.onRemove,
  });

  final int index;
  final MeshCoreTraceRouteHop hop;
  final String name;
  final int hashSize;
  final List<MeshCoreContact> contacts;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final hash = hop.hashAt(hashSize);
    final shared = hash == null
        ? 0
        : meshCoreTraceHopCandidates(hash, contacts).length;
    final String? problem;
    final Color problemColor;
    if (hash == null) {
      problem = l.meshcoreTraceRouteHopTooShort(hashSize);
      problemColor = SemanticColors.error;
    } else if (shared > 1) {
      problem = l.meshcoreTraceRouteAmbiguous(shared);
      problemColor = SemanticColors.warning;
    } else {
      problem = null;
      problemColor = context.textTertiary;
    }

    return Material(
      color: context.card,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacing12,
          AppTheme.spacing8,
          AppTheme.spacing4,
          AppTheme.spacing8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: AppTheme.spacing24,
              height: AppTheme.spacing24,
              margin: const EdgeInsets.only(top: AppTheme.spacing2),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
              child: Text(
                '${index + 1}',
                style: context.bodySmallStyle?.copyWith(
                  color: context.accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: context.bodySecondaryStyle?.copyWith(
                      color: context.textPrimary,
                    ),
                  ),
                  Text(
                    meshCoreTraceHex(hash ?? hop.key),
                    style: context.bodySmallStyle?.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
                  if (problem != null)
                    Text(
                      problem,
                      style: context.bodySmallStyle?.copyWith(
                        color: problemColor,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: l.meshcoreTraceRouteRemoveHop,
              icon: Icon(Icons.close_rounded, color: context.textTertiary),
              onPressed: onRemove,
            ),
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing8),
                child: Icon(
                  Icons.drag_handle_rounded,
                  color: context.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Its own semantics node, so iOS exposes each repeater as a separate
    // button instead of folding the list into one.
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacing4),
        child: Material(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            dense: true,
            leading: Icon(icon, color: context.textSecondary),
            title: Text(title, style: TextStyle(color: context.textPrimary)),
            subtitle: Text(
              subtitle,
              style: TextStyle(color: context.textTertiary),
            ),
            trailing: Icon(
              Icons.add_circle_outline_rounded,
              color: context.accentColor,
            ),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}
