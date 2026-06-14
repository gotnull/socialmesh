// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Human-readable byte-size formatting.

/// Format a byte count as a compact human-readable string (e.g. `120.4 MB`).
///
/// Uses binary (1024) steps. [fractionDigits] controls precision for KB and
/// larger units; bytes are always shown whole.
String formatByteSize(int bytes, {int fractionDigits = 1}) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024.0;
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024.0;
    unitIndex++;
  }
  return '${value.toStringAsFixed(fractionDigits)} ${units[unitIndex]}';
}
