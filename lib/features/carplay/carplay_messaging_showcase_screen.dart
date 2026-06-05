// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/safety.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/primary_gradient_button.dart';
import '../../core/widgets/section_header.dart';
import '../../services/haptic_service.dart';

/// A polished, animated feature reveal for CarPlay mesh messaging, opened from
/// the What's New registry (`/carplay`). Pure announcement UI: it links to no
/// live CarPlay wiring, it just showcases the capability. Accurate by design —
/// SiriKit-driven short-form messaging + the CarPlay channels/DMs list, framed
/// around Apple's CarPlay communication model (not VoIP, not a custom
/// dashboard).
class CarPlayMessagingShowcaseScreen extends ConsumerStatefulWidget {
  const CarPlayMessagingShowcaseScreen({super.key});

  @override
  ConsumerState<CarPlayMessagingShowcaseScreen> createState() =>
      _CarPlayMessagingShowcaseScreenState();
}

class _CarPlayMessagingShowcaseScreenState
    extends ConsumerState<CarPlayMessagingShowcaseScreen>
    with
        TickerProviderStateMixin,
        LifecycleSafeMixin<CarPlayMessagingShowcaseScreen> {
  // Drives the one-shot staggered entrance of every section.
  late final AnimationController _entrance;
  // Drives the looping ambient motion (hero glow + the flow-rail pulse).
  late final AnimationController _ambient;
  bool _reducedMotionApplied = false;

  @override
  void initState() {
    super.initState();
    AppLogging.carplay('Showcase opened (source=whats_new)');
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery is available here; honour reduce-motion exactly once.
    if (_reducedMotionApplied) return;
    _reducedMotionApplied = true;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _entrance.value = 1.0; // show final state, no movement
    } else {
      _entrance.forward();
      _ambient.repeat();
    }
  }

  @override
  void dispose() {
    AppLogging.carplay('Showcase closed');
    _entrance.dispose();
    _ambient.dispose();
    super.dispose();
  }

  void _onPrimaryCta() {
    ref.haptics.buttonTap();
    AppLogging.carplay('Showcase CTA tapped (action=dismiss)');
    safeNavigatorPop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GlassScaffold(
      title: l10n.carPlayShowcaseAppBarTitle,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing8,
            AppTheme.spacing16,
            AppTheme.spacing24,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _Reveal(
                controller: _entrance,
                start: 0.0,
                child: _HeroPanel(ambient: _ambient),
              ),
              const SizedBox(height: AppTheme.spacing24),
              _Reveal(
                controller: _entrance,
                start: 0.12,
                child: _FlowRail(ambient: _ambient),
              ),
              const SizedBox(height: AppTheme.spacing24),
              _Reveal(controller: _entrance, start: 0.22, child: _LeadCopy()),
              const SizedBox(height: AppTheme.spacing20),
              for (var i = 0; i < _featureCards.length; i++) ...[
                _Reveal(
                  controller: _entrance,
                  start: 0.30 + i * 0.07,
                  child: _FeatureCard(spec: _featureCards[i]),
                ),
                const SizedBox(height: AppTheme.spacing12),
              ],
              const SizedBox(height: AppTheme.spacing12),
              _Reveal(controller: _entrance, start: 0.70, child: _HowItWorks()),
              const SizedBox(height: AppTheme.spacing20),
              _Reveal(
                controller: _entrance,
                start: 0.80,
                child: _RealityCheck(),
              ),
              const SizedBox(height: AppTheme.spacing24),
              _Reveal(controller: _entrance, start: 0.88, child: _Footer()),
              const SizedBox(height: AppTheme.spacing24),
              _Reveal(
                controller: _entrance,
                start: 0.92,
                child: PrimaryGradientButton(
                  label: l10n.carPlayShowcaseCta,
                  icon: Icons.check_rounded,
                  onPressed: _onPrimaryCta,
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

// Accent for the whole surface — CarPlay blue (named constant lives in theme).
const Color _kCarPlayAccent = AppTheme.carPlayBlue;

// ===========================================================================
// Entrance reveal — staggered fade + rise driven by a shared controller.
// ===========================================================================

class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.controller,
    required this.start,
    required this.child,
  });

  final AnimationController controller;
  final double start;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(
        start.clamp(0.0, 1.0),
        math.min(start + 0.45, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        return Opacity(
          opacity: curved.value,
          child: Transform.translate(
            offset: Offset(0, (1 - curved.value) * AppTheme.spacing16),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

// ===========================================================================
// Hero panel — pulsing CarPlay glyph over a soft radial glow.
// ===========================================================================

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.ambient});

  final AnimationController ambient;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing24),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius24),
        border: Border.all(color: _kCarPlayAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: AnimatedBuilder(
              animation: ambient,
              builder: (context, child) {
                final t = (math.sin(ambient.value * 2 * math.pi) + 1) / 2;
                final glow = 0.18 + t * 0.22;
                final scale = 1.0 + t * 0.05;
                return Container(
                  width: AppTheme.spacing80,
                  height: AppTheme.spacing80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _kCarPlayAccent.withValues(alpha: glow),
                        _kCarPlayAccent.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Transform.scale(scale: scale, child: child),
                  ),
                );
              },
              child: Container(
                width: AppTheme.spacing48,
                height: AppTheme.spacing48,
                decoration: BoxDecoration(
                  color: _kCarPlayAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radius16),
                ),
                child: Icon(
                  Icons.directions_car_filled_outlined,
                  color: _kCarPlayAccent,
                  size: AppTheme.spacing28,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing20),
          Wrap(
            spacing: AppTheme.spacing8,
            runSpacing: AppTheme.spacing8,
            children: [
              _Pill(label: l10n.carPlayShowcaseBadgeMajor, accent: true),
              _Pill(label: l10n.carPlayShowcaseBadgeMessaging, accent: false),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            l10n.carPlayShowcaseTitle,
            style: context.headingStyle?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            l10n.carPlayShowcaseSubtitle,
            style: context.bodyStyle?.copyWith(color: context.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacing12),
          Row(
            children: [
              Icon(
                Icons.verified_outlined,
                size: AppTheme.spacing16,
                color: _kCarPlayAccent,
              ),
              const SizedBox(width: AppTheme.spacing6),
              Expanded(
                child: Text(
                  l10n.carPlayShowcaseHeroStatus,
                  style: context.captionStyle?.copyWith(
                    color: context.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.accent});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? _kCarPlayAccent : context.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing10,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label.toUpperCase(),
        style: context.captionStyle?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ===========================================================================
// Flow rail — four stages connected by a line with a travelling pulse.
// ===========================================================================

class _FlowRail extends StatelessWidget {
  const _FlowRail({required this.ambient});

  final AnimationController ambient;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stages = <(IconData, String)>[
      (Icons.mark_chat_unread_outlined, l10n.carPlayShowcaseFlowStep1),
      (Icons.mic_none_rounded, l10n.carPlayShowcaseFlowStep2),
      (Icons.settings_input_antenna_rounded, l10n.carPlayShowcaseFlowStep3),
      (Icons.done_all_rounded, l10n.carPlayShowcaseFlowStep4),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: l10n.carPlayShowcaseFlowTitle),
        SizedBox(
          height: AppTheme.spacing20,
          child: AnimatedBuilder(
            animation: ambient,
            builder: (context, _) => CustomPaint(
              painter: _FlowPainter(
                progress: ambient.value,
                lineColor: context.border,
                pulseColor: _kCarPlayAccent,
              ),
              size: Size.infinite,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacing8),
        Row(
          children: [
            for (var i = 0; i < stages.length; i++)
              Expanded(
                child: Column(
                  children: [
                    Icon(
                      stages[i].$1,
                      size: AppTheme.spacing20,
                      color: _kCarPlayAccent,
                    ),
                    const SizedBox(height: AppTheme.spacing6),
                    Text(
                      stages[i].$2,
                      textAlign: TextAlign.center,
                      style: context.captionStyle?.copyWith(
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _FlowPainter extends CustomPainter {
  _FlowPainter({
    required this.progress,
    required this.lineColor,
    required this.pulseColor,
  });

  final double progress;
  final Color lineColor;
  final Color pulseColor;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), line);

    // Travelling pulse left to right.
    final x = size.width * progress;
    final glow = Paint()
      ..color = pulseColor.withValues(alpha: 0.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(x, y), 5, glow);
    canvas.drawCircle(Offset(x, y), 3, Paint()..color = pulseColor);
  }

  @override
  bool shouldRepaint(_FlowPainter old) =>
      old.progress != progress ||
      old.lineColor != lineColor ||
      old.pulseColor != pulseColor;
}

// ===========================================================================
// Lead copy.
// ===========================================================================

class _LeadCopy extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.carPlayShowcaseLeadTitle,
          style: context.titleStyle?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppTheme.spacing8),
        Text(
          l10n.carPlayShowcaseLeadBody,
          style: context.bodySecondaryStyle?.copyWith(
            color: context.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Feature cards.
// ===========================================================================

class _FeatureSpec {
  const _FeatureSpec({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String Function(BuildContext) title;
  final String Function(BuildContext) body;
}

final List<_FeatureSpec> _featureCards = [
  _FeatureSpec(
    icon: Icons.send_rounded,
    title: (c) => c.l10n.carPlayShowcaseCardSendTitle,
    body: (c) => c.l10n.carPlayShowcaseCardSendBody,
  ),
  _FeatureSpec(
    icon: Icons.hearing_rounded,
    title: (c) => c.l10n.carPlayShowcaseCardHearTitle,
    body: (c) => c.l10n.carPlayShowcaseCardHearBody,
  ),
  _FeatureSpec(
    icon: Icons.done_all_rounded,
    title: (c) => c.l10n.carPlayShowcaseCardMarkTitle,
    body: (c) => c.l10n.carPlayShowcaseCardMarkBody,
  ),
  _FeatureSpec(
    icon: Icons.dashboard_customize_outlined,
    title: (c) => c.l10n.carPlayShowcaseCardBrowseTitle,
    body: (c) => c.l10n.carPlayShowcaseCardBrowseBody,
  ),
  _FeatureSpec(
    icon: Icons.shield_outlined,
    title: (c) => c.l10n.carPlayShowcaseCardSafeTitle,
    body: (c) => c.l10n.carPlayShowcaseCardSafeBody,
  ),
];

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.spec});

  final _FeatureSpec spec;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(color: context.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppTheme.spacing40,
            height: AppTheme.spacing40,
            decoration: BoxDecoration(
              color: _kCarPlayAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: Icon(
              spec.icon,
              color: _kCarPlayAccent,
              size: AppTheme.spacing24,
            ),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec.title(context),
                  style: context.bodyStyle?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  spec.body(context),
                  style: context.bodySecondaryStyle?.copyWith(
                    color: context.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// How it works — SiriKit intent chips.
// ===========================================================================

class _HowItWorks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Intent names are Apple API identifiers — verbatim, never localized.
    const intents = [
      'INSendMessageIntent',
      'INSearchForMessagesIntent',
      'INSetMessageAttributeIntent',
    ];
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.cardAlt,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(color: context.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: l10n.carPlayShowcaseHowTitle,
            leadingIcon: Icons.bolt_rounded,
          ),
          Text(
            l10n.carPlayShowcaseHowBody,
            style: context.bodySecondaryStyle?.copyWith(
              color: context.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          Wrap(
            spacing: AppTheme.spacing8,
            runSpacing: AppTheme.spacing8,
            children: [
              for (final name in intents)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing8,
                    vertical: AppTheme.spacing4,
                  ),
                  decoration: BoxDecoration(
                    color: _kCarPlayAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radius6),
                    border: Border.all(
                      color: _kCarPlayAccent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    name,
                    style: context.captionStyle?.copyWith(
                      color: _kCarPlayAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Reality check — what this is NOT.
// ===========================================================================

class _RealityCheck extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(
          color: SemanticColors.warning.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: AppTheme.spacing20,
            color: SemanticColors.warning,
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.carPlayShowcaseRealityTitle,
                  style: context.bodyStyle?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  l10n.carPlayShowcaseRealityBody,
                  style: context.bodySecondaryStyle?.copyWith(
                    color: context.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Footer.
// ===========================================================================

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      context.l10n.carPlayShowcaseFooter,
      textAlign: TextAlign.center,
      style: context.captionStyle?.copyWith(
        color: context.textTertiary,
        height: 1.5,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
