import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/story.dart';

void main() {
  group('Story', () {
    test('creates story with required fields', () {
      final story = Story(
        id: 'story-1',
        authorId: 'user-1',
        mediaUrl: 'https://example.com/image.jpg',
        mediaType: StoryMediaType.image,
        createdAt: DateTime(2024, 1, 1),
        expiresAt: DateTime(2024, 1, 2),
      );

      expect(story.id, 'story-1');
      expect(story.authorId, 'user-1');
      expect(story.mediaUrl, 'https://example.com/image.jpg');
      expect(story.mediaType, StoryMediaType.image);
      expect(story.viewCount, 0);
      expect(story.likeCount, 0);
    });

    test('isExpired returns true for past expiration', () {
      final story = Story(
        id: 'story-1',
        authorId: 'user-1',
        mediaUrl: 'https://example.com/image.jpg',
        mediaType: StoryMediaType.image,
        createdAt: DateTime(2020, 1, 1),
        expiresAt: DateTime(2020, 1, 2),
      );

      expect(story.isExpired, true);
    });

    test('isExpired returns false for future expiration', () {
      final story = Story(
        id: 'story-1',
        authorId: 'user-1',
        mediaUrl: 'https://example.com/image.jpg',
        mediaType: StoryMediaType.image,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );

      expect(story.isExpired, false);
    });

    test('copyWith creates modified copy', () {
      final story = Story(
        id: 'story-1',
        authorId: 'user-1',
        mediaUrl: 'https://example.com/image.jpg',
        mediaType: StoryMediaType.image,
        createdAt: DateTime(2024, 1, 1),
        expiresAt: DateTime(2024, 1, 2),
        viewCount: 10,
        likeCount: 5,
      );

      final updated = story.copyWith(viewCount: 20, likeCount: 10);

      expect(updated.id, story.id);
      expect(updated.authorId, story.authorId);
      expect(updated.viewCount, 20);
      expect(updated.likeCount, 10);
    });

    test('isVideo returns true for video media type', () {
      final story = Story(
        id: 'story-1',
        authorId: 'user-1',
        mediaUrl: 'https://example.com/video.mp4',
        mediaType: StoryMediaType.video,
        createdAt: DateTime(2024, 1, 1),
        expiresAt: DateTime(2024, 1, 2),
      );

      expect(story.isVideo, true);
    });

    test('isVideo returns false for image media type', () {
      final story = Story(
        id: 'story-1',
        authorId: 'user-1',
        mediaUrl: 'https://example.com/image.jpg',
        mediaType: StoryMediaType.image,
        createdAt: DateTime(2024, 1, 1),
        expiresAt: DateTime(2024, 1, 2),
      );

      expect(story.isVideo, false);
    });

    test('timeRemaining returns Duration.zero for expired story', () {
      final story = Story(
        id: 'story-1',
        authorId: 'user-1',
        mediaUrl: 'https://example.com/image.jpg',
        mediaType: StoryMediaType.image,
        createdAt: DateTime(2020, 1, 1),
        expiresAt: DateTime(2020, 1, 2),
      );

      expect(story.timeRemaining, Duration.zero);
    });

    test('equality is based on id', () {
      final story1 = Story(
        id: 'story-1',
        authorId: 'user-1',
        mediaUrl: 'https://example.com/image.jpg',
        mediaType: StoryMediaType.image,
        createdAt: DateTime(2024, 1, 1),
        expiresAt: DateTime(2024, 1, 2),
      );

      final story2 = Story(
        id: 'story-1',
        authorId: 'user-2', // Different author
        mediaUrl: 'https://example.com/other.jpg',
        mediaType: StoryMediaType.video,
        createdAt: DateTime(2024, 2, 1),
        expiresAt: DateTime(2024, 2, 2),
      );

      expect(story1, equals(story2));
      expect(story1.hashCode, equals(story2.hashCode));
    });
  });

  group('StoryGroup', () {
    test('creates story group', () {
      final stories = [
        Story(
          id: 'story-1',
          authorId: 'user-1',
          mediaUrl: 'https://example.com/image1.jpg',
          mediaType: StoryMediaType.image,
          createdAt: DateTime(2024, 1, 1, 10),
          expiresAt: DateTime(2024, 1, 2, 10),
        ),
        Story(
          id: 'story-2',
          authorId: 'user-1',
          mediaUrl: 'https://example.com/image2.jpg',
          mediaType: StoryMediaType.image,
          createdAt: DateTime(2024, 1, 1, 12),
          expiresAt: DateTime(2024, 1, 2, 12),
        ),
      ];

      final group = StoryGroup(
        userId: 'user-1',
        stories: stories,
        lastStoryAt: DateTime(2024, 1, 1, 12),
      );

      expect(group.userId, 'user-1');
      expect(group.stories.length, 2);
      expect(group.lastStoryAt, DateTime(2024, 1, 1, 12));
      expect(group.storyCount, 2);
    });

    test('currentStory returns first story', () {
      final stories = [
        Story(
          id: 'story-1',
          authorId: 'user-1',
          mediaUrl: 'https://example.com/image1.jpg',
          mediaType: StoryMediaType.image,
          createdAt: DateTime(2024, 1, 1, 10),
          expiresAt: DateTime(2024, 1, 2, 10),
        ),
        Story(
          id: 'story-2',
          authorId: 'user-1',
          mediaUrl: 'https://example.com/image2.jpg',
          mediaType: StoryMediaType.image,
          createdAt: DateTime(2024, 1, 1, 12),
          expiresAt: DateTime(2024, 1, 2, 12),
        ),
      ];

      final group = StoryGroup(
        userId: 'user-1',
        stories: stories,
        lastStoryAt: DateTime(2024, 1, 1, 12),
      );

      expect(group.currentStory?.id, 'story-1');
    });

    test('currentStory returns null for empty group', () {
      final group = StoryGroup(
        userId: 'user-1',
        stories: const [],
        lastStoryAt: DateTime(2024, 1, 1, 12),
      );

      expect(group.currentStory, isNull);
    });

    test('hasUnviewed flag works correctly', () {
      final stories = [
        Story(
          id: 'story-1',
          authorId: 'user-1',
          mediaUrl: 'https://example.com/image.jpg',
          mediaType: StoryMediaType.image,
          createdAt: DateTime(2024, 1, 1),
          expiresAt: DateTime(2024, 1, 2),
        ),
      ];

      final groupWithUnviewed = StoryGroup(
        userId: 'user-1',
        stories: stories,
        hasUnviewed: true,
        lastStoryAt: DateTime(2024, 1, 1),
      );

      final groupAllViewed = StoryGroup(
        userId: 'user-1',
        stories: stories,
        hasUnviewed: false,
        lastStoryAt: DateTime(2024, 1, 1),
      );

      expect(groupWithUnviewed.hasUnviewed, true);
      expect(groupAllViewed.hasUnviewed, false);
    });

    test('copyWith creates modified copy', () {
      final group = StoryGroup(
        userId: 'user-1',
        stories: const [],
        hasUnviewed: false,
        lastStoryAt: DateTime(2024, 1, 1),
      );

      final updated = group.copyWith(hasUnviewed: true);

      expect(updated.hasUnviewed, true);
      expect(updated.userId, group.userId);
    });

    test('equality is based on userId', () {
      final group1 = StoryGroup(
        userId: 'user-1',
        stories: const [],
        lastStoryAt: DateTime(2024, 1, 1),
      );

      final group2 = StoryGroup(
        userId: 'user-1',
        stories: const [],
        lastStoryAt: DateTime(2024, 2, 1), // Different date
      );

      expect(group1, equals(group2));
      expect(group1.hashCode, equals(group2.hashCode));
    });
  });

  group('StoryMediaType', () {
    test('has expected values', () {
      expect(StoryMediaType.values.length, 2);
      expect(StoryMediaType.values, contains(StoryMediaType.image));
      expect(StoryMediaType.values, contains(StoryMediaType.video));
    });
  });

  group('StoryVisibility', () {
    test('has expected values', () {
      expect(StoryVisibility.values.length, 3);
      expect(StoryVisibility.values, contains(StoryVisibility.public));
      expect(StoryVisibility.values, contains(StoryVisibility.followersOnly));
      expect(StoryVisibility.values, contains(StoryVisibility.closeFriends));
    });
  });

  group('ViewedStoriesState', () {
    test('initial state has no viewed stories', () {
      const state = ViewedStoriesState();
      expect(state.viewedStories, isEmpty);
    });

    test('hasViewed returns false for unviewed story', () {
      const state = ViewedStoriesState();
      expect(state.hasViewed('story-1'), false);
    });

    test('markViewed adds story to viewed list', () {
      const state = ViewedStoriesState();
      final updated = state.markViewed('story-1');

      expect(updated.hasViewed('story-1'), true);
      expect(state.hasViewed('story-1'), false); // Original unchanged
    });

    test('markViewed preserves existing viewed stories', () {
      final state = ViewedStoriesState(
        viewedStories: {'story-1': DateTime(2024, 1, 1)},
      );
      final updated = state.markViewed('story-2');

      expect(updated.hasViewed('story-1'), true);
      expect(updated.hasViewed('story-2'), true);
    });
  });

  group('StoryView', () {
    test('creates story view with required fields', () {
      final view = StoryView(
        viewerId: 'viewer-1',
        viewedAt: DateTime(2024, 1, 1),
      );

      expect(view.viewerId, 'viewer-1');
      expect(view.viewedAt, DateTime(2024, 1, 1));
    });
  });

  group('StoryLike', () {
    test('creates story like with required fields', () {
      final like = StoryLike(likerId: 'user-1', likedAt: DateTime(2024, 1, 1));

      expect(like.likerId, 'user-1');
      expect(like.likedAt, DateTime(2024, 1, 1));
    });
  });

  group('TextOverlay', () {
    test('creates text overlay with default values', () {
      const overlay = TextOverlay(text: 'Hello', x: 0.5, y: 0.5);

      expect(overlay.text, 'Hello');
      expect(overlay.x, 0.5);
      expect(overlay.y, 0.5);
      expect(overlay.fontSize, 24);
      expect(overlay.color, '#FFFFFF');
      expect(overlay.alignment, 'center');
    });

    test('creates text overlay with custom values', () {
      const overlay = TextOverlay(
        text: 'Custom',
        x: 0.2,
        y: 0.8,
        fontSize: 32.0,
        color: '#FF0000',
        alignment: 'left',
      );

      expect(overlay.text, 'Custom');
      expect(overlay.x, 0.2);
      expect(overlay.y, 0.8);
      expect(overlay.fontSize, 32.0);
      expect(overlay.color, '#FF0000');
      expect(overlay.alignment, 'left');
    });

    test('toMap returns correct map', () {
      const overlay = TextOverlay(
        text: 'Test',
        x: 0.3,
        y: 0.7,
        fontSize: 20,
        color: '#000000',
        alignment: 'right',
      );

      final map = overlay.toMap();
      expect(map['text'], 'Test');
      expect(map['x'], 0.3);
      expect(map['y'], 0.7);
      expect(map['fontSize'], 20);
      expect(map['color'], '#000000');
      expect(map['alignment'], 'right');
    });

    test('fromMap creates overlay correctly', () {
      final map = {
        'text': 'From Map',
        'x': 0.4,
        'y': 0.6,
        'fontSize': 28,
        'color': '#AABBCC',
        'alignment': 'center',
      };

      final overlay = TextOverlay.fromMap(map);
      expect(overlay.text, 'From Map');
      expect(overlay.x, 0.4);
      expect(overlay.y, 0.6);
      expect(overlay.fontSize, 28);
      expect(overlay.color, '#AABBCC');
      expect(overlay.alignment, 'center');
    });

    test('copyWith creates modified copy', () {
      const overlay = TextOverlay(text: 'Original', x: 0.5, y: 0.5);

      final updated = overlay.copyWith(text: 'Updated', fontSize: 36);

      expect(updated.text, 'Updated');
      expect(updated.fontSize, 36);
      expect(updated.x, 0.5); // Unchanged
      expect(updated.y, 0.5); // Unchanged
    });
  });
}
