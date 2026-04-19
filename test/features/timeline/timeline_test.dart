// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/timeline/domain/timeline_item.dart';
import 'package:socialmesh/features/timeline/providers/timeline_providers.dart';

void main() {
  group('TimelineItem', () {
    test('computes duration correctly', () {
      final item = TimelineItem(
        id: '1',
        start: DateTime(2025, 6, 18, 9, 0),
        end: DateTime(2025, 6, 18, 10, 30),
        title: 'Meeting',
      );
      expect(item.duration, const Duration(hours: 1, minutes: 30));
      expect(item.durationMinutes, 90);
    });

    test('computes startMinuteOfDay correctly', () {
      final item = TimelineItem(
        id: '1',
        start: DateTime(2025, 6, 18, 14, 45),
        end: DateTime(2025, 6, 18, 15, 45),
        title: 'Afternoon',
      );
      expect(item.startMinuteOfDay, 14 * 60 + 45);
    });

    test('equality is based on id', () {
      final a = TimelineItem(
        id: 'x',
        start: DateTime(2025, 1, 1),
        end: DateTime(2025, 1, 2),
        title: 'A',
      );
      final b = TimelineItem(
        id: 'x',
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 2),
        title: 'B',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('copyWith preserves fields', () {
      final original = TimelineItem(
        id: '1',
        start: DateTime(2025, 6, 18, 9, 0),
        end: DateTime(2025, 6, 18, 10, 0),
        title: 'Original',
        subtitle: 'Sub',
        priority: TimelinePriority.high,
        participantIds: ['a', 'b'],
        messageCount: 5,
        isCompleted: true,
        isBreak: false,
      );
      final copy = original.copyWith(title: 'Updated');
      expect(copy.title, 'Updated');
      expect(copy.subtitle, 'Sub');
      expect(copy.priority, TimelinePriority.high);
      expect(copy.participantIds, ['a', 'b']);
      expect(copy.messageCount, 5);
      expect(copy.isCompleted, true);
    });

    test('hasParticipants returns correctly', () {
      final withParticipants = TimelineItem(
        id: '1',
        start: DateTime(2025, 1, 1),
        end: DateTime(2025, 1, 2),
        title: 'T',
        participantIds: ['a'],
      );
      final without = TimelineItem(
        id: '2',
        start: DateTime(2025, 1, 1),
        end: DateTime(2025, 1, 2),
        title: 'T',
      );
      expect(withParticipants.hasParticipants, true);
      expect(without.hasParticipants, false);
    });
  });

  group('computeDayLayout', () {
    test('non-overlapping items get full width', () {
      final items = [
        TimelineItem(
          id: '1',
          start: DateTime(2025, 6, 18, 9, 0),
          end: DateTime(2025, 6, 18, 10, 0),
          title: 'A',
        ),
        TimelineItem(
          id: '2',
          start: DateTime(2025, 6, 18, 11, 0),
          end: DateTime(2025, 6, 18, 12, 0),
          title: 'B',
        ),
      ];
      final layouts = computeDayLayout(items, 1.0);
      expect(layouts, hasLength(2));
      for (final layout in layouts) {
        expect(layout.widthFraction, 1.0);
        expect(layout.leftFraction, 0.0);
      }
    });

    test('overlapping items split horizontally', () {
      final items = [
        TimelineItem(
          id: '1',
          start: DateTime(2025, 6, 18, 9, 0),
          end: DateTime(2025, 6, 18, 11, 0),
          title: 'A',
        ),
        TimelineItem(
          id: '2',
          start: DateTime(2025, 6, 18, 10, 0),
          end: DateTime(2025, 6, 18, 12, 0),
          title: 'B',
        ),
      ];
      final layouts = computeDayLayout(items, 1.0);
      expect(layouts, hasLength(2));
      expect(layouts[0].widthFraction, 0.5);
      expect(layouts[1].widthFraction, 0.5);
      expect(layouts[0].leftFraction, 0.0);
      expect(layouts[1].leftFraction, 0.5);
    });

    test('top position uses pixelsPerMinute', () {
      final items = [
        TimelineItem(
          id: '1',
          start: DateTime(2025, 6, 18, 2, 30), // 150 minutes
          end: DateTime(2025, 6, 18, 3, 30), // 60 minutes duration
          title: 'A',
        ),
      ];
      final layouts = computeDayLayout(items, 1.2);
      expect(layouts, hasLength(1));
      expect(layouts.first.top, closeTo(150 * 1.2, 0.01));
      expect(layouts.first.height, closeTo(60 * 1.2, 0.01));
    });

    test('empty list returns empty', () {
      expect(computeDayLayout([], 1.0), isEmpty);
    });

    test('three overlapping items get 1/3 width each', () {
      final items = [
        TimelineItem(
          id: '1',
          start: DateTime(2025, 6, 18, 9, 0),
          end: DateTime(2025, 6, 18, 12, 0),
          title: 'A',
        ),
        TimelineItem(
          id: '2',
          start: DateTime(2025, 6, 18, 9, 30),
          end: DateTime(2025, 6, 18, 11, 0),
          title: 'B',
        ),
        TimelineItem(
          id: '3',
          start: DateTime(2025, 6, 18, 10, 0),
          end: DateTime(2025, 6, 18, 11, 30),
          title: 'C',
        ),
      ];
      final layouts = computeDayLayout(items, 1.0);
      expect(layouts, hasLength(3));
      for (final layout in layouts) {
        expect(layout.widthFraction, closeTo(1.0 / 3, 0.01));
      }
    });
  });

  group('groupItemsByDay', () {
    test('groups items by their date', () {
      final items = [
        TimelineItem(
          id: '1',
          start: DateTime(2025, 6, 18, 9, 0),
          end: DateTime(2025, 6, 18, 10, 0),
          title: 'Mon A',
        ),
        TimelineItem(
          id: '2',
          start: DateTime(2025, 6, 18, 14, 0),
          end: DateTime(2025, 6, 18, 15, 0),
          title: 'Mon B',
        ),
        TimelineItem(
          id: '3',
          start: DateTime(2025, 6, 19, 9, 0),
          end: DateTime(2025, 6, 19, 10, 0),
          title: 'Tue',
        ),
      ];
      final grouped = groupItemsByDay(items);
      expect(grouped, hasLength(2));
      expect(grouped[DateTime(2025, 6, 18)], hasLength(2));
      expect(grouped[DateTime(2025, 6, 19)], hasLength(1));
    });

    test('empty list returns empty map', () {
      expect(groupItemsByDay([]), isEmpty);
    });
  });

  group('weekStartFor', () {
    test('returns Monday for a Wednesday', () {
      // June 18, 2025 is a Wednesday
      final wed = DateTime(2025, 6, 18);
      final monday = weekStartFor(wed);
      expect(monday, DateTime(2025, 6, 16));
      expect(monday.weekday, DateTime.monday);
    });

    test('returns same day for Monday', () {
      final mon = DateTime(2025, 6, 16);
      expect(weekStartFor(mon), DateTime(2025, 6, 16));
    });

    test('returns previous Monday for Sunday', () {
      // June 22, 2025 is a Sunday
      final sun = DateTime(2025, 6, 22);
      final monday = weekStartFor(sun);
      expect(monday, DateTime(2025, 6, 16));
    });
  });
}
