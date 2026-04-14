// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/automations/models/automation.dart';
import 'package:socialmesh/features/automations/models/condition_node.dart';
import 'package:socialmesh/features/automations/models/condition_node_result.dart';

void main() {
  group('ConditionNodeResult', () {
    group('PredicateResult', () {
      test('serializes to JSON', () {
        const result = PredicateResult(
          passed: true,
          conditionType: ConditionType.timeRange,
          detail: 'timeRange: passed',
        );

        final json = result.toJson();
        expect(json['nodeType'], 'predicate');
        expect(json['passed'], true);
        expect(json['conditionType'], 'timeRange');
        expect(json['detail'], 'timeRange: passed');
      });

      test('has correct nodeType', () {
        const result = PredicateResult(
          passed: false,
          conditionType: ConditionType.dayOfWeek,
          detail: 'dayOfWeek: failed',
        );
        expect(result.nodeType, ConditionNodeType.predicate);
      });
    });

    group('AllGroupResult', () {
      test('serializes with child results', () {
        const result = AllGroupResult(
          passed: false,
          childResults: [
            PredicateResult(
              passed: true,
              conditionType: ConditionType.timeRange,
              detail: 'timeRange: passed',
            ),
            PredicateResult(
              passed: false,
              conditionType: ConditionType.dayOfWeek,
              detail: 'dayOfWeek: failed',
            ),
          ],
        );

        final json = result.toJson();
        expect(json['nodeType'], 'all');
        expect(json['passed'], false);
        expect((json['childResults'] as List).length, 2);
      });

      test('has correct nodeType', () {
        const result = AllGroupResult(passed: true, childResults: []);
        expect(result.nodeType, ConditionNodeType.all);
      });
    });

    group('AnyGroupResult', () {
      test('serializes with child results', () {
        const result = AnyGroupResult(
          passed: true,
          childResults: [
            PredicateResult(
              passed: false,
              conditionType: ConditionType.batteryAbove,
              detail: 'batteryAbove: failed',
            ),
            PredicateResult(
              passed: true,
              conditionType: ConditionType.batteryBelow,
              detail: 'batteryBelow: passed',
            ),
          ],
        );

        final json = result.toJson();
        expect(json['nodeType'], 'any');
        expect(json['passed'], true);
      });

      test('has correct nodeType', () {
        const result = AnyGroupResult(passed: false, childResults: []);
        expect(result.nodeType, ConditionNodeType.any);
      });
    });

    group('NotGroupResult', () {
      test('serializes with child result', () {
        const result = NotGroupResult(
          passed: true,
          childResult: PredicateResult(
            passed: false,
            conditionType: ConditionType.nodeOffline,
            detail: 'nodeOffline: failed',
          ),
        );

        final json = result.toJson();
        expect(json['nodeType'], 'not');
        expect(json['passed'], true);
        expect(json['childResult'], isA<Map>());
        expect((json['childResult'] as Map)['passed'], false);
      });

      test('has correct nodeType', () {
        const result = NotGroupResult(
          passed: false,
          childResult: PredicateResult(
            passed: true,
            conditionType: ConditionType.nodeOnline,
            detail: 'nodeOnline: passed',
          ),
        );
        expect(result.nodeType, ConditionNodeType.not);
      });
    });
  });
}
