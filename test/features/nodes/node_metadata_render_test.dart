// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/mesh_models.dart';

/// Formats RSSI value the same way the _NodeCard widget does.
String formatRssi(int? rssi) {
  if (rssi == null) return '—';
  return '$rssi dBm';
}

/// Formats hop count the same way the _NodeCard widget does.
String? formatHopCount(int? hopCount) {
  if (hopCount == null) return null;
  if (hopCount == 0) return 'Direct';
  return '$hopCount ${hopCount == 1 ? 'hop' : 'hops'}';
}

/// Returns the transport label the same way the _NodeCard widget does.
String transportLabel(bool viaMqtt) {
  return viaMqtt ? 'MQTT' : 'RF';
}

/// Returns the transport icon the same way the _NodeCard widget does.
IconData transportIcon(bool viaMqtt) {
  return viaMqtt ? Icons.cloud_outlined : Icons.cell_tower;
}

/// Calculates signal bars from RSSI, matching _NodeCard._calculateSignalBars.
int calculateSignalBars(int? rssi) {
  if (rssi == null) return 0;
  if (rssi >= -70) return 4;
  if (rssi >= -80) return 3;
  if (rssi >= -90) return 2;
  if (rssi >= -100) return 1;
  return 0;
}

void main() {
  group('RSSI display', () {
    test('renders null RSSI as dash', () {
      expect(formatRssi(null), '—');
    });

    test('renders strong RSSI correctly', () {
      expect(formatRssi(-45), '-45 dBm');
    });

    test('renders moderate RSSI correctly', () {
      expect(formatRssi(-75), '-75 dBm');
    });

    test('renders weak RSSI correctly', () {
      expect(formatRssi(-110), '-110 dBm');
    });

    test('renders zero RSSI correctly', () {
      expect(formatRssi(0), '0 dBm');
    });

    test('renders boundary RSSI values correctly', () {
      expect(formatRssi(-70), '-70 dBm');
      expect(formatRssi(-80), '-80 dBm');
      expect(formatRssi(-90), '-90 dBm');
      expect(formatRssi(-100), '-100 dBm');
      expect(formatRssi(-120), '-120 dBm');
    });
  });

  group('Signal bars from RSSI', () {
    test('null RSSI yields 0 bars', () {
      expect(calculateSignalBars(null), 0);
    });

    test('strong signal (-45 dBm) yields 4 bars', () {
      expect(calculateSignalBars(-45), 4);
    });

    test('boundary -70 dBm yields 4 bars', () {
      expect(calculateSignalBars(-70), 4);
    });

    test('-71 dBm yields 3 bars', () {
      expect(calculateSignalBars(-71), 3);
    });

    test('boundary -80 dBm yields 3 bars', () {
      expect(calculateSignalBars(-80), 3);
    });

    test('-81 dBm yields 2 bars', () {
      expect(calculateSignalBars(-81), 2);
    });

    test('boundary -90 dBm yields 2 bars', () {
      expect(calculateSignalBars(-90), 2);
    });

    test('-91 dBm yields 1 bar', () {
      expect(calculateSignalBars(-91), 1);
    });

    test('boundary -100 dBm yields 1 bar', () {
      expect(calculateSignalBars(-100), 1);
    });

    test('very weak -101 dBm yields 0 bars', () {
      expect(calculateSignalBars(-101), 0);
    });

    test('extremely weak -120 dBm yields 0 bars', () {
      expect(calculateSignalBars(-120), 0);
    });
  });

  group('Hop count display', () {
    test('null hop count returns null (label hidden)', () {
      expect(formatHopCount(null), isNull);
    });

    test('0 hops renders as Direct', () {
      expect(formatHopCount(0), 'Direct');
    });

    test('1 hop renders singular', () {
      expect(formatHopCount(1), '1 hop');
    });

    test('2 hops renders plural', () {
      expect(formatHopCount(2), '2 hops');
    });

    test('3 hops renders plural', () {
      expect(formatHopCount(3), '3 hops');
    });

    test('max hop count (7) renders correctly', () {
      expect(formatHopCount(7), '7 hops');
    });

    test('high hop count renders correctly', () {
      expect(formatHopCount(10), '10 hops');
    });
  });

  group('Transport badge', () {
    test('RF node shows RF label', () {
      expect(transportLabel(false), 'RF');
    });

    test('MQTT node shows MQTT label', () {
      expect(transportLabel(true), 'MQTT');
    });

    test('RF node uses cell_tower icon', () {
      expect(transportIcon(false), Icons.cell_tower);
    });

    test('MQTT node uses cloud_outlined icon', () {
      expect(transportIcon(true), Icons.cloud_outlined);
    });

    test('default MeshNode is RF', () {
      final node = MeshNode(nodeNum: 1);
      expect(transportLabel(node.viaMqtt), 'RF');
      expect(transportIcon(node.viaMqtt), Icons.cell_tower);
    });

    test('explicit MQTT MeshNode shows MQTT transport', () {
      final node = MeshNode(nodeNum: 2, viaMqtt: true);
      expect(transportLabel(node.viaMqtt), 'MQTT');
      expect(transportIcon(node.viaMqtt), Icons.cloud_outlined);
    });
  });

  group('MeshNode RF metadata fields', () {
    test('MeshNode defaults to viaMqtt=false and hopCount=null', () {
      final node = MeshNode(nodeNum: 1);
      expect(node.viaMqtt, isFalse);
      expect(node.hopCount, isNull);
      expect(node.rssi, isNull);
    });

    test('MeshNode stores RF metadata correctly', () {
      final node = MeshNode(nodeNum: 1, rssi: -87, hopCount: 2, viaMqtt: false);
      expect(node.rssi, -87);
      expect(node.hopCount, 2);
      expect(node.viaMqtt, isFalse);
    });

    test('MeshNode stores MQTT metadata correctly', () {
      final node = MeshNode(
        nodeNum: 2,
        rssi: null,
        hopCount: null,
        viaMqtt: true,
      );
      expect(node.rssi, isNull);
      expect(node.hopCount, isNull);
      expect(node.viaMqtt, isTrue);
    });

    test('copyWith preserves all RF metadata', () {
      final original = MeshNode(
        nodeNum: 1,
        rssi: -75,
        hopCount: 1,
        viaMqtt: false,
      );
      final copy = original.copyWith(longName: 'Updated');

      expect(copy.rssi, -75);
      expect(copy.hopCount, 1);
      expect(copy.viaMqtt, isFalse);
      expect(copy.longName, 'Updated');
    });

    test('copyWith can update RF metadata independently', () {
      final original = MeshNode(
        nodeNum: 1,
        rssi: -75,
        hopCount: 1,
        viaMqtt: false,
      );

      final updated = original.copyWith(rssi: -92, hopCount: 3, viaMqtt: true);

      expect(updated.rssi, -92);
      expect(updated.hopCount, 3);
      expect(updated.viaMqtt, isTrue);
      expect(updated.nodeNum, 1);
    });
  });

  group('Combined metadata rendering', () {
    test('RF node with full metadata renders all fields', () {
      final node = MeshNode(nodeNum: 1, rssi: -87, hopCount: 2, viaMqtt: false);

      expect(formatRssi(node.rssi), '-87 dBm');
      expect(formatHopCount(node.hopCount), '2 hops');
      expect(transportLabel(node.viaMqtt), 'RF');
      expect(calculateSignalBars(node.rssi), 2);
    });

    test('MQTT node with no RF metadata shows appropriate defaults', () {
      final node = MeshNode(nodeNum: 2, viaMqtt: true);

      expect(formatRssi(node.rssi), '—');
      expect(formatHopCount(node.hopCount), isNull);
      expect(transportLabel(node.viaMqtt), 'MQTT');
      expect(calculateSignalBars(node.rssi), 0);
    });

    test('MQTT node with partial RF metadata renders available fields', () {
      final node = MeshNode(nodeNum: 3, rssi: -88, hopCount: 1, viaMqtt: true);

      expect(formatRssi(node.rssi), '-88 dBm');
      expect(formatHopCount(node.hopCount), '1 hop');
      expect(transportLabel(node.viaMqtt), 'MQTT');
      expect(calculateSignalBars(node.rssi), 2);
    });

    test('RF node with only RSSI renders RSSI and transport', () {
      final node = MeshNode(nodeNum: 4, rssi: -65, viaMqtt: false);

      expect(formatRssi(node.rssi), '-65 dBm');
      expect(formatHopCount(node.hopCount), isNull);
      expect(transportLabel(node.viaMqtt), 'RF');
      expect(calculateSignalBars(node.rssi), 4);
    });

    test('direct RF node renders correctly', () {
      final node = MeshNode(nodeNum: 5, rssi: -55, hopCount: 0, viaMqtt: false);

      expect(formatRssi(node.rssi), '-55 dBm');
      expect(formatHopCount(node.hopCount), 'Direct');
      expect(transportLabel(node.viaMqtt), 'RF');
      expect(calculateSignalBars(node.rssi), 4);
    });
  });
}
