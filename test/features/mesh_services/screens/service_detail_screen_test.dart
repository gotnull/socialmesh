// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_detail_payload.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_instance.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_template.dart';
import 'package:socialmesh/features/mesh_services/providers/mesh_service_providers.dart';
import 'package:socialmesh/features/mesh_services/screens/service_detail_screen.dart';
import 'package:socialmesh/features/mesh_services/services/mesh_service_engine.dart';
import 'package:socialmesh/features/mesh_services/services/mrrp_delivery_tracker.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/services/haptic_service.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_constants.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_dispatcher.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_engine.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_frame.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';

class _FakeMrrpEngine extends Fake implements MrrpEngine {
  final List<MrrpRequestResult> results = [];
  int sendCount = 0;

  @override
  Future<MrrpRequestResult> sendRequest(MrrpFrame request) async {
    sendCount++;
    if (results.isEmpty) {
      return const MrrpRequestResult(status: MrrpStatusCode.timeout);
    }
    return results.removeAt(0);
  }
}

class _NoopHapticService extends HapticService {
  _NoopHapticService(super.ref);

  @override
  Future<void> trigger(HapticType type) async {}
}

MrrpRequestResult _okResult({
  required int actionId,
  required Uint8List payload,
}) {
  return MrrpRequestResult(
    status: MrrpStatusCode.ok,
    latency: const Duration(milliseconds: 250),
    response: MrrpFrame(
      versionMajor: MrrpConstants.mrrpVersionMajor,
      versionMinor: MrrpConstants.mrrpVersionMinor,
      msgType: MrrpMessageType.response,
      flags: MrrpFlags.isResponse,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: 1,
      serviceId: kMeshServicesInstanceServiceId,
      actionId: actionId,
      payloadLen: payload.length,
      payload: payload,
    ),
  );
}

Uint8List _buildListInstancesPayload(MeshServiceInstance instance) {
  final titleBytes = utf8.encode(instance.title);
  final builder = BytesBuilder(copy: false)
    ..addByte(1)
    ..add(MeshServicesHandler.encodeInstanceId(instance.instanceId))
    ..addByte(instance.canonicalType.code)
    ..addByte(instance.presetId!.code)
    ..addByte(titleBytes.length)
    ..add(titleBytes);
  return Uint8List.fromList(builder.toBytes());
}

Uint8List _buildGetInstancePayload({
  required MeshServiceInstance instance,
  required Map<int, bool> checklistStates,
  required int requesterNodeId,
}) {
  final titleBytes = utf8.encode(instance.title);
  final descriptionBytes = utf8.encode(instance.description);
  final expiresAtBytes = Uint8List(4);
  if (instance.expiresAt != null) {
    ByteData.sublistView(expiresAtBytes).setUint32(
      0,
      instance.expiresAt!.millisecondsSinceEpoch ~/ 1000,
      Endian.little,
    );
  }

  final builder = BytesBuilder(copy: false)
    ..addByte(instance.canonicalType.code)
    ..addByte(instance.presetId!.code)
    ..addByte(instance.effectiveStatus.index)
    ..addByte(titleBytes.length)
    ..add(titleBytes)
    ..addByte(descriptionBytes.length)
    ..add(descriptionBytes)
    ..add(expiresAtBytes)
    ..add(
      MeshServiceDetailPayloadCodec.encodeExtension(
        instance: instance,
        pollVotes: const {},
        checklistStates: checklistStates,
        requesterNodeId: requesterNodeId,
      ),
    );

  return Uint8List.fromList(builder.toBytes());
}

Uint8List _buildLegacyGetInstancePayload({
  required MeshServiceInstance instance,
}) {
  final titleBytes = utf8.encode(instance.title);
  final descriptionBytes = utf8.encode(instance.description);
  final expiresAtBytes = Uint8List(4);
  if (instance.expiresAt != null) {
    ByteData.sublistView(expiresAtBytes).setUint32(
      0,
      instance.expiresAt!.millisecondsSinceEpoch ~/ 1000,
      Endian.little,
    );
  }

  final builder = BytesBuilder(copy: false)
    ..addByte(instance.canonicalType.code)
    ..addByte(instance.presetId!.code)
    ..addByte(instance.effectiveStatus.index)
    ..addByte(titleBytes.length)
    ..add(titleBytes)
    ..addByte(descriptionBytes.length)
    ..add(descriptionBytes)
    ..add(expiresAtBytes);

  return Uint8List.fromList(builder.toBytes());
}

Uint8List _buildToggleResponsePayload(List<bool> states) {
  return Uint8List.fromList([
    states.length,
    ...states.map((state) => state ? 1 : 0),
  ]);
}

void main() {
  testWidgets('remote list detail renders checklist items and toggles state', (
    tester,
  ) async {
    final instance = MeshServiceInstance(
      instanceId: 'checklist1234567',
      canonicalType: MeshServiceType.list,
      presetId: MeshServicePresetId.sharedChecklist,
      title: 'Camp Checklist',
      description: 'Tap items as you pack.',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1710000000000),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(1710003600000),
      config: const {
        'items': ['Water', 'Map'],
      },
    );
    final requesterNodeId = 0x12345678;
    final engine = _FakeMrrpEngine()
      ..results.addAll([
        _okResult(
          actionId: MeshServicesAction.listInstances,
          payload: _buildListInstancesPayload(instance),
        ),
        _okResult(
          actionId: MeshServicesAction.getInstance,
          payload: _buildGetInstancePayload(
            instance: instance,
            checklistStates: const {0: true, 1: false},
            requesterNodeId: requesterNodeId,
          ),
        ),
        _okResult(
          actionId: MeshServicesAction.interact,
          payload: _buildToggleResponsePayload(const [true, true]),
        ),
      ]);
    final tracker = MrrpDeliveryTracker(engine);
    addTearDown(tracker.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mrrpDeliveryTrackerProvider.overrideWithValue(tracker),
          hapticServiceProvider.overrideWith((ref) => _NoopHapticService(ref)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ServiceDetailScreen(
            nodeId: 0x12345678,
            serviceId: kMeshServicesInstanceServiceId,
            serviceType: 'mesh-services.instance.v1',
            serviceTitle: 'Camp Checklist',
            icon: Icons.checklist_rounded,
            accentColor: Colors.cyan,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('Water'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    expect(find.byIcon(Icons.check_box), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);

    await tester.tap(find.text('Map'));
    await tester.pump();
    await tester.pump();

    expect(engine.sendCount, 3);
    expect(find.byIcon(Icons.check_box), findsNWidgets(2));
    expect(find.byIcon(Icons.check_box_outline_blank), findsNothing);
  });

  testWidgets('incomplete cached list data is revalidated on reopen', (
    tester,
  ) async {
    final instance = MeshServiceInstance(
      instanceId: 'cachetest1234567',
      canonicalType: MeshServiceType.list,
      presetId: MeshServicePresetId.sharedChecklist,
      title: 'Packing List',
      description: 'Fresh detail should replace placeholders.',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1710000000000),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(1710003600000),
      config: const {
        'items': ['Water', 'Map'],
      },
    );
    const nodeId = 0x87654321;

    final firstEngine = _FakeMrrpEngine()
      ..results.addAll([
        _okResult(
          actionId: MeshServicesAction.listInstances,
          payload: _buildListInstancesPayload(instance),
        ),
        const MrrpRequestResult(status: MrrpStatusCode.internal),
      ]);
    final firstTracker = MrrpDeliveryTracker(firstEngine);
    addTearDown(firstTracker.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mrrpDeliveryTrackerProvider.overrideWithValue(firstTracker),
          hapticServiceProvider.overrideWith((ref) => _NoopHapticService(ref)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ServiceDetailScreen(
            nodeId: nodeId,
            serviceId: kMeshServicesInstanceServiceId,
            serviceType: 'mesh-services.instance.v1',
            serviceTitle: 'Packing List',
            icon: Icons.checklist_rounded,
            accentColor: Colors.cyan,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(firstEngine.sendCount, 2);
    expect(find.text('Packing List'), findsWidgets);
    expect(find.text('Water'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final secondEngine = _FakeMrrpEngine()
      ..results.addAll([
        _okResult(
          actionId: MeshServicesAction.listInstances,
          payload: _buildListInstancesPayload(instance),
        ),
        _okResult(
          actionId: MeshServicesAction.getInstance,
          payload: _buildGetInstancePayload(
            instance: instance,
            checklistStates: const {0: false, 1: false},
            requesterNodeId: nodeId,
          ),
        ),
      ]);
    final secondTracker = MrrpDeliveryTracker(secondEngine);
    addTearDown(secondTracker.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mrrpDeliveryTrackerProvider.overrideWithValue(secondTracker),
          hapticServiceProvider.overrideWith((ref) => _NoopHapticService(ref)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ServiceDetailScreen(
            nodeId: nodeId,
            serviceId: kMeshServicesInstanceServiceId,
            serviceType: 'mesh-services.instance.v1',
            serviceTitle: 'Packing List',
            icon: Icons.checklist_rounded,
            accentColor: Colors.cyan,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(secondEngine.sendCount, 2);
    expect(find.text('Water'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
  });

  testWidgets('legacy cached list detail is revalidated on reopen', (
    tester,
  ) async {
    final instance = MeshServiceInstance(
      instanceId: 'legacycache123456',
      canonicalType: MeshServiceType.list,
      presetId: MeshServicePresetId.sharedChecklist,
      title: 'Camp Checklist',
      description: 'Older cached detail lacked inline list items.',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1710000000000),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(1710003600000),
      config: const {
        'items': ['Water', 'Map'],
      },
    );
    const nodeId = 0x13572468;

    final firstEngine = _FakeMrrpEngine()
      ..results.addAll([
        _okResult(
          actionId: MeshServicesAction.listInstances,
          payload: _buildListInstancesPayload(instance),
        ),
        _okResult(
          actionId: MeshServicesAction.getInstance,
          payload: _buildLegacyGetInstancePayload(instance: instance),
        ),
      ]);
    final firstTracker = MrrpDeliveryTracker(firstEngine);
    addTearDown(firstTracker.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mrrpDeliveryTrackerProvider.overrideWithValue(firstTracker),
          hapticServiceProvider.overrideWith((ref) => _NoopHapticService(ref)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ServiceDetailScreen(
            nodeId: nodeId,
            serviceId: kMeshServicesInstanceServiceId,
            serviceType: 'mesh-services.instance.v1',
            serviceTitle: 'Camp Checklist',
            icon: Icons.checklist_rounded,
            accentColor: Colors.cyan,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(firstEngine.sendCount, 2);
    expect(find.text('Camp Checklist'), findsWidgets);
    expect(find.text('Water'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final secondEngine = _FakeMrrpEngine()
      ..results.addAll([
        _okResult(
          actionId: MeshServicesAction.listInstances,
          payload: _buildListInstancesPayload(instance),
        ),
        _okResult(
          actionId: MeshServicesAction.getInstance,
          payload: _buildGetInstancePayload(
            instance: instance,
            checklistStates: const {0: false, 1: true},
            requesterNodeId: nodeId,
          ),
        ),
      ]);
    final secondTracker = MrrpDeliveryTracker(secondEngine);
    addTearDown(secondTracker.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mrrpDeliveryTrackerProvider.overrideWithValue(secondTracker),
          hapticServiceProvider.overrideWith((ref) => _NoopHapticService(ref)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ServiceDetailScreen(
            nodeId: nodeId,
            serviceId: kMeshServicesInstanceServiceId,
            serviceType: 'mesh-services.instance.v1',
            serviceTitle: 'Camp Checklist',
            icon: Icons.checklist_rounded,
            accentColor: Colors.cyan,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(secondEngine.sendCount, 2);
    expect(find.text('Water'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
  });
}
