// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Phase 0 protocol-filter gating. Pins three invariants:
//   - A trigger with no `protocolFilter` (legacy automations) fires on
//     both Meshtastic and MeshCore events.
//   - A trigger pinned to `meshtastic` fires on Meshtastic events and
//     stays silent on MeshCore-tagged events.
//   - A trigger pinned to `meshcore` fires on MeshCore events and
//     stays silent on Meshtastic-tagged events.
//
// These tests live one layer below the wiring (Phase 3) so we can
// regression-pin the gate logic alone without re-running the entire
// event source.

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

class _NoopIftttService extends IftttService {
  @override
  bool get isActive => false;
}

Automation _messageReceivedAutomation({
  required String id,
  required TriggerProtocolFilter filter,
}) {
  return Automation(
    id: id,
    name: id,
    trigger: AutomationTrigger(
      type: TriggerType.messageReceived,
      config: filter == TriggerProtocolFilter.any
          ? const {}
          : {'protocolFilter': filter.name},
    ),
    actions: const [
      AutomationAction(
        type: ActionType.sendMessage,
        config: {'targetNodeNum': 999, 'messageText': 'fired'},
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Repo repo;
  late AutomationEngine engine;
  late List<String> fired;

  setUp(() {
    repo = _Repo();
    fired = [];
    engine = AutomationEngine(
      repository: repo,
      iftttService: _NoopIftttService(),
      onSendMessage: (_, _, _) async {
        fired.add('msg');
        return true;
      },
      onSendToChannel: (_, _, _) async => true,
    );
  });

  tearDown(() => engine.stop());

  group('AutomationTrigger.protocolFilter', () {
    test('legacy automations (no protocolFilter key) default to any', () {
      const t = AutomationTrigger(type: TriggerType.messageReceived);
      expect(t.protocolFilter, TriggerProtocolFilter.any);
      expect(t.matchesProtocol(TriggerProtocol.meshtastic), isTrue);
      expect(t.matchesProtocol(TriggerProtocol.meshcore), isTrue);
    });

    test('meshtastic filter only matches Meshtastic events', () {
      const t = AutomationTrigger(
        type: TriggerType.messageReceived,
        config: {'protocolFilter': 'meshtastic'},
      );
      expect(t.matchesProtocol(TriggerProtocol.meshtastic), isTrue);
      expect(t.matchesProtocol(TriggerProtocol.meshcore), isFalse);
    });

    test('meshcore filter only matches MeshCore events', () {
      const t = AutomationTrigger(
        type: TriggerType.messageReceived,
        config: {'protocolFilter': 'meshcore'},
      );
      expect(t.matchesProtocol(TriggerProtocol.meshtastic), isFalse);
      expect(t.matchesProtocol(TriggerProtocol.meshcore), isTrue);
    });

    test('unknown protocolFilter value falls back to any', () {
      const t = AutomationTrigger(
        type: TriggerType.messageReceived,
        config: {'protocolFilter': 'bogus_value_from_future_build'},
      );
      expect(t.protocolFilter, TriggerProtocolFilter.any);
      expect(t.matchesProtocol(TriggerProtocol.meshtastic), isTrue);
      expect(t.matchesProtocol(TriggerProtocol.meshcore), isTrue);
    });

    test('JSON round-trip preserves protocolFilter', () {
      const t = AutomationTrigger(
        type: TriggerType.messageReceived,
        config: {'protocolFilter': 'meshcore'},
      );
      final json = t.toJson();
      final restored = AutomationTrigger.fromJson(json);
      expect(restored.protocolFilter, TriggerProtocolFilter.meshcore);
    });
  });

  group('AutomationEngine gating on protocolFilter', () {
    // Use distinct senders per call so the engine's per-sender dedupe
    // key (`messageReceived_node{from}`) doesn't throttle the second
    // fire — throttling is orthogonal to protocol filtering and not
    // what these tests pin.
    AutomationMessage msg(int from) =>
        AutomationMessage(from: from, text: 'hi', channel: null);

    test('any-filter automation fires on both protocols', () async {
      repo.add(
        _messageReceivedAutomation(
          id: 'any',
          filter: TriggerProtocolFilter.any,
        ),
      );

      await engine.processMessage(
        msg(101),
        senderName: 'a',
        protocol: TriggerProtocol.meshtastic,
      );
      await engine.processMessage(
        msg(202),
        senderName: 'a',
        protocol: TriggerProtocol.meshcore,
      );

      expect(fired, hasLength(2));
    });

    test(
      'meshtastic-filter automation fires only on Meshtastic events',
      () async {
        repo.add(
          _messageReceivedAutomation(
            id: 'mt-only',
            filter: TriggerProtocolFilter.meshtastic,
          ),
        );

        await engine.processMessage(
          msg(101),
          senderName: 'a',
          protocol: TriggerProtocol.meshcore,
        );
        expect(fired, isEmpty);

        await engine.processMessage(
          msg(202),
          senderName: 'a',
          protocol: TriggerProtocol.meshtastic,
        );
        expect(fired, hasLength(1));
      },
    );

    test('meshcore-filter automation fires only on MeshCore events', () async {
      repo.add(
        _messageReceivedAutomation(
          id: 'mc-only',
          filter: TriggerProtocolFilter.meshcore,
        ),
      );

      await engine.processMessage(
        msg(101),
        senderName: 'a',
        protocol: TriggerProtocol.meshtastic,
      );
      expect(fired, isEmpty);

      await engine.processMessage(
        msg(202),
        senderName: 'a',
        protocol: TriggerProtocol.meshcore,
      );
      expect(fired, hasLength(1));
    });

    test(
      'existing Meshtastic call sites (no protocol arg) still fire any-filter',
      () async {
        repo.add(
          _messageReceivedAutomation(
            id: 'any',
            filter: TriggerProtocolFilter.any,
          ),
        );

        // No protocol arg defaults to meshtastic. Regression pin for
        // legacy app_providers.dart call sites.
        await engine.processMessage(msg(101), senderName: 'a');
        expect(fired, hasLength(1));
      },
    );
  });
}
