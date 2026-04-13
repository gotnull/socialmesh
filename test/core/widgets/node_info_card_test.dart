// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/core/widgets/node_info_card.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/models/presence_confidence.dart';
import 'package:socialmesh/providers/presence_providers.dart';

final _cardHostKey = UniqueKey();

Widget _wrap(Widget child, {required Map<int, NodePresence> presenceMap}) {
  return ProviderScope(
    overrides: [
      presenceMapProvider.overrideWith(
        () => _StaticPresenceNotifier(presenceMap),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme(AccentColors.magenta),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

MeshNode _buildNode() {
  return MeshNode(
    nodeNum: 123,
    longName: 'mesh-node',
    shortName: 'IK',
    userId: '!b2a72548',
    lastHeard: DateTime.now().subtract(const Duration(minutes: 5)),
    snr: 3,
    altitude: 42,
    hopCount: 5,
    hardwareModel: 'Heltec V4',
  );
}

NodePresence _buildPresence(MeshNode node) {
  return NodePresence(
    node: node,
    confidence: PresenceConfidence.fading,
    timeSinceLastHeard: const Duration(minutes: 5),
  );
}

class _StaticPresenceNotifier extends PresenceNotifier {
  _StaticPresenceNotifier(this._presenceMap);

  final Map<int, NodePresence> _presenceMap;

  @override
  Map<int, NodePresence> build() => _presenceMap;
}

void main() {
  group('NodeInfoCard', () {
    testWidgets('keeps trailing actions inside the card on narrow widths', (
      tester,
    ) async {
      final node = _buildNode();

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            key: _cardHostKey,
            width: 220,
            child: NodeInfoCard(
              node: node,
              onMessage: () {},
              onShareLocation: () {},
              onCopyCoordinates: () {},
              onTraceroute: () {},
              onViewDetails: () {},
              onViewHistory: () {},
              onShowTrack: () {},
              onViewPositionLog: () {},
            ),
          ),
          presenceMap: {node.nodeNum: _buildPresence(node)},
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);

      final cardRect = tester.getRect(find.byKey(_cardHostKey));
      final timelineRect = tester.getRect(find.byIcon(Icons.timeline));

      expect(timelineRect.right <= cardRect.right, isTrue);
      expect(timelineRect.left >= cardRect.left, isTrue);
    });

    testWidgets('allows tapping a wrapped trailing action', (tester) async {
      final node = _buildNode();
      var taps = 0;

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 220,
            child: NodeInfoCard(
              node: node,
              onMessage: () {},
              onShareLocation: () {},
              onCopyCoordinates: () {},
              onTraceroute: () {},
              onViewDetails: () {},
              onViewHistory: () {},
              onShowTrack: () {},
              onViewPositionLog: () => taps++,
            ),
          ),
          presenceMap: {node.nodeNum: _buildPresence(node)},
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.timeline));
      await tester.pump();

      expect(taps, 1);
    });
  });
}
