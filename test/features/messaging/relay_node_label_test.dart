// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/messaging/relay_node_label.dart';
import 'package:socialmesh/models/mesh_models.dart';

MeshNode _node(int nodeNum, {String? longName}) =>
    MeshNode(nodeNum: nodeNum, longName: longName);

void main() {
  group('resolveRelayNodeLabel', () {
    test('returns null for a null relay byte', () {
      expect(resolveRelayNodeLabel(null, [_node(0x11223344)]), isNull);
    });

    test('returns null for a zero relay byte', () {
      expect(resolveRelayNodeLabel(0, [_node(0x11223344)]), isNull);
    });

    test('resolves a unique low-byte match to the node display name', () {
      final nodes = [
        _node(0x112233C4, longName: 'Ridge Repeater'),
        _node(0x11223311, longName: 'Valley Node'),
      ];
      final label = resolveRelayNodeLabel(0xC4, nodes);
      expect(label, isNotNull);
      expect(label!.text, 'Ridge Repeater');
      expect(label.resolved, isTrue);
    });

    test('only the low byte of the relay value is matched', () {
      final nodes = [_node(0x112233C4, longName: 'Ridge Repeater')];
      final label = resolveRelayNodeLabel(0xFFFFFFC4, nodes);
      expect(label, isNotNull);
      expect(label!.text, 'Ridge Repeater');
      expect(label.resolved, isTrue);
    });

    test('falls back to hex when no known node matches', () {
      final label = resolveRelayNodeLabel(0xC4, [_node(0x11223311)]);
      expect(label, isNotNull);
      expect(label!.text, '0xC4');
      expect(label.resolved, isFalse);
    });

    test('falls back to hex when the match is ambiguous', () {
      final nodes = [
        _node(0x112233C4, longName: 'Ridge Repeater'),
        _node(0x556677C4, longName: 'Summit Router'),
      ];
      final label = resolveRelayNodeLabel(0xC4, nodes);
      expect(label, isNotNull);
      expect(label!.text, '0xC4');
      expect(label.resolved, isFalse);
    });

    test('hex fallback is zero-padded and uppercase', () {
      final label = resolveRelayNodeLabel(0x0A, const <MeshNode>[]);
      expect(label, isNotNull);
      expect(label!.text, '0x0A');
      expect(label.resolved, isFalse);
    });

    test('resolves against an empty node set', () {
      final label = resolveRelayNodeLabel(0xC4, const <MeshNode>[]);
      expect(label, isNotNull);
      expect(label!.text, '0xC4');
      expect(label.resolved, isFalse);
    });
  });
}
