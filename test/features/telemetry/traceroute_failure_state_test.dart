// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level pin tests for the Tranche 1 traceroute card failure state.
///
/// Failed traceroutes used to render "Forward 0 / Back 0" chips because
/// `_HopCountChip` was emitted unconditionally. That made a no-response
/// card read like a successful direct connection. The fix gates the chip
/// row on `log.response` and renders an explicit failure status row when
/// the target did not reply.
void main() {
  group('TraceRouteCard failure state', () {
    final cardFile = File('lib/features/telemetry/traceroute_log_screen.dart');

    late String source;

    setUpAll(() {
      expect(cardFile.existsSync(), true, reason: 'card source must exist');
      source = cardFile.readAsStringSync();
    });

    test('hop chips render only when the target responded', () {
      expect(
        source.contains('if (log.response)'),
        true,
        reason:
            'The hop chip row must be wrapped in `if (log.response)` so '
            'failed traceroutes do not surface a "0 hops" pill.',
      );
    });

    test('failure path renders explicit no-response copy in error red', () {
      expect(
        source.contains('telemetryTracerouteNoResponse'),
        true,
        reason:
            'Failure status row must reference the dedicated ARB key, not a '
            'generic fallback or empty placeholder.',
      );
      expect(
        source.contains('Icons.error_outline'),
        true,
        reason:
            'Failure status row must use Icons.error_outline so the visual '
            'state of a failed traceroute is unambiguous.',
      );
      expect(
        source.contains('AppTheme.errorRed'),
        true,
        reason:
            'Failure copy must use AppTheme.errorRed so it does not blend '
            'into the success-styled chip layout.',
      );
    });

    test('direct-connection hint remains gated on a real response', () {
      expect(
        source.contains(
          'if (log.response &&\n'
          '              forwardHops.isEmpty &&\n'
          '              returnHops.isEmpty &&\n'
          '              log.hopsTowards == 0 &&\n'
          '              log.hopsBack == 0)',
        ),
        true,
        reason:
            'The direct-connection hint must continue to require '
            'log.response == true, so failed traceroutes never claim a '
            'direct link.',
      );
    });
  });
}
