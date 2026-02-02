// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/navigation/meshcore_shell.dart';

void main() {
  group('MeshCoreShellIndexNotifier', () {
    test('initial state is 0 (Contacts tab)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final index = container.read(meshCoreShellIndexProvider);
      expect(index, 0);
    });

    test('setIndex updates the selected tab', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(meshCoreShellIndexProvider.notifier);

      // Navigate to Channels (index 1)
      notifier.setIndex(1);
      expect(container.read(meshCoreShellIndexProvider), 1);

      // Navigate to Map (index 2)
      notifier.setIndex(2);
      expect(container.read(meshCoreShellIndexProvider), 2);

      // Navigate to Tools (index 3)
      notifier.setIndex(3);
      expect(container.read(meshCoreShellIndexProvider), 3);

      // Navigate back to Contacts (index 0)
      notifier.setIndex(0);
      expect(container.read(meshCoreShellIndexProvider), 0);
    });
  });
}
