// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D48-A3: passive path-history seeding from
// `PUSH_CODE_PATH_UPDATED 0x81`.
//
// The firmware emits 0x81 whenever it learns or refreshes a route
// to a known contact. The wire payload is `[opcode][pubkey:32]`;
// it does NOT carry the new path bytes. To retrieve them we issue
// `CMD_GET_CONTACT_BY_KEY 0x1E` for the same pubkey; the firmware
// responds with one `RESP_CODE_CONTACT 0x03` frame whose
// `pathBytes` is the freshly-learned route.
//
// This listener runs alongside `MeshCoreSendConfirmationRouter`:
// both subscribe to the same frame stream, both are owned by the
// active session, both clean up on session disposal.
//
// Side benefits beyond closing parity audit Row 30:
//   - D48-A2's auto-route orchestrator now has a path pool that
//     grows automatically when the firmware learns a route, instead
//     of waiting for the user to Trace Path manually.
//   - D42-B-A's inferred-path overlay can surface inferred paths
//     for contacts the user has never traced.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/logging.dart';
import '../../../core/meshcore_constants.dart';
import '../protocol/meshcore_frame.dart';
import '../protocol/meshcore_messages.dart';
import '../protocol/meshcore_session.dart';

/// D48-A3: per-contact callback that hands the recorded path bytes
/// (length 1..64) to the path-history notifier so it can persist to
/// SharedPreferences + reactively update consumers. Receives the
/// contact's hex-prefix-keyed history slot via the provider family.
typedef MeshCorePathRecorder =
    Future<void> Function({
      required String contactPubKeyHex,
      required Uint8List pathBytes,
    });

class MeshCorePathUpdateListener {
  MeshCorePathUpdateListener({
    required MeshCoreSession session,
    required this._recorder,
    this._getContactTimeout = const Duration(seconds: 5),
  }) : _session = session {
    _sub = session.frameStream.listen(_onFrame);
  }

  /// D48-A3 / D29-B test-only constructor: lets the test substitute
  /// the `getContactByKey` call directly so a fake session isn't
  /// needed.
  @visibleForTesting
  MeshCorePathUpdateListener.forTest({
    required Stream<MeshCoreFrame> frameStream,
    required Future<MeshCoreContactInfo?> Function({
      required Uint8List pubKey,
      required Duration timeout,
    })
    this._getContactByKey,
    required this._recorder,
    this._getContactTimeout = const Duration(seconds: 5),
  }) : _session = null {
    _sub = frameStream.listen(_onFrame);
  }

  final MeshCoreSession? _session;
  Future<MeshCoreContactInfo?> Function({
    required Uint8List pubKey,
    required Duration timeout,
  })?
  _getContactByKey;
  final MeshCorePathRecorder _recorder;
  final Duration _getContactTimeout;

  late final StreamSubscription<MeshCoreFrame> _sub;

  /// Pubkeys currently being refreshed. Suppresses duplicate
  /// in-flight `CMD_GET_CONTACT_BY_KEY` per the same key; the
  /// firmware can chatter 0x81 in bursts during a multi-hop
  /// re-route.
  final Set<String> _inFlight = <String>{};

  bool _disposed = false;

  void _onFrame(MeshCoreFrame frame) {
    if (_disposed) return;
    if (frame.command != MeshCorePushCodes.pathUpdated) return;
    // Wire: [opcode][pubkey:32]. Frame stripping has already removed
    // the opcode, so the payload must be exactly 32 bytes.
    if (frame.payload.length < meshCorePubKeySize) {
      AppLogging.meshcore(
        'event=path_update.short_payload len=${frame.payload.length}',
        error: true,
      );
      return;
    }
    final pubKey = Uint8List.fromList(
      frame.payload.sublist(0, meshCorePubKeySize),
    );
    final fingerprint = AppLogging.publicKeyFingerprint(pubKey);
    final fingerprintKey = fingerprint;

    if (_inFlight.contains(fingerprintKey)) {
      AppLogging.meshcore(
        'event=path_update.fetch.skipped reason=in_flight '
        'target=$fingerprint',
      );
      return;
    }

    _inFlight.add(fingerprintKey);
    unawaited(_refresh(pubKey, fingerprint, fingerprintKey));
  }

  Future<void> _refresh(
    Uint8List pubKey,
    String fingerprint,
    String fingerprintKey,
  ) async {
    try {
      AppLogging.meshcore(
        'event=path_update.fetch.started target=$fingerprint',
      );
      final fetcher = _getContactByKey ?? _bindSessionGet();
      final contact = await fetcher(
        pubKey: pubKey,
        timeout: _getContactTimeout,
      );
      if (contact == null) {
        AppLogging.meshcore(
          'event=path_update.fetch.miss target=$fingerprint',
          error: true,
        );
        return;
      }
      // Flood-only learned route: nothing to record.
      if (contact.pathLength <= 0 || contact.pathBytes.isEmpty) {
        AppLogging.meshcore(
          'event=path_update.fetch.flood target=$fingerprint '
          'pathLen=${contact.pathLength}',
        );
        return;
      }

      final contactHex = contact.publicKeyHex.toLowerCase();
      await _recorder(
        contactPubKeyHex: contactHex,
        pathBytes: Uint8List.fromList(contact.pathBytes),
      );
      AppLogging.meshcore(
        'event=path_update.recorded target=$fingerprint '
        'pathLen=${contact.pathLength}',
      );
    } catch (e) {
      AppLogging.meshcore(
        'event=path_update.fetch.failed target=$fingerprint '
        'reason=${e.runtimeType}',
        error: true,
      );
    } finally {
      _inFlight.remove(fingerprintKey);
    }
  }

  Future<MeshCoreContactInfo?> Function({
    required Uint8List pubKey,
    required Duration timeout,
  })
  _bindSessionGet() {
    final session = _session!;
    Future<MeshCoreContactInfo?> bound({
      required Uint8List pubKey,
      required Duration timeout,
    }) => session.getContactByKey(pubKey: pubKey, timeout: timeout);
    _getContactByKey = bound;
    return bound;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _sub.cancel();
    _inFlight.clear();
  }
}
