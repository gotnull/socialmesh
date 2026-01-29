import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/features/signals/screens/create_signal_screen.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/connectivity_providers.dart';
import 'package:socialmesh/providers/auth_providers.dart';
import 'package:socialmesh/providers/connection_providers.dart';

class _TestNodesNotifier extends NodesNotifier {
  _TestNodesNotifier(this._nodes);

  final Map<int, MeshNode> _nodes;

  @override
  Map<int, MeshNode> build() => _nodes;
}

class _TestMyNodeNumNotifier extends MyNodeNumNotifier {
  _TestMyNodeNumNotifier(this._nodeNum);

  final int? _nodeNum;

  @override
  int? build() => _nodeNum;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Offline: image disabled and offline banner shown', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        isSignedInProvider.overrideWithValue(true),
        isDeviceConnectedProvider.overrideWithValue(true),
        myNodeNumProvider.overrideWith(() => _TestMyNodeNumNotifier(1)),
        nodesProvider.overrideWith(
          () => _TestNodesNotifier({
            1: MeshNode(nodeNum: 1, latitude: 1.0, longitude: 1.0),
          }),
        ),
      ],
    );

    final connNotifier = container.read(connectivityStatusProvider.notifier);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: const CreateSignalScreen()),
      ),
    );

    await tester.pump();

    // Ensure notifier is online so cloud features are available, then go offline
    connNotifier.setOnline(true);
    await tester.pump();

    // Now simulate going offline
    connNotifier.setOnline(false);
    await tester.pump();

    // Offline banner should be visible
    expect(
      find.textContaining('Offline: images and cloud features are unavailable'),
      findsOneWidget,
    );

    // Image icon button should NOT be present when offline (canUseCloud = false)
    final imageIconFinder = find.byIcon(Icons.image_outlined);
    expect(imageIconFinder, findsNothing);

    // Now simulate connectivity returning online
    connNotifier.setOnline(true);
    await tester.pump();

    // Banner should disappear
    expect(
      find.textContaining('Offline: images and cloud features are unavailable'),
      findsNothing,
    );

    // Image icon button should now be present when online
    expect(imageIconFinder, findsOneWidget);

    container.dispose();
  });
}
