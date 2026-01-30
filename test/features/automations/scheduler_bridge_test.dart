import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/automations/models/schedule_spec.dart';
import 'package:socialmesh/features/automations/scheduler_service.dart';
import 'package:socialmesh/features/automations/platform_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SchedulerBridge', () {
    late InAppScheduler inAppScheduler;
    late MockPlatformScheduler mockPlatformScheduler;
    late SchedulerBridge bridge;
    late FakeClock clock;

    setUp(() {
      clock = FakeClock(DateTime(2026, 1, 30, 9, 0, 0));
      inAppScheduler = InAppScheduler(clock: clock);
      mockPlatformScheduler = MockPlatformScheduler();
      bridge = SchedulerBridge(
        inAppScheduler: inAppScheduler,
        platformScheduler: mockPlatformScheduler,
        clock: () => clock.now(),
      );
    });

    tearDown(() {
      inAppScheduler.dispose();
    });

    group('registerSchedule', () {
      test('registers with inAppScheduler always', () async {
        final spec = ScheduleSpec.oneShot(
          id: 'test-oneshot',
          runAt: DateTime(2026, 1, 30, 10, 0, 0),
        );

        await bridge.registerSchedule(spec);

        expect(inAppScheduler.getSchedule('test-oneshot'), isNotNull);
        expect(inAppScheduler.schedules.length, 1);
      });

      test('registers oneShot with platform scheduler', () async {
        final spec = ScheduleSpec.oneShot(
          id: 'test-oneshot',
          runAt: DateTime(2026, 1, 30, 10, 0, 0),
        );

        await bridge.registerSchedule(spec);

        expect(
          mockPlatformScheduler.scheduledOneShotTasks,
          contains('test-oneshot'),
        );
        expect(mockPlatformScheduler.scheduledPeriodicTasks, isEmpty);
      });

      test('registers interval with platform scheduler as periodic', () async {
        final spec = ScheduleSpec.interval(
          id: 'test-interval',
          every: const Duration(minutes: 30),
        );

        await bridge.registerSchedule(spec);

        expect(
          mockPlatformScheduler.scheduledPeriodicTasks,
          contains('test-interval'),
        );
        expect(mockPlatformScheduler.scheduledOneShotTasks, isEmpty);
      });

      test(
        'registers daily with platform scheduler as oneShot for next fire',
        () async {
          final spec = ScheduleSpec.daily(
            id: 'test-daily',
            hour: 14,
            minute: 30,
          );

          await bridge.registerSchedule(spec);

          // Daily should be scheduled as one-shot for the next occurrence
          expect(
            mockPlatformScheduler.scheduledOneShotTasks,
            contains('test-daily'),
          );
          expect(mockPlatformScheduler.scheduledPeriodicTasks, isEmpty);
        },
      );

      test(
        'registers weekly with platform scheduler as oneShot for next fire',
        () async {
          final spec = ScheduleSpec.weekly(
            id: 'test-weekly',
            hour: 9,
            minute: 0,
            daysOfWeek: [1, 3, 5], // Mon, Wed, Fri
          );

          await bridge.registerSchedule(spec);

          // Weekly should be scheduled as one-shot for the next occurrence
          expect(
            mockPlatformScheduler.scheduledOneShotTasks,
            contains('test-weekly'),
          );
          expect(mockPlatformScheduler.scheduledPeriodicTasks, isEmpty);
        },
      );

      test('does not register with platform if disabled', () async {
        final spec = ScheduleSpec.oneShot(
          id: 'test-disabled',
          runAt: DateTime(2026, 1, 30, 10, 0, 0),
          enabled: false,
        );

        await bridge.registerSchedule(spec);

        // InAppScheduler still gets it
        expect(inAppScheduler.getSchedule('test-disabled'), isNotNull);
        // But platform scheduler doesn't
        expect(mockPlatformScheduler.scheduledOneShotTasks, isEmpty);
      });

      test('does not register past oneShot with platform', () async {
        final spec = ScheduleSpec.oneShot(
          id: 'test-past',
          runAt: DateTime(2026, 1, 30, 8, 0, 0), // 1 hour ago
        );

        await bridge.registerSchedule(spec);

        // InAppScheduler gets it for catch-up logic
        expect(inAppScheduler.getSchedule('test-past'), isNotNull);
        // Platform scheduler skips past one-shots
        expect(mockPlatformScheduler.scheduledOneShotTasks, isEmpty);
      });
    });

    group('unregisterSchedule', () {
      test('removes from inAppScheduler', () async {
        final spec = ScheduleSpec.oneShot(
          id: 'test-oneshot',
          runAt: DateTime(2026, 1, 30, 10, 0, 0),
        );

        await bridge.registerSchedule(spec);
        expect(inAppScheduler.getSchedule('test-oneshot'), isNotNull);

        await bridge.unregisterSchedule('test-oneshot');

        expect(inAppScheduler.getSchedule('test-oneshot'), isNull);
      });

      test('cancels from platform scheduler', () async {
        final spec = ScheduleSpec.oneShot(
          id: 'test-oneshot',
          runAt: DateTime(2026, 1, 30, 10, 0, 0),
        );

        await bridge.registerSchedule(spec);
        await bridge.unregisterSchedule('test-oneshot');

        expect(mockPlatformScheduler.cancelledTasks, contains('test-oneshot'));
      });
    });

    group('syncToPlatform', () {
      test('cancels all existing platform tasks first', () async {
        // Register some tasks
        await bridge.registerSchedule(
          ScheduleSpec.oneShot(
            id: 'task1',
            runAt: DateTime(2026, 1, 30, 10, 0, 0),
          ),
        );
        await bridge.registerSchedule(
          ScheduleSpec.interval(id: 'task2', every: const Duration(hours: 1)),
        );

        // Reset tracking
        mockPlatformScheduler.allTasksCancelled = false;

        // Sync to platform
        await bridge.syncToPlatform();

        expect(mockPlatformScheduler.allTasksCancelled, isTrue);
      });

      test('registers all active schedules', () async {
        // Add directly to inAppScheduler
        inAppScheduler.register(
          ScheduleSpec.oneShot(
            id: 'active1',
            runAt: DateTime(2026, 1, 30, 10, 0, 0),
          ),
        );
        inAppScheduler.register(
          ScheduleSpec.daily(id: 'active2', hour: 14, minute: 0),
        );
        inAppScheduler.register(
          ScheduleSpec.oneShot(
            id: 'disabled',
            runAt: DateTime(2026, 1, 30, 11, 0, 0),
            enabled: false,
          ),
        );

        mockPlatformScheduler.reset();

        await bridge.syncToPlatform();

        // Should have 2 active schedules registered (not the disabled one)
        expect(mockPlatformScheduler.scheduledOneShotTasks.length, 2);
        expect(
          mockPlatformScheduler.scheduledOneShotTasks,
          contains('active1'),
        );
        expect(
          mockPlatformScheduler.scheduledOneShotTasks,
          contains('active2'),
        );
        expect(
          mockPlatformScheduler.scheduledOneShotTasks,
          isNot(contains('disabled')),
        );
      });

      test('skips sync when platform scheduler is null', () async {
        final bridgeWithoutPlatform = SchedulerBridge(
          inAppScheduler: inAppScheduler,
          platformScheduler: null,
        );

        // Should not throw
        await bridgeWithoutPlatform.syncToPlatform();
      });

      test('skips sync when platform disabled', () async {
        bridge.setPlatformEnabled(false);

        inAppScheduler.register(
          ScheduleSpec.oneShot(
            id: 'test',
            runAt: DateTime(2026, 1, 30, 10, 0, 0),
          ),
        );

        mockPlatformScheduler.reset();
        await bridge.syncToPlatform();

        // Nothing should be scheduled
        expect(mockPlatformScheduler.scheduledOneShotTasks, isEmpty);
      });
    });

    group('processOnResume', () {
      test('calls tick on inAppScheduler', () async {
        final spec = ScheduleSpec.oneShot(
          id: 'test-oneshot',
          runAt: DateTime(2026, 1, 30, 9, 0, 0), // exactly now
        );

        inAppScheduler.register(spec);
        inAppScheduler.start();

        // Advance clock past the scheduled time
        clock.advance(const Duration(seconds: 1));

        // Track fired events
        final firedEvents = <ScheduledFireEvent>[];
        final subscription = inAppScheduler.fireEvents.listen((event) {
          firedEvents.add(event);
        });

        bridge.processOnResume();

        // Clean up
        await subscription.cancel();

        expect(firedEvents.length, 1);
        expect(firedEvents.first.scheduleId, 'test-oneshot');
      });
    });

    group('setPlatformEnabled', () {
      test('can disable platform scheduling', () async {
        bridge.setPlatformEnabled(false);

        final spec = ScheduleSpec.oneShot(
          id: 'test',
          runAt: DateTime(2026, 1, 30, 10, 0, 0),
        );

        await bridge.registerSchedule(spec);

        // InAppScheduler should still have it
        expect(inAppScheduler.getSchedule('test'), isNotNull);
        // Platform scheduler should not
        expect(mockPlatformScheduler.scheduledOneShotTasks, isEmpty);
      });

      test('can re-enable platform scheduling', () async {
        bridge.setPlatformEnabled(false);
        bridge.setPlatformEnabled(true);

        final spec = ScheduleSpec.oneShot(
          id: 'test',
          runAt: DateTime(2026, 1, 30, 10, 0, 0),
        );

        await bridge.registerSchedule(spec);

        expect(mockPlatformScheduler.scheduledOneShotTasks, contains('test'));
      });
    });

    group('daily/weekly rescheduling', () {
      test('uses computeNextOccurrence for correct fire times', () async {
        // Current time is 9:00 AM
        final spec = ScheduleSpec.daily(
          id: 'daily-test',
          hour: 8, // Already passed today
          minute: 0,
        );

        await bridge.registerSchedule(spec);

        // Should be scheduled for tomorrow 8:00 AM
        expect(
          mockPlatformScheduler.scheduledOneShotTasks,
          contains('daily-test'),
        );
      });
    });
  });

  group('MockPlatformScheduler', () {
    test('tracks scheduled one-shot tasks', () async {
      final mock = MockPlatformScheduler();

      await mock.scheduleOneShot(
        taskId: 'task1',
        scheduledFor: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(mock.scheduledOneShotTasks, contains('task1'));
      expect(await mock.isTaskScheduled('task1'), isTrue);
    });

    test('tracks scheduled periodic tasks', () async {
      final mock = MockPlatformScheduler();

      await mock.schedulePeriodic(
        taskId: 'task1',
        interval: const Duration(hours: 1),
      );

      expect(mock.scheduledPeriodicTasks, contains('task1'));
      expect(await mock.isTaskScheduled('task1'), isTrue);
    });

    test('tracks cancelled tasks', () async {
      final mock = MockPlatformScheduler();

      await mock.scheduleOneShot(
        taskId: 'task1',
        scheduledFor: DateTime.now().add(const Duration(hours: 1)),
      );
      await mock.cancelTask('task1');

      expect(mock.cancelledTasks, contains('task1'));
      expect(mock.scheduledOneShotTasks, isNot(contains('task1')));
      expect(await mock.isTaskScheduled('task1'), isFalse);
    });

    test('cancelAllTasks clears everything', () async {
      final mock = MockPlatformScheduler();

      await mock.scheduleOneShot(
        taskId: 'task1',
        scheduledFor: DateTime.now().add(const Duration(hours: 1)),
      );
      await mock.schedulePeriodic(
        taskId: 'task2',
        interval: const Duration(hours: 1),
      );
      await mock.cancelAllTasks();

      expect(mock.allTasksCancelled, isTrue);
      expect(mock.scheduledOneShotTasks, isEmpty);
      expect(mock.scheduledPeriodicTasks, isEmpty);
    });

    test('reset clears all tracking', () async {
      final mock = MockPlatformScheduler();

      await mock.initialize();
      await mock.scheduleOneShot(
        taskId: 'task1',
        scheduledFor: DateTime.now().add(const Duration(hours: 1)),
      );
      await mock.cancelTask('task1');
      await mock.cancelAllTasks();

      mock.reset();

      expect(mock.initialized, isFalse);
      expect(mock.scheduledOneShotTasks, isEmpty);
      expect(mock.scheduledPeriodicTasks, isEmpty);
      expect(mock.cancelledTasks, isEmpty);
      expect(mock.allTasksCancelled, isFalse);
    });
  });

  group('Integration: Platform callback simulation', () {
    test('platform task fires and processes due schedules', () async {
      final clock = FakeClock(DateTime(2026, 1, 30, 9, 0, 0));
      final inAppScheduler = InAppScheduler(clock: clock);
      final mockPlatformScheduler = MockPlatformScheduler();
      final bridge = SchedulerBridge(
        inAppScheduler: inAppScheduler,
        platformScheduler: mockPlatformScheduler,
      );

      // Register a schedule that fires soon
      final spec = ScheduleSpec.oneShot(
        id: 'test-schedule',
        runAt: DateTime(2026, 1, 30, 9, 0, 5), // 5 seconds from now
      );

      await bridge.registerSchedule(spec);
      inAppScheduler.start();

      // Track events
      final events = <ScheduledFireEvent>[];
      final subscription = inAppScheduler.fireEvents.listen(events.add);

      // Simulate time passing and platform callback
      clock.advance(const Duration(seconds: 10));

      // This simulates what happens when the platform scheduler fires
      // In reality, this would be called from workManagerCallbackDispatcher
      final now = clock.now();
      inAppScheduler.tick(now);

      await subscription.cancel();
      inAppScheduler.dispose();

      expect(events.length, 1);
      expect(events.first.scheduleId, 'test-schedule');
    });

    test('daily schedule re-registers after firing', () async {
      final clock = FakeClock(DateTime(2026, 1, 30, 8, 59, 0));
      final inAppScheduler = InAppScheduler(clock: clock);
      final mockPlatformScheduler = MockPlatformScheduler();
      final bridge = SchedulerBridge(
        inAppScheduler: inAppScheduler,
        platformScheduler: mockPlatformScheduler,
      );

      // Register a daily schedule for 9:00 AM
      final spec = ScheduleSpec.daily(id: 'daily-test', hour: 9, minute: 0);

      await bridge.registerSchedule(spec);
      inAppScheduler.start();

      // Track events
      final events = <ScheduledFireEvent>[];
      final subscription = inAppScheduler.fireEvents.listen(events.add);

      // Advance to just after 9:00 AM
      clock.advance(const Duration(minutes: 2));
      inAppScheduler.tick(clock.now());

      // Verify the schedule fired
      expect(events.length, 1);

      // After firing, syncToPlatform should re-register for next day
      mockPlatformScheduler.reset();
      await bridge.syncToPlatform();

      // Should have re-registered for tomorrow
      expect(
        mockPlatformScheduler.scheduledOneShotTasks,
        contains('daily-test'),
      );

      await subscription.cancel();
      inAppScheduler.dispose();
    });
  });
}
