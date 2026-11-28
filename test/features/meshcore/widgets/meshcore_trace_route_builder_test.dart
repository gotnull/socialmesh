// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/meshcore/widgets/meshcore_trace_route_builder.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';

class _Radio extends Notifier<String> {
  @override
  String build() => '';

  void connect(String prefix) => state = prefix;
}

final _radio = NotifierProvider<_Radio, String>(_Radio.new);

MeshCoreTraceRouteHop _hop(int b) =>
    MeshCoreTraceRouteHop(key: Uint8List.fromList([b]));

void main() {
  test('a route survives a reconnect but not a different radio', () {
    final container = ProviderContainer(
      overrides: [
        meshCoreSelfPubKeyPrefixProvider.overrideWith(
          (ref) => ref.watch(_radio),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(meshCoreTraceRouteProvider, (_, _) {});
    List<MeshCoreTraceRouteHop> hops() =>
        container.read(meshCoreTraceRouteProvider).hops;
    final radio = container.read(_radio.notifier);

    radio.connect('aabbccdd');
    container.read(meshCoreTraceRouteProvider.notifier).add(_hop(0xA0));
    expect(hops(), hasLength(1));

    radio.connect('');
    container.read(_radio);
    expect(hops(), hasLength(1));
    radio.connect('aabbccdd');
    container.read(_radio);
    expect(hops(), hasLength(1));

    radio.connect('11223344');
    container.read(_radio);
    expect(hops(), isEmpty);
  });

  test('moving, reversing and removing hops', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(meshCoreTraceRouteProvider.notifier);
    List<int> order() => [
      for (final h in container.read(meshCoreTraceRouteProvider).hops)
        h.key.first,
    ];
    for (final b in [1, 2, 3]) {
      notifier.add(_hop(b));
    }

    // ReorderableListView counts the target index before removal.
    notifier.move(0, 3);
    expect(order(), [2, 3, 1]);
    notifier.move(2, 0);
    expect(order(), [1, 2, 3]);
    notifier.reverse();
    expect(order(), [3, 2, 1]);
    notifier.removeAt(1);
    expect(order(), [3, 1]);
    notifier.clear();
    expect(order(), isEmpty);
  });

  test('a typed prefix is 1, 2 or 4 bytes of hex', () {
    expect(parseMeshCoreTraceHopPrefix('a3'), [0xA3]);
    expect(parseMeshCoreTraceHopPrefix('A3 f1'), [0xA3, 0xF1]);
    expect(parseMeshCoreTraceHopPrefix('01020304'), [1, 2, 3, 4]);
    expect(parseMeshCoreTraceHopPrefix('abc'), isNull);
    expect(parseMeshCoreTraceHopPrefix('a3f1c2'), isNull);
    expect(parseMeshCoreTraceHopPrefix('ridge'), isNull);
    expect(parseMeshCoreTraceHopPrefix(''), isNull);
  });

  test('a typed hop shorter than the hash size blocks the request', () {
    const draft = MeshCoreTraceRouteDraft();
    final route = draft.copyWith(hops: [_hop(0xEE)]);
    expect(route.request?.path, [0xEE]);
    expect(route.copyWith(hashSize: 2).request, isNull);
  });
}
