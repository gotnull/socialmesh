// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert' show utf8;

import 'package:flutter/services.dart';

/// Truncates input to a maximum UTF-8 *byte* length (not character count).
///
/// Meshtastic firmware allocates fixed-size byte buffers for the MQTT
/// config fields (Address 62 B, Username 62 B, Password 30 B, Root
/// 30 B), so a `maxLength` based on Dart's UTF-16 `length` property
/// silently overflows the wire when users type CJK or emoji input.
/// This formatter caps by encoded UTF-8 byte count instead, matching
/// the firmware's actual buffer.
///
/// On every change, if the new text exceeds [maxBytes] when encoded as
/// UTF-8, characters are dropped from the end until it fits. Cursor
/// position is clamped to the new length.
class Utf8ByteLengthFormatter extends TextInputFormatter {
  const Utf8ByteLengthFormatter(this.maxBytes) : assert(maxBytes > 0);

  final int maxBytes;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    if (utf8.encode(text).length <= maxBytes) return newValue;

    while (text.isNotEmpty && utf8.encode(text).length > maxBytes) {
      // Drop one code point. A surrogate pair goes as a whole: leaving
      // its high half behind makes invalid text that breaks rendering.
      final last = text.codeUnitAt(text.length - 1);
      final isLowSurrogate = last >= 0xDC00 && last <= 0xDFFF;
      final drop = isLowSurrogate && text.length >= 2 ? 2 : 1;
      text = text.substring(0, text.length - drop);
    }

    final selection = TextSelection.collapsed(offset: text.length);
    return TextEditingValue(
      text: text,
      selection: selection,
      composing: TextRange.empty,
    );
  }
}
