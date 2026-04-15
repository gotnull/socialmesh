// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:socialmesh/features/mesh_feed/widgets/mesh_post_card.dart';
import 'package:socialmesh/features/nodedex/widgets/sigil_painter.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/mesh_feed/mesh_feed_ranking.dart';
import 'package:socialmesh/services/mesh_feed/mesh_post.dart';
import 'package:socialmesh/services/nodes/node_identity_store.dart';

// ---------------------------------------------------------------------------
// Test notifiers
// ---------------------------------------------------------------------------

class _TestNodeIdentityNotifier extends NodeIdentityNotifier {
  _TestNodeIdentityNotifier(this._identities);

  final Map<int, NodeIdentity> _identities;

  @override
  Map<int, NodeIdentity> build() => _identities;
}

class _TestMyNodeNumNotifier extends MyNodeNumNotifier {
  _TestMyNodeNumNotifier(this._nodeNum);

  final int? _nodeNum;

  @override
  int? build() => _nodeNum;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const int _myNodeNum = 100;
const int _remoteNodeNum = 200;

MeshPost _makePost({
  int authorNodeNum = _remoteNodeNum,
  String content = 'Hello mesh',
  bool isLocal = false,
  Set<MeshTransportType> transports = const {MeshTransportType.lora},
  int? hopCount,
}) {
  return MeshPost(
    authorNodeNum: authorNodeNum,
    createdAtMs: DateTime.now().millisecondsSinceEpoch,
    content: content,
    isLocal: isLocal,
    seenViaTransports: transports,
    hopCount: hopCount,
  );
}

RankedPost _rank(MeshPost post, {double trust = 0.5}) {
  return RankedPost(
    post: post,
    score: 0.5,
    freshnessComponent: 0.5,
    trustComponent: trust,
    proximityComponent: 0.5,
    recencyComponent: 0.5,
  );
}

Widget _wrap({
  required RankedPost rankedPost,
  int? myNodeNum = _myNodeNum,
  Map<int, NodeIdentity> identities = const {},
}) {
  return ProviderScope(
    overrides: [
      myNodeNumProvider.overrideWith(() => _TestMyNodeNumNotifier(myNodeNum)),
      nodeIdentityProvider.overrideWith(
        () => _TestNodeIdentityNotifier(identities),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: MeshPostCard(rankedPost: rankedPost)),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MeshPostCard authorship badge', () {
    testWidgets('self-authored post shows "Your post" badge', (tester) async {
      final post = _makePost(authorNodeNum: _myNodeNum, isLocal: true);
      await tester.pumpWidget(_wrap(rankedPost: _rank(post)));
      await tester.pump();

      expect(find.text('Your post'), findsOneWidget);
    });

    testWidgets(
      'remote-authored post does NOT show "Your post" even if isLocal=true',
      (tester) async {
        // This is the core fix: a post received via sync may carry isLocal=true
        // from the sender. The card must never show "Your post" based on that.
        final post = _makePost(
          authorNodeNum: _remoteNodeNum,
          isLocal: true,
          transports: {MeshTransportType.local, MeshTransportType.lanPeerSync},
        );
        await tester.pumpWidget(
          _wrap(rankedPost: _rank(post), myNodeNum: _myNodeNum),
        );
        await tester.pump();

        expect(find.text('Your post'), findsNothing);
      },
    );

    testWidgets('remote synced post shows "Synced" badge', (tester) async {
      final post = _makePost(
        authorNodeNum: _remoteNodeNum,
        transports: {MeshTransportType.lanPeerSync},
      );
      await tester.pumpWidget(_wrap(rankedPost: _rank(post)));
      await tester.pump();

      expect(find.text('Synced'), findsOneWidget);
    });

    testWidgets(
      'nearby post (hop <= 1, no sync transport) shows "Nearby" badge',
      (tester) async {
        final post = _makePost(
          authorNodeNum: _remoteNodeNum,
          transports: {MeshTransportType.lora},
          hopCount: 1,
        );
        await tester.pumpWidget(_wrap(rankedPost: _rank(post)));
        await tester.pump();

        expect(find.text('Nearby'), findsOneWidget);
      },
    );

    testWidgets('relayed post (hop > 1) shows "Relayed" badge', (tester) async {
      final post = _makePost(
        authorNodeNum: _remoteNodeNum,
        transports: {MeshTransportType.lora},
        hopCount: 3,
      );
      await tester.pumpWidget(_wrap(rankedPost: _rank(post)));
      await tester.pump();

      expect(find.text('Relayed'), findsOneWidget);
    });
  });

  group('MeshPostCard author name', () {
    testWidgets('displays longName when available', (tester) async {
      final post = _makePost(authorNodeNum: _remoteNodeNum);
      await tester.pumpWidget(
        _wrap(
          rankedPost: _rank(post),
          identities: {
            _remoteNodeNum: const NodeIdentity(
              nodeNum: _remoteNodeNum,
              longName: 'Alpha Base',
              shortName: 'AB',
              lastUpdatedAt: 0,
            ),
          },
        ),
      );
      await tester.pump();

      expect(find.text('Alpha Base'), findsOneWidget);
      // shortName shown beside longName when different
      expect(find.text('AB'), findsOneWidget);
    });

    testWidgets('falls back to shortName when longName is null', (
      tester,
    ) async {
      final post = _makePost(authorNodeNum: _remoteNodeNum);
      await tester.pumpWidget(
        _wrap(
          rankedPost: _rank(post),
          identities: {
            _remoteNodeNum: const NodeIdentity(
              nodeNum: _remoteNodeNum,
              shortName: 'AB',
              lastUpdatedAt: 0,
            ),
          },
        ),
      );
      await tester.pump();

      expect(find.text('AB'), findsOneWidget);
    });

    testWidgets('falls back to hex when no name available', (tester) async {
      final post = _makePost(authorNodeNum: _remoteNodeNum);
      await tester.pumpWidget(_wrap(rankedPost: _rank(post)));
      await tester.pump();

      final expectedHex = '!${_remoteNodeNum.toRadixString(16)}';
      expect(find.text(expectedHex), findsOneWidget);
    });
  });

  group('MeshPostCard rendering', () {
    testWidgets('renders SigilAvatar for the author', (tester) async {
      final post = _makePost(authorNodeNum: _remoteNodeNum);
      await tester.pumpWidget(_wrap(rankedPost: _rank(post)));
      await tester.pump();

      expect(find.byType(SigilAvatar), findsOneWidget);
    });

    testWidgets('renders post content text', (tester) async {
      final post = _makePost(content: 'Test mesh message from the field');
      await tester.pumpWidget(_wrap(rankedPost: _rank(post)));
      await tester.pump();

      expect(find.text('Test mesh message from the field'), findsOneWidget);
    });

    testWidgets('multi-transport post shows swap_horiz icon', (tester) async {
      final post = _makePost(
        transports: {MeshTransportType.lora, MeshTransportType.lanPeerSync},
      );
      await tester.pumpWidget(_wrap(rankedPost: _rank(post)));
      await tester.pump();

      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
    });

    testWidgets('single-transport post does not show swap_horiz icon', (
      tester,
    ) async {
      final post = _makePost(transports: {MeshTransportType.lora});
      await tester.pumpWidget(_wrap(rankedPost: _rank(post)));
      await tester.pump();

      expect(find.byIcon(Icons.swap_horiz), findsNothing);
    });

    testWidgets('trust indicator displays for low trust score', (tester) async {
      final post = _makePost();
      await tester.pumpWidget(_wrap(rankedPost: _rank(post, trust: 0.10)));
      await tester.pump();

      expect(find.text('Unknown'), findsOneWidget);
    });

    testWidgets('trust indicator displays for high trust score', (
      tester,
    ) async {
      final post = _makePost();
      await tester.pumpWidget(_wrap(rankedPost: _rank(post, trust: 0.80)));
      await tester.pump();

      expect(find.text('Established'), findsOneWidget);
    });
  });
}
