// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

import '../../utils/emoji_text.dart';
import '../theme.dart';

// Body font size for [text], enlarged for emoji-only messages ("jumbomoji"):
// 1/2/3 emoji render at progressively smaller jumbo sizes; 0 (has text) or 4+
// emoji fall back to [baseFontSize], matching common messengers. The user's
// accessibility text-size preference still applies app-wide via
// MediaQuery.textScaler, so the returned value is the unscaled baseline.
double chatBubbleFontSize(String text, {required double baseFontSize}) {
  switch (emojiOnlyCount(text)) {
    case 1:
      return AppTheme.fontSizeEmoji1;
    case 2:
      return AppTheme.fontSizeEmoji2;
    case 3:
      return AppTheme.fontSizeEmoji3;
    default:
      return baseFontSize;
  }
}

// Canonical body-text style for chat bubbles. Each surface picks its own
// baseline (SIP DM + Meshtastic outgoing use 14, incoming uses 15); using
// one helper keeps incoming and outgoing bubbles symmetrical.
//
// The user's accessibility text-size preference is applied app-wide via
// MediaQuery.textScaler (see main.dart), so the size passed here is the
// unscaled baseline; the render layer scales it for every Text uniformly.
// Multiplying here again would double-scale.
//
// This is purely a render-time helper: it does NOT affect message
// payloads, wire format, persistence, or anything visible to the peer.
TextStyle chatBubbleBodyStyle({
  required double baseFontSize,
  Color? color,
  FontWeight? fontWeight,
}) {
  return TextStyle(
    fontSize: baseFontSize,
    color: color,
    fontWeight: fontWeight,
  );
}
