// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../models/mesh_models.dart';
import '../../core/logging.dart';
import '../../utils/text_sanitizer.dart';

/// Parse push payload into Message if possible. Accepts common key names.
Message? parsePushMessagePayload(Map<String, dynamic> data) {
  try {
    final String? messageId = data['messageId'] as String?;
    final int? from = data['fromNode'] != null
        ? int.tryParse('${data['fromNode']}')
        : (data['from'] != null ? int.tryParse('${data['from']}') : null);
    final int? to = data['toNode'] != null
        ? int.tryParse('${data['toNode']}')
        : (data['to'] != null ? int.tryParse('${data['to']}') : null);
    final int? channel = data['channel'] != null
        ? int.tryParse('${data['channel']}')
        : null;
    final String text = sanitizeUtf16(
      (data['text'] ?? data['message'] ?? '') as String,
    );
    if (text.isEmpty) return null;

    // Parse timestamp if available
    DateTime timestamp;
    if (data['timestamp'] != null) {
      final t = data['timestamp'];
      if (t is int) {
        timestamp = DateTime.fromMillisecondsSinceEpoch(t);
      } else if (t is String) {
        final parsed = int.tryParse(t);
        if (parsed != null) {
          timestamp = DateTime.fromMillisecondsSinceEpoch(parsed);
        } else {
          timestamp = DateTime.tryParse(t) ?? DateTime.now();
        }
      } else {
        timestamp = DateTime.now();
      }
    } else {
      timestamp = DateTime.now();
    }

    // Build deterministic id if none provided
    String id =
        messageId ??
        _generateDeterministicMessageId(from, to, channel, timestamp, text);

    final int fromVal = from ?? 0;
    final int toVal = to ?? 0;

    final message = Message(
      id: id,
      from: fromVal,
      to: toVal,
      text: text,
      timestamp: timestamp,
      channel: channel,
      received: true,
      source: MessageSource.unknown,
    );

    return message;
  } catch (e) {
    AppLogging.notifications('🔔 Error parsing push payload into Message: $e');
    return null;
  }
}

String _generateDeterministicMessageId(
  int? from,
  int? to,
  int? channel,
  DateTime timestamp,
  String text,
) {
  final input =
      '${from ?? ''}|${to ?? ''}|${channel ?? ''}|${timestamp.toUtc().millisecondsSinceEpoch}|$text';
  final bytes = utf8.encode(input);
  final digest = sha1.convert(bytes);
  return digest.toString();
}
