// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level pins for the Tranche 1 shared node long-press quick
/// action sheet.
///
/// The sheet is reused by Messages > Contacts and the Nodes tab. These
/// pins protect the canonical AppBottomSheet.showActions pattern, the
/// existing provider graph (no duplicate state), cooldown awareness on
/// traceroute, and the destructive Disconnect entry being gated on
/// isMyNode + a caller-supplied callback.
void main() {
  group('node_quick_actions_sheet', () {
    final sheetFile = File('lib/features/nodes/node_quick_actions_sheet.dart');
    final messagingFile = File('lib/features/messaging/messaging_screen.dart');
    final nodesFile = File('lib/features/nodes/nodes_screen.dart');

    late String sheetSource;
    late String messagingSource;
    late String nodesSource;

    setUpAll(() {
      expect(sheetFile.existsSync(), true);
      expect(messagingFile.existsSync(), true);
      expect(nodesFile.existsSync(), true);
      sheetSource = sheetFile.readAsStringSync();
      messagingSource = messagingFile.readAsStringSync();
      nodesSource = nodesFile.readAsStringSync();
    });

    test('uses AppBottomSheet.showActions (canonical pattern)', () {
      expect(
        sheetSource.contains('AppBottomSheet.showActions<NodeQuickAction>'),
        true,
        reason:
            'Quick-action sheet must reuse the canonical actions API, not '
            'showModalBottomSheet (banned by CLAUDE.md).',
      );
      expect(
        sheetSource.contains('showModalBottomSheet'),
        false,
        reason:
            'Legacy showModalBottomSheet usage was the original bug — must '
            'stay out of this file.',
      );
    });

    test('exposes the required NodeQuickAction values', () {
      const required = [
        'viewDetails',
        'viewInNodeDex',
        'favorite',
        'mute',
        'traceroute',
        'disconnect',
      ];
      for (final name in required) {
        expect(
          sheetSource.contains(name),
          true,
          reason:
              'NodeQuickAction.$name must be present so Tranche 1 actions '
              'remain wired.',
        );
      }
    });

    test('reuses existing providers — no parallel local state', () {
      // Sprint 2 moved the provider plumbing into the shared
      // node_actions.dart helper. The sheet itself must delegate to it
      // (not run its own protocol round-trip) and must still read the
      // countdown provider locally so the action subtitle reflects the
      // cooldown without round-tripping through the helper.
      expect(
        sheetSource.contains('await toggleNodeFavorite(context, ref, node);'),
        true,
        reason: 'Favorite path delegates to the shared helper.',
      );
      expect(
        sheetSource.contains('await toggleNodeMute(context, ref, node);'),
        true,
        reason: 'Mute path delegates to the shared helper.',
      );
      expect(
        sheetSource.contains('await sendNodeTraceroute(context, ref, node);'),
        true,
        reason: 'Traceroute path delegates to the shared helper.',
      );
      // Cooldown read remains local to the sheet (drives the disabled
      // subtitle on the action row).
      expect(
        sheetSource.contains('countdownProvider.notifier'),
        true,
        reason:
            'Traceroute cooldown must still be read at sheet build time so '
            'the disabled-state subtitle is accurate.',
      );
    });

    test('cooldown disables traceroute and surfaces remaining seconds', () {
      expect(
        sheetSource.contains('enabled: cooldownRemaining == 0'),
        true,
        reason:
            'Traceroute action must be greyed out while the existing '
            'cooldown is active, not just snackbar-rejected on tap.',
      );
      expect(
        sheetSource.contains(
          'quickActionTracerouteCooldown(cooldownRemaining)',
        ),
        true,
        reason:
            'Subtitle must show the cooldown countdown so the user '
            'understands why the action is disabled.',
      );
    });

    test('Disconnect entry is gated on isMyNode + onDisconnect callback', () {
      expect(
        sheetSource.contains('if (isMyNode && onDisconnect != null)'),
        true,
        reason:
            'Disconnect must only render for the user own node AND only '
            'when the caller has provided a transport-aware callback.',
      );
    });

    test('logs every meaningful state transition', () {
      // Sheet-side markers cover sheet lifecycle (open, action picked,
      // dismissed). Action-side markers (favorite toggled, mute toggled,
      // traceroute requested/denied) moved into node_actions.dart in
      // Sprint 2 and now carry the [NodeActions] prefix — those are
      // pinned by the node_actions_consolidation_test.dart sibling.
      const sheetSideMarkers = [
        '[QuickActions] sheet opened',
        '[QuickActions] action=',
        '[QuickActions] dismissed without action',
      ];
      for (final marker in sheetSideMarkers) {
        expect(
          sheetSource.contains(marker),
          true,
          reason: 'AppLogging marker missing: $marker',
        );
      }
    });

    test('Messages > Contacts wires the sheet via long-press', () {
      expect(
        messagingSource.contains(
          "import '../nodes/node_quick_actions_sheet.dart';",
        ),
        true,
      );
      expect(
        messagingSource.contains(
          'onLongPress: () => _openContactQuickActions(contact),',
        ),
        true,
        reason:
            'Both contact-list call sites must wire onLongPress to the new '
            'helper.',
      );
      expect(
        messagingSource.contains(
          'await showNodeQuickActionsSheet(context, ref, node);',
        ),
        true,
      );
    });

    test('Nodes tab passes onDisconnect for myNode and uses the helper', () {
      expect(
        nodesSource.contains("import 'node_quick_actions_sheet.dart';"),
        true,
      );
      expect(
        nodesSource.contains('return showNodeQuickActionsSheet('),
        true,
        reason:
            'Nodes tab must now call the shared helper instead of the old '
            'showModalBottomSheet body.',
      );
      expect(
        nodesSource.contains('onDisconnect: _disconnectDevice,'),
        true,
        reason:
            'The nodes screen still owns the disconnect transport call; '
            'the sheet only invokes its callback.',
      );
      expect(
        nodesSource.contains(
          'onLongPress: () => _showNodeLongPressMenu(context, node, isMyNode)',
        ),
        true,
        reason:
            'Long-press must be exposed for all nodes — the old myNode-only '
            'gate is gone.',
      );
    });
  });
}
