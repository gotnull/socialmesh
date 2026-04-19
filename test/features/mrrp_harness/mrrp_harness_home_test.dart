// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mrrp_harness/models/mrrp_qa_scenario.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';

void main() {
  group('QaStepStatus', () {
    test('enum has three values', () {
      expect(QaStepStatus.values.length, 3);
      expect(QaStepStatus.values, contains(QaStepStatus.pending));
      expect(QaStepStatus.values, contains(QaStepStatus.pass));
      expect(QaStepStatus.values, contains(QaStepStatus.fail));
    });
  });

  group('QaStep', () {
    test('starts with pending status', () {
      final step = QaStep(
        description: 'test step', // lint-allow: hardcoded-string
        expectedOutcome: 'expected', // lint-allow: hardcoded-string
        verify: (_) => true,
      );

      expect(step.status, QaStepStatus.pending);
      expect(step.actualOutcome, isNull);
    });

    test('verify callback executes correctly', () {
      var callCount = 0;
      final step = QaStep(
        description: 'test', // lint-allow: hardcoded-string
        expectedOutcome: 'expected', // lint-allow: hardcoded-string
        verify: (_) {
          callCount++;
          return true;
        },
      );

      expect(step.verify(null), isTrue);
      expect(callCount, 1);
    });
  });

  group('QaScenario', () {
    test('passed is true when all steps pass', () {
      final scenario = QaScenario(
        name: 'test', // lint-allow: hardcoded-string
        steps: [
          QaStep(
            description: 's1', // lint-allow: hardcoded-string
            expectedOutcome: 'e1', // lint-allow: hardcoded-string
            verify: (_) => true,
            status: QaStepStatus.pass,
          ),
          QaStep(
            description: 's2', // lint-allow: hardcoded-string
            expectedOutcome: 'e2', // lint-allow: hardcoded-string
            verify: (_) => true,
            status: QaStepStatus.pass,
          ),
        ],
      );

      expect(scenario.passed, isTrue);
      expect(scenario.passedCount, 2);
    });

    test('passed is false when any step fails', () {
      final scenario = QaScenario(
        name: 'test', // lint-allow: hardcoded-string
        steps: [
          QaStep(
            description: 's1', // lint-allow: hardcoded-string
            expectedOutcome: 'e1', // lint-allow: hardcoded-string
            verify: (_) => true,
            status: QaStepStatus.pass,
          ),
          QaStep(
            description: 's2', // lint-allow: hardcoded-string
            expectedOutcome: 'e2', // lint-allow: hardcoded-string
            verify: (_) => false,
            status: QaStepStatus.fail,
          ),
        ],
      );

      expect(scenario.passed, isFalse);
      expect(scenario.passedCount, 1);
    });

    test('hasRun is false when all pending', () {
      final scenario = QaScenario(
        name: 'test', // lint-allow: hardcoded-string
        steps: [
          QaStep(
            description: 's1', // lint-allow: hardcoded-string
            expectedOutcome: 'e1', // lint-allow: hardcoded-string
            verify: (_) => true,
          ),
        ],
      );

      expect(scenario.hasRun, isFalse);
    });

    test('hasRun is true when any step ran', () {
      final scenario = QaScenario(
        name: 'test', // lint-allow: hardcoded-string
        steps: [
          QaStep(
            description: 's1', // lint-allow: hardcoded-string
            expectedOutcome: 'e1', // lint-allow: hardcoded-string
            verify: (_) => true,
            status: QaStepStatus.pass,
          ),
          QaStep(
            description: 's2', // lint-allow: hardcoded-string
            expectedOutcome: 'e2', // lint-allow: hardcoded-string
            verify: (_) => true,
          ),
        ],
      );

      expect(scenario.hasRun, isTrue);
    });

    test('reset clears all steps to pending', () {
      final scenario = QaScenario(
        name: 'test', // lint-allow: hardcoded-string
        steps: [
          QaStep(
            description: 's1', // lint-allow: hardcoded-string
            expectedOutcome: 'e1', // lint-allow: hardcoded-string
            verify: (_) => true,
            status: QaStepStatus.pass,
          ),
          QaStep(
            description: 's2', // lint-allow: hardcoded-string
            expectedOutcome: 'e2', // lint-allow: hardcoded-string
            verify: (_) => false,
            status: QaStepStatus.fail,
          ),
        ],
      );

      scenario.steps[0].actualOutcome =
          'actual1'; // lint-allow: hardcoded-string
      scenario.steps[1].actualOutcome =
          'actual2'; // lint-allow: hardcoded-string

      scenario.reset();

      for (final step in scenario.steps) {
        expect(step.status, QaStepStatus.pending);
        expect(step.actualOutcome, isNull);
      }
      expect(scenario.hasRun, isFalse);
    });
  });

  group('buildQaScenarios', () {
    test('returns 8 scenarios', () {
      final scenarios = buildQaScenarios();
      expect(scenarios.length, 8);
    });

    test('all scenarios have at least 2 steps', () {
      final scenarios = buildQaScenarios();
      for (final s in scenarios) {
        expect(
          s.steps.length,
          greaterThanOrEqualTo(2),
          reason: '${s.name} should have >= 2 steps',
        ); // lint-allow: hardcoded-string
      }
    });

    test('all scenario names are unique', () {
      final scenarios = buildQaScenarios();
      final names = scenarios.map((s) => s.name).toSet();
      expect(names.length, scenarios.length);
    });

    test('all steps start as pending', () {
      final scenarios = buildQaScenarios();
      for (final s in scenarios) {
        for (final step in s.steps) {
          expect(step.status, QaStepStatus.pending);
        }
      }
    });

    test('all step verify callbacks execute without error', () {
      final scenarios = buildQaScenarios();
      for (final s in scenarios) {
        for (final step in s.steps) {
          expect(
            () => step.verify(null),
            returnsNormally,
            reason: '${s.name}/${step.description} verify should not throw',
          ); // lint-allow: hardcoded-string
        }
      }
    });

    test('all step verify callbacks pass (known-good fixture data)', () {
      final scenarios = buildQaScenarios();
      for (final s in scenarios) {
        for (final step in s.steps) {
          expect(
            step.verify(null),
            isTrue,
            reason: '${s.name}/${step.description} should pass',
          ); // lint-allow: hardcoded-string
        }
      }
    });

    test('Discovery scenario verifies advert, dir_req, dir_resp, request', () {
      final scenarios = buildQaScenarios();
      final discovery = scenarios.first;
      expect(
        discovery.name,
        contains('Discovery'),
      ); // lint-allow: hardcoded-string
      expect(discovery.steps.length, 4);
    });

    test('Meetup scenario verifies create, accept, cancel', () {
      final scenarios = buildQaScenarios();
      final meetup = scenarios[1];
      expect(meetup.name, contains('Meetup')); // lint-allow: hardcoded-string
      expect(meetup.steps.length, 3);
    });
  });

  group('MrrpServiceId name resolution in scenarios', () {
    test('known service IDs resolve correctly', () {
      expect(
        MrrpServiceId.nameOf(MrrpServiceId.meetupV1),
        'meetup.v1',
      ); // lint-allow: hardcoded-string
      expect(
        MrrpServiceId.nameOf(MrrpServiceId.profileV1),
        'profile.v1',
      ); // lint-allow: hardcoded-string
      expect(
        MrrpServiceId.nameOf(MrrpServiceId.boardV1),
        'board.v1',
      ); // lint-allow: hardcoded-string
      expect(
        MrrpServiceId.nameOf(MrrpServiceId.echoTest),
        'echo.test',
      ); // lint-allow: hardcoded-string
    });
  });
}
