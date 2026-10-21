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

    test("the Scanner's own attempt hands off to the onboarding flow", () {
      // The flow owns leaving the Scanner after a successful connect.
      // Without the hand-off the session comes up behind the
      // Auto-reconnecting overlay and the Scanner never leaves.
      final start = source.indexOf('Future<void> _tryAutoReconnect()');
      final end = source.indexOf('Future<void> _cancelAutoReconnect()');
      final body = source.substring(start, end).replaceAll(RegExp(r'\s+'), ' ');
      final handoffAt = body.indexOf(
        'ref.read(meshtasticOnboardingFlowProvider.notifier).connect(lastDevice);',
      );
      final connectAt = body.indexOf(
        'await _connectToDevice(lastDevice, isAutoReconnect: true);',
      );
      expect(handoffAt, greaterThan(0));
      expect(connectAt, greaterThan(handoffAt));
    });
  });

  group('Scanner deferring to a background reconnect', () {
    String section(String from, String to) {
      final start = source.indexOf(from);
      expect(start, greaterThan(0), reason: 'missing: $from');
      final end = source.indexOf(to, start);
      expect(end, greaterThan(start), reason: 'missing: $to');
      return source.substring(start, end).replaceAll(RegExp(r'\s+'), ' ');
    }

    test('idle with the link up counts as the reconnect succeeding', () {
      // The auto-reconnect manager resets to idle when the link comes
      // up. Read as "gave up", the Scanner started a manual scan and
      // never left once the session finished.
      final body = section(
        'void _listenForBackgroundReconnectOutcome()',
        '// Leaves the Scanner for a connection',
      );
      final linkUpAt = body.indexOf(
        'next == AutoReconnectState.idle && '
        'ref.read(transportProvider).isConnected',
      );
      final leaveAt = body.indexOf(
        'if (next == AutoReconnectState.success || linkUp)',
      );
      final scanAt = body.indexOf('_startScan()');
      expect(linkUpAt, greaterThan(0));
      expect(leaveAt, greaterThan(linkUpAt));
      expect(scanAt, greaterThan(leaveAt));
      expect(body.contains('_leaveForLiveConnection();'), isTrue);
    });

    test('an idle retry wait is stopped so the manual scan can start', () {
      final body = section(
        'void _stopIdleBackgroundRetry()',
        '/// Navigate to main app after successful connection.',
      );
      expect(
        body.contains(
          'if (!mounted || _backgroundReconnectSub == null) return;',
        ),
        isTrue,
        reason: 'an outcome already handled must not be cancelled again',
      );
      final pendingAt = body.indexOf(
        'if (!notifier.backgroundRetryPending) return;',
      );
      final cancelAt = body.indexOf('notifier.cancelAutoReconnect();');
      expect(pendingAt, greaterThan(0));
      expect(
        cancelAt,
        greaterThan(pendingAt),
        reason: 'an attempt still scanning or connecting is left alone',
      );
    });

    test('the deferral checks for a retry wait now and when the attempt '
        'ends', () {
      final body = section(
        "gate=defer_to_background_reconnect TRIPPED",
        'if (autoReconnectState == AutoReconnectState.failed)',
      );
      final listenAt = body.indexOf('_listenForBackgroundReconnectOutcome();');
      final nowAt = body.indexOf(
        'if (inFlight == null) { _stopIdleBackgroundRetry(); }',
      );
      final laterAt = body.indexOf(
        'inFlight.whenComplete(_stopIdleBackgroundRetry).ignore();',
      );
      expect(listenAt, greaterThan(0));
      expect(
        nowAt,
        greaterThan(listenAt),
        reason: 'the listener must exist before a cancel fires failed',
      );
      expect(laterAt, greaterThan(nowAt));
    });
  });
}
