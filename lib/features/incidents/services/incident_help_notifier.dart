// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Thin, injectable surface for Help Mode local notifications.
///
/// Extracted as an interface so the inbound wiring can be tested with a fake
/// (the concrete [NotificationService] is a platform singleton). Callers MUST
/// only notify for events that have already passed the Handshake-trust gate and
/// been stored. Per-incident de-duplication lives here so a duplicate inbound
/// create never produces a second notification.
///
/// Privacy: only an incident id crosses this boundary -- never a peer name,
/// message body, or coordinates.
library;

import '../../../services/notifications/notification_service.dart';

abstract class IncidentHelpNotifier {
  /// Notify the user of a trusted inbound help request, at most once per
  /// incident id for the lifetime of this notifier.
  Future<void> notifyHelpRequest({required int incidentId});
}

/// Default implementation backed by [NotificationService].
///
/// The show callback is injectable for tests; in production it forwards only an
/// incident id to [NotificationService.showIncidentHelpRequestNotification]
/// (generic copy, no sensitive content).
class DefaultIncidentHelpNotifier implements IncidentHelpNotifier {
  final Future<void> Function(int incidentId) _show;
  final Set<int> _notified = <int>{};

  DefaultIncidentHelpNotifier({Future<void> Function(int incidentId)? show})
    : _show =
          show ??
          ((incidentId) => NotificationService()
              .showIncidentHelpRequestNotification(incidentId: incidentId));

  @override
  Future<void> notifyHelpRequest({required int incidentId}) async {
    if (_notified.contains(incidentId)) return;
    _notified.add(incidentId);
    await _show(incidentId);
  }
}
