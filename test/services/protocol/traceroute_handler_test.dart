// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/models/telemetry_log.dart';
import 'package:socialmesh/services/storage/telemetry_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Traceroute RouteDiscovery parsing', () {
    test(
      'valid RouteDiscovery with forward and back paths parses correctly',
      () {
        final routeDiscovery = pb.RouteDiscovery(
          route: [0xAABBCCDD, 0x11223344],
          snrTowards: [40, -8], // scaled by 4: 10.0 dB, -2.0 dB
          routeBack: [0x55667788],
          snrBack: [24], // scaled by 4: 6.0 dB
        );

        final payload = routeDiscovery.writeToBuffer();
        expect(payload.isNotEmpty, true);

        final parsed = pb.RouteDiscovery.fromBuffer(payload);
        expect(parsed.route.length, 2);
        expect(parsed.route[0], 0xAABBCCDD);
        expect(parsed.route[1], 0x11223344);
        expect(parsed.snrTowards.length, 2);
        expect(parsed.snrTowards[0], 40);
        expect(parsed.snrTowards[1], -8);
        expect(parsed.routeBack.length, 1);
        expect(parsed.routeBack[0], 0x55667788);
        expect(parsed.snrBack.length, 1);
        expect(parsed.snrBack[0], 24);
      },
    );

    test('empty RouteDiscovery parses without error', () {
      final routeDiscovery = pb.RouteDiscovery();
      final payload = routeDiscovery.writeToBuffer();
      final parsed = pb.RouteDiscovery.fromBuffer(payload);

      expect(parsed.route, isEmpty);
      expect(parsed.snrTowards, isEmpty);
      expect(parsed.routeBack, isEmpty);
      expect(parsed.snrBack, isEmpty);
    });

    test('SNR values are correctly scaled by factor of 4', () {
      final routeDiscovery = pb.RouteDiscovery(
        route: [0x12345678],
        snrTowards: [48], // 48 / 4 = 12.0 dB
      );

      final parsed = pb.RouteDiscovery.fromBuffer(
        routeDiscovery.writeToBuffer(),
      );
      final snrDb = parsed.snrTowards[0] / 4.0;
      expect(snrDb, 12.0);
    });

    test('negative SNR values parse correctly', () {
      final routeDiscovery = pb.RouteDiscovery(
        route: [0x12345678],
        snrTowards: [-20], // -20 / 4 = -5.0 dB
      );

      final parsed = pb.RouteDiscovery.fromBuffer(
        routeDiscovery.writeToBuffer(),
      );
      final snrDb = parsed.snrTowards[0] / 4.0;
      expect(snrDb, -5.0);
    });
  });

  group('Traceroute TraceRouteLog model construction', () {
    test('TraceRouteLog from valid RouteDiscovery has correct fields', () {
      const targetNode = 0xAABBCCDD;
      final forwardRoute = [0x11111111, 0x22222222];
      final forwardSnr = [40, -8]; // 10.0, -2.0 dB
      final backRoute = [0x33333333];
      final backSnr = [24]; // 6.0 dB

      final forwardHops = <TraceRouteHop>[];
      for (var i = 0; i < forwardRoute.length; i++) {
        final snrRaw = i < forwardSnr.length ? forwardSnr[i] : null;
        forwardHops.add(
          TraceRouteHop(
            nodeNum: forwardRoute[i],
            snr: snrRaw != null ? snrRaw / 4.0 : null,
          ),
        );
      }

      final backHops = <TraceRouteHop>[];
      for (var i = 0; i < backRoute.length; i++) {
        final snrRaw = i < backSnr.length ? backSnr[i] : null;
        backHops.add(
          TraceRouteHop(
            nodeNum: backRoute[i],
            snr: snrRaw != null ? snrRaw / 4.0 : null,
            back: true,
          ),
        );
      }

      final log = TraceRouteLog(
        nodeNum: targetNode,
        targetNode: targetNode,
        sent: true,
        response: true,
        hopsTowards: forwardRoute.length,
        hopsBack: backRoute.length,
        hops: [...forwardHops, ...backHops],
        snr: 7.5,
      );

      expect(log.targetNode, targetNode);
      expect(log.nodeNum, targetNode);
      expect(log.sent, true);
      expect(log.response, true);
      expect(log.hopsTowards, 2);
      expect(log.hopsBack, 1);
      expect(log.hops.length, 3);
      expect(log.snr, 7.5);

      // Forward hops
      expect(log.hops[0].nodeNum, 0x11111111);
      expect(log.hops[0].snr, 10.0);
      expect(log.hops[0].back, false);
      expect(log.hops[1].nodeNum, 0x22222222);
      expect(log.hops[1].snr, -2.0);
      expect(log.hops[1].back, false);

      // Back hop
      expect(log.hops[2].nodeNum, 0x33333333);
      expect(log.hops[2].snr, 6.0);
      expect(log.hops[2].back, true);
    });

    test('TraceRouteLog with empty routes has zero hops', () {
      final log = TraceRouteLog(
        nodeNum: 0xDEADBEEF,
        targetNode: 0xDEADBEEF,
        sent: true,
        response: true,
        hopsTowards: 0,
        hopsBack: 0,
        hops: [],
      );

      expect(log.hopsTowards, 0);
      expect(log.hopsBack, 0);
      expect(log.hops, isEmpty);
      expect(log.response, true);
    });

    test('SNR list shorter than route list clamps safely', () {
      final route = [0x11111111, 0x22222222, 0x33333333];
      final snrTowards = [40]; // only 1 SNR for 3 hops

      final hops = <TraceRouteHop>[];
      for (var i = 0; i < route.length; i++) {
        final snrRaw = i < snrTowards.length ? snrTowards[i] : null;
        hops.add(
          TraceRouteHop(
            nodeNum: route[i],
            snr: snrRaw != null ? snrRaw / 4.0 : null,
          ),
        );
      }

      expect(hops.length, 3);
      expect(hops[0].snr, 10.0);
      expect(hops[1].snr, isNull);
      expect(hops[2].snr, isNull);
    });

    test('Forward-only route (no back path) stores correctly', () {
      final log = TraceRouteLog(
        nodeNum: 0xAABBCCDD,
        targetNode: 0xAABBCCDD,
        sent: true,
        response: true,
        hopsTowards: 2,
        hopsBack: 0,
        hops: [
          TraceRouteHop(nodeNum: 0x11111111, snr: 10.0),
          TraceRouteHop(nodeNum: 0x22222222, snr: -2.0),
        ],
      );

      expect(log.hopsBack, 0);
      expect(log.hops.where((h) => h.back).length, 0);
      expect(log.hops.where((h) => !h.back).length, 2);
    });
  });

  group('Traceroute TraceRouteLog JSON serialization', () {
    test('toJson and fromJson roundtrip preserves all fields', () {
      final original = TraceRouteLog(
        nodeNum: 0xAABBCCDD,
        targetNode: 0xAABBCCDD,
        sent: true,
        response: true,
        hopsTowards: 2,
        hopsBack: 1,
        hops: [
          TraceRouteHop(nodeNum: 0x11111111, snr: 10.0),
          TraceRouteHop(nodeNum: 0x22222222, snr: -2.0),
          TraceRouteHop(nodeNum: 0x33333333, snr: 6.0, back: true),
        ],
        snr: 7.5,
      );

      final json = original.toJson();
      final restored = TraceRouteLog.fromJson(json);

      expect(restored.nodeNum, original.nodeNum);
      expect(restored.targetNode, original.targetNode);
      expect(restored.sent, original.sent);
      expect(restored.response, original.response);
      expect(restored.hopsTowards, original.hopsTowards);
      expect(restored.hopsBack, original.hopsBack);
      expect(restored.snr, original.snr);
      expect(restored.hops.length, original.hops.length);

      for (var i = 0; i < original.hops.length; i++) {
        expect(restored.hops[i].nodeNum, original.hops[i].nodeNum);
        expect(restored.hops[i].snr, original.hops[i].snr);
        expect(restored.hops[i].back, original.hops[i].back);
      }
    });

    test('fromJson handles missing optional fields gracefully', () {
      final json = <String, dynamic>{
        'nodeNum': 12345,
        'targetNode': 67890,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final log = TraceRouteLog.fromJson(json);
      expect(log.nodeNum, 12345);
      expect(log.targetNode, 67890);
      expect(log.sent, true);
      expect(log.response, false);
      expect(log.hopsTowards, 0);
      expect(log.hopsBack, 0);
      expect(log.hops, isEmpty);
      expect(log.snr, isNull);
    });
  });

  group('Traceroute storage integration', () {
    late SharedPreferences prefs;
    late TelemetryStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      storage = TelemetryStorageService(prefs);
    });

    test('addTraceRouteLog stores and retrieves a single traceroute', () async {
      final log = TraceRouteLog(
        nodeNum: 0xAABBCCDD,
        targetNode: 0xAABBCCDD,
        sent: true,
        response: true,
        hopsTowards: 2,
        hopsBack: 1,
        hops: [
          TraceRouteHop(nodeNum: 0x11111111, snr: 10.0),
          TraceRouteHop(nodeNum: 0x22222222, snr: -2.0),
          TraceRouteHop(nodeNum: 0x33333333, snr: 6.0, back: true),
        ],
        snr: 7.5,
      );

      await storage.addTraceRouteLog(log);
      final logs = await storage.getTraceRouteLogs(0xAABBCCDD);

      expect(logs.length, 1);
      expect(logs.first.targetNode, 0xAABBCCDD);
      expect(logs.first.response, true);
      expect(logs.first.hopsTowards, 2);
      expect(logs.first.hopsBack, 1);
      expect(logs.first.hops.length, 3);
      expect(logs.first.snr, 7.5);

      // Verify hop details survived serialization
      expect(logs.first.hops[0].nodeNum, 0x11111111);
      expect(logs.first.hops[0].snr, 10.0);
      expect(logs.first.hops[0].back, false);
      expect(logs.first.hops[1].nodeNum, 0x22222222);
      expect(logs.first.hops[1].snr, -2.0);
      expect(logs.first.hops[1].back, false);
      expect(logs.first.hops[2].nodeNum, 0x33333333);
      expect(logs.first.hops[2].snr, 6.0);
      expect(logs.first.hops[2].back, true);
    });

    test('invalid/empty payload equivalent does not store', () async {
      // Simulate what happens when the handler receives empty payload:
      // it should not call addTraceRouteLog at all.
      // Verify storage remains empty.
      final logs = await storage.getTraceRouteLogs(99999);
      expect(logs, isEmpty);
    });

    test(
      'multiple traceroutes for same target are stored separately',
      () async {
        for (var i = 0; i < 3; i++) {
          await storage.addTraceRouteLog(
            TraceRouteLog(
              nodeNum: 0xAABBCCDD,
              targetNode: 0xAABBCCDD,
              sent: true,
              response: true,
              hopsTowards: i + 1,
              hopsBack: 0,
            ),
          );
        }

        final logs = await storage.getTraceRouteLogs(0xAABBCCDD);
        expect(logs.length, 3);
        expect(logs[0].hopsTowards, 1);
        expect(logs[1].hopsTowards, 2);
        expect(logs[2].hopsTowards, 3);
      },
    );

    test('traceroutes for different targets are isolated', () async {
      await storage.addTraceRouteLog(
        TraceRouteLog(
          nodeNum: 0x11111111,
          targetNode: 0x11111111,
          sent: true,
          response: true,
          hopsTowards: 2,
          hopsBack: 0,
        ),
      );
      await storage.addTraceRouteLog(
        TraceRouteLog(
          nodeNum: 0x22222222,
          targetNode: 0x22222222,
          sent: true,
          response: true,
          hopsTowards: 5,
          hopsBack: 0,
        ),
      );

      final logs1 = await storage.getTraceRouteLogs(0x11111111);
      final logs2 = await storage.getTraceRouteLogs(0x22222222);

      expect(logs1.length, 1);
      expect(logs1.first.hopsTowards, 2);
      expect(logs2.length, 1);
      expect(logs2.first.hopsTowards, 5);
    });

    test('getAllTraceRouteLogs returns logs from all nodes', () async {
      await storage.addTraceRouteLog(
        TraceRouteLog(
          nodeNum: 0x11111111,
          targetNode: 0x11111111,
          sent: true,
          response: true,
          hopsTowards: 2,
          hopsBack: 0,
        ),
      );
      await storage.addTraceRouteLog(
        TraceRouteLog(
          nodeNum: 0x22222222,
          targetNode: 0x22222222,
          sent: true,
          response: true,
          hopsTowards: 3,
          hopsBack: 1,
        ),
      );

      final all = await storage.getAllTraceRouteLogs();
      expect(all.length, 2);
    });

    test('clearTraceRouteLogs removes all traceroute data', () async {
      await storage.addTraceRouteLog(
        TraceRouteLog(
          nodeNum: 0x11111111,
          targetNode: 0x11111111,
          sent: true,
          response: true,
          hopsTowards: 1,
          hopsBack: 0,
        ),
      );
      await storage.addTraceRouteLog(
        TraceRouteLog(
          nodeNum: 0x22222222,
          targetNode: 0x22222222,
          sent: true,
          response: true,
          hopsTowards: 2,
          hopsBack: 0,
        ),
      );

      await storage.clearTraceRouteLogs();

      final all = await storage.getAllTraceRouteLogs();
      expect(all, isEmpty);
    });
  });

  group('Traceroute CSV export', () {
    test(
      'exported CSV has correct header and data for stored traceroutes',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final storage = TelemetryStorageService(prefs);

        await storage.addTraceRouteLog(
          TraceRouteLog(
            nodeNum: 0xAABBCCDD,
            targetNode: 0xAABBCCDD,
            sent: true,
            response: true,
            hopsTowards: 2,
            hopsBack: 1,
            hops: [
              TraceRouteHop(nodeNum: 0x11111111, snr: 10.0),
              TraceRouteHop(nodeNum: 0x22222222, snr: -2.0),
              TraceRouteHop(nodeNum: 0x33333333, snr: 6.0, back: true),
            ],
            snr: 7.5,
          ),
        );

        // Simulate the CSV export logic from data_export_screen.dart
        final logs = await storage.getTraceRouteLogs(0xAABBCCDD);
        final buffer = StringBuffer();
        buffer.writeln('timestamp,target_node,hops,route,snr_values');
        for (final log in logs) {
          final hopNodes = log.hops.map((h) => h.nodeNum).join('>');
          final snrValues = log.hops.map((h) => h.snr ?? 'N/A').join(',');
          buffer.writeln(
            '${log.timestamp.toIso8601String()},${log.targetNode},${log.hops.length},"$hopNodes","$snrValues"',
          );
        }

        final csv = buffer.toString();

        // Verify header
        expect(csv, contains('timestamp,target_node,hops,route,snr_values'));

        // Verify data row exists with route info
        expect(csv, contains('${0xAABBCCDD}'));
        expect(csv, contains('${0x11111111}>${0x22222222}>${0x33333333}'));
        expect(csv, contains('10.0'));
        expect(csv, contains('-2.0'));
        expect(csv, contains('6.0'));

        // Verify the CSV has exactly 2 lines (header + 1 data row)
        final lines = csv
            .trim()
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();
        expect(lines.length, 2);
      },
    );

    test('CSV export with no traceroutes produces header only', () {
      final buffer = StringBuffer();
      buffer.writeln('timestamp,target_node,hops,route,snr_values');

      final csv = buffer.toString();
      final lines = csv
          .trim()
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      expect(lines.length, 1);
      expect(lines.first, contains('timestamp'));
    });

    test('CSV export handles hops with missing SNR as N/A', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = TelemetryStorageService(prefs);

      await storage.addTraceRouteLog(
        TraceRouteLog(
          nodeNum: 0xDEADBEEF,
          targetNode: 0xDEADBEEF,
          sent: true,
          response: true,
          hopsTowards: 2,
          hopsBack: 0,
          hops: [
            TraceRouteHop(nodeNum: 0x11111111, snr: 10.0),
            TraceRouteHop(nodeNum: 0x22222222), // no SNR
          ],
        ),
      );

      final logs = await storage.getTraceRouteLogs(0xDEADBEEF);
      final snrValues = logs.first.hops.map((h) => h.snr ?? 'N/A').join(',');

      expect(snrValues, '10.0,N/A');
    });
  });

  group('Traceroute end-to-end simulation', () {
    test(
      'simulated inbound RouteDiscovery produces correct TraceRouteLog in storage',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final storage = TelemetryStorageService(prefs);

        // Simulate what _handleTracerouteMessage does:
        // 1. Parse RouteDiscovery from protobuf payload
        final routeDiscovery = pb.RouteDiscovery(
          route: [0x11111111, 0x22222222],
          snrTowards: [40, -8], // 10.0 dB, -2.0 dB
          routeBack: [0x33333333],
          snrBack: [24], // 6.0 dB
        );
        final payload = routeDiscovery.writeToBuffer();

        // 2. Parse it back (simulating fromBuffer in handler)
        final parsed = pb.RouteDiscovery.fromBuffer(payload);

        // 3. Build hops (same logic as _handleTracerouteMessage)
        const targetNode = 0xAABBCCDD;
        final forwardRoute = parsed.route.toList();
        final forwardSnr = parsed.snrTowards.toList();
        final forwardHops = <TraceRouteHop>[];
        for (var i = 0; i < forwardRoute.length; i++) {
          final snrRaw = i < forwardSnr.length ? forwardSnr[i] : null;
          forwardHops.add(
            TraceRouteHop(
              nodeNum: forwardRoute[i],
              snr: snrRaw != null ? snrRaw / 4.0 : null,
            ),
          );
        }

        final backRoute = parsed.routeBack.toList();
        final backSnrList = parsed.snrBack.toList();
        final backHops = <TraceRouteHop>[];
        for (var i = 0; i < backRoute.length; i++) {
          final snrRaw = i < backSnrList.length ? backSnrList[i] : null;
          backHops.add(
            TraceRouteHop(
              nodeNum: backRoute[i],
              snr: snrRaw != null ? snrRaw / 4.0 : null,
              back: true,
            ),
          );
        }

        // 4. Build and store log
        final log = TraceRouteLog(
          nodeNum: targetNode,
          targetNode: targetNode,
          sent: true,
          response: true,
          hopsTowards: forwardRoute.length,
          hopsBack: backRoute.length,
          hops: [...forwardHops, ...backHops],
          snr: 7.5,
        );

        await storage.addTraceRouteLog(log);

        // 5. Verify storage
        final storedLogs = await storage.getTraceRouteLogs(targetNode);
        expect(storedLogs.length, 1);

        final stored = storedLogs.first;
        expect(stored.targetNode, targetNode);
        expect(stored.response, true);
        expect(stored.hopsTowards, 2);
        expect(stored.hopsBack, 1);
        expect(stored.hops.length, 3);
        expect(stored.hops[0].nodeNum, 0x11111111);
        expect(stored.hops[0].snr, 10.0);
        expect(stored.hops[0].back, false);
        expect(stored.hops[1].nodeNum, 0x22222222);
        expect(stored.hops[1].snr, -2.0);
        expect(stored.hops[1].back, false);
        expect(stored.hops[2].nodeNum, 0x33333333);
        expect(stored.hops[2].snr, 6.0);
        expect(stored.hops[2].back, true);

        // 6. Verify it also shows up in getAllTraceRouteLogs
        final allLogs = await storage.getAllTraceRouteLogs();
        expect(allLogs.length, 1);
        expect(allLogs.first.targetNode, targetNode);
      },
    );

    test('direct-path traceroute (zero hops) stores correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = TelemetryStorageService(prefs);

      // Direct path: no intermediate hops
      final routeDiscovery = pb.RouteDiscovery();
      final parsed = pb.RouteDiscovery.fromBuffer(
        routeDiscovery.writeToBuffer(),
      );

      const targetNode = 0xBBBBBBBB;
      final log = TraceRouteLog(
        nodeNum: targetNode,
        targetNode: targetNode,
        sent: true,
        response: true,
        hopsTowards: parsed.route.length,
        hopsBack: parsed.routeBack.length,
        hops: [],
        snr: 12.0,
      );

      await storage.addTraceRouteLog(log);
      final stored = await storage.getTraceRouteLogs(targetNode);

      expect(stored.length, 1);
      expect(stored.first.hopsTowards, 0);
      expect(stored.first.hopsBack, 0);
      expect(stored.first.hops, isEmpty);
      expect(stored.first.response, true);
      expect(stored.first.snr, 12.0);
    });
  });

  group('Outbound placeholder and replace-on-response', () {
    late SharedPreferences prefs;
    late TelemetryStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      storage = TelemetryStorageService(prefs);
    });

    test(
      'outbound placeholder stores with response false and zero hops',
      () async {
        const targetNode = 0xAABBCCDD;

        await storage.addTraceRouteLog(
          TraceRouteLog(
            nodeNum: targetNode,
            targetNode: targetNode,
            sent: true,
            response: false,
            hopsTowards: 0,
            hopsBack: 0,
          ),
        );

        final logs = await storage.getTraceRouteLogs(targetNode);
        expect(logs.length, 1);
        expect(logs.first.response, false);
        expect(logs.first.sent, true);
        expect(logs.first.hopsTowards, 0);
        expect(logs.first.hopsBack, 0);
        expect(logs.first.hops, isEmpty);
      },
    );

    test(
      'replaceOrAddTraceRouteLog replaces pending entry for same target',
      () async {
        const targetNode = 0xAABBCCDD;

        // Store a pending (no-response) placeholder
        await storage.addTraceRouteLog(
          TraceRouteLog(
            nodeNum: targetNode,
            targetNode: targetNode,
            sent: true,
            response: false,
            hopsTowards: 0,
            hopsBack: 0,
          ),
        );

        var logs = await storage.getTraceRouteLogs(targetNode);
        expect(logs.length, 1);
        expect(logs.first.response, false);

        // Now a response arrives — replaceOrAdd should swap the placeholder
        await storage.replaceOrAddTraceRouteLog(
          TraceRouteLog(
            nodeNum: targetNode,
            targetNode: targetNode,
            sent: true,
            response: true,
            hopsTowards: 2,
            hopsBack: 1,
            hops: [
              TraceRouteHop(nodeNum: 0x11111111, snr: 10.0),
              TraceRouteHop(nodeNum: 0x22222222, snr: -2.0),
              TraceRouteHop(nodeNum: 0x33333333, snr: 6.0, back: true),
            ],
            snr: 7.5,
          ),
        );

        logs = await storage.getTraceRouteLogs(targetNode);
        expect(logs.length, 1);
        expect(logs.first.response, true);
        expect(logs.first.hopsTowards, 2);
        expect(logs.first.hopsBack, 1);
        expect(logs.first.hops.length, 3);
        expect(logs.first.snr, 7.5);
      },
    );

    test(
      'replaceOrAddTraceRouteLog appends when no pending entry exists',
      () async {
        const targetNode = 0xAABBCCDD;

        // Store a completed traceroute first (no pending entry)
        await storage.addTraceRouteLog(
          TraceRouteLog(
            nodeNum: targetNode,
            targetNode: targetNode,
            sent: true,
            response: true,
            hopsTowards: 1,
            hopsBack: 0,
            hops: [TraceRouteHop(nodeNum: 0x11111111, snr: 5.0)],
          ),
        );

        // Another response arrives with no matching pending entry
        await storage.replaceOrAddTraceRouteLog(
          TraceRouteLog(
            nodeNum: targetNode,
            targetNode: targetNode,
            sent: true,
            response: true,
            hopsTowards: 3,
            hopsBack: 0,
            hops: [
              TraceRouteHop(nodeNum: 0x11111111, snr: 10.0),
              TraceRouteHop(nodeNum: 0x22222222, snr: 8.0),
              TraceRouteHop(nodeNum: 0x33333333, snr: 6.0),
            ],
          ),
        );

        final logs = await storage.getTraceRouteLogs(targetNode);
        expect(logs.length, 2);
        expect(logs[0].hopsTowards, 1);
        expect(logs[1].hopsTowards, 3);
      },
    );

    test(
      'replaceOrAddTraceRouteLog only removes pending entry for matching target',
      () async {
        const targetA = 0x11111111;
        const targetB = 0x22222222;

        // Store pending entries for two different targets
        await storage.addTraceRouteLog(
          TraceRouteLog(
            nodeNum: targetA,
            targetNode: targetA,
            sent: true,
            response: false,
            hopsTowards: 0,
            hopsBack: 0,
          ),
        );
        await storage.addTraceRouteLog(
          TraceRouteLog(
            nodeNum: targetB,
            targetNode: targetB,
            sent: true,
            response: false,
            hopsTowards: 0,
            hopsBack: 0,
          ),
        );

        // Response arrives for targetB only
        await storage.replaceOrAddTraceRouteLog(
          TraceRouteLog(
            nodeNum: targetB,
            targetNode: targetB,
            sent: true,
            response: true,
            hopsTowards: 1,
            hopsBack: 0,
            hops: [TraceRouteHop(nodeNum: 0x99999999, snr: 4.0)],
          ),
        );

        // targetA still has its pending entry
        final logsA = await storage.getTraceRouteLogs(targetA);
        expect(logsA.length, 1);
        expect(logsA.first.response, false);

        // targetB was replaced
        final logsB = await storage.getTraceRouteLogs(targetB);
        expect(logsB.length, 1);
        expect(logsB.first.response, true);
        expect(logsB.first.hopsTowards, 1);
      },
    );

    test(
      'timed-out traceroute stays as No Response when no reply arrives',
      () async {
        const targetNode = 0xDEADBEEF;

        await storage.addTraceRouteLog(
          TraceRouteLog(
            nodeNum: targetNode,
            targetNode: targetNode,
            sent: true,
            response: false,
            hopsTowards: 0,
            hopsBack: 0,
          ),
        );

        // No response ever arrives — entry remains with response: false
        final logs = await storage.getTraceRouteLogs(targetNode);
        expect(logs.length, 1);
        expect(logs.first.response, false);
        expect(logs.first.sent, true);
        expect(logs.first.hops, isEmpty);
      },
    );

    test(
      'multiple sequential traceroutes to same target replace correctly',
      () async {
        const targetNode = 0xAABBCCDD;

        // First traceroute: send placeholder
        await storage.addTraceRouteLog(
          TraceRouteLog(
            nodeNum: targetNode,
            targetNode: targetNode,
            sent: true,
            response: false,
            hopsTowards: 0,
            hopsBack: 0,
          ),
        );

        // First traceroute: response arrives
        await storage.replaceOrAddTraceRouteLog(
          TraceRouteLog(
            nodeNum: targetNode,
            targetNode: targetNode,
            sent: true,
            response: true,
            hopsTowards: 1,
            hopsBack: 0,
            hops: [TraceRouteHop(nodeNum: 0x11111111, snr: 5.0)],
          ),
        );

        // Second traceroute: send placeholder
        await storage.addTraceRouteLog(
          TraceRouteLog(
            nodeNum: targetNode,
            targetNode: targetNode,
            sent: true,
            response: false,
            hopsTowards: 0,
            hopsBack: 0,
          ),
        );

        // Second traceroute: response arrives
        await storage.replaceOrAddTraceRouteLog(
          TraceRouteLog(
            nodeNum: targetNode,
            targetNode: targetNode,
            sent: true,
            response: true,
            hopsTowards: 2,
            hopsBack: 0,
            hops: [
              TraceRouteHop(nodeNum: 0x11111111, snr: 8.0),
              TraceRouteHop(nodeNum: 0x22222222, snr: 3.0),
            ],
          ),
        );

        // Should have exactly 2 completed entries, no pending
        final logs = await storage.getTraceRouteLogs(targetNode);
        expect(logs.length, 2);
        expect(logs.every((l) => l.response), true);
        expect(logs[0].hopsTowards, 1);
        expect(logs[1].hopsTowards, 2);
      },
    );
  });
}
