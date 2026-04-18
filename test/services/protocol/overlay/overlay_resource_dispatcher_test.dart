// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tests for [OverlayResourceDispatcher] — the capability-gated
/// entry point with deterministic fallback policy.
///
/// Locked P5 flag matrix:
///   - resource=true, link=false → inert (fallbackRequired)
///   - resource=true, link=true  → active (may overlay-accept)
///   - resource=false, link=true → resource inert (fallbackRequired)
///
/// Locked P5 capability rule:
///   - unknown peer → fallbackRequired (NO optimistic attempts)
///   - known unsupported peer → fallbackRequired
///   - known supported peer + flags on → overlayAccepted
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_capability_coordinator.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_feature_flag.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_models.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_resource_dispatcher.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_resource_egress.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_resource_engine.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_types.dart';

import '_overlay_link_test_harness.dart';

Uint8List _hint(int seed) => Uint8List.fromList(List<int>.filled(8, seed));

Future<
  ({
    OverlayResourceDispatcher dispatcher,
    OverlayCapabilityCoordinator capability,
    OverlayResourceEngine engine,
    OverlayFeatureFlags Function() flagsGetter,
  })
>
_rig({bool linkEnabled = true, bool resourceEnabled = true}) async {
  final store = await openInMemoryResourceStore();
  final egress = RecordingOverlayResourceEgress();
  final engine = OverlayResourceEngine(
    store: store,
    egress: egress,
    clock: FakeClock().now,
  );
  final capability = OverlayCapabilityCoordinator(clock: FakeClock().now);
  OverlayFeatureFlags currentFlags = OverlayFeatureFlags(
    linkEnabled: linkEnabled,
    resourceEnabled: resourceEnabled,
  );
  OverlayFeatureFlags flagsGetter() => currentFlags;
  final dispatcher = OverlayResourceDispatcher(
    engine: engine,
    capability: capability,
    flags: flagsGetter,
  );
  return (
    dispatcher: dispatcher,
    capability: capability,
    engine: engine,
    flagsGetter: flagsGetter,
  );
}

void main() {
  setUpAll(initFfi);

  test('link off: fallbackRequired regardless of other state', () async {
    final r = await _rig(linkEnabled: false);
    // Even if capability says yes, link-off → fallback.
    r.capability.record(
      5,
      const OverlayLinkCapabilities(supportedFeatures: 0x01),
      OverlayCapabilityObservationSource.linkFrame,
    );
    final result = await r.dispatcher.submit(
      peerEndpointHint: _hint(1),
      peerNodeNum: 5,
      payload: Uint8List.fromList([1, 2, 3]),
    );
    expect(result.outcome, OverlayResourceDispatchOutcome.fallbackRequired);
    expect(result.reason, OverlayResourceDispatchReason.linkDisabled);
    await r.engine.dispose();
  });

  test('resource off: fallbackRequired', () async {
    final r = await _rig(resourceEnabled: false);
    r.capability.record(
      5,
      const OverlayLinkCapabilities(supportedFeatures: 0x01),
      OverlayCapabilityObservationSource.linkFrame,
    );
    final result = await r.dispatcher.submit(
      peerEndpointHint: _hint(1),
      peerNodeNum: 5,
      payload: Uint8List.fromList([1, 2, 3]),
    );
    expect(result.outcome, OverlayResourceDispatchOutcome.fallbackRequired);
    expect(result.reason, OverlayResourceDispatchReason.resourceDisabled);
    await r.engine.dispose();
  });

  test(
    'unknown peer capability: fallbackRequired (no optimistic attempt)',
    () async {
      final r = await _rig();
      final result = await r.dispatcher.submit(
        peerEndpointHint: _hint(1),
        peerNodeNum: 42, // never observed
        payload: Uint8List.fromList([1, 2, 3]),
      );
      expect(result.outcome, OverlayResourceDispatchOutcome.fallbackRequired);
      expect(
        result.reason,
        OverlayResourceDispatchReason.peerCapabilityUnknown,
      );
      // Engine never got an offerLocal call — tick is a no-op.
      await r.engine.tick();
      await r.engine.dispose();
    },
  );

  test('peer known to NOT support overlay: fallbackRequired', () async {
    final r = await _rig();
    r.capability.record(
      5,
      const OverlayLinkCapabilities(supportedFeatures: 0x00),
      OverlayCapabilityObservationSource.capBeacon,
    );
    final result = await r.dispatcher.submit(
      peerEndpointHint: _hint(1),
      peerNodeNum: 5,
      payload: Uint8List.fromList([1, 2, 3]),
    );
    expect(result.outcome, OverlayResourceDispatchOutcome.fallbackRequired);
    expect(result.reason, OverlayResourceDispatchReason.peerNotOverlayCapable);
    await r.engine.dispose();
  });

  test(
    'happy path: flags on + peer capable → overlayAccepted + record',
    () async {
      final r = await _rig();
      r.capability.record(
        5,
        const OverlayLinkCapabilities(supportedFeatures: 0x01),
        OverlayCapabilityObservationSource.linkFrame,
      );
      final result = await r.dispatcher.submit(
        peerEndpointHint: _hint(1),
        peerNodeNum: 5,
        payload: Uint8List.fromList(List<int>.filled(64, 7)),
      );
      expect(result.outcome, OverlayResourceDispatchOutcome.overlayAccepted);
      expect(result.reason, OverlayResourceDispatchReason.ok);
      expect(result.record, isNotNull);
      expect(result.record!.state, OverlayResourceState.offering);
      await r.engine.dispose();
    },
  );

  test('empty payload: rejected (not a fallback candidate)', () async {
    final r = await _rig();
    r.capability.record(
      5,
      const OverlayLinkCapabilities(supportedFeatures: 0x01),
      OverlayCapabilityObservationSource.linkFrame,
    );
    final result = await r.dispatcher.submit(
      peerEndpointHint: _hint(1),
      peerNodeNum: 5,
      payload: Uint8List(0),
    );
    expect(result.outcome, OverlayResourceDispatchOutcome.rejected);
    expect(result.reason, OverlayResourceDispatchReason.badPayload);
    await r.engine.dispose();
  });

  test('OverlayFeatureFlags.resourceActive encodes the dependency rule', () {
    // resource=true, link=false → NOT active.
    const rOnLinkOff = OverlayFeatureFlags(
      linkEnabled: false,
      resourceEnabled: true,
    );
    expect(rOnLinkOff.resourceActive, isFalse);

    // resource=false, link=true → NOT active.
    const rOffLinkOn = OverlayFeatureFlags(
      linkEnabled: true,
      resourceEnabled: false,
    );
    expect(rOffLinkOn.resourceActive, isFalse);

    // Both on → active.
    const bothOn = OverlayFeatureFlags(
      linkEnabled: true,
      resourceEnabled: true,
    );
    expect(bothOn.resourceActive, isTrue);
  });
}
