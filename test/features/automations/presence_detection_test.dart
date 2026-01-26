import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/automations/automation_engine.dart';
import 'package:socialmesh/features/automations/automation_repository.dart';
import 'package:socialmesh/features/automations/models/automation.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/models/presence_confidence.dart';
import 'package:socialmesh/services/ifttt/ifttt_service.dart';

class QuickMockRepository extends AutomationRepository {
  final List<Automation> _automations = [];
  final List<AutomationLogEntry> _log = [];

  @override
  List<Automation> get automations => List.unmodifiable(_automations);

  @override
  List<AutomationLogEntry> get log => List.unmodifiable(_log);

  void addTestAutomation(Automation a) => _automations.add(a);

  @override
  Future<void> recordTrigger(String id) async {}

  @override
  Future<void> addLogEntry(AutomationLogEntry entry) async {
    _log.insert(0, entry);
  }

  @override
  Future<void> clearLog() async => _log.clear();
}

void main() {
  late QuickMockRepository repo;
  late IftttService ifttt;
  late AutomationEngine engine;
  late List<(int, String)> sentMessages;

  setUp(() {
    repo = QuickMockRepository();
    ifttt = IftttService();
    sentMessages = [];

    engine = AutomationEngine(
      repository: repo,
      iftttService: ifttt,
      onSendMessage: (nodeNum, message) async {
        sentMessages.add((nodeNum, message));
        return true;
      },
    );
  });

  tearDown(() {
    engine.stop();
  });

  test(
    'processPresenceUpdate triggers nodeOnline automation when becoming active',
    () async {
      final automation = Automation(
        id: 'presence-online-test',
        name: 'Presence Online Test',
        trigger: const AutomationTrigger(type: TriggerType.nodeOnline),
        actions: const [
          AutomationAction(
            type: ActionType.sendMessage,
            config: {'targetNodeNum': 999, 'messageText': 'Node came online'},
          ),
        ],
      );
      repo.addTestAutomation(automation);

      final node = MeshNode(nodeNum: 77, longName: 'PresenceNode');

      await engine.processPresenceUpdate(
        node,
        previous: PresenceConfidence.stale,
        current: PresenceConfidence.active,
      );

      expect(sentMessages, isNotEmpty);
      expect(sentMessages.first.$1, 999);
    },
  );

  test(
    'processPresenceUpdate triggers nodeOffline automation when becoming inactive',
    () async {
      final automation = Automation(
        id: 'presence-offline-test',
        name: 'Presence Offline Test',
        trigger: const AutomationTrigger(type: TriggerType.nodeOffline),
        actions: const [
          AutomationAction(
            type: ActionType.sendMessage,
            config: {'targetNodeNum': 999, 'messageText': 'Node went offline'},
          ),
        ],
      );
      repo.addTestAutomation(automation);

      final node = MeshNode(nodeNum: 88, longName: 'PresenceNode2');

      await engine.processPresenceUpdate(
        node,
        previous: PresenceConfidence.active,
        current: PresenceConfidence.stale,
      );

      expect(sentMessages, isNotEmpty);
      expect(sentMessages.first.$1, 999);
    },
  );
}
