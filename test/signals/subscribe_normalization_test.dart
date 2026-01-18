import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:socialmesh/features/signals/widgets/signal_card.dart';
import 'package:socialmesh/features/social/widgets/subscribe_button.dart';
import 'package:socialmesh/models/social.dart';
import 'package:socialmesh/providers/auth_providers.dart';

void main() {
  testWidgets(
    'SubscribeButton receives normalized cloud author id for mesh signals with authorSnapshot',
    (WidgetTester tester) async {
      // Create a Post that came over the mesh but has a cloud author snapshot
      final post = Post(
        id: 'sig1',
        authorId: 'mesh_cloud123',
        content: 'hello',
        createdAt: DateTime.now(),
        postMode: PostMode.signal,
        origin: SignalOrigin.mesh,
        authorSnapshot: const PostAuthorSnapshot(displayName: 'CloudUser'),
      );

      // Build the widget tree with provider overrides to avoid network
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // No signed-in user (subscribe button still renders as a sign-in prompt),
            // but we only care that the SubscribeButton was given the normalized id.
            currentUserProvider.overrideWith((ref) => null),
          ],
          child: MaterialApp(
            home: Scaffold(body: SignalCard(signal: post)),
          ),
        ),
      );

      // Allow a single pump for widget build (avoid waiting on long streams)
      await tester.pump();

      // Find SubscribeButton
      final finder = find.byType(SubscribeButton);
      expect(finder, findsOneWidget);

      final sb = tester.widget<SubscribeButton>(finder);

      // Verify the authorId was normalized (strip 'mesh_' prefix)
      expect(sb.authorId, 'cloud123');
    },
  );
}
