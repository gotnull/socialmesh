// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Riverpod provider graph for the Socialmesh Overlay v0.2 stack.
///
/// One authoritative provider per responsibility; no duplicates; every
/// attachment explicitly null-references its subscription on
/// `ref.onDispose`. This mirrors the bug-avoidance posture agreed in
/// P1 (commit `78b6a52b` class of bugs).
///
/// Wiring summary:
///
/// ```
/// overlayFlagProvider
///   │
///   ├── overlayLinkStoreProvider         (FutureProvider)
///   │     └── overlayLinkEngineProvider  (FutureProvider)
///   │            ├── overlayCapabilityCoordinatorProvider
///   │            └── overlayProtocolEgressProvider
///   │                  └── protocolServiceProvider (read-only sink)
///   └── overlayAttachmentProvider        (FutureProvider<void>)
///          └── protocolServiceProvider.attachOverlayInbound(...)
/// ```
///
/// When `overlayFlagProvider.linkEnabled == false`:
///   - `overlayLinkStoreProvider` still opens `links.db` (cheap
///     initialisation; avoids race if the flag flips on later).
///   - `overlayLinkEngineProvider` still builds an engine instance.
///   - `overlayAttachmentProvider` does NOT call
///     `attachOverlayInbound`. The handler stays `null` and incoming
///     v0.2 frames sit in the startup buffer until discarded on
///     disconnect.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/protocol/overlay/overlay_capability_coordinator.dart';
import '../services/protocol/overlay/overlay_endpoint_manager.dart';
import '../services/protocol/overlay/overlay_endpoint_store.dart';
import '../services/protocol/overlay/overlay_feature_flag.dart';
import '../services/protocol/overlay/overlay_identity_keypair.dart';
import '../services/protocol/overlay/overlay_ingress_dispatcher.dart';
import '../services/protocol/overlay/overlay_link_egress.dart';
import '../services/protocol/overlay/overlay_link_engine.dart';
import '../services/protocol/overlay/overlay_link_store.dart';
import '../services/protocol/overlay/overlay_protocol_egress.dart';
import '../services/protocol/overlay/overlay_resource_dispatcher.dart';
import '../services/protocol/overlay/overlay_resource_egress.dart';
import '../services/protocol/overlay/overlay_resource_engine.dart';
import '../services/protocol/overlay/overlay_resource_ingress_dispatcher.dart';
import '../services/protocol/overlay/overlay_resource_protocol_egress.dart';
import '../services/protocol/overlay/overlay_resource_store.dart';
import '../services/protocol/overlay/overlay_secure_session_manager.dart';
import 'app_providers.dart';
import 'sip_providers.dart';

/// Exposes the overlay feature flag snapshot. Re-evaluated only when
/// the provider is invalidated.
final overlayFlagProvider = Provider<OverlayFeatureFlags>((ref) {
  return OverlayFeatureFlags.fromEnv();
});

/// SQLite store for link state. One instance per app lifetime.
final overlayLinkStoreProvider = FutureProvider<OverlayLinkStore>((ref) async {
  final store = OverlayLinkStore();
  await store.init();
  ref.onDispose(() async {
    await store.close();
  });
  return store;
});

/// In-memory capability coordinator. Disposed when the provider tears
/// down (e.g., transport switch that invalidates the overlay graph).
final overlayCapabilityCoordinatorProvider =
    Provider<OverlayCapabilityCoordinator>((ref) {
      final coordinator = OverlayCapabilityCoordinator();
      ref.onDispose(coordinator.dispose);
      return coordinator;
    });

/// P3: persistent local Ed25519 identity. Separate keypair from the
/// SIP persona per the locked "keep identity layers separated"
/// principle. Generation is deferred to the first
/// `ensureInitialized()` call inside [overlayEndpointManagerProvider].
final overlayIdentityKeypairProvider = Provider<OverlayIdentityKeypair>((ref) {
  return OverlayIdentityKeypair();
});

/// P3: `endpoints.db` store. Opened lazily, closed on dispose.
final overlayEndpointStoreProvider = FutureProvider<OverlayEndpointStore>((
  ref,
) async {
  final store = OverlayEndpointStore();
  await store.init();
  ref.onDispose(() async {
    await store.close();
  });
  return store;
});

/// P3: the single authoritative [OverlayEndpointManager].
///
/// Built once per process; initialises the local Ed25519 keypair (on
/// first run, generates and persists) and caches the derived local
/// endpoint ID. Consumers never touch the keypair or endpoint store
/// directly.
final overlayEndpointManagerProvider = FutureProvider<OverlayEndpointManager>((
  ref,
) async {
  final keypair = ref.read(overlayIdentityKeypairProvider);
  final store = await ref.watch(overlayEndpointStoreProvider.future);
  final manager = OverlayEndpointManager(keypair: keypair, store: store);
  await manager.ensureInitialized();
  ref.onDispose(manager.dispose);
  return manager;
});

/// Outbound SIP sink for overlay link frames. Reads the flag lazily
/// on every send so a runtime toggle (P3) can take effect without
/// rebuilding the engine.
final overlayProtocolEgressProvider = Provider<OverlayLinkEgress>((ref) {
  final protocol = ref.read(protocolServiceProvider);
  return OverlayProtocolEgress(
    sipSink: (bytes, type) => protocol.sendSipPayload(bytes, type),
    flags: () => ref.read(overlayFlagProvider),
    rateLimiter: () => ref.read(sipRateLimiterProvider),
  );
});

/// v0.3 secure-session manager. Attached into [overlayLinkEngineProvider]
/// so the engine forwards link activation / secure-inbound / link
/// terminate hooks automatically. The manager's own `_enabledFlag`
/// reads `overlayFlagProvider.secureActive` per call, so a runtime
/// flag flip propagates without rebuilding either the manager or the
/// engine.
///
/// The manager shares the same `OverlayLinkStore` and egress sink as
/// the engine — they must operate on identical link state or secure
/// frames go to the wrong link.
final overlaySecureSessionManagerProvider =
    FutureProvider<OverlaySecureSessionManager>((ref) async {
      final store = await ref.watch(overlayLinkStoreProvider.future);
      final egress = ref.read(overlayProtocolEgressProvider);
      final endpointManager = await ref.watch(
        overlayEndpointManagerProvider.future,
      );
      final manager = OverlaySecureSessionManager(
        store: store,
        egress: egress,
        endpointManager: endpointManager,
        enabledFlag: () => ref.read(overlayFlagProvider).secureActive,
      );
      ref.onDispose(() async {
        await manager.dispose();
      });
      return manager;
    });

/// The single authoritative [OverlayLinkEngine] for this app process.
final overlayLinkEngineProvider = FutureProvider<OverlayLinkEngine>((
  ref,
) async {
  final store = await ref.watch(overlayLinkStoreProvider.future);
  final egress = ref.read(overlayProtocolEgressProvider);
  final endpointManager = await ref.watch(
    overlayEndpointManagerProvider.future,
  );
  final secureSessionManager = await ref.watch(
    overlaySecureSessionManagerProvider.future,
  );

  final engine = OverlayLinkEngine(
    store: store,
    egress: egress,
    endpointManager: endpointManager,
    secureSessionManager: secureSessionManager,
  );
  ref.onDispose(() async {
    await engine.dispose();
  });

  // Apply no-phantom-open restore semantics on every engine build.
  await engine.restore();
  return engine;
});

/// Wires the ingress dispatcher into [ProtocolService] when
/// `OVERLAY_LINK_ENABLED=true`. The provider is a `FutureProvider<void>`
/// because it awaits the engine future; the returned value is ignored
/// by callers. Its only purpose is lifecycle management.
///
/// Disposal: `attachOverlayInbound(null)` explicitly nulls the
/// reference held by [ProtocolService], and the dispatcher is marked
/// disposed so any in-flight callbacks no-op.
/// P5: `overlay_transfers.db` store. Opened lazily; closed on dispose.
final overlayResourceStoreProvider = FutureProvider<OverlayResourceStore>((
  ref,
) async {
  final store = OverlayResourceStore();
  await store.init();
  ref.onDispose(() async {
    await store.close();
  });
  return store;
});

/// P5: production [OverlayResourceEgress] adapter. Always built, but
/// its `sendFrame` short-circuits when `resourceActive` is false.
final overlayResourceEgressProvider = FutureProvider<OverlayResourceEgress>((
  ref,
) async {
  final linkEngine = await ref.watch(overlayLinkEngineProvider.future);
  return OverlayResourceProtocolEgress(
    linkEngine: linkEngine,
    flags: () => ref.read(overlayFlagProvider),
  );
});

/// P5: the single authoritative [OverlayResourceEngine].
///
/// Built once per process. Applies restore semantics on every build
/// (idempotent on an already-restored DB). Store + engine lifecycles
/// are independent — each has its own `ref.onDispose`.
final overlayResourceEngineProvider = FutureProvider<OverlayResourceEngine>((
  ref,
) async {
  final store = await ref.watch(overlayResourceStoreProvider.future);
  final egress = await ref.watch(overlayResourceEgressProvider.future);
  final engine = OverlayResourceEngine(store: store, egress: egress);
  ref.onDispose(() async {
    await engine.dispose();
  });
  await engine.restore();
  return engine;
});

/// P5: capability-gated dispatcher. Callers submit resource send
/// intents here; the dispatcher routes to overlay or returns a
/// `fallbackRequired` result per the locked P5 fallback policy.
///
/// This provider only builds when `resourceActive` is true. When the
/// resource flag (or the link flag it depends on) is off, reading
/// this provider returns null — callers then fall through to legacy
/// transport unconditionally.
final overlayResourceDispatcherProvider =
    FutureProvider<OverlayResourceDispatcher?>((ref) async {
      final flags = ref.watch(overlayFlagProvider);
      if (!flags.resourceActive) return null;
      final engine = await ref.watch(overlayResourceEngineProvider.future);
      final capability = ref.read(overlayCapabilityCoordinatorProvider);
      return OverlayResourceDispatcher(
        engine: engine,
        capability: capability,
        flags: () => ref.read(overlayFlagProvider),
      );
    });

/// P5: wires [OverlayResourceIngressDispatcher] onto the live
/// [OverlayLinkEngine] event stream. Only starts when
/// `resourceActive` is true. On dispose, the subscription is
/// explicitly cancelled and the reference nulled.
final overlayResourceIngressProvider =
    FutureProvider<OverlayResourceIngressDispatcher?>((ref) async {
      final flags = ref.watch(overlayFlagProvider);
      if (!flags.resourceActive) return null;

      final linkEngine = await ref.watch(overlayLinkEngineProvider.future);
      final resourceEngine = await ref.watch(
        overlayResourceEngineProvider.future,
      );

      final dispatcher = OverlayResourceIngressDispatcher(
        linkEngine: linkEngine,
        resourceEngine: resourceEngine,
      );
      dispatcher.start();
      ref.onDispose(() async {
        await dispatcher.stop();
      });
      return dispatcher;
    });

final overlayAttachmentProvider = FutureProvider<OverlayIngressDispatcher?>((
  ref,
) async {
  final flags = ref.watch(overlayFlagProvider);
  if (!flags.linkEnabled) {
    return null;
  }

  final engine = await ref.watch(overlayLinkEngineProvider.future);
  final coordinator = ref.read(overlayCapabilityCoordinatorProvider);
  final protocol = ref.read(protocolServiceProvider);

  final dispatcher = OverlayIngressDispatcher(
    engine: engine,
    coordinator: coordinator,
  );

  protocol.attachOverlayInbound(dispatcher.handleInboundMrrpBytes);

  ref.onDispose(() {
    // Explicit detach + null the stored reference inside ProtocolService.
    protocol.attachOverlayInbound(null);
    dispatcher.dispose();
  });

  return dispatcher;
});
