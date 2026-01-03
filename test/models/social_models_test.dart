import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/social.dart';
import 'package:socialmesh/services/social_service.dart';

void main() {
  group('PostVisibility', () {
    test('has all expected values', () {
      expect(PostVisibility.values.length, 3);
      expect(PostVisibility.values, contains(PostVisibility.public));
      expect(PostVisibility.values, contains(PostVisibility.followersOnly));
      expect(PostVisibility.values, contains(PostVisibility.private));
    });
  });

  group('Follow', () {
    test('generates correct document ID', () {
      final follow = Follow(
        id: 'test-id',
        followerId: 'user1',
        followeeId: 'user2',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(follow.documentId, 'user1_user2');
    });

    test('equality based on followerId and followeeId', () {
      final follow1 = Follow(
        id: 'id1',
        followerId: 'user1',
        followeeId: 'user2',
        createdAt: DateTime(2024, 1, 1),
      );

      final follow2 = Follow(
        id: 'id2',
        followerId: 'user1',
        followeeId: 'user2',
        createdAt: DateTime(2024, 6, 1),
      );

      final follow3 = Follow(
        id: 'id3',
        followerId: 'user1',
        followeeId: 'user3',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(follow1, equals(follow2));
      expect(follow1, isNot(equals(follow3)));
    });

    test('hashCode consistent with equality', () {
      final follow1 = Follow(
        id: 'id1',
        followerId: 'user1',
        followeeId: 'user2',
        createdAt: DateTime(2024, 1, 1),
      );

      final follow2 = Follow(
        id: 'id2',
        followerId: 'user1',
        followeeId: 'user2',
        createdAt: DateTime(2024, 6, 1),
      );

      expect(follow1.hashCode, equals(follow2.hashCode));
    });

    test('toString contains relevant info', () {
      final follow = Follow(
        id: 'test-id',
        followerId: 'user1',
        followeeId: 'user2',
        createdAt: DateTime(2024, 1, 1),
      );

      final str = follow.toString();
      expect(str, contains('user1'));
      expect(str, contains('user2'));
    });
  });

  group('PostAuthorSnapshot', () {
    test('fromMap creates correct snapshot', () {
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

    test('fromMap handles missing optional fields', () {
      final map = {'displayName': 'Test User'};

      final snapshot = PostAuthorSnapshot.fromMap(map);

      expect(snapshot.displayName, 'Test User');
      expect(snapshot.avatarUrl, isNull);
      expect(snapshot.isVerified, false);
    });

    test('toMap creates correct map', () {
      final snapshot = PostAuthorSnapshot(
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
      final snapshot = PostAuthorSnapshot(
        displayName: 'Test User',
        isVerified: false,
      );

      final map = snapshot.toMap();

      expect(map.containsKey('avatarUrl'), false);
    });
  });

  group('Post', () {
    test('imageUrls is alias for mediaUrls', () {
      final post = Post(
        id: 'post-1',
        authorId: 'user-1',
        content: 'Test post',
        mediaUrls: ['url1', 'url2'],
        createdAt: DateTime(2024, 1, 1),
      );

      expect(post.imageUrls, equals(post.mediaUrls));
      expect(post.imageUrls, ['url1', 'url2']);
    });

    test('default values for optional fields', () {
      final post = Post(
        id: 'post-1',
        authorId: 'user-1',
        content: 'Test post',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(post.mediaUrls, isEmpty);
      expect(post.location, isNull);
      expect(post.nodeId, isNull);
      expect(post.commentCount, 0);
      expect(post.likeCount, 0);
      expect(post.authorSnapshot, isNull);
    });

    test('equality based on id', () {
      final post1 = Post(
        id: 'post-1',
        authorId: 'user-1',
        content: 'Content 1',
        createdAt: DateTime(2024, 1, 1),
      );

      final post2 = Post(
        id: 'post-1',
        authorId: 'user-2',
        content: 'Content 2',
        createdAt: DateTime(2024, 6, 1),
      );

      final post3 = Post(
        id: 'post-2',
        authorId: 'user-1',
        content: 'Content 1',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(post1, equals(post2));
      expect(post1, isNot(equals(post3)));
    });
  });

  group('PostLocation', () {
    test('creates with all fields', () {
      final location = PostLocation(
        name: 'San Francisco',
        latitude: 37.7749,
        longitude: -122.4194,
      );

      expect(location.name, 'San Francisco');
      expect(location.latitude, 37.7749);
      expect(location.longitude, -122.4194);
    });

    test('fromMap creates correct location', () {
      final map = {
        'name': 'Test Location',
        'latitude': 40.7128,
        'longitude': -74.0060,
      };

      final location = PostLocation.fromMap(map);

      expect(location.name, 'Test Location');
      expect(location.latitude, 40.7128);
      expect(location.longitude, -74.0060);
    });

    test('toMap creates correct map', () {
      final location = PostLocation(
        name: 'Test Location',
        latitude: 40.7128,
        longitude: -74.0060,
      );

      final map = location.toMap();

      expect(map['name'], 'Test Location');
      expect(map['latitude'], 40.7128);
      expect(map['longitude'], -74.0060);
    });
  });

  group('Comment', () {
    test('creates root comment without parentId', () {
      final comment = Comment(
        id: 'comment-1',
        postId: 'post-1',
        authorId: 'user-1',
        content: 'Test comment',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(comment.parentId, isNull);
      expect(comment.likeCount, 0);
    });

    test('creates reply comment with parentId', () {
      final reply = Comment(
        id: 'comment-2',
        postId: 'post-1',
        authorId: 'user-2',
        content: 'Reply comment',
        parentId: 'comment-1',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(reply.parentId, 'comment-1');
    });

    test('equality based on id', () {
      final comment1 = Comment(
        id: 'comment-1',
        postId: 'post-1',
        authorId: 'user-1',
        content: 'Content 1',
        createdAt: DateTime(2024, 1, 1),
      );

      final comment2 = Comment(
        id: 'comment-1',
        postId: 'post-2',
        authorId: 'user-2',
        content: 'Content 2',
        createdAt: DateTime(2024, 6, 1),
      );

      expect(comment1, equals(comment2));
    });
  });

  group('PublicProfile', () {
    test('creates with required fields', () {
      final profile = PublicProfile(id: 'user-1', displayName: 'Test User');

      expect(profile.id, 'user-1');
      expect(profile.displayName, 'Test User');
      expect(profile.avatarUrl, isNull);
      expect(profile.bio, isNull);
      expect(profile.callsign, isNull);
      expect(profile.followerCount, 0);
      expect(profile.followingCount, 0);
      expect(profile.postCount, 0);
      expect(profile.isVerified, false);
    });

    test('creates with all fields', () {
      final profile = PublicProfile(
        id: 'user-1',
        displayName: 'Test User',
        avatarUrl: 'https://example.com/avatar.jpg',
        bio: 'Test bio',
        callsign: 'KD6-3.7',
        followerCount: 100,
        followingCount: 50,
        postCount: 25,
        isVerified: true,
        createdAt: DateTime(2024, 1, 1),
      );

      expect(profile.avatarUrl, 'https://example.com/avatar.jpg');
      expect(profile.bio, 'Test bio');
      expect(profile.callsign, 'KD6-3.7');
      expect(profile.followerCount, 100);
      expect(profile.followingCount, 50);
      expect(profile.postCount, 25);
      expect(profile.isVerified, true);
    });

    test('equality based on id', () {
      final profile1 = PublicProfile(id: 'user-1', displayName: 'Name 1');

      final profile2 = PublicProfile(id: 'user-1', displayName: 'Name 2');

      final profile3 = PublicProfile(id: 'user-2', displayName: 'Name 1');

      expect(profile1, equals(profile2));
      expect(profile1, isNot(equals(profile3)));
    });

    test('toAuthorSnapshot creates correct snapshot', () {
      final profile = PublicProfile(
        id: 'user-1',
        displayName: 'Test User',
        avatarUrl: 'https://example.com/avatar.jpg',
        callsign: 'KD6-3.7',
        isVerified: true,
      );

      final snapshot = profile.toAuthorSnapshot();

      expect(snapshot.displayName, 'Test User');
      expect(snapshot.avatarUrl, 'https://example.com/avatar.jpg');
      expect(snapshot.callsign, 'KD6-3.7');
      expect(snapshot.isVerified, true);
    });
  });

  group('CommentWithAuthor', () {
    test('creates with comment and author', () {
      final comment = Comment(
        id: 'comment-1',
        postId: 'post-1',
        authorId: 'user-1',
        content: 'Test comment',
        createdAt: DateTime(2024, 1, 1),
      );

      final author = PublicProfile(
        id: 'user-1',
        displayName: 'Test User',
        avatarUrl: 'https://example.com/avatar.jpg',
        isVerified: true,
      );

      final commentWithAuthor = CommentWithAuthor(
        comment: comment,
        author: author,
      );

      expect(commentWithAuthor.comment, comment);
      expect(commentWithAuthor.author, author);
    });

    test('author can be null', () {
      final comment = Comment(
        id: 'comment-1',
        postId: 'post-1',
        authorId: 'user-1',
        content: 'Test comment',
        createdAt: DateTime(2024, 1, 1),
      );

      final commentWithAuthor = CommentWithAuthor(
        comment: comment,
        author: null,
      );

      expect(commentWithAuthor.author, isNull);
    });
  });

  group('FeedAuthorSnapshot', () {
    test('fromMap creates correct snapshot', () {
      final map = {
        'displayName': 'Test User',
        'avatarUrl': 'https://example.com/avatar.jpg',
        'callsign': 'KD6-3.7',
        'isVerified': true,
      };

      final snapshot = FeedAuthorSnapshot.fromMap(map);

      expect(snapshot.displayName, 'Test User');
      expect(snapshot.avatarUrl, 'https://example.com/avatar.jpg');
      expect(snapshot.callsign, 'KD6-3.7');
      expect(snapshot.isVerified, true);
    });

    test('fromMap handles missing optional fields', () {
      final map = {'displayName': 'Test User'};

      final snapshot = FeedAuthorSnapshot.fromMap(map);

      expect(snapshot.displayName, 'Test User');
      expect(snapshot.avatarUrl, isNull);
      expect(snapshot.callsign, isNull);
      expect(snapshot.isVerified, false);
    });
  });
}
