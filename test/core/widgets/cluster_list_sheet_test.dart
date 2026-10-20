// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// The cluster list sheet's leading circle carries a node's short name, an
// identifier sized to its circle rather than body copy. At the Large
// accessibility text size the label must stay on one line inside the circle
// instead of wrapping, which is what a plain scaled Text in a fixed 36 pt
// container did.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/node_color.dart';
import 'package:socialmesh/core/widgets/mesh_map_widget.dart';
import 'package:socialmesh/core/widgets/node_avatar.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/mesh_models.dart';

MeshNode _node(int nodeNum, String shortName) {
  return MeshNode(
    nodeNum: nodeNum,
    longName: 'node-$shortName',
    shortName: shortName,
    userId: '!${nodeNum.toRadixString(16).padLeft(8, '0')}',
    lastHeard: DateTime.now(),
  );
}

Widget _wrap(Widget child, {required double textScale}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    // Keep the test surface size: the sheet caps its list at a fraction of
    // the screen height, and a bare MediaQueryData reports a zero screen.
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  testWidgets('short names stay on one line inside the circle at Large text', (
    tester,
  ) async {
    final nodes = [_node(0x1001, 'MGrW'), _node(0x1002, 'MGrX')];

    await tester.pumpWidget(
      _wrap(
        ClusterListSheet(nodes: nodes, onNodeSelected: (_) {}),
        textScale: 2.0,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NodeAvatar), findsNWidgets(2));

    // The circle shows the marker label, which upper-cases the short name.
    for (final name in nodes.map(nodeMarkerLabel)) {
      final text = tester.widget<Text>(find.text(name));
      expect(text.maxLines, 1);

      final avatarRect = tester.getRect(
        find.ancestor(of: find.text(name), matching: find.byType(NodeAvatar)),
      );
      final textRect = tester.getRect(find.text(name));
      expect(
        textRect.width,
        lessThanOrEqualTo(avatarRect.width),
        reason: '$name overflows its circle',
      );
      expect(
        textRect.height,
        lessThanOrEqualTo(avatarRect.height),
        reason: '$name overflows its circle',
      );
    }
  });

  testWidgets('tapping a row reports the node', (tester) async {
    MeshNode? selected;
    final nodes = [_node(0x1001, 'MGrW')];

    await tester.pumpWidget(
      _wrap(
        ClusterListSheet(nodes: nodes, onNodeSelected: (n) => selected = n),
        textScale: 1.0,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('node-MGrW'));
    await tester.pumpAndSettle();

    expect(selected?.nodeNum, 0x1001);
  });
}
