// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/countdown_providers.dart';
import '../theme.dart';

/// A slim animated banner that renders just below the app bar to show
/// active countdown operations (e.g. traceroute cooldowns).
///
/// Place this in a [Stack] inside the main shell, positioned below the
/// safe-area top + toolbar height. It auto-hides when no countdowns are
/// active and slides in/out with animation.
///
/// The banner is intentionally non-interactive (no tap targets) so it
/// never obstructs existing controls. It is purely informational.
class CountdownBanner extends ConsumerStatefulWidget {
  const CountdownBanner({super.key});

  @override
  ConsumerState<CountdownBanner> createState() => _CountdownBannerState();
}

class _CountdownBannerState extends ConsumerState<CountdownBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final countdowns = ref.watch(activeCountdownListProvider);
    final hasCountdowns = countdowns.isNotEmpty;

    // Drive the animation based on presence of countdowns
    if (hasCountdowns && !_slideController.isCompleted) {
      _slideController.forward();
    } else if (!hasCountdowns && _slideController.value > 0) {
      _slideController.reverse();
    }

    return AnimatedBuilder(
      animation: _slideController,
      builder: (context, child) {
        if (_slideController.isDismissed) {
          return const SizedBox.shrink();
        }
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(opacity: _fadeAnimation, child: child),
        );
      },
      child: _CountdownBannerContent(countdowns: countdowns),
    );
  }
}

class _CountdownBannerContent extends StatelessWidget {
  final List<CountdownTask> countdowns;

  const _CountdownBannerContent({required this.countdowns});

  @override
  Widget build(BuildContext context) {
    if (countdowns.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.surface.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: context.border.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < countdowns.length; i++) ...[
            _CountdownRow(task: countdowns[i]),
            if (i < countdowns.length - 1)
              Divider(
                height: 0.5,
                thickness: 0.5,
                color: context.border.withValues(alpha: 0.15),
              ),
          ],
        ],
      ),
    );
  }
}

class _CountdownRow extends StatelessWidget {
  final CountdownTask task;

  const _CountdownRow({required this.task});

  IconData _iconForType(CountdownType type) {
    switch (type) {
      case CountdownType.traceroute:
        return Icons.route;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;
    final progress = task.progress;
    final remaining = task.remainingSeconds;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Icon
          Icon(
            _iconForType(task.type),
            size: 14,
            color: accentColor.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 8),

          // Label
          Expanded(
            child: Text(
              task.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: context.textSecondary,
                fontFamily: AppTheme.fontFamily,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          // Progress bar
          SizedBox(
            width: 48,
            height: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: 1.0 - progress,
                backgroundColor: context.textTertiary.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(
                  accentColor.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Remaining seconds
          SizedBox(
            width: 28,
            child: Text(
              '${remaining}s',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: context.textTertiary,
                fontFamily: AppTheme.fontFamily,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
