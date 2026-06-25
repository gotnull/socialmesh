// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/automations/models/automation.dart';
import 'package:socialmesh/features/automations/widgets/variable_text_field.dart';

void main() {
  group('{{hops}} variable registration', () {
    test('validateVariables accepts {{hops}}', () {
      expect(validateVariables('reached you {{hops}}'), isEmpty);
    });

    test('validateVariables still rejects unknown variables', () {
      expect(validateVariables('{{nonsense}}'), contains('{{nonsense}}'));
    });

    test('{{hops}} is offered on message-received triggers', () {
      expect(
        getValidVariables(TriggerType.messageReceived),
        contains('{{hops}}'),
      );
      expect(
        getValidVariables(TriggerType.messageContains),
        contains('{{hops}}'),
      );
      expect(
        getValidVariables(TriggerType.channelActivity),
        contains('{{hops}}'),
      );
    });

    test('{{hops}} is not offered on unrelated triggers', () {
      expect(
        getValidVariables(TriggerType.batteryLow),
        isNot(contains('{{hops}}')),
      );
    });
  });
}
