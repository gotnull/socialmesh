// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging.dart';
import 'auth_providers.dart';

/// Enum for signal view modes
enum SignalViewMode { list, grid, gallery, map }

/// Provider for the current signal view mode with persistence
final signalViewModeProvider =
    NotifierProvider<SignalViewModeNotifier, SignalViewMode>(
      SignalViewModeNotifier.new,
    );

class SignalViewModeNotifier extends Notifier<SignalViewMode> {
  static const _prefKey = 'signal_view_mode';

  @override
  SignalViewMode build() {
    _loadFromPrefs();
    return SignalViewMode.list;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefKey);
      if (stored != null) {
        final mode = SignalViewMode.values.firstWhere(
          (m) => m.name == stored,
          orElse: () => SignalViewMode.list,
        );
        state = mode;
      }
    } catch (e) {
      AppLogging.social('Failed to load view mode: $e');
    }
  }

  Future<void> setMode(SignalViewMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode.name);
    } catch (e) {
      AppLogging.social('Failed to save view mode: $e');
    }
  }
}

/// Provider for bookmarked signal IDs
final signalBookmarksProvider =
    AsyncNotifierProvider<SignalBookmarksNotifier, Set<String>>(
      SignalBookmarksNotifier.new,
    );

class SignalBookmarksNotifier extends AsyncNotifier<Set<String>> {
  StreamSubscription<QuerySnapshot>? _subscription;

  @override
  Future<Set<String>> build() async {
    ref.onDispose(() {
      _subscription?.cancel();
    });

    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return {};
    }

    // Set up real-time listener
    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('saved_signals')
        .snapshots()
        .listen((snapshot) {
          state = AsyncData(snapshot.docs.map((d) => d.id).toSet());
        });

    // Return initial value from snapshot
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('saved_signals')
        .get();

    return snapshot.docs.map((d) => d.id).toSet();
  }

  Future<void> toggleBookmark(String signalId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final current = state.value ?? {};
    final isBookmarked = current.contains(signalId);

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('saved_signals')
        .doc(signalId);

    try {
      if (isBookmarked) {
        await docRef.delete();
        state = AsyncData({...current}..remove(signalId));
      } else {
        await docRef.set({
          'savedAt': FieldValue.serverTimestamp(),
          'signalId': signalId,
        });
        state = AsyncData({...current, signalId});
      }
    } catch (e) {
      AppLogging.social('Failed to toggle bookmark: $e');
    }
  }

  Future<void> addBookmark(String signalId) async {
    final current = state.value ?? {};
    if (current.contains(signalId)) return;
    await toggleBookmark(signalId);
  }

  Future<void> removeBookmark(String signalId) async {
    final current = state.value ?? {};
    if (!current.contains(signalId)) return;
    await toggleBookmark(signalId);
  }
}

/// Check if a specific signal is bookmarked
final isSignalBookmarkedProvider = Provider.family<bool, String>((
  ref,
  signalId,
) {
  final bookmarks = ref.watch(signalBookmarksProvider).value ?? {};
  return bookmarks.contains(signalId);
});

/// Provider for hidden signal IDs (local only, not synced)
final hiddenSignalsProvider =
    NotifierProvider<HiddenSignalsNotifier, Set<String>>(
      HiddenSignalsNotifier.new,
    );

class HiddenSignalsNotifier extends Notifier<Set<String>> {
  static const _prefKey = 'hidden_signals';

  @override
  Set<String> build() {
    _loadFromPrefs();
    return {};
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_prefKey);
      if (stored != null) {
        state = stored.toSet();
      }
    } catch (e) {
      AppLogging.social('Failed to load hidden signals: $e');
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefKey, state.toList());
    } catch (e) {
      AppLogging.social('Failed to save hidden signals: $e');
    }
  }

  Future<void> hideSignal(String signalId) async {
    state = {...state, signalId};
    await _saveToPrefs();
  }

  Future<void> unhideSignal(String signalId) async {
    state = {...state}..remove(signalId);
    await _saveToPrefs();
  }

  bool isHidden(String signalId) => state.contains(signalId);

  Future<void> clearAll() async {
    state = {};
    await _saveToPrefs();
  }
}

/// Record a signal view for statistics
Future<void> recordSignalView(String signalId, String? viewerId) async {
  if (viewerId == null) return;

  try {
    final viewerDocRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(signalId)
        .collection('viewers')
        .doc(viewerId);

    // Use set with merge to only record first view
    await viewerDocRef.set({
      'viewedAt': FieldValue.serverTimestamp(),
      'viewerId': viewerId,
    }, SetOptions(merge: true));

    // Increment view count on the stats document
    final statsRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(signalId)
        .collection('stats')
        .doc('views');

    await statsRef.set({
      'count': FieldValue.increment(1),
      'lastViewedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  } catch (e) {
    AppLogging.social('Failed to record signal view: $e');
  }
}

/// Provider for signal view count
final signalViewCountProvider = StreamProvider.family<int, String>((
  ref,
  signalId,
) {
  return FirebaseFirestore.instance
      .collection('posts')
      .doc(signalId)
      .collection('stats')
      .doc('views')
      .snapshots()
      .map((doc) => doc.data()?['count'] as int? ?? 0);
});
