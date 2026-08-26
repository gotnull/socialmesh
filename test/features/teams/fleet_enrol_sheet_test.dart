// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// The enrol picker.
//
// Two properties carry the weight here:
//
//   1. an empty list is never the answer to "no protocol" or "the
//      source failed" - each gets its own explanation, because an admin
//      told "nothing to enrol" would go looking for radios rather than
//      reconnecting one.
//   2. only Available candidates can reach the callable. The other
//      three states stay VISIBLE - hiding them leaves an admin hunting
//      for a radio that is already enrolled with no clue where it went -
//      but tapping them must do nothing at all.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/core/widgets/loading_indicator.dart';
import 'package:socialmesh/features/teams/application/fleet_candidate_source.dart';
import 'package:socialmesh/features/teams/application/fleet_enrol_candidates.dart';
import 'package:socialmesh/features/teams/application/fleet_providers.dart';
import 'package:socialmesh/features/teams/presentation/fleet_enrol_sheet.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/license_org_fleet_device.dart';
import 'package:socialmesh/providers/license_org_fleet_providers.dart';
import 'package:socialmesh/services/license_org/license_org_fleet_service.dart';

const _org = 'acme-team';

late AppLocalizations _l10n;

String _stateLabel(FleetCandidateState state) => switch (state) {
  FleetCandidateState.available => _l10n.fleetCandidateAvailable,
  FleetCandidateState.alreadyInFleet => _l10n.fleetCandidateAlreadyInFleet,
  FleetCandidateState.retiredInFleet => _l10n.fleetCandidateRetired,
  FleetCandidateState.unsupported => _l10n.fleetCandidateIdentityUnavailable,
};

FleetEnrolCandidate _candidate({
  required String identity,
  required FleetCandidateState state,
  String displayName = 'North Gate',
  bool isLocalDevice = false,
}) {
  return FleetEnrolCandidate(
    transportIdentity: state == FleetCandidateState.unsupported
        ? null
        : identity,
    rawIdentity: state == FleetCandidateState.unsupported
        ? null
        : identity.substring(3),
    transport: FleetTransport.meshtastic,
    displayName: displayName,
    observedHardware: 'TRACKER_T1000_E',
    observedFirmware: '2.7.19',
    isLocalDevice: isLocalDevice,
    state: state,
  );
}

// Records what actually reached the callable. The assertions are about
// the enrol arguments, not about the stub returning what it was told to.
class _StubService implements LicenseOrgFleetService {
  FleetMutationResult result;

  /// Raw identities that reached `enroll`.
  final List<String> enrolled = [];

  /// Any other mutation the sheet triggered. The picker enrols and
  /// nothing else, so this staying empty is part of the contract.
  final List<String> otherCalls = [];

  _StubService(this.result);

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
    enrolled.add(rawIdentity);
    return result;
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
    otherCalls.add('update');
    return result;
  }

  @override
  Future<FleetMutationResult> assign({
    required String licenseOrgId,
    required FleetTransport transport,
    required String rawIdentity,
    required FleetAssignmentKind assignment,
    String? assignedUid,
  }) async {
    otherCalls.add('assign');
    return result;
  }

  @override
  Future<FleetMutationResult> retire({
    required String licenseOrgId,
    required FleetTransport transport,
    required String rawIdentity,
  }) async {
    otherCalls.add('retire');
    return result;
  }
}

Future<_StubService> _open(
  WidgetTester tester,
  FleetCandidateSource source, {
  FleetMutationResult result = const FleetMutationSuccess(
    fleetDeviceId: 'acme-team__mt-81c42d94',
    created: true,
  ),
}) async {
  final service = _StubService(result);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fleetCandidateSourceProvider(_org).overrideWithValue(source),
        licenseOrgFleetServiceProvider.overrideWithValue(service),
        // The controller invalidates this on success; without an
        // override that would reach the real Firestore repository.
        licenseOrgFleetProvider(_org).overrideWith(
          (ref) => Stream.value(
            const LicenseOrgFleetSnapshot(
              devices: [],
              source: FleetSnapshotSource.cloud,
              syncedAt: null,
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
              onPressed: () => showFleetEnrolSheet(context, licenseOrgId: _org),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return service;
}

void main() {
  setUpAll(() async {
    _l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('the sheet never answers a source problem with an empty list', () {
    testWidgets('no active protocol says to connect a radio', (tester) async {
      await _open(tester, const FleetCandidateSourceNoProtocol());

      expect(find.text(_l10n.fleetEnrolNoProtocol), findsOneWidget);
      expect(find.text(_l10n.fleetEnrolNoCandidates), findsNothing);
    });

    testWidgets('a failed source is not reported as nothing found', (
      tester,
    ) async {
      await _open(tester, const FleetCandidateSourceUnavailable());

      expect(find.text(_l10n.fleetEnrolSourceUnavailable), findsOneWidget);
      expect(find.text(_l10n.fleetEnrolNoCandidates), findsNothing);
    });

    testWidgets('resolving shows progress, not an empty claim', (tester) async {
      final service = _StubService(
        const FleetMutationSuccess(fleetDeviceId: 'x', created: true),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fleetCandidateSourceProvider(
              _org,
            ).overrideWithValue(const FleetCandidateSourceLoading()),
            licenseOrgFleetServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme(AccentColors.magenta),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      showFleetEnrolSheet(context, licenseOrgId: _org),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      // Deliberately not pumpAndSettle: the indicator animates forever.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(LoadingIndicator), findsOneWidget);
      expect(find.text(_l10n.fleetEnrolNoCandidates), findsNothing);
      expect(find.text(_l10n.fleetEnrolNoProtocol), findsNothing);
    });

    testWidgets('resolved-but-empty is the only state that claims nothing', (
      tester,
    ) async {
      await _open(tester, const FleetCandidateSourceReady([]));

      expect(find.text(_l10n.fleetEnrolNoCandidates), findsOneWidget);
    });
  });

  group('framing', () {
    testWidgets('says these are observed radios, not owned ones', (
      tester,
    ) async {
      await _open(
        tester,
        FleetCandidateSourceReady([
          _candidate(
            identity: 'mt-81c42d94',
            state: FleetCandidateState.available,
          ),
        ]),
      );

      expect(find.text(_l10n.fleetEnrolHeader), findsOneWidget);
      expect(find.text(_l10n.fleetEnrolHeaderBody), findsOneWidget);
      // Enrolment records metadata; it never writes to the radio.
      expect(find.text(_l10n.fleetEnrolBoundaryNote), findsOneWidget);
    });

    testWidgets('the connected radio is marked, not hidden', (tester) async {
      await _open(
        tester,
        FleetCandidateSourceReady([
          _candidate(
            identity: 'mt-81c42d94',
            state: FleetCandidateState.available,
            isLocalDevice: true,
          ),
        ]),
      );

      expect(find.text(_l10n.fleetCandidateLocalDevice), findsOneWidget);
      expect(find.text('North Gate'), findsOneWidget);
    });
  });

  group('only Available candidates can reach the callable', () {
    testWidgets('tapping an available candidate enrols its raw identity', (
      tester,
    ) async {
      final service = await _open(
        tester,
        FleetCandidateSourceReady([
          _candidate(
            identity: 'mt-81c42d94',
            state: FleetCandidateState.available,
          ),
        ]),
      );

      await tester.tap(find.text('North Gate'));
      await tester.pumpAndSettle();

      expect(service.enrolled, ['81c42d94']);
      // The picker enrols; it never assigns, updates or retires.
      expect(service.otherCalls, isEmpty);
    });

    for (final entry in <FleetCandidateState, String>{
      FleetCandidateState.alreadyInFleet: 'already in fleet',
      FleetCandidateState.retiredInFleet: 'retired',
      FleetCandidateState.unsupported: 'identity unavailable',
    }.entries) {
      testWidgets('${entry.value} is visible, labelled and inert', (
        tester,
      ) async {
        final service = await _open(
          tester,
          FleetCandidateSourceReady([
            _candidate(identity: 'mt-81c42d94', state: entry.key),
          ]),
        );

        // Visible: an admin looking for this radio must be told why it
        // is not on offer.
        expect(find.text('North Gate'), findsOneWidget);
        expect(find.text(_stateLabel(entry.key)), findsOneWidget);

        await tester.tap(find.text('North Gate'));
        await tester.pumpAndSettle();

        expect(service.enrolled, isEmpty);
      });
    }

    testWidgets('an available candidate is labelled as such', (tester) async {
      await _open(
        tester,
        FleetCandidateSourceReady([
          _candidate(
            identity: 'mt-81c42d94',
            state: FleetCandidateState.available,
          ),
        ]),
      );

      expect(
        find.text(_stateLabel(FleetCandidateState.available)),
        findsOneWidget,
      );
    });

    testWidgets('an unsupported candidate explains what it means', (
      tester,
    ) async {
      await _open(
        tester,
        FleetCandidateSourceReady([
          _candidate(
            identity: 'mt-81c42d94',
            state: FleetCandidateState.unsupported,
          ),
        ]),
      );

      // "Identity unavailable" alone leaves the admin guessing whether
      // the radio is broken or the app is.
      expect(
        find.text(_l10n.fleetCandidateIdentityUnavailableHelp),
        findsOneWidget,
      );
    });
  });

  group('outcome handling', () {
    testWidgets('success closes the sheet and lets the authority refresh', (
      tester,
    ) async {
      await _open(
        tester,
        FleetCandidateSourceReady([
          _candidate(
            identity: 'mt-81c42d94',
            state: FleetCandidateState.available,
          ),
        ]),
      );

      await tester.tap(find.text('North Gate'));
      await tester.pumpAndSettle();

      // No locally injected row: the sheet is gone and the list the
      // admin returns to is whatever the invalidated fleet emits.
      expect(find.text(_l10n.fleetEnrolHeader), findsNothing);
      expect(find.text(_l10n.fleetAddedSnack), findsOneWidget);
    });

    testWidgets('a refusal keeps the sheet open and names the reason', (
      tester,
    ) async {
      await _open(
        tester,
        FleetCandidateSourceReady([
          _candidate(
            identity: 'mt-81c42d94',
            state: FleetCandidateState.available,
          ),
        ]),
        result: const FleetMutationFailure(
          reason: FleetMutationReason.deviceRetired,
          message: 'retired',
        ),
      );

      await tester.tap(find.text('North Gate'));
      await tester.pumpAndSettle();

      // Still open: the admin has not lost their place, and the picker
      // rebuilds from the authority so a state that changed underneath
      // them corrects itself.
      expect(find.text(_l10n.fleetEnrolHeader), findsOneWidget);
      expect(find.text(_l10n.fleetErrorDeviceRetired), findsOneWidget);
      // The refusal must render INSIDE the sheet. A SnackBar here comes
      // from the root ScaffoldMessenger and draws behind this sheet, so
      // the admin would be told nothing at all - caught on the
      // simulator, invisible to a finder that ignores occlusion.
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('an already-enrolled radio is not reported as newly added', (
      tester,
    ) async {
      await _open(
        tester,
        FleetCandidateSourceReady([
          _candidate(
            identity: 'mt-81c42d94',
            state: FleetCandidateState.available,
          ),
        ]),
        result: const FleetMutationSuccess(
          fleetDeviceId: 'acme-team__mt-81c42d94',
          created: false,
        ),
      );

      await tester.tap(find.text('North Gate'));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.fleetAlreadyAddedSnack), findsOneWidget);
      expect(find.text(_l10n.fleetAddedSnack), findsNothing);
    });
  });
}
