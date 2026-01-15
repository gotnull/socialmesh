import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/social_activity.dart';

void main() {
  group('SocialActivityType', () {
    test('has all expected values', () {
      expect(SocialActivityType.values, contains(SocialActivityType.storyLike));
      expect(SocialActivityType.values, contains(SocialActivityType.storyView));
      expect(SocialActivityType.values, contains(SocialActivityType.follow));
      expect(SocialActivityType.values, contains(SocialActivityType.postLike));
      expect(
        SocialActivityType.values,
        contains(SocialActivityType.postComment),
      );
      expect(SocialActivityType.values, contains(SocialActivityType.mention));
      expect(
        SocialActivityType.values,
        contains(SocialActivityType.commentReply),
      );
    });
  });

  group('SocialActivity', () {
    test('creates activity with required fields', () {
      final activity = SocialActivity(
        id: 'activity-1',
        type: SocialActivityType.follow,
        actorId: 'user-1',
        targetUserId: 'user-2',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(activity.id, 'activity-1');
      expect(activity.type, SocialActivityType.follow);
      expect(activity.actorId, 'user-1');
      expect(activity.targetUserId, 'user-2');
      expect(activity.isRead, false);
    });

    test('creates activity with all optional fields', () {
      final activity = SocialActivity(
        id: 'activity-1',
        type: SocialActivityType.postLike,
        actorId: 'user-1',
        targetUserId: 'user-2',
        contentId: 'post-1',
        previewImageUrl: 'https://example.com/preview.jpg',
        textContent: 'This is a post',
        createdAt: DateTime(2024, 1, 1),
        isRead: true,
      );

      expect(activity.contentId, 'post-1');
      expect(activity.previewImageUrl, 'https://example.com/preview.jpg');
      expect(activity.textContent, 'This is a post');
      expect(activity.isRead, true);
    });

    test('toFirestore converts to map correctly', () {
      final activity = SocialActivity(
        id: 'activity-1',
        type: SocialActivityType.postComment,
        actorId: 'user-1',
        targetUserId: 'user-2',
        contentId: 'post-1',
        createdAt: DateTime(2024, 1, 1),
      );

      final map = activity.toFirestore();
      expect(map['type'], 'postComment');
      expect(map['actorId'], 'user-1');
      expect(map['targetUserId'], 'user-2');
      expect(map['contentId'], 'post-1');
    });

    test('copyWith creates modified copy', () {
      final activity = SocialActivity(
        id: 'activity-1',
        type: SocialActivityType.follow,
        actorId: 'user-1',
        targetUserId: 'user-2',
        createdAt: DateTime(2024, 1, 1),
        isRead: false,
      );

      final updated = activity.copyWith(isRead: true);

      expect(updated.isRead, true);
      expect(updated.id, activity.id);
      expect(updated.type, activity.type);
    });

    group('activity descriptions', () {
      test('follow description', () {
        final activity = SocialActivity(
          id: '1',
          type: SocialActivityType.follow,
          actorId: 'u1',
          targetUserId: 'u2',
          createdAt: DateTime.now(),
        );
        expect(activity.description, 'Someone started following you');
      });

      test('storyLike description', () {
        final activity = SocialActivity(
          id: '1',
          type: SocialActivityType.storyLike,
          actorId: 'u1',
          targetUserId: 'u2',
          contentId: 's1',
          createdAt: DateTime.now(),
        );
        expect(activity.description, 'Someone liked your story');
      });

      test('storyView description', () {
        final activity = SocialActivity(
          id: '1',
          type: SocialActivityType.storyView,
          actorId: 'u1',
          targetUserId: 'u2',
          contentId: 's1',
          createdAt: DateTime.now(),
        );
        expect(activity.description, 'Someone viewed your story');
      });

      test('postLike description', () {
        final activity = SocialActivity(
          id: '1',
          type: SocialActivityType.postLike,
          actorId: 'u1',
          targetUserId: 'u2',
          contentId: 'p1',
          createdAt: DateTime.now(),
        );
        expect(activity.description, 'Someone liked your post');
      });

      test('postComment description', () {
        final activity = SocialActivity(
          id: '1',
          type: SocialActivityType.postComment,
          actorId: 'u1',
          targetUserId: 'u2',
          contentId: 'p1',
          createdAt: DateTime.now(),
        );
        expect(activity.description, 'Someone commented on your post');
      });

      test('mention description', () {
        final activity = SocialActivity(
          id: '1',
          type: SocialActivityType.mention,
          actorId: 'u1',
          targetUserId: 'u2',
          createdAt: DateTime.now(),
        );
        expect(activity.description, 'Someone mentioned you');
      });

      test('commentReply description', () {
        final activity = SocialActivity(
          id: '1',
          type: SocialActivityType.commentReply,
          actorId: 'u1',
          targetUserId: 'u2',
          createdAt: DateTime.now(),
        );
        expect(activity.description, 'Someone replied to your comment');
      });
    });

    group('activity icon names', () {
      test('storyLike and postLike use favorite icon', () {
        final storyLike = SocialActivity(
          id: '1',
          type: SocialActivityType.storyLike,
          actorId: 'u1',
          targetUserId: 'u2',
          createdAt: DateTime.now(),
        );
        final postLike = SocialActivity(
          id: '2',
          type: SocialActivityType.postLike,
          actorId: 'u1',
          targetUserId: 'u2',
          createdAt: DateTime.now(),
        );

        expect(storyLike.iconName, 'favorite');
        expect(postLike.iconName, 'favorite');
      });

      test('storyView uses visibility icon', () {
        final activity = SocialActivity(
          id: '1',
          type: SocialActivityType.storyView,
          actorId: 'u1',
          targetUserId: 'u2',
          createdAt: DateTime.now(),
        );
        expect(activity.iconName, 'visibility');
      });

      test('follow uses person_add icon', () {
        final activity = SocialActivity(
          id: '1',
          type: SocialActivityType.follow,
          actorId: 'u1',
          targetUserId: 'u2',
          createdAt: DateTime.now(),
        );
        expect(activity.iconName, 'person_add');
      });

      test('comments use chat_bubble icon', () {
        final postComment = SocialActivity(
          id: '1',
          type: SocialActivityType.postComment,
          actorId: 'u1',
          targetUserId: 'u2',
          createdAt: DateTime.now(),
        );
        final commentReply = SocialActivity(
          id: '2',
          type: SocialActivityType.commentReply,
          actorId: 'u1',
          targetUserId: 'u2',
          createdAt: DateTime.now(),
        );

        expect(postComment.iconName, 'chat_bubble');
        expect(commentReply.iconName, 'chat_bubble');
      });

      test('mention uses alternate_email icon', () {
        final activity = SocialActivity(
          id: '1',
          type: SocialActivityType.mention,
          actorId: 'u1',
          targetUserId: 'u2',
          createdAt: DateTime.now(),
        );
        expect(activity.iconName, 'alternate_email');
      });
    });

    test('equality is based on id', () {
      final activity1 = SocialActivity(
        id: 'activity-1',
        type: SocialActivityType.follow,
        actorId: 'user-1',
        targetUserId: 'user-2',
        createdAt: DateTime(2024, 1, 1),
      );

      final activity2 = SocialActivity(
        id: 'activity-1',
        type: SocialActivityType.postLike, // Different type
        actorId: 'user-3', // Different actor
        targetUserId: 'user-4',
        createdAt: DateTime(2024, 2, 1),
      );

      expect(activity1, equals(activity2));
      expect(activity1.hashCode, equals(activity2.hashCode));
    });
  });

  group('ActivityFeedState', () {
    test('initial state has correct defaults', () {
      const state = ActivityFeedState();
      expect(state.activities, isEmpty);
      expect(state.isLoading, false);
      expect(state.hasMore, true);
      expect(state.error, isNull);
      expect(state.unreadCount, 0);
    });

    test('copyWith creates modified copy', () {
      const state = ActivityFeedState();
      final updated = state.copyWith(isLoading: true, unreadCount: 5);

      expect(updated.isLoading, true);
      expect(updated.unreadCount, 5);
      expect(updated.activities, isEmpty); // Unchanged
    });

    test('copyWith preserves activities', () {
      final activities = [
        SocialActivity(
          id: 'activity-1',
          type: SocialActivityType.follow,
          actorId: 'user-1',
          targetUserId: 'user-2',
          createdAt: DateTime(2024, 1, 1),
        ),
      ];
      final state = ActivityFeedState(activities: activities, unreadCount: 1);
      final updated = state.copyWith(isLoading: true);

      expect(updated.activities, equals(activities));
      expect(updated.unreadCount, 1);
    });
  });
}
