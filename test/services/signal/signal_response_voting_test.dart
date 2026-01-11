import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/signal_service.dart';

/// Tests for SignalResponse voting logic
/// Note: These tests validate business logic independently of Firebase/SQLite
void main() {
  group('SignalResponse Voting', () {
    group('SignalResponse model', () {
      test('creates SignalResponse with default voting fields', () {
        final response = SignalResponse(
          id: 'response-1',
          signalId: 'signal-1',
          content: 'Test response',
          authorId: 'user-1',
          createdAt: DateTime(2024, 1, 1),
          expiresAt: DateTime(2024, 1, 2),
        );

        expect(response.id, 'response-1');
        expect(response.signalId, 'signal-1');
        expect(response.content, 'Test response');
        expect(response.score, 0);
        expect(response.upvoteCount, 0);
        expect(response.downvoteCount, 0);
        expect(response.replyCount, 0);
        expect(response.myVote, 0);
        expect(response.isDeleted, false);
        expect(response.depth, 0);
      });

      test('creates SignalResponse with voting fields', () {
        final response = SignalResponse(
          id: 'response-1',
          signalId: 'signal-1',
          content: 'Popular response',
          authorId: 'user-1',
          createdAt: DateTime(2024, 1, 1),
          expiresAt: DateTime(2024, 1, 2),
          score: 15,
          upvoteCount: 20,
          downvoteCount: 5,
          replyCount: 3,
          myVote: 1,
        );

        expect(response.score, 15);
        expect(response.upvoteCount, 20);
        expect(response.downvoteCount, 5);
        expect(response.replyCount, 3);
        expect(response.myVote, 1);
      });

      test('copyWith preserves voting fields when not specified', () {
        final original = SignalResponse(
          id: 'response-1',
          signalId: 'signal-1',
          content: 'Original',
          authorId: 'user-1',
          createdAt: DateTime(2024, 1, 1),
          expiresAt: DateTime(2024, 1, 2),
          score: 10,
          upvoteCount: 15,
          downvoteCount: 5,
          replyCount: 2,
          myVote: 1,
          isDeleted: false,
        );

        final modified = original.copyWith(content: 'Modified');

        expect(modified.content, 'Modified');
        expect(modified.score, 10);
        expect(modified.upvoteCount, 15);
        expect(modified.downvoteCount, 5);
        expect(modified.replyCount, 2);
        expect(modified.myVote, 1);
        expect(modified.isDeleted, false);
      });

      test('copyWith updates voting fields correctly', () {
        final original = SignalResponse(
          id: 'response-1',
          signalId: 'signal-1',
          content: 'Test',
          authorId: 'user-1',
          createdAt: DateTime(2024, 1, 1),
          expiresAt: DateTime(2024, 1, 2),
          score: 0,
          upvoteCount: 0,
          downvoteCount: 0,
        );

        // Simulate upvote
        final afterUpvote = original.copyWith(
          score: 1,
          upvoteCount: 1,
          myVote: 1,
        );

        expect(afterUpvote.score, 1);
        expect(afterUpvote.upvoteCount, 1);
        expect(afterUpvote.downvoteCount, 0);
        expect(afterUpvote.myVote, 1);

        // Simulate changing to downvote
        final afterDownvote = afterUpvote.copyWith(
          score: -1,
          upvoteCount: 0,
          downvoteCount: 1,
          myVote: -1,
        );

        expect(afterDownvote.score, -1);
        expect(afterDownvote.upvoteCount, 0);
        expect(afterDownvote.downvoteCount, 1);
        expect(afterDownvote.myVote, -1);
      });

      test('displayContent returns content when not deleted', () {
        final response = SignalResponse(
          id: 'response-1',
          signalId: 'signal-1',
          content: 'Visible content',
          authorId: 'user-1',
          createdAt: DateTime(2024, 1, 1),
          expiresAt: DateTime(2024, 1, 2),
          isDeleted: false,
        );

        expect(response.displayContent, 'Visible content');
      });

      test('displayContent returns [deleted] when soft deleted', () {
        final response = SignalResponse(
          id: 'response-1',
          signalId: 'signal-1',
          content: 'This should be hidden',
          authorId: 'user-1',
          createdAt: DateTime(2024, 1, 1),
          expiresAt: DateTime(2024, 1, 2),
          isDeleted: true,
        );

        expect(response.displayContent, '[deleted]');
      });

      test('isExpired returns correct value', () {
        final notExpired = SignalResponse(
          id: 'response-1',
          signalId: 'signal-1',
          content: 'Active response',
          authorId: 'user-1',
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        final expired = SignalResponse(
          id: 'response-2',
          signalId: 'signal-1',
          content: 'Expired response',
          authorId: 'user-1',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );

        expect(notExpired.isExpired, false);
        expect(expired.isExpired, true);
      });

      test('depth is correctly set for threaded replies', () {
        final rootResponse = SignalResponse(
          id: 'response-1',
          signalId: 'signal-1',
          content: 'Root response',
          authorId: 'user-1',
          createdAt: DateTime(2024, 1, 1),
          expiresAt: DateTime(2024, 1, 2),
          depth: 0,
        );

        final replyLevel1 = SignalResponse(
          id: 'response-2',
          signalId: 'signal-1',
          content: 'Reply level 1',
          authorId: 'user-2',
          parentId: 'response-1',
          createdAt: DateTime(2024, 1, 1),
          expiresAt: DateTime(2024, 1, 2),
          depth: 1,
        );

        final replyLevel2 = SignalResponse(
          id: 'response-3',
          signalId: 'signal-1',
          content: 'Reply level 2',
          authorId: 'user-3',
          parentId: 'response-2',
          createdAt: DateTime(2024, 1, 1),
          expiresAt: DateTime(2024, 1, 2),
          depth: 2,
        );

        expect(rootResponse.depth, 0);
        expect(rootResponse.parentId, isNull);
        expect(replyLevel1.depth, 1);
        expect(replyLevel1.parentId, 'response-1');
        expect(replyLevel2.depth, 2);
        expect(replyLevel2.parentId, 'response-2');
      });
    });

    group('ResponseVote model', () {
      test('creates ResponseVote with upvote', () {
        final vote = ResponseVote(
          responseId: 'response-1',
          signalId: 'signal-1',
          voterId: 'user-1',
          value: 1,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        expect(vote.responseId, 'response-1');
        expect(vote.signalId, 'signal-1');
        expect(vote.voterId, 'user-1');
        expect(vote.value, 1);
      });

      test('creates ResponseVote with downvote', () {
        final vote = ResponseVote(
          responseId: 'response-1',
          signalId: 'signal-1',
          voterId: 'user-2',
          value: -1,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        expect(vote.value, -1);
      });

      test('toFirestore serializes correctly', () {
        final vote = ResponseVote(
          responseId: 'response-1',
          signalId: 'signal-1',
          voterId: 'user-1',
          value: 1,
          createdAt: DateTime(2024, 1, 1, 12, 0),
          updatedAt: DateTime(2024, 1, 1, 13, 0),
        );

        final map = vote.toFirestore();

        expect(map['value'], 1);
        expect(map['createdAt'], isNotNull);
        expect(map['updatedAt'], isNotNull);
      });
    });

    group('Vote calculation logic', () {
      test('score equals upvotes minus downvotes', () {
        // 10 upvotes, 3 downvotes = score of 7
        final response = SignalResponse(
          id: 'response-1',
          signalId: 'signal-1',
          content: 'Test',
          authorId: 'user-1',
          createdAt: DateTime(2024, 1, 1),
          expiresAt: DateTime(2024, 1, 2),
          upvoteCount: 10,
          downvoteCount: 3,
          score: 7,
        );

        expect(response.score, response.upvoteCount - response.downvoteCount);
      });

      test('negative score when downvotes exceed upvotes', () {
        final response = SignalResponse(
          id: 'response-1',
          signalId: 'signal-1',
          content: 'Controversial',
          authorId: 'user-1',
          createdAt: DateTime(2024, 1, 1),
          expiresAt: DateTime(2024, 1, 2),
          upvoteCount: 2,
          downvoteCount: 8,
          score: -6,
        );

        expect(response.score, -6);
        expect(response.score < 0, true);
      });

      test('myVote values are valid', () {
        // Valid values: -1 (downvote), 0 (no vote), 1 (upvote)
        final noVote = SignalResponse(
          id: 'r1',
          signalId: 's1',
          content: 'Test',
          authorId: 'u1',
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          myVote: 0,
        );

        final upvoted = noVote.copyWith(myVote: 1);
        final downvoted = noVote.copyWith(myVote: -1);

        expect(noVote.myVote, 0);
        expect(upvoted.myVote, 1);
        expect(downvoted.myVote, -1);
      });
    });

    group('Firestore serialization', () {
      test('toFirestore includes depth and parentId but not vote counts', () {
        // Note: Vote counts (score, upvoteCount, etc.) are maintained by Cloud Functions
        // Client should NOT write these fields - they're managed server-side
        final response = SignalResponse(
          id: 'response-1',
          signalId: 'signal-1',
          content: 'Test content',
          authorId: 'user-1',
          authorName: 'Test User',
          parentId: 'parent-1',
          depth: 2,
          createdAt: DateTime(2024, 1, 1, 12, 0),
          expiresAt: DateTime(2024, 1, 2, 12, 0),
          score: 5,
          upvoteCount: 7,
          downvoteCount: 2,
          replyCount: 3,
          isDeleted: false,
        );

        final map = response.toFirestore();

        // These fields should be serialized (client-writable)
        expect(map['content'], 'Test content');
        expect(map['authorId'], 'user-1');
        expect(map['authorName'], 'Test User');
        expect(map['signalId'], 'signal-1');
        expect(map['parentId'], 'parent-1');
        expect(map['depth'], 2);
        expect(map['isDeleted'], false);

        // Vote counts should NOT be serialized (Cloud Functions only)
        expect(map.containsKey('score'), false);
        expect(map.containsKey('upvoteCount'), false);
        expect(map.containsKey('downvoteCount'), false);
        expect(map.containsKey('replyCount'), false);
      });

      test('toFirestore omits null parentId', () {
        final rootResponse = SignalResponse(
          id: 'response-1',
          signalId: 'signal-1',
          content: 'Root response',
          authorId: 'user-1',
          createdAt: DateTime(2024, 1, 1),
          expiresAt: DateTime(2024, 1, 2),
        );

        final map = rootResponse.toFirestore();

        // parentId should be omitted when null (using conditional field)
        expect(map.containsKey('parentId'), false);
        expect(map['depth'], 0);
      });

      test('fromFirestore parses voting fields correctly', () {
        // Simulate a Firestore document with all fields
        final firestoreData = {
          'signalId': 'signal-1',
          'content': 'Test content',
          'authorId': 'user-1',
          'authorName': 'Test User',
          'parentId': 'parent-1',
          'depth': 2,
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1, 12, 0)),
          'expiresAt': Timestamp.fromDate(DateTime(2024, 1, 2, 12, 0)),
          'score': 5,
          'upvoteCount': 7,
          'downvoteCount': 2,
          'replyCount': 3,
          'isDeleted': false,
        };

        final response = SignalResponse.fromFirestore(
          'response-1',
          firestoreData,
        );

        expect(response.id, 'response-1');
        expect(response.signalId, 'signal-1');
        expect(response.content, 'Test content');
        expect(response.authorId, 'user-1');
        expect(response.parentId, 'parent-1');
        expect(response.depth, 2);
        expect(response.score, 5);
        expect(response.upvoteCount, 7);
        expect(response.downvoteCount, 2);
        expect(response.replyCount, 3);
        expect(response.isDeleted, false);
        expect(response.isLocal, false); // fromFirestore sets isLocal to false
      });

      test('fromFirestore uses defaults for missing voting fields', () {
        // Simulate an older Firestore document without voting fields
        final firestoreData = {
          'signalId': 'signal-1',
          'content': 'Old content',
          'authorId': 'user-1',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
          'expiresAt': Timestamp.fromDate(DateTime(2024, 1, 2)),
        };

        final response = SignalResponse.fromFirestore(
          'response-1',
          firestoreData,
        );

        expect(response.depth, 0);
        expect(response.score, 0);
        expect(response.upvoteCount, 0);
        expect(response.downvoteCount, 0);
        expect(response.replyCount, 0);
        expect(response.isDeleted, false);
        expect(response.parentId, isNull);
      });
    });
  });
}
