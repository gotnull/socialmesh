// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'app_lifecycle_provider.dart';
import 'auth_providers.dart';
import 'connection_providers.dart';
import '../core/logging.dart';

/// Connectivity state summarizing platform connection and reachability
class ConnectivityStatus {
  final bool platformConnected; // connectivity_plus reports non-none
  final bool reachable; // actual internet reachable via ping
  final String reason; // short reason text

  const ConnectivityStatus({
    required this.platformConnected,
    required this.reachable,
    this.reason = '',
  });

  bool get online => platformConnected && reachable;
}

class ConnectivityNotifier extends Notifier<ConnectivityStatus> {
  @override
  ConnectivityStatus build() {
    // Initial state
    _connectivity = Connectivity();
    _sub = _connectivity.onConnectivityChanged.listen(_onPlatformChanged);
    _startPeriodicTimer();

    // Pause/resume the periodic reachability ping when the app is
    // backgrounded/foregrounded. Pinging google.com every 10 seconds in the
    // background wakes the network stack and drains battery for zero benefit.
    ref.listen<bool>(appLifecycleProvider, (previous, isForeground) {
      if (isForeground) {
        _startPeriodicTimer();
        // Run an immediate check so the UI has fresh data on resume.
        checkNow();
        AppLogging.connection(
          '🔋 Connectivity: periodic timer resumed (app foregrounded)',
        );
      } else {
        _stopPeriodicTimer();
        AppLogging.connection(
          '🔋 Connectivity: periodic timer paused (app backgrounded)',
        );
      }
    });

    // Register cleanup
    ref.onDispose(() {
      _sub?.cancel();
      _periodicTimer?.cancel();
    });

    // Initial check (fire-and-forget)
    checkNow();

    return const ConnectivityStatus(
      platformConnected: false,
      reachable: false,
      reason: 'init',
    );
  }

  final Duration _reachabilityTimeout = const Duration(seconds: 2);
  final Duration _cacheDuration = const Duration(seconds: 3);
  final Duration _periodicCheckInterval = const Duration(seconds: 10);

  late final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _periodicTimer;

  DateTime? _lastReachabilityCheck;
  bool? _lastReachable;

  void _startPeriodicTimer() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(_periodicCheckInterval, (_) => checkNow());
  }

  void _stopPeriodicTimer() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  // For tests, allow forcing the state
  void setOnline(bool online, {String reason = 'forced'}) {
    state = ConnectivityStatus(
      platformConnected: online,
      reachable: online,
      reason: reason,
    );
    AppLogging.connection(
      '🌐 Connectivity: status changed -> ${online ? 'online' : 'offline'}, canUseCloudFeatures=${state.online}, reason=$reason',
    );
  }

  Future<void> checkNow() async {
    try {
      final platformResults = await _connectivity.checkConnectivity();
      final platformConnected =
          !platformResults.contains(ConnectivityResult.none) &&
          platformResults.isNotEmpty;
      final now = DateTime.now();

      bool reachable = false;
      String reason = 'no-check';

      if (!platformConnected) {
        _lastReachabilityCheck = now;
        _lastReachable = false;
        state = ConnectivityStatus(
          platformConnected: false,
          reachable: false,
          reason: 'platform_disconnected',
        );
        AppLogging.connection(
          '🌐 Connectivity: status changed -> offline, canUseCloudFeatures=${state.online}, reason=platform_disconnected',
        );
        return;
      }

      // Use cached result when fresh
      if (_lastReachabilityCheck != null &&
          _lastReachabilityCheck!.add(_cacheDuration).isAfter(now) &&
          _lastReachable != null) {
        reachable = _lastReachable!;
        reason = 'cache';
      } else {
        // Perform lightweight reachability check
        try {
          reachable = await _pingUrl(
            'https://www.google.com/generate_204',
            timeout: _reachabilityTimeout,
          );
          reason = 'ping';
        } catch (e) {
          reachable = false;
          reason = 'ping_error';
        }
        _lastReachabilityCheck = now;
        _lastReachable = reachable;
      }

      state = ConnectivityStatus(
        platformConnected: true,
        reachable: reachable,
        reason: reason,
      );
      AppLogging.connection(
        '🌐 Connectivity: status changed -> ${state.online ? 'online' : 'offline'}, canUseCloudFeatures=${state.online}, reason=$reason',
      );
    } catch (e) {
      state = ConnectivityStatus(
        platformConnected: false,
        reachable: false,
        reason: 'error',
      );
      AppLogging.connection(
        '🌐 Connectivity: status changed -> offline, canUseCloudFeatures=false, reason=error:$e',
      );
    }
  }

  Future<void> _onPlatformChanged(List<ConnectivityResult> results) async {
    // Invalidate cache so checkNow() does a fresh reachability ping
    _lastReachabilityCheck = null;
    _lastReachable = null;

    final platformConnected =
        !results.contains(ConnectivityResult.none) && results.isNotEmpty;

    if (!platformConnected) {
      // Immediately set offline — don't wait for a ping that will fail anyway
      state = const ConnectivityStatus(
        platformConnected: false,
        reachable: false,
        reason: 'platform_disconnected',
      );
      AppLogging.connection(
        '🌐 Connectivity: platform change -> offline (airplane/wifi off), '
        'results=$results',
      );
      return;
    }

    // Platform says connected — do a fresh reachability check
    AppLogging.connection(
      '🌐 Connectivity: platform change -> connected, '
      'verifying reachability, results=$results',
    );
    await checkNow();
  }

  Future<bool> _pingUrl(String url, {required Duration timeout}) async {
    final uri = Uri.parse(url);
    final client = HttpClient();
    client.connectionTimeout = timeout;
    try {
      final request = await client.getUrl(uri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      return response.statusCode >= 200 && response.statusCode < 400;
    } finally {
      client.close(force: true);
    }
  }
}

final connectivityStatusProvider =
    NotifierProvider<ConnectivityNotifier, ConnectivityStatus>(
      ConnectivityNotifier.new,
    );

final isOnlineProvider = Provider<bool>((ref) {
  final status = ref.watch(connectivityStatusProvider);
  return status.online;
});

/// Whether cloud features can be used: requires platform network + signed-in user
final canUseCloudFeaturesProvider = Provider<bool>((ref) {
  final online = ref.watch(isOnlineProvider);
  final signedIn = ref.watch(isSignedInProvider);
  return online && signedIn;
});

/// Aggregated connectivity state for signals (mesh + cloud).
class SignalConnectivityState {
  final bool hasInternet;
  final bool isAuthenticated;
  final bool isBleConnected;

  const SignalConnectivityState({
    required this.hasInternet,
    required this.isAuthenticated,
    required this.isBleConnected,
  });

  bool get canUseCloud => hasInternet && isAuthenticated;
  bool get canUseMesh => isBleConnected;

  String? get cloudDisabledReason {
    if (!hasInternet) return 'No internet connection';
    if (!isAuthenticated) return 'Sign in required for cloud features';
    return null;
  }

  String? get meshDisabledReason {
    if (!isBleConnected) return 'Device not connected';
    return null;
  }
}

final signalConnectivityProvider = Provider<SignalConnectivityState>((ref) {
  final online = ref.watch(isOnlineProvider);
  final signedIn = ref.watch(isSignedInProvider);
  final bleConnected = ref.watch(isDeviceConnectedProvider);
  return SignalConnectivityState(
    hasInternet: online,
    isAuthenticated: signedIn,
    isBleConnected: bleConnected,
  );
});
