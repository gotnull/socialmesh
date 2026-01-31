// SPDX-License-Identifier: GPL-3.0-or-later
bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xD800 && codeUnit <= 0xDBFF;
bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;

/// Replace unpaired UTF-16 surrogates with U+FFFD to prevent text layout crashes.
String sanitizeUtf16(String input) {
  if (input.isEmpty) return input;

  final codeUnits = input.codeUnits;
  var hadInvalid = false;
  final buffer = StringBuffer();

  for (var i = 0; i < codeUnits.length; i++) {
    final unit = codeUnits[i];
    if (_isHighSurrogate(unit)) {
      if (i + 1 < codeUnits.length && _isLowSurrogate(codeUnits[i + 1])) {
        buffer.writeCharCode(unit);
        buffer.writeCharCode(codeUnits[i + 1]);
        i++;
      } else {
        hadInvalid = true;
        buffer.write('\uFFFD');
      }
      continue;
    }
    if (_isLowSurrogate(unit)) {
      hadInvalid = true;
      buffer.write('\uFFFD');
      continue;
    }
    buffer.writeCharCode(unit);
  }

  return hadInvalid ? buffer.toString() : input;
}
