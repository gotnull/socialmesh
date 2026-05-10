// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// Providers for MeshCore integration and protocol-agnostic device info.
//
// These providers enable the UI to access protocol-agnostic device
// information without depending on Meshtastic or MeshCore specific code.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging.dart';
import '../core/transport.dart';
import '../models/mesh_device.dart';
import '../models/meshcore_contact.dart';
import '../models/meshcore_channel.dart';
import '../services/meshcore/connection_coordinator.dart';
import '../services/meshcore/meshcore_adapter.dart';
import '../services/meshcore/meshcore_detector.dart';
import '../services/meshcore/meshcore_send_rate_limiter.dart';
import '../services/meshcore/protocol/meshcore_capture.dart';
import '../services/meshcore/protocol/meshcore_messages.dart';
import '../services/meshcore/protocol/meshcore_session.dart';
import 'app_providers.dart';
import 'connection_providers.dart';

/// Provider for the connection coordinator singleton.
///
/// The coordinator handles protocol detection and routes connections
/// to the appropriate adapter (Meshtastic or MeshCore).
final connectionCoordinatorProvider = Provider<ConnectionCoordinator>((ref) {
  final coordinator = ConnectionCoordinator();

  ref.onDispose(() {
    coordinator.dispose();
  });

  return coordinator;
});

/// Reactive provider for MeshCore connection state.
///
/// This StreamProvider watches the coordinator's stateStream, making the
/// connection state reactive. Dependent providers (like linkStatusProvider)
/// will rebuild when MeshCore connects/disconnects.
///
/// CRITICAL: This fixes the shell navigation bug where MeshCore connections
/// weren't triggering UI rebuilds because connectionCoordinatorProvider is
/// a plain Provider that doesn't notify on internal state changes.
///
/// The stream is seeded with the current connection state so new subscribers
/// immediately see the current state, not just future changes.
final meshCoreConnectionStateProvider = StreamProvider<MeshConnectionState>((
  ref,
) {
  final coordinator = ref.watch(connectionCoordinatorProvider);

  // Determine current state from coordinator
  MeshConnectionState currentState;
  if (coordinator.isConnected) {
    currentState = MeshConnectionState.connected;
  } else if (coordinator.isConnecting) {
    currentState = MeshConnectionState.connecting;
  } else {
    currentState = MeshConnectionState.disconnected;
  }

  // Emit current state first, then forward all future state changes.
  // This ensures new subscribers see the current state immediately.
  return Stream.value(currentState).asyncExpand((initial) async* {
    yield initial;
    await for (final state in coordinator.stateStream) {
      yield state;
    }
  });
});

/// Provider for the current protocol-agnostic device info.
///
/// This provides a unified view of the connected device regardless of
/// whether it's Meshtastic or MeshCore. UI components should use this
/// instead of protocol-specific providers.
///
/// Returns null when not connected or not yet identified.
///
/// D24.A: watches [meshCoreConnectionStateProvider] so the value is
/// reactive across the MeshCore identify transition. The
/// `connectionCoordinatorProvider` itself is a singleton-holder
/// (`==` returns true on every rebuild), so watching only it would
/// freeze this provider at its first value (typically `null` at app
/// launch, before connect). Pre-D24 every consumer that opened
/// before identify completed had to manually refresh; the
/// connection-state watch closes that gap.
final meshDeviceInfoProvider = Provider<MeshDeviceInfo?>((ref) {
  // Force a rebuild on each MeshCore connection-state transition
  // (disconnected → connecting → identifying → connected). The
  // `connected` emission happens AFTER identify succeeds and
  // `_currentDeviceInfo` is populated, so the freshly-read
  // `coordinator.deviceInfo` below will pick it up.
  ref.watch(meshCoreConnectionStateProvider);

  // Check coordinator first for MeshCore devices
  final coordinator = ref.watch(connectionCoordinatorProvider);
  if (coordinator.deviceInfo != null) {
    return coordinator.deviceInfo;
  }

  // Fall back to Meshtastic protocol service for Meshtastic devices
  final connectionState = ref.watch(deviceConnectionProvider);
  if (!connectionState.isConnected) {
    return null;
  }

  // Get Meshtastic device info from protocol service
  final protocol = ref.watch(protocolServiceProvider);
  final myNodeNum = protocol.myNodeNum;
  if (myNodeNum == null) {
    return null;
  }

  // Get node info from the nodes map
  final myNode = protocol.nodes[myNodeNum];
  final displayName =
      myNode?.longName ?? myNode?.shortName ?? 'Meshtastic Device';
  final firmwareVersion = myNode?.firmwareVersion;
  final hardwareModel = myNode?.hardwareModel;

  // Build MeshDeviceInfo from Meshtastic protocol service
  return MeshDeviceInfo(
    protocolType: MeshProtocolType.meshtastic,
    displayName: displayName,
    nodeId: myNodeNum.toRadixString(16).toUpperCase(),
    firmwareVersion: firmwareVersion,
    hardwareModel: hardwareModel,
  );
});

/// Provider for the detected protocol type of the connected device.
///
/// Returns unknown when not connected.
final meshProtocolTypeProvider = Provider<MeshProtocolType>((ref) {
  final deviceInfo = ref.watch(meshDeviceInfoProvider);
  return deviceInfo?.protocolType ?? MeshProtocolType.unknown;
});

/// Provider for the MeshCore adapter (null if not connected or not MeshCore).
///
/// Use this to access MeshCore-specific functionality like the session.
///
/// CRITICAL: Watches [meshCoreConnectionStateProvider] for reactivity.
/// `connectionCoordinatorProvider` is a plain `Provider` holding the
/// singleton: `ref.watch` on it never fires again because the
/// coordinator instance compares `==` to itself across rebuilds.
/// Without the connection-state watch, this provider freezes at its
/// first-built value (typically `null` at app launch, before connect).
/// Downstream watchers (`meshCoreSessionProvider`, contacts/channels
/// notifiers) would then never see the post-connect adapter.
final meshCoreAdapterProvider = Provider<MeshCoreAdapter?>((ref) {
  ref.watch(meshCoreConnectionStateProvider);
  final coordinator = ref.watch(connectionCoordinatorProvider);
  return coordinator.meshCoreAdapter;
});

/// Provider for the MeshCore session (null if not connected or not MeshCore).
///
/// Use this for direct protocol operations on MeshCore devices.
final meshCoreSessionProvider = Provider<MeshCoreSession?>((ref) {
  final adapter = ref.watch(meshCoreAdapterProvider);
  return adapter?.session;
});

// ---------------------------------------------------------------------------
// MeshCore Self Info Provider
// ---------------------------------------------------------------------------

/// Cached self info for the connected MeshCore device.
///
/// Provides the device's own identity information including public key and name.
class MeshCoreSelfInfoState {
  final MeshCoreSelfInfo? selfInfo;
  final bool isLoading;
  final String? error;

  const MeshCoreSelfInfoState({
    this.selfInfo,
    this.isLoading = false,
    this.error,
  });

  const MeshCoreSelfInfoState.initial()
    : selfInfo = null,
      isLoading = false,
      error = null;
  const MeshCoreSelfInfoState.loading()
    : selfInfo = null,
      isLoading = true,
      error = null;
  MeshCoreSelfInfoState.loaded(MeshCoreSelfInfo info)
    : selfInfo = info,
      isLoading = false,
      error = null;
  MeshCoreSelfInfoState.failed(String msg)
    : selfInfo = null,
      isLoading = false,
      error = msg;
}

class MeshCoreSelfInfoNotifier extends Notifier<MeshCoreSelfInfoState> {
  // D24.A: dedupe key + cancel guard.
  //
  // `_loadedForNodeId` records the `nodeId` we last fetched for, so a
  // spurious rebuild (e.g. another transition on
  // `meshCoreConnectionStateProvider` while still connected) does
  // not re-issue `getSelfInfo()`. Cleared on disconnect so the
  // next reconnect re-loads fresh state.
  String? _loadedForNodeId;

  // Flipped by `ref.onDispose` so async work bails instead of writing
  // to `state` after the notifier is gone (mirrors the D22
  // conversations-notifier pattern).
  bool _disposed = false;

  @override
  MeshCoreSelfInfoState build() {
    // Riverpod 3.x reuses the `Notifier` instance across rebuilds
    // (e.g. after `invalidate`), so a sticky `_disposed = true` from
    // a previous `ref.onDispose` would prevent the deferred load
    // from ever running again. Reset on every build entry so the
    // flag tracks the CURRENT lifecycle.
    _disposed = false;

    // D24.A: react to MeshCore identify completion via the
    // protocol-agnostic device-info signal. Pre-D24 we watched
    // `meshCoreAdapterProvider`, but the adapter reference does not
    // change identity when `adapter.deviceInfo` flips from null →
    // populated, so Riverpod skipped the rebuild and the user had to
    // tap Refresh to hydrate Battery / TX Power / SF/CR.
    //
    // `meshDeviceInfoProvider` (D24.A-reactive) emits a non-null
    // value only after identify succeeds, and re-emits null on
    // disconnect, giving us both the "load now" and "clear stale
    // state" edges for free.
    final deviceInfo = ref.watch(meshDeviceInfoProvider);

    if (deviceInfo == null) {
      // Disconnected or not yet identified — clear cache and reset
      // dedupe key so the next identify re-fetches.
      _loadedForNodeId = null;
      // Defer the state-reset off-build so `state` getter is not
      // accessed during the still-uninitialized initial build
      // (Riverpod 3 throws `Tried to read the state of an
      // uninitialized provider` otherwise). Re-checking inside the
      // microtask is safe because `state` is initialized by then.
      Future<void>(() {
        if (_disposed) return;
        if (state.selfInfo == null && state.error == null && !state.isLoading) {
          return;
        }
        state = const MeshCoreSelfInfoState.initial();
      });
    } else if (deviceInfo.protocolType == MeshProtocolType.meshcore &&
        deviceInfo.nodeId != _loadedForNodeId) {
      // First identify for this device this session, OR a different
      // device than we last loaded for. Defer the fetch off-build so
      // `state = ...loading()` runs after build returns and the
      // notifier's initial state has been committed.
      Future<void>(_loadSelfInfo);
    }

    ref.onDispose(() {
      _disposed = true;
    });

    return const MeshCoreSelfInfoState.initial();
  }

  Future<void> _loadSelfInfo() async {
    if (_disposed) return;
    state = const MeshCoreSelfInfoState.loading();
    try {
      final session = ref.read(meshCoreSessionProvider);
      if (session == null) {
        if (_disposed) return;
        state = MeshCoreSelfInfoState.failed('No session available');
        return;
      }

      final selfInfo = await session.getSelfInfo();
      if (_disposed) return;
      if (selfInfo != null) {
        state = MeshCoreSelfInfoState.loaded(selfInfo);
        // Cache the nodeId we loaded for so spurious rebuilds don't
        // re-fetch. Read the current device info (may have changed
        // during the await — defensive).
        final info = ref.read(meshDeviceInfoProvider);
        _loadedForNodeId = info?.nodeId;
      } else {
        state = MeshCoreSelfInfoState.failed('Failed to get self info');
      }
    } catch (e) {
      if (_disposed) return;
      state = MeshCoreSelfInfoState.failed(e.toString());
    }
  }

  /// Manual refresh path — bypasses the dedupe key so the user-tap
  /// always hits the wire.
  Future<void> refresh() async {
    _loadedForNodeId = null;
    await _loadSelfInfo();
  }
}

final meshCoreSelfInfoProvider =
    NotifierProvider<MeshCoreSelfInfoNotifier, MeshCoreSelfInfoState>(
      MeshCoreSelfInfoNotifier.new,
    );

// ---------------------------------------------------------------------------
// MeshCore Contacts Provider
// ---------------------------------------------------------------------------

/// State for MeshCore contacts list.
class MeshCoreContactsState {
  final List<MeshCoreContact> contacts;
  final bool isLoading;
  final String? error;
  final DateTime? lastRefresh;

  const MeshCoreContactsState({
    this.contacts = const [],
    this.isLoading = false,
    this.error,
    this.lastRefresh,
  });

  const MeshCoreContactsState.initial()
    : contacts = const [],
      isLoading = false,
      error = null,
      lastRefresh = null;
  const MeshCoreContactsState.loading()
    : contacts = const [],
      isLoading = true,
      error = null,
      lastRefresh = null;

  MeshCoreContactsState copyWith({
    List<MeshCoreContact>? contacts,
    bool? isLoading,
    String? error,
    DateTime? lastRefresh,
  }) {
    return MeshCoreContactsState(
      contacts: contacts ?? this.contacts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastRefresh: lastRefresh ?? this.lastRefresh,
    );
  }
}

class MeshCoreContactsNotifier extends Notifier<MeshCoreContactsState> {
  @override
  MeshCoreContactsState build() {
    // Auto-fetch contacts when connected to MeshCore
    final linkStatus = ref.watch(linkStatusProvider);
    if (linkStatus.isMeshCore && linkStatus.isConnected) {
      // Defer loading to avoid build-phase side effects
      Future.microtask(() => _loadContacts());
    }
    return const MeshCoreContactsState.initial();
  }

  Future<void> _loadContacts() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final session = ref.read(meshCoreSessionProvider);
      if (session == null) {
        state = state.copyWith(isLoading: false, error: 'No MeshCore session');
        return;
      }

      final contactInfos = await session.getContacts();

      // Load unread counts from storage
      final unreadCounts = <String, int>{};
      try {
        final contactStore = await SharedPreferences.getInstance();
        for (final info in contactInfos) {
          final keyHex = info.publicKey
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join();
          final unread = contactStore.getInt('meshcore_unread_$keyHex') ?? 0;
          unreadCounts[keyHex] = unread;
        }
      } catch (e) {
        // Ignore storage errors, use 0 for all
      }

      // Convert MeshCoreContactInfo to MeshCoreContact with unread counts
      final contacts = contactInfos.map((info) {
        final keyHex = info.publicKey
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        return MeshCoreContact(
          publicKey: info.publicKey,
          name: info.name,
          type: info.advType,
          pathLength: info.pathLength,
          path: info.pathBytes,
          latitude: info.latitudeDegrees,
          longitude: info.longitudeDegrees,
          lastSeen: DateTime.now(),
          unreadCount: unreadCounts[keyHex] ?? 0,
        );
      }).toList();

      // Sort by name
      contacts.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      state = MeshCoreContactsState(
        contacts: contacts,
        isLoading: false,
        lastRefresh: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await _loadContacts();
  }

  /// Update unread count for a contact.
  void updateUnreadCount(String publicKeyHex, int count) {
    final updated = state.contacts.map((c) {
      if (c.publicKeyHex == publicKeyHex) {
        return c.copyWith(unreadCount: count);
      }
      return c;
    }).toList();
    state = state.copyWith(contacts: updated);
  }

  /// D24.B: safe in-place merge of a freshly observed advert name
  /// into the local contacts state. Called from
  /// `MeshCoreConversationsNotifier._handleAdvertPush` after parsing
  /// a `PUSH_CODE_NEW_ADVERT` (0x8A) payload.
  ///
  /// Returns one of: `'ok'` (local entry updated), `'no_match'`
  /// (caller should refresh contacts to pick up the new entry),
  /// `'preserved'` (local has a non-empty name; advert name is
  /// ignored to honour the `do not overwrite a non-empty name`
  /// rule), or `'empty_advert'` (advert carried no name; nothing
  /// to merge).
  ///
  /// Hard rules (per D24.B spec):
  ///   - never overwrite a non-empty contact name with an empty
  ///     advert name
  ///   - never create a placeholder contact from an advert (callers
  ///     must trigger a contacts refresh on `'no_match'` instead)
  ///   - match by full public key only — sender prefix or partial
  ///     identity must NOT take this path
  String mergeAdvertName(String publicKeyHex, String advertName) {
    if (advertName.isEmpty) return 'empty_advert';
    if (publicKeyHex.length != 64) return 'no_match';
    final keyLower = publicKeyHex.toLowerCase();

    final updated = <MeshCoreContact>[];
    var matched = false;
    var changed = false;
    for (final c in state.contacts) {
      if (c.publicKeyHex.toLowerCase() == keyLower) {
        matched = true;
        if (c.name.isEmpty) {
          updated.add(c.copyWith(name: advertName));
          changed = true;
        } else {
          updated.add(c);
        }
      } else {
        updated.add(c);
      }
    }
    if (!matched) return 'no_match';
    if (!changed) return 'preserved';
    state = state.copyWith(contacts: updated);
    return 'ok';
  }

  /// Clear unread count for a contact.
  void clearUnread(String publicKeyHex) {
    updateUnreadCount(publicKeyHex, 0);
  }

  /// D28: stamp the latest SNR (firmware quarter encoding) on the contact
  /// whose pubkey starts with [senderPrefixHex] (a 6-byte / 12-char prefix
  /// from the V3 inbound message frame). Returns the matched contact's
  /// full pubkey hex if updated, or null if no contact matched. Session
  /// only — no persistence to the contact store.
  String? recordSnrFromPrefix(String senderPrefixHex, int snrQuarter) {
    if (senderPrefixHex.isEmpty) return null;
    final prefix = senderPrefixHex.toLowerCase();
    final updated = <MeshCoreContact>[];
    String? matchedKey;
    for (final c in state.contacts) {
      if (matchedKey == null &&
          c.publicKeyHex.toLowerCase().startsWith(prefix)) {
        matchedKey = c.publicKeyHex;
        updated.add(c.copyWith(snrQuarter: snrQuarter));
      } else {
        updated.add(c);
      }
    }
    if (matchedKey == null) return null;
    state = state.copyWith(contacts: updated);
    return matchedKey;
  }

  /// Local-only add. Used by the post-wire refresh path and tests.
  /// Production callers should use the async [addContact] which sends
  /// `CMD_ADD_UPDATE_CONTACT` to firmware first.
  @visibleForTesting
  void addContactLocal(MeshCoreContact contact) {
    final updated = [...state.contacts];
    final existingIndex = updated.indexWhere(
      (c) => c.publicKeyHex == contact.publicKeyHex,
    );
    if (existingIndex >= 0) {
      updated[existingIndex] = contact;
    } else {
      updated.add(contact);
    }
    updated.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    state = state.copyWith(contacts: updated);
  }

  /// Local-only remove. Production callers should use the async
  /// [removeContact] which sends `CMD_REMOVE_CONTACT` to firmware first.
  @visibleForTesting
  void removeContactLocal(String publicKeyHex) {
    final updated = state.contacts
        .where((c) => c.publicKeyHex != publicKeyHex)
        .toList();
    state = state.copyWith(contacts: updated);
  }

  /// D29 Part A: add or update [contact] on the connected firmware
  /// (`CMD_ADD_UPDATE_CONTACT` 0x09), then refresh the contact list
  /// from the radio so the local cache matches the firmware state.
  ///
  /// Returns `true` only when the firmware ACKed with `RESP_CODE_OK`
  /// AND the refresh completed. On failure (no session, wire error,
  /// timeout) returns `false` and leaves local state untouched — the
  /// caller is responsible for surfacing the error to the user.
  ///
  /// Pre-D29 this method only mutated local state, which silently
  /// diverged from the firmware contact table on every refresh.
  Future<bool> addContact(MeshCoreContact contact) async {
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      AppLogging.meshcore(
        'event=contact.add_update.skipped reason=no_session',
        error: true,
      );
      return false;
    }
    final ok = await session.addUpdateContact(
      pubKey: contact.publicKey,
      advType: contact.type,
      name: contact.name,
      flags: 0,
      pathLength: contact.pathLength,
      pathBytes: contact.path,
      latitude: contact.latitude,
      longitude: contact.longitude,
    );
    if (!ok) return false;
    await refresh();
    return true;
  }

  /// D29 Part B: remove the contact whose [publicKeyHex] matches
  /// (`CMD_REMOVE_CONTACT` 0x0F), then refresh from the radio.
  ///
  /// Returns `true` on `RESP_CODE_OK` + successful refresh. Pre-D29
  /// this mutated only the local cache.
  Future<bool> removeContact(String publicKeyHex) async {
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      AppLogging.meshcore(
        'event=contact.remove.skipped reason=no_session',
        error: true,
      );
      return false;
    }
    final contact = state.contacts.firstWhere(
      (c) => c.publicKeyHex == publicKeyHex,
      orElse: () => throw ArgumentError('contact not found: $publicKeyHex'),
    );
    final ok = await session.removeContact(contact.publicKey);
    if (!ok) return false;
    await refresh();
    return true;
  }

  /// D34c-A: persist a successful trace's hop bytes back to the
  /// contact's stored path via `CMD_ADD_UPDATE_CONTACT` (0x09).
  ///
  /// All other contact metadata (`type`, `name`, `latitude`,
  /// `longitude`, `flags`) is preserved verbatim — only
  /// `out_path_len` and `out_path` are mutated on the firmware side.
  /// Local state is NOT mutated until after the firmware ACK; on a
  /// non-OK ACK or wire failure the call returns `false` and leaves
  /// the in-memory contact list untouched. Caller surfaces the
  /// error.
  ///
  /// `hopBytes` is the byte sequence the firmware expects to walk
  /// when sending to this contact — typically extracted from a
  /// `MeshCoreTraceResult.hops.map((h) => h.pathByte)` after a
  /// successful Trace Path. Length must be in `[0, 64]`. An empty
  /// `hopBytes` resolves to `pathLength = 0` (direct route); 64+
  /// bytes are clamped at the session-helper layer.
  ///
  /// Logging surface (privacy-redacted):
  ///   - `event=contact.set_path_from_trace.attempted pubkey=<8B fingerprint> path_len=N`
  ///   - `event=contact.set_path_from_trace.<succeeded|failed> ...`
  /// Path bytes themselves are NEVER logged.
  Future<bool> setContactPathFromTrace({
    required String publicKeyHex,
    required Uint8List hopBytes,
  }) async {
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      AppLogging.meshcore(
        'event=contact.set_path_from_trace.skipped reason=no_session',
        error: true,
      );
      return false;
    }
    final contact = state.contacts.firstWhere(
      (c) => c.publicKeyHex == publicKeyHex,
      orElse: () => throw ArgumentError('contact not found: $publicKeyHex'),
    );
    AppLogging.meshcore(
      'event=contact.set_path_from_trace.attempted '
      'pubkey=${AppLogging.publicKeyFingerprint(contact.publicKey)} '
      'path_len=${hopBytes.length}',
    );
    final ok = await session.addUpdateContact(
      pubKey: contact.publicKey,
      advType: contact.type,
      name: contact.name,
      flags: 0,
      pathLength: hopBytes.length,
      pathBytes: hopBytes,
      latitude: contact.latitude,
      longitude: contact.longitude,
    );
    AppLogging.meshcore(
      'event=contact.set_path_from_trace.${ok ? 'succeeded' : 'failed'} '
      'pubkey=${AppLogging.publicKeyFingerprint(contact.publicKey)} '
      'path_len=${hopBytes.length}',
      error: !ok,
    );
    if (!ok) return false;
    await refresh();
    // D34c-B-A: surface the override flag so the routing card
    // renders "N hops (forced)" after a saved trace. Empty trace
    // (direct route) sets pathOverride = 0 and matches the Force
    // Direct semantics.
    _applyLocalPathOverride(
      publicKeyHex: publicKeyHex,
      pathOverride: hopBytes.length,
      pathOverrideBytes: Uint8List.fromList(hopBytes),
    );
    return true;
  }

  /// D29 Part C: reset the firmware-side learned route for the
  /// contact whose [publicKeyHex] matches (`CMD_RESET_PATH` 0x0D),
  /// then refresh so the local cache picks up the new path state.
  ///
  /// D34c-B-A: also clears any in-memory `pathOverride` /
  /// `pathOverrideBytes` so the routing card returns to its
  /// unforced label after the user resets.
  Future<bool> resetPath(String publicKeyHex) async {
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      AppLogging.meshcore(
        'event=contact.reset_path.skipped reason=no_session',
        error: true,
      );
      return false;
    }
    final contact = state.contacts.firstWhere(
      (c) => c.publicKeyHex == publicKeyHex,
      orElse: () => throw ArgumentError('contact not found: $publicKeyHex'),
    );
    final ok = await session.resetPath(contact.publicKey);
    if (!ok) return false;
    await refresh();
    _clearLocalPathOverride(publicKeyHex);
    return true;
  }

  /// D34c-B-A: write a user-chosen path override to the firmware
  /// contact entry AND mirror the choice into the local
  /// `pathOverride` / `pathOverrideBytes` fields so the routing card
  /// surfaces the "(forced)" suffix until reset.
  ///
  /// Modes shipping in this slice:
  ///   - [PathOverrideMode.forceFlood]   → wire `pathLength = -1`
  ///                                       (encoded as `0xFF`),
  ///                                       empty path bytes.
  ///   - [PathOverrideMode.forceDirect]  → wire `pathLength = 0`,
  ///                                       empty path bytes.
  ///
  /// Manual N-hop entry is intentionally NOT exposed here. Saved
  /// traces flow through [setContactPathFromTrace], which carries
  /// the trace's hop bytes verbatim.
  ///
  /// Atomic: on a non-OK firmware ACK or wire failure the call
  /// returns `false`, leaves the in-memory contact list untouched,
  /// and emits `event=contact.set_path_override.failed`. On success,
  /// `refresh()` reloads from firmware and the local override flag
  /// is reapplied so the "(forced)" pill survives the round-trip.
  ///
  /// Logging surface (privacy-redacted):
  ///   - `event=contact.set_path_override.attempted mode=<name> pubkey=<8B fingerprint>`
  ///   - `event=contact.set_path_override.<succeeded|failed> ...`
  /// Path bytes themselves are NEVER logged.
  Future<bool> setPathOverride({
    required String publicKeyHex,
    required PathOverrideMode mode,
  }) async {
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      AppLogging.meshcore(
        'event=contact.set_path_override.skipped reason=no_session '
        'mode=${mode.name}',
        error: true,
      );
      return false;
    }
    final contact = state.contacts.firstWhere(
      (c) => c.publicKeyHex == publicKeyHex,
      orElse: () => throw ArgumentError('contact not found: $publicKeyHex'),
    );

    final wirePathLength = switch (mode) {
      PathOverrideMode.forceFlood => -1,
      PathOverrideMode.forceDirect => 0,
    };

    AppLogging.meshcore(
      'event=contact.set_path_override.attempted '
      'mode=${mode.name} '
      'pubkey=${AppLogging.publicKeyFingerprint(contact.publicKey)}',
    );

    final ok = await session.addUpdateContact(
      pubKey: contact.publicKey,
      advType: contact.type,
      name: contact.name,
      flags: 0,
      pathLength: wirePathLength,
      pathBytes: Uint8List(0),
      latitude: contact.latitude,
      longitude: contact.longitude,
    );

    AppLogging.meshcore(
      'event=contact.set_path_override.${ok ? "succeeded" : "failed"} '
      'mode=${mode.name} '
      'pubkey=${AppLogging.publicKeyFingerprint(contact.publicKey)}',
      error: !ok,
    );

    if (!ok) return false;
    await refresh();
    _applyLocalPathOverride(
      publicKeyHex: publicKeyHex,
      pathOverride: wirePathLength,
      pathOverrideBytes: Uint8List(0),
    );
    return true;
  }

  /// Mutates the live contacts list to set the `pathOverride` flag on
  /// the matching contact. Used after [setPathOverride] and
  /// [setContactPathFromTrace] succeed. Idempotent on miss.
  void _applyLocalPathOverride({
    required String publicKeyHex,
    required int pathOverride,
    required Uint8List pathOverrideBytes,
  }) {
    final hex = publicKeyHex.toLowerCase();
    var changed = false;
    final updated = state.contacts.map((c) {
      if (c.publicKeyHex.toLowerCase() != hex) return c;
      changed = true;
      return c.copyWith(
        pathOverride: pathOverride,
        pathOverrideBytes: pathOverrideBytes,
      );
    }).toList();
    if (!changed) return;
    state = state.copyWith(contacts: updated);
  }

  /// Clears the `pathOverride` / `pathOverrideBytes` flag on the
  /// matching contact. Called from [resetPath] post-ACK so the
  /// routing card returns to its unforced label. Idempotent on miss.
  void _clearLocalPathOverride(String publicKeyHex) {
    final hex = publicKeyHex.toLowerCase();
    var changed = false;
    final updated = state.contacts.map((c) {
      if (c.publicKeyHex.toLowerCase() != hex) return c;
      if (c.pathOverride == null && c.pathOverrideBytes == null) return c;
      changed = true;
      return c.copyWith(clearPathOverride: true);
    }).toList();
    if (!changed) return;
    state = state.copyWith(contacts: updated);
  }
}

/// D34c-B-A: user-chosen path override modes for
/// [MeshCoreContactsNotifier.setPathOverride]. Manual N-hop entry is
/// intentionally absent — the only way to write an N-hop path today
/// is via the trace flow ([setContactPathFromTrace]).
enum PathOverrideMode { forceFlood, forceDirect }

final meshCoreContactsProvider =
    NotifierProvider<MeshCoreContactsNotifier, MeshCoreContactsState>(
      MeshCoreContactsNotifier.new,
    );

// ---------------------------------------------------------------------------
// MeshCore Channels Provider
// ---------------------------------------------------------------------------

/// State for MeshCore channels list.
class MeshCoreChannelsState {
  final List<MeshCoreChannel> channels;
  final bool isLoading;
  final String? error;
  final DateTime? lastRefresh;

  const MeshCoreChannelsState({
    this.channels = const [],
    this.isLoading = false,
    this.error,
    this.lastRefresh,
  });

  const MeshCoreChannelsState.initial()
    : channels = const [],
      isLoading = false,
      error = null,
      lastRefresh = null;
  const MeshCoreChannelsState.loading()
    : channels = const [],
      isLoading = true,
      error = null,
      lastRefresh = null;

  MeshCoreChannelsState copyWith({
    List<MeshCoreChannel>? channels,
    bool? isLoading,
    String? error,
    DateTime? lastRefresh,
  }) {
    return MeshCoreChannelsState(
      channels: channels ?? this.channels,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastRefresh: lastRefresh ?? this.lastRefresh,
    );
  }
}

class MeshCoreChannelsNotifier extends Notifier<MeshCoreChannelsState> {
  @override
  MeshCoreChannelsState build() {
    // Auto-fetch channels when connected to MeshCore
    final linkStatus = ref.watch(linkStatusProvider);
    if (linkStatus.isMeshCore && linkStatus.isConnected) {
      // Defer loading to avoid build-phase side effects
      Future.microtask(() => _loadChannels());
    }
    return const MeshCoreChannelsState.initial();
  }

  Future<void> _loadChannels() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final session = ref.read(meshCoreSessionProvider);
      if (session == null) {
        state = state.copyWith(isLoading: false, error: 'No MeshCore session');
        return;
      }

      final channelInfos = await session.getChannels();

      // Convert MeshCoreChannelInfo to MeshCoreChannel
      final channels = channelInfos.map((info) {
        return MeshCoreChannel(
          index: info.index,
          name: info.name,
          psk: info.psk,
        );
      }).toList();

      // Sort by index
      channels.sort((a, b) => a.index.compareTo(b.index));

      state = MeshCoreChannelsState(
        channels: channels,
        isLoading: false,
        lastRefresh: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await _loadChannels();
  }

  /// Add or update a channel on the device.
  ///
  /// Convenience wrapper that takes the existing [MeshCoreChannel]
  /// model. Equivalent to [addChannel]/[editChannel] — `CMD_SET_CHANNEL`
  /// is overwrite-by-slot, so the firmware doesn't distinguish "add"
  /// from "edit". The intent-based aliases below exist so caller code
  /// reads naturally at the UI layer.
  ///
  /// On firmware ACK this re-fetches the channel list so local state
  /// reflects what the radio actually persisted, not what the client
  /// asked for. Failure leaves state intact.
  Future<bool> setChannel(MeshCoreChannel channel) {
    return _writeChannel(
      index: channel.index,
      name: channel.name,
      psk: channel.psk,
    );
  }

  /// Add a new channel slot. Same wire op as [editChannel] (firmware's
  /// `CMD_SET_CHANNEL` is overwrite-by-slot); the distinction is
  /// caller intent and UI affordance.
  Future<bool> addChannel({
    required int index,
    required String name,
    required Uint8List psk,
  }) {
    return _writeChannel(index: index, name: name, psk: psk);
  }

  /// Edit an existing channel slot's name and/or PSK. Same wire op as
  /// [addChannel].
  Future<bool> editChannel({
    required int index,
    required String name,
    required Uint8List psk,
  }) {
    return _writeChannel(index: index, name: name, psk: psk);
  }

  /// Remove a channel slot. There is no dedicated firmware delete
  /// opcode at the pinned SHA — this overwrites the slot with empty
  /// name + zero PSK. After firmware ACK + refresh, the slot reads
  /// back as `MeshCoreChannelInfo.isEmpty` and is filtered out of
  /// `getChannels`. See `MeshCoreSession.removeChannel` for the wire
  /// convention.
  ///
  /// Returns `true` on firmware ACK + successful refresh; `false` on
  /// invalid slot, no session, firmware error, or timeout. Local state
  /// is only mutated via the post-ACK refresh.
  Future<bool> removeChannel({required int index}) async {
    if (index < 0 || index > 255) return false;

    final session = ref.read(meshCoreSessionProvider);
    if (session == null) return false;

    try {
      final success = await session.removeChannel(index: index);
      if (success) {
        await _loadChannels();
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  /// Single internal write path so add/edit/setChannel converge on one
  /// validate-then-wire-then-refresh pipeline. Any input that the
  /// session wrapper would have thrown an `ArgumentError` for is
  /// pre-rejected here so the UI can surface a validation error
  /// without burning a wire round-trip.
  Future<bool> _writeChannel({
    required int index,
    required String name,
    required Uint8List psk,
  }) async {
    if (index < 0 || index > 255) return false;
    if (name.codeUnits.length > 32) return false;
    if (psk.length != 16) return false;

    final session = ref.read(meshCoreSessionProvider);
    if (session == null) return false;

    try {
      final success = await session.setChannel(
        index: index,
        name: name,
        psk: psk,
      );
      if (success) {
        // Re-fetch so local state reflects firmware's authoritative
        // view (catches partial writes, slot-not-found rewrites the
        // empty channel back, etc). Failure path leaves state intact.
        await _loadChannels();
      }
      return success;
    } catch (_) {
      return false;
    }
  }
}

final meshCoreChannelsProvider =
    NotifierProvider<MeshCoreChannelsNotifier, MeshCoreChannelsState>(
      MeshCoreChannelsNotifier.new,
    );

/// Provider for the MeshCore debug capture (null if not MeshCore or release build).
///
/// Only available in debug builds for dev-only protocol inspection.
final meshCoreCaptureProvider = Provider<MeshCoreFrameCapture?>((ref) {
  if (!kDebugMode) return null;
  final coordinator = ref.watch(connectionCoordinatorProvider);
  return coordinator.meshCoreCapture;
});

// ---------------------------------------------------------------------------
// MeshCore Battery Refresh (Debug-only)
// ---------------------------------------------------------------------------

/// State for MeshCore battery refresh operation.
class MeshCoreBatteryState {
  /// The current status.
  final MeshCoreBatteryStatus status;

  /// Battery percentage (0-100), or null if unknown.
  final int? percentage;

  /// Battery voltage in millivolts, or null if unknown.
  final int? voltageMillivolts;

  /// Error message on failure.
  final String? errorMessage;

  const MeshCoreBatteryState.idle()
    : status = MeshCoreBatteryStatus.idle,
      percentage = null,
      voltageMillivolts = null,
      errorMessage = null;

  const MeshCoreBatteryState.inProgress()
    : status = MeshCoreBatteryStatus.inProgress,
      percentage = null,
      voltageMillivolts = null,
      errorMessage = null;

  const MeshCoreBatteryState.success({
    required this.percentage,
    required this.voltageMillivolts,
  }) : status = MeshCoreBatteryStatus.success,
       errorMessage = null;

  const MeshCoreBatteryState.failure(this.errorMessage)
    : status = MeshCoreBatteryStatus.failure,
      percentage = null,
      voltageMillivolts = null;

  bool get isIdle => status == MeshCoreBatteryStatus.idle;
  bool get isInProgress => status == MeshCoreBatteryStatus.inProgress;
  bool get isSuccess => status == MeshCoreBatteryStatus.success;
  bool get isFailure => status == MeshCoreBatteryStatus.failure;
}

enum MeshCoreBatteryStatus { idle, inProgress, success, failure }

/// Notifier for MeshCore battery refresh.
///
/// Provides reactive hydration of battery info on identify completion
/// plus manual refresh for the user-tap path.
class MeshCoreBatteryNotifier extends Notifier<MeshCoreBatteryState> {
  @override
  MeshCoreBatteryState build() {
    // D24.A symmetry: watch the protocol-agnostic device-info signal
    // (which `meshDeviceInfoProvider` rebuilds via the MeshCore
    // connection-state stream) so the battery card hydrates
    // automatically when identify completes. Pre-D24 this notifier
    // used `ref.read(meshCoreAdapterProvider)` and was therefore
    // captured at app-launch null state — Tools opened during connect
    // showed `--` until the user tapped Refresh, identical to the
    // self-info bug D24.A solved for TX Power / SF/CR. Watching the
    // adapter directly does not help: the adapter singleton's
    // reference does not change when `adapter.deviceInfo` flips, so
    // `ref.watch(meshCoreAdapterProvider)` would still freeze.
    final deviceInfo = ref.watch(meshDeviceInfoProvider);
    final adapter = ref.read(meshCoreAdapterProvider);
    final adapterDeviceInfo = adapter?.deviceInfo;
    if (deviceInfo != null &&
        deviceInfo.protocolType == MeshProtocolType.meshcore &&
        adapterDeviceInfo != null &&
        (adapterDeviceInfo.batteryPercentage != null ||
            adapterDeviceInfo.batteryVoltageMillivolts != null)) {
      return MeshCoreBatteryState.success(
        percentage: adapterDeviceInfo.batteryPercentage,
        voltageMillivolts: adapterDeviceInfo.batteryVoltageMillivolts,
      );
    }
    return const MeshCoreBatteryState.idle();
  }

  /// Refresh battery info from the device.
  Future<void> refresh() async {
    state = const MeshCoreBatteryState.inProgress();

    try {
      final adapter = ref.read(meshCoreAdapterProvider);
      if (adapter == null) {
        state = const MeshCoreBatteryState.failure('Not connected to MeshCore');
        return;
      }

      final percentage = await adapter.refreshBattery();
      final deviceInfo = adapter.deviceInfo;

      if (percentage != null || deviceInfo?.batteryVoltageMillivolts != null) {
        state = MeshCoreBatteryState.success(
          percentage: percentage,
          voltageMillivolts: deviceInfo?.batteryVoltageMillivolts,
        );
      } else {
        state = const MeshCoreBatteryState.failure('Battery info unavailable');
      }
    } catch (e) {
      state = MeshCoreBatteryState.failure(e.toString());
    }
  }

  void reset() {
    state = const MeshCoreBatteryState.idle();
  }
}

final meshCoreBatteryProvider =
    NotifierProvider<MeshCoreBatteryNotifier, MeshCoreBatteryState>(
      MeshCoreBatteryNotifier.new,
    );

/// Provider for protocol detection on a scanned device.
///
/// This is a family provider that takes scan parameters and returns
/// the detection result for a specific device.
final protocolDetectionProvider =
    Provider.family<ProtocolDetectionResult, ProtocolDetectionParams>((
      ref,
      params,
    ) {
      return MeshProtocolDetector.detect(
        device: params.device,
        advertisedServiceUuids: params.advertisedServiceUuids,
        manufacturerData: params.manufacturerData,
      );
    });

/// Parameters for protocol detection.
///
/// Contains information from a BLE scan needed to detect the device protocol.
class ProtocolDetectionParams {
  /// Device identifier and name.
  final DeviceInfo device;

  /// Service UUIDs advertised by the device.
  final List<String> advertisedServiceUuids;

  /// Manufacturer-specific data from the advertisement.
  final Map<int, List<int>>? manufacturerData;

  const ProtocolDetectionParams({
    required this.device,
    this.advertisedServiceUuids = const [],
    this.manufacturerData,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProtocolDetectionParams &&
          runtimeType == other.runtimeType &&
          device.id == other.device.id;

  @override
  int get hashCode => device.id.hashCode;
}

/// Notifier for ping test state.
///
/// Tracks the state of ping tests for the debug action in the device sheet.
class PingTestNotifier extends Notifier<PingTestState> {
  @override
  PingTestState build() => const PingTestState.idle();

  Future<void> ping() async {
    state = const PingTestState.inProgress();

    try {
      final coordinator = ref.read(connectionCoordinatorProvider);
      final latency = await coordinator.ping();

      if (latency != null) {
        state = PingTestState.success(latency);
      } else {
        // For Meshtastic without explicit ping, check if connected
        final connectionState = ref.read(deviceConnectionProvider);
        if (connectionState.isConnected) {
          // Meshtastic doesn't have explicit ping, but connection proves comms
          state = const PingTestState.success(Duration(milliseconds: 50));
        } else {
          state = const PingTestState.failure('Not connected');
        }
      }
    } catch (e) {
      state = PingTestState.failure(e.toString());
    }
  }

  void reset() {
    state = const PingTestState.idle();
  }
}

/// State of a ping test.
class PingTestState {
  /// The current status.
  final PingTestStatus status;

  /// Latency on success.
  final Duration? latency;

  /// Error message on failure.
  final String? errorMessage;

  const PingTestState.idle()
    : status = PingTestStatus.idle,
      latency = null,
      errorMessage = null;

  const PingTestState.inProgress()
    : status = PingTestStatus.inProgress,
      latency = null,
      errorMessage = null;

  const PingTestState.success(this.latency)
    : status = PingTestStatus.success,
      errorMessage = null;

  const PingTestState.failure(this.errorMessage)
    : status = PingTestStatus.failure,
      latency = null;

  /// Whether the test is idle.
  bool get isIdle => status == PingTestStatus.idle;

  /// Whether the test is in progress.
  bool get isInProgress => status == PingTestStatus.inProgress;

  /// Whether the test succeeded.
  bool get isSuccess => status == PingTestStatus.success;

  /// Whether the test failed.
  bool get isFailure => status == PingTestStatus.failure;
}

enum PingTestStatus { idle, inProgress, success, failure }

final pingTestProvider = NotifierProvider<PingTestNotifier, PingTestState>(
  PingTestNotifier.new,
);

/// State of a GATT dump operation.
class GattDumpState {
  /// The current status.
  final GattDumpStatus status;

  /// Discovered services on success.
  final List<GattServiceInfo>? services;

  /// Error message on failure.
  final String? errorMessage;

  const GattDumpState.idle()
    : status = GattDumpStatus.idle,
      services = null,
      errorMessage = null;

  const GattDumpState.inProgress()
    : status = GattDumpStatus.inProgress,
      services = null,
      errorMessage = null;

  const GattDumpState.success(this.services)
    : status = GattDumpStatus.success,
      errorMessage = null;

  const GattDumpState.failure(this.errorMessage)
    : status = GattDumpStatus.failure,
      services = null;

  bool get isIdle => status == GattDumpStatus.idle;
  bool get isInProgress => status == GattDumpStatus.inProgress;
  bool get isSuccess => status == GattDumpStatus.success;
  bool get isFailure => status == GattDumpStatus.failure;
}

enum GattDumpStatus { idle, inProgress, success, failure }

/// Info about a discovered GATT service.
class GattServiceInfo {
  final String uuid;
  final List<GattCharacteristicInfo> characteristics;

  const GattServiceInfo({required this.uuid, required this.characteristics});
}

/// Info about a discovered GATT characteristic.
class GattCharacteristicInfo {
  final String uuid;
  final List<String> properties;

  const GattCharacteristicInfo({required this.uuid, required this.properties});
}

final gattDumpProvider = NotifierProvider<GattDumpNotifier, GattDumpState>(
  GattDumpNotifier.new,
);

/// Notifier for GATT dump state.
///
/// Dumps all discovered GATT services and characteristics for debugging.
class GattDumpNotifier extends Notifier<GattDumpState> {
  @override
  GattDumpState build() => const GattDumpState.idle();

  Future<void> dump() async {
    state = const GattDumpState.inProgress();

    try {
      final coordinator = ref.read(connectionCoordinatorProvider);
      final services = await coordinator.discoverGattServices();

      if (services != null) {
        state = GattDumpState.success(services);
      } else {
        state = const GattDumpState.failure('GATT discovery not available');
      }
    } catch (e) {
      state = GattDumpState.failure(e.toString());
    }
  }

  void reset() {
    state = const GattDumpState.idle();
  }
}

// ---------------------------------------------------------------------------
// MeshCore Capture State (Dev-only)
// ---------------------------------------------------------------------------

/// Snapshot of MeshCore capture state for UI display.
///
/// Contains a copy of captured frames at a point in time.
class MeshCoreCaptureSnapshot {
  /// List of captured frames.
  final List<CapturedFrame> frames;

  /// Total frame count (may differ from frames.length if truncated).
  final int totalCount;

  /// Whether capture is active.
  final bool isActive;

  const MeshCoreCaptureSnapshot({
    required this.frames,
    required this.totalCount,
    required this.isActive,
  });

  /// Empty snapshot.
  const MeshCoreCaptureSnapshot.empty()
    : frames = const [],
      totalCount = 0,
      isActive = false;

  /// Whether there are any frames.
  bool get hasFrames => frames.isNotEmpty;
}

/// Notifier for MeshCore capture snapshot.
///
/// Provides a way for UI to observe capture changes without heavy rebuilds.
/// Call refresh() to poll the latest snapshot from the capture instance.
class MeshCoreCaptureNotifier extends Notifier<MeshCoreCaptureSnapshot> {
  @override
  MeshCoreCaptureSnapshot build() {
    // Initial state: check if we have an active capture
    final capture = ref.read(meshCoreCaptureProvider);
    if (capture == null) {
      return const MeshCoreCaptureSnapshot.empty();
    }
    return _snapshotFromCapture(capture);
  }

  /// Refresh the snapshot from the current capture.
  void refresh() {
    final capture = ref.read(meshCoreCaptureProvider);
    if (capture == null) {
      state = const MeshCoreCaptureSnapshot.empty();
      return;
    }
    state = _snapshotFromCapture(capture);
  }

  /// Clear the capture and refresh state.
  void clear() {
    final capture = ref.read(meshCoreCaptureProvider);
    capture?.clear();
    refresh();
  }

  /// Get the compact hex log for clipboard.
  String getHexLog() {
    final capture = ref.read(meshCoreCaptureProvider);
    return capture?.toCompactHexLog() ?? '(no capture active)';
  }

  MeshCoreCaptureSnapshot _snapshotFromCapture(MeshCoreFrameCapture capture) {
    final frames = capture.snapshot();
    return MeshCoreCaptureSnapshot(
      frames: frames,
      totalCount: frames.length,
      isActive: capture.isActive,
    );
  }
}

final meshCoreCaptureSnapshotProvider =
    NotifierProvider<MeshCoreCaptureNotifier, MeshCoreCaptureSnapshot>(
      MeshCoreCaptureNotifier.new,
    );

// ---------------------------------------------------------------------------
// MeshCore Display Preferences
// ---------------------------------------------------------------------------

/// SharedPreferences key for the battery voltage display preference.
///
/// Public so widget tests can stage initial values without reaching into
/// the notifier. Do not use this from production code; go through the
/// notifier instead.
@visibleForTesting
const String kMeshCoreShowBatteryVoltagePrefKey =
    'meshcore_settings_show_battery_voltage';

/// Global app preference: render the battery row as voltage (true) or as
/// percentage (false). Persists across screen navigation, disconnect /
/// reconnect, and cold restart so the user does not have to retoggle on
/// every visit to the MeshCore settings screen.
///
/// This is intentionally a global preference, not per-radio: it expresses
/// how the user wants battery rendered, not a property of a specific
/// device.
class MeshCoreShowBatteryVoltageNotifier extends Notifier<bool> {
  @override
  bool build() {
    Future.microtask(_loadFromPrefs);
    return false;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(kMeshCoreShowBatteryVoltagePrefKey) ?? false;
    } catch (_) {
      // Default already in state. Silent recovery is fine here; the
      // preference is non-critical and any failure to read implies a
      // failed write later will surface to the user via the toggle.
    }
  }

  /// Persist the preference and update reactive state in lockstep so a
  /// listener never sees a value that wasn't written.
  Future<void> set(bool value) async {
    if (state == value) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kMeshCoreShowBatteryVoltagePrefKey, value);
    state = value;
  }
}

final meshCoreShowBatteryVoltageProvider =
    NotifierProvider<MeshCoreShowBatteryVoltageNotifier, bool>(
      MeshCoreShowBatteryVoltageNotifier.new,
    );

// =============================================================================
// D34b-A1: Discovered / heard MeshCore peers (recent-heard feed).
// =============================================================================

/// One entry in the recent-heard feed. In-memory only — never persisted.
///
/// Populated by `_handleAdvertPush` in [MeshCoreConversationsNotifier]:
///   - `PUSH_CODE_NEW_ADVERT (0x8A)` carries the full 147-byte contact
///     descriptor → entry has `hasFullInfo = true`.
///   - `PUSH_CODE_ADVERT (0x80)` carries only a 32-byte pubkey → if no
///     full entry exists yet we record a minimal stub with empty
///     `name` and `advType = null` so the recency surface still picks
///     up the bump.
///
/// Privacy:
///   - Logs surface only `pubkey=<8B…8T>` redacted fingerprints, never
///     the full pubkey or path bytes.
///   - The buffer is in-memory only and lost on app restart by design.
class HeardAdvert {
  /// Full 32-byte public key.
  final Uint8List publicKey;

  /// Display name from the firmware contact slot. Empty string when the
  /// only push observed so far was a 0x80 (re-heard, pubkey-only).
  final String name;

  /// Advertised contact type (chat / repeater / room / sensor) from the
  /// firmware contact slot. `null` when only 0x80 has been observed.
  final int? advType;

  /// Wall-clock time at which the FIRST advert from this pubkey was
  /// recorded in this session.
  final DateTime firstHeard;

  /// Wall-clock time at which the MOST RECENT advert (any push code)
  /// from this pubkey was observed.
  final DateTime lastHeard;

  /// `true` iff a `PUSH_CODE_NEW_ADVERT (0x8A)` carried the full
  /// contact descriptor at any point. `false` for entries created
  /// purely from `PUSH_CODE_ADVERT (0x80)` re-heard pings — those
  /// carry no name or type and the UI shows a fingerprint placeholder
  /// + "Heard" badge, not an importable card.
  final bool hasFullInfo;

  const HeardAdvert({
    required this.publicKey,
    required this.name,
    required this.advType,
    required this.firstHeard,
    required this.lastHeard,
    required this.hasFullInfo,
  });

  String get publicKeyHex => publicKey
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join()
      .toLowerCase();

  /// Canonical UI fingerprint mirroring the redaction format used by
  /// the log channel and `MeshCoreContact.shortPubKeyHex`.
  String get shortPubKeyHex {
    final hex = publicKeyHex;
    if (hex.length < 16) return hex;
    return '<${hex.substring(0, 8)}…${hex.substring(hex.length - 8)}>';
  }

  /// Human-facing display name with deterministic fingerprint
  /// fallback. Mirrors `MeshCoreContact.displayName` so heard / imported
  /// rows render the same way.
  String get displayName {
    if (name.isNotEmpty) return name;
    if (publicKey.isEmpty) return '';
    if (publicKey.length < 8) return '';
    return shortPubKeyHex;
  }

  HeardAdvert copyWith({
    String? name,
    int? advType,
    DateTime? lastHeard,
    bool? hasFullInfo,
  }) {
    return HeardAdvert(
      publicKey: publicKey,
      name: name ?? this.name,
      advType: advType ?? this.advType,
      firstHeard: firstHeard,
      lastHeard: lastHeard ?? this.lastHeard,
      hasFullInfo: hasFullInfo ?? this.hasFullInfo,
    );
  }
}

/// In-memory recent-heard feed of MeshCore advert pushes.
///
/// Capped at [_maxEntries]. Self-pubkey filtered. Sorted by `lastHeard`
/// descending in [state] so the UI renders most-recent first without
/// extra work. Re-emits a fresh `List.unmodifiable` view on every
/// mutation so Riverpod's identity-based equality triggers downstream
/// rebuilds reliably.
class MeshCoreDiscoveredAdvertsNotifier extends Notifier<List<HeardAdvert>> {
  /// Hard cap. FIFO eviction by `lastHeard` (oldest evicted first when
  /// the cap is exceeded).
  static const int maxEntries = 100;

  final Map<String, HeardAdvert> _byPubkey = {};

  @override
  List<HeardAdvert> build() => const [];

  /// Record (or update) an advert from a successfully-parsed 0x8A
  /// payload. [isNew] is the firmware's "is this a brand-new contact?"
  /// flag; we don't currently expose it in the model, but the parameter
  /// is part of the API contract so future surfaces (e.g. a "new"
  /// pulse) can wire in without touching callers.
  void recordAdvert(MeshCoreContactInfo info, {required bool isNew}) {
    if (_isSelfPubkey(info.publicKey)) return;
    final hex = info.publicKeyHex.toLowerCase();
    final now = DateTime.now();
    final existing = _byPubkey[hex];
    final entry = HeardAdvert(
      publicKey: info.publicKey,
      name: info.name,
      advType: info.advType,
      firstHeard: existing?.firstHeard ?? now,
      lastHeard: now,
      hasFullInfo: true,
    );
    _byPubkey[hex] = entry;
    AppLogging.meshcore(
      'event=discovery.recorded source=0x8A '
      'pubkey=${AppLogging.publicKeyFingerprint(info.publicKey)} '
      'name_len=${info.name.length} adv_type=${info.advType}',
    );
    _evictIfOver();
    _emit();
  }

  /// Bump `lastHeard` for an existing entry, OR (if the pubkey is not
  /// yet in the buffer) record a minimal stub from a 0x80 re-heard
  /// ping. The stub has no name/type and surfaces in the UI as a
  /// fingerprint-only "Heard" row that can't be imported until a full
  /// 0x8A arrives. The latter behaviour matches the spec's "create a
  /// minimal entry if full pubkey is available" branch.
  void bumpLastHeard(Uint8List pubKey) {
    if (_isSelfPubkey(pubKey)) return;
    if (pubKey.length < 8) return;
    final hex = _hex(pubKey).toLowerCase();
    final now = DateTime.now();
    final existing = _byPubkey[hex];
    if (existing == null) {
      _byPubkey[hex] = HeardAdvert(
        publicKey: Uint8List.fromList(pubKey),
        name: '',
        advType: null,
        firstHeard: now,
        lastHeard: now,
        hasFullInfo: false,
      );
      AppLogging.meshcore(
        'event=discovery.recorded source=0x80 '
        'pubkey=${AppLogging.publicKeyFingerprint(pubKey)} '
        'minimal=true',
      );
    } else {
      _byPubkey[hex] = existing.copyWith(lastHeard: now);
    }
    _evictIfOver();
    _emit();
  }

  /// Remove a single entry by its pubkey hex (lowercase, 64 chars).
  /// Idempotent — silent no-op when the entry isn't present.
  void remove(String pubKeyHex) {
    if (_byPubkey.remove(pubKeyHex.toLowerCase()) != null) {
      _emit();
    }
  }

  /// Empty the whole heard list. Used by the Discovery screen's
  /// "Delete all" overflow.
  void clearAll() {
    if (_byPubkey.isEmpty) return;
    _byPubkey.clear();
    _emit();
  }

  bool _isSelfPubkey(Uint8List candidate) {
    final selfInfo = ref.read(meshCoreSelfInfoProvider).selfInfo;
    if (selfInfo == null) return false;
    final self = selfInfo.pubKey;
    if (self.length != candidate.length) return false;
    for (var i = 0; i < candidate.length; i++) {
      if (self[i] != candidate[i]) return false;
    }
    return true;
  }

  void _evictIfOver() {
    if (_byPubkey.length <= maxEntries) return;
    // Evict entries with oldest `lastHeard` until at cap.
    final sorted = _byPubkey.entries.toList()
      ..sort((a, b) => a.value.lastHeard.compareTo(b.value.lastHeard));
    final toRemove = _byPubkey.length - maxEntries;
    for (var i = 0; i < toRemove; i++) {
      _byPubkey.remove(sorted[i].key);
    }
  }

  void _emit() {
    final sorted = _byPubkey.values.toList()
      ..sort((a, b) => b.lastHeard.compareTo(a.lastHeard));
    state = List.unmodifiable(sorted);
  }

  String _hex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Riverpod 3.x notifier provider for the recent-heard feed.
final meshCoreDiscoveredAdvertsProvider =
    NotifierProvider<MeshCoreDiscoveredAdvertsNotifier, List<HeardAdvert>>(
      MeshCoreDiscoveredAdvertsNotifier.new,
    );

// ---------------------------------------------------------------------------
// D34a: chat-traffic measurement (in-memory only).
// ---------------------------------------------------------------------------

/// Riverpod 3.x notifier exposing the live [ChatTrafficSnapshot] from
/// the active MeshCore session's rate limiter.
///
/// Updates at 1 Hz while subscribed. Returns an empty snapshot when no
/// session is connected. State is in-memory only — nothing is
/// persisted, exported, or transmitted.
class MeshCoreChatTrafficNotifier extends Notifier<ChatTrafficSnapshot> {
  Timer? _ticker;

  @override
  ChatTrafficSnapshot build() {
    ref.onDispose(() {
      _ticker?.cancel();
      _ticker = null;
    });

    // Re-build whenever the live session swaps (connect / disconnect).
    final session = ref.watch(meshCoreSessionProvider);
    _ticker?.cancel();
    if (session == null) {
      return ChatTrafficSnapshot.empty(DateTime.now());
    }

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      // Re-read session through ref so a swap mid-tick is honoured.
      final live = ref.read(meshCoreSessionProvider);
      if (live == null) {
        state = ChatTrafficSnapshot.empty(DateTime.now());
        return;
      }
      state = live.sendRateLimiter.snapshot();
    });
    return session.sendRateLimiter.snapshot();
  }

  /// Force-refresh the snapshot from the live limiter. Used by the
  /// chat send path (and tests) so a `recordSend` becomes visible
  /// without waiting for the next 1 Hz tick.
  void refreshNow() {
    final session = ref.read(meshCoreSessionProvider);
    state = session == null
        ? ChatTrafficSnapshot.empty(DateTime.now())
        : session.sendRateLimiter.snapshot();
  }
}

final meshCoreChatTrafficProvider =
    NotifierProvider<MeshCoreChatTrafficNotifier, ChatTrafficSnapshot>(
      MeshCoreChatTrafficNotifier.new,
    );

// ---------------------------------------------------------------------------
// D35-A: Companion radio stats provider (firmware-backed link health).
// ---------------------------------------------------------------------------

/// Immutable wrapper carrying the latest [MeshCoreRadioStats] plus the
/// connection / staleness signals the Tools card renders.
///
/// Three rendering states:
///   - `isConnected == false`  → card shows the disconnected placeholder.
///   - `isConnected && latest == null` → card is connected but no
///     successful fetch has landed yet (typically the first 1 s after
///     mount). Show a quiet "fetching" placeholder, not stale red.
///   - `isConnected && latest != null && isStale` → values render greyed
///     with a stale hint; transport blip in progress.
///   - `isConnected && latest != null && !isStale` → live values.
class MeshCoreRadioStatsSnapshot {
  final MeshCoreRadioStats? latest;
  final bool isStale;
  final bool isConnected;

  const MeshCoreRadioStatsSnapshot({
    required this.latest,
    required this.isStale,
    required this.isConnected,
  });

  /// Snapshot used while no MeshCore session is connected.
  const MeshCoreRadioStatsSnapshot.disconnected()
    : latest = null,
      isStale = false,
      isConnected = false;
}

/// D35-A: staleness threshold. If the most recent successful fetch is
/// older than this, the Tools card greys the values and surfaces the
/// stale hint. 5 s matches the live-smoke plan: a transport blip
/// should be visible to the user within one polling round-trip plus
/// two retries.
const Duration _kRadioStatsStaleAfter = Duration(seconds: 5);

/// Riverpod 3.x notifier polling `getRadioStats()` at 1 Hz while
/// subscribed. The firmware request bypasses the D34a chat rate
/// limiter (verified by `d35_radio_stats_session_test.dart`), so the
/// poll loop does not compete for the 1024 B / 60 s text budget.
///
/// In-memory only. No persistence, no diagnostics export, no remote
/// telemetry.
class MeshCoreRadioStatsNotifier extends Notifier<MeshCoreRadioStatsSnapshot> {
  Timer? _ticker;
  bool _inFlight = false;

  @override
  MeshCoreRadioStatsSnapshot build() {
    ref.onDispose(() {
      _ticker?.cancel();
      _ticker = null;
    });

    final session = ref.watch(meshCoreSessionProvider);
    _ticker?.cancel();
    if (session == null) {
      return const MeshCoreRadioStatsSnapshot.disconnected();
    }

    // Kick off the first fetch immediately so the card populates
    // within the first second instead of waiting for the timer tick.
    Future.microtask(_pollOnce);

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _pollOnce());

    return const MeshCoreRadioStatsSnapshot(
      latest: null,
      isStale: false,
      isConnected: true,
    );
  }

  Future<void> _pollOnce() async {
    if (_inFlight) return;
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      state = const MeshCoreRadioStatsSnapshot.disconnected();
      return;
    }

    _inFlight = true;
    try {
      final stats = await session.getRadioStats();
      // Re-read session in case it swapped during the await.
      final stillConnected = ref.read(meshCoreSessionProvider) != null;
      if (!stillConnected) {
        state = const MeshCoreRadioStatsSnapshot.disconnected();
        return;
      }
      if (stats == null) {
        // Timeout / wrong-subtype / truncated: keep the previous
        // snapshot but flag it stale so the UI can grey it.
        final prev = state.latest;
        state = MeshCoreRadioStatsSnapshot(
          latest: prev,
          isStale: prev != null,
          isConnected: true,
        );
        return;
      }
      state = MeshCoreRadioStatsSnapshot(
        latest: stats,
        isStale: false,
        isConnected: true,
      );
    } finally {
      _inFlight = false;
    }
  }

  /// Force-refresh from the live session. Used by tests and any UI
  /// that wants to pull a fresh snapshot without waiting for the
  /// 1 Hz tick.
  Future<void> refreshNow() => _pollOnce();

  /// Recompute the stale flag against [now]. The 1 Hz timer already
  /// drives a fresh fetch every second, but the widget reads the
  /// snapshot synchronously; this helper lets the widget decide
  /// "stale at render time" without forcing another fetch.
  bool isStaleAt(DateTime now) {
    final latest = state.latest;
    if (latest == null) return false;
    return now.difference(latest.fetchedAt) > _kRadioStatsStaleAfter;
  }
}

final meshCoreRadioStatsProvider =
    NotifierProvider<MeshCoreRadioStatsNotifier, MeshCoreRadioStatsSnapshot>(
      MeshCoreRadioStatsNotifier.new,
    );

// ---------------------------------------------------------------------------
// D35-B-A: Companion radio CORE stats provider (uptime, queue, err flags).
// ---------------------------------------------------------------------------

/// Immutable wrapper carrying the latest [MeshCoreCoreStats] plus the
/// connection / staleness signals the Tools card renders.
///
/// Mirrors the shape of [MeshCoreRadioStatsSnapshot]; CORE stats are
/// polled on a slower cadence (5 s) so the staleness window is
/// proportionally larger (15 s).
class MeshCoreCoreStatsSnapshot {
  final MeshCoreCoreStats? latest;
  final bool isStale;
  final bool isConnected;

  const MeshCoreCoreStatsSnapshot({
    required this.latest,
    required this.isStale,
    required this.isConnected,
  });

  const MeshCoreCoreStatsSnapshot.disconnected()
    : latest = null,
      isStale = false,
      isConnected = false;
}

/// D35-B-A: CORE poll cadence and staleness threshold.
///
/// CORE values change slowly (uptime ticks once per second; queue
/// length is bursty but typically drains within a second; error
/// flags rarely flip). Polling every 5 s keeps wire chatter minimal.
/// The 15 s stale threshold catches a transport blip after roughly
/// three missed polls, leaving slack for the firmware to recover
/// without flapping the UI.
const Duration _kCoreStatsPollInterval = Duration(seconds: 5);
const Duration _kCoreStatsStaleAfter = Duration(seconds: 15);

/// Riverpod 3.x notifier polling `getCoreStats()` at 0.2 Hz while
/// subscribed. The firmware request bypasses the D34a chat rate
/// limiter, so the poll loop does not compete for the 1024 B / 60 s
/// text budget. In-memory only.
class MeshCoreCoreStatsNotifier extends Notifier<MeshCoreCoreStatsSnapshot> {
  Timer? _ticker;
  bool _inFlight = false;

  @override
  MeshCoreCoreStatsSnapshot build() {
    ref.onDispose(() {
      _ticker?.cancel();
      _ticker = null;
    });

    final session = ref.watch(meshCoreSessionProvider);
    _ticker?.cancel();
    if (session == null) {
      return const MeshCoreCoreStatsSnapshot.disconnected();
    }

    Future.microtask(_pollOnce);

    _ticker = Timer.periodic(_kCoreStatsPollInterval, (_) => _pollOnce());

    return const MeshCoreCoreStatsSnapshot(
      latest: null,
      isStale: false,
      isConnected: true,
    );
  }

  Future<void> _pollOnce() async {
    if (_inFlight) return;
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      state = const MeshCoreCoreStatsSnapshot.disconnected();
      return;
    }

    _inFlight = true;
    try {
      final stats = await session.getCoreStats();
      final stillConnected = ref.read(meshCoreSessionProvider) != null;
      if (!stillConnected) {
        state = const MeshCoreCoreStatsSnapshot.disconnected();
        return;
      }
      if (stats == null) {
        final prev = state.latest;
        state = MeshCoreCoreStatsSnapshot(
          latest: prev,
          isStale: prev != null,
          isConnected: true,
        );
        return;
      }
      state = MeshCoreCoreStatsSnapshot(
        latest: stats,
        isStale: false,
        isConnected: true,
      );
    } finally {
      _inFlight = false;
    }
  }

  /// Force-refresh from the live session. Used by tests and any UI
  /// that wants a fresh snapshot without waiting for the 5 s tick.
  Future<void> refreshNow() => _pollOnce();

  /// Recompute the stale flag against [now]. Mirrors the helper on
  /// [MeshCoreRadioStatsNotifier].
  bool isStaleAt(DateTime now) {
    final latest = state.latest;
    if (latest == null) return false;
    return now.difference(latest.fetchedAt) > _kCoreStatsStaleAfter;
  }
}

final meshCoreCoreStatsProvider =
    NotifierProvider<MeshCoreCoreStatsNotifier, MeshCoreCoreStatsSnapshot>(
      MeshCoreCoreStatsNotifier.new,
    );
