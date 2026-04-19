// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Format device uptime seconds into a compact human-readable string.
///
/// Examples: `45s`, `12m`, `3h 15m`, `2d 6h`.
String formatUptime(int seconds) {
  if (seconds < 60) return '${seconds}s';
  if (seconds < 3600) return '${seconds ~/ 60}m';
  if (seconds < 86400) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '${h}h ${m}m';
  }
  final d = seconds ~/ 86400;
  final h = (seconds % 86400) ~/ 3600;
  return '${d}d ${h}h';
}
