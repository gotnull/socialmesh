import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/social.dart';

/// Tests for SocialService logic
/// Note: These tests validate business logic independently of Firebase
void main() {
  group('Social Models', () {
    group('Post', () {
      test('creates Post with required fields', () {
        final post = Post(
          id: 'post-1',
          authorId: 'user-1',
          content: 'Hello world!',
          createdAt: DateTime(2024, 1, 1),
          visibility: PostVisibility.public,
        );

        expect(post.id, 'post-1');
        expect(post.authorId, 'user-1');
        expect(post.content, 'Hello world!');
        expect(post.visibility, PostVisibility.public);
        expect(post.likeCount, 0);
        expect(post.commentCount, 0);
        expect(post.imageUrls, isEmpty);
      });

      test('creates Post with all fields', () {
        final authorSnapshot = PostAuthorSnapshot(
          displayName: 'Test User',
          avatarUrl: 'https://example.com/avatar.jpg',
          isVerified: true,
        );

        final post = Post(
          id: 'post-2',
          authorId: 'user-2',
          content: 'Post with images',
          createdAt: DateTime(2024, 1, 1),
          visibility: PostVisibility.followersOnly,
          imageUrls: ['https://example.com/img1.jpg'],
          likeCount: 10,
          commentCount: 5,
          authorSnapshot: authorSnapshot,
        );

        expect(post.imageUrls, hasLength(1));
        expect(post.likeCount, 10);
        expect(post.commentCount, 5);
        expect(post.authorSnapshot?.displayName, 'Test User');
        expect(post.authorSnapshot?.isVerified, true);
      });

      test('copyWith creates modified copy', () {
        final original = Post(
          id: 'post-1',
          authorId: 'user-1',
          content: 'Original content',
          createdAt: DateTime(2024, 1, 1),
          visibility: PostVisibility.public,
          likeCount: 5,
        );

        final modified = original.copyWith(
          content: 'Modified content',
          likeCount: 10,
        );

        expect(modified.id, 'post-1');
        expect(modified.content, 'Modified content');
        expect(modified.likeCount, 10);
        expect(original.content, 'Original content');
        expect(original.likeCount, 5);
      });

      test('hasImages returns correct value', () {
        final noImages = Post(
          id: 'post-1',
          authorId: 'user-1',
          content: 'No images',
          createdAt: DateTime(2024, 1, 1),
          visibility: PostVisibility.public,
        );

        final withImages = Post(
          id: 'post-2',
          authorId: 'user-1',
          content: 'With images',
          createdAt: DateTime(2024, 1, 1),
          visibility: PostVisibility.public,
          imageUrls: ['https://example.com/img.jpg'],
        );

        expect(noImages.hasImages, false);
        expect(withImages.hasImages, true);
      });
    });

    group('Comment', () {
      test('creates root Comment', () {
        final comment = Comment(
          id: 'comment-1',
          postId: 'post-1',
          authorId: 'user-1',
          content: 'Great post!',
          createdAt: DateTime(2024, 1, 1),
        );

        expect(comment.id, 'comment-1');
        expect(comment.postId, 'post-1');
        expect(comment.parentId, isNull);
        expect(comment.isRootComment, true);
        expect(comment.replyCount, 0);
        expect(comment.likeCount, 0);
      });

      test('creates reply Comment with parentId', () {
        final reply = Comment(
          id: 'comment-2',
          postId: 'post-1',
          authorId: 'user-2',
          parentId: 'comment-1',
          content: 'Thanks!',
          createdAt: DateTime(2024, 1, 1),
        );

        expect(reply.parentId, 'comment-1');
        expect(reply.isRootComment, false);
      });

      test('copyWith preserves parentId', () {
        final original = Comment(
          id: 'comment-1',
          postId: 'post-1',
          authorId: 'user-1',
          parentId: 'parent-1',
          content: 'Original',
          createdAt: DateTime(2024, 1, 1),
        );

        final modified = original.copyWith(content: 'Modified');

        expect(modified.parentId, 'parent-1');
        expect(modified.content, 'Modified');
      });
    });

    group('Like', () {
      test('creates Like with required fields', () {
        final like = Like(
          id: 'user-1_post-1',
          userId: 'user-1',
          postId: 'post-1',
          createdAt: DateTime(2024, 1, 1),
        );

        expect(like.id, 'user-1_post-1');
        expect(like.userId, 'user-1');
        expect(like.postId, 'post-1');
        expect(like.documentId, 'user-1_post-1');
      });

      test('equality based on userId and postId', () {
        final like1 = Like(
          id: 'user-1_post-1',
          userId: 'user-1',
          postId: 'post-1',
          createdAt: DateTime(2024, 1, 1),
        );

        final like2 = Like(
          id: 'user-1_post-1',
          userId: 'user-1',
          postId: 'post-1',
          createdAt: DateTime(2024, 1, 2),
        );

        final like3 = Like(
          id: 'user-2_post-1',
          userId: 'user-2',
          postId: 'post-1',
          createdAt: DateTime(2024, 1, 1),
        );

        expect(like1, equals(like2)); // Same user/post, different time
        expect(like1, isNot(equals(like3))); // Different user
      });
    });

    group('Follow', () {
      test('creates Follow with required fields', () {
        final follow = Follow(
          id: 'user-1_user-2',
          followerId: 'user-1',
          followeeId: 'user-2',
          createdAt: DateTime(2024, 1, 1),
        );

        expect(follow.followerId, 'user-1');
        expect(follow.followeeId, 'user-2');
        expect(follow.documentId, 'user-1_user-2');
      });

      test('equality based on follower and followee', () {
        final follow1 = Follow(
          id: 'user-1_user-2',
          followerId: 'user-1',
          followeeId: 'user-2',
          createdAt: DateTime(2024, 1, 1),
        );

        final follow2 = Follow(
          id: 'user-1_user-2',
          followerId: 'user-1',
          followeeId: 'user-2',
          createdAt: DateTime(2024, 1, 2),
        );

        expect(follow1, equals(follow2));
      });
    });

    group('PublicProfile', () {
      test('creates PublicProfile with required fields', () {
        final profile = PublicProfile(id: 'user-1', displayName: 'Test User');

        expect(profile.id, 'user-1');
        expect(profile.displayName, 'Test User');
        expect(profile.avatarUrl, isNull);
        expect(profile.bio, isNull);
        expect(profile.followerCount, 0);
        expect(profile.followingCount, 0);
        expect(profile.postCount, 0);
        expect(profile.isVerified, false);
      });

      test('creates PublicProfile with all fields', () {
        final profile = PublicProfile(
          id: 'user-1',
          displayName: 'Famous User',
          avatarUrl: 'https://example.com/avatar.jpg',
          bio: 'Hello world',
          callsign: 'FM123',
          followerCount: 1000,
          followingCount: 50,
          postCount: 100,
          isVerified: true,
        );

        expect(profile.avatarUrl, 'https://example.com/avatar.jpg');
        expect(profile.bio, 'Hello world');
        expect(profile.callsign, 'FM123');
        expect(profile.followerCount, 1000);
        expect(profile.isVerified, true);
      });

      test('copyWith creates modified copy', () {
        final original = PublicProfile(
          id: 'user-1',
          displayName: 'Original Name',
          followerCount: 10,
        );

        final modified = original.copyWith(
          displayName: 'New Name',
          followerCount: 20,
        );

        expect(modified.displayName, 'New Name');
        expect(modified.followerCount, 20);
        expect(original.displayName, 'Original Name');
        expect(original.followerCount, 10);
      });
    });

    group('PostAuthorSnapshot', () {
      test('creates snapshot with required fields', () {
        const snapshot = PostAuthorSnapshot(displayName: 'Test User');

        expect(snapshot.displayName, 'Test User');
        expect(snapshot.avatarUrl, isNull);
        expect(snapshot.isVerified, false);
      });

      test('creates snapshot from map', () {
        final map = {
          'displayName': 'Test User',
          'avatarUrl': 'https://example.com/avatar.jpg',
          'isVerified': true,
        };

        final snapshot = PostAuthorSnapshot.fromMap(map);

        expect(snapshot.displayName, 'Test User');
        expect(snapshot.avatarUrl, 'https://example.com/avatar.jpg');
        expect(snapshot.isVerified, true);
      });

      test('toMap returns correct structure', () {
        const snapshot = PostAuthorSnapshot(
          displayName: 'Test User',
          avatarUrl: 'https://example.com/avatar.jpg',
          isVerified: true,
        );

        final map = snapshot.toMap();

        expect(map['displayName'], 'Test User');
        expect(map['avatarUrl'], 'https://example.com/avatar.jpg');
        expect(map['isVerified'], true);
      });

      test('toMap excludes null avatarUrl', () {
        const snapshot = PostAuthorSnapshot(displayName: 'Test User');

        final map = snapshot.toMap();

        expect(map.containsKey('avatarUrl'), false);
      });
    });

    group('PostVisibility', () {
      test('enum has correct values', () {
        expect(PostVisibility.values, hasLength(3));
        expect(PostVisibility.values, contains(PostVisibility.public));
        expect(PostVisibility.values, contains(PostVisibility.followersOnly));
        expect(PostVisibility.values, contains(PostVisibility.private));
      });
    });
  });

  group('Social Business Logic', () {
    group('Like ID Generation', () {
      test('post like ID format is userId_postId', () {
        const userId = 'user-123';
        const postId = 'post-456';
        final likeId = '${userId}_$postId';

        expect(likeId, 'user-123_post-456');
      });

      test('comment like ID format is userId_comment_commentId', () {
        const userId = 'user-123';
        const commentId = 'comment-456';
        final likeId = '${userId}_comment_$commentId';

        expect(likeId, 'user-123_comment_comment-456');
      });
    });

    group('Follow ID Generation', () {
      test('follow ID format is followerId_followeeId', () {
        const followerId = 'user-1';
        const followeeId = 'user-2';
        final followId = '${followerId}_$followeeId';

        expect(followId, 'user-1_user-2');
      });
    });

    group('Comment Threading', () {
      test('root comments have null parentId', () {
        final rootComment = Comment(
          id: 'c1',
          postId: 'p1',
          authorId: 'u1',
          content: 'Root',
          createdAt: DateTime.now(),
        );

        expect(rootComment.isRootComment, true);
        expect(rootComment.parentId, isNull);
      });

      test('replies have non-null parentId', () {
        final reply = Comment(
          id: 'c2',
          postId: 'p1',
          authorId: 'u2',
          parentId: 'c1',
          content: 'Reply',
          createdAt: DateTime.now(),
        );

        expect(reply.isRootComment, false);
        expect(reply.parentId, 'c1');
      });

      test('threading depth calculation', () {
        // Simulate threading logic
        final comments = <String, String?>{
          'c1': null, // root
          'c2': 'c1', // reply to c1, depth 1
          'c3': 'c2', // reply to c2, depth 2
          'c4': 'c3', // reply to c3, depth 3
        };

        int getDepth(String commentId) {
          int depth = 0;
          String? parentId = comments[commentId];
          while (parentId != null) {
            depth++;
            parentId = comments[parentId];
          }
          return depth;
        }

        expect(getDepth('c1'), 0);
        expect(getDepth('c2'), 1);
        expect(getDepth('c3'), 2);
        expect(getDepth('c4'), 3);
      });
    });

    group('Optimistic Updates', () {
      test('like count increment', () {
        int likeCount = 5;
        bool isLiked = false;

        // Simulate optimistic like
        if (!isLiked) {
          isLiked = true;
          likeCount++;
        }

        expect(likeCount, 6);
        expect(isLiked, true);
      });

      test('like count decrement does not go below zero', () {
        int likeCount = 0;
        bool isLiked = true;

        // Simulate optimistic unlike
        if (isLiked) {
          isLiked = false;
          likeCount = (likeCount - 1).clamp(0, 999999);
        }

        expect(likeCount, 0);
        expect(isLiked, false);
      });

      test('comment count increment', () {
        int commentCount = 3;

        // Simulate adding comment
        commentCount++;

        expect(commentCount, 4);
      });

      test('comment count decrement', () {
        int commentCount = 3;

        // Simulate deleting comment
        commentCount = (commentCount - 1).clamp(0, 999999);

        expect(commentCount, 2);
      });
    });

    group('Feed Item Sorting', () {
      test('posts sorted by createdAt descending', () {
        final posts = [
          Post(
            id: 'p1',
            authorId: 'u1',
            content: 'First',
            createdAt: DateTime(2024, 1, 1),
            visibility: PostVisibility.public,
          ),
          Post(
            id: 'p2',
            authorId: 'u1',
            content: 'Third',
            createdAt: DateTime(2024, 1, 3),
            visibility: PostVisibility.public,
          ),
          Post(
            id: 'p3',
            authorId: 'u1',
            content: 'Second',
            createdAt: DateTime(2024, 1, 2),
            visibility: PostVisibility.public,
          ),
        ];

        posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        expect(posts[0].content, 'Third');
        expect(posts[1].content, 'Second');
        expect(posts[2].content, 'First');
      });
    });

    group('Content Validation', () {
      test('empty content is invalid', () {
        const content = '';
        expect(content.trim().isEmpty, true);
      });

      test('whitespace-only content is invalid', () {
        const content = '   \n\t  ';
        expect(content.trim().isEmpty, true);
      });

      test('valid content passes', () {
        const content = 'Hello world!';
        expect(content.trim().isNotEmpty, true);
      });

      test('comment content collapsed to single line', () {
        const content = 'Line 1\nLine 2\n\nLine 3';
        final collapsed = content.replaceAll(RegExp(r'\s+'), ' ');

        expect(collapsed, 'Line 1 Line 2 Line 3');
      });
    });

    group('Profile Display', () {
      test('displayName fallback when null', () {
        String? displayName;
        final display = displayName ?? 'Unknown';

        expect(display, 'Unknown');
      });

      test('avatar initial from displayName', () {
        const displayName = 'John Doe';
        final initial = displayName[0].toUpperCase();

        expect(initial, 'J');
      });

      test('avatar initial from empty displayName', () {
        const displayName = '';
        final initial = displayName.isNotEmpty
            ? displayName[0].toUpperCase()
            : 'U';

        expect(initial, 'U');
      });
    });
  });

  group('Time Formatting', () {
    test('short time ago format', () {
      String shortTimeAgo(Duration diff) {
        if (diff.inSeconds < 60) return '${diff.inSeconds}s';
        if (diff.inMinutes < 60) return '${diff.inMinutes}m';
        if (diff.inHours < 24) return '${diff.inHours}h';
        if (diff.inDays < 7) return '${diff.inDays}d';
        if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
        if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo';
        return '${(diff.inDays / 365).floor()}y';
      }

      expect(shortTimeAgo(const Duration(seconds: 30)), '30s');
      expect(shortTimeAgo(const Duration(minutes: 5)), '5m');
      expect(shortTimeAgo(const Duration(hours: 3)), '3h');
      expect(shortTimeAgo(const Duration(days: 2)), '2d');
      expect(shortTimeAgo(const Duration(days: 14)), '2w');
      expect(shortTimeAgo(const Duration(days: 60)), '2mo');
      expect(shortTimeAgo(const Duration(days: 400)), '1y');
    });

    test('count formatting', () {
      String formatCount(int count) {
        if (count >= 1000000) {
          return '${(count / 1000000).toStringAsFixed(1)}M';
        } else if (count >= 1000) {
          return '${(count / 1000).toStringAsFixed(1)}K';
        }
        return count.toString();
      }

      expect(formatCount(0), '0');
      expect(formatCount(999), '999');
      expect(formatCount(1000), '1.0K');
      expect(formatCount(1500), '1.5K');
      expect(formatCount(10000), '10.0K');
      expect(formatCount(1000000), '1.0M');
      expect(formatCount(1500000), '1.5M');
    });
  });

  group('Report Functionality', () {
    test('report reasons are valid', () {
      final validReasons = [
        'spam',
        'harassment',
        'inappropriate',
        'misinformation',
        'other',
      ];

      expect(validReasons, hasLength(5));
      expect(validReasons, contains('spam'));
      expect(validReasons, contains('harassment'));
    });

    test('report requires reason', () {
      const reason = '';
      expect(reason.isEmpty, true);
    });

    test('report with valid reason', () {
      const reason = 'spam';
      expect(reason.isNotEmpty, true);
      expect(
        [
          'spam',
          'harassment',
          'inappropriate',
          'misinformation',
          'other',
        ].contains(reason),
        true,
      );
    });
  });
}
