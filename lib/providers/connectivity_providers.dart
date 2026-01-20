import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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
    _periodicTimer = Timer.periodic(_periodicCheckInterval, (_) => checkNow());

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
  StreamSubscription<ConnectivityResult>? _sub;
  Timer? _periodicTimer;

  DateTime? _lastReachabilityCheck;
  bool? _lastReachable;

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
      final platformResult = await _connectivity.checkConnectivity();
      final platformConnected = platformResult != ConnectivityResult.none;
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

  Future<void> _onPlatformChanged(ConnectivityResult result) async {
    // Trigger immediate check on platform changes
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
