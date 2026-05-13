// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level pins for Sprint 2 NodeActions consolidation.
///
/// Tranche 1 left favorite/mute/traceroute logic duplicated between
/// `node_quick_actions_sheet.dart` and `node_detail_screen.dart`.
/// Sprint 2 extracts a single helper at `lib/features/nodes/node_actions.dart`
/// and points both call sites at it. These pins protect the boundary so
/// the duplication can't silently come back.
void main() {
  group('NodeActions consolidation', () {
    final helperFile = File('lib/features/nodes/node_actions.dart');
    final sheetFile = File('lib/features/nodes/node_quick_actions_sheet.dart');
    final detailFile = File('lib/features/nodes/node_detail_screen.dart');

    late String helperSource;
    late String sheetSource;
    late String detailSource;

    setUpAll(() {
      expect(helperFile.existsSync(), true);
      expect(sheetFile.existsSync(), true);
      expect(detailFile.existsSync(), true);
      helperSource = helperFile.readAsStringSync();
      sheetSource = sheetFile.readAsStringSync();
      detailSource = detailFile.readAsStringSync();
    });

    test('helper exposes the three top-level functions', () {
      expect(
        helperSource.contains('Future<void> toggleNodeFavorite('),
        true,
        reason: 'toggleNodeFavorite must be exported.',
      );
      expect(
        helperSource.contains('Future<void> toggleNodeMute('),
        true,
        reason: 'toggleNodeMute must be exported.',
      );
      expect(
        helperSource.contains('Future<bool> sendNodeTraceroute('),
        true,
        reason:
            'sendNodeTraceroute must be exported. Returns bool so callers '
            'can distinguish cooldown/disconnect denial from success.',
      );
    });

    test('helper handles the TX-blocked friendly snackbar internally', () {
      expect(
        helperSource.contains('maybeShowTxBlockedSnackBar(context, e)'),
        true,
        reason:
            'The "protocol not ready" friendly path used to live only on '
            'Node Detail. Lifting it into the helper means every caller '
            '(sheet + detail) gets the same UX.',
      );
    });

    test('quick-action sheet delegates to the shared helpers', () {
      expect(
        sheetSource.contains("import 'node_actions.dart';"),
        true,
        reason: 'Sheet must import the shared helpers.',
      );
      expect(
        sheetSource.contains('await toggleNodeFavorite(context, ref, node);'),
        true,
      );
      expect(
        sheetSource.contains('await toggleNodeMute(context, ref, node);'),
        true,
      );
      expect(
        sheetSource.contains('await sendNodeTraceroute(context, ref, node);'),
        true,
      );
      // No duplicated private helpers should remain.
      expect(
        sheetSource.contains('Future<void> _toggleNodeFavorite('),
        false,
        reason:
            'The Tranche 1 private duplicate must be deleted now that the '
            'shared helper exists.',
      );
      expect(
        sheetSource.contains('Future<void> _toggleNodeMute('),
        false,
        reason: 'Private mute duplicate must be gone.',
      );
      expect(
        sheetSource.contains('Future<void> _sendNodeTraceroute('),
        false,
        reason: 'Private traceroute duplicate must be gone.',
      );
    });

    test(
      'Node Detail wraps the helpers with busy-flag UI but does not duplicate logic',
      () {
        expect(detailSource.contains("import 'node_actions.dart';"), true);
        expect(
          detailSource.contains(
            'await toggleNodeFavorite(context, ref, node);',
          ),
          true,
          reason:
              'Node Detail _toggleFavorite must delegate to the shared helper, '
              'not duplicate the protocol round-trip locally.',
        );
        expect(
          detailSource.contains('await toggleNodeMute(context, ref, node);'),
          true,
        );
        expect(
          detailSource.contains(
            'await sendNodeTraceroute(context, ref, node);',
          ),
          true,
        );
        // The screen still owns its busy flags (these drive inline button
        // spinners that the sheet does not need).
        expect(detailSource.contains('_isTogglingFavorite'), true);
        expect(detailSource.contains('_isTogglingMute'), true);
        expect(detailSource.contains('_isSendingTraceroute'), true);
      },
    );

    test('async safety: refs captured before awaits in the helper', () {
      // Pre-capture pattern: the cooldown notifier is read once into a
      // local before sendTraceroute awaits. This survives the lint hook.
      expect(
        helperSource.contains(
          'final cooldownNotifier = ref.read(countdownProvider.notifier);',
        ),
        true,
        reason:
            'sendNodeTraceroute must pre-capture countdown notifier so the '
            'post-await call does not trigger an async-safety lint error.',
      );
    });

    test(
      'logs use the [NodeActions] marker (not [QuickActions]) inside the helper',
      () {
        // Logs inside the shared helper should be attributed to NodeActions
        // so future incident triage can tell sheet vs detail callers apart
        // from the marker on the call-site side.
        expect(helperSource.contains('[NodeActions] favorite toggled'), true);
        expect(helperSource.contains('[NodeActions] mute toggled'), true);
        expect(
          helperSource.contains('[NodeActions] traceroute requested'),
          true,
        );
      },
    );
  });
}
