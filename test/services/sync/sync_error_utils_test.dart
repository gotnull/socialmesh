// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/sync/sync_error_utils.dart';

void main() {
  group('isCloudSyncPermissionDenied', () {
    test('true for a Firestore permission-denied FirebaseException', () {
      final error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions.',
      );
      expect(isCloudSyncPermissionDenied(error), isTrue);
    });

    test('false for other FirebaseException codes', () {
      final error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      expect(isCloudSyncPermissionDenied(error), isFalse);
    });

    test('false for non-Firebase errors', () {
      expect(isCloudSyncPermissionDenied(Exception('boom')), isFalse);
      expect(isCloudSyncPermissionDenied('permission-denied'), isFalse);
      expect(isCloudSyncPermissionDenied(StateError('x')), isFalse);
    });
  });
}
