// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Phase 4 Slice B - pins the IFTTT config's `protocolFilter` field
// shape + the runtime gate inside `processMessage`. A user who
// pins their IFTTT setup to `meshcore` should stop receiving
// Meshtastic-sourced webhooks, and vice versa.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/models/trigger_protocol.dart';
import 'package:socialmesh/services/ifttt/ifttt_service.dart';

void main() {
  late IftttService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = IftttService();
    await service.init();
  });

  group('IftttConfig.protocolFilter', () {
    test('defaults to TriggerProtocolFilter.any', () {
      const config = IftttConfig();
      expect(config.protocolFilter, TriggerProtocolFilter.any);
    });

    test('roundtrips through toJson / fromJson for every value', () {
      for (final filter in TriggerProtocolFilter.values) {
        final config = const IftttConfig().copyWith(protocolFilter: filter);
        final json = config.toJson();
        final restored = IftttConfig.fromJson(json);
        expect(restored.protocolFilter, filter, reason: 'roundtrip $filter');
      }
    });

    test('legacy JSON without the key defaults to any (back-compat)', () {
      // A user upgrading from a build before Slice B has no
      // `protocolFilter` in their persisted config. The
      // `fromJson` factory MUST default to `any` so existing IFTTT
      // setups keep firing for both protocols.
      final config = IftttConfig.fromJson(<String, dynamic>{
        'enabled': true,
        'webhookKey': 'legacy-key',
      });
      expect(config.protocolFilter, TriggerProtocolFilter.any);
    });

    test('unknown value falls back to any (forward-compat)', () {
      final config = IftttConfig.fromJson(<String, dynamic>{
        'protocolFilter': 'bogus-value-from-future-build',
      });
      expect(config.protocolFilter, TriggerProtocolFilter.any);
    });

    test('copyWith preserves protocolFilter when not specified', () {
      final original = const IftttConfig().copyWith(
        protocolFilter: TriggerProtocolFilter.meshcore,
      );
      final mutated = original.copyWith(enabled: true);
      expect(mutated.protocolFilter, TriggerProtocolFilter.meshcore);
    });
  });

  group('triggerProtocolFilterMatches', () {
    test('any matches both protocols', () {
      expect(
        triggerProtocolFilterMatches(
          TriggerProtocolFilter.any,
          TriggerProtocol.meshtastic,
        ),
        isTrue,
      );
      expect(
        triggerProtocolFilterMatches(
          TriggerProtocolFilter.any,
          TriggerProtocol.meshcore,
        ),
        isTrue,
      );
    });

    test('meshtastic matches only Meshtastic events', () {
      expect(
        triggerProtocolFilterMatches(
          TriggerProtocolFilter.meshtastic,
          TriggerProtocol.meshtastic,
        ),
        isTrue,
      );
      expect(
        triggerProtocolFilterMatches(
          TriggerProtocolFilter.meshtastic,
          TriggerProtocol.meshcore,
        ),
        isFalse,
      );
    });

    test('meshcore matches only MeshCore events', () {
      expect(
        triggerProtocolFilterMatches(
          TriggerProtocolFilter.meshcore,
          TriggerProtocol.meshtastic,
        ),
        isFalse,
      );
      expect(
        triggerProtocolFilterMatches(
          TriggerProtocolFilter.meshcore,
          TriggerProtocol.meshcore,
        ),
        isTrue,
      );
    });
  });

  group('IftttService.processMessage protocol gate', () {
    test(
      'config pinned to meshcore: meshtastic message no-ops (does not throw)',
      () async {
        await service.saveConfig(
          const IftttConfig(
            enabled: true,
            webhookKey: 'key',
            messageReceived: true,
            protocolFilter: TriggerProtocolFilter.meshcore,
          ),
        );

        // Meshtastic-sourced message should be silently dropped by
        // the gate before any HTTP call. We can't directly observe
        // the HTTP call from here, but the contract is: returns
        // normally without throwing, regardless of the trigger
        // method's webhook outcome.
        await service.processMessage(
          from: 123,
          text: 'hello',
          senderName: 'AlphaNode',
          protocol: TriggerProtocol.meshtastic,
        );
      },
    );

    test(
      'config pinned to meshtastic: meshcore message no-ops (does not throw)',
      () async {
        await service.saveConfig(
          const IftttConfig(
            enabled: true,
            webhookKey: 'key',
            messageReceived: true,
            protocolFilter: TriggerProtocolFilter.meshtastic,
          ),
        );

        await service.processMessage(
          from: 0xDEADBEEF,
          text: 'hello',
          senderName: 'TerryDev2',
          protocol: TriggerProtocol.meshcore,
        );
      },
    );

    test('config any: both protocols pass the gate', () async {
      await service.saveConfig(
        const IftttConfig(
          enabled: true,
          webhookKey: 'key',
          messageReceived: true,
        ),
      );

      await service.processMessage(
        from: 123,
        text: 'hi',
        senderName: 'A',
        protocol: TriggerProtocol.meshtastic,
      );
      await service.processMessage(
        from: 0xDEADBEEF,
        text: 'hi',
        senderName: 'B',
        protocol: TriggerProtocol.meshcore,
      );
    });
  });
}
