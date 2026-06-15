// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the cross-protocol compatibility matrix to the categorisation
// documented in `docs/engineering/MESHCORE_PROTOCOL_COMPATIBILITY.md`.
// When a new TriggerType / ActionType / DashboardWidgetType is added,
// these tests fail until the new value gets an explicit row in both
// the doc + the corresponding `supportOn` extension method. That keeps
// the matrix doc from silently drifting away from the code.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/automations/models/automation.dart';
import 'package:socialmesh/features/dashboard/models/dashboard_widget_config.dart';
import 'package:socialmesh/services/ifttt/ifttt_service.dart';

void main() {
  group('TriggerType.supportOn', () {
    test('every TriggerType is supported on Meshtastic', () {
      for (final t in TriggerType.values) {
        expect(
          t.supportOn(TriggerProtocol.meshtastic),
          ProtocolSupport.supported,
          reason: 'TriggerType.$t should be fully supported on Meshtastic',
        );
      }
    });

    test('Meshtastic-only triggers report unsupported on MeshCore', () {
      const meshtasticOnly = <TriggerType>{
        TriggerType.batteryLow,
        TriggerType.batteryFull,
        TriggerType.detectionSensor,
      };
      for (final t in meshtasticOnly) {
        expect(
          t.supportOn(TriggerProtocol.meshcore),
          ProtocolSupport.unsupported,
          reason:
              'TriggerType.$t depends on data MeshCore does not surface; '
              'must report unsupported so the picker hides it',
        );
      }
    });

    test('partial-support triggers on MeshCore', () {
      const partialOnMeshCore = <TriggerType>{
        TriggerType.nodeOnline,
        TriggerType.nodeOffline,
        TriggerType.positionChanged,
        TriggerType.geofenceEnter,
        TriggerType.geofenceExit,
      };
      for (final t in partialOnMeshCore) {
        expect(
          t.supportOn(TriggerProtocol.meshcore),
          ProtocolSupport.partial,
          reason:
              'TriggerType.$t fires on MeshCore only when the underlying '
              'data happens to exist; must report partial so the picker '
              "tags it with a 'Limited on MeshCore' chip",
        );
      }
    });

    test('fully-supported triggers on MeshCore (Phase 3 Slices A-E)', () {
      const fullySupported = <TriggerType>{
        TriggerType.messageReceived,
        TriggerType.messageContains,
        TriggerType.nodeSilent,
        TriggerType.scheduled,
        TriggerType.signalWeak,
        TriggerType.channelActivity,
        TriggerType.manual,
      };
      for (final t in fullySupported) {
        expect(
          t.supportOn(TriggerProtocol.meshcore),
          ProtocolSupport.supported,
          reason: 'TriggerType.$t should be fully supported on MeshCore',
        );
      }
    });

    test('every TriggerType has an explicit categorisation', () {
      // Catches a new TriggerType added without a corresponding row in
      // `supportOn`. The switch in the extension is exhaustive so the
      // analyzer would already catch this, but the explicit test gives
      // a clearer failure message.
      const accountedFor = <TriggerType>{
        // Meshtastic-only / unsupported
        TriggerType.batteryLow,
        TriggerType.batteryFull,
        TriggerType.detectionSensor,
        // Partial
        TriggerType.nodeOnline,
        TriggerType.nodeOffline,
        TriggerType.positionChanged,
        TriggerType.geofenceEnter,
        TriggerType.geofenceExit,
        // Supported
        TriggerType.messageReceived,
        TriggerType.messageContains,
        TriggerType.nodeSilent,
        TriggerType.scheduled,
        TriggerType.signalWeak,
        TriggerType.channelActivity,
        TriggerType.manual,
      };
      final missing = TriggerType.values.toSet().difference(accountedFor);
      expect(
        missing,
        isEmpty,
        reason:
            'New TriggerType detected without a compatibility row: '
            "${missing.map((t) => t.name).join(', ')}. "
            'Update MESHCORE_PROTOCOL_COMPATIBILITY.md + add to '
            'TriggerTypeProtocolSupport.supportOn + add to this test.',
      );
    });
  });

  group('ActionType.supportOn', () {
    test('every ActionType is supported on Meshtastic', () {
      for (final a in ActionType.values) {
        expect(
          a.supportOn(TriggerProtocol.meshtastic),
          ProtocolSupport.supported,
        );
      }
    });

    test('updateWidget is partial on MeshCore', () {
      expect(
        ActionType.updateWidget.supportOn(TriggerProtocol.meshcore),
        ProtocolSupport.partial,
        reason:
            'updateWidget partial-supports MeshCore: depends on the '
            'target widget having a MeshCore renderer',
      );
    });

    test('all other actions are fully supported on MeshCore', () {
      const fullySupported = <ActionType>{
        ActionType.sendMessage,
        ActionType.sendToChannel,
        ActionType.playSound,
        ActionType.vibrate,
        ActionType.pushNotification,
        ActionType.triggerWebhook,
        ActionType.logEvent,
        ActionType.triggerShortcut,
      };
      for (final a in fullySupported) {
        expect(
          a.supportOn(TriggerProtocol.meshcore),
          ProtocolSupport.supported,
          reason: 'ActionType.$a should be supported on MeshCore',
        );
      }
    });

    test('every ActionType has an explicit categorisation', () {
      const accountedFor = <ActionType>{
        ActionType.updateWidget,
        ActionType.sendMessage,
        ActionType.sendToChannel,
        ActionType.playSound,
        ActionType.vibrate,
        ActionType.pushNotification,
        ActionType.triggerWebhook,
        ActionType.logEvent,
        ActionType.triggerShortcut,
      };
      final missing = ActionType.values.toSet().difference(accountedFor);
      expect(missing, isEmpty);
    });
  });

  group('DashboardWidgetType.supportOn', () {
    test('every DashboardWidgetType is supported on Meshtastic', () {
      for (final w in DashboardWidgetType.values) {
        expect(
          w.supportOn(TriggerProtocol.meshtastic),
          ProtocolSupport.supported,
        );
      }
    });

    test('widgets with a MeshCore renderer report supported', () {
      const meshCoreReady = <DashboardWidgetType>{
        // Pack Phase 2 v1
        DashboardWidgetType.networkOverview,
        DashboardWidgetType.recentMessages,
        DashboardWidgetType.nearbyNodes,
        DashboardWidgetType.custom,
        // Pack Phase 2 v2: Dashboard v2 additions
        DashboardWidgetType.signalStrength,
        DashboardWidgetType.channelActivity,
        DashboardWidgetType.meshHealth,
        DashboardWidgetType.nodeMap,
        // quickCompose: semantic-equivalent to MeshCore's pre-existing
        // quickActions widget; same role, different enum name on the
        // MeshCore side.
        DashboardWidgetType.quickCompose,
      };
      for (final w in meshCoreReady) {
        expect(
          w.supportOn(TriggerProtocol.meshcore),
          ProtocolSupport.supported,
          reason:
              'DashboardWidgetType.$w has a MeshCore-side renderer; must '
              'report supported',
        );
      }
    });

    test('environmentMetrics still reports unsupported on MeshCore', () {
      // MeshCore wire protocol does not exchange peer telemetry the way
      // Meshtastic's TELEMETRY_APP portnum does, so a MeshCore-side
      // environment renderer would have no data to render. Stay
      // unsupported until a future MeshCore telemetry feature ships.
      expect(
        DashboardWidgetType.environmentMetrics.supportOn(
          TriggerProtocol.meshcore,
        ),
        ProtocolSupport.unsupported,
      );
    });

    test('every DashboardWidgetType has an explicit categorisation', () {
      const accountedFor = <DashboardWidgetType>{
        DashboardWidgetType.networkOverview,
        DashboardWidgetType.recentMessages,
        DashboardWidgetType.nearbyNodes,
        DashboardWidgetType.custom,
        DashboardWidgetType.signalStrength,
        DashboardWidgetType.channelActivity,
        DashboardWidgetType.meshHealth,
        DashboardWidgetType.quickCompose,
        DashboardWidgetType.nodeMap,
        DashboardWidgetType.environmentMetrics,
      };
      final missing = DashboardWidgetType.values.toSet().difference(
        accountedFor,
      );
      expect(missing, isEmpty);
    });
  });

  group('IftttTriggerType.supportOn', () {
    test('every IftttTriggerType is supported on Meshtastic', () {
      for (final t in IftttTriggerType.values) {
        expect(
          t.supportOn(TriggerProtocol.meshtastic),
          ProtocolSupport.supported,
          reason: 'IftttTriggerType.$t should be fully supported on Meshtastic',
        );
      }
    });

    test('Meshtastic-only IFTTT triggers report unsupported on MeshCore', () {
      const meshtasticOnly = <IftttTriggerType>{
        IftttTriggerType.batteryLow,
        IftttTriggerType.temperatureAlert,
      };
      for (final t in meshtasticOnly) {
        expect(
          t.supportOn(TriggerProtocol.meshcore),
          ProtocolSupport.unsupported,
          reason:
              'IftttTriggerType.$t depends on telemetry MeshCore does not '
              'exchange peer-to-peer; must report unsupported so the IFTTT '
              'config screen hides the row when MeshCore-pinned',
        );
      }
    });

    test('partial-support IFTTT triggers on MeshCore', () {
      const partialOnMeshCore = <IftttTriggerType>{
        IftttTriggerType.nodeOnline,
        IftttTriggerType.nodeOffline,
        IftttTriggerType.positionUpdate,
      };
      for (final t in partialOnMeshCore) {
        expect(
          t.supportOn(TriggerProtocol.meshcore),
          ProtocolSupport.partial,
          reason:
              'IftttTriggerType.$t fires on MeshCore only when the '
              "underlying data exists; must report partial so the row "
              "renders with a 'Limited on MeshCore' warning",
        );
      }
    });

    test('fully-supported IFTTT triggers on MeshCore', () {
      const fullySupported = <IftttTriggerType>{
        IftttTriggerType.messageReceived,
        IftttTriggerType.sosEmergency,
      };
      for (final t in fullySupported) {
        expect(
          t.supportOn(TriggerProtocol.meshcore),
          ProtocolSupport.supported,
          reason: 'IftttTriggerType.$t should be fully supported on MeshCore',
        );
      }
    });

    test('every IftttTriggerType has an explicit categorisation', () {
      const accountedFor = <IftttTriggerType>{
        IftttTriggerType.batteryLow,
        IftttTriggerType.temperatureAlert,
        IftttTriggerType.nodeOnline,
        IftttTriggerType.nodeOffline,
        IftttTriggerType.positionUpdate,
        IftttTriggerType.messageReceived,
        IftttTriggerType.sosEmergency,
      };
      final missing = IftttTriggerType.values.toSet().difference(accountedFor);
      expect(
        missing,
        isEmpty,
        reason:
            'New IftttTriggerType detected without a compatibility row: '
            "${missing.map((t) => t.name).join(', ')}. "
            'Update MESHCORE_PROTOCOL_COMPATIBILITY.md + add to '
            'IftttTriggerTypeProtocolSupport.supportOn + add to this test.',
      );
    });
  });
}
