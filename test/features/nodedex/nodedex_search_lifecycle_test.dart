// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/nodedex/providers/nodedex_providers.dart';

void main() {
  group('NodeDex UI-state providers reset after unmount', () {
    test('nodeDexSearchProvider resets to empty when no listeners remain', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sub = container.listen(nodeDexSearchProvider, (_, _) {});
      container.read(nodeDexSearchProvider.notifier).setQuery('foo');
      expect(container.read(nodeDexSearchProvider), 'foo');

      sub.close();
      // autoDispose runs at the end of the current frame — simulate by pumping.
      return Future<void>.delayed(Duration.zero).then((_) {
        expect(
          container.read(nodeDexSearchProvider),
          '',
          reason: 'autoDispose must reset query when the screen unmounts',
        );
      });
    });

    test('nodeDexFilterProvider resets to all when no listeners remain', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sub = container.listen(nodeDexFilterProvider, (_, _) {});
      container
          .read(nodeDexFilterProvider.notifier)
          .setFilter(NodeDexFilter.tagged);
      expect(container.read(nodeDexFilterProvider), NodeDexFilter.tagged);

      sub.close();
      return Future<void>.delayed(Duration.zero).then((_) {
        expect(
          container.read(nodeDexFilterProvider),
          NodeDexFilter.all,
          reason: 'autoDispose must reset filter when the screen unmounts',
        );
      });
    });

    test(
      'nodeDexRadioPresetFilterProvider resets to empty when no listeners remain',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final sub = container.listen(
          nodeDexRadioPresetFilterProvider,
          (_, _) {},
        );
        container.read(nodeDexRadioPresetFilterProvider.notifier).toggle(3);
        expect(container.read(nodeDexRadioPresetFilterProvider), {3});

        sub.close();
        return Future<void>.delayed(Duration.zero).then((_) {
          expect(
            container.read(nodeDexRadioPresetFilterProvider),
            isEmpty,
            reason:
                'autoDispose must reset preset filter when the screen unmounts',
          );
        });
      },
    );
  });
}
