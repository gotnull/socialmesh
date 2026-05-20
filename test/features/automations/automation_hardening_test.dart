// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/automations/automation_debug_service.dart';
import 'package:socialmesh/features/automations/automation_engine.dart';
import 'package:socialmesh/features/automations/automation_repository.dart';
import 'package:socialmesh/features/automations/models/automation.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/ifttt/ifttt_service.dart';

/// Mock repository for testing
class _MockRepository extends AutomationRepository {
  final List<Automation> _automations = [];
  final List<AutomationLogEntry> _log = [];
  final List<String> recordedTriggerIds = [];

  @override
  List<Automation> get automations => List.unmodifiable(_automations);

  @override
  List<AutomationLogEntry> get log => List.unmodifiable(_log);

  void addTestAutomation(Automation automation) {
    _automations.add(automation);
  }

  @override
  Future<void> recordTrigger(String id) async {
    recordedTriggerIds.add(id);
  }

  @override
  Future<void> addLogEntry(AutomationLogEntry entry) async {
    _log.insert(0, entry);
  }

  @override
  Future<void> clearLog() async {
    _log.clear();
  }
}

class _MockIftttService extends IftttService {
  @override
  bool get isActive => true;

  @override
  Future<bool> triggerCustomEvent({
    required String eventName,
    String? value1,
    String? value2,
    String? value3,
  }) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepository mockRepository;
  late _MockIftttService mockIftttService;
  late AutomationDebugService debugService;
  late AutomationEngine engine;
  late List<(int, String)> sentMessages;

  setUp(() {
    mockRepository = _MockRepository();
    mockIftttService = _MockIftttService();
    debugService = AutomationDebugService();
    sentMessages = [];

    engine = AutomationEngine(
      repository: mockRepository,
      iftttService: mockIftttService,
      debugService: debugService,
      onSendMessage: (nodeNum, message, _) async {
        sentMessages.add((nodeNum, message));
        return true;
      },
      onSendToChannel: (channelIndex, message, _) async {
        return true;
      },
    );
  });

  tearDown(() {
    engine.stop();
  });

  // ============================================================
  //  WI1: Condition Preservation
  // ============================================================
  group('WI1 - Condition preservation', () {
    test('Automation with conditions round-trips through toJson/fromJson', () {
      final automation = Automation(
        id: 'cond-test',
        name: 'With Conditions',
        trigger: const AutomationTrigger(type: TriggerType.messageReceived),
        actions: const [AutomationAction(type: ActionType.pushNotification)],
        conditions: const [
          AutomationCondition(
            type: ConditionType.timeRange,
            config: {'timeStart': '09:00', 'timeEnd': '17:00'},
          ),
          AutomationCondition(
            type: ConditionType.dayOfWeek,
            config: {
              'days': [1, 2, 3, 4, 5],
            },
          ),
        ],
      );

      final json = automation.toJson();
      final restored = Automation.fromJson(json);

      expect(restored.conditions, isNotNull);
      expect(restored.conditions!.length, 2);
      expect(restored.conditions![0].type, ConditionType.timeRange);
      expect(restored.conditions![1].type, ConditionType.dayOfWeek);
    });

    test('Automation without conditions has null conditions', () {
      final automation = Automation(
        id: 'no-cond',
        name: 'No Conditions',
        trigger: const AutomationTrigger(type: TriggerType.messageReceived),
        actions: const [AutomationAction(type: ActionType.pushNotification)],
      );

      expect(automation.conditions, isNull);

      final json = automation.toJson();
      final restored = Automation.fromJson(json);
      expect(restored.conditions, isNull);
    });

    test('copyWith preserves conditions when not overridden', () {
      final original = Automation(
        id: 'copy-test',
        name: 'Original',
        trigger: const AutomationTrigger(type: TriggerType.nodeOnline),
        actions: const [AutomationAction(type: ActionType.pushNotification)],
        conditions: const [
          AutomationCondition(
            type: ConditionType.batteryAbove,
            config: {'batteryThreshold': 50},
          ),
        ],
      );

      final edited = original.copyWith(name: 'Edited Name');

      expect(edited.name, 'Edited Name');
      expect(edited.conditions, isNotNull);
      expect(edited.conditions!.length, 1);
      expect(edited.conditions![0].type, ConditionType.batteryAbove);
    });
  });

  // ============================================================
  //  WI3: Throttle / Dedupe Scope Hardening
  // ============================================================
  group('WI3 - Dedupe key construction', () {
    final automation = Automation(
      id: 'dedup-test',
      name: 'Dedupe Test',
      trigger: const AutomationTrigger(type: TriggerType.nodeOnline),
      actions: const [AutomationAction(type: ActionType.pushNotification)],
    );

    test('node-based events include nodeNum in key', () {
      final eventA = AutomationEvent(
        type: TriggerType.nodeOnline,
        nodeNum: 100,
      );
      final eventB = AutomationEvent(
        type: TriggerType.nodeOnline,
        nodeNum: 200,
      );

      final keyA = AutomationEngine.buildDedupeKey(automation, eventA);
      final keyB = AutomationEngine.buildDedupeKey(automation, eventB);

      expect(keyA, contains('_node100'));
      expect(keyB, contains('_node200'));
      expect(keyA, isNot(equals(keyB)));
    });

    test('different nodes do not collide in throttle', () async {
      mockRepository.addTestAutomation(automation);

      // Node 100 goes offline, then online
      final node100Offline = MeshNode(
        nodeNum: 100,
        shortName: 'N1',
        longName: 'Node One',
        lastHeard: DateTime.now().subtract(const Duration(hours: 3)),
      );
      await engine.processNodeUpdate(node100Offline);
      final node100Online = MeshNode(
        nodeNum: 100,
        shortName: 'N1',
        longName: 'Node One',
        lastHeard: DateTime.now(),
      );
      await engine.processNodeUpdate(node100Online);

      // Node 200 goes offline, then online — within 1 minute of node 100
      final node200Offline = MeshNode(
        nodeNum: 200,
        shortName: 'N2',
        longName: 'Node Two',
        lastHeard: DateTime.now().subtract(const Duration(hours: 3)),
      );
      await engine.processNodeUpdate(node200Offline);
      final node200Online = MeshNode(
        nodeNum: 200,
        shortName: 'N2',
        longName: 'Node Two',
        lastHeard: DateTime.now(),
      );
      await engine.processNodeUpdate(node200Online);

      // Both should have triggered (2 log entries)
      expect(mockRepository.recordedTriggerIds.length, 2);
    });

    test('scheduled events include slotKey in key', () {
      final automationSched = Automation(
        id: 'sched-dedup',
        name: 'Schedule Test',
        trigger: const AutomationTrigger(type: TriggerType.scheduled),
        actions: const [AutomationAction(type: ActionType.pushNotification)],
      );

      final eventSlot1 = AutomationEvent(
        type: TriggerType.scheduled,
        slotKey: 'daily:2026-04-14T09:00',
        scheduleId: 'sched-dedup',
        scheduledFor: DateTime(2026, 4, 14, 9, 0),
      );
      final eventSlot2 = AutomationEvent(
        type: TriggerType.scheduled,
        slotKey: 'daily:2026-04-14T10:00',
        scheduleId: 'sched-dedup',
        scheduledFor: DateTime(2026, 4, 14, 10, 0),
      );

      final key1 = AutomationEngine.buildDedupeKey(automationSched, eventSlot1);
      final key2 = AutomationEngine.buildDedupeKey(automationSched, eventSlot2);

      expect(key1, contains('_slotdaily:2026-04-14T09:00'));
      expect(key2, contains('_slotdaily:2026-04-14T10:00'));
      expect(key1, isNot(equals(key2)));
    });

    test('channelActivity includes channelIndex in key', () {
      final automationCh = Automation(
        id: 'ch-dedup',
        name: 'Channel Test',
        trigger: const AutomationTrigger(type: TriggerType.channelActivity),
        actions: const [AutomationAction(type: ActionType.pushNotification)],
      );

      final eventCh0 = AutomationEvent(
        type: TriggerType.channelActivity,
        channelIndex: 0,
        nodeNum: 100,
      );
      final eventCh1 = AutomationEvent(
        type: TriggerType.channelActivity,
        channelIndex: 1,
        nodeNum: 100,
      );

      final key0 = AutomationEngine.buildDedupeKey(automationCh, eventCh0);
      final key1 = AutomationEngine.buildDedupeKey(automationCh, eventCh1);

      expect(key0, contains('_ch0'));
      expect(key1, contains('_ch1'));
      expect(key0, isNot(equals(key1)));
    });

    test('manual trigger has no extra discriminator', () {
      final manualEvent = AutomationEvent(
        type: TriggerType.manual,
        nodeNum: 42,
      );

      final key = AutomationEngine.buildDedupeKey(automation, manualEvent);

      expect(key, '${automation.id}_manual');
      // nodeNum should NOT be in manual key
      expect(key, isNot(contains('_node')));
    });

    test('same node burst still throttles', () async {
      mockRepository.addTestAutomation(
        Automation(
          id: 'burst-test',
          name: 'Burst Test',
          trigger: const AutomationTrigger(type: TriggerType.messageReceived),
          actions: const [
            AutomationAction(
              type: ActionType.sendMessage,
              config: {'targetNodeNum': 999, 'messageText': 'Hello'},
            ),
          ],
        ),
      );

      // Same message from same node rapidly
      await engine.processMessage(
        AutomationMessage(from: 100, text: 'test msg 1', channel: 0),
        senderName: 'Test',
      );
      await engine.processMessage(
        AutomationMessage(from: 100, text: 'test msg 2', channel: 0),
        senderName: 'Test',
      );

      // Only 1 should have been sent (second throttled by same node key)
      expect(sentMessages.length, 1);
    });
  });

  // ============================================================
  //  WI4: Debug Service Wiring
  // ============================================================
  group('WI4 - Debug tracing', () {
    test('successful execution records evaluation', () async {
      mockRepository.addTestAutomation(
        Automation(
          id: 'debug-success',
          name: 'Debug Success',
          trigger: const AutomationTrigger(type: TriggerType.messageReceived),
          actions: const [AutomationAction(type: ActionType.pushNotification)],
        ),
      );

      await engine.processMessage(
        AutomationMessage(from: 100, text: 'hello', channel: 0),
        senderName: 'Test',
      );

      final evals = debugService.evaluations;
      expect(evals.isNotEmpty, isTrue);

      final successEval = evals.firstWhere((e) => e.triggered);
      expect(successEval.automationId, 'debug-success');
      expect(successEval.eventType, TriggerType.messageReceived);
      expect(successEval.triggered, isTrue);
      expect(successEval.skipReason, isNull);
    });

    test('throttled execution records skip reason', () async {
      mockRepository.addTestAutomation(
        Automation(
          id: 'debug-throttle',
          name: 'Debug Throttle',
          trigger: const AutomationTrigger(type: TriggerType.messageReceived),
          actions: const [AutomationAction(type: ActionType.pushNotification)],
        ),
      );

      // First message triggers
      await engine.processMessage(
        AutomationMessage(from: 300, text: 'first', channel: 0),
        senderName: 'Test',
      );
      // Second message from same sender is throttled
      await engine.processMessage(
        AutomationMessage(from: 300, text: 'second', channel: 0),
        senderName: 'Test',
      );

      final evals = debugService.evaluations;
      final throttledEval = evals.firstWhere(
        (e) => !e.triggered && e.skipReason == SkipReason.throttled,
        orElse: () => throw StateError('No throttled evaluation found'),
      );
      expect(throttledEval.automationId, 'debug-throttle');
      expect(throttledEval.skipReason, SkipReason.throttled);
    });

    test('condition failure records evaluation', () async {
      mockRepository.addTestAutomation(
        Automation(
          id: 'debug-cond-fail',
          name: 'Debug Condition Fail',
          trigger: const AutomationTrigger(type: TriggerType.messageReceived),
          actions: const [AutomationAction(type: ActionType.pushNotification)],
          conditions: const [
            // Time range 03:00-03:01 — almost certainly not current time
            AutomationCondition(
              type: ConditionType.timeRange,
              config: {'timeStart': '03:00', 'timeEnd': '03:01'},
            ),
          ],
        ),
      );

      await engine.processMessage(
        AutomationMessage(from: 400, text: 'condition test', channel: 0),
        senderName: 'Test',
      );

      final evals = debugService.evaluations;
      final condFailEval = evals.firstWhere(
        (e) => !e.triggered && e.skipReason == SkipReason.conditionFailed,
        orElse: () => throw StateError('No condition-failed evaluation found'),
      );
      expect(condFailEval.automationId, 'debug-cond-fail');
      expect(condFailEval.skipReason, SkipReason.conditionFailed);
    });

    test('debug service summary counts are accurate', () async {
      mockRepository.addTestAutomation(
        Automation(
          id: 'debug-summary',
          name: 'Summary Test',
          trigger: const AutomationTrigger(type: TriggerType.messageReceived),
          actions: const [AutomationAction(type: ActionType.pushNotification)],
        ),
      );

      // Use a unique node to avoid throttle from previous tests
      await engine.processMessage(
        AutomationMessage(from: 500, text: 'first', channel: 0),
        senderName: 'Test',
      );
      // Same node second time is throttled
      await engine.processMessage(
        AutomationMessage(from: 500, text: 'second', channel: 0),
        senderName: 'Test',
      );

      final summary = debugService.getSummary();
      // At least 1 triggered and 1 skipped for this automation
      expect(summary['triggered']! >= 1, isTrue);
      expect(summary['skipped']! >= 1, isTrue);
    });
  });

  // ============================================================
  //  Legacy compatibility
  // ============================================================
  group('Legacy compatibility', () {
    test('manual execution still works', () async {
      final automation = Automation(
        id: 'manual-legacy',
        name: 'Manual Legacy',
        trigger: const AutomationTrigger(type: TriggerType.manual),
        actions: const [
          AutomationAction(
            type: ActionType.sendMessage,
            config: {'targetNodeNum': 999, 'messageText': 'manual test'},
          ),
        ],
      );

      await engine.executeAutomationManually(
        automation,
        AutomationEvent(type: TriggerType.manual),
      );

      expect(sentMessages.length, 1);
      expect(sentMessages.first.$2, 'manual test');
    });

    test('existing automations without conditions still work', () async {
      mockRepository.addTestAutomation(
        Automation(
          id: 'no-cond-legacy',
          name: 'No Conditions Legacy',
          trigger: const AutomationTrigger(type: TriggerType.messageReceived),
          actions: const [
            AutomationAction(
              type: ActionType.sendMessage,
              config: {'targetNodeNum': 999, 'messageText': 'legacy test'},
            ),
          ],
        ),
      );

      await engine.processMessage(
        AutomationMessage(from: 600, text: 'legacy message', channel: 0),
        senderName: 'Test',
      );

      expect(sentMessages.isNotEmpty, isTrue);
    });

    test('engine with conditions still evaluates them', () async {
      mockRepository.addTestAutomation(
        Automation(
          id: 'with-cond-legacy',
          name: 'With Conditions Legacy',
          trigger: const AutomationTrigger(type: TriggerType.messageReceived),
          actions: const [AutomationAction(type: ActionType.pushNotification)],
          conditions: const [
            // dayOfWeek: allow all days (0-6)
            AutomationCondition(
              type: ConditionType.dayOfWeek,
              config: {
                'days': [0, 1, 2, 3, 4, 5, 6],
              },
            ),
          ],
        ),
      );

      await engine.processMessage(
        AutomationMessage(from: 700, text: 'condition message', channel: 0),
        senderName: 'Test',
      );

      // Should trigger because all days are allowed
      expect(mockRepository.recordedTriggerIds, contains('with-cond-legacy'));
    });
  });
}
