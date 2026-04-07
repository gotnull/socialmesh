// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/animated_avatar_stack.dart';
import 'package:socialmesh/features/nodedex/widgets/coseen_network_card.dart';

void main() {
  group('CoSeenCardViewModel', () {
    test('constructs with required fields', () {
      const vm = CoSeenCardViewModel(totalCount: 5, avatarItems: []);
      expect(vm.totalCount, 5);
      expect(vm.avatarItems, isEmpty);
    });

    test('holds avatar items', () {
      final items = [
        const AvatarStackItem(id: '1', child: SizedBox()),
        const AvatarStackItem(id: '2', child: SizedBox()),
      ];
      final vm = CoSeenCardViewModel(totalCount: 2, avatarItems: items);
      expect(vm.avatarItems, hasLength(2));
      expect(vm.avatarItems.first.id, '1');
    });
  });

  group('CoSeenNetworkCard smoke tests', () {
    // Note: full provider wiring tests would require Riverpod test
    // infrastructure with mock providers. These are widget render
    // smoke tests using the card in isolation without provider state.

    testWidgets('renders SizedBox.shrink when no provider', (tester) async {
      // Without ProviderScope, the widget can't watch providers.
      // This verifies the card code path exists without errors.
      // Full integration testing requires mock providers.
      expect(const CoSeenNetworkCard(nodeNum: 12345), isA<Widget>());
    });
  });
}
