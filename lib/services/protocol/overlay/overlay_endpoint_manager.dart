// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Single authority for overlay identity + peer endpoint binding.
///
/// Combines three responsibilities that must not be scattered across
/// the codebase per the P3 locked architectural rules:
///   1. Local Ed25519 keypair lifecycle (via [OverlayIdentityKeypair]).
///   2. Local endpoint ID derivation (via [OverlayEndpointId]).
///   3. Peer endpoint resolution, persistence, and deterministic
///      tie-break (§24.1.4 of the spec).
///
/// Consumers never touch [OverlayEndpointStore] or
/// [OverlayIdentityKeypair] directly — they call into the manager,
/// which serialises all mutations via a single async mutex so concurrent
/// observations never race against each other or against `openLocal`.
library;

import 'dart:async';
import 'dart:typed_data';

import '../../../core/logging.dart';
import 'overlay_endpoint_id.dart';
import 'overlay_endpoint_record.dart';
import 'overlay_endpoint_store.dart';
import 'overlay_identity_keypair.dart';

/// The single-writer manager for overlay identity and peer endpoints.
class OverlayEndpointManager {
  final OverlayIdentityKeypair _keypair;
  final OverlayEndpointStore _store;
  final int Function() _clock;

  Future<void> _mutex = Future<void>.value();
  bool _disposed = false;

  Uint8List? _cachedLocalEndpointId;
  Uint8List? _cachedLocalPersonaHint;

  /// Construct a manager. The caller owns the lifetimes of [_keypair]
  /// and [_store] (and is responsible for disposing them after the
  /// manager is disposed).
  OverlayEndpointManager({
    required this._keypair,
    required this._store,
    int Function()? clock,
  }) : _clock = clock ?? _defaultClock;

  static int _defaultClock() => DateTime.now().millisecondsSinceEpoch;

  /// Ensure the local keypair exists (generate on first run), then
  /// derive and cache the local endpoint ID and persona hint.
  Future<void> ensureInitialized() async {
    if (_cachedLocalEndpointId != null) return;
    await _keypair.ensureInitialized();
    final pub = _keypair.publicKey();
    _cachedLocalEndpointId = await OverlayEndpointId.deriveRoot(pub);
    _cachedLocalPersonaHint = await OverlayEndpointId.personaHint(pub);
    AppLogging.overlay(
      'endpoint manager ready endpointId=${_hex(_cachedLocalEndpointId!)}',
    );
  }

  /// 8-byte local endpoint ID (root service). Throws if not yet
  /// initialised.
  Uint8List localEndpointId() {
    final id = _cachedLocalEndpointId;
    if (id == null) {
      throw StateError(
        'OverlayEndpointManager not initialized — call ensureInitialized()',
      );
    }
    return id;
  }

  /// 8-byte local persona hint (SHA-256(pubkey)[0..7]).
  Uint8List localPersonaHint() {
    final h = _cachedLocalPersonaHint;
    if (h == null) {
      throw StateError(
        'OverlayEndpointManager not initialized — call ensureInitialized()',
      );
    }
    return h;
  }

  /// 32-byte local Ed25519 public key.
  Uint8List localPublicKey() => _keypair.publicKey();

  /// Sign [data] with the local private key.
  Future<Uint8List> sign(Uint8List data) => _keypair.sign(data);

  /// Verify [signature] over [data] by [publicKey].
  Future<bool> verify(
    Uint8List data,
    Uint8List signature,
    Uint8List publicKey,
  ) => _keypair.verify(data, signature, publicKey);

  /// Record or refresh an endpoint observation. The semantics follow
  /// §24.1.4:
  ///
  /// - A signature-verified observation always wins over observed.
  /// - A signature-verified observation of the same endpointId
  ///   refreshes `lastSeenMs`, `peerNodeNumHint`, and capability
  ///   fields.
  /// - An observed observation never downgrades an existing
  ///   signature-verified row.
  Future<OverlayEndpointRecord> recordObservation({
    required Uint8List endpointId,
    required Uint8List personaPubEd,
    int serviceId = OverlayEndpointId.rootServiceId,
    int? peerNodeNum,
    int supportedFeatures = 0,
    int? maxChunkBytes,
    int? maxResourceBytes,
    required OverlayEndpointTrustLevel trustLevel,
    required String source,
  }) {
    return _serialize(() async {
      final existing = await _store.getByEndpointId(endpointId);
      final now = _clock();

      // Never downgrade an already-verified endpoint based on a new
      // observed-only observation.
      if (existing != null &&
          existing.trustLevel == OverlayEndpointTrustLevel.signatureVerified &&
          trustLevel == OverlayEndpointTrustLevel.observed) {
        final refreshed = existing.copyWith(
          lastSeenMs: now,
          peerNodeNumHint: peerNodeNum ?? existing.peerNodeNumHint,
        );
        await _store.upsert(refreshed);
        AppLogging.overlay(
          'endpoint refresh (preserved verified) '
          'id=${_hex(endpointId)} src=$source',
        );
        return refreshed;
      }

      final personaHint = await OverlayEndpointId.personaHint(personaPubEd);
      final record = OverlayEndpointRecord(
        endpointId: endpointId,
        personaPubEd: personaPubEd,
        personaHint: personaHint,
        serviceId: serviceId,
        peerNodeNumHint: peerNodeNum ?? existing?.peerNodeNumHint,
        supportedFeatures: supportedFeatures,
        maxChunkBytes: maxChunkBytes ?? existing?.maxChunkBytes,
        maxResourceBytes: maxResourceBytes ?? existing?.maxResourceBytes,
        firstSeenMs: existing?.firstSeenMs ?? now,
        lastSeenMs: now,
        trustLevel: trustLevel,
        source: source,
      );
      await _store.upsert(record);
      AppLogging.overlay(
        'endpoint upsert id=${_hex(endpointId)} '
        'trust=${trustLevel.name} src=$source',
      );
      return record;
    });
  }

  /// Deterministic tie-break per §24.1.4. Looks up by persona hint
  /// first (if provided), then by node num.
  ///
  /// Returns `null` if no binding can be found.
  Future<OverlayEndpointRecord?> resolvePeerByHints({
    Uint8List? personaHint,
    int? peerNodeNum,
  }) async {
    if (personaHint != null) {
      final byHint = await _store.getByPersonaHint(personaHint);
      if (byHint.isNotEmpty) {
        // Prefer verified rows.
        final verified = byHint.firstWhere(
          (r) => r.trustLevel == OverlayEndpointTrustLevel.signatureVerified,
          orElse: () => byHint.first,
        );
        return verified;
      }
    }
    if (peerNodeNum != null) {
      final byNode = await _store.getByPeerNodeNum(peerNodeNum);
      if (byNode.isNotEmpty) return byNode.first;
    }
    return null;
  }

  /// Lookup by endpoint ID (primary key).
  Future<OverlayEndpointRecord?> getByEndpointId(Uint8List endpointId) {
    return _store.getByEndpointId(endpointId);
  }

  /// Diagnostic: number of persisted endpoint rows.
  Future<int> endpointCount() => _store.count();

  /// Dispose the manager. Does NOT close the underlying store or
  /// keypair (those belong to their own providers).
  void dispose() {
    _disposed = true;
  }

  Future<T> _serialize<T>(Future<T> Function() fn) {
    if (_disposed) {
      return Future<T>.error(
        StateError('OverlayEndpointManager has been disposed'),
      );
    }
    final prior = _mutex;
    final completer = Completer<T>();
    _mutex = prior.then((_) async {
      try {
        completer.complete(await fn());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  static String _hex(Uint8List bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
