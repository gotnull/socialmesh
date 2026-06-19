// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:xml/xml.dart';

import '../../core/logging.dart';
import '../../utils/text_sanitizer.dart';
import 'tak_client_session.dart';

/// A parsed GeoChat message from CoT XML.
class GeoChatMessage {
  final String senderUid;
  final String senderCallsign;
  final String text;
  final String messageId;
  final String? recipientUid;
  final DateTime time;

  GeoChatMessage({
    required this.senderUid,
    required this.senderCallsign,
    required this.text,
    required this.messageId,
    this.recipientUid,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

/// Result of an outbound GeoChat operation.
class GeoChatSendResult {
  final String messageId;
  final String originatingCallsign;
  final DateTime sentAt;

  GeoChatSendResult({
    required this.messageId,
    required this.originatingCallsign,
    DateTime? sentAt,
  }) : sentAt = sentAt ?? DateTime.now();
}

/// Callback for sending mesh text messages.
typedef MeshTextSendCallback =
    Future<int> Function(String text, {int channelIndex, int? destination});

/// Callback for resolving a callsign to a mesh node number.
typedef CallsignResolver = int? Function(String callsign);

/// GeoChat bridging between TAK clients and Meshtastic mesh.
///
/// TAK GeoChat -> mesh channel text.
/// Mesh text -> GeoChat CoT XML to TAK clients.
/// Delivery receipts on mesh ACK.
class GeoChatBridge {
  /// Maximum outbound messages per rate-limit window per client.
  static const int maxOutboundPerWindow = 2;

  /// Rate-limit window duration.
  static const Duration rateLimitWindow = Duration(seconds: 10);

  /// TTL for pending receipt tracking.
  static const Duration receiptTtl = Duration(minutes: 5);

  final MeshTextSendCallback _meshSend;
  final CallsignResolver? _callsignResolver;

  /// Pending receipts: meshMessageId -> GeoChatSendResult.
  final _pendingReceipts = <int, GeoChatSendResult>{};

  /// Rate limiter: clientUid -> list of send timestamps.
  final _rateLimits = <String, List<DateTime>>{};

  GeoChatBridge({required this._meshSend, this._callsignResolver});

  /// Parses a GeoChat CoT XML event.
  ///
  /// Returns null if the XML is not a valid GeoChat event.
  static GeoChatMessage? parseGeoChatCot(String cotXml) {
    try {
      final doc = XmlDocument.parse(cotXml);
      final event = doc.rootElement;

      // GeoChat type is b-t-f.
      final type = event.getAttribute('type') ?? '';
      if (!type.startsWith('b-t-f')) return null;

      final uid = event.getAttribute('uid') ?? '';
      final detail = event.findElements('detail').firstOrNull;
      if (detail == null) return null;

      // Extract chat element.
      final chat = detail.findElements('__chat').firstOrNull;
      final senderCallsign = chat?.getAttribute('senderCallsign') ?? '';

      // Extract message text from remarks.
      final remarks = detail.findElements('remarks').firstOrNull;
      final text = remarks?.innerText ?? '';
      if (text.isEmpty) return null;

      // Parse UID: GeoChat.{senderUid}.{recipientUid}.{messageId}
      final parts = uid.split('.');
      final senderUid = parts.length > 1 ? parts[1] : uid;
      final recipientUid = parts.length > 2 ? parts[2] : null;
      final messageId = parts.length > 3 ? parts[3] : uid;

      return GeoChatMessage(
        senderUid: senderUid,
        senderCallsign: senderCallsign,
        text: text,
        messageId: messageId,
        recipientUid: recipientUid,
      );
    } on XmlException {
      return null;
    }
  }

  /// Builds a GeoChat CoT XML event from a mesh text message.
  static String buildGeoChatCot({
    required int fromNodeNum,
    required String callsign,
    required String text,
    String? toUid,
  }) {
    final nodeHex = fromNodeNum.toRadixString(16).toUpperCase().padLeft(8, '0');
    final senderUid = 'MESHTASTIC-$nodeHex';
    final recipientUid = toUid ?? 'All Chat Rooms';
    final messageId = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    final chatUid = 'GeoChat.$senderUid.$recipientUid.$messageId';
    final now = DateTime.now().toUtc().toIso8601String();
    final stale = DateTime.now()
        .toUtc()
        .add(const Duration(minutes: 5))
        .toIso8601String();

    final builder = XmlBuilder();
    builder.element(
      'event',
      nest: () {
        builder.attribute('version', '2.0');
        builder.attribute('type', 'b-t-f');
        builder.attribute('uid', chatUid);
        builder.attribute('how', 'h-g-i-g-o');
        builder.attribute('time', now);
        builder.attribute('start', now);
        builder.attribute('stale', stale);
        builder.element(
          'point',
          nest: () {
            builder.attribute('lat', '0.0');
            builder.attribute('lon', '0.0');
            builder.attribute('hae', '0.0');
            builder.attribute('ce', '9999999');
            builder.attribute('le', '9999999');
          },
        );
        builder.element(
          'detail',
          nest: () {
            builder.element(
              '__chat',
              nest: () {
                builder.attribute('senderCallsign', callsign);
                builder.attribute('chatroom', recipientUid);
                builder.attribute('id', chatUid);
                builder.attribute('parent', 'RootContactGroup');
                builder.element(
                  'chatgrp',
                  nest: () {
                    builder.attribute('uid0', senderUid);
                    builder.attribute('uid1', recipientUid);
                    builder.attribute('id', chatUid);
                  },
                );
              },
            );
            builder.element(
              'remarks',
              nest: () {
                builder.attribute('source', senderUid);
                builder.attribute('time', now);
                builder.attribute('to', recipientUid);
                builder.text(text);
              },
            );
            builder.element(
              'link',
              nest: () {
                builder.attribute('uid', senderUid);
                builder.attribute('type', 'a-f-G-U-C');
                builder.attribute('relation', 'p-p');
              },
            );
          },
        );
      },
    );
    return builder.buildDocument().toXmlString(pretty: false);
  }

  /// Builds a delivery receipt CoT event.
  static String buildReceiptCot({
    required String originalMessageUid,
    required String senderUid,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    final stale = DateTime.now()
        .toUtc()
        .add(const Duration(minutes: 1))
        .toIso8601String();
    final receiptUid =
        'receipt.$originalMessageUid.${DateTime.now().millisecondsSinceEpoch}';

    final builder = XmlBuilder();
    builder.element(
      'event',
      nest: () {
        builder.attribute('version', '2.0');
        builder.attribute('type', 'b-t-f-r');
        builder.attribute('uid', receiptUid);
        builder.attribute('how', 'h-g-i-g-o');
        builder.attribute('time', now);
        builder.attribute('start', now);
        builder.attribute('stale', stale);
        builder.element(
          'point',
          nest: () {
            builder.attribute('lat', '0.0');
            builder.attribute('lon', '0.0');
            builder.attribute('hae', '0.0');
            builder.attribute('ce', '9999999');
            builder.attribute('le', '9999999');
          },
        );
        builder.element(
          'detail',
          nest: () {
            builder.element(
              '__chat',
              nest: () {
                builder.attribute('senderCallsign', 'MESH-BRIDGE');
                builder.attribute('chatroom', senderUid);
                builder.attribute('id', receiptUid);
              },
            );
            builder.element(
              'remarks',
              nest: () {
                builder.attribute('source', 'MESH-BRIDGE');
                builder.attribute('time', now);
                builder.text('Delivered to mesh');
              },
            );
          },
        );
      },
    );
    return builder.buildDocument().toXmlString(pretty: false);
  }

  /// Handles a GeoChat CoT from a TAK client, forwarding to mesh.
  ///
  /// Returns the mesh message ID if sent, null if rate-limited or invalid.
  Future<int?> handleTakGeoChat({
    required TakClientSession session,
    required String cotXml,
  }) async {
    final message = parseGeoChatCot(cotXml);
    if (message == null) return null;

    final clientUid = session.uid.isNotEmpty
        ? session.uid
        : session.remoteAddress;

    // Rate limiting.
    if (!_checkRateLimit(clientUid)) {
      AppLogging.tak('GeoChat: TAK->mesh rate-limited $clientUid');
      return null;
    }

    // Sanitize message text.
    final sanitizedText = sanitizeExternalText(message.text);
    if (sanitizedText.isEmpty) return null;

    // Determine destination.
    int? destination;
    if (message.recipientUid != null &&
        message.recipientUid != 'All Chat Rooms' &&
        _callsignResolver != null) {
      // Try to resolve the recipient UID to a mesh node number.
      // Convention: MESHTASTIC-{hex} UIDs map directly.
      final uid = message.recipientUid!;
      if (uid.startsWith('MESHTASTIC-') && uid.length > 11) {
        destination = int.tryParse(uid.substring(11), radix: 16);
      } else {
        // Try callsign resolver.
        destination = _callsignResolver(uid);
      }
    }

    final callsign = session.callsign.isNotEmpty
        ? session.callsign
        : message.senderCallsign;

    AppLogging.tak(
      "GeoChat: TAK->mesh from $callsign: '${_truncate(sanitizedText, 40)}' (${sanitizedText.length} chars)",
    );

    // Send to mesh.
    final meshMsgId = await _meshSend(
      '[$callsign] $sanitizedText',
      channelIndex: 0,
      destination: destination,
    );

    // Track for delivery receipt.
    _pendingReceipts[meshMsgId] = GeoChatSendResult(
      messageId: message.messageId,
      originatingCallsign: clientUid,
    );
    _cleanExpiredReceipts();

    AppLogging.tak(
      'GeoChat: sent to mesh channel 0, messageId=$meshMsgId, awaiting ACK',
    );

    return meshMsgId;
  }

  /// Handles a mesh text message, converting to GeoChat CoT.
  ///
  /// Returns the CoT XML to be sent to TAK clients.
  String? handleMeshText({
    required int fromNodeNum,
    required String callsign,
    required String text,
  }) {
    if (text.isEmpty) return null;

    final nodeHex = fromNodeNum.toRadixString(16).toUpperCase().padLeft(8, '0');
    AppLogging.tak(
      "GeoChat: mesh->TAK from 0x$nodeHex ($callsign): '${_truncate(text, 40)}'",
    );

    return buildGeoChatCot(
      fromNodeNum: fromNodeNum,
      callsign: callsign,
      text: text,
    );
  }

  /// Handles a mesh ACK for a previously sent GeoChat.
  ///
  /// Returns receipt CoT XML and the originating client UID, or null.
  ({String cotXml, String clientUid})? handleMeshAck(int meshMessageId) {
    final result = _pendingReceipts.remove(meshMessageId);
    if (result == null) return null;

    AppLogging.tak(
      'GeoChat: mesh ACK received for messageId=$meshMessageId, sending receipt to ${result.originatingCallsign}',
    );

    final receiptCot = buildReceiptCot(
      originalMessageUid: result.messageId,
      senderUid: result.originatingCallsign,
    );

    return (cotXml: receiptCot, clientUid: result.originatingCallsign);
  }

  /// Number of pending delivery receipts.
  int get pendingReceiptCount => _pendingReceipts.length;

  // --- Rate Limiting ---

  bool _checkRateLimit(String clientUid) {
    final now = DateTime.now();
    final timestamps = _rateLimits.putIfAbsent(clientUid, () => []);

    // Clean old timestamps.
    timestamps.removeWhere((ts) => now.difference(ts) > rateLimitWindow);

    if (timestamps.length >= maxOutboundPerWindow) return false;

    timestamps.add(now);
    return true;
  }

  // --- Helpers ---

  void _cleanExpiredReceipts() {
    final cutoff = DateTime.now().subtract(receiptTtl);
    _pendingReceipts.removeWhere((_, r) => r.sentAt.isBefore(cutoff));
  }

  static String _truncate(String s, int maxLen) {
    if (s.length <= maxLen) return s;
    return '${s.substring(0, maxLen)}...';
  }
}
