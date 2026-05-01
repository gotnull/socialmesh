// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:socialmesh/features/nodedex/map/nodedex_map_pin.dart';
import 'package:socialmesh/features/nodedex/map/widgets/nodedex_sigil_marker.dart';
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/features/nodedex/widgets/sigil_painter.dart';

NodeDexMapPin _pin({
  int nodeNum = 0xb15e74db,
  NodeSocialTag? socialTag,
  String? displayName,
}) {
  final now = DateTime(2026, 4, 24, 12);
  return NodeDexMapPin(
    nodeNum: nodeNum,
    position: LatLng(37.7749, -122.4194),
    positionedAt: now,
    lastEncounterAt: now,
    encounterCount: 3,
    socialTag: socialTag,
    displayName: displayName,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('renders a SigilAvatar inside the marker', (tester) async {
    await tester.pumpWidget(
      _wrap(NodeDexSigilMarker(pin: _pin(), isSelected: false, isStale: false)),
    );

    expect(find.byType(SigilAvatar), findsOneWidget);
  });

  testWidgets('stale marker is wrapped in Opacity (~0.6) so the sigil fades', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(NodeDexSigilMarker(pin: _pin(), isSelected: false, isStale: true)),
    );

    final opacity = find.byType(Opacity);
    expect(opacity, findsAtLeastNWidgets(1));
    // First Opacity wrapping our subtree should be the stale fade.
    final stale = tester
        .widgetList<Opacity>(opacity)
        .firstWhere(
          (o) => o.opacity < 1.0,
          orElse: () => const Opacity(opacity: 1),
        );
    expect(stale.opacity, closeTo(0.6, 0.01));
  });

  testWidgets(
    'fresh marker is NOT wrapped in a fade-Opacity by the marker itself',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          NodeDexSigilMarker(pin: _pin(), isSelected: false, isStale: false),
        ),
      );

      // The marker subtree may contain Opacity widgets owned by Sigil
      // rendering; verify none of them are at the canonical 0.6 stale
      // opacity value.
      final opacities = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .map((o) => o.opacity)
          .toList();
      for (final op in opacities) {
        expect(
          op,
          isNot(closeTo(0.6, 0.01)),
          reason: 'fresh marker must not apply 0.6 stale fade',
        );
      }
    },
  );

  testWidgets('rebuilds without crash for every social-tag value (and null)', (
    tester,
  ) async {
    for (final tag in [
      null,
      NodeSocialTag.contact,
      NodeSocialTag.trustedNode,
      NodeSocialTag.knownRelay,
      NodeSocialTag.frequentPeer,
    ]) {
      await tester.pumpWidget(
        _wrap(
          NodeDexSigilMarker(
            pin: _pin(socialTag: tag),
            isSelected: false,
            isStale: false,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('selected marker grows compared to unselected', (tester) async {
    await tester.pumpWidget(
      _wrap(NodeDexSigilMarker(pin: _pin(), isSelected: false, isStale: false)),
    );
    final unselectedSize = tester.getSize(find.byType(NodeDexSigilMarker));

    await tester.pumpWidget(
      _wrap(NodeDexSigilMarker(pin: _pin(), isSelected: true, isStale: false)),
    );
    final selectedSize = tester.getSize(find.byType(NodeDexSigilMarker));

    expect(
      selectedSize.width,
      greaterThan(unselectedSize.width),
      reason: 'selected state should enlarge the marker',
    );
  });
}
