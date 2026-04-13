// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/widgets.dart';

import 'timeline_item.dart';

/// Delegate for handling timeline board interactions.
///
/// Consumers implement this to respond to user gestures on timeline items.
/// The delegate pattern keeps interaction logic out of the widget tree.
abstract class TimelineInteractionDelegate {
  /// Called when the user taps a timeline item.
  void onItemTap(BuildContext context, TimelineItem item);

  /// Called when the user long-presses a timeline item.
  void onItemLongPress(BuildContext context, TimelineItem item) {}
}
