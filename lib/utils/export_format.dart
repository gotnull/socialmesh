// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Format a value for inclusion in a CSV row. Strings/dynamic values get
/// double-quote escaping per RFC 4180; numbers and bools pass through.
String csvField(Object? value) {
  if (value == null) return '';
  if (value is num || value is bool) return value.toString();
  final s = value.toString();
  if (s.contains('"') ||
      s.contains(',') ||
      s.contains('\n') ||
      s.contains('\r')) {
    return '"${s.replaceAll('"', '""')}"'; // lint-allow: hardcoded-string - CSV quoting
  }
  return s;
}

/// File name for an exported file: `socialmesh-<stem>-<UTC stamp>.<ext>`,
/// stamped with [at] or, when omitted, the current time.
String exportFileName(String stem, String ext, {DateTime? at}) {
  final time = (at ?? DateTime.now()).toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  final stamp =
      '${time.year}${two(time.month)}${two(time.day)}'
      '${two(time.hour)}${two(time.minute)}';
  return 'socialmesh-$stem-$stamp.$ext'; // lint-allow: hardcoded-string - file name
}
