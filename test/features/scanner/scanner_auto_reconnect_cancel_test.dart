// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Cancel on the Scanner's auto-reconnect overlay must stop whichever
// reconnect put the overlay there. The overlay is usually shown for the
// background reconnect that was already running when the Scanner opened;
// clearing local flags and starting a manual scan while that attempt keeps
// scanning and retrying left the screen with no Bluetooth list and no way
// to scan. The Scanner's own attempt is stopped through a run counter so a
// cancelled attempt's scan loop does not start a second manual scan.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;
  setUpAll(() async {
    source = await File('lib/features/scanner/scanner_screen.dart')
        .readAsString();
  });

  group('Scanner auto-reconnect cancel', () {
    test('the overlay Cancel routes through the dedicated handler', () {
      final collapsed = source.replaceAll(RegExp(r'\s+'), ' ');
      expect(
        collapsed.contains('onCancel: () => unawaited(_cancelAutoReconnect())'),
        isTrue,
      );
    });

    test('the handler runs the authoritative cancel before scanning', () {
      final start = source.indexOf('Future<void> _cancelAutoReconnect()');
      expect(start, greaterThan(0));
      final body = source.substring(start, source.indexOf('\n  }\n', start));
      final cancelAt = body.indexOf('await notifier.userCancelAutoReconnect()');
      final scanAt = body.indexOf('await _startScan()');
      expect(cancelAt, greaterThan(0));
      expect(
        scanAt,
        greaterThan(cancelAt),
        reason:
            'the manual scan must wait for the background scan to stop, '
            'or the two contend for the adapter',
      );
      expect(body.contains('_backgroundReconnectSub?.close()'), isTrue);
      expect(body.contains('_autoReconnectRun++'), isTrue);
    });

    test("the Scanner's own attempt stops when its run is superseded", () {
      final start = source.indexOf('Future<void> _tryAutoReconnect()');
      final end = source.indexOf('Future<void> _cancelAutoReconnect()');
      final body = source.substring(start, end);
      expect(body.contains('final run = ++_autoReconnectRun;'), isTrue);
      expect(
        body.contains('if (!mounted || run != _autoReconnectRun) break;'),
        isTrue,
      );
      expect(
        body.contains('if (!mounted || run != _autoReconnectRun) return;'),
        isTrue,
      );
      expect(body.contains('if (run != _autoReconnectRun) return;'), isTrue);
    });
  });
}
