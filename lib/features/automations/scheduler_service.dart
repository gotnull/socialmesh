import 'dart:async';
import 'dart:collection';

import '../../core/logging.dart';
import 'models/schedule_spec.dart';

/// Clock abstraction for testability
///
/// In production, uses real DateTime.now()
/// In tests, can be mocked to return deterministic times
abstract class Clock {
  DateTime now();
}

/// Default clock implementation using system time
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Fake clock for deterministic testing
class FakeClock implements Clock {
  DateTime _now;

  FakeClock([DateTime? initialTime])
      : _now = initialTime ?? DateTime(2026, 1, 30, 9, 0, 0);

  @override
  DateTime now() => _now;

  /// Advance the clock by a duration
  void advance(Duration duration) {
    _now = _now.add(duration);
  }

  /// Set the clock to a specific time
  void setTime(DateTime time) {
    _now = time;
  }
}

/// Interface for the scheduler service
///
/// Manages scheduled automation triggers with deterministic testing support.
/// The scheduler maintains a priority queue of upcoming fire times and emits
/// events when schedules are due.
abstract class Scheduler {
  /// Start the scheduler (begins timer-based ticking in production)
  void start();

  /// Stop the scheduler
  void stop();

  /// Register a new schedule
  void register(ScheduleSpec spec);

  /// Unregister a schedule by ID
  void unregister(String scheduleId);

  /// Get a schedule by ID
  ScheduleSpec? getSchedule(String scheduleId);

  /// Get all registered schedules
  List<ScheduleSpec> get schedules;

  /// Reload schedules from storage (e.g., after restart)
  Future<void> resyncFromStore();

  /// Process schedules up to the given time (for deterministic testing)
  ///
  /// In tests, call this with FakeClock.now() after advancing the clock.
  /// Returns the list of events that fired.
  List<ScheduledFireEvent> tick(DateTime now);

  /// Stream of scheduled fire events
  Stream<ScheduledFireEvent> get fireEvents;

  /// Update a schedule's state (e.g., after firing)
  void updateSchedule(ScheduleSpec spec);

  /// Persist current state (called after firing events)
  Future<void> persist();
}

/// Entry in the schedule priority queue
class _ScheduleEntry implements Comparable<_ScheduleEntry> {
  final String scheduleId;
  final DateTime nextFireTime;
  final String slotKey;
  final int intervalCount;

  _ScheduleEntry({
    required this.scheduleId,
    required this.nextFireTime,
    required this.slotKey,
    this.intervalCount = 0,
  });

  @override
  int compareTo(_ScheduleEntry other) {
    return nextFireTime.compareTo(other.nextFireTime);
  }

  @override
  String toString() =>
      '_ScheduleEntry($scheduleId, $nextFireTime, $slotKey)';
}

/// Callback for persisting schedule state
typedef SchedulePersistCallback = Future<void> Function(
    List<ScheduleSpec> schedules);

/// Callback for loading schedule state
typedef ScheduleLoadCallback = Future<List<ScheduleSpec>> Function();

/// In-app scheduler implementation
///
/// Uses a min-heap (SplayTreeSet as sorted collection) to efficiently
/// find the next schedule to fire. Designed for deterministic testing
/// with injectable Clock.
class InAppScheduler implements Scheduler {
  final Clock _clock;
  final SchedulePersistCallback? _onPersist;
  final ScheduleLoadCallback? _onLoad;

  /// All registered schedules by ID
  final Map<String, ScheduleSpec> _schedules = {};

  /// Priority queue of upcoming fire times
  /// Using SplayTreeSet for O(log n) insertion/removal while maintaining order
  final SplayTreeSet<_ScheduleEntry> _queue = SplayTreeSet();

  /// Track entries by schedule ID for efficient removal
  final Map<String, _ScheduleEntry> _entriesByScheduleId = {};

  /// Stream controller for fire events (sync to ensure deterministic testing)
  final StreamController<ScheduledFireEvent> _fireController =
      StreamController<ScheduledFireEvent>.broadcast(sync: true);

  /// Timer for periodic ticking (production only)
  Timer? _timer;

  /// Whether the scheduler is running
  bool _isRunning = false;

  /// Tick interval for timer-based execution
  static const _tickInterval = Duration(seconds: 1);

  InAppScheduler({
    Clock? clock,
    SchedulePersistCallback? onPersist,
    ScheduleLoadCallback? onLoad,
  })  : _clock = clock ?? const SystemClock(),
        _onPersist = onPersist,
        _onLoad = onLoad;

  @override
  Stream<ScheduledFireEvent> get fireEvents => _fireController.stream;

  @override
  List<ScheduleSpec> get schedules => List.unmodifiable(_schedules.values);

  @override
  ScheduleSpec? getSchedule(String scheduleId) => _schedules[scheduleId];

  @override
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    // Only start timer for real clock (not fake clock)
    if (_clock is SystemClock) {
      _timer = Timer.periodic(_tickInterval, (_) {
        tick(_clock.now());
      });
    }

    AppLogging.automations('InAppScheduler: Started');
  }

  @override
  void stop() {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    AppLogging.automations('InAppScheduler: Stopped');
  }

  @override
  void register(ScheduleSpec spec) {
    // Remove existing if present
    if (_schedules.containsKey(spec.id)) {
      unregister(spec.id);
    }

    _schedules[spec.id] = spec;

    // Calculate and enqueue next fire time
    final nextEntry = _calculateNextEntry(spec, _clock.now());
    if (nextEntry != null) {
      _enqueue(nextEntry);
    }

    AppLogging.automations(
        'InAppScheduler: Registered schedule ${spec.id} (${spec.kind})');
  }

  @override
  void unregister(String scheduleId) {
    _schedules.remove(scheduleId);

    // Remove from queue
    final entry = _entriesByScheduleId.remove(scheduleId);
    if (entry != null) {
      _queue.remove(entry);
    }

    AppLogging.automations('InAppScheduler: Unregistered schedule $scheduleId');
  }

  @override
  void updateSchedule(ScheduleSpec spec) {
    _schedules[spec.id] = spec;
  }

  @override
  Future<void> resyncFromStore() async {
    if (_onLoad == null) return;

    final loaded = await _onLoad();
    final now = _clock.now();

    // Clear current state
    _schedules.clear();
    _queue.clear();
    _entriesByScheduleId.clear();

    // Re-register all schedules
    for (final spec in loaded) {
      _schedules[spec.id] = spec;

      if (!spec.isActive(now)) continue;

      final nextEntry = _calculateNextEntry(spec, now);
      if (nextEntry != null) {
        _enqueue(nextEntry);
      }
    }

    AppLogging.automations(
        'InAppScheduler: Resynced ${loaded.length} schedules from store');
  }

  @override
  Future<void> persist() async {
    if (_onPersist == null) return;
    await _onPersist(_schedules.values.toList());
  }

  @override
  List<ScheduledFireEvent> tick(DateTime now) {
    if (!_isRunning) return [];

    final events = <ScheduledFireEvent>[];
    final processedScheduleIds = <String>{};
    const maxProcessPerTick = 100; // Safety limit

    while (_queue.isNotEmpty && processedScheduleIds.length < maxProcessPerTick) {
      final entry = _queue.first;

      // Check if it's time to fire (or past due)
      if (entry.nextFireTime.isAfter(now)) {
        break; // Nothing more to process - all remaining entries are in the future
      }

      // Remove from queue
      _queue.remove(entry);
      _entriesByScheduleId.remove(entry.scheduleId);

      // Skip if we've already processed this schedule in this tick
      if (processedScheduleIds.contains(entry.scheduleId)) {
        continue;
      }

      final spec = _schedules[entry.scheduleId];
      if (spec == null || !spec.enabled) {
        processedScheduleIds.add(entry.scheduleId);
        continue;
      }

      // Process this schedule according to its catch-up policy
      final scheduleEvents = _processScheduleWithPolicy(spec, entry, now);
      events.addAll(scheduleEvents);
      processedScheduleIds.add(entry.scheduleId);
    }

    // Emit events
    for (final event in events) {
      _fireController.add(event);
    }

    if (events.isNotEmpty) {
      AppLogging.automations(
          'InAppScheduler: Tick processed ${events.length} events');
    }

    return events;
  }

  /// Process a schedule entry according to its catch-up policy
  List<ScheduledFireEvent> _processScheduleWithPolicy(
    ScheduleSpec spec,
    _ScheduleEntry entry,
    DateTime now,
  ) {
    final events = <ScheduledFireEvent>[];

    // For one-shot schedules, policy doesn't matter - fire once if due and not already fired
    if (spec.kind == ScheduleKind.oneShot) {
      if (!spec.hasSlotFired(entry.slotKey) &&
          spec.isWithinBoundaries(entry.nextFireTime)) {
        events.add(_createEvent(spec, entry, now));
        final updatedSpec = spec.recordFiredSlot(entry.slotKey, now);
        _schedules[spec.id] = updatedSpec;
      }
      return events;
    }

    // For repeating schedules, behavior depends on catch-up policy
    switch (spec.catchUpPolicy) {
      case CatchUpPolicy.none:
        // With CatchUpPolicy.none:
        // - If the entry time is close to now (within 5 minutes), fire it
        // - Otherwise, skip to the next occurrence at or after now
        // This prevents blasting multiple fires on time jumps, but allows
        // normal tick-by-tick operation to work

        // Check if the entry from the queue is still "close enough" to now
        final entryAge = now.difference(entry.nextFireTime);
        final isRecentEntry = entryAge <= const Duration(minutes: 5);

        if (isRecentEntry &&
            !spec.hasSlotFired(entry.slotKey) &&
            spec.isWithinBoundaries(entry.nextFireTime)) {
          // Entry is recent - fire it
          events.add(_createEvent(spec, entry, now));
          final updatedSpec = spec.recordFiredSlot(entry.slotKey, now);
          _schedules[spec.id] = updatedSpec;
          // Schedule the NEXT occurrence
          final next = _calculateNextEntry(updatedSpec, now, after: entry);
          if (next != null) {
            _enqueue(next);
          }
        } else {
          // Entry is stale (time jump happened) - skip to next at-or-after now
          final nextAtOrAfterNow = _computeNextOccurrenceAtOrAfter(spec, now);
          if (nextAtOrAfterNow != null && nextAtOrAfterNow.isAfter(now)) {
            final nextSlotKey = spec.generateSlotKey(nextAtOrAfterNow);
            final nextEntry = _ScheduleEntry(
              scheduleId: spec.id,
              nextFireTime: nextAtOrAfterNow,
              slotKey: nextSlotKey,
              intervalCount: 0,
            );
            _enqueue(nextEntry);
          } else if (nextAtOrAfterNow != null) {
            // nextAtOrAfterNow is at or before now - we might need to fire or skip
            final nextSlotKey = spec.generateSlotKey(nextAtOrAfterNow);
            if (!spec.hasSlotFired(nextSlotKey) &&
                spec.isWithinBoundaries(nextAtOrAfterNow) &&
                now.difference(nextAtOrAfterNow) <= const Duration(minutes: 5)) {
              final nextEntry = _ScheduleEntry(
                scheduleId: spec.id,
                nextFireTime: nextAtOrAfterNow,
                slotKey: nextSlotKey,
                intervalCount: 0,
              );
              events.add(_createEvent(spec, nextEntry, now));
              final updatedSpec = spec.recordFiredSlot(nextSlotKey, now);
              _schedules[spec.id] = updatedSpec;
              // Schedule the NEXT occurrence
              final next = _calculateNextEntry(updatedSpec, now, after: nextEntry);
              if (next != null) {
                _enqueue(next);
              }
            } else {
              // Skip this slot too, schedule next
              final tempEntry = _ScheduleEntry(
                scheduleId: spec.id,
                nextFireTime: nextAtOrAfterNow,
                slotKey: nextSlotKey,
                intervalCount: 0,
              );
              final next = _calculateNextEntry(spec, now, after: tempEntry);
              if (next != null) {
                _enqueue(next);
              }
            }
          }
        }
        break;

      case CatchUpPolicy.lastOnly:
        // Fire exactly one for the most recent missed slot (or current), then advance
        final mostRecentSlot = _findMostRecentMissedSlot(spec, entry, now);
        if (mostRecentSlot != null &&
            !spec.hasSlotFired(mostRecentSlot.slotKey) &&
            spec.isWithinBoundaries(mostRecentSlot.nextFireTime)) {
          events.add(_createEvent(spec, mostRecentSlot, now, isCatchUp: true));
          final updatedSpec =
              spec.recordFiredSlot(mostRecentSlot.slotKey, now);
          _schedules[spec.id] = updatedSpec;
          // Schedule next occurrence after the most recent
          final next = _calculateNextEntry(updatedSpec, now, after: mostRecentSlot);
          if (next != null) {
            _enqueue(next);
          }
        } else {
          // Nothing to fire, schedule next
          final next = _computeNextOccurrenceAtOrAfter(spec, now);
          if (next != null) {
            final nextEntry = _ScheduleEntry(
              scheduleId: spec.id,
              nextFireTime: next,
              slotKey: spec.generateSlotKey(next),
              intervalCount: 0,
            );
            _enqueue(nextEntry);
          }
        }
        break;

      case CatchUpPolicy.allWithinWindow:
        // Fire all missed slots within the catch-up window, capped
        var currentSpec = spec;
        var currentEntry = entry;
        var fireCount = 0;
        final windowStart = now.subtract(spec.catchUpWindow);

        while (fireCount < spec.maxCatchUpExecutions) {
          // Check if this entry is within the catch-up window
          if (currentEntry.nextFireTime.isBefore(windowStart)) {
            // Too old, skip to next
            final next =
                _calculateNextEntry(currentSpec, now, after: currentEntry);
            if (next == null || next.nextFireTime.isAfter(now)) {
              break;
            }
            currentEntry = next;
            continue;
          }

          // Check if past now
          if (currentEntry.nextFireTime.isAfter(now)) {
            // This is a future occurrence, enqueue and stop
            _enqueue(currentEntry);
            break;
          }

          // Fire if not already fired and within boundaries
          if (!currentSpec.hasSlotFired(currentEntry.slotKey) &&
              currentSpec.isWithinBoundaries(currentEntry.nextFireTime)) {
            events.add(_createEvent(
                currentSpec, currentEntry, now, isCatchUp: fireCount > 0));
            currentSpec =
                currentSpec.recordFiredSlot(currentEntry.slotKey, now);
            _schedules[spec.id] = currentSpec;
            fireCount++;
          }

          // Move to next occurrence
          final next =
              _calculateNextEntry(currentSpec, now, after: currentEntry);
          if (next == null) {
            break;
          }
          currentEntry = next;
        }

        // Ensure we have something enqueued for the future
        if (!_entriesByScheduleId.containsKey(spec.id)) {
          final nextFuture = _computeNextOccurrenceAtOrAfter(currentSpec, now);
          if (nextFuture != null && nextFuture.isAfter(now)) {
            final futureEntry = _ScheduleEntry(
              scheduleId: spec.id,
              nextFireTime: nextFuture,
              slotKey: currentSpec.generateSlotKey(nextFuture),
              intervalCount: 0,
            );
            _enqueue(futureEntry);
          }
        }
        break;
    }

    return events;
  }

  /// Create a ScheduledFireEvent from an entry
  ScheduledFireEvent _createEvent(
    ScheduleSpec spec,
    _ScheduleEntry entry,
    DateTime now, {
    bool? isCatchUp,
  }) {
    return ScheduledFireEvent(
      scheduleId: spec.id,
      slotKey: entry.slotKey,
      scheduledFor: entry.nextFireTime,
      isCatchUp: isCatchUp ??
          (entry.nextFireTime.isBefore(now) &&
              now.difference(entry.nextFireTime) > const Duration(seconds: 5)),
      intervalCount: entry.intervalCount,
    );
  }

  /// Compute the next occurrence at or after the given time
  DateTime? _computeNextOccurrenceAtOrAfter(ScheduleSpec spec, DateTime now) {
    switch (spec.kind) {
      case ScheduleKind.oneShot:
        return spec.runAt;
      case ScheduleKind.interval:
        // For intervals, compute next from startAt or lastEvaluatedAt
        if (spec.every == null) return null;
        final startTime = spec.startAt ?? spec.lastEvaluatedAt ?? now;
        final elapsed = now.difference(startTime);
        if (elapsed.isNegative) return startTime;
        final intervalsPassed = elapsed.inMilliseconds ~/ spec.every!.inMilliseconds;
        var nextFire = startTime.add(spec.every! * intervalsPassed);
        if (nextFire.isBefore(now)) {
          nextFire = startTime.add(spec.every! * (intervalsPassed + 1));
        }
        return nextFire;
      case ScheduleKind.daily:
        return _calculateNextDailyTime(spec, now, null);
      case ScheduleKind.weekly:
        return _calculateNextWeeklyTime(spec, now, null);
    }
  }

  /// Find the most recent missed slot for lastOnly policy
  _ScheduleEntry? _findMostRecentMissedSlot(
    ScheduleSpec spec,
    _ScheduleEntry startEntry,
    DateTime now,
  ) {
    _ScheduleEntry? mostRecent;
    var current = startEntry;
    var iterations = 0;
    const maxIterations = 1000; // Safety limit

    while (iterations < maxIterations) {
      if (current.nextFireTime.isAfter(now)) {
        break; // We've gone past now
      }

      if (!spec.hasSlotFired(current.slotKey) &&
          spec.isWithinBoundaries(current.nextFireTime)) {
        mostRecent = current;
      }

      // Calculate next
      final next = _calculateNextEntry(spec, now, after: current);
      if (next == null) break;
      current = next;
      iterations++;
    }

    return mostRecent;
  }

  /// Enqueue an entry
  void _enqueue(_ScheduleEntry entry) {
    _queue.add(entry);
    _entriesByScheduleId[entry.scheduleId] = entry;
  }

  /// Calculate the next entry for a schedule
  _ScheduleEntry? _calculateNextEntry(
    ScheduleSpec spec,
    DateTime now, {
    _ScheduleEntry? after,
  }) {
    if (!spec.isActive(now)) return null;

    DateTime? nextFireTime;
    String? slotKey;
    int intervalCount = after?.intervalCount ?? 0;

    switch (spec.kind) {
      case ScheduleKind.oneShot:
        if (spec.runAt == null) return null;
        if (spec.lastFiredSlotKey != null) return null; // Already fired
        nextFireTime = spec.runAt!;
        slotKey = spec.generateSlotKey(nextFireTime);
        break;

      case ScheduleKind.interval:
        if (spec.every == null) return null;
        final startTime = spec.startAt ?? spec.lastEvaluatedAt ?? now;

        if (after != null) {
          // Calculate next interval
          nextFireTime = after.nextFireTime.add(spec.every!);
          intervalCount = after.intervalCount + 1;
        } else if (spec.lastEvaluatedAt != null) {
          // Resume from last evaluation
          final elapsed = now.difference(startTime);
          final intervalsPassed = elapsed.inMilliseconds ~/ spec.every!.inMilliseconds;
          intervalCount = intervalsPassed;
          nextFireTime = startTime.add(spec.every! * intervalCount);

          // If we're past this interval, move to next
          if (nextFireTime.isBefore(now) ||
              nextFireTime.isAtSameMomentAs(now)) {
            intervalCount++;
            nextFireTime = startTime.add(spec.every! * intervalCount);
          }
        } else {
          // Fresh start
          nextFireTime = now.add(spec.every!);
          intervalCount = 1;
        }
        slotKey = spec.generateSlotKey(nextFireTime, intervalCount: intervalCount);
        break;

      case ScheduleKind.daily:
        nextFireTime = _calculateNextDailyTime(spec, now, after?.nextFireTime);
        if (nextFireTime == null) return null;
        slotKey = spec.generateSlotKey(nextFireTime);
        break;

      case ScheduleKind.weekly:
        nextFireTime = _calculateNextWeeklyTime(spec, now, after?.nextFireTime);
        if (nextFireTime == null) return null;
        slotKey = spec.generateSlotKey(nextFireTime);
        break;
    }

    // Check end boundary
    if (spec.endAt != null && nextFireTime.isAfter(spec.endAt!)) {
      return null;
    }

    return _ScheduleEntry(
      scheduleId: spec.id,
      nextFireTime: nextFireTime,
      slotKey: slotKey,
      intervalCount: intervalCount,
    );
  }

  /// Calculate next daily fire time
  DateTime? _calculateNextDailyTime(
    ScheduleSpec spec,
    DateTime now,
    DateTime? afterTime,
  ) {
    if (spec.hour == null || spec.minute == null) return null;

    // Start from the day after the last fire time, or today
    DateTime startDate;
    if (afterTime != null) {
      startDate = DateTime(
          afterTime.year, afterTime.month, afterTime.day + 1);
    } else {
      startDate = DateTime(now.year, now.month, now.day);
    }

    // Create candidate time
    var candidate = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      spec.hour!,
      spec.minute!,
    );

    // If we're past today's time and didn't have a previous fire time,
    // move to tomorrow
    if (afterTime == null && candidate.isBefore(now)) {
      candidate = DateTime(
        now.year,
        now.month,
        now.day + 1,
        spec.hour!,
        spec.minute!,
      );
    }

    return candidate;
  }

  /// Calculate next weekly fire time
  DateTime? _calculateNextWeeklyTime(
    ScheduleSpec spec,
    DateTime now,
    DateTime? afterTime,
  ) {
    if (spec.hour == null ||
        spec.minute == null ||
        spec.daysOfWeek == null ||
        spec.daysOfWeek!.isEmpty) {
      return null;
    }

    // Convert to Set for O(1) lookup
    final validDays = spec.daysOfWeek!.toSet();

    // Start from the day after the last fire time, or today
    DateTime startDate;
    if (afterTime != null) {
      startDate = DateTime(
          afterTime.year, afterTime.month, afterTime.day + 1);
    } else {
      startDate = DateTime(now.year, now.month, now.day);
    }

    // Find next valid day of week
    for (var i = 0; i < 8; i++) {
      final candidate = startDate.add(Duration(days: i));
      // Convert to 0=Sunday format
      final dayOfWeek = candidate.weekday % 7;

      if (validDays.contains(dayOfWeek)) {
        final fireTime = DateTime(
          candidate.year,
          candidate.month,
          candidate.day,
          spec.hour!,
          spec.minute!,
        );

        // Skip if this is today and we're past the time (and no afterTime)
        if (afterTime == null && i == 0 && fireTime.isBefore(now)) {
          continue;
        }

        return fireTime;
      }
    }

    return null;
  }

/// Dispose the scheduler
  void dispose() {
    stop();
    _fireController.close();
  }
}
