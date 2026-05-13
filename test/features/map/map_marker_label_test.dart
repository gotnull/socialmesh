// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/map/map_screen.dart';
import 'package:socialmesh/models/mesh_models.dart';

/// Behavioural tests for the Sprint 4 mesh-map node label helper.
///
/// Pre-Sprint-4 the marker rendered just `shortName[0]` so a node
/// labelled "MYSO" collapsed to "M", with no way to distinguish it
/// from "MOJO" or "MILK". The helper now returns the full shortName
/// (capped at 4 chars per Meshtastic spec) and falls back to the last
/// 4 hex digits of nodeNum when no shortName is set.
MeshNode _node({int nodeNum = 0x1234ABCD, String? shortName}) =>
    MeshNode(nodeNum: nodeNum, shortName: shortName, longName: 'longname');

void main() {
  group('nodeMarkerLabel', () {
    test('returns the full shortName up to 4 chars, upper-cased', () {
      expect(nodeMarkerLabel(_node(shortName: 'myso')), 'MYSO');
      expect(nodeMarkerLabel(_node(shortName: 'Ab')), 'AB');
      expect(nodeMarkerLabel(_node(shortName: 'X')), 'X');
    });

    test(
      'caps shortName at 4 grapheme clusters (defends against bad firmware)',
      () {
        expect(nodeMarkerLabel(_node(shortName: 'TooLong')), 'TOOL');
      },
    );

    test('falls back to last 4 hex digits when shortName is null or empty', () {
      // nodeNum 0x1234ABCD → hex "1234abcd" → last 4 → "abcd" → "ABCD"
      expect(nodeMarkerLabel(_node(nodeNum: 0x1234ABCD)), 'ABCD');
      expect(
        nodeMarkerLabel(_node(nodeNum: 0x1234ABCD, shortName: '')),
        'ABCD',
      );
    });

    test('zero-pads small node numbers before truncating', () {
      // nodeNum 0xAB → hex "ab" → padLeft(8, "0") → "000000ab" → "00AB"
      expect(nodeMarkerLabel(_node(nodeNum: 0xAB)), '00AB');
    });

    test(
      'handles grapheme clusters (emoji + combining marks) without slicing them',
      () {
        // Emoji is one grapheme cluster but two code units. We must not
        // split it mid-cluster. The result must contain the full emoji.
        expect(nodeMarkerLabel(_node(shortName: '🛰️')), '🛰️'.toUpperCase());
      },
    );

    test('upper-cases regardless of input case', () {
      expect(nodeMarkerLabel(_node(shortName: 'abcd')), 'ABCD');
      expect(nodeMarkerLabel(_node(shortName: 'aBcD')), 'ABCD');
    });
  });
}
