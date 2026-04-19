// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/voice/voice_constants.dart';

/// Provides the user's selected [VoiceQuality], persisted in SharedPreferences.
///
/// Usage:
/// ```dart
/// final quality = ref.watch(voiceQualityProvider);
/// ref.read(voiceQualityProvider.notifier).setQuality(VoiceQuality.high);
/// ```
class VoiceQualityNotifier extends Notifier<VoiceQuality> {
  @override
  VoiceQuality build() {
    _loadFromPrefs();
    return VoiceConstants.defaultQuality;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(VoiceConstants.qualityPrefsKey);
    final quality = VoiceQuality.fromPrefsValue(stored);
    if (quality != state) {
      state = quality;
    }
  }

  Future<void> setQuality(VoiceQuality quality) async {
    state = quality;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(VoiceConstants.qualityPrefsKey, quality.prefsValue);
  }
}

final voiceQualityProvider =
    NotifierProvider<VoiceQualityNotifier, VoiceQuality>(
      VoiceQualityNotifier.new,
    );
