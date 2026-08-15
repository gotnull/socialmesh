// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Human-readable byte sizes for storage-scale values.
//
// Distinct from the `_formatBytes` helpers inside `lib/features/file_transfer/`,
// which deliberately stop at KB because they describe LoRa chunk sizes and a
// value there is never large enough to warrant MB. This one covers the range a
// database file lands in.

const List<String> _units = ['B', 'KB', 'MB', 'GB', 'TB'];

/// Formats [bytes] as a short size string: `812 B`, `9.4 KB`, `1.4 MB`.
///
/// Bytes render whole; every larger unit keeps one decimal place, which is
/// enough to tell two radios' datasets apart without implying more precision
/// than an on-disk size has (SQLite files are page-aligned and grow in steps).
String formatByteSize(int bytes) {
  if (bytes < 0) return formatByteSize(0);
  if (bytes < 1024) return '$bytes ${_units.first}';

  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < _units.length - 1) {
    value /= 1024;
    unit++;
  }
  // Round before the boundary check so 1023.97 KB reads as 1.0 MB rather
  // than 1024.0 KB.
  final rounded = (value * 10).roundToDouble() / 10;
  if (rounded >= 1024 && unit < _units.length - 1) {
    return '${(rounded / 1024).toStringAsFixed(1)} ${_units[unit + 1]}';
  }
  return '${rounded.toStringAsFixed(1)} ${_units[unit]}';
}

/// Formats a node number as the canonical `!a6960864` Meshtastic node id.
String formatNodeId(int nodeNum) =>
    '!${(nodeNum & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0')}';
