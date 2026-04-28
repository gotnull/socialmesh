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
import '../services/protocol/sip/sip_constants.dart';
import '../services/protocol/sip/mrrp_counters.dart';
import '../services/protocol/sip/mrrp_dedup_cache.dart';
import '../services/protocol/sip/mrrp_dispatcher.dart';
import '../services/protocol/sip/mrrp_engine.dart';
import '../services/protocol/sip/mrrp_service_board.dart';
import '../services/protocol/sip/mrrp_service_echo.dart';
import '../services/protocol/sip/mrrp_service_incident.dart';
import '../services/protocol/sip/mrrp_service_meetup.dart';
import '../services/protocol/sip/mrrp_service_pet.dart';
import '../services/protocol/sip/mrrp_service_profile.dart';
import '../services/protocol/sip/mrrp_service_registry.dart';
import '../services/protocol/sip/mrrp_simulated_peer.dart';
import '../services/protocol/sip/mrrp_traffic_event.dart';
import '../services/protocol/sip/mrrp_types.dart';
import '../services/protocol/sip/sip_types.dart';
import 'app_providers.dart';
import 'peer_safety_providers.dart';
import 'sip_providers.dart';
import '../features/incidents/providers/mesh_incident_providers.dart';
import '../features/pet/models/remote_pet_share_status.dart';
import '../features/pet/providers/pet_providers.dart';
import '../features/pet/services/pet_public_state_codec.dart';

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
          MrrpServiceFlags.ephemeralOnly,
    ),
  );

  final profile = MrrpServiceProfile(
    configProvider: () {
      final myNodeNum = ref.read(myNodeNumProvider);
      final nodes = ref.read(nodesProvider);
      final myNode = myNodeNum != null ? nodes[myNodeNum] : null;
      final registeredIds = registry
          .getAll()
          .map((d) => d.serviceId)
          .toList(growable: false);
      return MrrpProfileConfig(
        displayName:
            myNode?.longName ??
            myNode?.shortName ??
            '', // lint-allow: hardcoded-string
        registeredServices: registeredIds,
        deviceClass: 1, // phone-app
      );
    },
  );
  registry.register(
    profile,
    MrrpServiceDescriptor(
      serviceId: MrrpServiceId.profileV1,
      serviceType: MrrpServiceType.app,
      serviceFlags:
          MrrpServiceFlags.supportsRequest |
          MrrpServiceFlags.supportsResponse |
          MrrpServiceFlags.requiresIdentity,
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
          MrrpServiceFlags.ephemeralOnly,
    ),
  );

  // incident.v1 — mesh incident reporting over SPP.
  if (AppFeatureFlags.isMeshIncidentsEnabled) {
    final incidentService = ref.read(meshIncidentServiceProvider);
    final incident = MrrpServiceIncident(
      onReportReceived: (report) {
        incidentService.ingestReport(report);
      },
      lookupCase: (caseId) {
        // Synchronous lookup returns null if DB not ready.
        // handleQuery is async-capable but the handler API
        // returns a sync result for the lookup callback.
        // Return the last known report for the case.
        return null; // Queries delegated to async service layer.
      },
    );
    registry.register(
      incident,
      MrrpServiceDescriptor(
        serviceId: MrrpServiceId.incidentV1,
        serviceType: MrrpServiceType.app,
        serviceFlags:
            MrrpServiceFlags.supportsRequest |
            MrrpServiceFlags.supportsResponse,
      ),
    );
  }

  // pet.v1 — opt-in compact owner pet public state.
  if (AppFeatureFlags.isPetEnabled) {
    final pet = MrrpServicePet(
      bytesProvider: () {
        final public = ref.read(petPublicStateProvider);
        if (public == null) return null;
        return PetPublicStateCodec.encode(public);
      },
    );
    registry.register(
      pet,
      MrrpServiceDescriptor(
        serviceId: MrrpServiceId.petV1,
        serviceType: MrrpServiceType.app,
        serviceFlags:
            MrrpServiceFlags.supportsRequest |
            MrrpServiceFlags.supportsResponse,
      ),
    );
  }

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
    // Deferred: onChange fires synchronously during frame processing which
    // can overlap with a widget build phase. Mutating provider state during
    // build throws "Tried to modify a provider while the widget tree was
    // building". A microtask defers the bump to after the current frame.
    Future.microtask(() => ref.read(mrrpCountersEpochProvider.notifier).bump());
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

  // Wire mesh privacy setting so advert broadcast is gated on discoverability.
  engine.isAdvertisingEnabled = ref.watch(meshPrivacyDiscoverableProvider);

  engine.onCacheChanged = () {
    // Deferred: onCacheChanged fires synchronously during frame processing
    // which can overlap with a widget build. See mrrpCountersProvider.
    Future.microtask(() => ref.read(mrrpAdvertEpochProvider.notifier).bump());
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
  // MRRP rides inside SIP frames, so inbound MRRP requests cannot be routed
  // unless the SIP ingress path is attached. Do this eagerly here rather than
  // relying on a SIP UI screen to watch sipDiscoveryProvider.
  ref.watch(sipDiscoveryProvider);

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
  Future<bool> sendViaSip(Uint8List mrrpPayload) async {
    // Account for the SIP frame header that sendSipPayload will add.
    final wireSize = mrrpPayload.length + SipConstants.sipWrapperMin;
    final limiter = ref.read(sipRateLimiterProvider);
    if (!limiter.canSend(wireSize)) {
      ref.read(mrrpCountersProvider).recordBudgetThrottle();
      return false;
    }
    final protocol = ref.read(protocolServiceProvider);
    final sent = await protocol.sendSipPayload(
      mrrpPayload,
      SipMessageType.mrrpData,
    );
    if (sent) {
      limiter.recordSend(wireSize);
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

  // Trust + Safety gate. Hot-path consulted at `_routeFrame` to
  // silently drop every MRRP frame originating from a blocked peer
  // — request, response, advert, dirReq, dirResp.
  engine.attachPeerSafetyGate(ref.read(peerSafetyGateProvider));

  // Wire counters and traffic event callback on engine.
  engine.counters = counters;
  engine.onTrafficEvent = (event) {
    ref.read(mrrpTrafficEventsProvider.notifier).add(event);
  };

  // Wire mesh privacy: gate inbound MRRP requests on discoverability.
  engine.isServicingEnabled = ref.watch(meshPrivacyDiscoverableProvider);

  // Wire profile sharing privacy on the profile.v1 handler.
  final profileHandler = registry.getHandler(MrrpServiceId.profileV1);
  if (profileHandler is MrrpServiceProfile) {
    profileHandler.isProfileSharingEnabled = ref.watch(
      meshPrivacyProfileSharingProvider,
    );
  }

  // Wire pet sharing on the pet.v1 handler. For v1, the feature flag
  // itself is the privacy gate; a user-visible opt-out toggle comes
  // with the NodeDex peer-visibility work.
  final petHandler = registry.getHandler(MrrpServiceId.petV1);
  if (petHandler is MrrpServicePet) {
    petHandler.isPetSharingEnabled = AppFeatureFlags.isPetEnabled;
  }

  // Wire inbound pet.v1 response ingestion. The observer fires on every
  // RESPONSE/ERROR whose dedup check passed; we inspect the service ID
  // and (on success) decode the 8-byte PetPublicState from the payload,
  // then write it to the remote_pet_cache keyed by the authoritative
  // sender nodeNum from the Meshtastic packet — NOT by a requester-side
  // assumed target (see peer-targeting notes in pet_remote_client.dart).
  if (AppFeatureFlags.isPetEnabled) {
    engine.onResponseObserved = (frame, senderNodeId) {
      if (frame.serviceId != MrrpServiceId.petV1) return;
      if (frame.actionId != PetAction.getSummary) return;
      // Error frame → peer declined to share (feature disabled,
      // unauthorized, or any service-level failure). Record the signal
      // so the Companion card can say "this node isn't sharing" in
      // plain language instead of "no observation yet".
      if ((frame.flags & MrrpFlags.isError) != 0) {
        ref
            .read(petIngestControllerProvider)
            .recordShareStatus(senderNodeId, RemotePetShareStatus.notSharing);
        return;
      }
      // Empty payload → peer acknowledged the request but has no pet
      // bound right now (not paired, just reset, etc.). Surface the
      // same "not sharing" copy; the distinction from an error frame is
      // invisible to the user and would add no product value.
      if (frame.payload.isEmpty) {
        ref
            .read(petIngestControllerProvider)
            .recordShareStatus(senderNodeId, RemotePetShareStatus.notSharing);
        return;
      }
      final decoded = PetPublicStateCodec.tryDecode(
        Uint8List.fromList(frame.payload),
      );
      if (decoded == null) return;
      // ref.read is safe here — we're inside a provider body's closure,
      // not rebuilding. Fire-and-forget; failures are logged internally.
      // ingestRemotePet also flips share status to `sharing`.
      ref
          .read(petIngestControllerProvider)
          .ingestRemotePet(senderNodeId, decoded);
    };
  }

  // Start the engine BEFORE attaching to the protocol service.
  //
  // CRITICAL ORDER: engine.start() must precede protocol.attachMrrpEngine().
  // Attachment sets _mrrpEngine synchronously, then defers the startup
  // buffer drain to a microtask. Drained frames call
  // engine.handleInboundFrame(), which checks `if (!_running)` and drops
  // the frame if the engine has not started. The drain is deferred (not
  // synchronous) to avoid mutating other Riverpod providers (counters
  // epoch, advert epoch, traffic events) during this provider's build.
  engine.start();

  // Attach to protocol service — drain of buffered startup frames is
  // scheduled as a microtask. The engine is already running, so
  // handleInboundFrame processes them when the microtask executes.
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
