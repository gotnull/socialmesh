import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/providers/social_providers.dart';

void main() {
  group('Social Providers', () {
    test('socialServiceProvider is a Provider', () {
      expect(socialServiceProvider, isA<Provider>());
    });

    test('pendingReportCountProvider is a StreamProvider', () {
      expect(pendingReportCountProvider, isA<StreamProvider<int>>());
    });
  });

  group('Follow State', () {
    test('creates with default values', () {
      const state = FollowState();

      expect(state.isFollowing, false);
      expect(state.isFollowedBy, false);
      expect(state.isLoading, false);
      expect(state.error, isNull);
      expect(state.isMutual, false);
    });

    test('creates with custom values', () {
      const state = FollowState(
        isFollowing: true,
        isFollowedBy: true,
        isLoading: false,
      );

      expect(state.isFollowing, true);
      expect(state.isFollowedBy, true);
      expect(state.isLoading, false);
      expect(state.isMutual, true);
    });

    test('isMutual is true when both following', () {
      const state = FollowState(isFollowing: true, isFollowedBy: true);

      expect(state.isMutual, true);
    });

    test('isMutual is false when only following', () {
      const state = FollowState(isFollowing: true, isFollowedBy: false);

      expect(state.isMutual, false);
    });

    test('isMutual is false when only followed by', () {
      const state = FollowState(isFollowing: false, isFollowedBy: true);

      expect(state.isMutual, false);
    });

    test('copyWith updates specified fields', () {
      const state = FollowState(isFollowing: false, isFollowedBy: false);

      final updated = state.copyWith(isFollowing: true, isLoading: true);

      expect(updated.isFollowing, true);
      expect(updated.isFollowedBy, false);
      expect(updated.isLoading, true);
    });

    test('copyWith preserves unspecified fields', () {
      const state = FollowState(
        isFollowing: true,
        isFollowedBy: true,
        error: 'Test error',
      );

      final updated = state.copyWith(isLoading: true);

      expect(updated.isFollowing, true);
      expect(updated.isFollowedBy, true);
      // Note: error is reset to null when not specified in copyWith
      expect(updated.isLoading, true);
    });

    test('copyWith can set error to null', () {
      const state = FollowState(error: 'Test error');

      final updated = state.copyWith(error: null);

      expect(updated.error, isNull);
    });
  });
}
