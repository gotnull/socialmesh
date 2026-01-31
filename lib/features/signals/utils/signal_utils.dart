// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

/// Utility functions for signal-related UI components.
///
/// These functions provide consistent styling and formatting across
/// all signal-related screens and widgets.

// =============================================================================
// Age-Based Colors
// =============================================================================

/// Get age-based color for a signal based on creation time.
///
/// Returns:
/// - Green: < 5 minutes old
/// - Amber: < 30 minutes old
/// - Orange: < 2 hours old
/// - Red: > 2 hours old
Color getSignalAgeColor(DateTime createdAt) {
  final age = DateTime.now().difference(createdAt);
  if (age.inMinutes < 5) {
    return Colors.green;
  } else if (age.inMinutes < 30) {
    return Colors.amber;
  } else if (age.inHours < 2) {
    return Colors.orange;
  } else {
    return Colors.red.shade300;
  }
}

/// Get color for hop count indicator.
///
/// Returns:
/// - Green: 0 hops (local)
/// - Amber: 1-2 hops (nearby)
/// - Orange: 3+ hops (distant)
Color getHopCountColor(int? hopCount) {
  if (hopCount == null) return Colors.grey;
  if (hopCount == 0) return Colors.green;
  if (hopCount <= 2) return Colors.amber;
  return Colors.orange;
}

// =============================================================================
// Time Formatting
// =============================================================================

/// Format relative time (e.g., "5m ago", "2h ago").
///
/// [compact] - If true, omits "ago" suffix (e.g., "5m" instead of "5m ago")
String formatTimeAgo(DateTime time, {bool compact = false}) {
  final diff = DateTime.now().difference(time);
  final suffix = compact ? '' : ' ago';

  if (diff.inMinutes < 1) {
    return compact ? 'now' : 'Just now';
  } else if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m$suffix';
  } else if (diff.inHours < 24) {
    return '${diff.inHours}h$suffix';
  } else if (diff.inDays < 7) {
    return '${diff.inDays}d$suffix';
  } else {
    return '${(diff.inDays / 7).floor()}w$suffix';
  }
}

/// Format time as "Active Xm" style for signal cards.
String formatActiveTime(DateTime time) {
  final diff = DateTime.now().difference(time);

  if (diff.inMinutes < 1) return 'Active now';
  if (diff.inMinutes < 60) return 'Active ${diff.inMinutes}m';
  if (diff.inHours < 24) return 'Active ${diff.inHours}h';
  return 'Active ${diff.inDays}d';
}

// =============================================================================
// TTL (Time-To-Live) Formatting
// =============================================================================

/// Format TTL remaining (e.g., "5m left" or "5m" for compact).
///
/// [compact] - If true, omits "left" suffix
String formatTtlRemaining(DateTime? expiresAt, {bool compact = false}) {
  if (expiresAt == null) return '';
  final remaining = expiresAt.difference(DateTime.now());
  if (remaining.isNegative) return 'Expired';

  final suffix = compact ? '' : ' left';
  if (remaining.inSeconds < 60) return '${remaining.inSeconds}s$suffix';
  if (remaining.inMinutes < 60) return '${remaining.inMinutes}m$suffix';
  if (remaining.inHours < 24) return '${remaining.inHours}h$suffix';
  return '${remaining.inDays}d$suffix';
}

/// Get TTL color based on urgency.
///
/// Returns:
/// - Red: expired or < 30 minutes remaining
/// - Orange: < 2 hours remaining
/// - Grey: more time remaining or no TTL
Color getTtlColor(DateTime? expiresAt) {
  if (expiresAt == null) return Colors.white38;
  final remaining = expiresAt.difference(DateTime.now());
  if (remaining.isNegative) return Colors.red.shade300;
  if (remaining.inMinutes < 30) return Colors.red.shade300;
  if (remaining.inHours < 2) return Colors.orange;
  return Colors.white38;
}

/// Check if a signal has expired.
bool isSignalExpired(DateTime? expiresAt) {
  if (expiresAt == null) return false;
  return DateTime.now().isAfter(expiresAt);
}

/// Format a TTL countdown string for signal cards.
/// Uses seconds when remaining < 60s, minutes + seconds when < 10m,
/// and returns "Faded" at or below 0.
String formatSignalTtlCountdown(Duration? remaining) {
  if (remaining == null) return '';
  if (remaining.inSeconds <= 0) return 'Faded';
  if (remaining.inSeconds < 60) return 'Fades in ${remaining.inSeconds}s';
  if (remaining.inMinutes < 10) {
    final mins = remaining.inMinutes;
    final secs = remaining.inSeconds % 60;
    return 'Fades in ${mins}m ${secs}s';
  }
  if (remaining.inMinutes < 60) return 'Fades in ${remaining.inMinutes}m';
  if (remaining.inHours < 24) return 'Fades in ${remaining.inHours}h';
  return 'Fades in ${remaining.inDays}d';
}
