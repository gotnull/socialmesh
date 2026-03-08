// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Riverpod providers for MRRP state.
///
/// Exposes MRRP service registry, dispatcher, advert cache, engine,
/// and counters to the widget layer. All providers are gated behind
/// [AppFeatureFlags.isMrrpEnabled] and require SIP to also be enabled.
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../services/protocol/sip/mrrp_advert_engine.dart';
import '../services/protocol/sip/mrrp_counters.dart';
import '../services/protocol/sip/mrrp_dedup_cache.dart';
import '../services/protocol/sip/mrrp_dispatcher.dart';
import '../services/protocol/sip/mrrp_engine.dart';
import '../services/protocol/sip/mrrp_service_board.dart';
import '../services/protocol/sip/mrrp_service_echo.dart';
import '../services/protocol/sip/mrrp_service_meetup.dart';
import '../services/protocol/sip/mrrp_service_profile.dart';
import '../services/protocol/sip/mrrp_service_registry.dart';
import '../services/protocol/sip/mrrp_simulated_peer.dart';
import '../services/protocol/sip/mrrp_traffic_event.dart';
import '../services/protocol/sip/mrrp_types.dart';
import '../services/protocol/sip/sip_types.dart';
import 'app_providers.dart';
import 'sip_providers.dart';

/// Whether MRRP is enabled (sourced from SmFeatureFlag).
final mrrpEnabledProvider = NotifierProvider<MrrpEnabledNotifier, bool>(
  MrrpEnabledNotifier.new,
);

/// Notifier controlling MRRP enabled state.
class MrrpEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => AppFeatureFlags.isMrrpEnabled;

  /// Set the MRRP enabled state.
  void setEnabled(bool value) => state = value;
}

/// MRRP service registry — registers built-in service handlers.
final mrrpServiceRegistryProvider = Provider<MrrpServiceRegistry?>((ref) {
  final mrrpEnabled = ref.watch(mrrpEnabledProvider);
  final sipEnabled = ref.watch(sipEnabledProvider);
  if (!mrrpEnabled || !sipEnabled) return null;

  final registry = MrrpServiceRegistry();

  // Register built-in services.
  final meetup = MrrpServiceMeetup();
  registry.register(
    meetup,
    MrrpServiceDescriptor(
      serviceId: MrrpServiceId.meetupV1,
      serviceType: MrrpServiceType.app,
      serviceFlags:
          MrrpServiceFlags.supportsRequest |
          MrrpServiceFlags.supportsResponse |
          MrrpServiceFlags.ephemeralOnly |
          MrrpServiceFlags.userVisible,
    ),
  );

  final profile = MrrpServiceProfile(
    configProvider: () => const MrrpProfileConfig(
      displayName: '', // lint-allow: hardcoded-string
      registeredServices: [],
    ),
  );
  registry.register(
    profile,
    MrrpServiceDescriptor(
      serviceId: MrrpServiceId.profileV1,
      serviceType: MrrpServiceType.app,
      serviceFlags:
          MrrpServiceFlags.supportsRequest |
          MrrpServiceFlags.supportsResponse |
          MrrpServiceFlags.requiresIdentity |
          MrrpServiceFlags.userVisible,
    ),
  );

  final board = MrrpServiceBoard();
  registry.register(
    board,
    MrrpServiceDescriptor(
      serviceId: MrrpServiceId.boardV1,
      serviceType: MrrpServiceType.app,
      serviceFlags:
          MrrpServiceFlags.supportsRequest |
          MrrpServiceFlags.supportsResponse |
          MrrpServiceFlags.ephemeralOnly |
          MrrpServiceFlags.userVisible,
    ),
  );

  // echo.test — only when harness is enabled.
  if (AppFeatureFlags.isMrrpHarnessEnabled) {
    final echo = MrrpServiceEcho();
    registry.register(
      echo,
      MrrpServiceDescriptor(
        serviceId: MrrpServiceId.echoTest,
        serviceType: MrrpServiceType.test,
        serviceFlags:
            MrrpServiceFlags.supportsRequest |
            MrrpServiceFlags.supportsResponse |
            MrrpServiceFlags.testOnly,
      ),
    );
  }

  return registry;
});

/// MRRP dedup cache instance.
final mrrpDedupCacheProvider = Provider<MrrpDedupCache?>((ref) {
  final registry = ref.watch(mrrpServiceRegistryProvider);
  if (registry == null) return null;
  return MrrpDedupCache();
});

/// MRRP dispatcher instance.
///
/// Created without [MrrpDispatcher.onSend]; the send callback is wired
/// by [mrrpEngineProvider] after construction to avoid circular deps.
final mrrpDispatcherProvider = Provider<MrrpDispatcher?>((ref) {
  final registry = ref.watch(mrrpServiceRegistryProvider);
  if (registry == null) return null;
  return MrrpDispatcher(registry: registry);
});

/// MRRP counters — session-scoped instrumentation (shared singleton).
final mrrpCountersProvider = Provider<MrrpCounters>((ref) {
  final counters = MrrpCounters();
  counters.onChange = () {
    ref.read(mrrpCountersEpochProvider.notifier).bump();
  };
  return counters;
});

/// Maximum events retained in the traffic console.
const _kMaxTrafficEvents = 200;

/// Provider for the traffic event stream (session-scoped).
final mrrpTrafficEventsProvider =
    NotifierProvider<MrrpTrafficEventsNotifier, List<MrrpTrafficEvent>>(
      MrrpTrafficEventsNotifier.new,
    );

/// Notifier managing the bounded traffic event list.
class MrrpTrafficEventsNotifier extends Notifier<List<MrrpTrafficEvent>> {
  @override
  List<MrrpTrafficEvent> build() => [];

  /// Add a traffic event (newest first, bounded).
  void add(MrrpTrafficEvent event) {
    final updated = [event, ...state];
    if (updated.length > _kMaxTrafficEvents) {
      state = updated.sublist(0, _kMaxTrafficEvents);
    } else {
      state = updated;
    }
  }

  /// Clear all events.
  void clear() => state = [];
}

/// Registry of simulated MRRP peers (session-scoped).
final mrrpSimPeersProvider =
    NotifierProvider<MrrpSimPeersNotifier, List<MrrpSimulatedPeer>>(
      MrrpSimPeersNotifier.new,
    );

/// Notifier managing the simulated peer list.
class MrrpSimPeersNotifier extends Notifier<List<MrrpSimulatedPeer>> {
  int _nextIndex = 1;

  @override
  List<MrrpSimulatedPeer> build() => [];

  /// Add a simulated peer.
  void add(MrrpSimulatedPeer peer) {
    state = [...state, peer];
  }

  /// Remove a simulated peer by ID.
  void remove(String simId) {
    state = state.where((p) => p.simId != simId).toList();
  }

  /// Update the response mode for a simulated peer.
  void updateMode(String simId, SimResponseMode mode) {
    state = [
      for (final p in state)
        if (p.simId == simId) p..mode = mode else p,
    ];
  }

  /// Update the delay for a simulated peer.
  void updateDelay(String simId, int seconds) {
    state = [
      for (final p in state)
        if (p.simId == simId) p..delaySeconds = seconds else p,
    ];
  }

  /// Update the error status for a simulated peer.
  void updateErrorStatus(String simId, MrrpStatusCode status) {
    state = [
      for (final p in state)
        if (p.simId == simId) p..errorStatus = status else p,
    ];
  }

  /// Allocate the next sequential index.
  int allocateIndex() => _nextIndex++;
}

/// Bumped whenever advert cache changes so downstream providers rebuild.
final mrrpAdvertEpochProvider = NotifierProvider<_MrrpAdvertEpoch, int>(
  _MrrpAdvertEpoch.new,
);

class _MrrpAdvertEpoch extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// MRRP advert engine instance.
///
/// Created without [MrrpAdvertEngine.onSend]; the send callback is wired
/// by [mrrpEngineProvider] after construction to avoid circular deps.
final mrrpAdvertEngineProvider = Provider<MrrpAdvertEngine?>((ref) {
  final registry = ref.watch(mrrpServiceRegistryProvider);
  if (registry == null) return null;

  final engine = MrrpAdvertEngine(registry: registry);

  engine.onCacheChanged = () {
    ref.read(mrrpAdvertEpochProvider.notifier).bump();
  };

  ref.onDispose(() {
    engine.onCacheChanged = null;
    engine.dispose();
  });

  return engine;
});

/// Bumped whenever MRRP counters change.
final mrrpCountersEpochProvider = NotifierProvider<_MrrpCountersEpoch, int>(
  _MrrpCountersEpoch.new,
);

class _MrrpCountersEpoch extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// MRRP engine — main entry point for the protocol stack.
final mrrpEngineProvider = Provider<MrrpEngine?>((ref) {
  final registry = ref.watch(mrrpServiceRegistryProvider);
  if (registry == null) return null;

  final advertEngine = ref.watch(mrrpAdvertEngineProvider);
  if (advertEngine == null) return null;

  final dispatcher = ref.watch(mrrpDispatcherProvider);
  if (dispatcher == null) return null;

  final dedupCache = ref.watch(mrrpDedupCacheProvider);
  if (dedupCache == null) return null;

  // SIP transport send callback — shared by engine, dispatcher, and advert.
  // Rate-limited via SipRateLimiter to enforce the 1024 bytes/60s airtime
  // budget shared with SIP discovery frames.
  Future<bool> sendViaSip(Uint8List sipPayload) async {
    final limiter = ref.read(sipRateLimiterProvider);
    if (!limiter.canSend(sipPayload.length)) {
      ref.read(mrrpCountersProvider).recordBudgetThrottle();
      return false;
    }
    final protocol = ref.read(protocolServiceProvider);
    final sent = await protocol.sendSipPayload(
      sipPayload,
      SipMessageType.mrrpData,
    );
    if (sent) {
      limiter.recordSend(sipPayload.length);
    }
    return sent;
  }

  // Wire send callbacks on dispatcher and advert engine.
  dispatcher.onSend = sendViaSip;
  advertEngine.onSend = sendViaSip;

  // Wire counters.
  final counters = ref.read(mrrpCountersProvider);
  dispatcher.counters = counters;
  advertEngine.counters = counters;

  // Wire sim peer interception on dispatcher.
  dispatcher.onSimPeerRequest = (frame) async {
    final simPeers = ref.read(mrrpSimPeersProvider);
    final matching = simPeers.where(
      (p) => p.serviceIds.contains(frame.serviceId),
    );
    if (matching.isEmpty) return null;
    return matching.first.handleRequest(frame);
  };

  final engine = MrrpEngine(
    registry: registry,
    advertEngine: advertEngine,
    dispatcher: dispatcher,
    dedupCache: dedupCache,
    onSend: sendViaSip,
  );

  // Wire counters and traffic event callback on engine.
  engine.counters = counters;
  engine.onTrafficEvent = (event) {
    ref.read(mrrpTrafficEventsProvider.notifier).add(event);
  };

  // Start the engine BEFORE attaching to the protocol service.
  //
  // CRITICAL ORDER: engine.start() must precede protocol.attachMrrpEngine().
  // Attachment triggers an immediate synchronous drain of the MRRP startup
  // buffer (_drainMrrpStartupBuffer). Each drained frame calls
  // engine.handleInboundFrame(), which checks `if (!_running)` first and
  // silently drops the frame if the engine is not yet running. Calling
  // start() after attach means every frame in the startup buffer (e.g.,
  // SERVICE_ADVERTs received before MrrpEngine was first built) is permanently
  // dropped — the entire MRRP buffering fix is rendered ineffective.
  engine.start();

  // Attach to protocol service — drain of any buffered startup frames fires
  // here. The engine is already running, so handleInboundFrame processes them.
  final protocol = ref.read(protocolServiceProvider);
  protocol.attachMrrpEngine(engine);

  ref.onDispose(() {
    protocol.attachMrrpEngine(null);
    engine.dispose();
  });

  return engine;
});

/// All cached advert services (from remote peers), keyed by node ID.
///
/// Watches [mrrpEngineProvider] to ensure the engine is created and attached
/// to the protocol service before reading cached services. Without this
/// dependency the engine never starts, send callbacks are never wired,
/// and incoming SERVICE_ADVERT frames are silently dropped.
final mrrpCachedServicesProvider = Provider<Map<int, List<MrrpCachedService>>>((
  ref,
) {
  // Ensure the engine is created, attached, and running.
  ref.watch(mrrpEngineProvider);
  ref.watch(mrrpAdvertEpochProvider);
  final advertEngine = ref.watch(mrrpAdvertEngineProvider);
  return advertEngine?.getAllCachedServices() ?? {};
});
