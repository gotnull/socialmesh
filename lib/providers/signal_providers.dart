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
import 'connectivity_providers.dart';

// =============================================================================
// SERVICE PROVIDER
// =============================================================================

/// Provider for the SignalService singleton.
final signalServiceProvider = Provider<SignalService>((ref) {
  final dedupeStore = ref.watch(meshPacketDedupeStoreProvider);
  return SignalService(dedupeStore: dedupeStore);
});

// =============================================================================
// SIGNAL FEED STATE
// =============================================================================

/// State for the presence feed (local signals view).
/// Uses a Map keyed by signalId as the single source of truth to prevent duplicates.
class SignalFeedState {
  /// Internal map keyed by signalId - the single source of truth.
  final Map<String, Post> _signalMap;

  /// Signal IDs that are currently fading out (expired but animating).
  final Set<String> fadingSignalIds;

  final bool isLoading;
  final String? error;
  final DateTime? lastRefresh;

  SignalFeedState({
    Map<String, Post>? signalMap,
    Set<String>? fadingSignalIds,
    this.isLoading = false,
    this.error,
    this.lastRefresh,
  }) : _signalMap = signalMap ?? {},
       fadingSignalIds = fadingSignalIds ?? {};

  /// Get signals as sorted list (computed from map).
  List<Post> get signals => List<Post>.from(_signalMap.values);

  /// Check if a signal exists by ID.
  bool hasSignal(String id) => _signalMap.containsKey(id);

  /// Get a signal by ID.
  Post? getSignal(String id) => _signalMap[id];

  SignalFeedState copyWith({
    Map<String, Post>? signalMap,
    Set<String>? fadingSignalIds,
    bool? isLoading,
    String? error,
    DateTime? lastRefresh,
  }) {
    return SignalFeedState(
      signalMap: signalMap ?? Map.from(_signalMap),
      fadingSignalIds: fadingSignalIds ?? Set.from(this.fadingSignalIds),
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastRefresh: lastRefresh ?? this.lastRefresh,
    );
  }

  /// Create a new state with a signal added/updated.
  /// Uses upsert semantics - updates if exists, inserts if not.
  SignalFeedState withSignal(Post signal, {required String source}) {
    final newMap = Map<String, Post>.from(_signalMap);
    final existed = newMap.containsKey(signal.id);

    if (existed) {
      AppLogging.signals(
        '📡 Signals: ⚠️ Duplicate insert prevented for ${signal.id} (source=$source) - updating instead',
      );
    }

    newMap[signal.id] = signal;
    return copyWith(signalMap: newMap);
  }

  /// Create a new state with a signal removed.
  SignalFeedState withoutSignal(String signalId) {
    final newMap = Map<String, Post>.from(_signalMap);
    newMap.remove(signalId);
    return copyWith(signalMap: newMap);
  }

  /// Create a new state with multiple signals (replaces all).
  /// Used for refresh - builds map from list.
  SignalFeedState withSignals(List<Post> signals) {
    final newMap = <String, Post>{};
    for (final signal in signals) {
      if (newMap.containsKey(signal.id)) {
        AppLogging.signals(
          '📡 Signals: ⚠️ Duplicate in batch for ${signal.id} - keeping latest',
        );
      }
      newMap[signal.id] = signal;
    }
    return copyWith(signalMap: newMap);
  }
}

/// Sort signals for the presence feed.
List<Post> sortSignalsForFeed(List<Post> signals, int? myNodeNum) {
  return List<Post>.from(signals)..sort((a, b) {
    // 1. Same node = highest priority
    if (myNodeNum != null && a.meshNodeId != null && b.meshNodeId != null) {
      final aIsMe = a.meshNodeId == myNodeNum;
      final bIsMe = b.meshNodeId == myNodeNum;
      if (aIsMe && !bIsMe) return -1;
      if (!aIsMe && bIsMe) return 1;
    }

    // 2. hopCount sort (lower = closer, null = lowest priority)
    final aHop = a.hopCount;
    final bHop = b.hopCount;
    if (aHop != null && bHop != null) {
      if (aHop != bHop) {
        AppLogging.signals(
          '📡 Signals: Sorting by hopCount (a=$aHop, b=$bHop)',
        );
        return aHop.compareTo(bHop); // ascending
      }
    } else if (aHop != null) {
      return -1; // non-null beats null
    } else if (bHop != null) {
      return 1; // non-null beats null
    }

    // 3. Expiry sort (expiring soon first)
    if (a.expiresAt != null && b.expiresAt != null) {
      final expiryCompare = a.expiresAt!.compareTo(b.expiresAt!);
      if (expiryCompare != 0) return expiryCompare;
    }

    // 4. Creation time (newest first)
    return b.createdAt.compareTo(a.createdAt);
  });
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
  StreamSubscription<String>? _remoteDeleteSubscription;
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
      _remoteDeleteSubscription?.cancel();
      _stopLifecycleObserver();
    });

    // Load signals immediately, then retry cloud lookups
    Future.microtask(() async {
      await refresh();
      // After initial load, check for signals that need cloud data
      await _retryCloudLookups();
    });

    // Re-attach listeners on auth changes to avoid silent stalls
    ref.listen<bool>(isSignedInProvider, (previous, next) {
      final service = ref.read(signalServiceProvider);
      Future.microtask(() => service.handleAuthChanged());
    });

    // Retry cloud lookups when connectivity returns
    ref.listen<bool>(isOnlineProvider, (previous, next) {
      if (next == true) {
        Future.microtask(() => _retryCloudLookups());
      }
    });

    return SignalFeedState(isLoading: true);
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
          bool hasImage,
        ) async {
          try {
            final packetId = await protocol.sendSignal(
              signalId: signalId,
              content: content,
              ttlMinutes: ttlMinutes,
              latitude: latitude,
              longitude: longitude,
              hasImage: hasImage,
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

    // Subscribe to remote deletions (signal deleted by author on another device)
    _remoteDeleteSubscription?.cancel();
    _remoteDeleteSubscription = service.onRemoteDelete.listen(
      (signalId) {
        AppLogging.signals(
          'Remote deletion received for signal: $signalId - removing from feed',
        );
        state = state.withoutSignal(signalId);
      },
      onError: (e) {
        AppLogging.signals('Remote delete stream error: $e');
      },
    );

    AppLogging.signals('Mesh integration wired');
  }

  /// Handle incoming mesh signal packet from ProtocolService.
  Future<void> _handleIncomingMeshSignal(MeshSignalPacket packet) async {
    AppLogging.signals(
      'Processing incoming mesh signal from !${packet.senderNodeId.toRadixString(16)}'
      ' (id=${packet.signalId ?? "none"}, packetId=${packet.packetId})',
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
      signalId: packet.signalId,
      packetId: packet.packetId,
      ttlMinutes: packet.ttlMinutes,
      location: location,
      hopCount: packet.hopCount,
      hasPendingCloudImage: packet.hasImage,
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
      AppLogging.signals(
        'App resumed - running signal cleanup and cloud retry',
      );
      _cleanupExpired();
      _retryCloudLookups();
      refresh(silent: true);
    }
  }

  /// Retry cloud lookups for signals received while offline.
  Future<void> _retryCloudLookups() async {
    final service = ref.read(signalServiceProvider);
    final updatedCount = await service.retryCloudLookups();
    if (updatedCount > 0) {
      // Refresh to show newly fetched images
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
      AppLogging.signals('PERIODIC_REFRESH triggered');
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

  /// Duration for fade-out animation when signals expire.
  /// Must be longer than the snap animation duration (2500ms) to allow
  /// the snap effect to complete before the widget is unmounted.
  static const _fadeOutDuration = Duration(milliseconds: 3000);

  /// Called every second to update countdown display and remove expired signals.
  void _tickCountdown({DateTime? nowOverride}) {
    final now = nowOverride ?? DateTime.now();
    final currentSignals = state.signals;
    final currentFading = state.fadingSignalIds;

    // Check if any signals have expired that aren't already fading
    final newlyExpiredIds = <String>[];
    for (final signal in currentSignals) {
      if (signal.expiresAt != null &&
          signal.expiresAt!.isBefore(now) &&
          !currentFading.contains(signal.id)) {
        newlyExpiredIds.add(signal.id);
      }
    }

    // Start fade-out animation for newly expired signals
    if (newlyExpiredIds.isNotEmpty) {
      final newFading = Set<String>.from(currentFading)
        ..addAll(newlyExpiredIds);
      state = state.copyWith(fadingSignalIds: newFading, lastRefresh: now);

      AppLogging.signals(
        'Countdown tick: starting fade-out for ${newlyExpiredIds.length} expired signals',
      );

      // Schedule actual removal after animation completes
      for (final id in newlyExpiredIds) {
        Future.delayed(_fadeOutDuration, () {
          _completeSignalFadeOut(id);
        });
      }
    } else {
      // Just update the timestamp to trigger countdown display updates
      state = state.copyWith(lastRefresh: now);
    }
  }

  @visibleForTesting
  void tickCountdownForTest(DateTime now) {
    _tickCountdown(nowOverride: now);
  }

  /// Complete the fade-out animation and remove the signal from state.
  void _completeSignalFadeOut(String signalId) {
    if (!state.hasSignal(signalId)) return; // Already removed

    // Ensure expired signals are removed from local DB and listeners
    final service = ref.read(signalServiceProvider);
    Future.microtask(() => service.cleanupExpiredSignals());

    final newFading = Set<String>.from(state.fadingSignalIds)..remove(signalId);
    var newState = state.copyWith(fadingSignalIds: newFading);
    newState = newState.withoutSignal(signalId);
    state = newState;

    AppLogging.signals('Fade-out complete: removed signal $signalId');
  }

  /// Refresh the signal feed from local storage.
  Future<void> refresh({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final service = ref.read(signalServiceProvider);
      await service.init();
      final allSignals = await service.getAllLocalSignals();
      final signals = await service.getActiveSignals();

      // Sort signals
      final sorted = _sortSignals(signals);

      AppLogging.signals('Feed refreshed: ${sorted.length} active signals');

      // Diagnostic: log DB vs in-memory counts and any removals
      final inMemoryCount = state.signals.length;
      AppLogging.signals(
        'Feed diagnostics: dbCount=${sorted.length} inMemoryCount=$inMemoryCount',
      );
      // Detect signals present in memory but missing in DB
      final missingInDb = state.signals
          .map((s) => s.id)
          .where((id) => !sorted.any((sig) => sig.id == id))
          .toList();
      if (missingInDb.isNotEmpty) {
        for (final id in missingInDb) {
          AppLogging.signals('REFRESH_REMOVE signalId=$id reason=not_in_db');
        }
      }

      final activeIds = sorted.map((sig) => sig.id).toSet();
      for (final signal in allSignals) {
        if (activeIds.contains(signal.id)) continue;
        final reason = signal.isExpired
            ? 'expired'
            : (signal.postMode != PostMode.signal)
                ? 'post_mode=${signal.postMode.name}'
                : 'filtered';
        AppLogging.signals(
          'REFRESH_EXCLUDE signalId=${signal.id} reason=$reason',
        );
      }

      // Use withSignals to build map - handles deduplication
      state = state
          .withSignals(sorted)
          .copyWith(isLoading: false, lastRefresh: DateTime.now());

      AppLogging.signals(
        'Feed refresh complete: inMemory=${state.signals.length}',
      );

      // Trigger resolver for any signals that may now be resolvable (idempotent)
      final sigService = ref.read(signalServiceProvider);
      for (final sig in sorted) {
        if (sig.mediaUrls.isNotEmpty &&
            (sig.imageLocalPath == null || sig.imageLocalPath!.isEmpty)) {
          // Fire-and-forget - safe to call repeatedly
          Future.microtask(() => sigService.resolveSignalImageIfNeeded(sig));
        }
      }
    } catch (e) {
      AppLogging.signals('Feed refresh error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Sort signals by proximity, expiry, and creation time.
  /// Priority order:
  /// 1. Same meshNodeId as myNodeNum (local device)
  /// 2. hopCount ascending (lower = closer, null = unknown/lowest priority)
  /// 3. expiresAt ascending (expiring soon first)
  /// 4. createdAt descending (newest first)
  List<Post> _sortSignals(List<Post> signals) {
    // Get current node position for proximity sorting
    final myNodeNum = ref.read(myNodeNumProvider);

    return sortSignalsForFeed(signals, myNodeNum);
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
    bool? useCloud,
  }) async {
    final service = ref.read(signalServiceProvider);
    final myNodeNum = ref.read(myNodeNumProvider);
    final profile = ref.read(userProfileProvider).value;
    final detectedCanUseCloud = ref
        .read(signalConnectivityProvider)
        .canUseCloud;
    final meshOnlyDebug = ref.read(meshOnlyDebugModeProvider);
    final canUseCloud =
        (useCloud ?? detectedCanUseCloud) && !meshOnlyDebug;

    AppLogging.signals(
      'Creating new signal: ttl=${ttlMinutes}m, hasLocation=${location != null}, '
      'hasImage=${imageLocalPath != null}, canUseCloud=$canUseCloud '
      'meshOnlyDebug=$meshOnlyDebug',
    );

    try {
      final signal = await service.createSignal(
        content: content,
        ttlMinutes: ttlMinutes,
        location: location,
        meshNodeId: myNodeNum,
        imageLocalPath: imageLocalPath,
        authorSnapshot: profile?.isSynced == true
            ? PostAuthorSnapshot(
                displayName: profile!.displayName,
                avatarUrl: profile.avatarUrl,
                isVerified: profile.isVerified,
              )
            : null,
        useCloud: canUseCloud,
      );

      // Add to state using map-based upsert (handles duplicates)
      state = state.withSignal(signal, source: 'local');

      AppLogging.signals('Signal created successfully: ${signal.id}');
      return signal;
    } catch (e) {
      AppLogging.signals('Failed to create signal: $e');
      return null;
    }
  }

  /// Add a signal received from mesh.
  Future<void> addMeshSignal({
    required String content,
    required int senderNodeId,
    String? signalId,
    int? packetId,
    int ttlMinutes = SignalTTL.defaultTTL,
    PostLocation? location,
    int? hopCount,
    bool hasPendingCloudImage = false,
  }) async {
    final service = ref.read(signalServiceProvider);

    // Check if signal already exists in state (early dedupe)
    if (signalId != null && state.hasSignal(signalId)) {
      AppLogging.signals(
        '📡 Signals: ⚠️ Duplicate insert prevented for $signalId (source=mesh) - already in state',
      );
      return;
    }

    AppLogging.signals(
      'Processing mesh signal from node !${senderNodeId.toRadixString(16)}'
      ' (id=${signalId ?? "none"}, packetId=${packetId ?? "none"})',
    );

    try {
      final signal = await service.createSignalFromMesh(
        content: content,
        senderNodeId: senderNodeId,
        signalId: signalId,
        packetId: packetId,
        ttlMinutes: ttlMinutes,
        location: location,
        hopCount: hopCount,
        allowCloud: !ref.read(meshOnlyDebugModeProvider),
        hasPendingCloudImage: hasPendingCloudImage,
      );

      // If null, it was ignored or a duplicate in DB
      if (signal == null) {
        if (signalId != null && signalId.isNotEmpty) {
          AppLogging.signals(
            '📡 Signals: ⚠️ Duplicate insert prevented for $signalId (source=db)',
          );
        }
        return;
      }

      // Add to state using map-based upsert
      state = state.withSignal(signal, source: 'mesh');

      AppLogging.signals('Mesh signal added to feed: ${signal.id}');
      AppLogging.signals(
        'FEED_ADD_OK signalId=${signal.id} feedCount=${state.signals.length}',
      );
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
      state = state.withoutSignal(signalId);
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
        // Update state with new image URL using map-based update
        final existingSignal = state.getSignal(signalId);
        if (existingSignal != null) {
          final updated = existingSignal.copyWith(
            mediaUrls: [url],
            imageState: ImageState.cloud,
          );
          state = state.withSignal(updated, source: 'upload');
        }
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

/// Provider to check if a signal is currently fading out.
final isSignalFadingProvider = Provider.family<bool, String>((ref, signalId) {
  final feedState = ref.watch(signalFeedProvider);
  return feedState.fadingSignalIds.contains(signalId);
});

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
