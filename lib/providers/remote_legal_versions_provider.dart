// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/legal/legal_constants.dart';
import '../core/logging.dart';
import 'app_providers.dart';

/// Cache keys for the last-fetched remote legal document versions.
///
/// These are stored in [SharedPreferences] so that the effective versions
/// survive offline launches — if the user was once online and saw a newer
/// remote version, they will still be prompted even when offline.
const _cachedTermsKey = 'cached_remote_terms_version';
const _cachedPrivacyKey = 'cached_remote_privacy_version';

/// Firestore path: `app_config/legal_versions`.
const _collection = 'app_config';
const _document = 'legal_versions';

/// The effective legal document versions the user must accept.
///
/// This is computed as `max(hardcoded, remote)` — the hardcoded values in
/// [LegalConstants] serve as a floor that ships with every app release,
/// while the remote Firestore document can raise the bar server-side
/// without an app update.
class EffectiveLegalVersions {
  final String termsVersion;
  final String privacyVersion;

  const EffectiveLegalVersions({
    required this.termsVersion,
    required this.privacyVersion,
  });
}

/// Provider that resolves the effective legal document versions.
///
/// **Fetch strategy (offline-first):**
/// 1. Read `app_config/legal_versions` from Firestore (server preferred,
///    5-second timeout).
/// 2. On success, cache the remote versions in [SharedPreferences].
/// 3. On failure (offline / timeout), fall back to the SharedPreferences
///    cache from the last successful fetch.
/// 4. Return `max(hardcoded, remote-or-cache)` for each version.
///
/// The returned versions are used by [_AppRouter] and
/// [TermsAcceptanceNotifier.accept] to decide whether the consent gate
/// should appear and to record which version the user accepted.
final effectiveLegalVersionsProvider = FutureProvider<EffectiveLegalVersions>((
  ref,
) async {
  final settings = await ref.read(settingsServiceProvider.future);
  final prefs = settings.prefs;

  String? remoteTerms;
  String? remotePrivacy;

  // --- Phase 1: Try Firestore ------------------------------------------------
  try {
    final doc = await FirebaseFirestore.instance
        .collection(_collection)
        .doc(_document)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 5));

    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      remoteTerms = data['terms_version'] as String?;
      remotePrivacy = data['privacy_version'] as String?;

      // Cache for offline fallback
      if (remoteTerms != null) {
        await prefs.setString(_cachedTermsKey, remoteTerms);
      }
      if (remotePrivacy != null) {
        await prefs.setString(_cachedPrivacyKey, remotePrivacy);
      }

      AppLogging.auth(
        'remote legal versions fetched: '
        'terms=$remoteTerms, privacy=$remotePrivacy',
      );
    }
  } catch (e) {
    AppLogging.auth('remote legal versions fetch failed: $e');
  }

  // --- Phase 2: Fall back to cache -------------------------------------------
  remoteTerms ??= prefs.getString(_cachedTermsKey);
  remotePrivacy ??= prefs.getString(_cachedPrivacyKey);

  // --- Phase 3: Resolve effective = max(hardcoded, remote) -------------------
  final effectiveTerms = _maxVersion(LegalConstants.termsVersion, remoteTerms);
  final effectivePrivacy = _maxVersion(
    LegalConstants.privacyVersion,
    remotePrivacy,
  );

  AppLogging.auth(
    'effective legal versions: '
    'terms=$effectiveTerms, privacy=$effectivePrivacy',
  );

  return EffectiveLegalVersions(
    termsVersion: effectiveTerms,
    privacyVersion: effectivePrivacy,
  );
});

/// Returns the later of two YYYY-MM-DD version strings.
///
/// If [remote] is null or not a valid version date, returns [hardcoded].
String _maxVersion(String hardcoded, String? remote) {
  if (remote == null || !LegalConstants.isValidVersion(remote)) {
    return hardcoded;
  }
  // String comparison works for YYYY-MM-DD format (ISO-8601 date).
  return remote.compareTo(hardcoded) > 0 ? remote : hardcoded;
}
