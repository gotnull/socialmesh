// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

import '../theme.dart';
import 'glass_scaffold.dart';

/// Metadata for a single step in a guided flow.
class GuidedFlowStep {
  /// Short step title shown in the progress indicator.
  final String title;

  /// Icon displayed alongside the step indicator.
  final IconData icon;

  /// Accent color for the active step indicator.
  final Color color;

  const GuidedFlowStep({
    required this.title,
    required this.icon,
    required this.color,
  });
}

/// A reusable scaffold for wizard / multi-step guided flows.
///
/// Wraps [GlassScaffold] with a step progress indicator and a [PageView]
/// that animates between steps. The caller provides step metadata and
/// page builder callbacks; this scaffold handles the chrome.
///
/// Used by: service creation wizard, contact exchange flow, discovery wizard.
class GuidedFlowScaffold extends StatelessWidget {
  /// Screen title shown in the glass app bar.
  final String title;

  /// Metadata for each step (title, icon, color).
  final List<GuidedFlowStep> steps;

  /// Zero-based index of the currently active step.
  final int currentStep;

  /// Page controller that drives the [PageView].
  final PageController pageController;

  /// Builder for each step page. Called with the step index.
  final Widget Function(BuildContext context, int stepIndex) pageBuilder;

  /// Widget placed at the bottom (typically a [BottomActionBar] with
  /// Back / Next / Done buttons).
  final Widget? bottomBar;

  /// Optional leading widget for the app bar (defaults to back arrow).
  final Widget? leading;

  /// Whether the user can swipe between pages manually.
  final bool allowSwipe;

  /// Callback when the page changes via swipe.
  final ValueChanged<int>? onPageChanged;

  const GuidedFlowScaffold({
    super.key,
    required this.title,
    required this.steps,
    required this.currentStep,
    required this.pageController,
    required this.pageBuilder,
    this.bottomBar,
    this.leading,
    this.allowSwipe = false,
    this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Use NeverScrollableScrollPhysics on the outer GlassScaffold so it routes
    // through _buildNonScrollableBody, which hands the Column directly to
    // Scaffold.body rather than wrapping it in SliverFillRemaining.
    //
    // The SliverFillRemaining(hasScrollBody: false) + PageView combination
    // triggers a null-check crash in RenderViewportBase.layoutChildSequence on
    // Android, producing a completely blank screen. Bypassing the sliver path
    // here fixes the issue on Android while keeping the glass app-bar styling.
    //
    // The bottom action bar is passed as bottomNavigationBar so the Scaffold
    // correctly reserves space for it and pins it above the system navigation.
    return GlassScaffold.body(
      title: title,
      leading: leading,
      physics: const NeverScrollableScrollPhysics(),
      bottomNavigationBar: bottomBar,
      body: Column(
        children: [
          _StepProgressIndicator(steps: steps, currentStep: currentStep),
          Expanded(
            child: PageView.builder(
              controller: pageController,
              physics: allowSwipe
                  ? const ClampingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              onPageChanged: onPageChanged,
              itemCount: steps.length,
              itemBuilder: pageBuilder,
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal step progress indicator with connected dots and labels.
class _StepProgressIndicator extends StatelessWidget {
  final List<GuidedFlowStep> steps;
  final int currentStep;

  const _StepProgressIndicator({
    required this.steps,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing12,
      ),
      decoration: BoxDecoration(
        color: context.background,
        border: Border(
          bottom: BorderSide(color: context.border.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            // Connector line between dots
            final stepBefore = index ~/ 2;
            final isCompleted = stepBefore < currentStep;
            return Expanded(
              child: Container(
                height: 2,
                color: isCompleted
                    ? steps[stepBefore].color.withValues(alpha: 0.6)
                    : context.border.withValues(alpha: 0.2),
              ),
            );
          }
          // Step dot
          final stepIndex = index ~/ 2;
          final isActive = stepIndex == currentStep;
          final isCompleted = stepIndex < currentStep;
          final step = steps[stepIndex];

          return _StepDot(
            step: step,
            isActive: isActive,
            isCompleted: isCompleted,
            stepNumber: stepIndex + 1,
          );
        }),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final GuidedFlowStep step;
  final bool isActive;
  final bool isCompleted;
  final int stepNumber;

  const _StepDot({
    required this.step,
    required this.isActive,
    required this.isCompleted,
    required this.stepNumber,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive || isCompleted
        ? step.color
        : context.textTertiary.withValues(alpha: 0.4);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          width: isActive ? 36 : 28,
          height: isActive ? 36 : 28,
          decoration: BoxDecoration(
            color: isActive
                ? color.withValues(alpha: 0.15)
                : isCompleted
                ? color.withValues(alpha: 0.1)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: isActive ? 2.0 : 1.5),
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, size: 14, color: color)
                : Icon(step.icon, size: isActive ? 16 : 12, color: color),
          ),
        ),
        const SizedBox(height: AppTheme.spacing4),
        Text(
          step.title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive || isCompleted
                ? context.textSecondary
                : context.textTertiary.withValues(alpha: 0.5),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
