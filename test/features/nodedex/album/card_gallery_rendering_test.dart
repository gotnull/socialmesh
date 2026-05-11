// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodedex/album/album_constants.dart';
import 'package:socialmesh/features/nodedex/album/album_providers.dart';
import 'package:socialmesh/features/nodedex/album/card_gallery_screen.dart';
import 'package:socialmesh/features/nodedex/album/card_flip_widget.dart';
import 'package:socialmesh/features/nodedex/album/holographic_effect.dart';
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/features/nodedex/providers/nodedex_providers.dart';
import 'package:socialmesh/features/nodedex/services/sigil_generator.dart';
import 'package:socialmesh/features/nodedex/services/trait_engine.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';

class _EmptyNodesNotifier extends NodesNotifier {
  @override
  Map<int, MeshNode> build() => {};
}

class _StaticNodeDexNotifier extends NodeDexNotifier {
  final Map<int, NodeDexEntry> entries;

  _StaticNodeDexNotifier(this.entries);

  @override
  Map<int, NodeDexEntry> build() => entries;
}

Widget _wrap(
  Widget child, {
  ThemeData? theme,
  List<dynamic> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      nodesProvider.overrideWith(() => _EmptyNodesNotifier()),
      ...overrides,
    ],
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

    test('flip timing uses a non-overshooting gallery animation', () {
      expect(
        AlbumConstants.flipDuration.inMilliseconds,
        greaterThanOrEqualTo(500),
      );
      expect(AlbumConstants.flipCurve, Curves.easeInOutCubic);
      expect(AlbumConstants.flipPerspective, lessThanOrEqualTo(0.0015));
    });

    test('carousel layout leaves visible neighboring card peeks', () {
      expect(AlbumConstants.galleryViewportFraction, lessThanOrEqualTo(0.75));
      expect(AlbumConstants.galleryUnfocusedScale, greaterThanOrEqualTo(0.9));
      expect(AlbumConstants.galleryUnfocusedOpacity, greaterThanOrEqualTo(0.7));
    });

    testWidgets('gallery route hides underlying NodeDex app bar actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => showCardGallery(context: context),
                child: const Text('open'),
              );
            },
          ),
          overrides: [
            albumFlatEntriesProvider.overrideWithValue([
              _entry(0x9EE8522C, encounterCount: 50),
            ]),
          ],
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump(const Duration(milliseconds: 400));

      final route = ModalRoute.of(
        tester.element(find.byType(CardGalleryScreen, skipOffstage: false)),
      );
      expect(route?.opaque, isTrue);
    });

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

    testWidgets('top-bar flip button flips the current gallery card', (
      tester,
    ) async {
      final entry = _entry(0x9EE8522C, encounterCount: 50);
      await tester.pumpWidget(
        _wrap(
          const CardGalleryScreen(animate: false),
          overrides: [
            albumFlatEntriesProvider.overrideWithValue([entry]),
            nodeDexProvider.overrideWith(
              () => _StaticNodeDexNotifier({entry.nodeNum: entry}),
            ),
          ],
        ),
      );
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CardGalleryScreen)),
      );
      expect(container.read(cardFlipStateProvider), isEmpty);

      await tester.tap(find.bySemanticsLabel('Tap card to flip'));
      await tester.pump();

      expect(container.read(cardFlipStateProvider), contains(entry.nodeNum));
    });

    testWidgets(
      'gallery reveal animations are disabled when animate is false',
      (tester) async {
        final entry = _entry(0x9EE8522C, encounterCount: 50);
        await tester.pumpWidget(
          _wrap(
            const CardGalleryScreen(animate: false),
            overrides: [
              albumFlatEntriesProvider.overrideWithValue([entry]),
              nodeDexProvider.overrideWith(
                () => _StaticNodeDexNotifier({entry.nodeNum: entry}),
              ),
            ],
          ),
        );
        await tester.pump();

        expect(find.byType(AnimatedSwitcher), findsNothing);
      },
    );

    testWidgets('gallery uses subtle reveal animations when enabled', (
      tester,
    ) async {
      final entry = _entry(0x9EE8522C, encounterCount: 50);
      await tester.pumpWidget(
        _wrap(
          const CardGalleryScreen(),
          overrides: [
            albumFlatEntriesProvider.overrideWithValue([entry]),
            nodeDexProvider.overrideWith(
              () => _StaticNodeDexNotifier({entry.nodeNum: entry}),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSwitcher), findsOneWidget);
    });

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
