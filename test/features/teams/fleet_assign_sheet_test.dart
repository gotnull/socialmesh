// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// The assignment sheet.
//
// Assignment and purpose are separate callables, so the properties that
// matter are about which writes actually leave the sheet:
//
//   - only the halves that changed are sent
//   - a failed assignment stops before the purpose write, so a refused
//     save never half-lands
//   - when both change and the second fails, the admin is told which
//     half landed instead of being sent back to redo finished work
//
// The client-side consistency rule is the same one the server enforces:
// `member` needs an active uid, the other two must not carry one. It is
// checked here so the admin is never offered a save the callable would
// reject.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/core/widgets/primary_gradient_button.dart';
import 'package:socialmesh/features/license_org/utils/member_label.dart';
import 'package:socialmesh/features/teams/application/fleet_providers.dart';
import 'package:socialmesh/features/teams/presentation/fleet_assign_sheet.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/license_org_fleet_device.dart';
import 'package:socialmesh/models/license_org_membership.dart';
import 'package:socialmesh/providers/license_org_fleet_providers.dart';
import 'package:socialmesh/providers/license_org_members_providers.dart';
import 'package:socialmesh/services/license_org/license_org_fleet_service.dart';

const _org = 'acme-team';
const _identity = 'mt-81c42d94';

late AppLocalizations _l10n;

LicenseOrgFleetDevice _device({
  FleetAssignmentKind assignment = FleetAssignmentKind.unassigned,
  String? assignedUid,
  String? purpose,
  FleetDeviceStatus status = FleetDeviceStatus.active,
}) {
  return LicenseOrgFleetDevice(
    id: fleetDeviceIdFor(licenseOrgId: _org, transportIdentity: _identity)!,
    licenseOrgId: _org,
    transport: FleetTransport.meshtastic,
    transportIdentity: _identity,
    label: 'North Gate',
    assignedUid: assignedUid,
    assignment: assignment,
    purpose: purpose,
    tags: const [],
    notes: null,
    lastKnownHardware: null,
    lastKnownFirmware: null,
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

/// Records the arguments of every write, so the assertions are about
/// what reached the callable rather than about the stub echoing back
/// what it was handed.
class _StubService implements LicenseOrgFleetService {
  FleetMutationResult assignResult;
  FleetMutationResult updateResult;

  final List<({FleetAssignmentKind assignment, String? uid})> assigns = [];
  final List<String?> purposes = [];

  _StubService({
    this.assignResult = const FleetMutationSuccess(
      fleetDeviceId: 'acme-team__mt-81c42d94',
      created: false,
    ),
    this.updateResult = const FleetMutationSuccess(
      fleetDeviceId: 'acme-team__mt-81c42d94',
      created: false,
    ),
  });

  @override
  Future<FleetMutationResult> assign({
    required String licenseOrgId,
    required FleetTransport transport,
    required String rawIdentity,
    required FleetAssignmentKind assignment,
    String? assignedUid,
  }) async {
    assigns.add((assignment: assignment, uid: assignedUid));
    return assignResult;
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
    purposes.add(purpose);
    return updateResult;
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
    throw StateError('the assignment sheet must never enrol');
  }

  @override
  Future<FleetMutationResult> retire({
    required String licenseOrgId,
    required FleetTransport transport,
    required String rawIdentity,
  }) async {
    throw StateError('the assignment sheet must never retire');
  }
}

Future<_StubService> _open(
  WidgetTester tester, {
  required LicenseOrgFleetDevice device,
  List<LicenseOrgMembership> members = const [],
  _StubService? service,
  LicenseOrgFleetDevice? liveDevice,
}) async {
  final stub = service ?? _StubService();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        licenseOrgFleetServiceProvider.overrideWithValue(stub),
        licenseOrgMembersProvider(
          _org,
        ).overrideWith((ref) => Stream.value(members)),
        // fleetDeviceByIdProvider derives from this, so overriding the
        // snapshot exercises the real lookup rather than stubbing it.
        licenseOrgFleetProvider(_org).overrideWith(
          (ref) => Stream.value(
            LicenseOrgFleetSnapshot(
              devices: [liveDevice ?? device],
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
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showFleetAssignSheet(
                context,
                licenseOrgId: _org,
                device: device,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return stub;
}

bool _saveEnabled(WidgetTester tester) {
  return tester
      .widget<PrimaryGradientButton>(find.byType(PrimaryGradientButton))
      .enabled;
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.byType(PrimaryGradientButton));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    _l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('save is offered only for a submittable, changed record', () {
    testWidgets('an untouched record cannot be saved', (tester) async {
      await _open(tester, device: _device());

      expect(_saveEnabled(tester), isFalse);
    });

    testWidgets('member without a person selected cannot be saved', (
      tester,
    ) async {
      await _open(tester, device: _device(), members: [_member('uid-alpha')]);

      await tester.tap(find.text(_l10n.fleetAssignMember));
      await tester.pumpAndSettle();

      // The callable rejects `member` with a null uid; offering Save
      // here would walk the admin into that refusal.
      expect(_saveEnabled(tester), isFalse);
    });

    testWidgets('member with a person selected can be saved', (tester) async {
      await _open(tester, device: _device(), members: [_member('uid-alpha')]);

      await tester.tap(find.text(_l10n.fleetAssignMember));
      await tester.pumpAndSettle();
      await tester.tap(find.text(licenseOrgMemberLabel('uid-alpha')));
      await tester.pumpAndSettle();

      expect(_saveEnabled(tester), isTrue);
    });

    testWidgets('switching away from member drops the uid', (tester) async {
      final stub = await _open(
        tester,
        device: _device(
          assignment: FleetAssignmentKind.member,
          assignedUid: 'uid-alpha',
        ),
        members: [_member('uid-alpha')],
      );

      await tester.tap(find.text(_l10n.fleetAssignOrgPool));
      await tester.pumpAndSettle();
      await _save(tester);

      // orgPool and unassigned are both null-uid server-side; carrying
      // the old uid across the switch would submit a contradictory
      // record.
      expect(stub.assigns, [
        (assignment: FleetAssignmentKind.orgPool, uid: null),
      ]);
    });
  });

  group('only the halves that changed are written', () {
    testWidgets('an assignment change alone issues no purpose write', (
      tester,
    ) async {
      final stub = await _open(tester, device: _device(purpose: 'North Gate'));

      await tester.tap(find.text(_l10n.fleetAssignOrgPool));
      await tester.pumpAndSettle();
      await _save(tester);

      expect(stub.assigns.length, 1);
      expect(stub.purposes, isEmpty);
    });

    testWidgets('a purpose change alone issues no assignment write', (
      tester,
    ) async {
      final stub = await _open(tester, device: _device());

      await tester.enterText(find.byType(TextField), 'Event Control');
      await tester.pumpAndSettle();
      await _save(tester);

      expect(stub.assigns, isEmpty);
      expect(stub.purposes, ['Event Control']);
    });

    testWidgets('clearing the purpose sends null, not an empty string', (
      tester,
    ) async {
      final stub = await _open(tester, device: _device(purpose: 'North Gate'));

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();
      await _save(tester);

      expect(stub.purposes, [null]);
    });

    testWidgets('both changes issue both writes, assignment first', (
      tester,
    ) async {
      final stub = await _open(tester, device: _device());

      await tester.tap(find.text(_l10n.fleetAssignOrgPool));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Event Control');
      await tester.pumpAndSettle();
      await _save(tester);

      expect(stub.assigns.length, 1);
      expect(stub.purposes, ['Event Control']);
    });
  });

  group('a refused write never half-lands', () {
    testWidgets('a failed assignment stops before the purpose write', (
      tester,
    ) async {
      final stub = _StubService(
        assignResult: const FleetMutationFailure(
          reason: FleetMutationReason.permissionDenied,
          message: 'denied',
        ),
      );
      await _open(tester, device: _device(), service: stub);

      await tester.tap(find.text(_l10n.fleetAssignOrgPool));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Event Control');
      await tester.pumpAndSettle();
      await _save(tester);

      expect(stub.purposes, isEmpty);
      expect(find.text(_l10n.fleetErrorPermissionDenied), findsOneWidget);
      // Still open: the admin keeps their edits rather than retyping.
      expect(find.text(_l10n.fleetAssignTitle), findsOneWidget);
      // In-sheet, never a SnackBar: this sheet covers most of the
      // screen and a root SnackBar draws behind it.
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a partial save names which half landed', (tester) async {
      final stub = _StubService(
        updateResult: const FleetMutationFailure(
          reason: FleetMutationReason.unavailable,
          message: 'offline',
        ),
      );
      await _open(tester, device: _device(), service: stub);

      await tester.tap(find.text(_l10n.fleetAssignOrgPool));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Event Control');
      await tester.pumpAndSettle();
      await _save(tester);

      expect(find.text(_l10n.fleetAssignPartialSave), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      // The flat message would send the admin back to redo an
      // assignment that is already saved.
      expect(find.text(_l10n.fleetErrorUnavailable), findsNothing);
      expect(find.text(_l10n.fleetAssignTitle), findsOneWidget);
    });

    testWidgets('a purpose-only failure reports its own reason', (
      tester,
    ) async {
      final stub = _StubService(
        updateResult: const FleetMutationFailure(
          reason: FleetMutationReason.unavailable,
          message: 'offline',
        ),
      );
      await _open(tester, device: _device(), service: stub);

      await tester.enterText(find.byType(TextField), 'Event Control');
      await tester.pumpAndSettle();
      await _save(tester);

      // Nothing landed, so there is no partial to report.
      expect(find.text(_l10n.fleetErrorUnavailable), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text(_l10n.fleetAssignPartialSave), findsNothing);
    });

    testWidgets('a successful save closes the sheet', (tester) async {
      await _open(tester, device: _device());

      await tester.tap(find.text(_l10n.fleetAssignOrgPool));
      await tester.pumpAndSettle();
      await _save(tester);

      expect(find.text(_l10n.fleetAssignTitle), findsNothing);
      expect(find.text(_l10n.fleetAssignedSnack), findsOneWidget);
    });
  });

  group('state the admin has to be told about', () {
    testWidgets('a departed assignee is surfaced, not silently cleared', (
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

      expect(find.text(_l10n.fleetAssignInactiveMember), findsOneWidget);
      // The departed uid is not offered as a choice: the callable
      // re-reads the roster and would refuse it.
      expect(find.text(licenseOrgMemberLabel('uid-gone')), findsNothing);
      expect(find.text(licenseOrgMemberLabel('uid-alpha')), findsOneWidget);
    });

    testWidgets('an empty roster explains itself rather than showing nothing', (
      tester,
    ) async {
      await _open(tester, device: _device());

      await tester.tap(find.text(_l10n.fleetAssignMember));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.fleetAssignNoMembers), findsOneWidget);
    });

    testWidgets('a radio retired elsewhere stops offering a save', (
      tester,
    ) async {
      await _open(
        tester,
        device: _device(),
        liveDevice: _device(status: FleetDeviceStatus.retired),
      );

      expect(find.text(_l10n.fleetErrorDeviceRetired), findsOneWidget);
      expect(_saveEnabled(tester), isFalse);
    });
  });
}
