// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Generic renderer for one Handshake onboarding page.
//
// Takes a [HandshakeOnboardingPageData] and draws the matching focal visual
// (from the onboarding animation toolkit) above the headline, body, and any
// optional highlight card / feature row / tagline. The screen drives which
// page is [active] so offscreen pages pause their animations.

import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme.dart';
import '../animation/morse_dash.dart';
import '../animation/particle_stream.dart';
import '../animation/pulse_link.dart';
import '../animation/radar_sweep.dart';
import '../animation/sketch_stroke.dart';
import '../handshake_onboarding_models.dart';
import 'handshake_feature_row.dart';
import 'handshake_highlight_card.dart';

/// Renders a single content page of the onboarding flow.
class HandshakeOnboardingPage extends StatelessWidget {
  const HandshakeOnboardingPage({
    super.key,
    required this.data,
    required this.active,
    this.onInteract,
  });

  final HandshakeOnboardingPageData data;

  /// Whether this is the page currently on screen (drives animation pausing).
  final bool active;

  /// Fired when the user performs the page's hands-on interaction (haptics).
  final VoidCallback? onInteract;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing24,
            vertical: AppTheme.spacing16,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - AppTheme.spacing32,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildVisual(context),
                const SizedBox(height: AppTheme.spacing24),
                Text(
                  data.headline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing12),
                Text(
                  data.body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
                if (data.visual == HandshakeVisual.handshake &&
                    data.interactiveHint != null) ...[
                  const SizedBox(height: AppTheme.spacing12),
                  _hint(context, data.interactiveHint!),
                ],
                if (data.highlightTitle != null &&
                    data.highlightBody != null) ...[
                  const SizedBox(height: AppTheme.spacing20),
                  HandshakeHighlightCard(
                    accent: data.accent,
                    title: data.highlightTitle!,
                    body: data.highlightBody!,
                  ),
                ],
                if (data.features.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacing20),
                  HandshakeFeatureRow(
                    accent: data.accent,
                    features: data.features,
                  ),
                ],
                if (data.tagline != null) ...[
                  const SizedBox(height: AppTheme.spacing16),
                  Text(
                    data.tagline!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: data.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _hint(BuildContext context, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.touch_app_outlined, size: 14, color: data.accent),
        const SizedBox(width: AppTheme.spacing6),
        Text(
          text,
          style: TextStyle(
            color: data.accent,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildVisual(BuildContext context) {
    final l10n = context.l10n;
    switch (data.visual) {
      case HandshakeVisual.welcome:
        return _BeaconVisual(accent: data.accent);
      case HandshakeVisual.handshake:
        return PulseLink(
          accent: data.accent,
          active: active,
          acceptLabel: l10n.handshakeOnboardingHandshakeAccept,
          connectedLabel: l10n.handshakeOnboardingHandshakeConnected,
          onAccept: onInteract,
        );
      case HandshakeVisual.discovery:
        return SizedBox(
          height: 200,
          child: RadarSweep(accent: data.accent, active: active),
        );
      case HandshakeVisual.messaging:
        return SizedBox(
          height: 120,
          child: ParticleStream(accent: data.accent, active: active),
        );
      case HandshakeVisual.sketch:
        return SketchStroke(
          accent: data.accent,
          hint: data.interactiveHint ?? '',
          onStroke: onInteract,
        );
      case HandshakeVisual.games:
        return _GamesVisual(accent: data.accent);
      case HandshakeVisual.morse:
        return MorseDash(
          accent: data.accent,
          active: active,
          hint: data.interactiveHint ?? '',
          onPulse: onInteract,
        );
      case HandshakeVisual.services:
        return _ServicesVisual(accent: data.accent);
    }
  }
}

/// Welcome focal: a calm glowing beacon over the shared backdrop.
class _BeaconVisual extends StatelessWidget {
  const _BeaconVisual({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.card,
            border: Border.all(
              color: accent.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.35),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Icon(Icons.hub_outlined, size: 40, color: accent),
        ),
      ),
    );
  }
}

/// Games focal: two peers and a game token between them.
class _GamesVisual extends StatelessWidget {
  const _GamesVisual({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _peer(context, Icons.person_outline),
          _connector(),
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.16),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Icon(Icons.sports_esports_outlined, size: 26, color: accent),
          ),
          _connector(),
          _peer(context, Icons.person_outline),
        ],
      ),
    );
  }

  Widget _peer(BuildContext context, IconData icon) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.card,
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Icon(icon, size: 22, color: accent),
    );
  }

  Widget _connector() {
    return Container(
      width: 28,
      height: 1.4,
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
      color: accent.withValues(alpha: 0.3),
    );
  }
}

/// Services focal: a peer card expanding to reveal shared services.
class _ServicesVisual extends StatelessWidget {
  const _ServicesVisual({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(AppTheme.spacing16),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius16),
            border: Border.all(color: accent.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.16),
                    ),
                    child: Icon(Icons.person_outline, size: 18, color: accent),
                  ),
                  const SizedBox(width: AppTheme.spacing10),
                  _bar(context, 90),
                ],
              ),
              const SizedBox(height: AppTheme.spacing12),
              _serviceRow(context, Icons.event_outlined),
              const SizedBox(height: AppTheme.spacing8),
              _serviceRow(context, Icons.dashboard_outlined),
              const SizedBox(height: AppTheme.spacing8),
              _serviceRow(context, Icons.handyman_outlined),
            ],
          ),
        ),
      ),
    );
  }

  Widget _serviceRow(BuildContext context, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spacing6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            color: accent.withValues(alpha: 0.12),
          ),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: AppTheme.spacing10),
        _bar(context, 120),
      ],
    );
  }

  Widget _bar(BuildContext context, double width) {
    return Container(
      width: width,
      height: 6,
      decoration: BoxDecoration(
        color: context.textTertiary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppTheme.radius3),
      ),
    );
  }
}
