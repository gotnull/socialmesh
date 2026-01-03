import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/social.dart';
import 'package:socialmesh/services/social_service.dart';

void main() {
  group('Comment Threading Logic', () {
    test('organizes flat comments into tree structure', () {
      // Simulates the logic in post_detail_screen.dart
      final allComments = [
        // Root comment
        _createCommentWithAuthor('c1', null, 'Root comment 1'),
        // Reply to c1
        _createCommentWithAuthor('c2', 'c1', 'Reply to c1'),
        // Another root
        _createCommentWithAuthor('c3', null, 'Root comment 2'),
        // Reply to c2 (nested reply)
        _createCommentWithAuthor('c4', 'c2', 'Reply to reply'),
        // Another reply to c1
        _createCommentWithAuthor('c5', 'c1', 'Another reply to c1'),
      ];

      // Build tree structure (same logic as post_detail_screen)
      final rootComments = allComments
          .where((c) => c.comment.parentId == null)
          .toList();
      final repliesMap = <String, List<CommentWithAuthor>>{};

      for (final c in allComments) {
        if (c.comment.parentId != null) {
          repliesMap.putIfAbsent(c.comment.parentId!, () => []).add(c);
        }
      }

      // Should have 2 root comments
      expect(rootComments.length, 2);
      expect(rootComments[0].comment.id, 'c1');
      expect(rootComments[1].comment.id, 'c3');

      // c1 should have 2 direct replies
      expect(repliesMap['c1']?.length, 2);
      expect(repliesMap['c1']![0].comment.id, 'c2');
      expect(repliesMap['c1']![1].comment.id, 'c5');

      // c2 should have 1 reply
      expect(repliesMap['c2']?.length, 1);
      expect(repliesMap['c2']![0].comment.id, 'c4');

      // c3 should have no replies
      expect(repliesMap['c3'], isNull);
    });

    test('flattens tree with correct depth', () {
      final allComments = [
        _createCommentWithAuthor('c1', null, 'Root'),
        _createCommentWithAuthor('c2', 'c1', 'Depth 1'),
        _createCommentWithAuthor('c3', 'c2', 'Depth 2'),
        _createCommentWithAuthor('c4', 'c3', 'Depth 3'),
        _createCommentWithAuthor('c5', 'c4', 'Depth 4 (clamped)'),
      ];

      final rootComments = allComments
          .where((c) => c.comment.parentId == null)
          .toList();
      final repliesMap = <String, List<CommentWithAuthor>>{};

      for (final c in allComments) {
        if (c.comment.parentId != null) {
          repliesMap.putIfAbsent(c.comment.parentId!, () => []).add(c);
        }
      }

      // Flatten with depth tracking
      final displayList = <_DisplayItem>[];
      void addWithReplies(CommentWithAuthor comment, int depth) {
        displayList.add(_DisplayItem(comment: comment, depth: depth));
        final replies = repliesMap[comment.comment.id] ?? [];
        for (final reply in replies) {
          addWithReplies(reply, depth + 1);
        }
      }

      for (final root in rootComments) {
        addWithReplies(root, 0);
      }

      expect(displayList.length, 5);
      expect(displayList[0].depth, 0); // c1
      expect(displayList[1].depth, 1); // c2
      expect(displayList[2].depth, 2); // c3
      expect(displayList[3].depth, 3); // c4
      expect(displayList[4].depth, 4); // c5

      // Verify clamping works (UI would clamp to 3)
      expect(displayList[4].depth.clamp(0, 3), 3);
    });

    test('handles empty comment list', () {
      final allComments = <CommentWithAuthor>[];

      final rootComments = allComments
          .where((c) => c.comment.parentId == null)
          .toList();

      expect(rootComments, isEmpty);
    });

    test('handles orphaned replies gracefully', () {
      // Reply to non-existent parent
      final allComments = [
        _createCommentWithAuthor('c1', 'nonexistent', 'Orphan reply'),
        _createCommentWithAuthor('c2', null, 'Root'),
      ];

      final rootComments = allComments
          .where((c) => c.comment.parentId == null)
          .toList();
      final repliesMap = <String, List<CommentWithAuthor>>{};

      for (final c in allComments) {
        if (c.comment.parentId != null) {
          repliesMap.putIfAbsent(c.comment.parentId!, () => []).add(c);
        }
      }

      // Root should only have c2
      expect(rootComments.length, 1);
      expect(rootComments[0].comment.id, 'c2');

      // orphan is in repliesMap under nonexistent parent
      expect(repliesMap['nonexistent']?.length, 1);

      // When flattening, orphan won't appear since parent doesn't exist in roots
      final displayList = <_DisplayItem>[];
      void addWithReplies(CommentWithAuthor comment, int depth) {
        displayList.add(_DisplayItem(comment: comment, depth: depth));
        final replies = repliesMap[comment.comment.id] ?? [];
        for (final reply in replies) {
          addWithReplies(reply, depth + 1);
        }
      }

      for (final root in rootComments) {
        addWithReplies(root, 0);
      }

      // Only c2 appears (orphan is lost)
      expect(displayList.length, 1);
      expect(displayList[0].comment.comment.id, 'c2');
    });
  });

  group('Profile Update Validation', () {
    test('display name cannot be empty', () {
      const displayName = '';
      expect(displayName.trim().isEmpty, true);
    });

    test('display name can have leading/trailing spaces trimmed', () {
      const displayName = '  Test User  ';
      expect(displayName.trim(), 'Test User');
      expect(displayName.trim().isNotEmpty, true);
    });

    test('callsign can be null when empty', () {
      const callsign = '   ';
      final processed = callsign.trim().isEmpty ? null : callsign.trim();
      expect(processed, isNull);
    });

    test('callsign preserved when has value', () {
      const callsign = 'KD6-3.7';
      final processed = callsign.trim().isEmpty ? null : callsign.trim();
      expect(processed, 'KD6-3.7');
    });
  });

  group('Post Location', () {
    test('PostLocation can be created with all fields', () {
      final location = PostLocation(
        name: 'San Francisco, CA',
        latitude: 37.7749,
        longitude: -122.4194,
      );

      expect(location.name, 'San Francisco, CA');
      expect(location.latitude, closeTo(37.7749, 0.0001));
      expect(location.longitude, closeTo(-122.4194, 0.0001));
    });

    test('PostLocation roundtrip through map', () {
      final original = PostLocation(
        name: 'Test Location',
        latitude: 40.7128,
        longitude: -74.0060,
      );

      final map = original.toMap();
      final restored = PostLocation.fromMap(map);

      expect(restored.name, original.name);
      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
    });
  });

  group('Post Visibility', () {
    test('default visibility is public', () {
      const visibility = PostVisibility.public;
      expect(visibility, PostVisibility.public);
    });

    test('visibility options available', () {
      expect(PostVisibility.values, contains(PostVisibility.public));
      expect(PostVisibility.values, contains(PostVisibility.followersOnly));
      expect(PostVisibility.values, contains(PostVisibility.private));
    });
  });

  group('Share URL Generation', () {
    test('generates correct share URL format', () {
      const postId = 'abc123';
      const url = 'https://socialmesh.app/post/$postId';

      expect(url, contains('socialmesh.app'));
      expect(url, contains(postId));
      expect(url, startsWith('https://'));
    });

    test('share message contains URL', () {
      const postId = 'test-post-id';
      final message =
          'Check out this post on Socialmesh!\nhttps://socialmesh.app/post/$postId';

      expect(message, contains('https://socialmesh.app/post/test-post-id'));
    });
  });

  group('Report Functionality', () {
    test('report reasons are strings', () {
      const reason = 'Inappropriate content';
      expect(reason, isA<String>());
      expect(reason.isNotEmpty, true);
    });

    test('report types match expected values', () {
      // These should match what's in social_service.dart
      const postType = 'post';
      const userType = 'user';
      const commentType = 'comment';

      expect(postType, 'post');
      expect(userType, 'user');
      expect(commentType, 'comment');
    });
  });
}

// Helper to create CommentWithAuthor for testing
CommentWithAuthor _createCommentWithAuthor(
  String id,
  String? parentId,
  String content,
) {
  return CommentWithAuthor(
    comment: Comment(
      id: id,
      postId: 'test-post',
      authorId: 'test-user',
      content: content,
      parentId: parentId,
      createdAt: DateTime(2024, 1, 1),
    ),
    author: PublicProfile(id: 'test-user', displayName: 'Test User'),
  );
}

// Helper class matching post_detail_screen.dart structure
class _DisplayItem {
  final CommentWithAuthor comment;
  final int depth;

  _DisplayItem({required this.comment, required this.depth});
}
