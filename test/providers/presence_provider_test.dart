import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:socialmesh/features/automations/automation_engine.dart';
import 'package:socialmesh/features/automations/automation_repository.dart';
import 'package:socialmesh/features/automations/automation_providers.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/models/presence_confidence.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/presence_providers.dart';
import 'package:socialmesh/services/ifttt/ifttt_service.dart';

class _TestNodesNotifier extends NodesNotifier {
  @override
  Map<int, MeshNode> build() => {};

  void setNodes(Map<int, MeshNode> nodes) {
    state = nodes;
  }
}

AutomationEngine _noopAutomationEngine() {
  return AutomationEngine(
    repository: AutomationRepository(),
    iftttService: IftttService(),
  );
}

void main() {
  test('presence transitions follow lastHeard aging', () {
    var now = DateTime(2026, 1, 24, 12, 0, 0);
    final container = ProviderContainer(
      overrides: [
        nodesProvider.overrideWith(_TestNodesNotifier.new),
        iftttServiceProvider.overrideWithValue(IftttService()),
        automationEngineProvider.overrideWithValue(_noopAutomationEngine()),
        presenceClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);

    final nodesNotifier =
        container.read(nodesProvider.notifier) as _TestNodesNotifier;

    nodesNotifier.setNodes({1: MeshNode(nodeNum: 1, lastHeard: now)});
    container.read(presenceMapProvider.notifier).recomputeNow();
    expect(
      container.read(presenceMapProvider)[1]!.confidence,
      PresenceConfidence.active,
    );

    now = now.add(const Duration(minutes: 5));
    nodesNotifier.setNodes({
      1: MeshNode(
        nodeNum: 1,
        lastHeard: now.subtract(const Duration(minutes: 5)),
      ),
    });
    container.read(presenceMapProvider.notifier).recomputeNow();
    expect(
      container.read(presenceMapProvider)[1]!.confidence,
      PresenceConfidence.fading,
    );

    now = now.add(const Duration(minutes: 15));
    nodesNotifier.setNodes({
      1: MeshNode(
        nodeNum: 1,
        lastHeard: now.subtract(const Duration(minutes: 20)),
      ),
    });
    container.read(presenceMapProvider.notifier).recomputeNow();
    expect(
      container.read(presenceMapProvider)[1]!.confidence,
      PresenceConfidence.stale,
    );

    now = now.add(const Duration(hours: 2));
    nodesNotifier.setNodes({
      1: MeshNode(
        nodeNum: 1,
        lastHeard: now.subtract(const Duration(hours: 2)),
      ),
    });
    container.read(presenceMapProvider.notifier).recomputeNow();
    expect(
      container.read(presenceMapProvider)[1]!.confidence,
      PresenceConfidence.unknown,
    );
  });

  test('node does not return to active without a new packet', () {
    var now = DateTime(2026, 1, 24, 12, 0, 0);
    final container = ProviderContainer(
      overrides: [
        nodesProvider.overrideWith(_TestNodesNotifier.new),
        iftttServiceProvider.overrideWithValue(IftttService()),
        automationEngineProvider.overrideWithValue(_noopAutomationEngine()),
        presenceClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);

    final nodesNotifier =
        container.read(nodesProvider.notifier) as _TestNodesNotifier;

    final lastHeard = now.subtract(const Duration(minutes: 25));
    nodesNotifier.setNodes({1: MeshNode(nodeNum: 1, lastHeard: lastHeard)});
    container.read(presenceMapProvider.notifier).recomputeNow();

    final confidence = container.read(presenceMapProvider)[1]!.confidence;
    expect(confidence, isNot(PresenceConfidence.active));

    now = now.add(const Duration(minutes: 10));
    nodesNotifier.setNodes({1: MeshNode(nodeNum: 1, lastHeard: lastHeard)});
    container.read(presenceMapProvider.notifier).recomputeNow();
    final confidenceAgain = container.read(presenceMapProvider)[1]!.confidence;
    expect(confidenceAgain, isNot(PresenceConfidence.active));
  });

  test('presence decays over time without new packets', () {
    var now = DateTime(2026, 1, 24, 12, 0, 0);
    final container = ProviderContainer(
      overrides: [
        nodesProvider.overrideWith(_TestNodesNotifier.new),
        iftttServiceProvider.overrideWithValue(IftttService()),
        automationEngineProvider.overrideWithValue(_noopAutomationEngine()),
        presenceClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);

    final nodesNotifier =
        container.read(nodesProvider.notifier) as _TestNodesNotifier;

    nodesNotifier.setNodes({1: MeshNode(nodeNum: 1, lastHeard: now)});
    container.read(presenceMapProvider.notifier).recomputeNow();
    expect(
      container.read(presenceMapProvider)[1]!.confidence,
      PresenceConfidence.active,
    );

    now = now.add(const Duration(minutes: 3));
    container.read(presenceMapProvider.notifier).recomputeNow();
    expect(
      container.read(presenceMapProvider)[1]!.confidence,
      PresenceConfidence.fading,
    );

    now = now.add(const Duration(minutes: 10));
    container.read(presenceMapProvider.notifier).recomputeNow();
    expect(
      container.read(presenceMapProvider)[1]!.confidence,
      PresenceConfidence.stale,
    );

    now = now.add(const Duration(minutes: 60));
    container.read(presenceMapProvider.notifier).recomputeNow();
    expect(
      container.read(presenceMapProvider)[1]!.confidence,
      PresenceConfidence.unknown,
    );
  });
}
