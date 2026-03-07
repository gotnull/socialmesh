// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// MRRP traffic event — protocol-level data class for recording
/// inbound/outbound frame activity in the harness traffic console.
library;

import 'mrrp_types.dart';

/// A single MRRP traffic event for the traffic console.
class MrrpTrafficEvent {
  final DateTime timestamp;
  final String direction; // TX or RX
  final MrrpMessageType msgType;
  final int? serviceId;
  final int? actionId;
  final int? requestId;
  final int? peerNodeId;
  final int sizeBytes;
  final MrrpStatusCode? status;

  const MrrpTrafficEvent({
    required this.timestamp,
    required this.direction,
    required this.msgType,
    this.serviceId,
    this.actionId,
    this.requestId,
    this.peerNodeId,
    required this.sizeBytes,
    this.status,
  });

  /// Format for clipboard export.
  String toClipboardText() {
    final buf = StringBuffer()
      ..write(timestamp.toIso8601String())
      ..write(' ') // lint-allow: hardcoded-string
      ..write(direction)
      ..write(' ') // lint-allow: hardcoded-string
      ..write(msgType.name);
    if (serviceId != null) {
      buf.write(
        ' svc=${MrrpServiceId.nameOf(serviceId!)}',
      ); // lint-allow: hardcoded-string
    }
    if (actionId != null) {
      buf.write(
        ' act=0x${actionId!.toRadixString(16)}',
      ); // lint-allow: hardcoded-string
    }
    if (requestId != null) {
      buf.write(
        ' req=0x${requestId!.toRadixString(16)}',
      ); // lint-allow: hardcoded-string
    }
    if (peerNodeId != null) {
      buf.write(
        ' peer=0x${peerNodeId!.toRadixString(16).padLeft(8, '0')}',
      ); // lint-allow: hardcoded-string
    }
    buf.write(' ${sizeBytes}B'); // lint-allow: hardcoded-string
    if (status != null) {
      buf.write(' status=${status!.name}'); // lint-allow: hardcoded-string
    }
    return buf.toString();
  }
}
