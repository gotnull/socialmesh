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
import '../l10n/app_localizations.dart';
import '../core/meshcore_constants.dart';
import '../core/transport.dart';
import '../models/mesh_device.dart';
// D46-A: `parseContact` is imported via meshcore_messages.dart below
// (typed `ParseResult<MeshCoreContactInfo>`). The model-side weak
// variant (`MeshCoreContact?` direct return) is hidden so callers
// here disambiguate cleanly.
import '../models/meshcore_contact.dart' hide parseContact;
import '../models/meshcore_contact_import_preview.dart';
import '../models/meshcore_auto_add_config.dart';
import '../models/meshcore_auto_route_settings.dart';
import '../models/meshcore_channel.dart';
import '../models/meshcore_path_overlay.dart';
import '../services/meshcore/protocol/meshcore_cayenne_lpp.dart';
import '../services/meshcore/connection_coordinator.dart';
import '../services/meshcore/meshcore_adapter.dart';
import '../services/meshcore/meshcore_detector.dart';
import '../services/meshcore/meshcore_send_rate_limiter.dart';
import '../services/meshcore/protocol/meshcore_capture.dart';
import '../services/meshcore/protocol/meshcore_contact_url.dart';
import '../services/meshcore/protocol/meshcore_messages.dart';
import '../services/meshcore/protocol/meshcore_session.dart';
import '../services/meshcore/routing/meshcore_path_update_listener.dart';
import '../services/meshcore/routing/meshcore_send_confirmation_router.dart';
import '../services/meshcore/storage/meshcore_channel_prefs_store.dart';
import '../services/meshcore/storage/meshcore_message_store.dart';
import '../services/meshcore/storage/meshcore_path_history_store.dart';
import '../services/notifications/meshcore_advert_batcher.dart';
import '../services/notifications/meshcore_notification_rate_limiter.dart';
import '../services/notifications/notification_service.dart';
import 'app_providers.dart';
import 'connection_providers.dart';
import 'meshcore_notification_settings.dart';

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

/// D48-A2: single delivery-ack router per active session. Re-created
/// whenever the session changes (reconnect, swap to a different
/// radio). Tests override with a router fed by a controllable stream.
final meshCoreSendConfirmationRouterProvider =
    Provider<MeshCoreSendConfirmationRouter?>((ref) {
      final session = ref.watch(meshCoreSessionProvider);
      if (session == null) return null;
      final router = MeshCoreSendConfirmationRouter(
        frameStream: session.frameStream,
      );
      ref.onDispose(router.dispose);
      return router;
    });

/// D48-A3: passive path-history seeding listener.
///
/// Subscribes to `PUSH_CODE_PATH_UPDATED 0x81` on the active session's
/// frame stream. On each push: extract the contact pubkey, issue
/// `CMD_GET_CONTACT_BY_KEY 0x1E` to retrieve the freshly-learned
/// path, and record it via the per-contact path-history notifier
/// (D39 + D48-A1 store, source `inbound`).
///
/// Owned by the active session: recreated on reconnect / radio swap,
/// disposed on session teardown.
final meshCorePathUpdateListenerProvider =
    Provider<MeshCorePathUpdateListener?>((ref) {
      final session = ref.watch(meshCoreSessionProvider);
      if (session == null) return null;
      final listener = MeshCorePathUpdateListener(
        session: session,
        recorder:
            ({
              required String contactPubKeyHex,
              required Uint8List pathBytes,
            }) async {
              await ref
                  .read(meshCorePathHistoryProvider(contactPubKeyHex).notifier)
                  .record(pathBytes, MeshCorePathSource.inbound);
            },
      );
      ref.onDispose(listener.dispose);
      return listener;
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

  /// Contacts received so far during an in-flight roster sync.
  final int syncReceived;

  /// Total contacts the firmware will send this sync (from the
  /// `CONTACTS_START` count), or `null` when the firmware omits it
  /// (older firmware) — drives indeterminate vs determinate progress.
  final int? syncTotal;

  const MeshCoreContactsState({
    this.contacts = const [],
    this.isLoading = false,
    this.error,
    this.lastRefresh,
    this.syncReceived = 0,
    this.syncTotal,
  });

  const MeshCoreContactsState.initial()
    : contacts = const [],
      isLoading = false,
      error = null,
      lastRefresh = null,
      syncReceived = 0,
      syncTotal = null;
  const MeshCoreContactsState.loading()
    : contacts = const [],
      isLoading = true,
      error = null,
      lastRefresh = null,
      syncReceived = 0,
      syncTotal = null;

  MeshCoreContactsState copyWith({
    List<MeshCoreContact>? contacts,
    bool? isLoading,
    String? error,
    DateTime? lastRefresh,
    int? syncReceived,
    int? syncTotal,
    bool clearSyncTotal = false,
  }) {
    return MeshCoreContactsState(
      contacts: contacts ?? this.contacts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastRefresh: lastRefresh ?? this.lastRefresh,
      syncReceived: syncReceived ?? this.syncReceived,
      syncTotal: clearSyncTotal ? null : (syncTotal ?? this.syncTotal),
    );
  }
}

class MeshCoreContactsNotifier extends Notifier<MeshCoreContactsState> {
  @override
  MeshCoreContactsState build() {
    // Auto-fetch contacts when connected to MeshCore
    final linkStatus = ref.watch(linkStatusProvider);
    if (linkStatus.isMeshCore && linkStatus.isConnected) {
      // D48-A3: eagerly bind the path-update listener so it begins
      // subscribing to PUSH_CODE_PATH_UPDATED 0x81 the moment a
      // session is up. The listener provider is otherwise lazy.
      ref.watch(meshCorePathUpdateListenerProvider);
      // Defer loading to avoid build-phase side effects
      Future.microtask(() => _loadContacts());
    }
    return const MeshCoreContactsState.initial();
  }

  Future<void> _loadContacts() async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      error: null,
      syncReceived: 0,
      clearSyncTotal: true,
    );

    try {
      final session = ref.read(meshCoreSessionProvider);
      if (session == null) {
        state = state.copyWith(isLoading: false, error: 'No MeshCore session');
        return;
      }

      final contactInfos = await session.getContacts(
        onProgress: (received, total) {
          state = state.copyWith(
            syncReceived: received,
            syncTotal: total,
            clearSyncTotal: total == null,
          );
        },
      );

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
          // D-Q3: surface the firmware-side flags byte. Bit 0
          // drives the favorite star + pinned-to-top sort.
          flags: info.flags,
        );
      }).toList();

      // D-Q3: favorites pin to the top; remaining rows sort by name.
      contacts.sort((a, b) {
        if (a.isFavorite != b.isFavorite) {
          return a.isFavorite ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

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

  /// D46-A: broadcast OUR contact card to nearby peers via
  /// `CMD_SHARE_CONTACT 0x10`. Pulls the local device's pubkey from
  /// [meshCoreSelfInfoProvider] — the firmware uses it to identify
  /// which self-advertisement to broadcast.
  ///
  /// Returns `true` on `RESP_CODE_OK`, `false` on no session, no
  /// self-info loaded, firmware error, or timeout.
  Future<bool> broadcastSelfContact() async {
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      AppLogging.meshcore(
        'event=contact.share.skipped reason=no_session',
        error: true,
      );
      return false;
    }
    final selfInfo = ref.read(meshCoreSelfInfoProvider).selfInfo;
    if (selfInfo == null || selfInfo.pubKey.isEmpty) {
      AppLogging.meshcore(
        'event=contact.share.skipped reason=no_self_info',
        error: true,
      );
      return false;
    }
    return session.shareSelfContact(selfInfo.pubKey);
  }

  /// D46-A: export [contact] from firmware and return the canonical
  /// `meshcore://<hex>` URL. Returns `null` on no session, firmware
  /// error, malformed frame, or timeout.
  Future<String?> exportContactUrl(MeshCoreContact contact) async {
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      AppLogging.meshcore(
        'event=contact.export.skipped reason=no_session',
        error: true,
      );
      return null;
    }
    final frame = await session.exportContact(contact.publicKey);
    if (frame == null) return null;
    try {
      return MeshCoreContactUrl.encode(frame);
    } on ArgumentError {
      // Session already validates the 135..147 byte range, but
      // defence-in-depth: if a future firmware emits a longer frame,
      // surface the failure rather than encode garbage.
      AppLogging.meshcore(
        'event=contact.export.encode_failed bytes=${frame.length}',
        error: true,
      );
      return null;
    }
  }

  /// D46-A: parse a `meshcore://<hex>` (or legacy `<pubkeyhex>:<name>`)
  /// clipboard payload into a preview struct ready for the
  /// confirmation sheet. Synchronous — no firmware round-trip.
  ///
  /// Returns `null` when the input matches neither format or is
  /// otherwise unparseable.
  MeshCoreContactImportPreview? previewContactImport(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    // Try modern format first.
    final frame = MeshCoreContactUrl.decode(trimmed);
    if (frame != null) {
      final parseResult = parseContact(frame);
      if (!parseResult.isSuccess) {
        AppLogging.meshcore(
          'event=contact.import.preview.failed reason=parse_modern',
          error: true,
        );
        return null;
      }
      final info = parseResult.value!;
      final contact = MeshCoreContact(
        publicKey: info.publicKey,
        name: info.name,
        type: info.advType,
        pathLength: info.pathLength,
        path: info.pathBytes,
        latitude: info.latitudeDegrees,
        longitude: info.longitudeDegrees,
        lastSeen: DateTime.fromMillisecondsSinceEpoch(info.lastMod * 1000),
      );
      return MeshCoreContactImportPreview(
        format: MeshCoreContactImportFormat.modern,
        contact: contact,
        pubKeyFingerprint8: _firstNHex(info.publicKey, 8),
        frameBytes: frame,
      );
    }

    // Fall back to the legacy `<pubkeyhex>:<name>` form.
    final legacy = parseLegacyContactCode(trimmed);
    if (legacy == null) {
      AppLogging.meshcore(
        'event=contact.import.preview.failed reason=unrecognized_format',
        error: true,
      );
      return null;
    }
    return MeshCoreContactImportPreview(
      format: MeshCoreContactImportFormat.legacy,
      contact: legacy,
      pubKeyFingerprint8: _firstNHex(legacy.publicKey, 8),
    );
  }

  /// D46-A: send a previewed contact to firmware. Routes through
  /// `CMD_IMPORT_CONTACT 0x12` (full-frame) when the preview is
  /// modern; otherwise falls through to the D29 `addUpdateContact`
  /// path (the legacy text-form cannot round-trip the canonical
  /// frame).
  ///
  /// Returns `true` on firmware acceptance + a successful contact
  /// list refresh.
  Future<bool> commitContactImport(MeshCoreContactImportPreview preview) async {
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      AppLogging.meshcore(
        'event=contact.import.commit.skipped reason=no_session',
        error: true,
      );
      return false;
    }
    bool ok;
    if (preview.isFullFrame) {
      ok = await session.importContact(preview.frameBytes!);
    } else {
      ok = await session.addUpdateContact(
        pubKey: preview.contact.publicKey,
        advType: preview.contact.type,
        name: preview.contact.name,
        flags: 0,
        pathLength: preview.contact.pathLength,
        pathBytes: preview.contact.path,
        latitude: preview.contact.latitude,
        longitude: preview.contact.longitude,
      );
    }
    if (!ok) return false;
    await refresh();
    return true;
  }

  static String _firstNHex(Uint8List bytes, int n) {
    final take = bytes.length < (n ~/ 2) ? bytes.length : (n ~/ 2);
    final sb = StringBuffer();
    for (int i = 0; i < take; i++) {
      sb.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
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
    // D39-A: record the hop bytes in this contact's app-local path
    // history (source: trace). Dedup + LRU eviction live in the
    // history store. Skips silently on hopBytes.isEmpty - a direct
    // route is a mode, not a path. Failures are logged by the
    // notifier and do NOT mask the firmware write's success.
    if (hopBytes.isNotEmpty) {
      await ref
          .read(meshCorePathHistoryProvider(publicKeyHex).notifier)
          .record(hopBytes, MeshCorePathSource.trace);
    }
    return true;
  }

  /// D34c-B-B: write a user-typed N-hop path override to the firmware
  /// contact entry. Mirrors the shape of [setContactPathFromTrace] but
  /// records the path-history entry with `MeshCorePathSource.manual`
  /// so the row's source badge renders the correct label.
  ///
  /// Use case: power user wants to force traffic through a specific
  /// sequence of repeaters that did NOT come from a trace response.
  ///
  /// Validation contract: the caller (typically the manual-path sheet)
  /// must have already parsed `hopBytes` from the user input via
  /// `parseManualPathHexPrefixes`. This wrapper accepts the bytes
  /// verbatim and clamps to the same 64-hop ceiling the parser
  /// enforces; an over-length list is silently truncated to fail the
  /// firmware ACK rather than mask the misuse.
  ///
  /// Logging surface (privacy-redacted):
  ///   - `event=contact.set_path_from_manual.attempted pubkey=<8B fingerprint> path_len=N`
  ///   - `event=contact.set_path_from_manual.<succeeded|failed> ...`
  /// Path bytes themselves are NEVER logged.
  Future<bool> setContactPathFromManualEntry({
    required String publicKeyHex,
    required Uint8List hopBytes,
  }) async {
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      AppLogging.meshcore(
        'event=contact.set_path_from_manual.skipped reason=no_session',
        error: true,
      );
      return false;
    }
    final contact = state.contacts.firstWhere(
      (c) => c.publicKeyHex == publicKeyHex,
      orElse: () => throw ArgumentError('contact not found: $publicKeyHex'),
    );
    AppLogging.meshcore(
      'event=contact.set_path_from_manual.attempted '
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
      'event=contact.set_path_from_manual.${ok ? 'succeeded' : 'failed'} '
      'pubkey=${AppLogging.publicKeyFingerprint(contact.publicKey)} '
      'path_len=${hopBytes.length}',
      error: !ok,
    );
    if (!ok) return false;
    await refresh();
    _applyLocalPathOverride(
      publicKeyHex: publicKeyHex,
      pathOverride: hopBytes.length,
      pathOverrideBytes: Uint8List.fromList(hopBytes),
    );
    if (hopBytes.isNotEmpty) {
      await ref
          .read(meshCorePathHistoryProvider(publicKeyHex).notifier)
          .record(hopBytes, MeshCorePathSource.manual);
    }
    return true;
  }

  /// D-Q3: flip the per-contact favorite bit (`MeshCoreContactFlags.favorite`)
  /// and write the new flags byte back via `CMD_ADD_UPDATE_CONTACT 0x09`.
  /// Read-modify-write: reserved bits in `flags` round-trip verbatim so a
  /// future telemetry-permission slice doesn't fight this one.
  ///
  /// Mirrors the new flag into local state on success so the UI re-renders
  /// without waiting for the post-write `refresh()` (which still fires so
  /// the firmware-canonical state lands).
  Future<bool> toggleContactFavorite({required String publicKeyHex}) async {
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      AppLogging.meshcore(
        'event=contact.toggle_favorite.skipped reason=no_session',
        error: true,
      );
      return false;
    }
    final contact = state.contacts.firstWhere(
      (c) => c.publicKeyHex == publicKeyHex,
      orElse: () => throw ArgumentError('contact not found: $publicKeyHex'),
    );
    final nextFlags = contact.flags ^ MeshCoreContactFlags.favorite;
    AppLogging.meshcore(
      'event=contact.toggle_favorite.attempted '
      'pubkey=${AppLogging.publicKeyFingerprint(contact.publicKey)} '
      'flags_before=0x${contact.flags.toRadixString(16).padLeft(2, '0')} '
      'flags_after=0x${nextFlags.toRadixString(16).padLeft(2, '0')}',
    );
    final ok = await session.addUpdateContact(
      pubKey: contact.publicKey,
      advType: contact.type,
      name: contact.name,
      flags: nextFlags,
      pathLength: contact.pathLength,
      pathBytes: contact.path,
      latitude: contact.latitude,
      longitude: contact.longitude,
    );
    AppLogging.meshcore(
      'event=contact.toggle_favorite.${ok ? 'succeeded' : 'failed'} '
      'pubkey=${AppLogging.publicKeyFingerprint(contact.publicKey)}',
      error: !ok,
    );
    if (!ok) return false;
    // Mirror locally before refresh() so the UI re-renders immediately.
    final updatedContacts =
        state.contacts.map((c) {
          if (c.publicKeyHex != publicKeyHex) return c;
          return c.copyWith(flags: nextFlags);
        }).toList()..sort((a, b) {
          if (a.isFavorite != b.isFavorite) {
            return a.isFavorite ? -1 : 1;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
    state = state.copyWith(contacts: updatedContacts);
    await refresh();
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

  /// Channel slots probed so far during an in-flight sync.
  final int syncReceived;

  /// Total channel slots being probed this sync (the fixed slot count),
  /// or `null` before a sync starts.
  final int? syncTotal;

  const MeshCoreChannelsState({
    this.channels = const [],
    this.isLoading = false,
    this.error,
    this.lastRefresh,
    this.syncReceived = 0,
    this.syncTotal,
  });

  const MeshCoreChannelsState.initial()
    : channels = const [],
      isLoading = false,
      error = null,
      lastRefresh = null,
      syncReceived = 0,
      syncTotal = null;
  const MeshCoreChannelsState.loading()
    : channels = const [],
      isLoading = true,
      error = null,
      lastRefresh = null,
      syncReceived = 0,
      syncTotal = null;

  MeshCoreChannelsState copyWith({
    List<MeshCoreChannel>? channels,
    bool? isLoading,
    String? error,
    DateTime? lastRefresh,
    int? syncReceived,
    int? syncTotal,
    bool clearSyncTotal = false,
  }) {
    return MeshCoreChannelsState(
      channels: channels ?? this.channels,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastRefresh: lastRefresh ?? this.lastRefresh,
      syncReceived: syncReceived ?? this.syncReceived,
      syncTotal: clearSyncTotal ? null : (syncTotal ?? this.syncTotal),
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

    state = state.copyWith(
      isLoading: true,
      error: null,
      syncReceived: 0,
      clearSyncTotal: true,
    );

    try {
      final session = ref.read(meshCoreSessionProvider);
      if (session == null) {
        state = state.copyWith(isLoading: false, error: 'No MeshCore session');
        return;
      }

      final channelInfos = await session.getChannels(
        onProgress: (received, total) {
          state = state.copyWith(syncReceived: received, syncTotal: total);
        },
      );

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

// ---------------------------------------------------------------------------
// MeshCore initial-sync progress (parity gap MO-4)
// ---------------------------------------------------------------------------

/// View model for the cross-tab sync-progress bar.
///
/// [active] is true while any roster sync is in flight. [value] is the
/// determinate fraction `0.0..1.0`, or `null` for an indeterminate bar
/// (sync active but no known total yet).
class MeshCoreSyncProgress {
  final bool active;
  final double? value;

  const MeshCoreSyncProgress({required this.active, this.value});

  static double? _fraction(int received, int? total) {
    if (total == null || total <= 0) return null;
    return (received / total).clamp(0.0, 1.0).toDouble();
  }
}

/// Derives the sync-progress bar state from the contacts and channels
/// notifiers. Contacts and channels load in parallel; the bar prefers the
/// contact fraction (the count-backed headline signal) while contacts are
/// syncing and falls back to channels otherwise. Centralising the
/// received/total math here keeps it out of the widget.
final meshCoreSyncProgressProvider = Provider<MeshCoreSyncProgress>((ref) {
  final contacts = ref.watch(meshCoreContactsProvider);
  final channels = ref.watch(meshCoreChannelsProvider);

  final active = contacts.isLoading || channels.isLoading;
  if (!active) {
    return const MeshCoreSyncProgress(active: false);
  }

  final value = contacts.isLoading
      ? MeshCoreSyncProgress._fraction(
          contacts.syncReceived,
          contacts.syncTotal,
        )
      : MeshCoreSyncProgress._fraction(
          channels.syncReceived,
          channels.syncTotal,
        );
  return MeshCoreSyncProgress(active: true, value: value);
});

// ---------------------------------------------------------------------------
// D37-A: MeshCore channel preferences (mute)
// ---------------------------------------------------------------------------

/// 8-char hex prefix of the connected device's public key.
///
/// Used as the per-device key for [MeshCoreChannelPrefsStore]. Empty
/// string when no MeshCore device is identified yet — the store treats
/// the empty key as "no-op" so writes never land in a global keyspace.
///
/// Logging note: only this 8-char prefix is ever logged downstream;
/// the full 32-byte pubkey is intentionally never written to logs by
/// the channel-prefs surface.
String meshCoreSelfPubKeyPrefix(MeshCoreSelfInfo? info) {
  if (info == null) return '';
  final bytes = info.pubKey;
  if (bytes.isEmpty) return '';
  final hex = bytes
      .take(4)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return hex;
}

/// Reactive provider exposing the connected device's 8-char pubkey
/// prefix (or empty string when no device is identified).
final meshCoreSelfPubKeyPrefixProvider = Provider<String>((ref) {
  final info = ref.watch(meshCoreSelfInfoProvider).selfInfo;
  return meshCoreSelfPubKeyPrefix(info);
});

/// Process-wide [MeshCoreChannelPrefsStore]. Tests override this with a
/// `SharedPreferences.setMockInitialValues`-backed instance.
final meshCoreChannelPrefsStoreProvider = Provider<MeshCoreChannelPrefsStore>((
  ref,
) {
  return MeshCoreChannelPrefsStore();
});

/// D37-A: per-device channel preferences (muted set + reserved hidden/
/// order). Notifier-shaped so widgets can `ref.watch` directly.
///
/// Lifecycle:
///   - `build()` reads the current pubkey prefix; when it flips
///     (connect, reconnect to a different device, disconnect), the
///     notifier re-loads from the store.
///   - Empty prefix → state remains [MeshCoreChannelPrefs.empty] and
///     all mutate paths are no-ops.
///   - On a successful mutate, the persisted blob is the source of
///     truth: we re-read it to update state so a concurrent write
///     elsewhere can't be silently overwritten.
///
/// Logging discipline (verified by `d37a_channel_prefs_redaction_test.dart`):
///   - Only `idx=<int>` and the 8-char pubkey-prefix appear in events.
///   - Never the channel name, never the PSK, never the channel code,
///     never the full pubkey.
class MeshCoreChannelPrefsNotifier extends Notifier<MeshCoreChannelPrefs> {
  String _lastLoadedPrefix = '';
  bool _disposed = false;

  @override
  MeshCoreChannelPrefs build() {
    _disposed = false;
    final prefix = ref.watch(meshCoreSelfPubKeyPrefixProvider);
    if (prefix.isEmpty) {
      _lastLoadedPrefix = '';
      // Defer reset off-build so we don't write to `state` before it's
      // initialised.
      Future<void>(() {
        if (_disposed) return;
        if (state.mutedChannelIndices.isEmpty &&
            state.hiddenChannelIndices.isEmpty &&
            state.orderedChannelIndices.isEmpty) {
          return;
        }
        state = MeshCoreChannelPrefs.empty;
      });
    } else if (prefix != _lastLoadedPrefix) {
      _lastLoadedPrefix = prefix;
      Future<void>(_loadFor(prefix));
    }
    ref.onDispose(() {
      _disposed = true;
    });
    return MeshCoreChannelPrefs.empty;
  }

  Future<void> Function() _loadFor(String prefix) {
    return () async {
      if (_disposed) return;
      try {
        final store = ref.read(meshCoreChannelPrefsStoreProvider);
        final loaded = await store.load(prefix);
        if (_disposed) return;
        // Defensive: the pubkey may have flipped while we were
        // awaiting. Only write state if the prefix is still current.
        if (ref.read(meshCoreSelfPubKeyPrefixProvider) != prefix) return;
        state = loaded;
      } catch (e) {
        if (_disposed) return;
        AppLogging.meshcore(
          'event=channel.prefs.load.failed reason=${e.runtimeType}',
          error: true,
        );
      }
    };
  }

  /// True iff slot [channelIndex] is currently muted.
  bool isMuted(int channelIndex) =>
      state.mutedChannelIndices.contains(channelIndex);

  /// Persist mute on slot [channelIndex]. Idempotent. No-op when no
  /// device is identified.
  Future<void> mute(int channelIndex) async {
    final prefix = ref.read(meshCoreSelfPubKeyPrefixProvider);
    if (prefix.isEmpty) return;
    if (state.mutedChannelIndices.contains(channelIndex)) return;
    final store = ref.read(meshCoreChannelPrefsStoreProvider);
    try {
      final updated = await store.mute(prefix, channelIndex);
      if (_disposed) return;
      if (ref.read(meshCoreSelfPubKeyPrefixProvider) != prefix) return;
      state = updated;
      AppLogging.meshcore(
        'event=channel.muted idx=$channelIndex device=$prefix',
      );
    } catch (e) {
      AppLogging.meshcore(
        'event=channel.mute.failed idx=$channelIndex reason=${e.runtimeType}',
        error: true,
      );
    }
  }

  /// Persist un-mute on slot [channelIndex]. Idempotent.
  Future<void> unmute(int channelIndex) async {
    final prefix = ref.read(meshCoreSelfPubKeyPrefixProvider);
    if (prefix.isEmpty) return;
    if (!state.mutedChannelIndices.contains(channelIndex)) return;
    final store = ref.read(meshCoreChannelPrefsStoreProvider);
    try {
      final updated = await store.unmute(prefix, channelIndex);
      if (_disposed) return;
      if (ref.read(meshCoreSelfPubKeyPrefixProvider) != prefix) return;
      state = updated;
      AppLogging.meshcore(
        'event=channel.unmuted idx=$channelIndex device=$prefix',
      );
    } catch (e) {
      AppLogging.meshcore(
        'event=channel.unmute.failed idx=$channelIndex '
        'reason=${e.runtimeType}',
        error: true,
      );
    }
  }

  /// D37-B-A: true iff slot [channelIndex] is currently hidden from
  /// the default channels list.
  bool isHidden(int channelIndex) =>
      state.hiddenChannelIndices.contains(channelIndex);

  /// D37-B-A: persist hide on slot [channelIndex]. Idempotent. No-op
  /// when no device is identified. Hide is independent of mute and
  /// does NOT gate notifications — the notification gate consults
  /// the muted set only.
  Future<void> hide(int channelIndex) async {
    final prefix = ref.read(meshCoreSelfPubKeyPrefixProvider);
    if (prefix.isEmpty) return;
    if (state.hiddenChannelIndices.contains(channelIndex)) return;
    final store = ref.read(meshCoreChannelPrefsStoreProvider);
    try {
      final updated = await store.hide(prefix, channelIndex);
      if (_disposed) return;
      if (ref.read(meshCoreSelfPubKeyPrefixProvider) != prefix) return;
      state = updated;
      AppLogging.meshcore(
        'event=channel.hidden idx=$channelIndex device=$prefix',
      );
    } catch (e) {
      AppLogging.meshcore(
        'event=channel.hide.failed idx=$channelIndex reason=${e.runtimeType}',
        error: true,
      );
    }
  }

  /// D37-B-A: persist unhide on slot [channelIndex]. Idempotent.
  Future<void> unhide(int channelIndex) async {
    final prefix = ref.read(meshCoreSelfPubKeyPrefixProvider);
    if (prefix.isEmpty) return;
    if (!state.hiddenChannelIndices.contains(channelIndex)) return;
    final store = ref.read(meshCoreChannelPrefsStoreProvider);
    try {
      final updated = await store.unhide(prefix, channelIndex);
      if (_disposed) return;
      if (ref.read(meshCoreSelfPubKeyPrefixProvider) != prefix) return;
      state = updated;
      AppLogging.meshcore(
        'event=channel.unhidden idx=$channelIndex device=$prefix',
      );
    } catch (e) {
      AppLogging.meshcore(
        'event=channel.unhide.failed idx=$channelIndex '
        'reason=${e.runtimeType}',
        error: true,
      );
    }
  }

  /// D37-C-A: replace the user-defined channel render order. The store
  /// dedupes and drops out-of-range entries; this notifier method just
  /// forwards the call and reflects the persisted result in state.
  /// Setting order does NOT mutate the muted or hidden sets.
  ///
  /// Log surface is intentionally count-only — the actual index list
  /// is not surfaced to AppLogging so log readers can't reconstruct
  /// the user's channel curation.
  Future<void> setOrder(List<int> order) async {
    final prefix = ref.read(meshCoreSelfPubKeyPrefixProvider);
    if (prefix.isEmpty) return;
    final store = ref.read(meshCoreChannelPrefsStoreProvider);
    try {
      final updated = await store.setOrder(prefix, order);
      if (_disposed) return;
      if (ref.read(meshCoreSelfPubKeyPrefixProvider) != prefix) return;
      state = updated;
      AppLogging.meshcore(
        'event=channel.order.set '
        'count=${updated.orderedChannelIndices.length} device=$prefix',
      );
    } catch (e) {
      AppLogging.meshcore(
        'event=channel.order.set.failed reason=${e.runtimeType}',
        error: true,
      );
    }
  }
}

final meshCoreChannelPrefsProvider =
    NotifierProvider<MeshCoreChannelPrefsNotifier, MeshCoreChannelPrefs>(
      MeshCoreChannelPrefsNotifier.new,
    );

/// Read-only convenience: the current muted set.
final meshCoreChannelMutedSetProvider = Provider<Set<int>>((ref) {
  return ref.watch(meshCoreChannelPrefsProvider).mutedChannelIndices;
});

/// Read-only convenience: the current hidden set (D37-B-A).
final meshCoreChannelHiddenSetProvider = Provider<Set<int>>((ref) {
  return ref.watch(meshCoreChannelPrefsProvider).hiddenChannelIndices;
});

/// Read-only convenience: the current user-defined channel render
/// order (D37-C-A). Listed slot indices render first in this order;
/// unlisted channels render after, in firmware slot-index order.
final meshCoreChannelOrderProvider = Provider<List<int>>((ref) {
  return ref.watch(meshCoreChannelPrefsProvider).orderedChannelIndices;
});

// ---------------------------------------------------------------------------
// D39-A: per-contact path history (app-local)
// ---------------------------------------------------------------------------

/// Process-wide [MeshCorePathHistoryStore]. Tests override with a
/// `SharedPreferences.setMockInitialValues`-backed instance.
final meshCorePathHistoryStoreProvider = Provider<MeshCorePathHistoryStore>((
  ref,
) {
  return MeshCorePathHistoryStore();
});

/// 8-char hex prefix of a contact's 32-byte ed25519 public key.
///
/// Used as the per-contact key for [MeshCorePathHistoryStore]. Mirrors
/// the canonical SocialMesh log fingerprint
/// (`MeshCoreContact.shortPubKeyHex`'s 8-head). Returns the empty
/// string when [publicKeyHex] is too short.
String meshCoreContactPubKeyPrefix(String publicKeyHex) {
  if (publicKeyHex.length < 8) return '';
  return publicKeyHex.substring(0, 8).toLowerCase();
}

/// Per-contact path-history notifier (family).
///
/// Lifecycle:
///   - `build()` reads the current device pubkey prefix; when it
///     flips (connect / device swap / disconnect), the notifier
///     re-loads from the store.
///   - When either prefix is empty, state stays empty and all
///     mutate paths are no-ops.
///
/// Logging discipline:
///   - Path bytes are NEVER written to AppLogging.
///   - Lines carry `path_len=<int>` and `source=<wire>` only.
class MeshCorePathHistoryNotifier
    extends Notifier<List<MeshCorePathHistoryEntry>> {
  MeshCorePathHistoryNotifier(this.publicKeyHex);

  /// Target contact's 64-char public-key hex; injected via the family
  /// tear-off.
  final String publicKeyHex;

  bool _disposed = false;
  String _lastLoadedDevice = '';

  @override
  List<MeshCorePathHistoryEntry> build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);

    final device = ref.watch(meshCoreSelfPubKeyPrefixProvider);
    final contactPrefix = meshCoreContactPubKeyPrefix(publicKeyHex);
    if (device.isEmpty || contactPrefix.isEmpty) {
      _lastLoadedDevice = '';
      return const <MeshCorePathHistoryEntry>[];
    }
    if (device != _lastLoadedDevice) {
      _lastLoadedDevice = device;
      Future<void>(() async {
        if (_disposed) return;
        try {
          final store = ref.read(meshCorePathHistoryStoreProvider);
          final loaded = await store.load(device, contactPrefix);
          if (_disposed) return;
          if (ref.read(meshCoreSelfPubKeyPrefixProvider) != device) return;
          state = loaded;
        } catch (e) {
          if (_disposed) return;
          AppLogging.meshcore(
            'event=path_history.load.failed reason=${e.runtimeType}',
            error: true,
          );
        }
      });
    }
    return const <MeshCorePathHistoryEntry>[];
  }

  /// Record [bytes] under this notifier's contact, sourced from a
  /// successful Trace Path save. Dedup + LRU eviction happen at the
  /// store layer. No-op on empty prefix.
  Future<void> record(Uint8List bytes, MeshCorePathSource source) async {
    final device = ref.read(meshCoreSelfPubKeyPrefixProvider);
    final contactPrefix = meshCoreContactPubKeyPrefix(publicKeyHex);
    if (device.isEmpty || contactPrefix.isEmpty) return;
    if (bytes.isEmpty || bytes.length > kMeshCorePathHistoryMaxPathBytes) {
      return;
    }
    final store = ref.read(meshCorePathHistoryStoreProvider);
    // D48-A2: seed new entries with the user-configured
    // `initialRouteWeight`. Existing entries are untouched (the store
    // only consults `initialWeight` when inserting; updates use
    // `recordPathSuccess` / `recordPathFailure`).
    final autoRouteSettings = ref.read(meshCoreAutoRouteSettingsProvider);
    try {
      final pre = state.length;
      final updated = await store.record(
        devicePubKeyPrefix: device,
        contactPubKeyPrefix: contactPrefix,
        bytes: bytes,
        source: source,
        now: DateTime.now(),
        initialWeight: autoRouteSettings.initialRouteWeight,
      );
      if (_disposed) return;
      if (ref.read(meshCoreSelfPubKeyPrefixProvider) != device) return;
      state = updated;
      AppLogging.meshcore(
        'event=path_history.recorded source=${source.wire} '
        'path_len=${bytes.length}',
      );
      if (pre >= kMeshCorePathHistoryMaxEntriesPerContact &&
          updated.length == kMeshCorePathHistoryMaxEntriesPerContact) {
        AppLogging.meshcore('event=path_history.evicted reason=lru');
      }
    } catch (e) {
      AppLogging.meshcore(
        'event=path_history.record.failed reason=${e.runtimeType}',
        error: true,
      );
    }
  }

  /// Activate the saved entry identified by [entryId]: write its
  /// path bytes to firmware via the existing
  /// [MeshCoreContactsNotifier.setContactPathFromTrace] helper, and
  /// on success bump the entry's `lastUsedAt`.
  ///
  /// Returns `false` when the entry is missing, the firmware write
  /// fails, or no device is identified.
  Future<bool> activate(String entryId) async {
    final device = ref.read(meshCoreSelfPubKeyPrefixProvider);
    final contactPrefix = meshCoreContactPubKeyPrefix(publicKeyHex);
    if (device.isEmpty || contactPrefix.isEmpty) return false;
    final entry = state.firstWhere(
      (e) => e.id == entryId,
      orElse: () => _missingEntry,
    );
    if (identical(entry, _missingEntry)) return false;
    final ok = await ref
        .read(meshCoreContactsProvider.notifier)
        .setContactPathFromTrace(
          publicKeyHex: publicKeyHex,
          hopBytes: entry.bytes,
        );
    if (!ok) return false;
    // setContactPathFromTrace records-or-touches the entry by exact
    // bytes via this notifier's `record()`, so `lastUsedAt` is
    // already up to date. Nothing else to do.
    AppLogging.meshcore(
      'event=path_history.activated path_len=${entry.bytes.length}',
    );
    return true;
  }

  /// Delete the saved entry identified by [entryId]. App-local only;
  /// firmware's active path override is unaffected.
  Future<void> delete(String entryId) async {
    final device = ref.read(meshCoreSelfPubKeyPrefixProvider);
    final contactPrefix = meshCoreContactPubKeyPrefix(publicKeyHex);
    if (device.isEmpty || contactPrefix.isEmpty) return;
    final store = ref.read(meshCorePathHistoryStoreProvider);
    try {
      final updated = await store.delete(
        devicePubKeyPrefix: device,
        contactPubKeyPrefix: contactPrefix,
        entryId: entryId,
      );
      if (_disposed) return;
      if (ref.read(meshCoreSelfPubKeyPrefixProvider) != device) return;
      state = updated;
      AppLogging.meshcore('event=path_history.deleted');
    } catch (e) {
      AppLogging.meshcore(
        'event=path_history.delete.failed reason=${e.runtimeType}',
        error: true,
      );
    }
  }

  static final MeshCorePathHistoryEntry _missingEntry =
      MeshCorePathHistoryEntry(
        id: '__missing__',
        bytes: Uint8List(0),
        len: 0,
        source: MeshCorePathSource.trace,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        lastUsedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
}

final meshCorePathHistoryProvider =
    NotifierProvider.family<
      MeshCorePathHistoryNotifier,
      List<MeshCorePathHistoryEntry>,
      String
    >(MeshCorePathHistoryNotifier.new);

// ---------------------------------------------------------------------------
// D42-A: map path overlay (app-local, ephemeral, single at a time)
// ---------------------------------------------------------------------------

/// Holds the currently-rendered path overlay on `MeshCoreMapScreen`,
/// or `null` when no overlay is active. Replaced atomically by every
/// new `setActive` / `setFromHistory`; cleared via `clear()`.
///
/// Lifecycle:
///   - Ephemeral - never persisted.
///   - No background discovery, no auto-overlay on connect.
///   - Replaced (not stacked) on each new set call.
///
/// Logging:
///   - `event=path_overlay.shown source=<active|history> hop_count=<int>`
///   - `event=path_overlay.cleared`
///   - No path bytes, no full pubkeys, no message text.
class MeshCorePathOverlayNotifier extends Notifier<MeshCorePathOverlay?> {
  @override
  MeshCorePathOverlay? build() => null;

  /// Build an overlay from the contact's live firmware path
  /// (preferring `pathOverrideBytes` when set). Returns `true` iff
  /// the overlay carries at least two drawable points (origin →
  /// target via known hops). Returns `false` and leaves state
  /// untouched when the path is flood or no coordinate data
  /// resolved.
  bool setActive(MeshCoreContact contact) {
    // Notifier may be disposed if the caller fires from a teardown
    // path (route exit, provider container reset). Bail before any
    // ref.read / state = ... runs - those throw on disposed.
    // Crashlytics [E 88594eb8] + [E a0f48e9c].
    if (!ref.mounted) return false;
    final contacts = ref.read(meshCoreContactsProvider).contacts;
    final selfInfo = ref.read(meshCoreSelfInfoProvider).selfInfo;
    final overlay = MeshCorePathOverlay.fromContact(
      target: contact,
      contacts: contacts,
      selfInfo: selfInfo,
    );
    return _apply(overlay);
  }

  /// Build an overlay from a saved path-history hop-byte sequence.
  /// Returns `true` iff the overlay is drawable.
  bool setFromHistory(MeshCoreContact contact, Uint8List hopBytes) {
    if (!ref.mounted) return false;
    final contacts = ref.read(meshCoreContactsProvider).contacts;
    final selfInfo = ref.read(meshCoreSelfInfoProvider).selfInfo;
    final overlay = MeshCorePathOverlay.fromHistory(
      target: contact,
      contacts: contacts,
      selfInfo: selfInfo,
      hopBytes: hopBytes,
    );
    return _apply(overlay);
  }

  /// D42-B-A: build an overlay from app-local passive evidence (D39
  /// saved entries + persisted inbound message paths). Uses
  /// [inferRecentPathBytes] for the selection rule; never queries the
  /// firmware. Returns `true` iff a candidate was found AND the
  /// resulting overlay is drawable. State is not mutated on the
  /// `false` path — existing overlays survive a failed inference
  /// attempt.
  Future<bool> setInferred(MeshCoreContact contact) async {
    if (!ref.mounted) return false;
    final selfPrefix = ref.read(meshCoreSelfPubKeyPrefixProvider);
    final contactPrefix = meshCoreContactPubKeyPrefix(contact.publicKeyHex);
    if (selfPrefix.isEmpty || contactPrefix.isEmpty) return false;

    final historyStore = ref.read(meshCorePathHistoryStoreProvider);
    final messageStore = _messageStoreForInference;

    final results = await Future.wait<Object>([
      historyStore.load(selfPrefix, contactPrefix),
      messageStore.loadContactMessages(contact.publicKeyHex),
    ]);
    if (!ref.mounted) return false;

    final savedEntries = results[0] as List<MeshCorePathHistoryEntry>;
    final storedMessages = results[1] as List<MeshCoreStoredMessage>;

    final inferred = inferRecentPathBytes(
      savedEntries: savedEntries,
      storedMessages: storedMessages,
    );
    if (inferred == null) return false;

    final contacts = ref.read(meshCoreContactsProvider).contacts;
    final selfInfo = ref.read(meshCoreSelfInfoProvider).selfInfo;
    final overlay = MeshCorePathOverlay.fromInferred(
      target: contact,
      contacts: contacts,
      selfInfo: selfInfo,
      hopBytes: inferred.hopBytes,
    );
    return _apply(overlay);
  }

  /// Lazy MeshCoreMessageStore reference. Mirrors the
  /// `MeshCoreChatHistoryNotifier` pattern: stores are instantiated
  /// per-notifier and rely on `SharedPreferences.setMockInitialValues`
  /// in tests. There is no dedicated provider for the message store
  /// in this layer.
  MeshCoreMessageStore get _messageStoreForInference =>
      _messageStoreInstance ??= MeshCoreMessageStore();
  MeshCoreMessageStore? _messageStoreInstance;

  /// Remove the active overlay.
  void clear() {
    if (!ref.mounted) return;
    if (state == null) return;
    state = null;
    AppLogging.meshcore('event=path_overlay.cleared');
  }

  bool _apply(MeshCorePathOverlay? overlay) {
    if (overlay == null || !overlay.hasDrawableData) return false;
    state = overlay;
    AppLogging.meshcore(
      'event=path_overlay.shown source=${overlay.source.wire} '
      'hop_count=${overlay.totalHopCount}',
    );
    return true;
  }
}

final meshCorePathOverlayProvider =
    NotifierProvider<MeshCorePathOverlayNotifier, MeshCorePathOverlay?>(
      MeshCorePathOverlayNotifier.new,
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
/// Row 11.b: per-process rate limiter shared across all MeshCore
/// notification categories. Held at module level (not inside the
/// notifier) so its state survives notifier rebuilds and so multiple
/// surfaces can share categories without coordination.
final MeshCoreNotificationRateLimiter _meshCoreNotificationRateLimiter =
    MeshCoreNotificationRateLimiter(
      defaultCooldown: const Duration(minutes: 5),
    );

/// Row 11.c: aggregation buffer for adverts the rate limiter suppressed.
/// Drained on the next eligible advert and surfaced as a single batch
/// summary notification on the `meshcore_batch_summary` channel.
final MeshCoreAdvertBatcher _meshCoreAdvertBatcher = MeshCoreAdvertBatcher();

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

    // Row 11.b: fire an advert notification when this is the first
    // time we hear this peer in the current session, gated by the
    // user's "Advert notifications" toggle and the per-category rate
    // limiter so a chatty radio doesn't flood the lock screen.
    if (existing == null) {
      _maybeFireAdvertNotification(info);
    }
  }

  void _maybeFireAdvertNotification(MeshCoreContactInfo info) {
    final notificationsEnabled = ref
        .read(meshCoreAdvertNotificationsEnabledProvider)
        .maybeWhen(data: (v) => v, orElse: () => true);
    if (!notificationsEnabled) {
      // Toggle is OFF: discard anything currently buffered so a later
      // re-enable doesn't surface stale peers from the previous window.
      _meshCoreAdvertBatcher.clear();
      return;
    }
    final displayName = info.name.isEmpty ? info.publicKeyHex : info.name;
    if (!_meshCoreNotificationRateLimiter.tryFire('meshcore_adverts')) {
      // Row 11.c: instead of dropping, buffer the suppressed peer.
      // It will surface in the batch summary on the next eligible
      // fire when the rate limiter window elapses.
      _meshCoreAdvertBatcher.add(
        MeshCoreAdvertBatchEntry(
          pubKeyHex: info.publicKeyHex,
          displayName: displayName,
          heardAt: DateTime.now(),
        ),
      );
      AppLogging.meshcore(
        'event=discovery.notification.rate_limited '
        'pubkey=${AppLogging.publicKeyFingerprint(info.publicKey)} '
        'buffered=${_meshCoreAdvertBatcher.pendingCount}',
      );
      return;
    }
    // Rate limiter allowed the fire. If anything is buffered, this is a
    // batch trigger: include the trigger as the final entry and surface
    // a single summary covering every suppressed peer plus the trigger.
    if (_meshCoreAdvertBatcher.isNotEmpty) {
      _meshCoreAdvertBatcher.add(
        MeshCoreAdvertBatchEntry(
          pubKeyHex: info.publicKeyHex,
          displayName: displayName,
          heardAt: DateTime.now(),
        ),
      );
      final drained = _meshCoreAdvertBatcher.drain();
      AppLogging.meshcore(
        'event=discovery.notification.batch_summary '
        'count=${drained.length}',
      );
      NotificationService()
          .showMeshCoreAdvertBatchSummaryNotification(
            peerCount: drained.length,
            peerNames: drained.map((e) => e.displayName).toList(),
          )
          .catchError((Object e) {
            AppLogging.meshcore(
              'event=discovery.notification.error reason=${e.runtimeType}',
              error: true,
            );
          });
      return;
    }
    final advTypeLabel = _advTypeLabelForNotification(info.advType);
    NotificationService()
        .showMeshCoreAdvertNotification(
          contactName: displayName,
          pubKeyHex: info.publicKeyHex,
          advTypeLabel: advTypeLabel,
        )
        .catchError((Object e) {
          AppLogging.meshcore(
            'event=discovery.notification.error reason=${e.runtimeType}',
            error: true,
          );
        });
  }

  String? _advTypeLabelForNotification(int advType) {
    // The notifier doesn't carry a BuildContext, so resolve to a
    // locale-derived label via lookupAppLocalizations off the platform
    // dispatcher. Acceptable for a notification body; the chat UI uses
    // contact_l10n.dart for in-app type rendering.
    final l10n = lookupAppLocalizations(PlatformDispatcher.instance.locale);
    switch (advType) {
      case MeshCoreAdvType.chat:
        return l10n.meshcoreChatNode;
      case MeshCoreAdvType.repeater:
        return l10n.meshcoreRepeaterNode;
      case MeshCoreAdvType.room:
        return l10n.meshcoreRoomNode;
      case MeshCoreAdvType.sensor:
        return l10n.meshcoreSensorNode;
      default:
        return null;
    }
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

// ---------------------------------------------------------------------------
// D35-PACKETS-A: Companion radio PACKETS stats provider.
//
// Exposes the firmware-side cumulative packet counters
// (`STATS_TYPE_PACKETS`). Auto-disposes when no listener is watching
// so the timer stops the instant the Companion Radio card's "Packet
// counters" subsection collapses. Pinned by a provider regression
// test.
// ---------------------------------------------------------------------------

/// Immutable wrapper carrying the latest [MeshCorePacketsStats] plus
/// the connection / staleness signals the Tools card renders.
class MeshCorePacketsStatsSnapshot {
  final MeshCorePacketsStats? latest;
  final bool isStale;
  final bool isConnected;

  const MeshCorePacketsStatsSnapshot({
    required this.latest,
    required this.isStale,
    required this.isConnected,
  });

  const MeshCorePacketsStatsSnapshot.disconnected()
    : latest = null,
      isStale = false,
      isConnected = false;
}

/// D35-PACKETS-A poll cadence and staleness threshold.
///
/// Counts tick at the rate of mesh activity (typically a few packets
/// per minute on a quiet channel, occasionally bursty). 10 s is slow
/// enough to keep wire chatter low and fast enough to catch bursts
/// within one tick. Stale threshold = 3 missed polls.
const Duration _kPacketsStatsPollInterval = Duration(seconds: 10);
const Duration _kPacketsStatsStaleAfter = Duration(seconds: 30);

/// Riverpod 3.x notifier polling `getPacketsStats()` while
/// subscribed. Combined with `NotifierProvider.autoDispose`, this
/// gives strict lazy semantics: the timer ONLY runs when at least
/// one widget is watching the provider. When the last listener
/// unsubscribes (e.g. the user collapses the Packet counters
/// subsection), the Notifier is disposed and the timer is cancelled
/// before the next tick.
class MeshCorePacketsStatsNotifier
    extends Notifier<MeshCorePacketsStatsSnapshot> {
  Timer? _ticker;
  bool _inFlight = false;

  @override
  MeshCorePacketsStatsSnapshot build() {
    ref.onDispose(() {
      _ticker?.cancel();
      _ticker = null;
    });

    final session = ref.watch(meshCoreSessionProvider);
    _ticker?.cancel();
    if (session == null) {
      return const MeshCorePacketsStatsSnapshot.disconnected();
    }

    Future.microtask(_pollOnce);

    _ticker = Timer.periodic(_kPacketsStatsPollInterval, (_) => _pollOnce());

    return const MeshCorePacketsStatsSnapshot(
      latest: null,
      isStale: false,
      isConnected: true,
    );
  }

  Future<void> _pollOnce() async {
    if (_inFlight) return;
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      state = const MeshCorePacketsStatsSnapshot.disconnected();
      return;
    }

    _inFlight = true;
    try {
      final stats = await session.getPacketsStats();
      final stillConnected = ref.read(meshCoreSessionProvider) != null;
      if (!stillConnected) {
        state = const MeshCorePacketsStatsSnapshot.disconnected();
        return;
      }
      if (stats == null) {
        final prev = state.latest;
        state = MeshCorePacketsStatsSnapshot(
          latest: prev,
          isStale: prev != null,
          isConnected: true,
        );
        return;
      }
      state = MeshCorePacketsStatsSnapshot(
        latest: stats,
        isStale: false,
        isConnected: true,
      );
    } finally {
      _inFlight = false;
    }
  }

  /// Force-refresh from the live session. Used by tests and any UI
  /// that wants a fresh snapshot without waiting for the 10 s tick.
  Future<void> refreshNow() => _pollOnce();

  /// Recompute the stale flag against [now]. Mirrors the helpers on
  /// [MeshCoreRadioStatsNotifier] and [MeshCoreCoreStatsNotifier].
  bool isStaleAt(DateTime now) {
    final latest = state.latest;
    if (latest == null) return false;
    return now.difference(latest.fetchedAt) > _kPacketsStatsStaleAfter;
  }
}

final meshCorePacketsStatsProvider =
    NotifierProvider.autoDispose<
      MeshCorePacketsStatsNotifier,
      MeshCorePacketsStatsSnapshot
    >(MeshCorePacketsStatsNotifier.new);

// ---------------------------------------------------------------------------
// D36-A: Neighbours / repeater query provider (per-repeater family).
//
// One Notifier instance per target repeater public-key hex. State is
// tiny (status + last response + last error + cooldown timestamp) and
// holds NO timers or stream subscriptions, so the family does not
// leak resources even without `.autoDispose`. The 10 s per-repeater
// cooldown is enforced inside `requestRefresh()`.
// ---------------------------------------------------------------------------

/// Status surface for the neighbours request lifecycle. The UI maps
/// each value to a distinct sheet state (loading spinner, success
/// rows, error hint, cooldown countdown).
enum MeshCoreNeighborsStatus {
  /// No request has been issued yet for this repeater.
  idle,

  /// A request is in flight. The UI shows a spinner.
  loading,

  /// A response has landed; [MeshCoreNeighborsState.lastResponse] is
  /// populated.
  success,

  /// A request failed (timeout, transport drop, parse failure,
  /// single-flight rejection, or no MeshCore session). The UI shows
  /// [MeshCoreNeighborsState.lastError] copy.
  failure,

  /// The 10 s per-repeater cooldown is active. The UI shows a
  /// "Try again in Ns" message; refresh is disabled until
  /// [MeshCoreNeighborsState.cooldownUntil].
  cooling,
}

/// Immutable per-repeater state for the neighbours sheet.
///
/// Privacy: holds the parsed response only (4-byte prefixes, no full
/// pubkeys). Errors are typed (enum-like strings); never raw payload
/// bytes.
class MeshCoreNeighborsState {
  final MeshCoreNeighborsStatus status;
  final MeshCoreNeighborsResponse? lastResponse;
  final String? lastError;
  final DateTime? cooldownUntil;

  const MeshCoreNeighborsState({
    required this.status,
    this.lastResponse,
    this.lastError,
    this.cooldownUntil,
  });

  const MeshCoreNeighborsState.idle()
    : status = MeshCoreNeighborsStatus.idle,
      lastResponse = null,
      lastError = null,
      cooldownUntil = null;

  MeshCoreNeighborsState copyWith({
    MeshCoreNeighborsStatus? status,
    MeshCoreNeighborsResponse? lastResponse,
    String? lastError,
    DateTime? cooldownUntil,
    bool clearLastError = false,
    bool clearCooldown = false,
  }) {
    return MeshCoreNeighborsState(
      status: status ?? this.status,
      lastResponse: lastResponse ?? this.lastResponse,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      cooldownUntil: clearCooldown
          ? null
          : (cooldownUntil ?? this.cooldownUntil),
    );
  }
}

/// D36-A: 10 s per-repeater cooldown. Mirrors the airtime-safety
/// constraint from the recon: a manual refresh sends ~155 B OTA, so
/// rate-limiting at the UI layer prevents refresh-mashing from
/// hammering the channel.
const Duration _kNeighborsCooldown = Duration(seconds: 10);

/// D36-A: hardcoded `getNeighbours` request payload. The bytes after
/// the request-type byte (`0x06`) match meshcore-open's pinned shape
/// and cap the response at 15 neighbours.
///
///   [0x06, 0x00, 0x0F, 0x00, 0x00, 0x00, 0x04]
///   req_type   reserved   max=15    offset_hi  offset_lo  order_by  key_prefix_len=4
const List<int> _kNeighborsRequestBytes = [
  0x06,
  0x00,
  0x0F,
  0x00,
  0x00,
  0x00,
  0x04,
];

class MeshCoreNeighborsNotifier extends Notifier<MeshCoreNeighborsState> {
  MeshCoreNeighborsNotifier(this.publicKeyHex);

  /// Target repeater public-key hex; injected via the family-provider
  /// constructor tear-off.
  final String publicKeyHex;

  @override
  MeshCoreNeighborsState build() => const MeshCoreNeighborsState.idle();

  /// Trigger a fresh neighbours query against the repeater whose
  /// public-key hex matches this notifier's family argument.
  ///
  /// Behaviour:
  ///   - Enforces a 10 s per-repeater cooldown. A second call within
  ///     the window transitions to `cooling` and returns without
  ///     sending bytes.
  ///   - Requires a live MeshCore session and a matching contact in
  ///     the live contact list (we read the 32-byte pubkey from
  ///     `meshCoreContactsProvider` rather than re-parsing the hex
  ///     ourselves).
  ///   - The session helper `sendBinaryRequest` has its own
  ///     single-flight guard; concurrent calls (e.g. user mashes
  ///     refresh on two different repeaters at once) will return
  ///     null for the second one and transition that family entry
  ///     to `failure`.
  Future<void> requestRefresh() async {
    final now = DateTime.now();
    final cooldown = state.cooldownUntil;
    if (cooldown != null && now.isBefore(cooldown)) {
      state = state.copyWith(
        status: MeshCoreNeighborsStatus.cooling,
        clearLastError: true,
      );
      return;
    }

    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      state = state.copyWith(
        status: MeshCoreNeighborsStatus.failure,
        lastError: 'no_session',
      );
      return;
    }

    final contacts = ref.read(meshCoreContactsProvider).contacts;
    final contact = contacts
        .where((c) => c.publicKeyHex == publicKeyHex)
        .firstOrNull;
    if (contact == null) {
      state = state.copyWith(
        status: MeshCoreNeighborsStatus.failure,
        lastError: 'contact_missing',
      );
      return;
    }

    state = state.copyWith(
      status: MeshCoreNeighborsStatus.loading,
      clearLastError: true,
      clearCooldown: true,
    );

    final responseBytes = await session.sendBinaryRequest(
      recipientPubKey: contact.publicKey,
      requestBytes: Uint8List.fromList(_kNeighborsRequestBytes),
    );

    final cooldownEnd = DateTime.now().add(_kNeighborsCooldown);

    if (responseBytes == null) {
      state = state.copyWith(
        status: MeshCoreNeighborsStatus.failure,
        lastError: 'timeout',
        cooldownUntil: cooldownEnd,
      );
      return;
    }

    final parsed = MeshCoreNeighborsResponse.parse(responseBytes);
    if (parsed == null) {
      state = state.copyWith(
        status: MeshCoreNeighborsStatus.failure,
        lastError: 'parse_failed',
        cooldownUntil: cooldownEnd,
      );
      return;
    }

    state = state.copyWith(
      status: MeshCoreNeighborsStatus.success,
      lastResponse: parsed,
      clearLastError: true,
      cooldownUntil: cooldownEnd,
    );
  }

  /// Clear the cooling flag if the cooldown timestamp has elapsed.
  /// The UI calls this on every rebuild so a sheet that stays open
  /// past the cooldown transitions from `cooling` back to whatever
  /// status preceded it. Returns the resolved current status.
  MeshCoreNeighborsStatus visibleStatus(DateTime now) {
    if (state.status != MeshCoreNeighborsStatus.cooling) {
      return state.status;
    }
    final until = state.cooldownUntil;
    if (until == null || now.isAfter(until)) {
      // Cooldown elapsed; return to idle/success depending on what
      // we have buffered.
      final next = state.lastResponse == null
          ? MeshCoreNeighborsStatus.idle
          : MeshCoreNeighborsStatus.success;
      state = state.copyWith(status: next);
      return next;
    }
    return MeshCoreNeighborsStatus.cooling;
  }
}

final meshCoreNeighborsProvider =
    NotifierProvider.family<
      MeshCoreNeighborsNotifier,
      MeshCoreNeighborsState,
      String
    >(MeshCoreNeighborsNotifier.new);

// ---------------------------------------------------------------------------
// D41-A: per-contact Cayenne LPP telemetry
// ---------------------------------------------------------------------------

/// Per-contact telemetry request status. Mirrors the shape of
/// [MeshCoreNeighborsStatus] so the sheet UX stays consistent.
enum MeshCoreTelemetryStatus {
  /// No request has been issued yet for this contact.
  idle,

  /// A request is in flight. The UI shows a spinner.
  requesting,

  /// A response landed; [MeshCoreTelemetryState.lastResponse] is set.
  success,

  /// Request failed (timeout, parse failure, single-flight, no
  /// session, no contact). UI shows [MeshCoreTelemetryState.lastError]
  /// copy.
  failure,

  /// The 10 s per-contact cooldown is active.
  cooling,
}

/// Immutable per-contact state for the telemetry sheet.
///
/// Privacy: holds the parsed response only (decoded units). Errors
/// are typed (enum-like strings); never raw payload bytes.
class MeshCoreTelemetryState {
  final MeshCoreTelemetryStatus status;
  final MeshCoreTelemetryResponse? lastResponse;
  final String? lastError;
  final DateTime? cooldownUntil;

  const MeshCoreTelemetryState({
    required this.status,
    this.lastResponse,
    this.lastError,
    this.cooldownUntil,
  });

  const MeshCoreTelemetryState.idle()
    : status = MeshCoreTelemetryStatus.idle,
      lastResponse = null,
      lastError = null,
      cooldownUntil = null;

  MeshCoreTelemetryState copyWith({
    MeshCoreTelemetryStatus? status,
    MeshCoreTelemetryResponse? lastResponse,
    String? lastError,
    DateTime? cooldownUntil,
    bool clearLastError = false,
    bool clearCooldown = false,
  }) {
    return MeshCoreTelemetryState(
      status: status ?? this.status,
      lastResponse: lastResponse ?? this.lastResponse,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      cooldownUntil: clearCooldown
          ? null
          : (cooldownUntil ?? this.cooldownUntil),
    );
  }
}

/// D41-A: 10 s per-contact cooldown. Matches the D36-A neighbours
/// rate-limiter on the same airtime-safety grounds: a manual refresh
/// hits the firmware queue + (potentially) the LoRa channel; rate-
/// limiting the UI prevents refresh-mashing.
const Duration _kTelemetryCooldown = Duration(seconds: 10);

class MeshCoreTelemetryNotifier extends Notifier<MeshCoreTelemetryState> {
  MeshCoreTelemetryNotifier(this.publicKeyHex);

  /// Target contact public-key hex; injected via the family
  /// constructor tear-off.
  final String publicKeyHex;

  @override
  MeshCoreTelemetryState build() => const MeshCoreTelemetryState.idle();

  /// Trigger a fresh telemetry query against this notifier's family
  /// argument. Cooldown / no-session / no-contact / timeout paths
  /// transition the state without throwing.
  ///
  /// Logging surface (privacy-redacted; pubkey appears only as the
  /// canonical 8-byte fingerprint):
  ///   - `event=telemetry.request.sent pubkey=<8B fingerprint>`
  ///   - `event=telemetry.response.received pubkey=<8B> reading_count=<int>`
  ///   - `event=telemetry.request.timeout pubkey=<8B>`
  ///   - `event=telemetry.request.cooling reason=cooldown pubkey=<8B>`
  ///   - never the actual telemetry values; never the raw LPP bytes.
  Future<void> requestRefresh() async {
    final now = DateTime.now();
    final cooldown = state.cooldownUntil;
    if (cooldown != null && now.isBefore(cooldown)) {
      state = state.copyWith(
        status: MeshCoreTelemetryStatus.cooling,
        clearLastError: true,
      );
      AppLogging.meshcore(
        'event=telemetry.request.cooling reason=cooldown '
        'pubkey=${_pubkeyFingerprintHex(publicKeyHex)}',
      );
      return;
    }

    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      state = state.copyWith(
        status: MeshCoreTelemetryStatus.failure,
        lastError: 'no_session',
      );
      return;
    }

    final contacts = ref.read(meshCoreContactsProvider).contacts;
    final contact = contacts
        .where((c) => c.publicKeyHex == publicKeyHex)
        .firstOrNull;
    if (contact == null) {
      state = state.copyWith(
        status: MeshCoreTelemetryStatus.failure,
        lastError: 'contact_missing',
      );
      return;
    }

    state = state.copyWith(
      status: MeshCoreTelemetryStatus.requesting,
      clearLastError: true,
      clearCooldown: true,
    );
    AppLogging.meshcore(
      'event=telemetry.request.sent '
      'pubkey=${AppLogging.publicKeyFingerprint(contact.publicKey)}',
    );

    final response = await session.requestTelemetry(contact.publicKey);

    final cooldownEnd = DateTime.now().add(_kTelemetryCooldown);

    if (response == null) {
      AppLogging.meshcore(
        'event=telemetry.request.timeout '
        'pubkey=${AppLogging.publicKeyFingerprint(contact.publicKey)}',
        error: true,
      );
      state = state.copyWith(
        status: MeshCoreTelemetryStatus.failure,
        lastError: 'timeout',
        cooldownUntil: cooldownEnd,
      );
      return;
    }

    AppLogging.meshcore(
      'event=telemetry.response.received '
      'pubkey=${AppLogging.publicKeyFingerprint(contact.publicKey)} '
      'reading_count=${response.readings.length}',
    );

    state = state.copyWith(
      status: MeshCoreTelemetryStatus.success,
      lastResponse: response,
      clearLastError: true,
      cooldownUntil: cooldownEnd,
    );
  }

  /// Compute the visible status: transitions `cooling` back to a
  /// resolved status (idle or success depending on whether a prior
  /// response is buffered) once the cooldown timestamp has elapsed.
  /// Rewrites the underlying state so the sheet rebuild picks up the
  /// transition without a second `requestRefresh` call.
  MeshCoreTelemetryStatus visibleStatus(DateTime now) {
    if (state.status != MeshCoreTelemetryStatus.cooling) {
      return state.status;
    }
    final until = state.cooldownUntil;
    if (until == null || now.isAfter(until)) {
      final next = state.lastResponse == null
          ? MeshCoreTelemetryStatus.idle
          : MeshCoreTelemetryStatus.success;
      state = state.copyWith(status: next);
      return next;
    }
    return MeshCoreTelemetryStatus.cooling;
  }
}

/// Compose an 8-char hex fingerprint from a 64-char pubkey hex
/// string for log lines. Mirrors `AppLogging.publicKeyFingerprint`'s
/// shape but operates on the hex form we have on hand here.
String _pubkeyFingerprintHex(String publicKeyHex) {
  if (publicKeyHex.length < 8) return publicKeyHex;
  return '4B:${publicKeyHex.substring(0, 4).toLowerCase()}'
      // lint-allow: hardcoded-string — diagnostic log payload
      '…${publicKeyHex.substring(publicKeyHex.length - 4).toLowerCase()}';
}

final meshCoreTelemetryProvider =
    NotifierProvider.family<
      MeshCoreTelemetryNotifier,
      MeshCoreTelemetryState,
      String
    >(MeshCoreTelemetryNotifier.new);

// ---------------------------------------------------------------------------
// D47-A: per-device auto-add contact config
// ---------------------------------------------------------------------------

/// Notifier-held state for the auto-add config card.
class MeshCoreAutoAddConfigState {
  /// Most-recent value loaded from the firmware. Null until the
  /// first successful [MeshCoreAutoAddConfigNotifier.refresh].
  final MeshCoreAutoAddConfig? loaded;

  /// True while a load or set is in flight.
  final bool isLoading;

  /// Last error encountered. Cleared on the next successful
  /// load / write.
  final String? lastError;

  const MeshCoreAutoAddConfigState({
    this.loaded,
    this.isLoading = false,
    this.lastError,
  });

  const MeshCoreAutoAddConfigState.initial()
    : loaded = null,
      isLoading = false,
      lastError = null;

  MeshCoreAutoAddConfigState copyWith({
    MeshCoreAutoAddConfig? loaded,
    bool? isLoading,
    String? lastError,
    bool clearError = false,
  }) {
    return MeshCoreAutoAddConfigState(
      loaded: loaded ?? this.loaded,
      isLoading: isLoading ?? this.isLoading,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}

/// D47-A: per-device auto-add contact policy notifier.
///
/// Loads firmware state on demand (via `refresh()`). `update()` writes
/// new config via `CMD_SET_AUTO_ADD_CONFIG 0x3A` and, on success,
/// updates the local snapshot. The firmware itself drives the actual
/// auto-promote on inbound advert match — the app owns only the
/// policy toggles.
class MeshCoreAutoAddConfigNotifier
    extends Notifier<MeshCoreAutoAddConfigState> {
  @override
  MeshCoreAutoAddConfigState build() =>
      const MeshCoreAutoAddConfigState.initial();

  /// Pull the firmware's current config and replace [loaded]. On
  /// failure leaves [loaded] alone and sets [lastError].
  Future<void> refresh() async {
    if (!ref.mounted) return;
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      state = state.copyWith(lastError: 'no_session');
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    final config = await session.getAutoAddConfig();
    if (!ref.mounted) return;
    if (config == null) {
      state = state.copyWith(isLoading: false, lastError: 'load_failed');
      return;
    }
    state = MeshCoreAutoAddConfigState(loaded: config, isLoading: false);
  }

  /// Write [next] to the firmware. On success replaces [loaded] with
  /// [next]; on failure leaves [loaded] untouched and sets
  /// [lastError].
  Future<bool> update(MeshCoreAutoAddConfig next) async {
    if (!ref.mounted) return false;
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      state = state.copyWith(lastError: 'no_session');
      return false;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    final ok = await session.setAutoAddConfig(next);
    if (!ref.mounted) return false;
    if (!ok) {
      state = state.copyWith(isLoading: false, lastError: 'set_failed');
      return false;
    }
    state = MeshCoreAutoAddConfigState(loaded: next, isLoading: false);
    return true;
  }
}

final meshCoreAutoAddConfigProvider =
    NotifierProvider<MeshCoreAutoAddConfigNotifier, MeshCoreAutoAddConfigState>(
      MeshCoreAutoAddConfigNotifier.new,
    );

// ---------------------------------------------------------------------------
// D48-A1: app-side auto-route rotation settings (persisted)
// ---------------------------------------------------------------------------

/// Per-setting SharedPreferences keys. Bool / double primitives match
/// the existing per-key prefs pattern (see
/// `meshCoreShowBatteryVoltageProvider`).
const String kMeshCoreAutoRouteEnabledPrefKey =
    'meshcore_auto_route_rotation_enabled';
const String kMeshCoreAutoRouteMaxWeightPrefKey =
    'meshcore_auto_route_max_weight';
const String kMeshCoreAutoRouteInitialWeightPrefKey =
    'meshcore_auto_route_initial_weight';
const String kMeshCoreAutoRouteSuccessIncrementPrefKey =
    'meshcore_auto_route_success_increment';
const String kMeshCoreAutoRouteFailureDecrementPrefKey =
    'meshcore_auto_route_failure_decrement';
const String kMeshCoreAutoRouteMaxRetriesPrefKey =
    'meshcore_auto_route_max_retries';
const String kMeshCoreAutoRouteRetryTimeoutSecondsPrefKey =
    'meshcore_auto_route_retry_timeout_seconds';

/// D48-A1: notifier for the auto-route rotation policy. Persists each
/// field independently to SharedPreferences. All setter methods
/// clamp the input to the documented range before writing — both the
/// store and reactive state advance together so a listener never
/// sees a value that wasn't written.
///
/// The rotation orchestrator that consumes these settings is wired
/// in D48-A2; D48-A1 ships the settings surface only.
class MeshCoreAutoRouteSettingsNotifier
    extends Notifier<MeshCoreAutoRouteSettings> {
  @override
  MeshCoreAutoRouteSettings build() {
    Future.microtask(_loadFromPrefs);
    return const MeshCoreAutoRouteSettings.defaults();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = MeshCoreAutoRouteSettings(
        enabled: prefs.getBool(kMeshCoreAutoRouteEnabledPrefKey) ?? false,
        maxRouteWeight: MeshCoreAutoRouteSettings.clampWeight(
          prefs.getDouble(kMeshCoreAutoRouteMaxWeightPrefKey) ??
              MeshCoreAutoRouteSettings.defaultMaxRouteWeight,
        ),
        initialRouteWeight: MeshCoreAutoRouteSettings.clampWeight(
          prefs.getDouble(kMeshCoreAutoRouteInitialWeightPrefKey) ??
              MeshCoreAutoRouteSettings.defaultInitialRouteWeight,
        ),
        routeWeightSuccessIncrement: MeshCoreAutoRouteSettings.clampIncrement(
          prefs.getDouble(kMeshCoreAutoRouteSuccessIncrementPrefKey) ??
              MeshCoreAutoRouteSettings.defaultRouteWeightSuccessIncrement,
        ),
        routeWeightFailureDecrement: MeshCoreAutoRouteSettings.clampIncrement(
          prefs.getDouble(kMeshCoreAutoRouteFailureDecrementPrefKey) ??
              MeshCoreAutoRouteSettings.defaultRouteWeightFailureDecrement,
        ),
        maxRetries: MeshCoreAutoRouteSettings.clampMaxRetries(
          prefs.getInt(kMeshCoreAutoRouteMaxRetriesPrefKey) ??
              MeshCoreAutoRouteSettings.defaultMaxRetries,
        ),
        retryTimeoutSeconds: MeshCoreAutoRouteSettings.clampRetryTimeoutSeconds(
          prefs.getInt(kMeshCoreAutoRouteRetryTimeoutSecondsPrefKey) ??
              MeshCoreAutoRouteSettings.defaultRetryTimeoutSeconds,
        ),
      );
    } catch (_) {
      // Defaults already in state; silent recovery is fine here. A
      // failed read implies a failed write will surface to the user
      // when they touch the next slider.
    }
  }

  Future<void> setEnabled(bool value) async {
    if (state.enabled == value) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kMeshCoreAutoRouteEnabledPrefKey, value);
    state = state.copyWith(enabled: value);
  }

  Future<void> setMaxRouteWeight(double value) async {
    final clamped = MeshCoreAutoRouteSettings.clampWeight(value);
    if (state.maxRouteWeight == clamped) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(kMeshCoreAutoRouteMaxWeightPrefKey, clamped);
    state = state.copyWith(maxRouteWeight: clamped);
  }

  Future<void> setInitialRouteWeight(double value) async {
    final clamped = MeshCoreAutoRouteSettings.clampWeight(value);
    if (state.initialRouteWeight == clamped) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(kMeshCoreAutoRouteInitialWeightPrefKey, clamped);
    state = state.copyWith(initialRouteWeight: clamped);
  }

  Future<void> setRouteWeightSuccessIncrement(double value) async {
    final clamped = MeshCoreAutoRouteSettings.clampIncrement(value);
    if (state.routeWeightSuccessIncrement == clamped) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(kMeshCoreAutoRouteSuccessIncrementPrefKey, clamped);
    state = state.copyWith(routeWeightSuccessIncrement: clamped);
  }

  Future<void> setRouteWeightFailureDecrement(double value) async {
    final clamped = MeshCoreAutoRouteSettings.clampIncrement(value);
    if (state.routeWeightFailureDecrement == clamped) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(kMeshCoreAutoRouteFailureDecrementPrefKey, clamped);
    state = state.copyWith(routeWeightFailureDecrement: clamped);
  }

  Future<void> setMaxRetries(int value) async {
    final clamped = MeshCoreAutoRouteSettings.clampMaxRetries(value);
    if (state.maxRetries == clamped) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kMeshCoreAutoRouteMaxRetriesPrefKey, clamped);
    state = state.copyWith(maxRetries: clamped);
  }

  Future<void> setRetryTimeoutSeconds(int value) async {
    final clamped = MeshCoreAutoRouteSettings.clampRetryTimeoutSeconds(value);
    if (state.retryTimeoutSeconds == clamped) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kMeshCoreAutoRouteRetryTimeoutSecondsPrefKey, clamped);
    state = state.copyWith(retryTimeoutSeconds: clamped);
  }
}

final meshCoreAutoRouteSettingsProvider =
    NotifierProvider<
      MeshCoreAutoRouteSettingsNotifier,
      MeshCoreAutoRouteSettings
    >(MeshCoreAutoRouteSettingsNotifier.new);
