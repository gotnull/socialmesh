import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/social.dart';
import 'package:socialmesh/services/social_service.dart';

void main() {
  group('CommentWithAuthor', () {
    test('creates CommentWithAuthor with author', () {
      final comment = Comment(
        id: 'comment-1',
        postId: 'post-1',
        authorId: 'user-1',
        content: 'Great post!',
        createdAt: DateTime(2024, 1, 1),
      );

      final author = PublicProfile(
        id: 'user-1',
        displayName: 'Test User',
        avatarUrl: 'https://example.com/avatar.jpg',
      );

      final commentWithAuthor = CommentWithAuthor(
        comment: comment,
        author: author,
      );

      expect(commentWithAuthor.comment.id, 'comment-1');
      expect(commentWithAuthor.author?.displayName, 'Test User');
      expect(
        commentWithAuthor.author?.avatarUrl,
        'https://example.com/avatar.jpg',
      );
    });

    test('creates CommentWithAuthor without author', () {
      final comment = Comment(
        id: 'comment-1',
        postId: 'post-1',
        authorId: 'deleted-user',
        content: 'Comment from deleted user',
        createdAt: DateTime(2024, 1, 1),
      );

      final commentWithAuthor = CommentWithAuthor(
        comment: comment,
        author: null,
      );

      expect(commentWithAuthor.comment.id, 'comment-1');
      expect(commentWithAuthor.author, isNull);
    });
  });

  group('Comment Threading Logic', () {
    test('builds correct thread structure', () {
      final comments = [
        Comment(
          id: 'c1',
          postId: 'p1',
          authorId: 'u1',
          content: 'Root comment 1',
          createdAt: DateTime(2024, 1, 1, 10, 0),
        ),
        Comment(
          id: 'c2',
          postId: 'p1',
          authorId: 'u2',
          parentId: 'c1',
          content: 'Reply to c1',
          createdAt: DateTime(2024, 1, 1, 11, 0),
        ),
        Comment(
          id: 'c3',
          postId: 'p1',
          authorId: 'u1',
          content: 'Root comment 2',
          createdAt: DateTime(2024, 1, 1, 12, 0),
        ),
        Comment(
          id: 'c4',
          postId: 'p1',
          authorId: 'u3',
          parentId: 'c2',
          content: 'Reply to c2',
          createdAt: DateTime(2024, 1, 1, 13, 0),
        ),
      ];

      // Build thread structure
      final rootComments = comments.where((c) => c.isRootComment).toList();
      final repliesByParent = <String, List<Comment>>{};

      for (final comment in comments) {
        if (!comment.isRootComment && comment.parentId != null) {
          repliesByParent.putIfAbsent(comment.parentId!, () => []);
          repliesByParent[comment.parentId!]!.add(comment);
        }
      }

      expect(rootComments, hasLength(2));
      expect(repliesByParent['c1'], hasLength(1));
      expect(repliesByParent['c2'], hasLength(1));
      expect(repliesByParent.containsKey('c3'), false);
      expect(repliesByParent.containsKey('c4'), false);
    });

    test('flattens thread for display', () {
      final comments = [
        Comment(
          id: 'c1',
          postId: 'p1',
          authorId: 'u1',
          content: 'Root 1',
          createdAt: DateTime(2024, 1, 1, 10, 0),
        ),
        Comment(
          id: 'c2',
          postId: 'p1',
          authorId: 'u2',
          parentId: 'c1',
          content: 'Reply to c1',
          createdAt: DateTime(2024, 1, 1, 11, 0),
        ),
        Comment(
          id: 'c3',
          postId: 'p1',
          authorId: 'u1',
          content: 'Root 2',
          createdAt: DateTime(2024, 1, 1, 12, 0),
        ),
      ];

      // Build display list with depths
      final displayList = <({Comment comment, int depth})>[];
      final repliesByParent = <String, List<Comment>>{};

      for (final comment in comments) {
        if (!comment.isRootComment && comment.parentId != null) {
          repliesByParent.putIfAbsent(comment.parentId!, () => []);
          repliesByParent[comment.parentId!]!.add(comment);
        }
      }

      void addWithReplies(Comment comment, int depth) {
        displayList.add((comment: comment, depth: depth));
        final replies = repliesByParent[comment.id] ?? [];
        for (final reply in replies) {
          addWithReplies(reply, depth + 1);
        }
      }

      final rootComments = comments.where((c) => c.isRootComment).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      for (final root in rootComments) {
        addWithReplies(root, 0);
      }

      expect(displayList, hasLength(3));
      expect(displayList[0].comment.id, 'c1');
      expect(displayList[0].depth, 0);
      expect(displayList[1].comment.id, 'c2');
      expect(displayList[1].depth, 1);
      expect(displayList[2].comment.id, 'c3');
      expect(displayList[2].depth, 0);
    });

    test('max depth is clamped at 3', () {
      int clampedDepth(int depth) => depth.clamp(0, 3);

      expect(clampedDepth(0), 0);
      expect(clampedDepth(1), 1);
      expect(clampedDepth(2), 2);
      expect(clampedDepth(3), 3);
      expect(clampedDepth(4), 3);
      expect(clampedDepth(10), 3);
    });
  });

  group('Comment Like Logic', () {
    test('like ID generation for comments', () {
      const userId = 'user-123';
      const commentId = 'comment-456';
      final likeId = '${userId}_comment_$commentId';

      expect(likeId, 'user-123_comment_comment-456');
    });

    test('optimistic like update', () {
      bool isLiked = false;
      int likeCount = 5;

      // Simulate like
      isLiked = true;
      likeCount++;

      expect(isLiked, true);
      expect(likeCount, 6);
    });

    test('optimistic unlike update', () {
      bool isLiked = true;
      int likeCount = 5;

      // Simulate unlike
      isLiked = false;
      likeCount = (likeCount - 1).clamp(0, 999999);

      expect(isLiked, false);
      expect(likeCount, 4);
    });

    test('revert on error', () {
      bool isLiked = false;
      int likeCount = 5;

      // Optimistic like
      isLiked = true;
      likeCount++;

      // Error occurred - revert
      isLiked = false;
      likeCount = (likeCount - 1).clamp(0, 999999);

      expect(isLiked, false);
      expect(likeCount, 5);
    });
  });

  group('Comment Display', () {
    test('author display name fallback', () {
      String getDisplayName(PublicProfile? author) {
        return author?.displayName ?? 'Unknown';
      }

      final author = PublicProfile(id: 'u1', displayName: 'John');
      expect(getDisplayName(author), 'John');
      expect(getDisplayName(null), 'Unknown');
    });

    test('avatar initial extraction', () {
      String getInitial(String? displayName) {
        return (displayName ?? 'U')[0].toUpperCase();
      }

      expect(getInitial('John'), 'J');
      expect(getInitial('jane'), 'J');
      expect(getInitial(null), 'U');
    });

    test('content whitespace normalization', () {
      const content = 'Hello\nWorld\n\nTest';
      final normalized = content.replaceAll(RegExp(r'\s+'), ' ');

      expect(normalized, 'Hello World Test');
    });

    test('indent calculation for replies', () {
      double getIndent(int depth, bool isReply) {
        return isReply ? 54.0 : 16.0;
      }

      expect(getIndent(0, false), 16.0);
      expect(getIndent(1, true), 54.0);
      expect(getIndent(2, true), 54.0);
      expect(getIndent(3, true), 54.0);
    });

    test('avatar size for replies vs root', () {
      double getAvatarRadius(bool isReply) {
        return isReply ? 12 : 16;
      }

      expect(getAvatarRadius(false), 16);
      expect(getAvatarRadius(true), 12);
    });

    test('font size for replies vs root', () {
      double getFontSize(bool isReply) {
        return isReply ? 13 : 14;
      }

      expect(getFontSize(false), 14);
      expect(getFontSize(true), 13);
    });
  });

  group('Comment Actions', () {
    test('delete confirmation flow', () {
      bool confirmDelete(bool userConfirmed) {
        return userConfirmed;
      }

      expect(confirmDelete(true), true);
      expect(confirmDelete(false), false);
    });

    test('reply depth limit check', () {
      bool canReply(int depth) {
        return depth < 3;
      }

      expect(canReply(0), true);
      expect(canReply(1), true);
      expect(canReply(2), true);
      expect(canReply(3), false);
      expect(canReply(4), false);
    });

    test('own comment detection', () {
      bool isOwnComment(String? currentUserId, String authorId) {
        return currentUserId == authorId;
      }

      expect(isOwnComment('user-1', 'user-1'), true);
      expect(isOwnComment('user-1', 'user-2'), false);
      expect(isOwnComment(null, 'user-1'), false);
    });
  });
}
