// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Phase 3 Slice E - pins that scheduled triggers with a pinned
// `protocolFilter` (meshcore / meshtastic) actually fire AND route
// their actions via the right protocol.
//
// Without the gate bypass + `_routingProtocol` helper introduced in
// Slice E, a `protocolFilter=meshcore` scheduled automation would
// never fire — the gate would reject because the scheduled event
// carries the default `protocol=meshtastic` placeholder. Slice E
// makes the gate skip the protocol check for scheduled events and
// derives the dispatch protocol from the automation's own filter
// instead of from the event's source protocol tag.

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

Automation _scheduledAutomation({
  required String id,
  required TriggerProtocolFilter filter,
}) {
  return Automation(
    id: id,
    name: id,
    trigger: AutomationTrigger(
      type: TriggerType.scheduled,
      config: filter == TriggerProtocolFilter.any
          ? const {'schedule': 'daily:9:0'}
          : {'schedule': 'daily:9:0', 'protocolFilter': filter.name},
    ),
    actions: const [
      AutomationAction(
        type: ActionType.sendMessage,
        config: {'targetNodeNum': 999, 'messageText': 'ping'},
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Repo repo;
  late AutomationEngine engine;
  late List<(int, String, TriggerProtocol)> sentMessages;

  setUp(() {
    repo = _Repo();
    sentMessages = [];
    engine = AutomationEngine(
      repository: repo,
      iftttService: _NoopIfttt(),
      onSendMessage: (nodeNum, message, protocol) async {
        sentMessages.add((nodeNum, message, protocol));
        return true;
      },
      onSendToChannel: (_, _, _) async => true,
    );
  });

  tearDown(() => engine.stop());

  group('scheduled-trigger protocol override (Slice E)', () {
    test(
      'meshcore-pinned scheduled trigger FIRES (gate no longer rejects)',
      () async {
        repo.add(
          _scheduledAutomation(
            id: 'sched-meshcore',
            filter: TriggerProtocolFilter.meshcore,
          ),
        );

        // Build the scheduled AutomationEvent with its default
        // protocol (meshtastic placeholder). Pre-Slice-E this would
        // be filtered out by `matchesProtocol` because the trigger
        // is pinned to meshcore.
        final event = AutomationEvent(
          type: TriggerType.scheduled,
          scheduleId: 'sched-meshcore',
          slotKey: 'daily:2026-05-20T09:00+10:00',
        );
        await engine.executeAutomationManually(repo.automations.first, event);

        expect(sentMessages, hasLength(1));
      },
    );

    test(
      'meshcore-pinned scheduled action routes with TriggerProtocol.meshcore',
      () async {
        repo.add(
          _scheduledAutomation(
            id: 'sched-meshcore',
            filter: TriggerProtocolFilter.meshcore,
          ),
        );

        final event = AutomationEvent(
          type: TriggerType.scheduled,
          scheduleId: 'sched-meshcore',
          slotKey: 'daily:2026-05-20T09:00+10:00',
        );
        await engine.executeAutomationManually(repo.automations.first, event);

        // The action's protocol arg comes from the automation's
        // filter (not from event.protocol which defaults to
        // meshtastic) — that's the Slice E override.
        expect(sentMessages.first.$3, TriggerProtocol.meshcore);
      },
    );

    test(
      'meshtastic-pinned scheduled action routes with TriggerProtocol.meshtastic',
      () async {
        repo.add(
          _scheduledAutomation(
            id: 'sched-mt',
            filter: TriggerProtocolFilter.meshtastic,
          ),
        );

        final event = AutomationEvent(
          type: TriggerType.scheduled,
          scheduleId: 'sched-mt',
          slotKey: 'daily:2026-05-20T09:00+10:00',
        );
        await engine.executeAutomationManually(repo.automations.first, event);

        expect(sentMessages.first.$3, TriggerProtocol.meshtastic);
      },
    );

    test(
      'any-filter scheduled action keeps the event.protocol default (back-compat)',
      () async {
        repo.add(
          _scheduledAutomation(
            id: 'sched-any',
            filter: TriggerProtocolFilter.any,
          ),
        );

        final event = AutomationEvent(
          type: TriggerType.scheduled,
          scheduleId: 'sched-any',
          slotKey: 'daily:2026-05-20T09:00+10:00',
        );
        await engine.executeAutomationManually(repo.automations.first, event);

        // any-filter falls through to event.protocol. The default
        // (meshtastic) preserves legacy behaviour for scheduled
        // automations created before Slice E.
        expect(sentMessages.first.$3, TriggerProtocol.meshtastic);
      },
    );
  });
}
