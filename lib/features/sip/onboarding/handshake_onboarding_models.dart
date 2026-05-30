// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Declarative page model for the Handshake onboarding flow.
//
// Each page is data, not a hand-rolled widget tree. The screen builds a list
// of [HandshakeOnboardingPageData] from localized strings and hands it to a
// single generic renderer. Adding, reordering, or re-copying a page is a data
// edit, not a layout rewrite.

import 'package:flutter/material.dart';

/// Which ambient visual / interaction a page renders behind its copy. The
/// generic page renderer switches on this to pick the matching animation
/// layer from the onboarding animation toolkit.
enum HandshakeVisual {
  /// Drifting mesh field with a brighter central node (welcome).
  welcome,

  /// Two peer cards with a pulse travelling between them. Interactive: the
  /// user taps Accept to light the link.
  handshake,

  /// Radar sweep with discovery blips drifting in and out.
  discovery,

  /// Plaintext characters dissolving into encrypted particles + a lock.
  messaging,

  /// Animated ink stroke that reconstructs on a second surface. Interactive:
  /// the user can draw a short stroke themselves.
  sketch,

  /// Playful peer-to-peer game motifs drifting between two nodes.
  games,

  /// Morse dot/dash ripples propagating across nodes. Interactive: the user
  /// taps to emit pulses.
  morse,

  /// Peer card expanding to reveal shared services.
  services,
}

/// A single capability chip in a page's optional feature row.
class HandshakeFeature {
  const HandshakeFeature({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Fully-resolved data for one onboarding page. All strings are already
/// localized by the screen before construction.
class HandshakeOnboardingPageData {
  const HandshakeOnboardingPageData({
    required this.visual,
    required this.accent,
    required this.headline,
    required this.body,
    required this.cta,
    this.highlightTitle,
    this.highlightBody,
    this.features = const [],
    this.tagline,
    this.interactiveHint,
  });

  /// Ambient visual / interaction for this page.
  final HandshakeVisual visual;

  /// Page accent colour (from AccentColors). Drives the backdrop tint, the
  /// page dots, and the primary button gradient on this page.
  final Color accent;

  final String headline;
  final String body;

  /// Label for the bottom primary button on this page.
  final String cta;

  /// Optional emphasis card under the body (e.g. the consent reassurance).
  final String? highlightTitle;
  final String? highlightBody;

  /// Optional row of capability chips.
  final List<HandshakeFeature> features;

  /// Optional short tagline shown beneath the body.
  final String? tagline;

  /// Optional one-line prompt inviting the user to try the interaction
  /// (e.g. "Tap Accept", "Draw something"). Only set on interactive pages.
  final String? interactiveHint;

  /// Whether this page carries a hands-on interaction the user can perform.
  bool get isInteractive =>
      visual == HandshakeVisual.handshake ||
      visual == HandshakeVisual.sketch ||
      visual == HandshakeVisual.morse;
}
