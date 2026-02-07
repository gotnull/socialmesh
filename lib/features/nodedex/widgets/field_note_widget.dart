// SPDX-License-Identifier: GPL-3.0-or-later

// Field Note Widget — displays a deterministic field journal observation.
//
// Renders the auto-generated field note for a node as a subtle,
// italic text block that reads like a naturalist's journal entry.
// The note is generated deterministically from the node's identity
// and trait data, so the same node always shows the same note.
//
// The widget supports two modes:
//   - Inline: a single line of italic text (for list tiles)
//   - Expanded: a bordered card with a "Field Note" header (for detail view)
//
// Visibility is controlled by the progressive disclosure system.
// The widget renders nothing if the note should be hidden.

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../models/nodedex_entry.dart';
import '../services/field_note_generator.dart';

/// Displays a deterministic field note for a NodeDex entry.
///
/// The note is generated from the node's identity seed and primary
/// trait using [FieldNoteGenerator]. The same inputs always produce
/// the same note — no randomness, no network, no side effects.
///
/// Usage:
/// ```dart
/// FieldNoteWidget(
///   entry: entry,
///   trait: traitResult.primary,
///   accentColor: entry.sigil?.primaryColor ?? context.accentColor,
/// )
/// ```
class FieldNoteWidget extends StatelessWidget {
  /// The NodeDex entry to generate the note for.
  final NodeDexEntry entry;

  /// The primary trait used for template selection.
  final NodeTrait trait;

  /// Accent color for the note border and icon.
  final Color accentColor;

  /// Whether to render in expanded card mode (true) or inline mode (false).
  final bool expanded;

  /// Whether this note is visible. When false, renders nothing.
  /// Controlled by the progressive disclosure system.
  final bool visible;

  const FieldNoteWidget({
    super.key,
    required this.entry,
    required this.trait,
    required this.accentColor,
    this.expanded = false,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final note = FieldNoteGenerator.generate(entry: entry, trait: trait);

    if (expanded) {
      return _buildExpanded(context, note);
    }
    return _buildInline(context, note);
  }

  /// Inline mode: a single line of italic text.
  ///
  /// Suitable for embedding in list tiles or compact headers.
  Widget _buildInline(BuildContext context, String note) {
    return Text(
      note,
      style: TextStyle(
        fontSize: 11,
        fontStyle: FontStyle.italic,
        color: context.textTertiary,
        height: 1.3,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Expanded mode: a bordered card with header.
  ///
  /// Used in the NodeDex detail screen where more vertical space
  /// is available. Includes a small icon and "Field Note" label.
  Widget _buildExpanded(BuildContext context, String note) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Row(
            children: [
              Icon(
                Icons.edit_note_rounded,
                size: 14,
                color: accentColor.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 6),
              Text(
                'Field Note',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: accentColor.withValues(alpha: 0.5),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Note text
          Text(
            note,
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: context.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Collapsible field note with disclosure toggle.
///
/// Wraps [FieldNoteWidget] in an expandable container that starts
/// collapsed, showing just the "Field Note" header. Tapping reveals
/// the full note text. This supports the progressive disclosure
/// philosophy — information is available but not forced.
class CollapsibleFieldNote extends StatefulWidget {
  /// The NodeDex entry to generate the note for.
  final NodeDexEntry entry;

  /// The primary trait used for template selection.
  final NodeTrait trait;

  /// Accent color for the note border and icon.
  final Color accentColor;

  /// Whether this note is visible at all.
  final bool visible;

  /// Whether to start expanded (true) or collapsed (false).
  final bool initiallyExpanded;

  const CollapsibleFieldNote({
    super.key,
    required this.entry,
    required this.trait,
    required this.accentColor,
    this.visible = true,
    this.initiallyExpanded = false,
  });

  @override
  State<CollapsibleFieldNote> createState() => _CollapsibleFieldNoteState();
}

class _CollapsibleFieldNoteState extends State<CollapsibleFieldNote>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _controller;
  late Animation<double> _heightFactor;
  late Animation<double> _iconTurns;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _heightFactor = _controller.drive(CurveTween(curve: Curves.easeInOut));
    _iconTurns = _controller.drive(
      Tween<double>(
        begin: 0.0,
        end: 0.5,
      ).chain(CurveTween(curve: Curves.easeInOut)),
    );

    if (_expanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    final note = FieldNoteGenerator.generate(
      entry: widget.entry,
      trait: widget.trait,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: widget.accentColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.accentColor.withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tappable header
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 14,
                    color: widget.accentColor.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Field Note',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: widget.accentColor.withValues(alpha: 0.5),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  RotationTransition(
                    turns: _iconTurns,
                    child: Icon(
                      Icons.expand_more,
                      size: 16,
                      color: widget.accentColor.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable note content
          ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Align(
                  alignment: Alignment.topLeft,
                  heightFactor: _heightFactor.value,
                  child: child,
                );
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Text(
                  note,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: context.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Evidence list widget for trait explanations.
///
/// Renders a list of bullet-point evidence lines explaining why
/// a trait was assigned. Each line shows the observation text
/// from [TraitEvidence]. Used in the detail view when the
/// disclosure tier permits showing trait evidence.
class TraitEvidenceList extends StatelessWidget {
  /// The evidence lines to display.
  final List<String> observations;

  /// Accent color for bullet dots.
  final Color accentColor;

  /// Whether this evidence list is visible.
  final bool visible;

  const TraitEvidenceList({
    super.key,
    required this.observations,
    required this.accentColor,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || observations.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: observations
            .map((obs) => _buildBullet(context, obs))
            .toList(),
      ),
    );
  }

  Widget _buildBullet(BuildContext context, String observation) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              observation,
              style: TextStyle(
                fontSize: 11,
                color: context.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
