// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Human-readable delivery phase for mesh transfers.
///
/// Maps MRRP protocol states to user-understandable phases without
/// exposing chunk frames, reassembly, or transport details.
enum DeliveryPhase {
  /// Preparing the payload for transfer.
  preparing,

  /// Actively sending data to the mesh.
  sending,

  /// Data has been committed to the mesh network.
  sentToMesh,

  /// No route to the recipient is available yet.
  waitingForPath,

  /// Data is being relayed through the mesh.
  delivering,

  /// Some parts have arrived, others are in transit.
  partiallyDelivered,

  /// Automatic retry is in progress.
  retrying,

  /// Resuming a previously interrupted transfer.
  resuming,

  /// All data has arrived at the destination.
  delivered,

  /// Delivery is confirmed with integrity verification.
  verified,

  /// Something requires user attention.
  needsAttention,

  /// Transfer failed after all retries.
  failed,
}

/// Extension providing human-readable labels and descriptions for
/// [DeliveryPhase] values.
///
/// Callers must supply the l10n labels; this extension provides
/// icon, color, and progress semantics. The actual translated strings
/// are passed in by the widget layer via l10n keys.
extension DeliveryPhasePresentation on DeliveryPhase {
  /// Icon that communicates this phase visually.
  IconData get icon {
    switch (this) {
      case DeliveryPhase.preparing:
        return Icons.pending_outlined;
      case DeliveryPhase.sending:
        return Icons.upload_outlined;
      case DeliveryPhase.sentToMesh:
        return Icons.cell_tower;
      case DeliveryPhase.waitingForPath:
        return Icons.route_outlined;
      case DeliveryPhase.delivering:
        return Icons.swap_horiz;
      case DeliveryPhase.partiallyDelivered:
        return Icons.pie_chart_outline;
      case DeliveryPhase.retrying:
        return Icons.replay;
      case DeliveryPhase.resuming:
        return Icons.play_circle_outline;
      case DeliveryPhase.delivered:
        return Icons.check_circle_outline;
      case DeliveryPhase.verified:
        return Icons.verified_outlined;
      case DeliveryPhase.needsAttention:
        return Icons.info_outline;
      case DeliveryPhase.failed:
        return Icons.error_outline;
    }
  }

  /// Semantic color for this phase.
  Color get color {
    switch (this) {
      case DeliveryPhase.preparing:
      case DeliveryPhase.sending:
      case DeliveryPhase.sentToMesh:
      case DeliveryPhase.delivering:
        return SemanticColors.info;
      case DeliveryPhase.waitingForPath:
      case DeliveryPhase.partiallyDelivered:
      case DeliveryPhase.retrying:
      case DeliveryPhase.resuming:
        return SemanticColors.warning;
      case DeliveryPhase.delivered:
      case DeliveryPhase.verified:
        return SemanticColors.success;
      case DeliveryPhase.needsAttention:
        return AccentColors.orange;
      case DeliveryPhase.failed:
        return SemanticColors.error;
    }
  }

  /// Whether this phase represents an active transferring state.
  bool get isActive {
    switch (this) {
      case DeliveryPhase.preparing:
      case DeliveryPhase.sending:
      case DeliveryPhase.sentToMesh:
      case DeliveryPhase.delivering:
      case DeliveryPhase.retrying:
      case DeliveryPhase.resuming:
        return true;
      case DeliveryPhase.waitingForPath:
      case DeliveryPhase.partiallyDelivered:
      case DeliveryPhase.delivered:
      case DeliveryPhase.verified:
      case DeliveryPhase.needsAttention:
      case DeliveryPhase.failed:
        return false;
    }
  }

  /// Whether the user can safely leave the screen.
  bool get isSafeToLeave {
    switch (this) {
      case DeliveryPhase.sentToMesh:
      case DeliveryPhase.delivering:
      case DeliveryPhase.delivered:
      case DeliveryPhase.verified:
      case DeliveryPhase.needsAttention:
      case DeliveryPhase.failed:
        return true;
      case DeliveryPhase.preparing:
      case DeliveryPhase.sending:
      case DeliveryPhase.waitingForPath:
      case DeliveryPhase.partiallyDelivered:
      case DeliveryPhase.retrying:
      case DeliveryPhase.resuming:
        return false;
    }
  }

  /// Whether delivery is complete (success or failure).
  bool get isTerminal {
    switch (this) {
      case DeliveryPhase.delivered:
      case DeliveryPhase.verified:
      case DeliveryPhase.failed:
        return true;
      case DeliveryPhase.preparing:
      case DeliveryPhase.sending:
      case DeliveryPhase.sentToMesh:
      case DeliveryPhase.waitingForPath:
      case DeliveryPhase.delivering:
      case DeliveryPhase.partiallyDelivered:
      case DeliveryPhase.retrying:
      case DeliveryPhase.resuming:
      case DeliveryPhase.needsAttention:
        return false;
    }
  }
}

/// Displays delivery progress with plain-language status.
///
/// Shows the current [DeliveryPhase], a human-readable description,
/// optional progress bar, and an expandable expert details section.
class DeliveryProgressCard extends StatefulWidget {
  /// Current delivery phase.
  final DeliveryPhase phase;

  /// Human-readable label for the current phase (from l10n).
  final String label;

  /// One-line description of what is happening (from l10n).
  final String description;

  /// Optional progress value (0.0 to 1.0) for multi-part transfers.
  final double? progress;

  /// Optional text shown below the progress bar (e.g., "3 of 5 parts").
  final String? progressDetail;

  /// Whether to show expert details section.
  final bool showExpertDetails;

  /// Expert diagnostic details (protocol state, route info, etc.).
  final List<String>? expertDetails;

  /// Localized label for the expert details toggle.
  final String? expertToggleLabel;

  /// Localized hint shown when the phase is safe to leave.
  final String? safeToLeaveHint;

  const DeliveryProgressCard({
    super.key,
    required this.phase,
    required this.label,
    required this.description,
    this.progress,
    this.progressDetail,
    this.showExpertDetails = false,
    this.expertDetails,
    this.expertToggleLabel,
    this.safeToLeaveHint,
  });

  @override
  State<DeliveryProgressCard> createState() => _DeliveryProgressCardState();
}

class _DeliveryProgressCardState extends State<DeliveryProgressCard> {
  bool _expertExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: widget.phase.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status header
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Row(
              children: [
                _PhaseIcon(phase: widget.phase),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing2),
                      Text(
                        widget.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Progress bar (optional)
          if (widget.progress != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radius4),
                    child: LinearProgressIndicator(
                      value: widget.progress,
                      minHeight: 6,
                      backgroundColor: widget.phase.color.withValues(
                        alpha: 0.1,
                      ),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.phase.color,
                      ),
                    ),
                  ),
                  if (widget.progressDetail != null) ...[
                    const SizedBox(height: AppTheme.spacing4),
                    Text(
                      widget.progressDetail!,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
          ],

          // Safe-to-leave hint
          if (widget.phase.isSafeToLeave &&
              !widget.phase.isTerminal &&
              widget.safeToLeaveHint != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                0,
                AppTheme.spacing16,
                AppTheme.spacing12,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 14,
                    color: AppTheme.successGreen.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: AppTheme.spacing6),
                  Expanded(
                    child: Text(
                      widget.safeToLeaveHint!,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Expert details expander
          if (widget.showExpertDetails &&
              widget.expertDetails != null &&
              widget.expertDetails!.isNotEmpty)
            _ExpertDetailsSection(
              details: widget.expertDetails!,
              isExpanded: _expertExpanded,
              toggleLabel: widget.expertToggleLabel,
              onToggle: () =>
                  setState(() => _expertExpanded = !_expertExpanded),
            ),
        ],
      ),
    );
  }
}

/// Animated phase icon with a pulsing ring for active states.
class _PhaseIcon extends StatefulWidget {
  final DeliveryPhase phase;

  const _PhaseIcon({required this.phase});

  @override
  State<_PhaseIcon> createState() => _PhaseIconState();
}

class _PhaseIconState extends State<_PhaseIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.phase.isActive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_PhaseIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.phase.isActive && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.phase.isActive && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = widget.phase.isActive
            ? 1.0 + (_pulseController.value * 0.1)
            : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: widget.phase.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.phase.color.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(widget.phase.icon, size: 20, color: widget.phase.color),
          ),
        );
      },
    );
  }
}

/// Expandable section for expert-level diagnostic details.
class _ExpertDetailsSection extends StatelessWidget {
  final List<String> details;
  final bool isExpanded;
  final String? toggleLabel;
  final VoidCallback onToggle;

  const _ExpertDetailsSection({
    required this.details,
    required this.isExpanded,
    this.toggleLabel,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Divider
        Container(height: 1, color: context.border.withValues(alpha: 0.08)),
        // Toggle
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onToggle();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing10,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.science_outlined,
                  size: 14,
                  color: context.textTertiary,
                ),
                const SizedBox(width: AppTheme.spacing6),
                Expanded(
                  child: Text(
                    toggleLabel ?? 'Technical details',
                    style: TextStyle(fontSize: 12, color: context.textTertiary),
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: context.textTertiary,
                ),
              ],
            ),
          ),
        ),
        // Details
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: isExpanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacing16,
                    0,
                    AppTheme.spacing16,
                    AppTheme.spacing12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: details
                        .map(
                          (detail) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppTheme.spacing4,
                            ),
                            child: Text(
                              detail,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: context.textTertiary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
