// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Dart side of the iOS WatchConnectivity bridge.
//
// Drives the lifecycle of the native bridge through a single
// MethodChannel (name pinned in [kWatchCompanionChannelName]). The
// iOS bridge is a transport only; this Dart class is the policy
// owner — it decides when to activate the session, when to push a
// snapshot, and how to route an inbound intent.
//
// This file is public (lives at the package root, not under
// _internal/) because it has no protocol-specific imports. It depends
// only on the public watch-companion service and feature-flag
// providers. The protocol-isolation tripwire stays green.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:socialmesh/core/logging.dart';

import 'models/watch_companion_intent.dart';
import 'models/watch_companion_intent_result.dart';
import 'models/watch_companion_snapshot.dart';
import 'watch_companion_feature_flags.dart';
import 'watch_companion_providers.dart';
import 'watch_companion_service.dart';

/// Public MethodChannel name shared with Swift
/// (`ios/Runner/WatchCompanion/WatchCompanionBridge.swift`). Must
/// match the Swift constant `WatchCompanionWire.channelName`.
const String kWatchCompanionChannelName = 'com.socialmesh/watch_companion';

/// Methods Dart invokes on the native side. The Swift bridge's
/// `handle(call:result:)` dispatches against these strings.
class _NativeMethods {
  _NativeMethods._();
  static const String activateSession = 'activateSession';
  static const String deactivateSession = 'deactivateSession';
  static const String pushSnapshot = 'pushSnapshot';
}

/// Methods the native side invokes on this Dart bridge. Returned as
/// the [MethodCall.method] string in [MethodChannel.setMethodCallHandler].
class _NativeCallbacks {
  _NativeCallbacks._();
  static const String onIntent = 'onIntent';
  static const String onSessionStateChanged = 'onSessionStateChanged';
}

/// Diagnostic-reason strings the Dart bridge synthesises when an
/// inbound intent cannot reach the service (e.g. malformed payload).
/// These complement the application-level rejection vocabulary owned
/// by `WatchSendFacade` and the bridge-level vocabulary in
/// `WatchCompanionCodec.swift`.
class _BridgeDiagnostics {
  _BridgeDiagnostics._();
  static const String invalidIntentPayload = 'invalid_intent_payload';
  static const String dispatchException = 'bridge_dispatch_exception';
}

/// Orchestrator for the iOS WatchConnectivity bridge. Construct via
/// [watchCompanionChannelBridgeProvider] so lifecycle is owned by the
/// ProviderScope, then call [start] once at app boot.
/// Per-dependency reader functions. The bridge only needs two values
/// from Riverpod (the feature flags + the service); injecting them as
/// closures keeps the constructor free of Riverpod's internal
/// `ProviderListenable<T>` type, so tests can build a bridge against
/// a `ProviderContainer` without touching Riverpod's framework types.
typedef WatchCompanionFlagsReader = WatchCompanionFeatureFlags Function();
typedef WatchCompanionServiceReader = WatchCompanionService Function();

class WatchCompanionChannelBridge {
  WatchCompanionChannelBridge({
    required WatchCompanionFlagsReader readFlags,
    required WatchCompanionServiceReader readService,
    MethodChannel? channel,
  }) : _readFlags = readFlags,
       _readService = readService,
       _channel = channel ?? const MethodChannel(kWatchCompanionChannelName);

  final WatchCompanionFlagsReader _readFlags;
  final WatchCompanionServiceReader _readService;
  final MethodChannel _channel;

  bool _started = false;
  bool _activated = false;
  StreamSubscription<WatchCompanionSnapshot>? _snapshotSub;

  /// Wire the inbound-call handler, then ask Swift to activate the
  /// WCSession (subject to the feature flag), then start streaming
  /// snapshots onto the bridge. Safe to call once; further calls
  /// are no-ops so an unintended double-start at boot is harmless.
  Future<void> start() async {
    if (_started) {
      AppLogging.watchCompanion('bridge.start ignored: already started');
      return;
    }
    _started = true;

    _channel.setMethodCallHandler(_onNativeCall);
    AppLogging.watchCompanion(
      'bridge.start: channel=$kWatchCompanionChannelName handler installed',
    );

    final WatchCompanionFeatureFlags flags = _readFlags();
    if (!flags.enabled) {
      AppLogging.watchCompanion(
        'bridge.start: WATCH_COMPANION_ENABLED=false; not activating WCSession',
      );
      return;
    }

    try {
      final bool? activated = await _channel.invokeMethod<bool>(
        _NativeMethods.activateSession,
      );
      _activated = activated ?? false;
      AppLogging.watchCompanion(
        'bridge.start: native activate returned $activated',
      );
    } on PlatformException catch (e) {
      AppLogging.watchCompanion(
        'bridge.start: native activate failed code=${e.code} msg=${e.message}',
      );
      return;
    } catch (e) {
      AppLogging.watchCompanion('bridge.start: native activate threw: $e');
      return;
    }

    if (!_activated) {
      AppLogging.watchCompanion(
        'bridge.start: WCSession unsupported on this device, '
        'snapshot stream not attached',
      );
      return;
    }

    // Push the most recent snapshot synchronously so the Watch can
    // render something on session activation without waiting for the
    // next composer tick.
    final service = _readService();
    final cached = service.latestSnapshot;
    if (cached != null) {
      await _pushSnapshot(cached);
    }

    _snapshotSub = service.snapshots.listen(
      _pushSnapshot,
      onError: (Object e, StackTrace st) {
        AppLogging.watchCompanion('bridge: snapshot stream error: $e');
      },
    );
    AppLogging.watchCompanion('bridge.start: subscribed to snapshot stream');
  }

  /// Tear down the bridge. Cancels the snapshot subscription, clears
  /// the inbound-call handler, and asks Swift to drop its WCSession
  /// delegate so a subsequent [start] from a hot-restart re-wires
  /// cleanly.
  Future<void> dispose() async {
    if (!_started) return;
    _started = false;

    await _snapshotSub?.cancel();
    _snapshotSub = null;
    _channel.setMethodCallHandler(null);

    if (_activated) {
      try {
        await _channel.invokeMethod<bool>(_NativeMethods.deactivateSession);
      } catch (e) {
        AppLogging.watchCompanion('bridge.dispose: deactivate threw: $e');
      }
      _activated = false;
    }
    AppLogging.watchCompanion('bridge.dispose: shut down');
  }

  Future<void> _pushSnapshot(WatchCompanionSnapshot snap) async {
    try {
      await _channel.invokeMethod<bool>(
        _NativeMethods.pushSnapshot,
        snap.toJson(),
      );
      AppLogging.watchCompanion(
        'bridge: snapshot pushed (gen=${snap.generatedAt} '
        'status=${snap.connection.status.name})',
      );
    } on PlatformException catch (e) {
      AppLogging.watchCompanion(
        'bridge: pushSnapshot failed code=${e.code} msg=${e.message}',
      );
    } catch (e) {
      AppLogging.watchCompanion('bridge: pushSnapshot threw: $e');
    }
  }

  Future<dynamic> _onNativeCall(MethodCall call) async {
    switch (call.method) {
      case _NativeCallbacks.onIntent:
        return _handleNativeIntent(call.arguments);

      case _NativeCallbacks.onSessionStateChanged:
        AppLogging.watchCompanion(
          'bridge: native session state changed: ${call.arguments}',
        );
        return null;

      default:
        AppLogging.watchCompanion(
          'bridge: unknown native method "${call.method}" (ignored)',
        );
        return null;
    }
  }

  Future<Map<String, dynamic>> _handleNativeIntent(Object? arguments) async {
    Map<String, dynamic> json;
    try {
      json = _coerceJson(arguments);
    } catch (e) {
      AppLogging.watchCompanion(
        'bridge: malformed intent arguments: $e (raw=$arguments)',
      );
      return _synthesiseReject(
        requestId: _extractRequestIdLoose(arguments),
        diagnosticReason: _BridgeDiagnostics.invalidIntentPayload,
      );
    }

    final WatchCompanionIntent intent;
    try {
      intent = WatchCompanionIntent.fromJson(json);
    } catch (e) {
      AppLogging.watchCompanion('bridge: intent decode failed: $e');
      return _synthesiseReject(
        requestId: _extractRequestIdLoose(json),
        diagnosticReason: _BridgeDiagnostics.invalidIntentPayload,
      );
    }

    try {
      final service = _readService();
      final result = await service.handleIntent(intent);
      return result.toJson();
    } catch (e) {
      AppLogging.watchCompanion(
        'bridge: service.handleIntent threw: $e req=${intent.requestId}',
      );
      return _synthesiseReject(
        requestId: intent.requestId,
        diagnosticReason: _BridgeDiagnostics.dispatchException,
      );
    }
  }

  /// MethodChannel marshals dictionaries into `Map<Object?, Object?>` on
  /// the receiving side. Coerce to `Map<String, dynamic>` so the codec
  /// can read it; throw on any non-map input so the caller can synth a
  /// stable rejection.
  Map<String, dynamic> _coerceJson(Object? raw) {
    if (raw is Map) {
      return _deepCoerce(raw) as Map<String, dynamic>;
    }
    throw FormatException('expected Map, got ${raw.runtimeType}');
  }

  /// Recursive coercion: every nested Map becomes `Map<String, dynamic>`
  /// and every nested List becomes `List<dynamic>`. The
  /// `StandardMethodCodec` decodes to `Map<Object?, Object?>` /
  /// `List<Object?>` at every level; the Dart codecs in `models/`
  /// expect tighter types, so the bridge has to normalise the whole
  /// tree before handing off to `WatchCompanionIntent.fromJson`.
  Object? _deepCoerce(Object? value) {
    if (value is Map) {
      return value.map((key, v) => MapEntry(key.toString(), _deepCoerce(v)));
    }
    if (value is List) {
      return value.map(_deepCoerce).toList();
    }
    return value;
  }

  String _extractRequestIdLoose(Object? raw) {
    if (raw is Map) {
      final v = raw['requestId'];
      if (v is String) return v;
    }
    return 'unknown';
  }

  Map<String, dynamic> _synthesiseReject({
    required String requestId,
    required String diagnosticReason,
  }) {
    return WatchCompanionIntentResult(
      requestId: requestId,
      accepted: false,
      diagnosticReason: diagnosticReason,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    ).toJson();
  }
}
