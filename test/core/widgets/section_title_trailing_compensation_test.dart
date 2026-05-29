// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// SectionTitle trailing-compensation regression: tall trailing
// widgets (e.g. an IconButton's 32x32 hit area) must NOT inflate
// the SectionTitle's reported height. Without compensation,
// callers had to hand-tune the surrounding SizedBox spacers to
// undo the row inflation — see LICENSE_ORG_OVERVIEW_SCREEN.md §9.3.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/core/widgets/section_header.dart';

void main() {
  group('SectionTitle — trailing compensation', () {
    testWidgets(
      'tall trailing (IconButton 32x32) does not inflate reported height',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  // Baseline: SectionTitle without trailing — reports
                  // its natural text-row height + built-in bottom
                  // padding.
                  const SectionTitle(title: 'baseline'),
                  // With a tall trailing — should report the SAME
                  // height as the baseline. Internal compensation
                  // collapses the trailing's vertical contribution
                  // to zero via Align(heightFactor: 0).
                  SectionTitle(
                    title: 'with trailing',
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        final baselineSize = tester.getSize(find.byType(SectionTitle).first);
        final withTrailingSize = tester.getSize(
          find.byType(SectionTitle).at(1),
        );

        // Heights must match: the IconButton's 32px hit area does
        // not contribute to the SectionTitle's reported height. A
        // regression to the pre-compensation behavior (Row aligns to
        // max-child height) would push `withTrailingSize.height` to
        // ~32+8=40px, leaving baseline at ~18+8=26px and tripping
        // this expect by a wide margin.
        expect(
          withTrailingSize.height,
          equals(baselineSize.height),
          reason:
              'Tall trailing inflated SectionTitle height. Check that '
              'the trailing is wrapped in Align(heightFactor: 0) in '
              'lib/core/widgets/section_header.dart.',
        );
      },
    );

    testWidgets(
      'wide trailing (info pill) preserves its natural width in the row',
      (tester) async {
        // The compensation must not eat the trailing's width — only
        // its height. A wide trailing (e.g. a verified-vendor pill in
        // the device-shop product detail screen) must still claim
        // its natural horizontal footprint in the row, or the title
        // would extend underneath it.
        const pillKey = ValueKey('pill');
        const pillWidth = 80.0;
        const pillHeight = 24.0;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SectionTitle(
                title: 'title',
                trailing: SizedBox(
                  key: pillKey,
                  width: pillWidth,
                  height: pillHeight,
                ),
              ),
            ),
          ),
        );

        final pillSize = tester.getSize(find.byKey(pillKey));
        expect(
          pillSize.width,
          equals(pillWidth),
          reason:
              'Trailing lost its natural width — compensation '
              'is over-collapsing the horizontal axis.',
        );
        expect(
          pillSize.height,
          equals(pillHeight),
          reason:
              'Trailing renders at its intrinsic height even '
              'though it contributes 0 to the row height.',
        );
      },
    );

    testWidgets(
      'trailing is pinned to the right edge regardless of title length',
      (tester) async {
        // Companion regression: the pencil was visually offset to
        // the left when the title was short, because the previous
        // Flexible+Spacer layout left the trailing at
        // `title_width + 50%_of_remaining` instead of the row's
        // right edge. The fix (Flexible → Expanded) keeps the
        // trailing pinned to the right.
        const trailingKey = ValueKey('trailing');
        const trailingWidth = 32.0;
        const totalWidth = 400.0;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: totalWidth,
                child: SectionTitle(
                  title: 'short', // ~40px wide — well under half of 400
                  trailing: SizedBox(
                    key: trailingKey,
                    width: trailingWidth,
                    height: 32,
                  ),
                ),
              ),
            ),
          ),
        );

        final trailingRect = tester.getRect(find.byKey(trailingKey));
        // Right edge of trailing must be at the right edge of the
        // 400px-wide SectionTitle.
        expect(
          trailingRect.right,
          equals(totalWidth),
          reason:
              'Trailing not pinned to right edge — Flexible '
              'regression. Check that the title is wrapped in '
              'Expanded (not Flexible) in section_header.dart.',
        );
      },
    );
  });
}
