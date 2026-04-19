// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// SIP-NodeDex Bridge — connects SIP identity data to NodeDex entries.
//
// When SIP discovers a peer or verifies an identity claim, this bridge
// updates the corresponding NodeDex entry with SIP-specific fields:
// sipCapable, sipPubkey, sipPersonaId, sipIdentityState, sipDisplayName.
//
// The bridge also regenerates the sigil from persona_id when available,
// so SIP-verified peers get an identity-stable sigil instead of one
// derived from the hardware-assigned node number.

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../features/nodedex/models/nodedex_entry.dart';
import '../features/nodedex/providers/nodedex_providers.dart';
import '../features/nodedex/services/sigil_generator.dart';
import '../services/protocol/sip/sip_types.dart';

/// Result of a bridge update operation.
class SipNodeDexUpdate {
  /// The updated NodeDex entry with SIP fields applied.
  final NodeDexEntry entry;

  /// Whether the sigil was regenerated from persona_id.
  final bool sigilChanged;

  /// Whether the identity state changed (e.g. TOFU -> PINNED).
  final bool stateChanged;

  const SipNodeDexUpdate({
    required this.entry,
    this.sigilChanged = false,
    this.stateChanged = false,
  });
}

/// Bridges SIP identity data into NodeDex entries.
///
/// This is a stateless utility class. It transforms NodeDex entries
/// by applying SIP identity information. The caller is responsible
/// for persisting the updated entries via NodeDexNotifier.
abstract final class SipNodeDexBridge {
  /// Mark a node as SIP-capable after receiving a valid SIP beacon.
  ///
  /// Sets sipCapable=true without changing identity fields. Called
  /// when a CAP_BEACON is received from a peer, before any identity
  /// exchange has occurred.
  static SipNodeDexUpdate markSipCapable(NodeDexEntry entry) {
    if (entry.sipCapable == true) {
      return SipNodeDexUpdate(entry: entry);
    }

    AppLogging.sip(
      'SIP_NODEDEX: marking node=${_hex(entry.nodeNum)} as sip_capable', // lint-allow: hardcoded-string
    );

    return SipNodeDexUpdate(
      entry: entry.copyWith(sipCapable: true),
      stateChanged: true,
    );
  }

  /// Apply a verified SIP identity claim to a NodeDex entry.
  ///
  /// Updates sipCapable, sipPubkey, sipPersonaId, sipIdentityState,
  /// and sipDisplayName. If the persona_id is new or changed, the
  /// sigil is regenerated from persona_id bytes to provide an
  /// identity-stable visual identity.
  ///
  /// [nodeId] is the Meshtastic node number.
  /// [pubkey] is the 32-byte Ed25519 public key.
  /// [personaId] is the 16-byte persona ID derived from the public key.
  /// [identityState] is the resulting trust state (e.g. verifiedTofu).
  /// [displayName] is the peer's self-reported name (optional).
  static SipNodeDexUpdate applyIdentityClaim({
    required NodeDexEntry entry,
    required Uint8List pubkey,
    required Uint8List personaId,
    required SipIdentityState identityState,
    String? displayName,
  }) {
    final previousState = entry.sipIdentityState;
    final stateChanged = previousState != identityState;

    // Generate sigil from persona_id if available and different.
    final bool sigilChanged;
    final SigilData newSigil;
    if (entry.sipPersonaId == null ||
        !_bytesEqual(entry.sipPersonaId!, personaId)) {
      newSigil = SigilGenerator.generateFromPersonaId(personaId);
      sigilChanged = true;
    } else {
      newSigil = entry.sigil ?? SigilGenerator.generateFromPersonaId(personaId);
      sigilChanged = false;
    }

    AppLogging.sip(
      'SIP_NODEDEX: updating node=${_hex(entry.nodeNum)} -> ' // lint-allow: hardcoded-string
      'sip_capable=true, ' // lint-allow: hardcoded-string
      'persona_id=${_hexBytes(personaId)}, ' // lint-allow: hardcoded-string
      'identity_state=${identityState.name}', // lint-allow: hardcoded-string
    );

    if (sigilChanged) {
      AppLogging.sip(
        'SIP_NODEDEX: sigil derived from persona_id ' // lint-allow: hardcoded-string
        '(not node_num) for node=${_hex(entry.nodeNum)}', // lint-allow: hardcoded-string
      );
    }

    return SipNodeDexUpdate(
      entry: entry.copyWith(
        sipCapable: true,
        sipPubkey: pubkey,
        sipPersonaId: personaId,
        sipIdentityState: identityState,
        sipDisplayName: displayName,
        sigil: newSigil,
      ),
      sigilChanged: sigilChanged,
      stateChanged: stateChanged,
    );
  }

  /// Update only the identity state of an existing SIP entry.
  ///
  /// Used when the user pins, unpins, or accepts a changed key
  /// without a new identity claim being received.
  static SipNodeDexUpdate updateIdentityState({
    required NodeDexEntry entry,
    required SipIdentityState newState,
  }) {
    if (entry.sipIdentityState == newState) {
      return SipNodeDexUpdate(entry: entry);
    }

    AppLogging.sip(
      'SIP_NODEDEX: state change for node=${_hex(entry.nodeNum)}: ' // lint-allow: hardcoded-string
      '${entry.sipIdentityState?.name ?? "null"} -> ${newState.name}', // lint-allow: hardcoded-string
    );

    return SipNodeDexUpdate(
      entry: entry.copyWith(sipIdentityState: newState),
      stateChanged: true,
    );
  }

  /// Find all NodeDex entries that share the same pubkey.
  ///
  /// A single SIP identity (same Ed25519 key) may appear on different
  /// node IDs over time. This method finds all entries using the same
  /// public key, enabling the UI to show them as the same identity.
  static List<NodeDexEntry> findEntriesByPubkey(
    Map<int, NodeDexEntry> allEntries,
    Uint8List pubkey,
  ) {
    return allEntries.values
        .where((e) => e.sipPubkey != null && _bytesEqual(e.sipPubkey!, pubkey))
        .toList();
  }

  /// Clear SIP identity data from an entry.
  ///
  /// Resets all SIP fields and regenerates the sigil from node number.
  /// Used when identity data is explicitly rejected or cleared.
  static SipNodeDexUpdate clearIdentity(NodeDexEntry entry) {
    AppLogging.sip(
      'SIP_NODEDEX: clearing identity for node=${_hex(entry.nodeNum)}', // lint-allow: hardcoded-string
    );

    return SipNodeDexUpdate(
      entry: entry.copyWith(
        clearSipCapable: true,
        clearSipPubkey: true,
        clearSipPersonaId: true,
        clearSipIdentityState: true,
        clearSipDisplayName: true,
        clearMrrpServiceIds: true,
        sigil: SigilGenerator.generate(entry.nodeNum),
      ),
      sigilChanged: true,
      stateChanged: true,
    );
  }

  /// Apply discovered MRRP service IDs from a SERVICE_ADVERT frame.
  ///
  /// Stores service IDs as a comma-separated string of decimal values.
  /// No-op if the service IDs are unchanged.
  static SipNodeDexUpdate applyMrrpServices({
    required NodeDexEntry entry,
    required List<int> serviceIds,
  }) {
    final sorted = List<int>.from(serviceIds)..sort();
    final csv = sorted.join(','); // lint-allow: hardcoded-string
    if (entry.mrrpServiceIds == csv) {
      return SipNodeDexUpdate(entry: entry);
    }

    AppLogging.sip(
      'SIP_NODEDEX: MRRP services for node=${_hex(entry.nodeNum)}: $csv', // lint-allow: hardcoded-string
    );

    return SipNodeDexUpdate(
      entry: entry.copyWith(mrrpServiceIds: csv),
      stateChanged: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _hex(int nodeNum) =>
      '0x${nodeNum.toRadixString(16).toUpperCase()}'; // lint-allow: hardcoded-string

  static String _hexBytes(Uint8List bytes) {
    if (bytes.length <= 4) {
      return bytes
          .map(
            (b) => b.toRadixString(16).padLeft(2, '0').toUpperCase(),
          ) // lint-allow: hardcoded-string
          .join();
    }
    return '${bytes.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join()}...'; // lint-allow: hardcoded-string
  }

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ---------------------------------------------------------------------------
// Provider-aware bridge helpers
// ---------------------------------------------------------------------------

/// Marks a node as SIP-capable in NodeDex (called on CAP_BEACON receipt).
///
/// If the entry exists, applies [SipNodeDexBridge.markSipCapable] and
/// persists via [NodeDexNotifier.applySipUpdate].
void sipBridgeMarkCapable(WidgetRef ref, int nodeId) {
  final entries = ref.read(nodeDexProvider);
  final existing = entries[nodeId];
  if (existing == null) return;

  final result = SipNodeDexBridge.markSipCapable(existing);
  if (result.stateChanged) {
    ref.read(nodeDexProvider.notifier).applySipUpdate(result.entry);
  }
}

/// Overload for use inside providers (Ref rather than WidgetRef).
void sipBridgeMarkCapableFromRef(Ref ref, int nodeId) {
  final entries = ref.read(nodeDexProvider);
  final existing = entries[nodeId];
  if (existing == null) return;

  final result = SipNodeDexBridge.markSipCapable(existing);
  if (result.stateChanged) {
    ref.read(nodeDexProvider.notifier).applySipUpdate(result.entry);
  }
}

/// Applies a verified identity claim to a NodeDex entry.
///
/// If the entry exists, applies [SipNodeDexBridge.applyIdentityClaim] and
/// persists via [NodeDexNotifier.applySipUpdate].
void sipBridgeApplyIdentity({
  required Ref ref,
  required int nodeId,
  required Uint8List pubkey,
  required Uint8List personaId,
  required SipIdentityState identityState,
  String? displayName,
}) {
  final entries = ref.read(nodeDexProvider);
  final existing = entries[nodeId];
  if (existing == null) return; // not yet in NodeDex

  final result = SipNodeDexBridge.applyIdentityClaim(
    entry: existing,
    pubkey: pubkey,
    personaId: personaId,
    identityState: identityState,
    displayName: displayName,
  );

  if (result.stateChanged || result.sigilChanged) {
    ref.read(nodeDexProvider.notifier).applySipUpdate(result.entry);
  }
}

/// Updates the identity state of a NodeDex entry (e.g. pin, accept changed key).
void sipBridgeUpdateState({
  required Ref ref,
  required int nodeId,
  required SipIdentityState newState,
}) {
  final entries = ref.read(nodeDexProvider);
  final existing = entries[nodeId];
  if (existing == null) return;

  final result = SipNodeDexBridge.updateIdentityState(
    entry: existing,
    newState: newState,
  );

  if (result.stateChanged) {
    ref.read(nodeDexProvider.notifier).applySipUpdate(result.entry);
  }
}

/// Writes discovered MRRP service IDs to the NodeDex entry for a peer.
///
/// Called when a SERVICE_ADVERT frame is received. The entry must already
/// exist in NodeDex; if it does not, this is a no-op.
void sipBridgeApplyMrrpServices({
  required Ref ref,
  required int nodeId,
  required List<int> serviceIds,
}) {
  final entries = ref.read(nodeDexProvider);
  final existing = entries[nodeId];
  if (existing == null) return;

  final result = SipNodeDexBridge.applyMrrpServices(
    entry: existing,
    serviceIds: serviceIds,
  );

  if (result.stateChanged) {
    ref.read(nodeDexProvider.notifier).applySipUpdate(result.entry);
  }
}
