// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetStatusLine — plain-language "what should I tap right now?" banner
// above the creature. Driven by [PetAdvisory].
//
// The care loop was not discoverable without this: stats decayed
// silently, the Stabilise button materialised from nowhere, and
// hygiene artefacts looked like decoration. This widget consolidates
// the "one thing to do right now" into a single readable line, names
// the action button inline, and uses colour + icon to reinforce
// urgency at a glance.

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../models/pet_advisory.dart';

class PetStatusLine extends StatelessWidget {
  final PetAdvisory advisory;

  const PetStatusLine({super.key, required this.advisory});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final visual = _visualFor(advisory.kind);
    final message = _messageFor(advisory.kind, l10n);
    final accent = visual.color;

    // Background + border intensity scales with urgency level so the
    // "Thriving" state feels ambient and "Sick" feels like a siren.
    final (bgAlpha, borderAlpha, textColor) = switch (advisory.level) {
      PetAdvisoryLevel.urgent => (0.18, 0.55, context.textPrimary),
      PetAdvisoryLevel.warn => (0.12, 0.40, context.textPrimary),
      PetAdvisoryLevel.info => (0.08, 0.28, context.textSecondary),
      PetAdvisoryLevel.calm => (0.05, 0.18, context.textSecondary),
      PetAdvisoryLevel.stage => (0.06, 0.22, context.textSecondary),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing12,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: accent.withValues(alpha: borderAlpha)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.22),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.55)),
            ),
            child: Icon(visual.icon, size: 20, color: accent),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: _buildRichMessage(
              context: context,
              message: message,
              textColor: textColor,
              accent: accent,
            ),
          ),
        ],
      ),
    );
  }

  /// Build the message with the action name (wrapped in `[[…]]`)
  /// rendered in the accent color + bold so the user's eye snaps to
  /// the button name. Falls back to a plain single-style Text when no
  /// `[[…]]` markers exist.
  Widget _buildRichMessage({
    required BuildContext context,
    required String message,
    required Color textColor,
    required Color accent,
  }) {
    const start = '[[';
    const end = ']]';
    final startIdx = message.indexOf(start);
    final endIdx = message.indexOf(end);

    final baseStyle = TextStyle(
      fontSize: 13.5,
      height: 1.3,
      color: textColor,
      fontFamily: AppTheme.fontFamily,
    );
    final emphasisStyle = baseStyle.copyWith(
      color: accent,
      fontWeight: FontWeight.w700,
    );

    if (startIdx < 0 || endIdx < 0 || endIdx < startIdx) {
      return Text(message, style: baseStyle);
    }

    final before = message.substring(0, startIdx);
    final emphasis = message.substring(startIdx + start.length, endIdx);
    final after = message.substring(endIdx + end.length);

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          if (before.isNotEmpty) TextSpan(text: before),
          TextSpan(text: emphasis, style: emphasisStyle),
          if (after.isNotEmpty) TextSpan(text: after),
        ],
      ),
    );
  }

  /// Icon + accent colour per advisory kind. Colours reuse the same
  /// AccentColors palette that the matching action buttons use, so
  /// the status line and the pulsing button read as the same "channel."
  _AdvisoryVisual _visualFor(PetAdvisoryKind kind) {
    switch (kind) {
      case PetAdvisoryKind.dormant:
        return _AdvisoryVisual(Icons.hourglass_empty, AccentColors.slate);
      case PetAdvisoryKind.egg:
        return _AdvisoryVisual(Icons.egg_outlined, AppTheme.primaryPurple);
      case PetAdvisoryKind.sick:
      case PetAdvisoryKind.callSick:
        return _AdvisoryVisual(Icons.medical_services, AccentColors.red);
      case PetAdvisoryKind.callHungry:
      case PetAdvisoryKind.energyLow:
        return _AdvisoryVisual(Icons.restaurant, AccentColors.yellow);
      case PetAdvisoryKind.callLonely:
      case PetAdvisoryKind.callBoredom:
      case PetAdvisoryKind.moodLow:
        return _AdvisoryVisual(Icons.favorite, AccentColors.pink);
      case PetAdvisoryKind.callHygiene:
      case PetAdvisoryKind.hygieneImminent:
        return _AdvisoryVisual(Icons.cleaning_services, AccentColors.orange);
      case PetAdvisoryKind.hygieneMild:
        return _AdvisoryVisual(Icons.cleaning_services, AccentColors.teal);
      case PetAdvisoryKind.callBedtime:
      case PetAdvisoryKind.bedtime:
        return _AdvisoryVisual(Icons.nightlight_round, AccentColors.indigo);
      case PetAdvisoryKind.resting:
        return _AdvisoryVisual(Icons.bedtime, AccentColors.indigo);
      case PetAdvisoryKind.thriving:
        return _AdvisoryVisual(Icons.check_circle, AccentColors.emerald);
    }
  }

  /// Localised message with `[[action]]` markers around the action
  /// keyword. See [_buildRichMessage] for the rendering contract.
  String _messageFor(PetAdvisoryKind kind, AppLocalizations l10n) {
    switch (kind) {
      case PetAdvisoryKind.dormant:
        return l10n.petAdvisoryDormant;
      case PetAdvisoryKind.egg:
        return l10n.petAdvisoryEgg;
      case PetAdvisoryKind.sick:
        return l10n.petAdvisorySick;
      case PetAdvisoryKind.callHungry:
        return l10n.petAdvisoryCallHungry;
      case PetAdvisoryKind.callLonely:
        return l10n.petAdvisoryCallLonely;
      case PetAdvisoryKind.callSick:
        return l10n.petAdvisoryCallSick;
      case PetAdvisoryKind.callHygiene:
        return l10n.petAdvisoryCallHygiene;
      case PetAdvisoryKind.callBedtime:
        return l10n.petAdvisoryCallBedtime;
      case PetAdvisoryKind.callBoredom:
        return l10n.petAdvisoryCallBoredom;
      case PetAdvisoryKind.hygieneImminent:
        return l10n.petAdvisoryHygieneImminent;
      case PetAdvisoryKind.energyLow:
        return l10n.petAdvisoryEnergyLow;
      case PetAdvisoryKind.moodLow:
        return l10n.petAdvisoryMoodLow;
      case PetAdvisoryKind.hygieneMild:
        return l10n.petAdvisoryHygieneMild;
      case PetAdvisoryKind.resting:
        return l10n.petAdvisoryResting;
      case PetAdvisoryKind.bedtime:
        return l10n.petAdvisoryBedtime;
      case PetAdvisoryKind.thriving:
        return l10n.petAdvisoryThriving;
    }
  }
}

class _AdvisoryVisual {
  final IconData icon;
  final Color color;
  const _AdvisoryVisual(this.icon, this.color);
}
