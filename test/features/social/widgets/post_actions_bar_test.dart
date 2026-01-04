import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/models/social.dart';
import 'package:socialmesh/features/social/widgets/post_actions_bar.dart';

void main() {
  group('PostActionsBar Widget', () {
    late Post testPost;

    setUp(() {
      testPost = Post(
        id: 'test-post-1',
        authorId: 'user-1',
        content: 'Test post content',
        createdAt: DateTime(2024, 1, 1),
        visibility: PostVisibility.public,
        likeCount: 10,
        commentCount: 5,
      );
    });

    testWidgets('displays like, comment, and share buttons', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: PostActionsBar(post: testPost)),
          ),
        ),
      );

      // Should show like icon (outline since not liked)
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      // Should show comment icon
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);

      // Should show share icon
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    });

    testWidgets('displays like count when showCounts is true', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PostActionsBar(post: testPost, showCounts: true),
            ),
          ),
        ),
      );

      // Should show like count
      expect(find.text('10'), findsOneWidget);

      // Should show comment count
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('hides counts when showCounts is false', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PostActionsBar(post: testPost, showCounts: false),
            ),
          ),
        ),
      );

      // Should not show counts
      expect(find.text('10'), findsNothing);
      expect(find.text('5'), findsNothing);
    });

    testWidgets('uses commentCountOverride when provided', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PostActionsBar(
                post: testPost,
                showCounts: true,
                commentCountOverride: 20,
              ),
            ),
          ),
        ),
      );

      // Should show overridden count instead of post.commentCount
      expect(find.text('20'), findsOneWidget);
      expect(find.text('5'), findsNothing);
    });

    testWidgets('calls onCommentTap when comment button pressed', (
      tester,
    ) async {
      bool commentTapped = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PostActionsBar(
                post: testPost,
                onCommentTap: () => commentTapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.chat_bubble_outline));
      await tester.pump();

      expect(commentTapped, true);
    });

    testWidgets('calls onShareTap when share button pressed', (tester) async {
      bool shareTapped = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PostActionsBar(
                post: testPost,
                onShareTap: () => shareTapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.share_outlined));
      await tester.pump();

      expect(shareTapped, true);
    });

    testWidgets('respects custom iconSize', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: PostActionsBar(post: testPost, iconSize: 32)),
          ),
        ),
      );

      // Find icons and verify they exist
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    });

    testWidgets('does not show zero counts', (tester) async {
      final postWithZeroCounts = Post(
        id: 'test-post-2',
        authorId: 'user-1',
        content: 'Test post',
        createdAt: DateTime(2024, 1, 1),
        visibility: PostVisibility.public,
        likeCount: 0,
        commentCount: 0,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PostActionsBar(post: postWithZeroCounts, showCounts: true),
            ),
          ),
        ),
      );

      // Should not show "0" text for counts
      expect(find.text('0'), findsNothing);
    });
  });

  group('Count Formatting', () {
    testWidgets('formats thousands correctly', (tester) async {
      final postWithHighCounts = Post(
        id: 'test-post-3',
        authorId: 'user-1',
        content: 'Viral post',
        createdAt: DateTime(2024, 1, 1),
        visibility: PostVisibility.public,
        likeCount: 1500,
        commentCount: 2500,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PostActionsBar(post: postWithHighCounts, showCounts: true),
            ),
          ),
        ),
      );

      // Should format as K
      expect(find.text('1.5K'), findsOneWidget);
      expect(find.text('2.5K'), findsOneWidget);
    });
  });
}
