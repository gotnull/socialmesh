// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// The fleet detail screen.
//
// The containment property is the one that matters most: this screen
// shows CONFIGURED metadata and an enrolment-time snapshot, and nothing
// live. A battery reading, a signal figure or a derived health verdict
// appearing here would turn an inventory record into something an
// operator reads as current, with no observation pipeline behind it.
//
// The rest is about honest state: a retired record stays readable, a
// departed assignee is named rather than collapsed into "not assigned",
// and retirement asks first and reports what actually happened.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/features/license_org/utils/member_label.dart';
import 'package:socialmesh/features/teams/application/fleet_providers.dart';
import 'package:socialmesh/features/teams/presentation/fleet_device_detail_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/license_org_fleet_device.dart';
import 'package:socialmesh/models/license_org_membership.dart';
import 'package:socialmesh/providers/connectivity_providers.dart';
import 'package:socialmesh/providers/license_org_fleet_providers.dart';
import 'package:socialmesh/providers/license_org_members_providers.dart';
import 'package:socialmesh/providers/license_org_overview_providers.dart';
import 'package:socialmesh/services/license_org/license_org_fleet_service.dart';

const _org = 'acme-team';
const _identity = 'mt-81c42d94';
final _deviceId = fleetDeviceIdFor(
  licenseOrgId: _org,
  transportIdentity: _identity,
)!;

late AppLocalizations _l10n;

LicenseOrgFleetDevice _device({
  FleetAssignmentKind assignment = FleetAssignmentKind.unassigned,
  String? assignedUid,
  String? purpose,
  FleetDeviceStatus status = FleetDeviceStatus.active,
  FleetTransport transport = FleetTransport.meshtastic,
  String? hardware = 'TRACKER_T1000_E',
  String? firmware = '2.7.19',
}) {
  return LicenseOrgFleetDevice(
    id: _deviceId,
    licenseOrgId: _org,
    transport: transport,
    transportIdentity: _identity,
    label: 'North Gate',
    assignedUid: assignedUid,
    assignment: assignment,
    purpose: purpose,
    tags: const ['gate'],
    notes: null,
    lastKnownHardware: hardware,
    lastKnownFirmware: firmware,
    createdBy: 'admin-1',
    createdAt: DateTime.utc(2026, 8, 1),
    updatedAt: DateTime.utc(2026, 8, 14),
    status: status,
  );
}

LicenseOrgMembership _member(String uid) {
  return LicenseOrgMembership(
    uid: uid,
    orgId: _org,
    role: LicenseOrgMemberRole.member,
    joinedAt: DateTime.utc(2026, 7, 1),
    invitedBy: 'admin-1',
    status: LicenseOrgMemberStatus.active,
  );
}

class _StubService implements LicenseOrgFleetService {
  FleetMutationResult retireResult;
  int retireCalls = 0;

  _StubService({
    this.retireResult = const FleetMutationSuccess(
      fleetDeviceId: 'acme-team__mt-81c42d94',
      created: false,
    ),
  });

  @override
  Future<FleetMutationResult> retire({
    required String licenseOrgId,
    required FleetTransport transport,
    required String rawIdentity,
  }) async {
    retireCalls++;
    return retireResult;
  }

  @override
  Future<FleetMutationResult> enroll({
    required String licenseOrgId,
    required FleetTransport transport,
    required String rawIdentity,
    String? label,
    String? purpose,
    List<String>? tags,
    String? notes,
    String? lastKnownHardware,
    String? lastKnownFirmware,
  }) async {
    throw StateError('the detail screen must never enrol');
  }

  @override
  Future<FleetMutationResult> update({
    required String licenseOrgId,
    required FleetTransport transport,
    required String rawIdentity,
    String? label,
    String? purpose,
    List<String>? tags,
    String? notes,
  }) async {
    throw StateError('the detail screen must never update metadata');
  }

  @override
  Future<FleetMutationResult> assign({
    required String licenseOrgId,
    required FleetTransport transport,
    required String rawIdentity,
    required FleetAssignmentKind assignment,
    String? assignedUid,
  }) async {
    throw StateError('the detail screen must never assign directly');
  }
}

Future<_StubService> _open(
  WidgetTester tester, {
  LicenseOrgFleetDevice? device,
  List<LicenseOrgMembership> members = const [],
  LicenseOrgMemberRole role = LicenseOrgMemberRole.owner,
  bool online = true,
  _StubService? service,
}) async {
  final stub = service ?? _StubService();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        licenseOrgFleetServiceProvider.overrideWithValue(stub),
        isOnlineProvider.overrideWithValue(online),
        licenseOrgRoleProvider(_org).overrideWithValue(role),
        licenseOrgMembersProvider(
          _org,
        ).overrideWith((ref) => Stream.value(members)),
        licenseOrgFleetProvider(_org).overrideWith(
          (ref) => Stream.value(
            LicenseOrgFleetSnapshot(
              devices: device == null ? const [] : [device],
              source: FleetSnapshotSource.cloud,
              syncedAt: DateTime.utc(2026, 8, 15),
              isStale: false,
              isRefreshing: false,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme(AccentColors.magenta),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FleetDeviceDetailScreen(
          licenseOrgId: _org,
          fleetDeviceId: _deviceId,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return stub;
}

void main() {
  setUpAll(() async {
    _l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('nothing live reaches this screen', () {
    testWidgets('the snapshot is labelled as a snapshot', (tester) async {
      await _open(tester, device: _device());

      expect(
        find.text(_l10n.fleetDetailSectionSnapshot.toUpperCase()),
        findsOneWidget,
      );
      // Without this note a firmware string reads as current.
      expect(find.text(_l10n.fleetSnapshotNote), findsOneWidget);
      expect(find.text('2.7.19'), findsOneWidget);
    });

    testWidgets('no battery, signal or health verdict is shown', (
      tester,
    ) async {
      await _open(tester, device: _device());

      for (final forbidden in [
        _l10n.nodeHealthUnknown,
        _l10n.nodeDetailSignalUnknown,
      ]) {
        expect(find.text(forbidden), findsNothing);
      }
      // Every visible row is one this screen declares.
      expect(
        find.text(_l10n.fleetDetailSectionRecord.toUpperCase()),
        findsOneWidget,
      );
      expect(find.text(_l10n.fleetLabelStatus), findsOneWidget);
      expect(find.text(_l10n.fleetLabelIdentity), findsOneWidget);
    });

    testWidgets('a MeshCore radio carries its reset caveat', (tester) async {
      await _open(tester, device: _device(transport: FleetTransport.meshCore));
      await tester.dragUntilVisible(
        find.text(_l10n.fleetMeshCoreResetNote),
        find.byType(Scrollable).first,
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();

      // A factory reset produces a genuinely different key, and
      // SocialMesh cannot tell it is the same physical radio.
      expect(find.text(_l10n.fleetMeshCoreResetNote), findsOneWidget);
    });

    testWidgets('a Meshtastic radio does not carry the MeshCore caveat', (
      tester,
    ) async {
      await _open(tester, device: _device());
      // Scrolled to the end first: findsNothing on an unscrolled list
      // would pass merely because the banner is below the fold.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.fleetSnapshotNote), findsOneWidget);
      expect(find.text(_l10n.fleetMeshCoreResetNote), findsNothing);
    });
  });

  group('state is reported honestly', () {
    testWidgets('a retired record stays readable', (tester) async {
      await _open(tester, device: _device(status: FleetDeviceStatus.retired));

      expect(find.text(_l10n.fleetSectionRetired), findsOneWidget);
      // Retirement is soft: the record is still here to read.
      expect(find.text(_identity), findsOneWidget);
    });

    testWidgets('a departed assignee is named, not collapsed to unassigned', (
      tester,
    ) async {
      await _open(
        tester,
        device: _device(
          assignment: FleetAssignmentKind.member,
          assignedUid: 'uid-gone',
        ),
        members: [_member('uid-alpha')],
      );

      final label = licenseOrgMemberLabel('uid-gone');
      expect(
        find.text('$label - ${_l10n.fleetAssignInactiveMember}'),
        findsOneWidget,
      );
      expect(find.text(_l10n.fleetAssignNobody), findsNothing);
    });

    testWidgets('an active assignee shows the plain roster label', (
      tester,
    ) async {
      await _open(
        tester,
        device: _device(
          assignment: FleetAssignmentKind.member,
          assignedUid: 'uid-alpha',
        ),
        members: [_member('uid-alpha')],
      );

      expect(find.text(licenseOrgMemberLabel('uid-alpha')), findsOneWidget);
    });

    testWidgets('a record that left the fleet says so', (tester) async {
      await _open(tester, device: null);

      expect(find.text(_l10n.fleetDetailMissing), findsOneWidget);
    });
  });

  group('write capability', () {
    testWidgets('a plain member is told why, and gets no retire action', (
      tester,
    ) async {
      await _open(tester, device: _device(), role: LicenseOrgMemberRole.member);

      expect(find.text(_l10n.fleetErrorPermissionDenied), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('offline blocks writes without hiding the record', (
      tester,
    ) async {
      await _open(tester, device: _device(), online: false);

      expect(find.text(_l10n.fleetOfflineWriteBlocked), findsOneWidget);
      // Reading is unaffected: the block is about mutation only.
      expect(find.text(_identity), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('a retired record offers no further mutation', (tester) async {
      await _open(tester, device: _device(status: FleetDeviceStatus.retired));

      expect(find.byIcon(Icons.more_vert), findsNothing);
    });
  });

  group('retirement', () {
    Future<void> tapRetire(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n.fleetRetireAction).last);
      await tester.pumpAndSettle();
    }

    testWidgets('asks first and does nothing when declined', (tester) async {
      final stub = await _open(tester, device: _device());

      await tapRetire(tester);
      expect(find.text(_l10n.fleetRetireConfirmTitle), findsOneWidget);
      // Says where the radio goes, rather than warning about data loss
      // that soft retirement does not cause.
      expect(find.text(_l10n.fleetRetireConfirmBody), findsOneWidget);

      await tester.tap(find.text(_l10n.commonCancel));
      await tester.pumpAndSettle();

      expect(stub.retireCalls, 0);
    });

    testWidgets('retires on confirmation', (tester) async {
      final stub = await _open(tester, device: _device());

      await tapRetire(tester);
      await tester.tap(find.text(_l10n.fleetRetireAction).last);
      await tester.pumpAndSettle();

      expect(stub.retireCalls, 1);
      expect(find.text(_l10n.fleetRetiredSnack), findsOneWidget);
    });

    testWidgets('a refusal is reported by reason, not swallowed', (
      tester,
    ) async {
      final stub = _StubService(
        retireResult: const FleetMutationFailure(
          reason: FleetMutationReason.unavailable,
          message: 'offline',
        ),
      );
      await _open(tester, device: _device(), service: stub);

      await tapRetire(tester);
      await tester.tap(find.text(_l10n.fleetRetireAction).last);
      await tester.pumpAndSettle();

      expect(find.text(_l10n.fleetErrorUnavailable), findsOneWidget);
      expect(find.text(_l10n.fleetRetiredSnack), findsNothing);
    });
  });
}
