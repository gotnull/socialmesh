// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/automations/automation_debug_service.dart';
import 'package:socialmesh/features/automations/automation_engine.dart';
import 'package:socialmesh/features/automations/automation_repository.dart';
import 'package:socialmesh/features/automations/models/automation.dart';
import 'package:socialmesh/features/automations/models/condition_node.dart';
import 'package:socialmesh/features/automations/models/condition_node_result.dart';
import 'package:socialmesh/services/ifttt/ifttt_service.dart';

/// Mock repository for testing
class _MockRepository extends AutomationRepository {
  final List<Automation> _automations = [];
  final List<AutomationLogEntry> _log = [];

  @override
  List<Automation> get automations => List.unmodifiable(_automations);

  @override
  List<AutomationLogEntry> get log => List.unmodifiable(_log);

  void addTestAutomation(Automation a) {
    _automations.add(a);
  }

  @override
  Future<void> recordTrigger(String id) async {}

  @override
  Future<void> addLogEntry(AutomationLogEntry entry) async {
    _log.insert(0, entry);
  }

  @override
  Future<void> clearLog() async => _log.clear();
}

class _MockIfttt extends IftttService {
  @override
  bool get isActive => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepository repo;
  late _MockIfttt ifttt;
  late AutomationDebugService debugService;
  late AutomationEngine engine;
  late List<(int, String)> sentMessages;

  setUp(() {
    repo = _MockRepository();
    ifttt = _MockIfttt();
    debugService = AutomationDebugService();
    sentMessages = [];

    engine = AutomationEngine(
      repository: repo,
      iftttService: ifttt,
      debugService: debugService,
      onSendMessage: (nodeNum, message, _) async {
        sentMessages.add((nodeNum, message));
        return true;
      },
    );
  });

  tearDown(() {
    engine.stop();
  });

  // =========================================================================
  // Evaluator semantics (unit tests on evaluateConditionTree)
  // =========================================================================
  group('evaluateConditionTree', () {
    // Use a Monday at 10:00 as the evaluation context
    final monday10am = DateTime(2026, 4, 13, 10, 0); // Monday

    AutomationEvent eventAt(DateTime dt) => AutomationEvent(
      type: TriggerType.messageReceived,
      nodeNum: 100,
      batteryLevel: 50,
      timestamp: dt,
    );

    group('predicate', () {
      test('true when condition passes', () {
        // timeRange 08:00-18:00, event at 10:00 -> pass
        const node = PredicateNode(
          condition: AutomationCondition(
            type: ConditionType.timeRange,
            config: {'timeStart': '08:00', 'timeEnd': '18:00'},
          ),
        );
        final result = engine.evaluateConditionTree(node, eventAt(monday10am));
        expect(result, isA<PredicateResult>());
        expect(result.passed, isTrue);
        expect(
          (result as PredicateResult).conditionType,
          ConditionType.timeRange,
        );
      });

      test('false when condition fails', () {
        // timeRange 22:00-06:00, event at 10:00 -> fail
        const node = PredicateNode(
          condition: AutomationCondition(
            type: ConditionType.timeRange,
            config: {'timeStart': '22:00', 'timeEnd': '06:00'},
          ),
        );
        final result = engine.evaluateConditionTree(node, eventAt(monday10am));
        expect(result.passed, isFalse);
      });
    });

    group('ALL group', () {
      test('all-true passes', () {
        // timeRange 08:00-18:00 + dayOfWeek [1] (Monday) at 10:00
        const node = AllGroup(
          children: [
            PredicateNode(
              condition: AutomationCondition(
                type: ConditionType.timeRange,
                config: {'timeStart': '08:00', 'timeEnd': '18:00'},
              ),
            ),
            PredicateNode(
              condition: AutomationCondition(
                type: ConditionType.dayOfWeek,
                config: {
                  'daysOfWeek': [1],
                }, // Monday
              ),
            ),
          ],
        );
        final result = engine.evaluateConditionTree(node, eventAt(monday10am));
        expect(result, isA<AllGroupResult>());
        expect(result.passed, isTrue);
        final allResult = result as AllGroupResult;
        expect(allResult.childResults.length, 2);
        expect(allResult.childResults.every((r) => r.passed), isTrue);
      });

      test('one-false fails', () {
        // timeRange 08:00-18:00 + dayOfWeek [0] (Sunday) at Monday 10:00
        const node = AllGroup(
          children: [
            PredicateNode(
              condition: AutomationCondition(
                type: ConditionType.timeRange,
                config: {'timeStart': '08:00', 'timeEnd': '18:00'},
              ),
            ),
            PredicateNode(
              condition: AutomationCondition(
                type: ConditionType.dayOfWeek,
                config: {
                  'daysOfWeek': [0],
                }, // Sunday only
              ),
            ),
          ],
        );
        final result = engine.evaluateConditionTree(node, eventAt(monday10am));
        expect(result.passed, isFalse);
        final allResult = result as AllGroupResult;
        // First child passed, second failed
        expect(allResult.childResults[0].passed, isTrue);
        expect(allResult.childResults[1].passed, isFalse);
      });
    });

    group('ANY group', () {
      test('one-true passes', () {
        const node = AnyGroup(
          children: [
            PredicateNode(
              condition: AutomationCondition(
                type: ConditionType.dayOfWeek,
                config: {
                  'daysOfWeek': [0],
                }, // Sunday - fails on Monday
              ),
            ),
            PredicateNode(
              condition: AutomationCondition(
                type: ConditionType.timeRange,
                config: {'timeStart': '08:00', 'timeEnd': '18:00'}, // passes
              ),
            ),
          ],
        );
        final result = engine.evaluateConditionTree(node, eventAt(monday10am));
        expect(result.passed, isTrue);
        final anyResult = result as AnyGroupResult;
        expect(anyResult.childResults[0].passed, isFalse);
        expect(anyResult.childResults[1].passed, isTrue);
      });

      test('all-false fails', () {
        const node = AnyGroup(
          children: [
            PredicateNode(
              condition: AutomationCondition(
                type: ConditionType.dayOfWeek,
                config: {
                  'daysOfWeek': [0],
                }, // Sunday
              ),
            ),
            PredicateNode(
              condition: AutomationCondition(
                type: ConditionType.timeRange,
                config: {'timeStart': '22:00', 'timeEnd': '06:00'}, // overnight
              ),
            ),
          ],
        );
        final result = engine.evaluateConditionTree(node, eventAt(monday10am));
        expect(result.passed, isFalse);
      });
    });

    group('NOT group', () {
      test('inverts true child to false', () {
        const node = NotGroup(
          child: PredicateNode(
            condition: AutomationCondition(
              type: ConditionType.timeRange,
              config: {'timeStart': '08:00', 'timeEnd': '18:00'},
            ),
          ),
        );
        final result = engine.evaluateConditionTree(node, eventAt(monday10am));
        expect(result.passed, isFalse);
        final notResult = result as NotGroupResult;
        expect(notResult.childResult.passed, isTrue);
      });

      test('inverts false child to true', () {
        const node = NotGroup(
          child: PredicateNode(
            condition: AutomationCondition(
              type: ConditionType.dayOfWeek,
              config: {
                'daysOfWeek': [0],
              }, // Sunday
            ),
          ),
        );
        final result = engine.evaluateConditionTree(node, eventAt(monday10am));
        expect(result.passed, isTrue);
        final notResult = result as NotGroupResult;
        expect(notResult.childResult.passed, isFalse);
      });
    });

    group('nested combinations', () {
      test('ALL(predicate, ANY(predicate, NOT(predicate))) is deterministic', () {
        // ALL(timeRange:pass, ANY(sunday:fail, NOT(nodeOffline:always-true)))
        // nodeOffline with no nodeNum returns true (missing data passes)
        // NOT(true) = false
        // ANY(false, false) = false
        // ALL(true, false) = false
        const tree = AllGroup(
          children: [
            PredicateNode(
              condition: AutomationCondition(
                type: ConditionType.timeRange,
                config: {'timeStart': '08:00', 'timeEnd': '18:00'},
              ),
            ),
            AnyGroup(
              children: [
                PredicateNode(
                  condition: AutomationCondition(
                    type: ConditionType.dayOfWeek,
                    config: {
                      'daysOfWeek': [0],
                    }, // Sunday
                  ),
                ),
                NotGroup(
                  child: PredicateNode(
                    condition: AutomationCondition(
                      type: ConditionType.batteryAbove,
                      config: {'batteryThreshold': 30},
                    ),
                  ),
                ),
              ],
            ),
          ],
        );

        // Event at Monday 10:00 with battery 50
        final event = AutomationEvent(
          type: TriggerType.messageReceived,
          nodeNum: 100,
          batteryLevel: 50,
          timestamp: monday10am,
        );
        final result = engine.evaluateConditionTree(tree, event);
        // timeRange: pass, ANY(Sunday:fail, NOT(battery>30 with 50: true -> NOT=false)) = false
        // ALL(true, false) = false
        expect(result.passed, isFalse);
      });
    });

    group('unsupported/stubbed conditions', () {
      test('geofence conditions always pass', () {
        const node = PredicateNode(
          condition: AutomationCondition(type: ConditionType.withinGeofence),
        );
        final result = engine.evaluateConditionTree(node, eventAt(monday10am));
        expect(result.passed, isTrue);
      });

      test('battery conditions with null battery pass', () {
        const node = PredicateNode(
          condition: AutomationCondition(
            type: ConditionType.batteryAbove,
            config: {'batteryThreshold': 80},
          ),
        );
        // Event with no battery level
        final event = AutomationEvent(
          type: TriggerType.messageReceived,
          nodeNum: 100,
          timestamp: monday10am,
        );
        final result = engine.evaluateConditionTree(node, event);
        expect(
          result.passed,
          isTrue,
        ); // null battery -> true (existing semantics)
      });
    });
  });

  // =========================================================================
  // Legacy compatibility (flat conditions still gate actions)
  // =========================================================================
  group('Legacy flat conditions via engine', () {
    test('flat AND conditions block when one fails', () async {
      // dayOfWeek condition with a day that is NOT today -> blocked
      final todayWeekday = DateTime.now().weekday % 7; // 0=Sun Dart conversion
      final notToday = (todayWeekday + 3) % 7;

      repo.addTestAutomation(
        Automation(
          id: 'legacy-and-gate',
          name: 'Legacy AND Gate',
          trigger: const AutomationTrigger(type: TriggerType.messageReceived),
          actions: const [
            AutomationAction(
              type: ActionType.sendMessage,
              config: {'targetNodeNum': 999, 'messageText': 'test'},
            ),
          ],
          conditions: [
            AutomationCondition(
              type: ConditionType.dayOfWeek,
              config: {
                'daysOfWeek': [notToday],
              },
            ),
          ],
        ),
      );

      engine.start();

      await engine.processMessage(
        AutomationMessage(from: 100, text: 'hi', channel: 0),
        senderName: 'TestNode',
      );

      expect(sentMessages, isEmpty);
    });

    test('flat conditions pass correctly', () async {
      // Use a wide time window centered on now
      final now = TimeOfDay.now();
      final startHour = (now.hour - 1) % 24;
      final endHour = (now.hour + 1) % 24;

      repo.addTestAutomation(
        Automation(
          id: 'legacy-pass',
          name: 'Legacy Pass',
          trigger: const AutomationTrigger(type: TriggerType.messageReceived),
          actions: const [
            AutomationAction(
              type: ActionType.sendMessage,
              config: {'targetNodeNum': 999, 'messageText': 'hello'},
            ),
          ],
          conditions: [
            AutomationCondition(
              type: ConditionType.timeRange,
              config: {'timeStart': '$startHour:00', 'timeEnd': '$endHour:00'},
            ),
          ],
        ),
      );

      engine.start();

      await engine.processMessage(
        AutomationMessage(from: 100, text: 'hi', channel: 0),
        senderName: 'TestNode',
      );

      expect(sentMessages, isNotEmpty);
    });
  });

  // =========================================================================
  // conditionTree on automation gates engine execution
  // =========================================================================
  group('conditionTree gates engine execution', () {
    test('AnyGroup allows execution when one child passes', () async {
      final now = TimeOfDay.now();
      final startHour = (now.hour - 1) % 24;
      final endHour = (now.hour + 1) % 24;
      final todayWeekday = DateTime.now().weekday % 7;
      final notToday = (todayWeekday + 3) % 7;

      repo.addTestAutomation(
        Automation(
          id: 'any-gate',
          name: 'Any Gate',
          trigger: const AutomationTrigger(type: TriggerType.messageReceived),
          actions: const [
            AutomationAction(
              type: ActionType.sendMessage,
              config: {'targetNodeNum': 999, 'messageText': 'any-pass'},
            ),
          ],
          conditionTree: AnyGroup(
            children: [
              PredicateNode(
                condition: AutomationCondition(
                  type: ConditionType.dayOfWeek,
                  config: {
                    'daysOfWeek': [notToday],
                  }, // fails
                ),
              ),
              PredicateNode(
                condition: AutomationCondition(
                  type: ConditionType.timeRange,
                  config: {
                    'timeStart': '$startHour:00',
                    'timeEnd': '$endHour:00',
                  }, // passes
                ),
              ),
            ],
          ),
        ),
      );

      engine.start();

      await engine.processMessage(
        AutomationMessage(from: 100, text: 'hi', channel: 0),
        senderName: 'TestNode',
      );

      expect(sentMessages.length, 1);
    });

    test('NotGroup blocks when inner passes', () async {
      final now = TimeOfDay.now();
      final startHour = (now.hour - 1) % 24;
      final endHour = (now.hour + 1) % 24;

      repo.addTestAutomation(
        Automation(
          id: 'not-gate',
          name: 'Not Gate',
          trigger: const AutomationTrigger(type: TriggerType.messageReceived),
          actions: const [
            AutomationAction(
              type: ActionType.sendMessage,
              config: {'targetNodeNum': 999, 'messageText': 'not-block'},
            ),
          ],
          conditionTree: NotGroup(
            child: PredicateNode(
              condition: AutomationCondition(
                type: ConditionType.timeRange,
                config: {
                  'timeStart': '$startHour:00',
                  'timeEnd': '$endHour:00',
                }, // passes -> NOT = fail
              ),
            ),
          ),
        ),
      );

      engine.start();

      await engine.processMessage(
        AutomationMessage(from: 100, text: 'hi', channel: 0),
        senderName: 'TestNode',
      );

      expect(sentMessages, isEmpty);
    });
  });

  // =========================================================================
  // Debug tracing
  // =========================================================================
  group('Debug tracing with condition tree', () {
    test('successful execution records conditionTreeResult', () async {
      final now = TimeOfDay.now();
      final startHour = (now.hour - 1) % 24;
      final endHour = (now.hour + 1) % 24;

      repo.addTestAutomation(
        Automation(
          id: 'debug-tree',
          name: 'Debug Tree',
          trigger: const AutomationTrigger(type: TriggerType.messageReceived),
          actions: const [AutomationAction(type: ActionType.vibrate)],
          conditions: [
            AutomationCondition(
              type: ConditionType.timeRange,
              config: {'timeStart': '$startHour:00', 'timeEnd': '$endHour:00'},
            ),
          ],
        ),
      );

      engine.start();

      await engine.processMessage(
        AutomationMessage(from: 100, text: 'hi', channel: 0),
        senderName: 'TestNode',
      );

      final evals = debugService.evaluations;
      expect(evals, isNotEmpty);
      final eval = evals.first;
      expect(eval.triggered, isTrue);
      expect(eval.conditionTreeResult, isNotNull);
      expect(eval.conditionTreeResult!.passed, isTrue);
    });

    test('condition failure records conditionTreeResult', () async {
      final todayWeekday = DateTime.now().weekday % 7;
      final notToday = (todayWeekday + 3) % 7;

      repo.addTestAutomation(
        Automation(
          id: 'debug-fail',
          name: 'Debug Fail',
          trigger: const AutomationTrigger(type: TriggerType.messageReceived),
          actions: const [AutomationAction(type: ActionType.vibrate)],
          conditions: [
            AutomationCondition(
              type: ConditionType.dayOfWeek,
              config: {
                'daysOfWeek': [notToday],
              },
            ),
          ],
        ),
      );

      engine.start();

      await engine.processMessage(
        AutomationMessage(from: 100, text: 'hi', channel: 0),
        senderName: 'TestNode',
      );

      final evals = debugService.evaluations;
      expect(evals, isNotEmpty);
      final eval = evals.first;
      expect(eval.triggered, isFalse);
      expect(eval.skipReason, SkipReason.conditionFailed);
      expect(eval.conditionTreeResult, isNotNull);
      expect(eval.conditionTreeResult!.passed, isFalse);
    });

    test('manual bypass records manualBypass flag', () async {
      final automation = Automation(
        id: 'manual-debug',
        name: 'Manual Debug',
        trigger: const AutomationTrigger(type: TriggerType.manual),
        actions: const [AutomationAction(type: ActionType.vibrate)],
        conditions: const [
          AutomationCondition(
            type: ConditionType.dayOfWeek,
            config: {
              'daysOfWeek': [0],
            }, // May fail
          ),
        ],
      );

      engine.start();

      await engine.executeAutomationManually(
        automation,
        AutomationEvent(type: TriggerType.manual),
      );

      final evals = debugService.evaluations;
      final manualEval = evals.where((e) => e.manualBypass).toList();
      expect(manualEval, isNotEmpty);
      expect(manualEval.first.triggered, isTrue);
      expect(manualEval.first.manualBypass, isTrue);
    });

    test('no conditions produces null conditionTreeResult', () async {
      repo.addTestAutomation(
        Automation(
          id: 'no-conds',
          name: 'No Conditions',
          trigger: const AutomationTrigger(type: TriggerType.messageReceived),
          actions: const [AutomationAction(type: ActionType.vibrate)],
        ),
      );

      engine.start();

      await engine.processMessage(
        AutomationMessage(from: 100, text: 'hi', channel: 0),
        senderName: 'TestNode',
      );

      final evals = debugService.evaluations;
      expect(evals, isNotEmpty);
      final eval = evals.first;
      expect(eval.triggered, isTrue);
      expect(eval.conditionTreeResult, isNull);
    });

    test('conditionTreeResult toJson includes nested structure', () async {
      final now = TimeOfDay.now();
      final startHour = (now.hour - 1) % 24;
      final endHour = (now.hour + 1) % 24;
      final todayWeekday = DateTime.now().weekday % 7;

      repo.addTestAutomation(
        Automation(
          id: 'debug-nested',
          name: 'Debug Nested',
          trigger: const AutomationTrigger(type: TriggerType.messageReceived),
          actions: const [AutomationAction(type: ActionType.vibrate)],
          conditionTree: AllGroup(
            children: [
              PredicateNode(
                condition: AutomationCondition(
                  type: ConditionType.timeRange,
                  config: {
                    'timeStart': '$startHour:00',
                    'timeEnd': '$endHour:00',
                  },
                ),
              ),
              AnyGroup(
                children: [
                  PredicateNode(
                    condition: AutomationCondition(
                      type: ConditionType.dayOfWeek,
                      config: {
                        'daysOfWeek': [todayWeekday],
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      engine.start();

      await engine.processMessage(
        AutomationMessage(from: 100, text: 'hi', channel: 0),
        senderName: 'TestNode',
      );

      final eval = debugService.evaluations.first;
      expect(eval.conditionTreeResult, isNotNull);

      final json = eval.toJson();
      expect(json['conditionTreeResult'], isA<Map>());
      expect(json['conditionTreeResult']['nodeType'], 'all');
      expect(json['conditionTreeResult']['childResults'], isA<List>());
    });
  });
}
