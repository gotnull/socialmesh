// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D37-C-A - pure-function pins for `applyChannelOrder` and
// `computeReorderedFullList`.
//
// These helpers carry the entire reorder algorithm. Pinning them in
// isolation (no widget pumping, no Riverpod) keeps regression cost
// low and the contract explicit.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/meshcore/widgets/meshcore_channel_order.dart';
import 'package:socialmesh/models/meshcore_channel.dart';

MeshCoreChannel _ch(int index) => MeshCoreChannel(
  index: index,
  name: 'ch-$index',
  psk: Uint8List.fromList(List.generate(16, (i) => index)),
);

List<int> _indices(List<MeshCoreChannel> cs) => cs.map((c) => c.index).toList();

void main() {
  group('applyChannelOrder', () {
    test('empty userOrder returns firmwareSorted unchanged', () {
      final fw = [_ch(0), _ch(1), _ch(2), _ch(3)];
      final out = applyChannelOrder(fw, const []);
      expect(_indices(out), orderedEquals([0, 1, 2, 3]));
    });

    test('full userOrder applies user sequence verbatim', () {
      final fw = [_ch(0), _ch(1), _ch(2), _ch(3)];
      final out = applyChannelOrder(fw, const [3, 1, 0, 2]);
      expect(_indices(out), orderedEquals([3, 1, 0, 2]));
    });

    test('partial userOrder: listed first, unlisted tail in slot order', () {
      final fw = [_ch(0), _ch(1), _ch(2), _ch(3), _ch(4)];
      final out = applyChannelOrder(fw, const [3, 1]);
      // Listed [3,1] first; then [0,2,4] (firmware slot order).
      expect(_indices(out), orderedEquals([3, 1, 0, 2, 4]));
    });

    test('non-existent slot indices in userOrder are dropped silently', () {
      final fw = [_ch(0), _ch(1), _ch(2)];
      final out = applyChannelOrder(fw, const [9, 1, 99, 0]);
      // 9 and 99 don't exist, drop them; listed-existing = [1, 0];
      // unlisted = [2].
      expect(_indices(out), orderedEquals([1, 0, 2]));
    });

    test('duplicate slot indices in userOrder are deduped (first wins)', () {
      final fw = [_ch(0), _ch(1), _ch(2)];
      final out = applyChannelOrder(fw, const [2, 0, 2, 1, 0]);
      expect(_indices(out), orderedEquals([2, 0, 1]));
    });

    test('output length always equals firmwareSorted length', () {
      final fw = [_ch(0), _ch(1), _ch(2), _ch(3), _ch(4)];
      for (final order in const <List<int>>[
        <int>[],
        [4, 0],
        [9, 9, 9],
        [3, 3, 3, 2, 1, 0, 4],
      ]) {
        final out = applyChannelOrder(fw, order);
        expect(out.length, fw.length, reason: 'order=$order');
      }
    });
  });

  group('computeReorderedFullList', () {
    test('moving a tile within the All filter (visible == full)', () {
      // Full and visible are the same set: [A=0, B=1, C=2, D=3].
      final cs = [_ch(0), _ch(1), _ch(2), _ch(3)];
      // Drag C (idx=2) from position 2 to position 0.
      final next = computeReorderedFullList(
        full: cs,
        visible: cs,
        oldVisibleIndex: 2,
        newVisibleIndex: 0,
      );
      expect(next, orderedEquals([2, 0, 1, 3]));
    });

    test('reorder under a filter preserves non-visible channels in place', () {
      // Full = [P=0, Q=1, R=2, S=3], visible = [P, R] (filter excludes Q+S).
      // Drag R from visible position 1 to visible position 0.
      final full = [_ch(0), _ch(1), _ch(2), _ch(3)];
      final visible = [full[0], full[2]];
      final next = computeReorderedFullList(
        full: full,
        visible: visible,
        oldVisibleIndex: 1,
        newVisibleIndex: 0,
      );
      // Visible positions in full are slots 0 and 2. They now carry
      // [R, P] = [2, 0]. Non-visible positions (1, 3) keep their
      // original entries Q=1 and S=3.
      expect(next, orderedEquals([2, 1, 0, 3]));
    });

    test('reorder under Hidden filter preserves visible-but-non-hidden', () {
      // Full = [A=0, B=1, C=2, D=3]; only B and D are hidden.
      // Visible (Hidden filter) = [B, D]. Drag D before B.
      final full = [_ch(0), _ch(1), _ch(2), _ch(3)];
      final visible = [full[1], full[3]];
      final next = computeReorderedFullList(
        full: full,
        visible: visible,
        oldVisibleIndex: 1,
        newVisibleIndex: 0,
      );
      // Visible positions in full are slots 1 and 3. They now carry
      // [D, B] = [3, 1]. Non-visible positions (0, 2) keep A=0 and C=2.
      expect(next, orderedEquals([0, 3, 2, 1]));
    });

    test('oldIndex == newIndex is a no-op (returns full order unchanged)', () {
      final full = [_ch(0), _ch(1), _ch(2)];
      final visible = [full[0], full[1], full[2]];
      final next = computeReorderedFullList(
        full: full,
        visible: visible,
        oldVisibleIndex: 1,
        newVisibleIndex: 1,
      );
      expect(next, orderedEquals([0, 1, 2]));
    });

    test('out-of-range visible indices are a safe no-op', () {
      final full = [_ch(0), _ch(1)];
      final visible = [full[0], full[1]];
      final next = computeReorderedFullList(
        full: full,
        visible: visible,
        oldVisibleIndex: 99,
        newVisibleIndex: 0,
      );
      expect(next, orderedEquals([0, 1]));
    });

    test('reorder across the middle: [A, B, C] -> drag A to end gives '
        '[B, C, A]', () {
      final cs = [_ch(0), _ch(1), _ch(2)];
      final next = computeReorderedFullList(
        full: cs,
        visible: cs,
        oldVisibleIndex: 0,
        newVisibleIndex: 2,
      );
      expect(next, orderedEquals([1, 2, 0]));
    });

    test('reorder under Public filter preserves Private positions', () {
      // Full = [PUB0=0, PRIV1=1, PUB2=2, PRIV3=3]; Public chip shows
      // [PUB0, PUB2]. Drag PUB2 above PUB0.
      final full = [_ch(0), _ch(1), _ch(2), _ch(3)];
      final visible = [full[0], full[2]];
      final next = computeReorderedFullList(
        full: full,
        visible: visible,
        oldVisibleIndex: 1,
        newVisibleIndex: 0,
      );
      // Visible positions in full are 0 and 2. They now carry [PUB2,
      // PUB0] = [2, 0]. Non-visible 1 and 3 keep PRIV1=1 and PRIV3=3.
      expect(next, orderedEquals([2, 1, 0, 3]));
    });
  });
}
