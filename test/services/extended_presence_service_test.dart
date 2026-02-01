// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/models/presence_confidence.dart';
import 'package:socialmesh/services/extended_presence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Mock SharedPreferences for tests that need it
    SharedPreferences.setMockInitialValues({});
  });

  group('ExtendedPresenceService rate limiting', () {
    group('shouldBroadcast', () {
      test('returns false for empty info', () {
        final service = ExtendedPresenceService();
        const info = ExtendedPresenceInfo();

        // Empty info should never broadcast
        expect(service.shouldBroadcast(info), isFalse);
      });

      test('returns true for first broadcast with data', () {
        final service = ExtendedPresenceService();
        const info = ExtendedPresenceInfo(intent: PresenceIntent.available);

        expect(service.shouldBroadcast(info), isTrue);
      });

      test('returns false for same info after recordBroadcast', () async {
        final service = ExtendedPresenceService();
        const info = ExtendedPresenceInfo(intent: PresenceIntent.available);

        expect(service.shouldBroadcast(info), isTrue);
        await service.recordBroadcast(info);

        // Same info, immediately after
        expect(service.shouldBroadcast(info), isFalse);
      });

      test('returns true for changed info even within interval', () async {
        final service = ExtendedPresenceService();
        const info1 = ExtendedPresenceInfo(intent: PresenceIntent.available);
        const info2 = ExtendedPresenceInfo(intent: PresenceIntent.camping);

        await service.recordBroadcast(info1);

        // Different info should always broadcast
        expect(service.shouldBroadcast(info2), isTrue);
      });

      test('returns true for changed status', () async {
        final service = ExtendedPresenceService();
        const info1 = ExtendedPresenceInfo(
          intent: PresenceIntent.available,
          shortStatus: 'Hello',
        );
        const info2 = ExtendedPresenceInfo(
          intent: PresenceIntent.available,
          shortStatus: 'World',
        );

        await service.recordBroadcast(info1);
        expect(service.shouldBroadcast(info2), isTrue);
      });
    });

    group('minBroadcastInterval', () {
      test('is 15 minutes', () {
        expect(
          ExtendedPresenceService.minBroadcastInterval,
          equals(const Duration(minutes: 15)),
        );
      });
    });
  });

  group('ExtendedPresenceService remote cache', () {
    test('handleRemotePresence stores value', () {
      final service = ExtendedPresenceService();
      const info = ExtendedPresenceInfo(
        intent: PresenceIntent.camping,
        shortStatus: 'Basecamp',
      );

      service.handleRemotePresence(123, info);

      final cached = service.getRemotePresence(123);
      expect(cached, isNotNull);
      expect(cached!.intent, PresenceIntent.camping);
      expect(cached.shortStatus, 'Basecamp');
    });

    test('getRemotePresence returns null for unknown node', () {
      final service = ExtendedPresenceService();
      final cached = service.getRemotePresence(999);
      expect(cached, isNull);
    });

    test('handleRemotePresence removes entry for empty info', () {
      final service = ExtendedPresenceService();

      // First add an entry
      service.handleRemotePresence(
        42,
        const ExtendedPresenceInfo(intent: PresenceIntent.traveling),
      );
      expect(service.getRemotePresence(42), isNotNull);

      // Remove with empty info
      service.handleRemotePresence(42, const ExtendedPresenceInfo());
      expect(service.getRemotePresence(42), isNull);
    });

    test('allRemotePresence returns unmodifiable map', () {
      final service = ExtendedPresenceService();
      service.handleRemotePresence(
        1,
        const ExtendedPresenceInfo(intent: PresenceIntent.available),
      );
      service.handleRemotePresence(
        2,
        const ExtendedPresenceInfo(intent: PresenceIntent.camping),
      );

      final all = service.allRemotePresence;
      expect(all.length, 2);
      expect(all[1]?.intent, PresenceIntent.available);
      expect(all[2]?.intent, PresenceIntent.camping);

      // Should be unmodifiable
      expect(
        () => all[3] = const ExtendedPresenceInfo(),
        throwsUnsupportedError,
      );
    });

    test('remoteUpdates stream emits on handleRemotePresence', () async {
      final service = ExtendedPresenceService();
      final updates = <(int, ExtendedPresenceInfo)>[];

      final subscription = service.remoteUpdates.listen(updates.add);

      service.handleRemotePresence(
        42,
        const ExtendedPresenceInfo(intent: PresenceIntent.relayNode),
      );

      // Wait for stream to emit
      await Future<void>.delayed(Duration.zero);

      expect(updates.length, 1);
      expect(updates[0].$1, 42);
      expect(updates[0].$2.intent, PresenceIntent.relayNode);

      await subscription.cancel();
      service.dispose();
    });

    test('handleRemotePresence deduplicates unchanged info', () async {
      final service = ExtendedPresenceService();
      final updates = <(int, ExtendedPresenceInfo)>[];

      final subscription = service.remoteUpdates.listen(updates.add);

      const info = ExtendedPresenceInfo(intent: PresenceIntent.passive);

      // Same info twice
      service.handleRemotePresence(42, info);
      service.handleRemotePresence(42, info);

      await Future<void>.delayed(Duration.zero);

      // Should only emit once
      expect(updates.length, 1);

      await subscription.cancel();
      service.dispose();
    });
  });

  group('ExtendedPresenceService cleanup', () {
    test('dispose cancels scheduled saves', () {
      final service = ExtendedPresenceService();

      // Add some data that would trigger a scheduled save
      service.handleRemotePresence(
        1,
        const ExtendedPresenceInfo(intent: PresenceIntent.available),
      );

      // Dispose should not throw
      expect(() => service.dispose(), returnsNormally);
    });
  });
}
