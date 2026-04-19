// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'voice_constants.dart';

/// Utilities for detecting and describing voice message MIME types.
abstract final class VoiceMime {
  /// Returns true when [mimeType] represents a Codec2 voice message.
  static bool isVoiceMessage(String? mimeType) =>
      mimeType == VoiceConstants.mimeType;

  /// Returns true when [filename] has the `.c2` voice message extension.
  static bool hasVoiceExtension(String? filename) =>
      filename?.endsWith(VoiceConstants.fileExtension) ?? false;

  /// Generates a timestamped voice message filename.
  static String generateFilename() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '${VoiceConstants.filenamePrefix}$ts${VoiceConstants.fileExtension}';
  }
}
