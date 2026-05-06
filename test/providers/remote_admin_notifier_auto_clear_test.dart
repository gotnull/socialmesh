// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tests for `RemoteAdminNotifier`'s auto-clear-on-disconnect invariant.
///
/// Mirrors the iOS Settings picker reset on disconnect: a remote admin
/// target must not survive a connection loss, otherwise the next reconnect
/// would silently dispatch admin writes to a stale remote and (worse)
/// inject the wrong session passkey.
///
/// Implementation: `RemoteAdminNotifier.build()` registers a
/// `ref.listen<AsyncValue<DeviceConnectionState>>` on
/// `connectionStateProvider` and clears state when a transition from
/// connected → disconnected is observed while a remote target is set.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/providers/app_providers.dart';

ProviderContainer _createContainer(
  StreamController<DeviceConnectionState> connectionController,
) {
  return ProviderContainer(
    overrides: [
      connectionStateProvider.overrideWith(
        (ref) => connectionController.stream,
      ),
    ],
  );
}

void main() {
  group('RemoteAdminNotifier auto-clear on disconnect', () {
    late StreamController<DeviceConnectionState> connectionController;
    late ProviderContainer container;

    setUp(() {
      connectionController =
          StreamController<DeviceConnectionState>.broadcast();
      container = _createContainer(connectionController);
    });

    tearDown(() async {
      container.dispose();
      await connectionController.close();
    });

    test('initial state has no remote target', () {
      final state = container.read(remoteAdminProvider);
      expect(state.targetNodeNum, isNull);
      expect(state.targetNodeName, isNull);
      expect(state.isRemote, isFalse);
      expect(container.read(remoteAdminTargetProvider), isNull);
    });

    test('setTarget then disconnect clears the remote admin state', () async {
      // Force RemoteAdminNotifier.build() so its ref.listen on
      // connectionStateProvider is registered before we emit anything.
      container.read(remoteAdminProvider);
      // Keep the StreamProvider hot so emissions are observed by the
      // ref.listen inside RemoteAdminNotifier.
      container.listen<AsyncValue<DeviceConnectionState>>(
        connectionStateProvider,
        (_, _) {},
      );

      connectionController.add(DeviceConnectionState.connected);
      await container.read(connectionStateProvider.future);
      expect(
        container.read(connectionStateProvider).asData?.value,
        equals(DeviceConnectionState.connected),
      );

      const remoteNum = 0x12345678;
      container
          .read(remoteAdminProvider.notifier)
          .setTarget(remoteNum, 'Remote Test Node');
      expect(
        container.read(remoteAdminProvider).targetNodeNum,
        equals(remoteNum),
      );
      expect(container.read(remoteAdminTargetProvider), equals(remoteNum));

      connectionController.add(DeviceConnectionState.disconnected);
      // Two microtask drains: one for the StreamProvider to receive the
      // event, one for ref.listen in RemoteAdminNotifier to fire.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final cleared = container.read(remoteAdminProvider);
      expect(
        cleared.targetNodeNum,
        isNull,
        reason:
            'iOS Settings picker resets on disconnect — SocialMesh must '
            'mirror this so a stale remote target cannot survive a '
            'reconnect cycle and silently route admin writes to the '
            'wrong node.',
      );
      expect(cleared.targetNodeName, isNull);
      expect(cleared.isRemote, isFalse);
      expect(container.read(remoteAdminTargetProvider), isNull);
    });

    test(
      'disconnect with no remote target set is a no-op (does not crash)',
      () async {
        connectionController.add(DeviceConnectionState.connected);
        container.read(connectionStateProvider);
        await Future<void>.delayed(Duration.zero);

        connectionController.add(DeviceConnectionState.disconnected);
        await Future<void>.delayed(Duration.zero);

        final state = container.read(remoteAdminProvider);
        expect(state.targetNodeNum, isNull);
        expect(state.isRemote, isFalse);
      },
    );

    test(
      'disconnect without a prior connected event does NOT clear the target',
      () async {
        // Skip any "connected" event — this models the case where the app
        // boots already-disconnected. The auto-clear guard requires
        // wasConnected==true, so an initial disconnect must not trigger
        // a spurious clear of an explicitly-set target.
        const remoteNum = 0x87654321;
        container
            .read(remoteAdminProvider.notifier)
            .setTarget(remoteNum, 'Pre-Connect Remote');

        connectionController.add(DeviceConnectionState.disconnected);
        await Future<void>.delayed(Duration.zero);

        final state = container.read(remoteAdminProvider);
        expect(
          state.targetNodeNum,
          equals(remoteNum),
          reason:
              'No prior connected → disconnected transition was observed; '
              'the auto-clear must not fire on a cold-boot disconnect.',
        );
      },
    );

    test('clearTarget always resets state regardless of connection', () {
      const remoteNum = 0xCAFEBABE;
      container
          .read(remoteAdminProvider.notifier)
          .setTarget(remoteNum, 'Manual Clear Test');
      expect(container.read(remoteAdminProvider).isRemote, isTrue);

      container.read(remoteAdminProvider.notifier).clearTarget();

      final state = container.read(remoteAdminProvider);
      expect(state.targetNodeNum, isNull);
      expect(state.isRemote, isFalse);
    });
  });
}
