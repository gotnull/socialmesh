// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level pins for Sprint 2's NodeDex preview card on Node Details.
///
/// The feedback was: "Avoid burying NodeDex behind Overflow > View NodeDex
/// only" and "Make classification/tagging accessible from Node Details"
/// and "Make notes accessible from Node Details". The implementation
/// adds a preview card between the Identity card and the Radio card
/// that reads `nodeDexEntryProvider` (no parallel state) and surfaces
/// the social tag + note + a prominent "Open" CTA.
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

    test('reads nodeDexEntryProvider — no parallel state', () {
      expect(
        source.contains('ref.watch(nodeDexEntryProvider(node.nodeNum))'),
        true,
        reason:
            'The preview must consume the same provider as the full NodeDex '
            'screen so edits propagate everywhere without a copy.',
      );
      // The card must not introduce its own local social-tag or note
      // state — those are owned by NodeDexNotifier.
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

    test('body uses InfoTable like the surrounding sections', () {
      // Visual consistency: the NodeDex preview shares the same bordered,
      // zebra-striped table layout as the Identity / Radio / Device
      // Metrics sections instead of hand-rolled SizedBox(width:100)+Text
      // rows. The previous layout wrapped the "Classification" label
      // mid-word on narrow viewports.
      expect(
        source.contains('InfoTable(') &&
            source.contains('InfoTableRow(') &&
            source.contains('nodeDetailNodeDexClassificationLabel') &&
            source.contains('nodeDetailNodeDexNoteLabel'),
        true,
        reason:
            'NodeDex preview body must be an InfoTable with InfoTableRow '
            'entries (label + value + tappable onTap), matching the '
            'Identity / Radio sections directly above and below it.',
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
            'InfoTableRow.valueWidget is what lets the classification + note '
            'rows host a chip / action button instead of plain text.',
      );
    });

    test('every meaningful interaction emits an AppLogging marker', () {
      const required = [
        '[NodeDexPreview] open full NodeDex',
        '[NodeDexPreview] classify sheet opened',
        '[NodeDexPreview] classify tap with no entry',
        '[NodeDexPreview] tag applied',
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
      // the existing overflow entrypoint — keep it as a discoverable
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
      const requiredKeys = [
        'nodeDetailNodeDexSectionTitle',
        'nodeDetailNodeDexOpenCta',
        'nodeDetailNodeDexClassificationLabel',
        'nodeDetailNodeDexNoteLabel',
        'nodeDetailNodeDexNotClassified',
        'nodeDetailNodeDexNoNote',
        'nodeDetailNodeDexClassifyCta',
        'nodeDetailNodeDexAddNoteCta',
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
