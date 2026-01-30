import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/automations/models/schedule_spec.dart';
import 'package:socialmesh/features/automations/scheduler_service.dart';
import 'package:socialmesh/features/automations/automation_engine.dart';
import 'package:socialmesh/features/automations/automation_repository.dart';
import 'package:socialmesh/features/automations/models/automation.dart';
import 'package:socialmesh/services/ifttt/ifttt_service.dart';

/// Mock repository for testing scheduled triggers
class MockSchedulerRepository extends AutomationRepository {
  final List<Automation> _testAutomations = [];
  final List<ScheduleSpec> _testSchedules = [];
  final List<String> recordedTriggerIds = [];
  final List<AutomationLogEntry> _testLog = [];

  @override
  List<Automation> get automations => List.unmodifiable(_testAutomations);

  @override
  List<ScheduleSpec> get schedules => List.unmodifiable(_testSchedules);

  @override
  List<AutomationLogEntry> get log => List.unmodifiable(_testLog);

  void addTestAutomation(Automation automation) {
    _testAutomations.add(automation);
  }

  void addTestSchedule(ScheduleSpec schedule) {
    _testSchedules.add(schedule);
  }

  void clearTestData() {
    _testAutomations.clear();
    _testSchedules.clear();
    _testLog.clear();
  }

  @override
  Future<void> recordTrigger(String id) async {
    recordedTriggerIds.add(id);
  }

  @override
  Future<void> addLogEntry(AutomationLogEntry entry) async {
    _testLog.insert(0, entry);
  }

  @override
  Future<void> persistSchedules(List<ScheduleSpec> schedules) async {
    _testSchedules.clear();
    _testSchedules.addAll(schedules);
  }

  @override
  Future<List<ScheduleSpec>> loadSchedules() async {
    return List.from(_testSchedules);
  }
}

/// Mock IFTTT service for testing
class MockSchedulerIftttService extends IftttService {
  @override
  bool get isActive => false;

  @override
  Future<bool> testWebhook() async => false;

  @override
  Future<bool> triggerCustomEvent({
    required String eventName,
    String? value1,
    String? value2,
    String? value3,
  }) async {
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScheduleSpec Model', () {
    test('oneShot factory creates valid spec', () {
      final runAt = DateTime(2026, 1, 30, 9, 0, 0);
      final spec = ScheduleSpec.oneShot(id: 'test-oneshot', runAt: runAt);

      expect(spec.id, 'test-oneshot');
      expect(spec.kind, ScheduleKind.oneShot);
      expect(spec.runAt, runAt);
      expect(spec.tz, 'Australia/Melbourne');
    });

    test('interval factory creates valid spec', () {
      final spec = ScheduleSpec.interval(
        id: 'test-interval',
        every: const Duration(minutes: 1),
      );

      expect(spec.id, 'test-interval');
      expect(spec.kind, ScheduleKind.interval);
      expect(spec.every, const Duration(minutes: 1));
    });

    test('interval enforces minimum duration', () {
      expect(
        () => ScheduleSpec.interval(every: const Duration(seconds: 5)),
        throwsA(isA<AssertionError>()),
      );
    });

    test('daily factory creates valid spec', () {
      final spec = ScheduleSpec.daily(id: 'test-daily', hour: 9, minute: 0);

      expect(spec.id, 'test-daily');
      expect(spec.kind, ScheduleKind.daily);
      expect(spec.hour, 9);
      expect(spec.minute, 0);
    });

    test('weekly factory creates valid spec', () {
      final spec = ScheduleSpec.weekly(
        id: 'test-weekly',
        hour: 19,
        minute: 30,
        daysOfWeek: [1], // Monday
      );

      expect(spec.id, 'test-weekly');
      expect(spec.kind, ScheduleKind.weekly);
      expect(spec.hour, 19);
      expect(spec.minute, 30);
      expect(spec.daysOfWeek, [1]);
    });

    test('generateSlotKey for oneShot', () {
      final runAt = DateTime.utc(2026, 1, 30, 9, 0, 0);
      final spec = ScheduleSpec.oneShot(runAt: runAt);

      final slotKey = spec.generateSlotKey(runAt);
      expect(slotKey, startsWith('oneShot:'));
      expect(slotKey, contains('2026-01-30'));
    });

    test('generateSlotKey for interval', () {
      final spec = ScheduleSpec.interval(every: const Duration(minutes: 1));

      final slotKey = spec.generateSlotKey(DateTime.now(), intervalCount: 5);
      expect(slotKey, 'interval:5');
    });

    test('generateSlotKey for daily', () {
      final spec = ScheduleSpec.daily(hour: 9, minute: 0);

      final scheduleFor = DateTime(2026, 1, 30, 9, 0, 0);
      final slotKey = spec.generateSlotKey(scheduleFor);
      expect(slotKey, startsWith('daily:'));
      expect(slotKey, contains('2026-01-30'));
      expect(slotKey, contains('09:00'));
    });

    test('toJson and fromJson roundtrip', () {
      final original = ScheduleSpec.daily(
        id: 'roundtrip-test',
        hour: 9,
        minute: 30,
        tz: 'Australia/Melbourne',
        catchUpPolicy: CatchUpPolicy.lastOnly,
        jitterMs: 100,
      );

      final json = original.toJson();
      final restored = ScheduleSpec.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.kind, original.kind);
      expect(restored.hour, original.hour);
      expect(restored.minute, original.minute);
      expect(restored.tz, original.tz);
      expect(restored.catchUpPolicy, original.catchUpPolicy);
      expect(restored.jitterMs, original.jitterMs);
    });

    test('isActive returns false after oneShot fires', () {
      final spec = ScheduleSpec.oneShot(runAt: DateTime(2026, 1, 30, 9, 0, 0));

      expect(spec.isActive(DateTime(2026, 1, 30, 8, 0, 0)), isTrue);

      final fired = spec.recordFiredSlot(
        'oneShot:2026-01-30T09:00:00.000Z',
        DateTime(2026, 1, 30, 9, 0, 0),
      );

      expect(fired.isActive(DateTime(2026, 1, 30, 10, 0, 0)), isFalse);
    });

    test('applyJitter with seeded random is deterministic', () {
      final spec = ScheduleSpec.oneShot(
        runAt: DateTime(2026, 1, 30, 9, 0, 0),
        jitterMs: 1000,
      );

      final random1 = math.Random(42);
      final random2 = math.Random(42);

      final time1 = spec.applyJitter(DateTime(2026, 1, 30, 9, 0, 0), random1);
      final time2 = spec.applyJitter(DateTime(2026, 1, 30, 9, 0, 0), random2);

      expect(time1, time2);
    });

    test('applyJitter with zero jitter returns original time', () {
      final spec = ScheduleSpec.oneShot(
        runAt: DateTime(2026, 1, 30, 9, 0, 0),
        jitterMs: 0,
      );

      final original = DateTime(2026, 1, 30, 9, 0, 0);
      final result = spec.applyJitter(original, math.Random());

      expect(result, original);
    });
  });

  group('InAppScheduler - One-shot Schedule', () {
    test('fires exactly once at scheduled time', () {
      final clock = FakeClock(DateTime(2026, 1, 30, 9, 0, 0));
      final events = <ScheduledFireEvent>[];

      final scheduler = InAppScheduler(clock: clock);

      scheduler.fireEvents.listen(events.add);
      scheduler.start();

      // Register one-shot at T+10s
      final spec = ScheduleSpec.oneShot(
        id: 'test-oneshot',
        runAt: DateTime(2026, 1, 30, 9, 0, 10),
      );
      scheduler.register(spec);

      // Advance to T+9s - should not fire
      clock.advance(const Duration(seconds: 9));
      scheduler.tick(clock.now());
      expect(events, isEmpty);

      // Advance to T+10s - should fire
      clock.advance(const Duration(seconds: 1));
      scheduler.tick(clock.now());
      expect(events.length, 1);
      expect(events.first.scheduleId, 'test-oneshot');
      expect(events.first.slotKey, startsWith('oneShot:'));

      // Advance further - should not fire again
      clock.advance(const Duration(seconds: 10));
      scheduler.tick(clock.now());
      expect(events.length, 1); // Still just 1 event

      scheduler.dispose();
    });

    test('does not fire if time is before scheduled time', () {
      final clock = FakeClock(DateTime(2026, 1, 30, 9, 0, 0));
      final events = <ScheduledFireEvent>[];

      final scheduler = InAppScheduler(clock: clock);
      scheduler.fireEvents.listen(events.add);
      scheduler.start();

      // Register one-shot at T+1h
      final spec = ScheduleSpec.oneShot(
        id: 'future-oneshot',
        runAt: DateTime(2026, 1, 30, 10, 0, 0),
      );
      scheduler.register(spec);

      // Advance by 30 minutes
      clock.advance(const Duration(minutes: 30));
      scheduler.tick(clock.now());

      expect(events, isEmpty);

      scheduler.dispose();
    });
  });

  group('InAppScheduler - Interval Schedule', () {
    test('fires at correct intervals', () {
      final clock = FakeClock(DateTime(2026, 1, 30, 9, 0, 0));
      final events = <ScheduledFireEvent>[];

      final scheduler = InAppScheduler(clock: clock);
      scheduler.fireEvents.listen(events.add);
      scheduler.start();

      // Register interval every 60s
      final spec = ScheduleSpec.interval(
        id: 'test-interval',
        every: const Duration(seconds: 60),
        startAt: DateTime(2026, 1, 30, 9, 0, 0),
      );
      scheduler.register(spec);

      // Advance across 5 minutes
      for (var i = 0; i < 5; i++) {
        clock.advance(const Duration(seconds: 60));
        scheduler.tick(clock.now());
      }

      // Should have 5 events
      expect(events.length, 5);

      // Verify slot keys are sequential
      for (var i = 0; i < 5; i++) {
        expect(events[i].slotKey, 'interval:${i + 1}');
      }

      scheduler.dispose();
    });

    test('respects dedupe across restarts', () {
      final clock = FakeClock(DateTime(2026, 1, 30, 9, 0, 0));
      final events = <ScheduledFireEvent>[];

      var scheduler = InAppScheduler(clock: clock);
      scheduler.fireEvents.listen(events.add);
      scheduler.start();

      // Register interval every 60s
      var spec = ScheduleSpec.interval(
        id: 'test-interval',
        every: const Duration(seconds: 60),
        startAt: DateTime(2026, 1, 30, 9, 0, 0),
      );
      scheduler.register(spec);

      // Fire once
      clock.advance(const Duration(seconds: 60));
      scheduler.tick(clock.now());
      expect(events.length, 1);

      // Get updated spec
      final updatedSpec = scheduler.getSchedule('test-interval')!;
      scheduler.dispose();

      // Create new scheduler (simulating restart)
      events.clear();
      scheduler = InAppScheduler(clock: clock);
      scheduler.fireEvents.listen(events.add);
      scheduler.start();

      // Register with preserved state
      scheduler.register(updatedSpec);

      // Tick at same time - should not re-fire the same slot
      scheduler.tick(clock.now());
      expect(events, isEmpty);

      // Advance to next interval - should fire
      clock.advance(const Duration(seconds: 60));
      scheduler.tick(clock.now());
      expect(events.length, 1);
      expect(events.first.slotKey, 'interval:2');

      scheduler.dispose();
    });
  });

  group('InAppScheduler - Daily Schedule', () {
    test('fires daily at correct time', () {
      // Start at 8:59 on Jan 30
      final clock = FakeClock(DateTime(2026, 1, 30, 8, 59, 0));
      final events = <ScheduledFireEvent>[];

      final scheduler = InAppScheduler(clock: clock);
      scheduler.fireEvents.listen(events.add);
      scheduler.start();

      // Register daily at 09:00
      final spec = ScheduleSpec.daily(id: 'test-daily', hour: 9, minute: 0);
      scheduler.register(spec);

      // Advance 1 minute - should fire
      clock.advance(const Duration(minutes: 1));
      scheduler.tick(clock.now());
      expect(events.length, 1);
      expect(events.first.slotKey, contains('09:00'));

      // Advance 23 hours 59 minutes - no new fire yet
      clock.advance(const Duration(hours: 23, minutes: 59));
      scheduler.tick(clock.now());
      expect(events.length, 1);

      // Advance 1 more minute to next day 09:00 - should fire again
      clock.advance(const Duration(minutes: 1));
      scheduler.tick(clock.now());
      expect(events.length, 2);

      scheduler.dispose();
    });

    test('fires on consecutive days', () {
      // Simple test: daily schedule fires each day
      final clock = FakeClock(DateTime(2026, 1, 30, 8, 59, 0));
      final events = <ScheduledFireEvent>[];

      final scheduler = InAppScheduler(clock: clock);
      scheduler.fireEvents.listen(events.add);
      scheduler.start();

      // Register daily at 09:00
      final spec = ScheduleSpec.daily(
        id: 'consecutive-test',
        hour: 9,
        minute: 0,
      );
      scheduler.register(spec);

      // Day 1: Jan 30 09:00
      clock.advance(const Duration(minutes: 1));
      scheduler.tick(clock.now());
      expect(events.length, 1);
      expect(events.first.slotKey, contains('2026-01-30'));

      // Day 2: Jan 31 09:00
      clock.advance(const Duration(hours: 24));
      scheduler.tick(clock.now());
      expect(events.length, 2);
      expect(events.last.slotKey, contains('2026-01-31'));

      // Verify exactly one fire per day
      final slotDates = events.map((e) => e.slotKey.split('T')[0]).toSet();
      expect(slotDates.length, 2);

      scheduler.dispose();
    });

    test('fires exactly once per day even with large time jump', () {
      final clock = FakeClock(DateTime(2026, 1, 30, 9, 0, 0));
      final events = <ScheduledFireEvent>[];

      final scheduler = InAppScheduler(clock: clock);
      scheduler.fireEvents.listen(events.add);
      scheduler.start();

      final spec = ScheduleSpec.daily(
        id: 'test-daily-jump',
        hour: 9,
        minute: 0,
        catchUpPolicy: CatchUpPolicy.none,
      );
      scheduler.register(spec);

      // Fire today
      scheduler.tick(clock.now());
      expect(events.length, 1);

      // Jump forward 7 days
      clock.advance(const Duration(days: 7));
      scheduler.tick(clock.now());

      // With catchUpPolicy.none (default), large time jumps should NOT blast
      // all intermediate days. It should fire at most 2:
      // - The initial Jan 30 fire
      // - One fire for current time (if within grace period)
      // Since we're jumping to Feb 6 09:00 exactly, that's within 5-min grace
      expect(events.length, 2);
      // Last event should be Feb 6
      expect(events.last.slotKey, contains('2026-02-06'));

      scheduler.dispose();
    });
  });

  group('InAppScheduler - Weekly Schedule', () {
    test('fires only on specified days', () {
      // Jan 30, 2026 is a Friday
      final clock = FakeClock(DateTime(2026, 1, 30, 9, 0, 0));
      final events = <ScheduledFireEvent>[];

      final scheduler = InAppScheduler(clock: clock);
      scheduler.fireEvents.listen(events.add);
      scheduler.start();

      // Register weekly on Monday (1) at 19:30
      final spec = ScheduleSpec.weekly(
        id: 'test-weekly',
        hour: 19,
        minute: 30,
        daysOfWeek: [1], // Monday
      );
      scheduler.register(spec);

      // Today is Friday - shouldn't fire
      scheduler.tick(clock.now());
      expect(events, isEmpty);

      // Advance to Saturday, Sunday - still no fire
      clock.advance(const Duration(days: 2));
      scheduler.tick(clock.now());
      expect(events, isEmpty);

      // Advance to Monday 19:30
      clock.setTime(DateTime(2026, 2, 2, 19, 30, 0));
      scheduler.tick(clock.now());
      expect(events.length, 1);
      expect(events.first.slotKey, contains('19:30'));

      scheduler.dispose();
    });

    test('works with dayOfWeek condition (redundant but validates path)', () {
      // Jan 30, 2026 is a Friday
      final clock = FakeClock(DateTime(2026, 1, 30, 9, 0, 0));
      final events = <ScheduledFireEvent>[];

      final scheduler = InAppScheduler(clock: clock);
      scheduler.fireEvents.listen(events.add);
      scheduler.start();

      // Create automation with weekly schedule AND dayOfWeek condition
      final spec = ScheduleSpec.weekly(
        id: 'weekly-with-condition',
        hour: 19,
        minute: 30,
        daysOfWeek: [1], // Monday
      );
      scheduler.register(spec);

      // Create engine with mock repository
      final mockRepository = MockSchedulerRepository();
      final automation = Automation(
        id: 'monday-automation',
        name: 'Monday Alert',
        trigger: const AutomationTrigger(type: TriggerType.scheduled),
        conditions: const [
          AutomationCondition(
            type: ConditionType.dayOfWeek,
            config: {
              'daysOfWeek': [1],
            }, // Monday
          ),
        ],
        actions: const [AutomationAction(type: ActionType.vibrate)],
      );
      mockRepository.addTestAutomation(automation);

      final engine = AutomationEngine(
        repository: mockRepository,
        iftttService: MockSchedulerIftttService(),
        scheduler: scheduler,
      );

      // Listen for triggered automations
      mockRepository.recordedTriggerIds.clear();

      // Move to Monday 19:30
      clock.setTime(DateTime(2026, 2, 2, 19, 30, 0));
      final firedEvents = scheduler.tick(clock.now());

      // Process events through engine
      for (final event in firedEvents) {
        engine.processScheduledEvent(event);
      }

      // Verify event fired
      expect(events.length, 1);

      scheduler.dispose();
      engine.stop();
    });
  });

  group('InAppScheduler - Catch-up Policies', () {
    test('catchUpPolicy.none skips missed slots on time jump', () {
      // Start at Jan 30 09:00 with slot already fired
      final clock = FakeClock(DateTime(2026, 1, 30, 9, 0, 0));
      final events = <ScheduledFireEvent>[];

      final scheduler = InAppScheduler(clock: clock);
      scheduler.fireEvents.listen(events.add);
      scheduler.start();

      final spec =
          ScheduleSpec.daily(
            id: 'test-no-catchup',
            hour: 9,
            minute: 0,
            catchUpPolicy: CatchUpPolicy.none,
            lastEvaluatedAt: DateTime(2026, 1, 30, 9, 0, 0),
          ).recordFiredSlot(
            'daily:2026-01-30T09:00+11:00',
            DateTime(2026, 1, 30, 9, 0, 0),
          );
      scheduler.register(spec);

      // Jump forward 7 days to Feb 6 at 12:00 (past 09:00)
      // According to semantics: fires 0 (09:00 already passed today)
      clock.setTime(DateTime(2026, 2, 6, 12, 0, 0));
      scheduler.tick(clock.now());

      // Should fire 0 - the 09:00 slot for today already passed
      expect(events.length, 0);

      scheduler.dispose();
    });

    test(
      'catchUpPolicy.none does not fire if past the scheduled time even within minutes',
      () {
        // Start at Jan 30 09:00 with slot already fired
        final clock = FakeClock(DateTime(2026, 1, 30, 9, 0, 0));
        final events = <ScheduledFireEvent>[];

        final scheduler = InAppScheduler(clock: clock);
        scheduler.fireEvents.listen(events.add);
        scheduler.start();

        final spec =
            ScheduleSpec.daily(
              id: 'test-no-catchup-grace',
              hour: 9,
              minute: 0,
              catchUpPolicy: CatchUpPolicy.none,
              lastEvaluatedAt: DateTime(2026, 1, 30, 9, 0, 0),
            ).recordFiredSlot(
              'daily:2026-01-30T09:00+11:00',
              DateTime(2026, 1, 30, 9, 0, 0),
            );
        scheduler.register(spec);

        // Jump forward 7 days to Feb 6 at 09:02 (past today's 09:00)
        // With catchUpPolicy.none, since 09:00 already passed, it should NOT fire
        // The next occurrence is scheduled for Feb 7 09:00
        clock.setTime(DateTime(2026, 2, 6, 9, 2, 0));
        scheduler.tick(clock.now());

        // Should fire 0 - past today's 09:00 slot, next is tomorrow
        expect(events.length, 0);

        scheduler.dispose();
      },
    );

    test('catchUpPolicy.lastOnly fires once for most recent missed slot', () {
      final clock = FakeClock(DateTime(2026, 1, 30, 9, 0, 0));
      final events = <ScheduledFireEvent>[];

      final scheduler = InAppScheduler(clock: clock);
      scheduler.fireEvents.listen(events.add);
      scheduler.start();

      final spec =
          ScheduleSpec.daily(
            id: 'test-lastonly-catchup',
            hour: 9,
            minute: 0,
            catchUpPolicy: CatchUpPolicy.lastOnly,
            lastEvaluatedAt: DateTime(2026, 1, 30, 9, 0, 0),
          ).recordFiredSlot(
            'daily:2026-01-30T09:00+11:00',
            DateTime(2026, 1, 30, 9, 0, 0),
          );
      scheduler.register(spec);

      // Jump forward 7 days to Feb 6 at 12:00 (past 09:00)
      clock.setTime(DateTime(2026, 2, 6, 12, 0, 0));
      scheduler.tick(clock.now());

      // Should fire exactly 1 - the most recent missed slot (Feb 6 09:00)
      expect(events.length, 1);
      expect(events.first.slotKey, contains('2026-02-06'));
      expect(events.first.isCatchUp, isTrue);

      scheduler.dispose();
    });

    test('catchUpPolicy.allWithinWindow fires all missed within window', () {
      final clock = FakeClock(DateTime(2026, 1, 30, 9, 0, 0));
      final events = <ScheduledFireEvent>[];

      final scheduler = InAppScheduler(clock: clock);
      scheduler.fireEvents.listen(events.add);
      scheduler.start();

      final spec =
          ScheduleSpec.daily(
            id: 'test-all-catchup',
            hour: 9,
            minute: 0,
            catchUpPolicy: CatchUpPolicy.allWithinWindow,
            catchUpWindow: const Duration(days: 7),
            maxCatchUpExecutions: 5,
            lastEvaluatedAt: DateTime(2026, 1, 30, 9, 0, 0),
          ).recordFiredSlot(
            'daily:2026-01-30T09:00+11:00',
            DateTime(2026, 1, 30, 9, 0, 0),
          );
      scheduler.register(spec);

      // Jump forward 3 days to Feb 2 at 09:00
      clock.setTime(DateTime(2026, 2, 2, 9, 0, 0));
      scheduler.tick(clock.now());

      // Should fire events for missed days (Jan 31, Feb 1, Feb 2) - 3 total
      expect(events.length, 3);
      // First events should be marked as catch-up
      expect(events.where((e) => e.isCatchUp).length, greaterThanOrEqualTo(2));

      scheduler.dispose();
    });

    test('allWithinWindow respects maxCatchUpExecutions limit', () {
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final events = <ScheduledFireEvent>[];

      final scheduler = InAppScheduler(clock: clock);
      scheduler.fireEvents.listen(events.add);
      scheduler.start();

      final spec =
          ScheduleSpec.daily(
            id: 'test-limited-catchup',
            hour: 9,
            minute: 0,
            catchUpPolicy: CatchUpPolicy.allWithinWindow,
            catchUpWindow: const Duration(days: 365),
            maxCatchUpExecutions: 5, // Limit to 5
            lastEvaluatedAt: DateTime(2026, 1, 1, 9, 0, 0),
          ).recordFiredSlot(
            'daily:2026-01-01T09:00+11:00',
            DateTime(2026, 1, 1, 9, 0, 0),
          );
      scheduler.register(spec);

      // Jump forward 30 days
      clock.setTime(DateTime(2026, 1, 31, 9, 0, 0));
      scheduler.tick(clock.now());

      // Should be limited to 5 even though 30 days passed
      expect(events.length, 5);

      scheduler.dispose();
    });
  });

  group('InAppScheduler - Persistence and Restart', () {
    test('schedule state survives restart', () async {
      final clock = FakeClock(DateTime(2026, 1, 30, 9, 0, 0));
      var persistedSchedules = <ScheduleSpec>[];

      // First scheduler instance
      var scheduler = InAppScheduler(
        clock: clock,
        onPersist: (schedules) async {
          persistedSchedules = List.from(schedules);
        },
        onLoad: () async => persistedSchedules,
      );
      scheduler.start();

      // Register and fire
      final spec = ScheduleSpec.oneShot(
        id: 'persist-test',
        runAt: DateTime(2026, 1, 30, 9, 0, 10),
      );
      scheduler.register(spec);

      clock.advance(const Duration(seconds: 10));
      scheduler.tick(clock.now());

      // Persist state
      await scheduler.persist();
      scheduler.dispose();

      // Verify persisted state has lastFiredSlotKey
      expect(persistedSchedules.first.lastFiredSlotKey, isNotNull);

      // Second scheduler instance (simulating app restart)
      final events2 = <ScheduledFireEvent>[];
      scheduler = InAppScheduler(
        clock: clock,
        onPersist: (schedules) async {
          persistedSchedules = List.from(schedules);
        },
        onLoad: () async => persistedSchedules,
      );
      scheduler.fireEvents.listen(events2.add);
      scheduler.start();

      // Resync from store
      await scheduler.resyncFromStore();

      // Try to tick - should not re-fire the same slot
      scheduler.tick(clock.now());
      expect(events2, isEmpty); // Already fired, shouldn't fire again

      scheduler.dispose();
    });

    test('next slot fires correctly after restart', () async {
      final clock = FakeClock(DateTime(2026, 1, 30, 9, 0, 0));
      var persistedSchedules = <ScheduleSpec>[];

      // First scheduler instance
      var scheduler = InAppScheduler(
        clock: clock,
        onPersist: (schedules) async {
          persistedSchedules = List.from(schedules);
        },
        onLoad: () async => persistedSchedules,
      );
      scheduler.start();

      // Register daily schedule
      final spec = ScheduleSpec.daily(id: 'persist-daily', hour: 9, minute: 0);
      scheduler.register(spec);

      // Fire today
      scheduler.tick(clock.now());
      await scheduler.persist();
      scheduler.dispose();

      // Second scheduler instance (next day)
      clock.advance(const Duration(days: 1));

      final events2 = <ScheduledFireEvent>[];
      scheduler = InAppScheduler(
        clock: clock,
        onPersist: (schedules) async {
          persistedSchedules = List.from(schedules);
        },
        onLoad: () async => persistedSchedules,
      );
      scheduler.fireEvents.listen(events2.add);
      scheduler.start();

      await scheduler.resyncFromStore();
      scheduler.tick(clock.now());

      // Should fire for next day
      expect(events2.length, 1);
      expect(events2.first.slotKey, contains('2026-01-31'));

      scheduler.dispose();
    });
  });

  group('AutomationEngine - Event Context', () {
    test('timeRange condition evaluates using scheduledFor', () {
      // Simulate: schedule daily 23:00, condition timeRange 22:00-23:30
      // The condition should use scheduledFor (23:00), not wall clock
      final scheduledFor = DateTime(2026, 1, 30, 23, 0, 0);

      final event = AutomationEvent.scheduledFire(
        scheduleId: 'test-schedule',
        slotKey: 'daily:2026-01-30T23:00+11:00',
        scheduledFor: scheduledFor,
      );

      // Verify evaluationTime returns scheduledFor
      expect(event.evaluationTime, scheduledFor);
      expect(event.evaluationTime.hour, 23);
    });

    test('dayOfWeek condition evaluates using scheduledFor', () {
      // Jan 30, 2026 is a Friday (weekday = 5)
      final scheduledFor = DateTime(2026, 1, 30, 9, 0, 0);

      final event = AutomationEvent.scheduledFire(
        scheduleId: 'test-schedule',
        slotKey: 'daily:2026-01-30T09:00+11:00',
        scheduledFor: scheduledFor,
      );

      // weekday % 7: Friday = 5 % 7 = 5
      expect(event.evaluationTime.weekday % 7, 5);
    });

    test('regular events use timestamp for evaluation', () {
      final timestamp = DateTime(2026, 1, 30, 10, 0, 0);

      final event = AutomationEvent(
        type: TriggerType.messageReceived,
        timestamp: timestamp,
        messageText: 'Hello',
      );

      // For non-scheduled events, evaluationTime is timestamp
      expect(event.evaluationTime, timestamp);
      expect(event.scheduledFor, isNull);
    });
  });

  group('InAppScheduler - Concurrency and Safety', () {
    test('large time jump processes deterministically with caps', () {
      final clock = FakeClock(DateTime(2026, 1, 1, 0, 0, 0));
      final events = <ScheduledFireEvent>[];

      final scheduler = InAppScheduler(clock: clock);
      scheduler.fireEvents.listen(events.add);
      scheduler.start();

      // Register interval every 10 seconds
      final spec = ScheduleSpec.interval(
        id: 'burst-test',
        every: const Duration(seconds: 10),
        startAt: DateTime(2026, 1, 1, 0, 0, 0),
      );
      scheduler.register(spec);

      // Jump forward 24 hours in one tick
      clock.advance(const Duration(hours: 24));
      final firedEvents = scheduler.tick(clock.now());

      // Should be capped at maxProcessPerTick (100)
      expect(firedEvents.length, lessThanOrEqualTo(100));

      // Results should be deterministic
      final firstSlotKey = firedEvents.first.slotKey;
      expect(firstSlotKey, startsWith('interval:'));

      scheduler.dispose();
    });

    test('multiple schedules process correctly', () {
      final clock = FakeClock(DateTime(2026, 1, 30, 8, 55, 0));
      final events = <ScheduledFireEvent>[];

      final scheduler = InAppScheduler(clock: clock);
      scheduler.fireEvents.listen(events.add);
      scheduler.start();

      // Register multiple schedules
      scheduler.register(
        ScheduleSpec.oneShot(
          id: 'oneshot-1',
          runAt: DateTime(2026, 1, 30, 9, 0, 0),
        ),
      );
      scheduler.register(
        ScheduleSpec.oneShot(
          id: 'oneshot-2',
          runAt: DateTime(2026, 1, 30, 9, 5, 0),
        ),
      );
      scheduler.register(
        ScheduleSpec.daily(id: 'daily-1', hour: 9, minute: 10),
      );

      // Advance to 9:15
      clock.advance(const Duration(minutes: 20));
      scheduler.tick(clock.now());

      // All three should have fired
      expect(events.length, 3);

      final ids = events.map((e) => e.scheduleId).toSet();
      expect(ids, contains('oneshot-1'));
      expect(ids, contains('oneshot-2'));
      expect(ids, contains('daily-1'));

      scheduler.dispose();
    });

    test('disabled schedule does not fire', () {
      final clock = FakeClock(DateTime(2026, 1, 30, 8, 59, 0));
      final events = <ScheduledFireEvent>[];

      final scheduler = InAppScheduler(clock: clock);
      scheduler.fireEvents.listen(events.add);
      scheduler.start();

      final spec = ScheduleSpec.daily(
        id: 'disabled-test',
        hour: 9,
        minute: 0,
        enabled: false,
      );
      scheduler.register(spec);

      clock.advance(const Duration(minutes: 1));
      scheduler.tick(clock.now());

      expect(events, isEmpty);

      scheduler.dispose();
    });

    test('schedule outside boundaries does not fire', () {
      final clock = FakeClock(DateTime(2026, 2, 1, 9, 0, 0));
      final events = <ScheduledFireEvent>[];

      final scheduler = InAppScheduler(clock: clock);
      scheduler.fireEvents.listen(events.add);
      scheduler.start();

      // Schedule with endAt in the past
      final spec = ScheduleSpec.daily(
        id: 'expired-test',
        hour: 9,
        minute: 0,
        endAt: DateTime(2026, 1, 31, 23, 59, 59),
      );
      scheduler.register(spec);

      scheduler.tick(clock.now());

      expect(events, isEmpty);

      scheduler.dispose();
    });
  });

  group('FakeClock', () {
    test('advance moves time forward', () {
      final clock = FakeClock(DateTime(2026, 1, 1, 0, 0, 0));

      expect(clock.now(), DateTime(2026, 1, 1, 0, 0, 0));

      clock.advance(const Duration(hours: 1));
      expect(clock.now(), DateTime(2026, 1, 1, 1, 0, 0));

      clock.advance(const Duration(days: 1));
      expect(clock.now(), DateTime(2026, 1, 2, 1, 0, 0));
    });

    test('setTime sets absolute time', () {
      final clock = FakeClock(DateTime(2026, 1, 1, 0, 0, 0));

      clock.setTime(DateTime(2026, 6, 15, 12, 30, 0));
      expect(clock.now(), DateTime(2026, 6, 15, 12, 30, 0));
    });
  });

  group('Integration - Engine + Scheduler', () {
    test('scheduled trigger executes automation actions', () async {
      final clock = FakeClock(DateTime(2026, 1, 30, 8, 59, 0));
      final mockRepository = MockSchedulerRepository();
      final events = <ScheduledFireEvent>[];
      final sentMessages = <(int, String)>[];

      final scheduler = InAppScheduler(clock: clock);
      scheduler.fireEvents.listen(events.add);

      // Create automation
      final automation = Automation(
        id: 'scheduled-automation',
        name: 'Scheduled Alert',
        trigger: const AutomationTrigger(type: TriggerType.scheduled),
        actions: const [
          AutomationAction(
            type: ActionType.sendMessage,
            config: {
              'targetNodeNum': 999,
              'messageText': 'Scheduled alert at {{time}}',
            },
          ),
        ],
      );
      mockRepository.addTestAutomation(automation);

      final engine = AutomationEngine(
        repository: mockRepository,
        iftttService: MockSchedulerIftttService(),
        scheduler: scheduler,
        onSendMessage: (nodeNum, message) async {
          sentMessages.add((nodeNum, message));
          return true;
        },
      );
      engine.start();

      // Register schedule
      final spec = ScheduleSpec.daily(
        id: 'scheduled-automation',
        hour: 9,
        minute: 0,
      );
      scheduler.register(spec);

      // Advance to trigger time
      clock.advance(const Duration(minutes: 1));
      final firedEvents = scheduler.tick(clock.now());

      // Process events
      for (final event in firedEvents) {
        await engine.processScheduledEvent(event);
      }

      // Verify actions executed
      expect(sentMessages.length, 1);
      expect(sentMessages.first.$1, 999);
      expect(sentMessages.first.$2, contains('Scheduled alert'));

      engine.stop();
      scheduler.dispose();
    });
  });
}
