// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Abstract service handler interface for MRRP services.
///
/// Each built-in or third-party MRRP service implements this interface.
/// The [MrrpDispatcher] routes inbound REQUEST frames by [serviceId] and
/// validates [supportedActions] before calling [handleRequest].
library;

import 'mrrp_frame.dart';

/// Contract for an MRRP service handler.
///
/// Implementors provide business logic only. They must not:
/// - Parse raw wire frames
/// - Generate request IDs
/// - Manage retries or timeouts
/// - Implement duplicate suppression
/// - Mutate session/transport state
abstract class MrrpServiceHandler {
  /// The 32-bit service identifier this handler responds to.
  int get serviceId;

  /// The set of action IDs this handler supports.
  Set<int> get supportedActions;

  /// Handle an inbound REQUEST and return a RESPONSE or ERROR frame.
  ///
  /// [request] is the decoded MRRP frame with msg_type=REQUEST.
  /// [senderNodeId] is the Meshtastic node ID of the requester.
  ///
  /// The returned frame must have the same [requestId] as the request.
  /// The dispatcher will set IS_RESPONSE / IS_ERROR flags as needed.
  Future<MrrpFrame> handleRequest(MrrpFrame request, int senderNodeId);
}
