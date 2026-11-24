// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';
import 'dart:typed_data';

// SMAZ short-text compression as MeshCore clients send it: the text is
// replaced by `s:` and the base64 of a SMAZ stream when that is shorter.
// Codes 0..253 index the standard SMAZ codebook; 254 is one verbatim byte
// and 255 a verbatim run of (next byte + 1) bytes.

const int _verbatimSingle = 254;
const int _verbatimRun = 255;

const List<String> _codebook = [
  " ",
  "the",
  "e",
  "t",
  "a",
  "of",
  "o",
  "and",
  "i",
  "n",
  "s",
  "e ",
  "r",
  " th",
  " t",
  "in",
  "he",
  "th",
  "h",
  "he ",
  "to",
  "\r\n",
  "l",
  "s ",
  "d",
  " a",
  "an",
  "er",
  "c",
  " o",
  "d ",
  "on",
  " of",
  "re",
  "of ",
  "t ",
  ", ",
  "is",
  "u",
  "at",
  "   ",
  "n ",
  "or",
  "which",
  "f",
  "m",
  "as",
  "it",
  "that",
  "\n",
  "was",
  "en",
  "  ",
  " w",
  "es",
  " an",
  " i",
  "\r",
  "f ",
  "g",
  "p",
  "nd",
  " s",
  "nd ",
  "ed ",
  "w",
  "ed",
  "http://",
  "for",
  "te",
  "ing",
  "y ",
  "The",
  " c",
  "ti",
  "r ",
  "his",
  "st",
  " in",
  "ar",
  "nt",
  ",",
  " to",
  "y",
  "ng",
  " h",
  "with",
  "le",
  "al",
  "to ",
  "b",
  "ou",
  "be",
  "were",
  " b",
  "se",
  "o ",
  "ent",
  "ha",
  "ng ",
  "their",
  "\"",
  "hi",
  "from",
  " f",
  "in ",
  "de",
  "ion",
  "me",
  "v",
  ".",
  "ve",
  "all",
  "re ",
  "ri",
  "ro",
  "is ",
  "co",
  "f t",
  "are",
  "ea",
  ". ",
  "her",
  " m",
  "er ",
  " p",
  "es ",
  "by",
  "they",
  "di",
  "ra",
  "ic",
  "not",
  "s, ",
  "d t",
  "at ",
  "ce",
  "la",
  "h ",
  "ne",
  "as ",
  "tio",
  "on ",
  "n t",
  "io",
  "we",
  " a ",
  "om",
  ", a",
  "s o",
  "ur",
  "li",
  "ll",
  "ch",
  "had",
  "this",
  "e t",
  "g ",
  "e\r\n",
  " wh",
  "ere",
  " co",
  "e o",
  "a ",
  "us",
  " d",
  "ss",
  "\n\r\n",
  "\r\n\r",
  "=\"",
  " be",
  " e",
  "s a",
  "ma",
  "one",
  "t t",
  "or ",
  "but",
  "el",
  "so",
  "l ",
  "e s",
  "s,",
  "no",
  "ter",
  " wa",
  "iv",
  "ho",
  "e a",
  " r",
  "hat",
  "s t",
  "ns",
  "ch ",
  "wh",
  "tr",
  "ut",
  "/",
  "have",
  "ly ",
  "ta",
  " ha",
  " on",
  "tha",
  "-",
  " l",
  "ati",
  "en ",
  "pe",
  " re",
  "there",
  "ass",
  "si",
  " fo",
  "wa",
  "ec",
  "our",
  "who",
  "its",
  "z",
  "fo",
  "rs",
  ">",
  "ot",
  "un",
  "<",
  "im",
  "th ",
  "nc",
  "ate",
  "><",
  "ver",
  "ad",
  " we",
  "ly",
  "ee",
  " n",
  "id",
  " cl",
  "ac",
  "il",
  "</",
  "rt",
  " wi",
  "div",
  "e, ",
  " it",
  "whi",
  " ma",
  "ge",
  "x",
  "e c",
  "men",
  ".com",
];

final List<Uint8List> _codebookBytes = [
  for (final e in _codebook) Uint8List.fromList(ascii.encode(e)),
];

final int _longestEntry = _codebookBytes.fold(
  0,
  (m, e) => e.length > m ? e.length : m,
);

/// Decodes a SMAZ-compressed `s:` text, or returns null when [text] is not
/// one. Plain text can start with `s:` too, so a payload only counts as
/// compressed when it decodes to valid UTF-8, re-compresses to the same
/// bytes and is shorter than the text it carries, the sender's rules for
/// choosing it.
String? meshCoreSmazDecodeText(String text) {
  final trimmed = text.trimLeft();
  if (!trimmed.startsWith('s:') || trimmed.length <= 2) return null;
  try {
    final compressed = _base64Flexible(trimmed.substring(2));
    if (compressed.isEmpty) return null;
    final plain = meshCoreSmazDecompress(compressed);
    final decoded = utf8.decode(plain);
    final again = meshCoreSmazCompress(plain);
    if (!_sameBytes(again, compressed)) return null;
    if (2 + base64Encode(compressed).length >= plain.length) return null;
    return decoded;
  } on FormatException {
    return null;
  }
}

/// SMAZ-compresses [input], greedily taking the longest codebook match.
Uint8List meshCoreSmazCompress(Uint8List input) {
  final out = BytesBuilder(copy: false);
  final verbatim = <int>[];

  void flush() {
    if (verbatim.isEmpty) return;
    if (verbatim.length == 1) {
      out
        ..addByte(_verbatimSingle)
        ..addByte(verbatim.first);
    } else {
      out
        ..addByte(_verbatimRun)
        ..addByte(verbatim.length - 1)
        ..add(verbatim);
    }
    verbatim.clear();
  }

  var i = 0;
  while (i < input.length) {
    var bestLen = 0;
    var bestCode = -1;
    final remaining = input.length - i;
    final maxLen = remaining < _longestEntry ? remaining : _longestEntry;
    for (var code = 0; code < _codebookBytes.length; code++) {
      final entry = _codebookBytes[code];
      if (entry.length > maxLen || entry.length <= bestLen) continue;
      if (_matchesAt(input, i, entry)) {
        bestLen = entry.length;
        bestCode = code;
        if (bestLen == maxLen) break;
      }
    }
    if (bestCode >= 0) {
      flush();
      out.addByte(bestCode);
      i += bestLen;
      continue;
    }
    verbatim.add(input[i++]);
    if (verbatim.length == 256) flush();
  }
  flush();
  return out.toBytes();
}

/// Expands a SMAZ stream; throws [FormatException] on a malformed one.
Uint8List meshCoreSmazDecompress(Uint8List input) {
  final out = BytesBuilder(copy: false);
  var i = 0;
  while (i < input.length) {
    final code = input[i];
    if (code == _verbatimSingle) {
      if (i + 1 >= input.length) {
        throw const FormatException('SMAZ: truncated verbatim byte');
      }
      out.addByte(input[i + 1]);
      i += 2;
    } else if (code == _verbatimRun) {
      if (i + 1 >= input.length) {
        throw const FormatException('SMAZ: truncated verbatim length');
      }
      final end = i + 2 + input[i + 1] + 1;
      if (end > input.length) {
        throw const FormatException('SMAZ: truncated verbatim run');
      }
      out.add(input.sublist(i + 2, end));
      i = end;
    } else {
      if (code >= _codebookBytes.length) {
        throw const FormatException('SMAZ: code out of range');
      }
      out.add(_codebookBytes[code]);
      i++;
    }
  }
  return out.toBytes();
}

bool _matchesAt(Uint8List input, int offset, Uint8List entry) {
  if (offset + entry.length > input.length) return false;
  for (var j = 0; j < entry.length; j++) {
    if (input[offset + j] != entry[j]) return false;
  }
  return true;
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var j = 0; j < a.length; j++) {
    if (a[j] != b[j]) return false;
  }
  return true;
}

// Standard base64, or base64url without padding.
Uint8List _base64Flexible(String encoded) {
  final s = encoded.trim();
  try {
    return base64Decode(s);
  } on FormatException {
    var n = s.replaceAll('-', '+').replaceAll('_', '/');
    final pad = n.length % 4;
    if (pad != 0) n = n.padRight(n.length + 4 - pad, '=');
    return base64Decode(n);
  }
}
