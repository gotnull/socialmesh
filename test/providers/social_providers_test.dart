// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:socialmesh/providers/social_providers.dart';
import 'package:socialmesh/services/content_moderation_service.dart';
import 'package:socialmesh/services/social_service.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockAuth extends Mock implements FirebaseAuth {}

class _FakeSocialService extends SocialService {
  _FakeSocialService(this._linked)
    : super(firestore: _MockFirestore(), auth: _MockAuth());

  final List<int> _linked;

  @override
  Stream<List<int>> watchLinkedNodeIds() => Stream.value(_linked);
}

void main() {
  group('Social Providers', () {
    test('socialServiceProvider is a Provider of SocialService', () {
      expect(socialServiceProvider, isA<Provider<SocialService>>());
    });

    test('contentModerationServiceProvider is a Provider of ContentModerationService', () {
      expect(
        contentModerationServiceProvider,
        isA<Provider<ContentModerationService>>(),
      );
    });
  });

  group('Linked node providers', () {
    ProviderContainer containerWith(List<int> linked) {
      final container = ProviderContainer(
        overrides: [
          socialServiceProvider.overrideWithValue(_FakeSocialService(linked)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('linkedNodeIdsProvider emits the service stream', () async {
      final container = containerWith([11, 22]);
      final sub = container.listen(linkedNodeIdsProvider, (_, _) {});
      addTearDown(sub.close);

      expect(await container.read(linkedNodeIdsProvider.future), [11, 22]);
    });

    test('isNodeLinkedProvider is true only for a linked node', () async {
      final container = containerWith([11, 22]);
      final linkedSub = container.listen(isNodeLinkedProvider(22), (_, _) {});
      final otherSub = container.listen(isNodeLinkedProvider(33), (_, _) {});
      addTearDown(linkedSub.close);
      addTearDown(otherSub.close);

      expect(await container.read(isNodeLinkedProvider(22).future), isTrue);
      expect(await container.read(isNodeLinkedProvider(33).future), isFalse);
    });
  });
}
