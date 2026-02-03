import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:socialmesh/generated/meshtastic/channel.pb.dart';

void main() {
  final b64 = 'CAASHwoQbALD4MuGHQH7bM86dfbneBILVGVzdENoYW5uZWwYAQ';

  // Add padding
  String normalized = b64;
  final remainder = normalized.length % 4;
  if (remainder != 0) {
    normalized = normalized.padRight(normalized.length + (4 - remainder), '=');
  }

  final bytes = base64Decode(normalized);
  debugPrint('Total bytes: ${bytes.length}');
  debugPrint(
    'Hex: ${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
  );

  // Manual analysis
  debugPrint('\n--- Manual byte analysis ---');
  var i = 0;
  while (i < bytes.length) {
    final tag = bytes[i];
    final fieldNum = tag >> 3;
    final wireType = tag & 0x7;
    debugPrint('Offset $i: tag=$tag (field $fieldNum, wire type $wireType)');
    i++;

    if (wireType == 0) {
      // Varint
      var val = 0;
      var shift = 0;
      while (true) {
        final b = bytes[i++];
        val |= (b & 0x7f) << shift;
        if ((b & 0x80) == 0) break;
        shift += 7;
      }
      debugPrint('  Varint value: $val');
    } else if (wireType == 2) {
      // Length-delimited
      final len = bytes[i++];
      final data = bytes.sublist(i, i + len);
      i += len;
      debugPrint('  Length: $len');
      debugPrint(
        '  Data hex: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
      );
      // Try to interpret as string
      try {
        final str = utf8.decode(data);
        if (str.codeUnits.every((c) => c >= 32 && c < 127)) {
          debugPrint('  As string: "$str"');
        }
      } catch (_) {}
    }
  }

  // Try skipping first 2 bytes and parsing rest as ChannelSettings
  debugPrint('\n--- Try parsing bytes[2:] as ChannelSettings ---');
  try {
    // Skip "08 00" (index field)
    final settingsBytes = bytes.sublist(2);
    debugPrint(
      'Settings bytes (${settingsBytes.length}): ${settingsBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
    );

    // This should be: 12 1f <31 bytes of settings>
    // So the actual settings data starts at byte 2 of this
    if (settingsBytes[0] == 0x12) {
      final settingsLen = settingsBytes[1];
      final actualSettings = settingsBytes.sublist(2, 2 + settingsLen);
      debugPrint(
        'Actual settings (${actualSettings.length}): ${actualSettings.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
      );

      final settings = ChannelSettings.fromBuffer(actualSettings);
      debugPrint('Name: "${settings.name}"');
      debugPrint('PSK length: ${settings.psk.length}');
      debugPrint(
        'PSK hex: ${settings.psk.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
      );
    }
  } catch (e) {
    debugPrint('Failed: $e');
  }
}
