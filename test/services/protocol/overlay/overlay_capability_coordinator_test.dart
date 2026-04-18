// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tests for [OverlayCapabilityCoordinator].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_capability_coordinator.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_models.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_types.dart';

import '_overlay_link_test_harness.dart';

OverlayLinkCapabilities _linkOnly() => const OverlayLinkCapabilities(
  supportedFeatures: OverlayCapabilityFeature.linkV02,
);

void main() {
  test('record + forPeer roundtrip', () {
    final clock = FakeClock();
    final c = OverlayCapabilityCoordinator(clock: clock.now);
    c.record(42, _linkOnly(), OverlayCapabilityObservationSource.capBeacon);
    final snap = c.forPeer(42)!;
    expect(snap.supportsLink, isTrue);
    expect(snap.source, OverlayCapabilityObservationSource.capBeacon);
    expect(snap.observedAtMs, clock.now());
  });

  test('later observation overwrites earlier for same peer', () {
    final clock = FakeClock();
    final c = OverlayCapabilityCoordinator(clock: clock.now);
    c.record(7, _linkOnly(), OverlayCapabilityObservationSource.capBeacon);
    final t0 = c.forPeer(7)!.observedAtMs;

    clock.advanceMs(5_000);
    c.record(7, _linkOnly(), OverlayCapabilityObservationSource.linkFrame);
    final snap = c.forPeer(7)!;
    expect(snap.source, OverlayCapabilityObservationSource.linkFrame);
    expect(snap.observedAtMs, greaterThan(t0));
  });

  test('isLinkCapable reflects supportedFeatures bit', () {
    final c = OverlayCapabilityCoordinator(clock: FakeClock().now);
    expect(c.isLinkCapable(99), isFalse);
    c.record(99, _linkOnly(), OverlayCapabilityObservationSource.linkFrame);
    expect(c.isLinkCapable(99), isTrue);

    // Peer with no features bit remains non-capable even with a snapshot.
    c.record(
      100,
      const OverlayLinkCapabilities(supportedFeatures: 0),
      OverlayCapabilityObservationSource.capBeacon,
    );
    expect(c.isLinkCapable(100), isFalse);
  });

  test('forget removes the snapshot', () {
    final c = OverlayCapabilityCoordinator(clock: FakeClock().now);
    c.record(1, _linkOnly(), OverlayCapabilityObservationSource.linkFrame);
    expect(c.forPeer(1), isNotNull);
    c.forget(1);
    expect(c.forPeer(1), isNull);
  });

  test('dispose clears all + rejects further records', () {
    final c = OverlayCapabilityCoordinator(clock: FakeClock().now);
    c.record(1, _linkOnly(), OverlayCapabilityObservationSource.linkFrame);
    c.record(2, _linkOnly(), OverlayCapabilityObservationSource.linkFrame);
    expect(c.snapshotCount, 2);
    c.dispose();
    expect(c.snapshotCount, 0);
    // Post-dispose records are no-ops.
    c.record(3, _linkOnly(), OverlayCapabilityObservationSource.linkFrame);
    expect(c.snapshotCount, 0);
  });

  test('debugSnapshot returns a copy (no back-reference)', () {
    final c = OverlayCapabilityCoordinator(clock: FakeClock().now);
    c.record(1, _linkOnly(), OverlayCapabilityObservationSource.linkFrame);
    final view = c.debugSnapshot();
    expect(view, hasLength(1));
    view.remove(1);
    expect(c.snapshotCount, 1);
  });
}
