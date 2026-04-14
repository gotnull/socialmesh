// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_detail_payload.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_instance.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_signal_kind.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_template.dart';

void main() {
  MeshServiceInstance instance({
    required MeshServiceType type,
    MeshServicePresetId? presetId,
    Map<String, dynamic> config = const {},
  }) {
    return MeshServiceInstance(
      instanceId: 'instance-1',
      canonicalType: type,
      presetId: presetId,
      title: 'Test instance',
      description: 'Description',
      createdAt: DateTime(2026, 1, 2, 3, 4, 5),
      config: config,
    );
  }

  test('signal kind falls back safely for unknown code and storage', () {
    expect(MeshServiceSignalKind.fromCode(99), MeshServiceSignalKind.checkIn);
    expect(
      MeshServiceSignalKind.fromStorage('unknown'),
      MeshServiceSignalKind.checkIn,
    );
  });

  test('decode returns empty extension for missing payload', () {
    final decoded = MeshServiceDetailPayloadCodec.decode(
      MeshServiceType.feed,
      Uint8List(0),
    );

    expect(decoded.createdAt, isNull);
    expect(decoded.pollOptions, isEmpty);
    expect(decoded.listItems, isEmpty);
  });

  test('signal extension round-trips signal kind', () {
    final encoded = MeshServiceDetailPayloadCodec.encodeExtension(
      instance: instance(
        type: MeshServiceType.signal,
        config: const {'signalKind': 'hazard'},
      ),
      pollVotes: const {},
      checklistStates: const {},
      requesterNodeId: 0x1234,
    );

    final decoded = MeshServiceDetailPayloadCodec.decode(
      MeshServiceType.signal,
      encoded,
    );

    expect(decoded.signalKind, MeshServiceSignalKind.hazard);
    expect(decoded.createdAt, DateTime(2026, 1, 2, 3, 4, 5));
  });

  test('sensor extension round-trips reading metadata', () {
    final capturedAt = DateTime(2026, 4, 5, 6, 7, 8);
    final encoded = MeshServiceDetailPayloadCodec.encodeExtension(
      instance: instance(
        type: MeshServiceType.sensor,
        presetId: MeshServicePresetId.weatherStation,
        config: {
          'sensorValue': '23.4',
          'sensorUnit': '°C',
          'sensorSource': 'Ridge station',
          'sensorCapturedAtMs': capturedAt.millisecondsSinceEpoch,
        },
      ),
      pollVotes: const {},
      checklistStates: const {},
      requesterNodeId: 0x1234,
    );

    final decoded = MeshServiceDetailPayloadCodec.decode(
      MeshServiceType.sensor,
      encoded,
    );

    expect(decoded.sensorValue, '23.4');
    expect(decoded.sensorUnit, '°C');
    expect(decoded.sensorSource, 'Ridge station');
    expect(decoded.sensorCapturedAt, capturedAt);
  });
}
