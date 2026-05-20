// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Phase 3 Slice D - pins that the engine dispatches send-message /
// send-to-channel callbacks with the firing event's `protocol` tag.
// The production callback in `automation_providers.dart` branches on
// this value to route through Meshtastic's `protocolServiceProvider`
// (legacy) or MeshCore's `meshCoreSessionProvider` (new in Slice D).
// These tests pin the engine -> callback contract; the provider-side
// branching is verified by analyze + e2e sim deploy.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/automations/automation_engine.dart';
import 'package:socialmesh/features/automations/automation_repository.dart';
import 'package:socialmesh/features/automations/models/automation.dart';
import 'package:socialmesh/services/ifttt/ifttt_service.dart';

class _Repo extends AutomationRepository {
  final List<Automation> _items = [];
  final List<AutomationLogEntry> _log = [];

  @override
  List<Automation> get automations => List.unmodifiable(_items);

  @override
  List<AutomationLogEntry> get log => List.unmodifiable(_log);

  void add(Automation a) => _items.add(a);

  @override
  Future<void> recordTrigger(String id) async {}

  @override
  Future<void> addLogEntry(AutomationLogEntry entry) async {
    _log.insert(0, entry);
  }

  @override
  Future<void> clearLog() async => _log.clear();
}

class _NoopIfttt extends IftttService {
  @override
  bool get isActive => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Repo repo;
  late AutomationEngine engine;
  late List<(int, String, TriggerProtocol)> sentMessages;
  late List<(int, String, TriggerProtocol)> sentChannelMessages;

  setUp(() {
    repo = _Repo();
    sentMessages = [];
    sentChannelMessages = [];
    engine = AutomationEngine(
      repository: repo,
      iftttService: _NoopIfttt(),
      onSendMessage: (nodeNum, message, protocol) async {
        sentMessages.add((nodeNum, message, protocol));
        return true;
      },
      onSendToChannel: (channelIndex, message, protocol) async {
        sentChannelMessages.add((channelIndex, message, protocol));
        return true;
      },
    );
  });

  tearDown(() => engine.stop());

  Automation sendMessageAutomation({TriggerProtocolFilter? filter}) {
    return Automation(
      id: 'send-msg',
      name: 'Send a reply',
      trigger: AutomationTrigger(
        type: TriggerType.messageReceived,
        config: filter == null || filter == TriggerProtocolFilter.any
            ? const {}
            : {'protocolFilter': filter.name},
      ),
      actions: const [
        AutomationAction(
          type: ActionType.sendMessage,
          config: {'targetNodeNum': 999, 'messageText': 'echo'},
        ),
      ],
    );
  }

  Automation sendChannelAutomation({TriggerProtocolFilter? filter}) {
    return Automation(
      id: 'send-channel',
      name: 'Broadcast a reply',
      trigger: AutomationTrigger(
        type: TriggerType.channelActivity,
        config: filter == null || filter == TriggerProtocolFilter.any
            ? const {}
            : {'protocolFilter': filter.name},
      ),
      actions: const [
        AutomationAction(
          type: ActionType.sendToChannel,
          config: {'targetChannelIndex': 1, 'messageText': 'echo'},
        ),
      ],
    );
  }

  group('AutomationEngine action routing by protocol', () {
    test(
      'meshcore-filter automation routes sendMessage with protocol=meshcore',
      () async {
        repo.add(sendMessageAutomation(filter: TriggerProtocolFilter.meshcore));

        // Phase 0's gate ensures only meshcore-tagged events reach
        // the action dispatch when filter=meshcore. Slice A's wiring
        // sets the tag from the MeshCore inbound-message handler.
        // Here we simulate that flow by calling processMessage with
        // protocol=meshcore.
        await engine.processMessage(
          AutomationMessage(from: 0xDEADBEEF, text: 'ping', channel: null),
          senderName: 'peer',
          protocol: TriggerProtocol.meshcore,
        );

        expect(sentMessages, hasLength(1));
        expect(sentMessages.first.$1, 999);
        expect(sentMessages.first.$3, TriggerProtocol.meshcore);
      },
    );

    test(
      'meshtastic-filter automation routes sendMessage with protocol=meshtastic',
      () async {
        repo.add(
          sendMessageAutomation(filter: TriggerProtocolFilter.meshtastic),
        );

        await engine.processMessage(
          AutomationMessage(from: 123, text: 'ping', channel: null),
          senderName: 'mt-peer',
          protocol: TriggerProtocol.meshtastic,
        );

        expect(sentMessages, hasLength(1));
        expect(sentMessages.first.$3, TriggerProtocol.meshtastic);
      },
    );

    test(
      'any-filter automation carries event.protocol through to the callback',
      () async {
        repo.add(sendMessageAutomation());

        await engine.processMessage(
          AutomationMessage(from: 101, text: 'a', channel: null),
          senderName: 'peer',
          protocol: TriggerProtocol.meshcore,
        );
        await engine.processMessage(
          AutomationMessage(from: 202, text: 'b', channel: null),
          senderName: 'peer',
          protocol: TriggerProtocol.meshtastic,
        );

        expect(sentMessages, hasLength(2));
        // First fire carried meshcore tag, second carried meshtastic.
        // Routing layer uses this to pick the dispatch path.
        expect(sentMessages[0].$3, TriggerProtocol.meshcore);
        expect(sentMessages[1].$3, TriggerProtocol.meshtastic);
      },
    );

    test(
      'channelActivity sendToChannel action carries event.protocol',
      () async {
        repo.add(sendChannelAutomation(filter: TriggerProtocolFilter.meshcore));

        // channelActivity fires when processMessage receives a
        // message with non-null channel.
        await engine.processMessage(
          AutomationMessage(from: 0xCAFE, text: 'hi', channel: 1),
          senderName: 'peer',
          protocol: TriggerProtocol.meshcore,
        );

        expect(sentChannelMessages, hasLength(1));
        expect(sentChannelMessages.first.$1, 1);
        expect(sentChannelMessages.first.$3, TriggerProtocol.meshcore);
      },
    );

    test(
      'legacy callsites (no protocol arg) default to meshtastic on the callback',
      () async {
        repo.add(sendMessageAutomation());

        // Mirrors the existing app_providers.dart hook that doesn't
        // pass a protocol arg. The Phase 0 default flows through to
        // the callback, so the routing layer never sees a null tag.
        await engine.processMessage(
          AutomationMessage(from: 555, text: 'legacy', channel: null),
          senderName: 'peer',
        );

        expect(sentMessages, hasLength(1));
        expect(sentMessages.first.$3, TriggerProtocol.meshtastic);
      },
    );
  });
}
