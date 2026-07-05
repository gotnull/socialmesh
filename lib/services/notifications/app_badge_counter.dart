// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// In-memory model of the app-icon unread badge. NotificationService keeps
// one instance and mirrors every mutation to the native badge, so this
// class stays pure (no plugin/channel dependency) and unit-testable.
//
// Lifecycle of the value:
//   - resume / launch: reset() alongside the native clearBadge
//   - app backgrounding: set() to the authoritative provider unread total
//   - message notification while backgrounded: bump() per unread message
//     (provider totals are stale while backgrounded, hence the counter)

/// Tracks the number shown on the app icon badge.
class AppBadgeCounter {
  int _value = 0;

  /// The current badge value; never negative.
  int get value => _value;

  /// Sets the badge to [count], clamping negatives to zero, and returns the
  /// stored value.
  int set(int count) => _value = count < 0 ? 0 : count;

  /// Increments the badge by [by] (default 1) and returns the new value.
  int bump([int by = 1]) => set(_value + by);

  /// Resets the badge to zero.
  void reset() => _value = 0;
}
