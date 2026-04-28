// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: hardcoded-string — dev-only debug sheet, kDebugMode-gated;
// strings never reach end users so ARB translations are not required.

// Dev-only pet state scrubber. Exposes every PetCreature visual
// permutation — stage, branch, mood, asleep, sick, call reason, and
// preferFrontFace — as overrides that drive the real pet hero widget
// live. Only reachable from the pet-home overflow menu when
// kDebugMode is true; compiles to dead code in release.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../models/pet_enums.dart';
import '../providers/pet_debug_overrides.dart';

class PetDebugOverlaySheet extends ConsumerWidget {
  final ScrollController scrollController;

  const PetDebugOverlaySheet({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overrides = ref.watch(petDebugOverridesProvider);
    final notifier = ref.read(petDebugOverridesProvider.notifier);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(
        left: AppTheme.spacing16,
        right: AppTheme.spacing16,
        top: AppTheme.spacing8,
        bottom: AppTheme.spacing32,
      ),
      children: [
        Row(
          children: [
            Icon(Icons.science_outlined, size: 20, color: context.accentColor),
            const SizedBox(width: AppTheme.spacing10),
            Expanded(
              child: Text(
                'Pet state scrubber',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
            TextButton(
              onPressed: overrides.isAnyOverrideActive ? notifier.reset : null,
              child: const Text('Reset'),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing4),
        Text(
          'Debug-only. Overrides the pet hero live so you can see '
          'every visual state without mutating real pet data. Leave '
          'any row unset to keep the real state for that dimension.',
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: context.textTertiary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),
        _EnumChipRow<PetStage>(
          title: 'Stage',
          values: PetStage.values,
          selected: overrides.stage,
          label: _stageLabel,
          onChanged: notifier.setStage,
        ),
        _EnumChipRow<PetBranch>(
          title: 'Branch',
          values: PetBranch.values,
          selected: overrides.branch,
          label: _branchLabel,
          onChanged: notifier.setBranch,
        ),
        _EnumChipRow<PetMood>(
          title: 'Mood',
          values: PetMood.values,
          selected: overrides.mood,
          label: _moodLabel,
          onChanged: notifier.setMood,
        ),
        _EnumChipRow<CallReason>(
          title: 'Call reason',
          values: CallReason.values,
          selected: overrides.callReason,
          label: _callReasonLabel,
          onChanged: notifier.setCallReason,
        ),
        const SizedBox(height: AppTheme.spacing8),
        _TriStateRow(
          title: 'Sleeping',
          value: overrides.isAsleep,
          onChanged: notifier.setIsAsleep,
        ),
        _TriStateRow(
          title: 'Sick',
          value: overrides.isSick,
          onChanged: notifier.setIsSick,
        ),
        _TriStateRow(
          title: 'Face forward (preferFrontFace)',
          value: overrides.preferFrontFace,
          onChanged: notifier.setPreferFrontFace,
        ),
      ],
    );
  }
}

class _EnumChipRow<T> extends StatelessWidget {
  final String title;
  final List<T> values;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T?> onChanged;

  const _EnumChipRow({
    required this.title,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: context.textTertiary,
                letterSpacing: 1.2,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),
          Wrap(
            spacing: AppTheme.spacing8,
            runSpacing: AppTheme.spacing6,
            children: [
              _Chip(
                label: 'Real',
                selected: selected == null,
                onTap: () => onChanged(null),
              ),
              for (final v in values)
                _Chip(
                  label: label(v),
                  selected: selected == v,
                  onTap: () => onChanged(v),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TriStateRow extends StatelessWidget {
  final String title;
  final bool? value;
  final ValueChanged<bool?> onChanged;

  const _TriStateRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: context.textPrimary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),
          _Chip(
            label: 'Real',
            selected: value == null,
            onTap: () => onChanged(null),
          ),
          const SizedBox(width: AppTheme.spacing6),
          _Chip(
            label: 'On',
            selected: value == true,
            onTap: () => onChanged(true),
          ),
          const SizedBox(width: AppTheme.spacing6),
          _Chip(
            label: 'Off',
            selected: value == false,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing10,
          vertical: AppTheme.spacing6,
        ),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.18)
              : context.card.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppTheme.radius10),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.9)
                : context.border.withValues(alpha: 0.5),
            width: selected ? 1.2 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? accent : context.textSecondary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
      ),
    );
  }
}

String _stageLabel(PetStage s) => switch (s) {
  PetStage.egg => 'Egg',
  PetStage.juvenile => 'Juvenile',
  PetStage.adolescent => 'Adolescent',
  PetStage.adult => 'Adult',
  PetStage.elder => 'Elder',
  PetStage.dormant => 'Dormant',
};

String _branchLabel(PetBranch b) => switch (b) {
  PetBranch.unborn => 'Unborn',
  PetBranch.luminous => 'Luminous',
  PetBranch.steady => 'Steady',
  PetBranch.volatile => 'Volatile',
  PetBranch.dimmed => 'Dimmed',
};

String _moodLabel(PetMood m) => switch (m) {
  PetMood.content => 'Content',
  PetMood.hungry => 'Hungry',
  PetMood.sad => 'Sad',
  PetMood.sick => 'Sick',
  PetMood.sleeping => 'Sleeping',
  PetMood.calling => 'Calling',
};

String _callReasonLabel(CallReason r) => switch (r) {
  CallReason.hungry => 'Hungry',
  CallReason.lonely => 'Lonely',
  CallReason.sick => 'Sick',
  CallReason.hygiene => 'Hygiene',
  CallReason.bedtime => 'Bedtime',
  CallReason.boredom => 'Boredom',
};
