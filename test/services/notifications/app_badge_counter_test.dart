// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Issue #196 - app icon unread badge. AppBadgeCounter is the in-memory
// badge model NotificationService mirrors to the native icon badge:
// set() at app backgrounding (authoritative provider total), bump() per
// unread message while backgrounded, reset() on resume/launch clear.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/notifications/app_badge_counter.dart';

void main() {
  group('AppBadgeCounter', () {
    test('starts at zero', () {
      expect(AppBadgeCounter().value, 0);
    });

    test('set stores and returns the count', () {
      final counter = AppBadgeCounter();
      expect(counter.set(7), 7);
      expect(counter.value, 7);
    });

    test('set clamps negatives to zero', () {
      final counter = AppBadgeCounter();
      counter.set(3);
      expect(counter.set(-2), 0);
      expect(counter.value, 0);
    });

    test('bump increments by one by default', () {
      final counter = AppBadgeCounter();
      expect(counter.bump(), 1);
      expect(counter.bump(), 2);
      expect(counter.value, 2);
    });

    test('bump by N adds the batch size', () {
      final counter = AppBadgeCounter();
      counter.set(2);
      expect(counter.bump(5), 7);
      expect(counter.value, 7);
    });

    test('reset returns to zero', () {
      final counter = AppBadgeCounter();
      counter.set(9);
      counter.reset();
      expect(counter.value, 0);
    });
  });
}
