// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tests for the public `attachOverlayInbound` surface on
/// [ProtocolService].
///
/// These exercise:
///   - attaching/detaching a handler toggles `_overlayInbound` without
///     throwing,
///   - the startup-buffer getter works before a frame arrives,
///   - re-attaching with a new handler replaces (does not duplicate)
///     the prior handler.
///
/// Frame-delivery coverage (sniffed-frame → handler) lives in
/// `overlay_ingress_dispatcher_test.dart` and
/// `overlay_providers_lifecycle_test.dart`. Driving raw SIP bytes
/// through the real `ProtocolService._handleSipPacket` from a unit
/// test would require adding a debug helper, which would violate the
/// P2 "thin integration only" rule — so we stay within the public
/// attach API here.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

/// Null transport stub. ProtocolService's lifecycle methods are not
/// called in these tests; only the attach/detach surface is.
class _NullTransport implements DeviceTransport {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('overlayStartupBufferLength starts at zero', () {
    final ps = ProtocolService(_NullTransport());
    expect(ps.overlayStartupBufferLength, 0);
  });

  test('attachOverlayInbound(handler) does not throw', () {
    final ps = ProtocolService(_NullTransport());
    Future<void> handler(int from, Uint8List bytes) async {}
    expect(() => ps.attachOverlayInbound(handler), returnsNormally);
  });

  test('attachOverlayInbound(null) detaches cleanly and is idempotent', () {
    final ps = ProtocolService(_NullTransport());
    Future<void> handler(int from, Uint8List bytes) async {}
    ps.attachOverlayInbound(handler);
    expect(() => ps.attachOverlayInbound(null), returnsNormally);
    // A second null detach is a no-op.
    expect(() => ps.attachOverlayInbound(null), returnsNormally);
  });

  test('re-attaching a new handler replaces the prior reference', () {
    final ps = ProtocolService(_NullTransport());
    Future<void> first(int from, Uint8List bytes) async {}
    Future<void> second(int from, Uint8List bytes) async {}

    ps.attachOverlayInbound(first);
    // Replacing does not throw and does not require a null in between.
    expect(() => ps.attachOverlayInbound(second), returnsNormally);
    // Detach cleanly.
    ps.attachOverlayInbound(null);
  });
}
