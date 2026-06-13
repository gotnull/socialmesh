// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

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

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/units/distance_format.dart';
import '../models/nodedex_entry.dart';
import '../services/field_note_generator.dart';
import 'nodedex_card.dart';

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

  /// Display-units preference, so distances in the note honour Imperial.
  final MeasurementUnits units;

  const FieldNoteWidget({
    super.key,
    required this.entry,
    required this.trait,
    required this.accentColor,
    required this.units,
    this.expanded = false,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final note = FieldNoteGenerator.generate(
      entry: entry,
      trait: trait,
      l10n: context.l10n,
      units: units,
    );

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
    return NodeDexCard(
      title: context.l10n.nodedexFieldNoteLabel,
      icon: Icons.edit_note_rounded,
      helpKey: 'field_note',
      child: Text(
        note,
        style: TextStyle(
          fontSize: 13,
          fontStyle: FontStyle.italic,
          color: context.textSecondary,
          height: 1.5,
        ),
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

  /// Whether to wrap the list in the default screen-edge padding.
  /// Set to `false` when embedding inside a card that already pads.
  final bool padded;

  const TraitEvidenceList({
    super.key,
    required this.observations,
    required this.accentColor,
    this.visible = true,
    this.padded = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || observations.isEmpty) return const SizedBox.shrink();

    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: observations.map((obs) => _buildBullet(context, obs)).toList(),
    );

    if (!padded) return list;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: list,
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
          const SizedBox(width: AppTheme.spacing8),
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
