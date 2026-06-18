// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/incidents/services/incident_help_notifier.dart';

void main() {
  group('DefaultIncidentHelpNotifier', () {
    test('notifies once per incident (de-duped)', () async {
      final shown = <int>[];
      final notifier = DefaultIncidentHelpNotifier(
        show: (id) async => shown.add(id),
      );

      await notifier.notifyHelpRequest(incidentId: 7);
      await notifier.notifyHelpRequest(incidentId: 7); // duplicate
      await notifier.notifyHelpRequest(incidentId: 9);

      expect(shown, [7, 9]); // 7 only once, 9 once
    });

    test(
      'only an incident id crosses the boundary (no body / coordinates)',
      () {
        // The notify API takes nothing but an incident id, so a message body or
        // coordinates structurally cannot be passed to a notification.
        const IncidentHelpNotifier notifier = _ApiShapeProbe();
        expect(notifier, isA<IncidentHelpNotifier>());
      },
    );
  });
}

class _ApiShapeProbe implements IncidentHelpNotifier {
  const _ApiShapeProbe();
  @override
  Future<void> notifyHelpRequest({required int incidentId}) async {}
}
