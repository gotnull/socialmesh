import 'dart:math' as math;
import 'package:uuid/uuid.dart';

/// Schedule kind for automations
enum ScheduleKind {
  /// One-time schedule that fires once at a specific time
  oneShot,

  /// Repeating schedule at fixed intervals
  interval,

  /// Daily schedule at a specific local time
  daily,

  /// Weekly schedule on selected days at a specific local time
  weekly,
}

/// Policy for handling missed executions when app resumes
enum CatchUpPolicy {
  /// Do not run any missed executions
  none,

  /// If missed many, run once immediately on resume
  lastOnly,

  /// Run all missed executions within a maxWindow duration (capped)
  allWithinWindow,
}

/// Strategy for deduplicating schedule executions
enum DedupeKeyStrategy {
  /// Dedupe by scheduled slot (recommended)
  /// e.g., "daily:2026-01-30T09:00+11:00" only fires once for that slot
  byScheduledSlot,

  /// No deduplication - can fire multiple times for same slot
  none,
}

/// Specification for a scheduled trigger
///
/// Supports:
/// - One-shot: fires once at a specific DateTime
/// - Interval: fires repeatedly with a fixed Duration
/// - Daily: fires at a specific HH:MM local time every day
/// - Weekly: fires on selected weekdays at a specific HH:MM local time
class ScheduleSpec {
  /// Unique identifier for this schedule
  final String id;

  /// Kind of schedule
  final ScheduleKind kind;

  /// IANA timezone identifier (default: Australia/Melbourne)
  final String tz;

  /// For oneShot: the exact time to fire (stored as UTC)
  /// For interval/daily/weekly: optional start boundary
  final DateTime? runAt;

  /// For interval schedules: the duration between fires
  final Duration? every;

  /// For daily/weekly: hour in local time (0-23)
  final int? hour;

  /// For daily/weekly: minute in local time (0-59)
  final int? minute;

  /// For weekly: days of week (0=Sunday, 6=Saturday)
  final List<int>? daysOfWeek;

  /// Optional start boundary (do not fire before this)
  final DateTime? startAt;

  /// Optional end boundary (do not fire after this)
  final DateTime? endAt;

  /// Optional jitter in milliseconds (0 for deterministic)
  final int jitterMs;

  /// Policy for handling missed executions
  final CatchUpPolicy catchUpPolicy;

  /// Maximum window for catch-up executions (for allWithinWindow policy)
  final Duration catchUpWindow;

  /// Maximum number of catch-up executions per tick (safety limit)
  final int maxCatchUpExecutions;

  /// Strategy for deduplicating executions
  final DedupeKeyStrategy dedupeKeyStrategy;

  /// Last slot key that was fired (for dedupe)
  String? lastFiredSlotKey;

  /// Last time the schedule was evaluated (for catch-up)
  DateTime? lastEvaluatedAt;

  /// Whether this schedule is enabled
  final bool enabled;

  ScheduleSpec({
    String? id,
    required this.kind,
    this.tz = 'Australia/Melbourne',
    this.runAt,
    this.every,
    this.hour,
    this.minute,
    this.daysOfWeek,
    this.startAt,
    this.endAt,
    this.jitterMs = 0,
    this.catchUpPolicy = CatchUpPolicy.none,
    this.catchUpWindow = const Duration(hours: 24),
    this.maxCatchUpExecutions = 20,
    this.dedupeKeyStrategy = DedupeKeyStrategy.byScheduledSlot,
    this.lastFiredSlotKey,
    this.lastEvaluatedAt,
    this.enabled = true,
  })  : id = id ?? const Uuid().v4(),
        assert(
          kind != ScheduleKind.oneShot || runAt != null,
          'oneShot requires runAt',
        ),
        assert(
          kind != ScheduleKind.interval || every != null,
          'interval requires every',
        ),
        assert(
          kind != ScheduleKind.interval ||
              every == null ||
              every.inSeconds >= 10,
          'interval must be >= 10 seconds',
        ),
        assert(
          kind != ScheduleKind.daily || (hour != null && minute != null),
          'daily requires hour and minute',
        ),
        assert(
          kind != ScheduleKind.weekly ||
              (hour != null && minute != null && daysOfWeek != null),
          'weekly requires hour, minute, and daysOfWeek',
        );

  /// Factory for one-shot schedule
  factory ScheduleSpec.oneShot({
    String? id,
    required DateTime runAt,
    String tz = 'Australia/Melbourne',
    int jitterMs = 0,
    bool enabled = true,
  }) {
    return ScheduleSpec(
      id: id,
      kind: ScheduleKind.oneShot,
      runAt: runAt,
      tz: tz,
      jitterMs: jitterMs,
      enabled: enabled,
    );
  }

  /// Factory for interval schedule
  factory ScheduleSpec.interval({
    String? id,
    required Duration every,
    DateTime? startAt,
    DateTime? endAt,
    String tz = 'Australia/Melbourne',
    int jitterMs = 0,
    CatchUpPolicy catchUpPolicy = CatchUpPolicy.none,
    Duration catchUpWindow = const Duration(hours: 24),
    int maxCatchUpExecutions = 20,
    DateTime? lastEvaluatedAt,
    bool enabled = true,
  }) {
    return ScheduleSpec(
      id: id,
      kind: ScheduleKind.interval,
      every: every,
      startAt: startAt,
      endAt: endAt,
      tz: tz,
      jitterMs: jitterMs,
      catchUpPolicy: catchUpPolicy,
      catchUpWindow: catchUpWindow,
      maxCatchUpExecutions: maxCatchUpExecutions,
      lastEvaluatedAt: lastEvaluatedAt,
      enabled: enabled,
    );
  }

  /// Factory for daily schedule
  factory ScheduleSpec.daily({
    String? id,
    required int hour,
    required int minute,
    DateTime? startAt,
    DateTime? endAt,
    String tz = 'Australia/Melbourne',
    int jitterMs = 0,
    CatchUpPolicy catchUpPolicy = CatchUpPolicy.none,
    Duration catchUpWindow = const Duration(hours: 24),
    int maxCatchUpExecutions = 20,
    DateTime? lastEvaluatedAt,
    bool enabled = true,
  }) {
    return ScheduleSpec(
      id: id,
      kind: ScheduleKind.daily,
      hour: hour,
      minute: minute,
      startAt: startAt,
      endAt: endAt,
      tz: tz,
      jitterMs: jitterMs,
      catchUpPolicy: catchUpPolicy,
      catchUpWindow: catchUpWindow,
      maxCatchUpExecutions: maxCatchUpExecutions,
      lastEvaluatedAt: lastEvaluatedAt,
      enabled: enabled,
    );
  }

  /// Factory for weekly schedule
  factory ScheduleSpec.weekly({
    String? id,
    required int hour,
    required int minute,
    required List<int> daysOfWeek,
    DateTime? startAt,
    DateTime? endAt,
    String tz = 'Australia/Melbourne',
    int jitterMs = 0,
    CatchUpPolicy catchUpPolicy = CatchUpPolicy.none,
    Duration catchUpWindow = const Duration(hours: 24),
    int maxCatchUpExecutions = 20,
    DateTime? lastEvaluatedAt,
    bool enabled = true,
  }) {
    return ScheduleSpec(
      id: id,
      kind: ScheduleKind.weekly,
      hour: hour,
      minute: minute,
      daysOfWeek: daysOfWeek,
      startAt: startAt,
      endAt: endAt,
      tz: tz,
      jitterMs: jitterMs,
      catchUpPolicy: catchUpPolicy,
      catchUpWindow: catchUpWindow,
      maxCatchUpExecutions: maxCatchUpExecutions,
      lastEvaluatedAt: lastEvaluatedAt,
      enabled: enabled,
    );
  }

  /// Generate slot key for deduplication
  ///
  /// Slot keys are stable strings that identify a specific scheduled execution:
  /// - oneShot: "oneShot:{isoDateTime}"
  /// - interval: "interval:{n}" where n is the interval count from startAt
  /// - daily: "daily:{date}T{HH:MM}{offset}"
  /// - weekly: "weekly:{date}T{HH:MM}{offset}"
  String generateSlotKey(DateTime scheduledFor, {int? intervalCount}) {
    switch (kind) {
      case ScheduleKind.oneShot:
        return 'oneShot:${scheduledFor.toIso8601String()}';
      case ScheduleKind.interval:
        return 'interval:${intervalCount ?? 0}';
      case ScheduleKind.daily:
        return 'daily:${_formatLocalSlotTime(scheduledFor)}';
      case ScheduleKind.weekly:
        return 'weekly:${_formatLocalSlotTime(scheduledFor)}';
    }
  }

  /// Format local slot time for slot key (includes offset for DST awareness)
  String _formatLocalSlotTime(DateTime dt) {
    // Format: YYYY-MM-DDTHH:MM±HH:MM
    final offset = dt.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes =
        (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final date = dt.toIso8601String().split('T')[0];
    final time =
        '${hour?.toString().padLeft(2, '0')}:${minute?.toString().padLeft(2, '0')}';
    return '$date' 'T$time$sign$hours:$minutes';
  }

  /// Check if a slot key has already been fired
  bool hasSlotFired(String slotKey) {
    if (dedupeKeyStrategy == DedupeKeyStrategy.none) return false;
    return lastFiredSlotKey == slotKey;
  }

  /// Record that a slot was fired
  ScheduleSpec recordFiredSlot(String slotKey, DateTime evaluatedAt) {
    return copyWith(
      lastFiredSlotKey: slotKey,
      lastEvaluatedAt: evaluatedAt,
    );
  }

  /// Apply jitter to a scheduled time
  DateTime applyJitter(DateTime scheduledFor, math.Random random) {
    if (jitterMs <= 0) return scheduledFor;
    final jitter = random.nextInt(jitterMs);
    return scheduledFor.add(Duration(milliseconds: jitter));
  }

  /// Check if schedule is within its valid time boundaries
  bool isWithinBoundaries(DateTime now) {
    if (startAt != null && now.isBefore(startAt!)) return false;
    if (endAt != null && now.isAfter(endAt!)) return false;
    return true;
  }

  /// Check if the schedule is still active (one-shot fires once, others continue)
  bool isActive(DateTime now) {
    if (!enabled) return false;
    if (!isWithinBoundaries(now)) return false;

    // One-shot is inactive after it fires
    if (kind == ScheduleKind.oneShot && lastFiredSlotKey != null) {
      return false;
    }

    return true;
  }

  ScheduleSpec copyWith({
    String? id,
    ScheduleKind? kind,
    String? tz,
    DateTime? runAt,
    Duration? every,
    int? hour,
    int? minute,
    List<int>? daysOfWeek,
    DateTime? startAt,
    DateTime? endAt,
    int? jitterMs,
    CatchUpPolicy? catchUpPolicy,
    Duration? catchUpWindow,
    int? maxCatchUpExecutions,
    DedupeKeyStrategy? dedupeKeyStrategy,
    String? lastFiredSlotKey,
    DateTime? lastEvaluatedAt,
    bool? enabled,
  }) {
    return ScheduleSpec(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      tz: tz ?? this.tz,
      runAt: runAt ?? this.runAt,
      every: every ?? this.every,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      jitterMs: jitterMs ?? this.jitterMs,
      catchUpPolicy: catchUpPolicy ?? this.catchUpPolicy,
      catchUpWindow: catchUpWindow ?? this.catchUpWindow,
      maxCatchUpExecutions: maxCatchUpExecutions ?? this.maxCatchUpExecutions,
      dedupeKeyStrategy: dedupeKeyStrategy ?? this.dedupeKeyStrategy,
      lastFiredSlotKey: lastFiredSlotKey ?? this.lastFiredSlotKey,
      lastEvaluatedAt: lastEvaluatedAt ?? this.lastEvaluatedAt,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'tz': tz,
        'runAt': runAt?.toIso8601String(),
        'everySeconds': every?.inSeconds,
        'hour': hour,
        'minute': minute,
        'daysOfWeek': daysOfWeek,
        'startAt': startAt?.toIso8601String(),
        'endAt': endAt?.toIso8601String(),
        'jitterMs': jitterMs,
        'catchUpPolicy': catchUpPolicy.name,
        'catchUpWindowSeconds': catchUpWindow.inSeconds,
        'maxCatchUpExecutions': maxCatchUpExecutions,
        'dedupeKeyStrategy': dedupeKeyStrategy.name,
        'lastFiredSlotKey': lastFiredSlotKey,
        'lastEvaluatedAt': lastEvaluatedAt?.toIso8601String(),
        'enabled': enabled,
      };

  factory ScheduleSpec.fromJson(Map<String, dynamic> json) {
    return ScheduleSpec(
      id: json['id'] as String,
      kind: ScheduleKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => ScheduleKind.oneShot,
      ),
      tz: json['tz'] as String? ?? 'Australia/Melbourne',
      runAt: json['runAt'] != null
          ? DateTime.parse(json['runAt'] as String)
          : null,
      every: json['everySeconds'] != null
          ? Duration(seconds: json['everySeconds'] as int)
          : null,
      hour: json['hour'] as int?,
      minute: json['minute'] as int?,
      daysOfWeek: (json['daysOfWeek'] as List?)?.cast<int>(),
      startAt: json['startAt'] != null
          ? DateTime.parse(json['startAt'] as String)
          : null,
      endAt: json['endAt'] != null
          ? DateTime.parse(json['endAt'] as String)
          : null,
      jitterMs: json['jitterMs'] as int? ?? 0,
      catchUpPolicy: CatchUpPolicy.values.firstWhere(
        (p) => p.name == json['catchUpPolicy'],
        orElse: () => CatchUpPolicy.none,
      ),
      catchUpWindow: Duration(
        seconds: json['catchUpWindowSeconds'] as int? ?? 86400,
      ),
      maxCatchUpExecutions: json['maxCatchUpExecutions'] as int? ?? 20,
      dedupeKeyStrategy: DedupeKeyStrategy.values.firstWhere(
        (s) => s.name == json['dedupeKeyStrategy'],
        orElse: () => DedupeKeyStrategy.byScheduledSlot,
      ),
      lastFiredSlotKey: json['lastFiredSlotKey'] as String?,
      lastEvaluatedAt: json['lastEvaluatedAt'] != null
          ? DateTime.parse(json['lastEvaluatedAt'] as String)
          : null,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  @override
  String toString() {
    return 'ScheduleSpec(id: $id, kind: $kind, tz: $tz, '
        'hour: $hour, minute: $minute, daysOfWeek: $daysOfWeek, '
        'catchUpPolicy: $catchUpPolicy, enabled: $enabled)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScheduleSpec && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Represents a scheduled fire event
class ScheduledFireEvent {
  /// The schedule ID that fired
  final String scheduleId;

  /// Stable slot key for deduplication (e.g., "daily:2026-01-30T09:00+11:00")
  final String slotKey;

  /// The intended fire time (not necessarily "now")
  final DateTime scheduledFor;

  /// Whether this is a catch-up execution
  final bool isCatchUp;

  /// The interval count (for interval schedules)
  final int? intervalCount;

  const ScheduledFireEvent({
    required this.scheduleId,
    required this.slotKey,
    required this.scheduledFor,
    this.isCatchUp = false,
    this.intervalCount,
  });

  Map<String, dynamic> toJson() => {
        'scheduleId': scheduleId,
        'slotKey': slotKey,
        'scheduledFor': scheduledFor.toIso8601String(),
        'isCatchUp': isCatchUp,
        'intervalCount': intervalCount,
      };

  factory ScheduledFireEvent.fromJson(Map<String, dynamic> json) {
    return ScheduledFireEvent(
      scheduleId: json['scheduleId'] as String,
      slotKey: json['slotKey'] as String,
      scheduledFor: DateTime.parse(json['scheduledFor'] as String),
      isCatchUp: json['isCatchUp'] as bool? ?? false,
      intervalCount: json['intervalCount'] as int?,
    );
  }

  @override
  String toString() =>
      'ScheduledFireEvent(scheduleId: $scheduleId, slotKey: $slotKey, '
      'scheduledFor: $scheduledFor, isCatchUp: $isCatchUp)';
}
