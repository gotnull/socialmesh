// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The collapsed app bar shows the same avatar as the hero header once the
// user scrolls, so both must resolve the node's identity colour. Our own
// node is no exception: peers see it in its identity colour too.
void main() {
  late String source;

  setUpAll(() {
    final file = File('lib/features/nodes/node_detail_screen.dart');
    expect(file.existsSync(), true);
    source = file.readAsStringSync();
  });

  test('every NodeAvatar resolves the identity colour', () {
    final avatars = RegExp(r'NodeAvatar\(([^()]|\([^()]*\))*\)')
        .allMatches(source)
        .map((m) => m.group(0)!)
        .toList();

    expect(avatars, hasLength(2), reason: 'hero and collapsed app bar');
    for (final avatar in avatars) {
      expect(
        avatar.contains('accentColor'),
        false,
        reason: 'NodeAvatar must not use the accent colour: $avatar',
      );
    }
    final collapsed = avatars.singleWhere((a) => a.contains('size: 28'));
    expect(collapsed, contains('_getAvatarColor(node)'));
  });
}
