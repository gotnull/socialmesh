// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodedex/album/card_flip_widget.dart';
import 'package:socialmesh/features/nodedex/album/holographic_effect.dart';
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/features/nodedex/services/sigil_generator.dart';
import 'package:socialmesh/features/nodedex/services/trait_engine.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';

class _EmptyNodesNotifier extends NodesNotifier {
  @override
  Map<int, MeshNode> build() => {};
}

Widget _wrap(Widget child, {ThemeData? theme}) {
  return ProviderScope(
    overrides: [nodesProvider.overrideWith(() => _EmptyNodesNotifier())],
    child: MaterialApp(
      theme: theme ?? ThemeData.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

NodeDexEntry _entry(int nodeNum, {required int encounterCount}) {
  return NodeDexEntry.discovered(
    nodeNum: nodeNum,
    timestamp: DateTime.utc(2026, 1, 2),
    sigil: SigilGenerator.generate(nodeNum),
    lastKnownName: '!${nodeNum.toRadixString(16).toUpperCase()}',
    lastKnownHardware: 'T-Echo',
    lastKnownRole: 'CLIENT',
    lastKnownFirmware: '2.7.15',
  ).copyWith(
    encounterCount: encounterCount,
    messageCount: 3,
    maxDistanceSeen: 1200,
    bestSnr: 7,
    coSeenNodes: const {},
  );
}

void main() {
  group('NodeDex selected-card rendering regressions', () {
    const brokenAndControlNodes = [0xAF10D229, 0x599D1617, 0x698571A8];

    testWidgets(
      'holographic overlay can be clipped without ParentData errors',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            SizedBox(
              width: 240,
              height: 336,
              child: Stack(
                children: [
                  const ColoredBox(color: Color(0xFF0D1117)),
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: const HolographicEffect(
                        rarityIndex: 4,
                        animate: false,
                        positioned: false,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('flipped back face keeps dark NodeDex surface in any theme', (
      tester,
    ) async {
      late BuildContext darkContext;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              darkContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final darkSurface = nodeDexCardBackSurfaceColor(darkContext);

      late BuildContext lightContext;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              lightContext = context;
              return const SizedBox.shrink();
            },
          ),
          theme: ThemeData.light(),
        ),
      );
      final lightSurface = nodeDexCardBackSurfaceColor(lightContext);

      expect(darkSurface, const Color(0xFF0D1117));
      expect(lightSurface, darkSurface);
      expect(darkSurface.computeLuminance(), lessThan(0.02));
    });

    for (final nodeNum in brokenAndControlNodes) {
      testWidgets('known node !${nodeNum.toRadixString(16).toUpperCase()} '
          'renders and flips without washing out', (tester) async {
        final entry = _entry(nodeNum, encounterCount: 50);
        final hexId = '!${nodeNum.toRadixString(16).toUpperCase()}';

        await tester.pumpWidget(
          _wrap(
            CardFlipWidget(
              entry: entry,
              traitResult: const TraitResult(
                primary: NodeTrait.relay,
                confidence: 0.91,
              ),
              displayName: hexId,
              hexId: hexId,
              width: 260,
              animate: false,
              front: const ColoredBox(color: Color(0xFF0D1117)),
            ),
          ),
        );

        await tester.tap(find.byType(CardFlipWidget));
        await tester.pump();

        expect(find.text(hexId), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
