// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter/foundation.dart' show protected;
import 'package:geolocator/geolocator.dart';

import '../../core/logging.dart';
import '../protocol/protocol_service.dart';
import 'phone_position_governor.dart';

/// Service that provides phone GPS location and can send it to the mesh.
/// Phone GPS sharing is opt-in only and disabled by default for privacy.
///
/// All position publishes are routed through [PhonePositionGovernor] which
/// enforces minimum time interval, minimum distance, and the
/// `providePhoneLocation` opt-in gate. This prevents burst-on-resume,
/// stationary spam, and duplicate publishes from multiple trigger paths.
///
/// The [isLocationSharingEnabled] callback is checked by both the governor
/// and by [startLocationUpdates] as an early-exit guard. When it returns
/// `false`, no POSITION_APP packets are emitted and no GPS radio wake occurs.
class LocationService {
  /// Governor that enforces rate limiting, distance gating, and opt-in
  /// checks for all phone GPS position publishes.
  final PhonePositionGovernor _governor;

  /// Callback that returns whether the user has opted in to sharing
  /// their phone GPS position with the mesh. Evaluated on every tick.
  /// When `null`, defaults to `false` (safe — no emission).
  final bool Function()? isLocationSharingEnabled;

  Timer? _locationTimer;
  Position? _lastPosition;
  bool _isRunning = false;

  /// Consecutive GPS failure count for exponential backoff.
  /// Reset to 0 on any successful position fix.
  int _consecutiveFailures = 0;

  /// Maximum number of consecutive failures before we stop attempting
  /// GPS reads until a manual request or restart succeeds.
  static const int maxConsecutiveFailures = 10;

  /// Timer tick counter for backoff modulo calculation.
  int _tickCount = 0;

  /// Whether periodic location updates are currently active.
  bool get isRunning => _isRunning;

  /// Exposed for testing: how many consecutive GPS failures have occurred.
  int get consecutiveFailures => _consecutiveFailures;

  /// Reset failure counter. Called internally on successful GPS fix.
  /// Exposed as protected for testable subclasses that override
  /// [getCurrentPosition].
  @protected
  void resetConsecutiveFailures() => _consecutiveFailures = 0;

  /// Increment failure counter. Called internally on GPS failure.
  /// Exposed as protected for testable subclasses that override
  /// [getCurrentPosition].
  @protected
  void incrementConsecutiveFailures() => _consecutiveFailures++;

  /// The governor instance, exposed for provider wiring and testing.
  PhonePositionGovernor get governor => _governor;

  /// Guards against concurrent permission requests which cause
  /// "A request for location permissions is already running" crashes.
  Completer<bool>? _permissionCompleter;

  /// How often to poll the phone GPS and attempt a publish (in seconds).
  ///
  /// The governor enforces the actual minimum publish interval (300s for
  /// automatic, 60s for manual). This timer cadence controls how often
  /// we *check* whether a publish is warranted — the governor will deny
  /// most ticks for stationary users, preventing airtime waste.
  static const int positionUpdateIntervalSeconds = 30;

  LocationService(
    ProtocolService protocolService, {
    this.isLocationSharingEnabled,
    PhonePositionGovernor? governor,
  }) : _governor =
           governor ??
           PhonePositionGovernor(
             protocolService,
             isLocationSharingEnabled: isLocationSharingEnabled,
           );

  /// Current position
  Position? get lastPosition => _lastPosition;

  /// Check if location services are enabled and we have permission.
  ///
  /// Serializes permission requests so that only one
  /// [Geolocator.requestPermission] call is in flight at a time.
  Future<bool> checkPermissions() async {
    // If a permission request is already running, wait for it.
    if (_permissionCompleter != null) {
      AppLogging.nodes(
        'Permission request already in progress, waiting for result',
      );
      return _permissionCompleter!.future;
    }

    _permissionCompleter = Completer<bool>();

    try {
      final result = await _checkPermissionsInternal();
      _permissionCompleter!.complete(result);
      return result;
    } catch (e) {
      _permissionCompleter!.completeError(e);
      rethrow;
    } finally {
      _permissionCompleter = null;
    }
  }

  Future<bool> _checkPermissionsInternal() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      AppLogging.nodes('Location services are disabled');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        AppLogging.nodes('Location permission denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      AppLogging.nodes('Location permission permanently denied');
      return false;
    }

    return true;
  }

  /// Get current position once.
  ///
  /// This does NOT check [isLocationSharingEnabled] — it only reads
  /// the phone GPS. Callers that need a position for display (map,
  /// incident form, etc.) can use this freely. The gate is enforced
  /// only on the *send-to-mesh* path inside the governor.
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _lastPosition = position;
      resetConsecutiveFailures();
      AppLogging.debug(
        '📍 Got phone GPS position: ${position.latitude}, ${position.longitude}',
      );
      return position;
    } catch (e) {
      incrementConsecutiveFailures();
      AppLogging.nodes(
        'Error getting location (failure $_consecutiveFailures): $e',
      );
      return null;
    }
  }

  /// Start periodic location updates to the mesh.
  ///
  /// The timer fires every [positionUpdateIntervalSeconds] seconds.
  /// On each tick, the [PhonePositionGovernor] decides whether to publish
  /// based on:
  /// - `providePhoneLocation` opt-in
  /// - minimum time interval (300s auto, 60s manual)
  /// - minimum distance moved (150m for auto)
  ///
  /// Unlike the previous implementation, there is NO immediate send on
  /// start. The first tick fires after [positionUpdateIntervalSeconds],
  /// and the governor decides whether to allow it. This eliminates the
  /// burst-on-resume pattern where stop → start → immediate send created
  /// duplicate publishes.
  Future<void> startLocationUpdates() async {
    if (_isRunning) return;

    // Early exit: don't request GPS permissions or start the timer when
    // the user has not opted in. This avoids waking the GPS radio and
    // draining battery for ticks that would be no-ops anyway.
    // Resume/reconnect paths call this unconditionally, so the guard
    // must live here as well as inside the governor.
    if (!(isLocationSharingEnabled?.call() ?? false)) {
      AppLogging.nodes(
        'Skipping location updates — providePhoneLocation is disabled',
      );
      return;
    }

    final hasPermission = await checkPermissions();
    if (!hasPermission) {
      AppLogging.nodes('Cannot start location updates - no permission');
      return;
    }

    _isRunning = true;
    AppLogging.nodes('Starting periodic location updates');

    // Submit an initial tick through the governor. The governor enforces
    // its own time and distance gates, so this will only publish if
    // enough time has elapsed since the last publish (e.g., after a
    // genuine 5-minute background pause). This replaces the old
    // unconditional immediate send that caused burst-on-resume.
    await _governedTick(PositionPublishReason.lifecycleResume);

    // Then poll every N seconds — governor decides on each tick.
    _locationTimer = Timer.periodic(
      Duration(seconds: positionUpdateIntervalSeconds),
      (_) => _governedTick(PositionPublishReason.timerTick),
    );
  }

  /// Stop periodic location updates.
  void stopLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _isRunning = false;
    _tickCount = 0;
    AppLogging.nodes('Stopped location updates');
  }

  /// Send position once (for manual requests from dashboard quick actions).
  ///
  /// Routed through the governor with [PositionPublishReason.manualAction].
  /// The governor enforces a 60-second minimum interval for manual actions
  /// (shorter than the 300s auto interval) and bypasses the distance gate
  /// so the user's explicit intent is respected.
  ///
  /// Returns the [PublishDecision] so callers can show appropriate feedback.
  Future<PublishDecision> sendPositionOnce() async {
    return _governedTick(PositionPublishReason.manualAction);
  }

  /// Publish with a specific reason (for widget actions, commands, etc.).
  ///
  /// Fetches the current GPS position and routes through the governor.
  /// Returns [PublishDecision.blockedNoPosition] if no GPS fix is available.
  Future<PublishDecision> publishWithReason(
    PositionPublishReason reason,
  ) async {
    return _governedTick(reason);
  }

  /// Publish a known position with a specific reason (for callers that
  /// already have coordinates, e.g., SharePositionCommand).
  ///
  /// Routes through the governor with the provided coordinates.
  Future<PublishDecision> publishKnownPosition({
    required double latitude,
    required double longitude,
    int? altitude,
    required PositionPublishReason reason,
  }) async {
    return _governor.requestPublish(
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      reason: reason,
    );
  }

  /// Dispose resources.
  void dispose() {
    stopLocationUpdates();
  }

  // -----------------------------------------------------------------------
  // Private
  // -----------------------------------------------------------------------

  /// Fetch current GPS position and route through the governor.
  ///
  /// This is the single internal path for all publish attempts that need
  /// to read the phone GPS first. The governor enforces all gates.
  ///
  /// When GPS fails repeatedly, an exponential backoff skips timer ticks
  /// to avoid waking the GPS radio every 30s when there is no fix
  /// (e.g. deep indoors). Manual actions bypass the backoff so the user
  /// can always force a retry.
  Future<PublishDecision> _governedTick(PositionPublishReason reason) async {
    // Quick gate: if sharing is disabled, skip GPS wake entirely.
    if (!(isLocationSharingEnabled?.call() ?? false)) {
      return PublishDecision.blockedDisabled;
    }

    // Exponential backoff for timer ticks after repeated GPS failures.
    // Manual actions and lifecycle resume always attempt a fresh read so
    // the user (or an app resume) can break out of the backoff cycle.
    if (reason == PositionPublishReason.timerTick && _consecutiveFailures > 0) {
      // Skip this tick unless it aligns with the backoff schedule.
      // Backoff: skip 1, 2, 4, 8... ticks (capped at maxConsecutiveFailures).
      // Example at 30s interval: after 3 failures, only attempt every 4th
      // tick (120s); after 5 failures, every 16th tick (480s).
      final skipCount = 1 << _consecutiveFailures.clamp(0, 6); // max 64 ticks
      // Use a simple modulo on consecutive failures to determine skip.
      // _consecutiveFailures doubles as both the backoff exponent and
      // the tick counter since it only increments on actual GPS attempts.
      if (_consecutiveFailures >= maxConsecutiveFailures) {
        AppLogging.nodes(
          'GPS backoff: skipping tick ($_consecutiveFailures failures, '
          'max reached — use manual action to retry)',
        );
        return PublishDecision.blockedNoPosition;
      }
      // Simple check: let through every skipCount-th timer tick.
      // We use _tickCount to avoid coupling to _consecutiveFailures.
      _tickCount++;
      if (_tickCount % skipCount != 0) {
        return PublishDecision.blockedNoPosition;
      }
    }

    try {
      final position = await getCurrentPosition();
      if (position == null) {
        AppLogging.nodes('No position available for governor tick');
        return PublishDecision.blockedNoPosition;
      }

      // `return await` is required (not `return`): `return aFuture` from
      // an async function chains the rejection past the surrounding catch,
      // so transport errors (TransportSendError, async broken-pipe
      // SocketException) escape as unhandled zone errors to
      // PlatformDispatcher.onError. Crashlytics 7894c78d.
      return await _governor.requestPublish(
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude.toInt(),
        reason: reason,
      );
    } catch (e) {
      AppLogging.nodes('Error in governed position tick: $e');
      return PublishDecision.blockedNoPosition;
    }
  }
}
