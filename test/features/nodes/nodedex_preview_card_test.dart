// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Source-level pins for the NodeDex preview card on Node Details.
//
// Sprint 2 introduced this card to surface NodeDex content (social tag
// + note) directly on Node Details so the user does not have to dig
// through Overflow > View NodeDex. The card reads
// nodeDexEntryProvider (no parallel state) and surfaces the social
// tag + note + a prominent "Open" CTA.
//
// Sprint 8 restructured the Note: it moved out of the InfoTable into
// a sibling _NodeDexNoteSection so long-form prose wraps naturally
// at full width and the edit affordance lives on the SectionTitle
// header rather than stacking under a right-aligned cell. Tests are
// updated to pin the new structure without losing the classification
// guarantees from Sprint 2.
void main() {
  group('NodeDex preview card on Node Details', () {
    final detailFile = File('lib/features/nodes/node_detail_screen.dart');
    late String source;

    setUpAll(() {
      expect(detailFile.existsSync(), true);
      source = detailFile.readAsStringSync();
    });

    test('helper exists and is wired into the slivers list', () {
      expect(
        source.contains(
          'Widget _buildNodeDexPreviewCard(BuildContext context, MeshNode node)',
        ),
        true,
        reason: 'The preview builder must be a named helper on the state.',
      );
      // Insertion order: between Identity and Radio cards.
      final flattened = source.replaceAll(RegExp(r'\s+'), ' ');
      expect(
        flattened.contains(
          'SliverToBoxAdapter(child: _buildIdentityCard(context, node)), '
          '// ── NodeDex preview (classification + note + open CTA) ── '
          'SliverToBoxAdapter(child: _buildNodeDexPreviewCard(context, node)), '
          '// ── Radio card ── '
          'SliverToBoxAdapter(child: _buildRadioCard(context, node)),',
        ),
        true,
        reason:
            'The preview card must sit immediately after the Identity card '
            'and before the Radio card so NodeDex content is the first '
            'thing the user sees after the basic device metadata.',
      );
    });

    test('reads nodeDexEntryProvider, no parallel state', () {
      expect(
        source.contains('ref.watch(nodeDexEntryProvider(node.nodeNum))'),
        true,
        reason:
            'The preview must consume the same provider as the full NodeDex '
            'screen so edits propagate everywhere without a copy.',
      );
      // The card must not introduce its own local social-tag or note
      // state. Those are owned by NodeDexNotifier.
      expect(
        source.contains('TextEditingController(text: entry?.userNote'),
        false,
        reason:
            'No local TextEditingController for the note. Edits route '
            'through the NodeDex notifier (via the full screen or the '
            'social-tag selector sheet).',
      );
    });

    test(
      'classify tap opens SocialTagSelector and dispatches via the notifier',
      () {
        expect(
          source.contains('SocialTagSelector('),
          true,
          reason:
              'Tag classification must reuse the canonical SocialTagSelector '
              'widget, not a one-off picker.',
        );
        expect(
          source.contains('tagNotifier.setSocialTag(node.nodeNum, tag);'),
          true,
          reason:
              'Tag selection must dispatch through NodeDexNotifier.setSocialTag '
              'so the SQLite store + cloud sync stay in lockstep with the '
              'rest of NodeDex.',
        );
        // Pre-captured notifier (async-safety pattern).
        expect(
          source.contains(
            'final tagNotifier = ref.read(nodeDexProvider.notifier);',
          ),
          true,
          reason:
              'Notifier must be read BEFORE awaiting the sheet so the post-'
              'await callback does not trip the async-safety lint.',
        );
      },
    );

    test('classification stays in the InfoTable; note moves out of the '
        'right-aligned 5:6 cell', () {
      // The original structural fix moved long-form note prose out of
      // the 5:6 two-column InfoTableRow layout (where it was crammed
      // into a right-aligned mono value cell). The implementation has
      // since been generalised: the InfoTable primitive now supports
      // a `fullWidthContent` mode that renders an uppercase header
      // row + a full-width prose body in place of the 5:6 cells.
      // Note uses that mode; classification keeps the original 5:6
      // layout. The structural guarantee is the same regardless of
      // whether prose lives in a sibling widget or a full-width
      // InfoTableRow: prose must NOT render in the right-aligned
      // value cell.
      expect(
        source.contains('InfoTable(') &&
            source.contains('InfoTableRow(') &&
            source.contains('nodeDetailNodeDexClassificationLabel'),
        true,
        reason:
            'Classification must remain an InfoTableRow so the empty / '
            'classified states share visual language with the surrounding '
            'Identity / Radio sections.',
      );
      expect(
        source.contains('fullWidthContent:'),
        true,
        reason:
            'The Note row must use the InfoTable `fullWidthContent` slot '
            'so prose renders as a full-width block with its own header. '
            'Stuffing prose into `value` / `valueWidget` regresses to the '
            'right-aligned-mono-squeeze layout that was explicitly '
            'rejected in the structural fix.',
      );
      expect(
        source.contains('nodeDetailNodeDexNoteLabel'),
        true,
        reason: 'Note row must reference the Note label ARB key.',
      );
    });

    test('classified row renders SocialTagBadge inside the InfoTable cell', () {
      // The classification cell must use SocialTagBadge so the chip colour
      // matches the Classify Node sheet exactly (sky / emerald / orange /
      // primaryPurple). Flattening the tag to plain text drops the per-tag
      // colour cue and breaks visual parity with the selector sheet.
      expect(
        source.contains('SocialTagBadge(tag: socialTag)') ||
            source.contains('SocialTagBadge(\n              tag: socialTag'),
        true,
        reason:
            'When entry.socialTag is set, the value cell must render '
            'SocialTagBadge so the chip inherits the same per-tag colour '
            'map as SocialTagSelector.',
      );
      expect(
        source.contains('valueWidget:'),
        true,
        reason:
            'InfoTableRow.valueWidget is what lets the classification row '
            'host a chip / action button instead of plain text.',
      );
    });

    test('note row carries canonical helpSheet + pencil affordances', () {
      // The InfoTable primitive now renders the uppercase SectionTitle
      // header internally for full-width rows; what the call site is
      // responsible for is wiring the helpSheetBuilder (so copy stays
      // consistent with the standalone NodeDex Note card via the
      // shared 'note' helpKey) and the headerTrailing pencil
      // affordance.
      expect(
        source.contains("NodeDexHelpSheetBody(helpKey: 'note')"),
        true,
        reason:
            'Note help affordance must reuse the NodeDex helpKey "note" so '
            'copy stays consistent with the standalone NodeDex note card.',
      );
      expect(
        source.contains('helpSheetBuilder:'),
        true,
        reason:
            'Note InfoTableRow must wire helpSheetBuilder so the (i) icon '
            'renders on the full-width header line.',
      );
      expect(
        source.contains('headerTrailing:') &&
            source.contains('_NoteSectionPencilButton('),
        true,
        reason:
            'Edit affordance must be the small inline pencil button on the '
            'InfoTableRow headerTrailing slot (which the InfoTable primitive '
            'renders in the full-width header row), not a body-stacked '
            'Edit pill.',
      );
    });

    test('every meaningful interaction emits an AppLogging marker', () {
      const required = [
        '[NodeDexPreview] open full NodeDex',
        '[NodeDexPreview] classify sheet opened',
        '[NodeDexPreview] classify tap with no entry',
        '[NodeDexPreview] tag applied',
        '[NodeDexPreview] note editor opened',
      ];
      for (final marker in required) {
        expect(
          source.contains(marker),
          true,
          reason: 'AppLogging marker missing: $marker',
        );
      }
    });

    test('overflow menu entrypoint is retained as a redundant path', () {
      // The feedback was to make NodeDex MORE accessible, not to remove
      // the existing overflow entrypoint. Keep it as a discoverable
      // fallback for power users.
      expect(
        source.contains("value: 'nodedex'"),
        true,
        reason:
            'The overflow menu entry should remain; this sprint adds a '
            'prominent path, it does not replace the existing one.',
      );
    });

    test('ARB keys exist for every preview-card label', () {
      // Sprint 8 dropped nodeDetailNodeDexNoNote from the required set:
      // the empty state is now a "+ Add note" chip rather than a "No
      // note yet" placeholder string, so the key is no longer
      // referenced by the preview card.
      const requiredKeys = [
        'nodeDetailNodeDexSectionTitle',
        'nodeDetailNodeDexOpenCta',
        'nodeDetailNodeDexClassificationLabel',
        'nodeDetailNodeDexNoteLabel',
        'nodeDetailNodeDexNotClassified',
        'nodeDetailNodeDexClassifyCta',
        'nodeDetailNodeDexAddNoteCta',
        'nodedexNoteEdit',
      ];
      for (final key in requiredKeys) {
        expect(
          source.contains('context.l10n.$key'),
          true,
          reason:
              'Card must reference l10n key $key — no hardcoded strings '
              'are allowed in user-facing UI per CLAUDE.md.',
        );
      }
    });
  });
}
