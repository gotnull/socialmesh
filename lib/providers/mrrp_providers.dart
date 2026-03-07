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
import '../services/protocol/sip/mrrp_dedup_cache.dart';
import '../services/protocol/sip/mrrp_dispatcher.dart';
import '../services/protocol/sip/mrrp_engine.dart';
import '../services/protocol/sip/mrrp_service_board.dart';
import '../services/protocol/sip/mrrp_service_echo.dart';
import '../services/protocol/sip/mrrp_service_meetup.dart';
import '../services/protocol/sip/mrrp_service_profile.dart';
import '../services/protocol/sip/mrrp_service_registry.dart';
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
  Future<bool> sendViaSip(Uint8List sipPayload) async {
    final protocol = ref.read(protocolServiceProvider);
    return protocol.sendSipPayload(sipPayload, SipMessageType.mrrpData);
  }

  // Wire send callbacks on dispatcher and advert engine.
  dispatcher.onSend = sendViaSip;
  advertEngine.onSend = sendViaSip;

  final engine = MrrpEngine(
    registry: registry,
    advertEngine: advertEngine,
    dispatcher: dispatcher,
    dedupCache: dedupCache,
    onSend: sendViaSip,
  );

  // Attach to protocol service.
  final protocol = ref.read(protocolServiceProvider);
  protocol.attachMrrpEngine(engine);

  // Auto-start.
  engine.start();

  ref.onDispose(() {
    protocol.attachMrrpEngine(null);
    engine.dispose();
  });

  return engine;
});

/// All cached advert services (from remote peers), keyed by node ID.
final mrrpCachedServicesProvider = Provider<Map<int, List<MrrpCachedService>>>((
  ref,
) {
  ref.watch(mrrpAdvertEpochProvider);
  final advertEngine = ref.watch(mrrpAdvertEngineProvider);
  return advertEngine?.getAllCachedServices() ?? {};
});
