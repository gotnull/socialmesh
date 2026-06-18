// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/incidents/services/help_location_policy.dart';
import 'package:socialmesh/features/incidents/services/incident_help_controller.dart';

void main() {
  group('HelpLocationPolicy', () {
    test('precise location sending is unsupported / disabled', () {
      expect(HelpLocationPolicy.preciseLocationSendingSupported, isFalse);
      expect(HelpLocationPolicy.canSendPreciseLocation, isFalse);
      expect(
        HelpLocationPolicy.status,
        HelpLocationStatus.unsupportedTransport,
      );
    });

    test('controller latch mirrors the policy (single source of truth)', () {
      expect(
        IncidentHelpController.preciseLocationSendingSupported,
        HelpLocationPolicy.preciseLocationSendingSupported,
      );
    });
  });
}
