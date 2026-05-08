// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// Providers for MeshCore integration and protocol-agnostic device info.
//
// These providers enable the UI to access protocol-agnostic device
// information without depending on Meshtastic or MeshCore specific code.

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
    return true;
  }

  /// D29 Part C: reset the firmware-side learned route for the
  /// contact whose [publicKeyHex] matches (`CMD_RESET_PATH` 0x0D),
  /// then refresh so the local cache picks up the new path state.
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
    return true;
  }
}

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
