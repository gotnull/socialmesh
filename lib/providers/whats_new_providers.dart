// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging.dart';
import '../core/whats_new/whats_new_registry.dart';

/// Preference key storing the last version whose What's New popup was dismissed.
const _prefLastSeenVersion = 'whatsNew.lastSeenVersion';

/// Preference key storing badge keys for new features that the user
/// has not yet visited. These persist independently of popup dismissal
/// so that drawer NEW chips remain visible until the user actually
/// navigates to the feature.
const _prefFeatureBadgeKeys = 'whatsNew.featureBadgeKeys';

/// State exposed by [WhatsNewNotifier].
class WhatsNewState {
  /// The pending payload to show, or null when nothing is pending.
  final WhatsNewPayload? pendingPayload;

  /// Badge keys from new features the user has not yet visited.
  /// Used by the drawer to decide which items display a NEW chip
  /// and by the hamburger button to show a dot indicator.
  ///
  /// These persist independently of popup dismissal — clearing them
  /// requires an explicit [WhatsNewNotifier.dismissBadgeKey] call,
  /// which happens when the user navigates to the corresponding
  /// drawer item.
  final Set<String> unseenBadgeKeys;

  /// Whether the What's New sheet has already been presented this session.
  /// Prevents the popup from reappearing on widget rebuilds.
  final bool shownThisSession;

  /// Whether the initial load from preferences has completed.
  final bool isLoaded;

  const WhatsNewState({
    this.pendingPayload,
    this.unseenBadgeKeys = const {},
    this.shownThisSession = false,
    this.isLoaded = false,
  });

  WhatsNewState copyWith({
    WhatsNewPayload? pendingPayload,
    bool clearPendingPayload = false,
    Set<String>? unseenBadgeKeys,
    bool? shownThisSession,
    bool? isLoaded,
  }) {
    return WhatsNewState(
      pendingPayload: clearPendingPayload
          ? null
          : (pendingPayload ?? this.pendingPayload),
      unseenBadgeKeys: unseenBadgeKeys ?? this.unseenBadgeKeys,
      shownThisSession: shownThisSession ?? this.shownThisSession,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }

  /// Convenience: true when there is a payload the user has not yet dismissed.
  bool get hasPending => pendingPayload != null;

  /// Returns true if [badgeKey] is in the unseen set.
  bool isBadgeKeyUnseen(String badgeKey) => unseenBadgeKeys.contains(badgeKey);

  /// True when there are any unseen badge keys (used by hamburger button).
  bool get hasUnseenBadgeKeys => unseenBadgeKeys.isNotEmpty;

  static const WhatsNewState initial = WhatsNewState();
}

/// Notifier that manages the What's New lifecycle.
///
/// On [build] it loads the last-seen version from SharedPreferences,
/// resolves the current app version, and computes pending payloads and
/// unseen badge keys via [WhatsNewRegistry].
///
/// Badge keys are decoupled from popup dismissal:
/// - [markSeen] persists the popup version but keeps badge keys intact.
/// - [dismissBadgeKey] removes an individual badge key when the user
///   navigates to the corresponding feature.
class WhatsNewNotifier extends Notifier<WhatsNewState> {
  @override
  WhatsNewState build() {
    _loadState();
    return WhatsNewState.initial;
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final lastSeen = prefs.getString(_prefLastSeenVersion);

      // --- Popup payload ---
      final pending = WhatsNewRegistry.getPendingPayload(
        currentVersion: currentVersion,
        lastSeenVersion: lastSeen,
      );

      // --- Badge keys (persisted independently) ---
      // Load existing badge keys the user has NOT yet visited.
      final storedKeys = prefs.getStringList(_prefFeatureBadgeKeys);
      final featureBadgeKeys = storedKeys?.toSet() ?? <String>{};

      // If there is a pending (or new) payload, merge its badge keys
      // into the persisted set so newly introduced features are tracked.
      if (pending != null) {
        final newKeys = pending.badgeKeys;
        if (newKeys.isNotEmpty) {
          final merged = {...featureBadgeKeys, ...newKeys};
          if (merged.length != featureBadgeKeys.length) {
            await prefs.setStringList(_prefFeatureBadgeKeys, merged.toList());
            featureBadgeKeys.addAll(newKeys);
          }
        }
      }

      // For a brand-new install (lastSeen is null AND no stored keys),
      // do NOT seed badge keys — the popup will introduce the features.
      // Badge keys only accumulate once the user has seen at least one
      // popup OR when new payloads add keys on a version upgrade.

      state = state.copyWith(
        pendingPayload: pending,
        unseenBadgeKeys: featureBadgeKeys,
        isLoaded: true,
      );

      AppLogging.app(
        'WhatsNew: loaded — current=$currentVersion, lastSeen=$lastSeen, '
        'pending=${pending?.version}, badgeKeys=$featureBadgeKeys',
      );
    } catch (e) {
      AppLogging.app('WhatsNew: failed to load state: $e');
      state = state.copyWith(isLoaded: true);
    }
  }

  /// Marks the current pending popup as seen and persists the version.
  ///
  /// Call this when the user explicitly dismisses the What's New sheet.
  ///
  /// This does **not** clear [unseenBadgeKeys]. Badge keys persist
  /// until the user visits the corresponding feature via the drawer,
  /// at which point [dismissBadgeKey] should be called.
  Future<void> markSeen() async {
    final payload = state.pendingPayload;
    if (payload == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLastSeenVersion, payload.version);

      AppLogging.app('WhatsNew: marked seen — version=${payload.version}');

      // Clear the popup payload and mark session as shown,
      // but keep unseenBadgeKeys intact.
      state = state.copyWith(clearPendingPayload: true, shownThisSession: true);
    } catch (e) {
      AppLogging.app('WhatsNew: failed to persist seen version: $e');
    }
  }

  /// Removes a single badge key from the unseen set and persists
  /// the change.
  ///
  /// Call this when the user navigates to a drawer item that has
  /// a matching [whatsNewBadgeKey]. After this call the drawer
  /// NEW chip for [key] will no longer appear.
  Future<void> dismissBadgeKey(String key) async {
    final updated = Set<String>.from(state.unseenBadgeKeys)..remove(key);

    // Update state immediately for responsive UI
    state = state.copyWith(unseenBadgeKeys: updated);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefFeatureBadgeKeys, updated.toList());

      AppLogging.app('WhatsNew: dismissed badge key "$key"');
    } catch (e) {
      AppLogging.app('WhatsNew: failed to persist badge key dismissal: $e');
    }
  }

  /// Records that the sheet was already presented this session so the
  /// startup hook does not trigger it again on rebuilds.
  void markShownThisSession() {
    state = state.copyWith(shownThisSession: true);
  }

  /// Resets the last-seen version and all badge keys in preferences.
  /// Intended for testing and the Help Center's "Reset All" flow.
  Future<void> resetLastSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefLastSeenVersion);
      await prefs.remove(_prefFeatureBadgeKeys);
      AppLogging.app('WhatsNew: reset last seen version and badge keys');
      // Reload state to recompute pending/badge keys
      await _loadState();
      state = state.copyWith(shownThisSession: false);
    } catch (e) {
      AppLogging.app('WhatsNew: failed to reset: $e');
    }
  }
}

/// Central provider for What's New state.
final whatsNewProvider = NotifierProvider<WhatsNewNotifier, WhatsNewState>(
  WhatsNewNotifier.new,
);

/// Convenience provider that exposes only the unseen badge keys set.
/// Widgets that only care about drawer badge state can watch this
/// to avoid unnecessary rebuilds from other [WhatsNewState] changes.
final whatsNewUnseenBadgeKeysProvider = Provider<Set<String>>((ref) {
  return ref.watch(whatsNewProvider.select((s) => s.unseenBadgeKeys));
});

/// Convenience provider: true when any unseen badge keys exist.
/// Used by the hamburger menu button to show a dot indicator.
final whatsNewHasUnseenProvider = Provider<bool>((ref) {
  return ref.watch(
    whatsNewProvider.select((s) => s.unseenBadgeKeys.isNotEmpty),
  );
});
