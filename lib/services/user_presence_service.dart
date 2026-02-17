// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/core/logging.dart';
import '../providers/auth_providers.dart';

/// Service to manage user online/offline presence in Firestore
class UserPresenceService {
  final FirebaseFirestore _firestore;
  final String? _userId;

  UserPresenceService(this._firestore, this._userId);

  /// Start tracking user presence (call when app becomes active)
  Future<void> setOnline() async {
    if (_userId == null) {
      AppLogging.auth('🟢 setOnline: No user ID, skipping');
      return;
    }

    AppLogging.auth('🟢 setOnline: Setting user $_userId online...');
    try {
      await _firestore.collection('presence').doc(_userId).set({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      AppLogging.auth('🟢 setOnline: Success for $_userId');
    } catch (e) {
      AppLogging.auth('🟢 setOnline: Error - $e');
    }
  }

  /// Stop tracking user presence (call when app goes to background)
  Future<void> setOffline() async {
    if (_userId == null) return;

    AppLogging.auth('🔴 setOffline: Setting user $_userId offline...');
    try {
      await _firestore.collection('presence').doc(_userId).set({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      AppLogging.auth('🔴 setOffline: Success for $_userId');
    } catch (e) {
      AppLogging.auth('🔴 setOffline: Error - $e');
    }
  }

  /// Stream of user's online status
  Stream<bool> userOnlineStatus(String userId) {
    return _firestore
        .collection('presence')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return false;

          final data = snapshot.data();
          if (data == null) return false;

          final isOnline = data['isOnline'] as bool? ?? false;
          final lastSeen = data['lastSeen'] as Timestamp?;

          // Consider online if marked online AND last seen within 5 minutes
          if (!isOnline) return false;
          if (lastSeen == null) return false;

          final lastSeenDate = lastSeen.toDate();
          final now = DateTime.now();
          final difference = now.difference(lastSeenDate);

          return difference.inMinutes < 5;
        })
        .handleError((Object e) {
          AppLogging.auth('User presence stream error: $e');
        });
  }
}

/// Provider for user presence service
final userPresenceServiceProvider = Provider<UserPresenceService>((ref) {
  final firestore = FirebaseFirestore.instance;
  final user = ref.watch(currentUserProvider);
  return UserPresenceService(firestore, user?.uid);
});

/// Provider for checking if a specific user is online
final userOnlineStatusProvider = StreamProvider.family<bool, String>((
  ref,
  userId,
) {
  final service = ref.watch(userPresenceServiceProvider);
  return service.userOnlineStatus(userId);
});
