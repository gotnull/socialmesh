import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../models/social.dart';
import '../services/protocol/protocol_service.dart';
import '../services/signal_service.dart';
import 'app_providers.dart';
import 'auth_providers.dart';
import 'profile_providers.dart';

// =============================================================================
// SERVICE PROVIDER
// =============================================================================

/// Provider for the SignalService singleton.
final signalServiceProvider = Provider<SignalService>((ref) {
  return SignalService();
});

// =============================================================================
// SIGNAL FEED STATE
// =============================================================================

/// State for the presence feed (local signals view).
class SignalFeedState {
  final List<Post> signals;
  final bool isLoading;
  final String? error;
  final DateTime? lastRefresh;

  const SignalFeedState({
    this.signals = const [],
    this.isLoading = false,
    this.error,
    this.lastRefresh,
  });

  SignalFeedState copyWith({
    List<Post>? signals,
    bool? isLoading,
    String? error,
    DateTime? lastRefresh,
  }) {
    return SignalFeedState(
      signals: signals ?? this.signals,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastRefresh: lastRefresh ?? this.lastRefresh,
    );
  }
}

// =============================================================================
// SIGNAL FEED NOTIFIER
// =============================================================================

/// Notifier for managing the local signal feed (Presence Feed).
///
/// Signals are displayed locally-first, sorted by:
/// 1. Proximity (if mesh node data available)
/// 2. Expiry time (ascending - expiring soon first)
/// 3. Creation time (descending - newest first)
///
/// Handles background cleanup on app resume and periodic intervals.
/// Subscribes to ProtocolService.signalStream for incoming mesh signals.
class SignalFeedNotifier extends Notifier<SignalFeedState>
    with WidgetsBindingObserver {
  Timer? _cleanupTimer;
  Timer? _refreshTimer;
  Timer? _countdownTimer;
  StreamSubscription<MeshSignalPacket>? _signalSubscription;
  bool _isObserving = false;

  @override
  SignalFeedState build() {
    // Start periodic cleanup when notifier is created
    _startCleanupTimer();
    _startAutoRefresh();
    _startCountdownTimer();
    _startLifecycleObserver();
    _wireMeshIntegration();

    // Cleanup when disposed
    ref.onDispose(() {
      _cleanupTimer?.cancel();
      _refreshTimer?.cancel();
      _countdownTimer?.cancel();
      _signalSubscription?.cancel();
      _stopLifecycleObserver();
    });

    // Load signals immediately
    Future.microtask(() => refresh());

    return const SignalFeedState(isLoading: true);
  }

  /// Wire up mesh broadcast callback and incoming signal subscription.
  void _wireMeshIntegration() {
    final service = ref.read(signalServiceProvider);
    final protocol = ref.read(protocolServiceProvider);

    // Set up broadcast callback (includes signalId for deterministic matching)
    service.onBroadcastSignal =
        (
          String signalId,
          String content,
          int ttlMinutes,
          double? latitude,
          double? longitude,
        ) async {
          try {
            final packetId = await protocol.sendSignal(
              signalId: signalId,
              content: content,
              ttlMinutes: ttlMinutes,
              latitude: latitude,
              longitude: longitude,
            );
            return packetId;
          } catch (e) {
            AppLogging.signals('Mesh broadcast failed: $e');
            return null;
          }
        };

    // Subscribe to incoming mesh signals
    _signalSubscription?.cancel();
    _signalSubscription = protocol.signalStream.listen(
      _handleIncomingMeshSignal,
      onError: (e) {
        AppLogging.signals('Signal stream error: $e');
      },
    );

    AppLogging.signals('Mesh integration wired');
  }

  /// Handle incoming mesh signal packet from ProtocolService.
  Future<void> _handleIncomingMeshSignal(MeshSignalPacket packet) async {
    AppLogging.signals(
      'Processing incoming mesh signal from !${packet.senderNodeId.toRadixString(16)}'
      '${packet.isLegacy ? ' (LEGACY - no id)' : ' (id=${packet.signalId})'}',
    );

    PostLocation? location;
    if (packet.latitude != null && packet.longitude != null) {
      location = PostLocation(
        latitude: packet.latitude!,
        longitude: packet.longitude!,
      );
    }

    await addMeshSignal(
      content: packet.content,
      senderNodeId: packet.senderNodeId,
      signalId: packet.signalId, // null for legacy packets
      ttlMinutes: packet.ttlMinutes,
      location: location,
    );
  }

  void _startLifecycleObserver() {
    if (!_isObserving) {
      WidgetsBinding.instance.addObserver(this);
      _isObserving = true;
      AppLogging.signals('Started app lifecycle observer');
    }
  }

  void _stopLifecycleObserver() {
    if (_isObserving) {
      WidgetsBinding.instance.removeObserver(this);
      _isObserving = false;
      AppLogging.signals('Stopped app lifecycle observer');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppLogging.signals('App resumed - running signal cleanup');
      _cleanupExpired();
      refresh(silent: true);
    }
  }

  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    // Run cleanup every minute
    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      AppLogging.signals('Periodic cleanup triggered');
      _cleanupExpired();
    });
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      refresh(silent: true);
    });
  }

  /// Global countdown timer - ticks every second.
  /// Removes expired signals and notifies UI for countdown updates.
  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tickCountdown();
    });
  }

  /// Called every second to update countdown display and remove expired signals.
  void _tickCountdown() {
    final now = DateTime.now();
    final currentSignals = state.signals;

    // Check if any signals have expired
    final expiredIds = <String>[];
    for (final signal in currentSignals) {
      if (signal.expiresAt != null && signal.expiresAt!.isBefore(now)) {
        expiredIds.add(signal.id);
      }
    }

    // Remove expired signals from state
    if (expiredIds.isNotEmpty) {
      final remaining = currentSignals
          .where((s) => !expiredIds.contains(s.id))
          .toList();
      state = state.copyWith(signals: remaining);
      AppLogging.signals(
        'Countdown tick: removed ${expiredIds.length} expired signals',
      );
    }

    // Force UI rebuild for countdown updates
    // This triggers widget rebuilds to recompute remaining time from expiresAt
    state = state.copyWith(lastRefresh: now);
  }

  /// Refresh the signal feed from local storage.
  Future<void> refresh({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final service = ref.read(signalServiceProvider);
      await service.init();
      final signals = await service.getActiveSignals();

      // Sort signals
      final sorted = _sortSignals(signals);

      AppLogging.signals('Feed refreshed: ${sorted.length} active signals');

      state = SignalFeedState(
        signals: sorted,
        isLoading: false,
        lastRefresh: DateTime.now(),
      );
    } catch (e) {
      AppLogging.signals('Feed refresh error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Sort signals by proximity, expiry, and creation time.
  List<Post> _sortSignals(List<Post> signals) {
    // Get current node position for proximity sorting
    final myNodeNum = ref.read(myNodeNumProvider);

    return List<Post>.from(signals)..sort((a, b) {
      // 1. Proximity sort (if we have mesh node data)
      if (myNodeNum != null && a.meshNodeId != null && b.meshNodeId != null) {
        // Same node = highest priority
        final aIsMe = a.meshNodeId == myNodeNum;
        final bIsMe = b.meshNodeId == myNodeNum;
        if (aIsMe && !bIsMe) return -1;
        if (!aIsMe && bIsMe) return 1;

        // TODO: Add hop count comparison when available
      }

      // 2. Expiry sort (expiring soon first)
      if (a.expiresAt != null && b.expiresAt != null) {
        final expiryCompare = a.expiresAt!.compareTo(b.expiresAt!);
        if (expiryCompare != 0) return expiryCompare;
      }

      // 3. Creation time (newest first)
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  /// Remove expired signals from state.
  Future<void> _cleanupExpired() async {
    final service = ref.read(signalServiceProvider);
    final removed = await service.cleanupExpiredSignals();

    if (removed > 0) {
      AppLogging.signals('Expired $removed signals, refreshing feed');
      await refresh(silent: true);
    }
  }

  /// Add a new signal to the feed.
  Future<Post?> createSignal({
    required String content,
    int ttlMinutes = SignalTTL.defaultTTL,
    PostLocation? location,
    String? imageLocalPath,
  }) async {
    final service = ref.read(signalServiceProvider);
    final myNodeNum = ref.read(myNodeNumProvider);
    final profile = ref.read(userProfileProvider).value;

    AppLogging.signals(
      'Creating new signal: ttl=${ttlMinutes}m, hasLocation=${location != null}, '
      'hasImage=${imageLocalPath != null}',
    );

    try {
      final signal = await service.createSignal(
        content: content,
        ttlMinutes: ttlMinutes,
        location: location,
        meshNodeId: myNodeNum,
        imageLocalPath: imageLocalPath,
        authorSnapshot: profile != null
            ? PostAuthorSnapshot(
                displayName: profile.displayName,
                avatarUrl: profile.avatarUrl,
                isVerified: profile.isVerified,
              )
            : null,
      );

      // Add to state immediately
      state = state.copyWith(signals: [signal, ...state.signals]);

      AppLogging.signals('Signal created successfully: ${signal.id}');
      return signal;
    } catch (e) {
      AppLogging.signals('Failed to create signal: $e');
      return null;
    }
  }

  /// Add a signal received from mesh.
  /// signalId is null for legacy packets (pre-deterministic-matching).
  Future<void> addMeshSignal({
    required String content,
    required int senderNodeId,
    String? signalId,
    int ttlMinutes = SignalTTL.defaultTTL,
    PostLocation? location,
  }) async {
    final service = ref.read(signalServiceProvider);

    AppLogging.signals(
      'Processing mesh signal from node !${senderNodeId.toRadixString(16)}'
      '${signalId != null ? ' (id=$signalId)' : ' (legacy)'}',
    );

    try {
      final signal = await service.createSignalFromMesh(
        content: content,
        senderNodeId: senderNodeId,
        signalId: signalId,
        ttlMinutes: ttlMinutes,
        location: location,
      );

      // If null, it was a duplicate
      if (signal == null) {
        AppLogging.signals('Mesh signal was duplicate, ignoring');
        return;
      }

      // Add to state immediately
      final signals = [signal, ...state.signals];
      state = state.copyWith(signals: _sortSignals(signals));

      AppLogging.signals('Mesh signal added to feed: ${signal.id}');
    } catch (e) {
      AppLogging.signals('Failed to add mesh signal: $e');
    }
  }

  /// Delete a signal.
  Future<void> deleteSignal(String signalId) async {
    final service = ref.read(signalServiceProvider);

    AppLogging.signals('Deleting signal: $signalId');

    try {
      await service.deleteSignal(signalId);
      state = state.copyWith(
        signals: state.signals.where((s) => s.id != signalId).toList(),
      );
      AppLogging.signals('Signal deleted successfully');
    } catch (e) {
      AppLogging.signals('Failed to delete signal: $e');
    }
  }

  /// Upload an image for a signal.
  Future<String?> uploadImage(String signalId, String localPath) async {
    final service = ref.read(signalServiceProvider);

    AppLogging.signals('Uploading image for signal: $signalId');

    try {
      final url = await service.uploadSignalImage(signalId, localPath);
      if (url != null) {
        // Update state with new image URL
        final signals = state.signals.map((s) {
          if (s.id == signalId) {
            return s.copyWith(mediaUrls: [url], imageState: ImageState.cloud);
          }
          return s;
        }).toList();

        state = state.copyWith(signals: signals);
        AppLogging.signals('Image uploaded successfully: $url');
      }
      return url;
    } catch (e) {
      AppLogging.signals('Failed to upload image: $e');
      return null;
    }
  }

  /// Check if image is unlocked for a signal.
  bool isImageUnlocked(Post signal) {
    final service = ref.read(signalServiceProvider);
    return service.isImageUnlocked(signal);
  }
}

/// Provider for the signal feed.
final signalFeedProvider =
    NotifierProvider<SignalFeedNotifier, SignalFeedState>(
      SignalFeedNotifier.new,
    );

// =============================================================================
// HELPER PROVIDERS
// =============================================================================

/// Provider for active (non-expired) signal count.
final activeSignalCountProvider = Provider<int>((ref) {
  final feedState = ref.watch(signalFeedProvider);
  return feedState.signals.length;
});

/// Provider for signals from a specific node.
final signalsFromNodeProvider = Provider.family<List<Post>, int>((ref, nodeId) {
  final feedState = ref.watch(signalFeedProvider);
  return feedState.signals.where((s) => s.meshNodeId == nodeId).toList();
});

/// Provider for my own signals.
final mySignalsProvider = Provider<List<Post>>((ref) {
  final feedState = ref.watch(signalFeedProvider);
  final currentUser = ref.watch(currentUserProvider);

  if (currentUser == null) return [];

  return feedState.signals.where((s) => s.authorId == currentUser.uid).toList();
});

// =============================================================================
// CREATE SIGNAL STATE
// =============================================================================

/// State for signal creation.
class CreateSignalState {
  final String content;
  final int ttlMinutes;
  final PostLocation? location;
  final String? imageLocalPath;
  final bool isSubmitting;
  final String? error;

  const CreateSignalState({
    this.content = '',
    this.ttlMinutes = SignalTTL.defaultTTL,
    this.location,
    this.imageLocalPath,
    this.isSubmitting = false,
    this.error,
  });

  bool get canSubmit =>
      content.trim().isNotEmpty && !isSubmitting && content.length <= 280;

  CreateSignalState copyWith({
    String? content,
    int? ttlMinutes,
    PostLocation? location,
    String? imageLocalPath,
    bool? isSubmitting,
    String? error,
    bool clearLocation = false,
    bool clearImage = false,
  }) {
    return CreateSignalState(
      content: content ?? this.content,
      ttlMinutes: ttlMinutes ?? this.ttlMinutes,
      location: clearLocation ? null : (location ?? this.location),
      imageLocalPath: clearImage
          ? null
          : (imageLocalPath ?? this.imageLocalPath),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
    );
  }
}

/// Notifier for signal creation.
class CreateSignalNotifier extends Notifier<CreateSignalState> {
  @override
  CreateSignalState build() => const CreateSignalState();

  void setContent(String content) {
    state = state.copyWith(content: content);
  }

  void setTTL(int minutes) {
    state = state.copyWith(ttlMinutes: minutes);
  }

  void setLocation(PostLocation? location) {
    if (location == null) {
      state = state.copyWith(clearLocation: true);
    } else {
      state = state.copyWith(location: location);
    }
  }

  void setImage(String? localPath) {
    if (localPath == null) {
      state = state.copyWith(clearImage: true);
    } else {
      state = state.copyWith(imageLocalPath: localPath);
    }
  }

  Future<Post?> submit() async {
    if (!state.canSubmit) return null;

    state = state.copyWith(isSubmitting: true, error: null);

    try {
      final feedNotifier = ref.read(signalFeedProvider.notifier);
      final signal = await feedNotifier.createSignal(
        content: state.content.trim(),
        ttlMinutes: state.ttlMinutes,
        location: state.location,
        imageLocalPath: state.imageLocalPath,
      );

      if (signal != null) {
        // Reset state after successful creation
        state = const CreateSignalState();
      }

      return signal;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return null;
    }
  }

  void reset() {
    state = const CreateSignalState();
  }
}

/// Provider for signal creation state.
final createSignalProvider =
    NotifierProvider<CreateSignalNotifier, CreateSignalState>(
      CreateSignalNotifier.new,
    );
