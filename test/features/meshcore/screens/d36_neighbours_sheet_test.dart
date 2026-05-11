// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D36-A: `showMeshCoreNeighborsSheet` rendering regression pins.
//
// We stub `meshCoreNeighborsProvider` directly with the family-arg
// overrideWith form so each test can drive the sheet into a specific
// state (success, timeout, cooling, empty) without exercising the
// session or transport.
//
// Pinned invariants (this file):
//   - Sheet header renders the repeater name.
//   - Success state renders one row per neighbour with resolved
//     contact name (or redacted `<8-char-hex>` prefix when no match).
//   - Empty success state (zero rows) renders the "no data" hint.
//   - Failure (timeout) renders the timeout copy.
//   - Cooling state renders the "Try again in Ns" copy.
//   - Banned-pattern sweep on every rendered Text widget:
//     no full 32-byte pubkey hex, no MMF, no [mrrp], no base64 envelope.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_neighbors_sheet.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';

class _StubNeighborsNotifier extends MeshCoreNeighborsNotifier {
  _StubNeighborsNotifier(super.publicKeyHex, this._initial);
  final MeshCoreNeighborsState _initial;

  @override
  MeshCoreNeighborsState build() => _initial;

  @override
  Future<void> requestRefresh() async {
    // No-op in tests; the sheet's initState calls requestRefresh()
    // but we want the stubbed state to remain unchanged.
  }
}

class _StubContactsNotifier extends MeshCoreContactsNotifier {
  _StubContactsNotifier(this._seed);
  final List<MeshCoreContact> _seed;

  @override
  MeshCoreContactsState build() {
    return MeshCoreContactsState(contacts: List.unmodifiable(_seed));
  }
}

class _SheetOpener extends StatefulWidget {
  final MeshCoreContact repeater;
  const _SheetOpener({required this.repeater});

  @override
  State<_SheetOpener> createState() => _SheetOpenerState();
}

class _SheetOpenerState extends State<_SheetOpener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showMeshCoreNeighborsSheet(context, repeater: widget.repeater);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand();
  }
}

MeshCoreContact _repeater({String name = 'Repeater-Alpha'}) {
  return MeshCoreContact(
    publicKey: Uint8List.fromList(List.generate(32, (i) => i + 1)),
    name: name,
    type: MeshCoreAdvType.repeater,
    pathLength: -1,
    path: Uint8List(0),
    lastSeen: DateTime(2026, 5, 11, 12),
  );
}

Widget _wrap({
  required MeshCoreContact repeater,
  required MeshCoreNeighborsState state,
  List<MeshCoreContact> contacts = const [],
}) {
  return ProviderScope(
    overrides: [
      meshCoreContactsProvider.overrideWith(
        () => _StubContactsNotifier(contacts),
      ),
      meshCoreNeighborsProvider(repeater.publicKeyHex).overrideWith(
        () => _StubNeighborsNotifier(repeater.publicKeyHex, state),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: _SheetOpener(repeater: repeater)),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  // _SheetOpener triggers the bottom sheet from initState's
  // post-frame callback. Pump twice to drive the modal-route
  // animation past the in-flight phase so the sheet content is
  // findable.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Banned patterns that MUST NEVER appear in any rendered text node.
final List<RegExp> _bannedRenderTextPatterns = [
  RegExp(r'\[mrrp\]'),
  RegExp(r'\[/mrrp\]'),
  RegExp(r'02:[0-9a-f]{12}:'),
  RegExp(r'01:[0-9a-f]{2}:'),
  // 32-byte hex pubkey (any case) - never expand the 4-byte prefix.
  RegExp(r'[0-9a-fA-F]{64}'),
  // Long base64-ish runs (envelope content).
  RegExp(r'[A-Za-z0-9+/_-]{32,}={0,2}'),
];

void _expectNoBannedText(WidgetTester tester) {
  final allTexts = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .toList();
  for (final pat in _bannedRenderTextPatterns) {
    for (final t in allTexts) {
      expect(
        pat.hasMatch(t),
        isFalse,
        reason: 'banned pattern $pat matched rendered text "$t"',
      );
    }
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('success state renders the repeater name in the title plus '
      'one row per neighbour', (tester) async {
    tester.view.physicalSize = const Size(440, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repeater = _repeater(name: 'Repeater-Alpha');
    final knownNeighbour = MeshCoreContact(
      publicKey: Uint8List.fromList([
        0xAA,
        0xBB,
        0xCC,
        0xDD,
        ...List.generate(28, (i) => 0xEE),
      ]),
      name: 'KnownPeer',
      type: MeshCoreAdvType.chat,
      pathLength: 0,
      path: Uint8List(0),
      lastSeen: DateTime(2026, 5, 11, 12),
    );
    final state = MeshCoreNeighborsState(
      status: MeshCoreNeighborsStatus.success,
      lastResponse: MeshCoreNeighborsResponse(
        reportedCount: 2,
        results: [
          MeshCoreNeighbor(
            pubKeyPrefix: Uint8List.fromList([0xAA, 0xBB, 0xCC, 0xDD]),
            lastHeard: const Duration(seconds: 42),
            snrQuarter: 24, // 6.0 dB
          ),
          MeshCoreNeighbor(
            pubKeyPrefix: Uint8List.fromList([0xFA, 0xCE, 0xB0, 0x0C]),
            lastHeard: const Duration(minutes: 5, seconds: 17),
            snrQuarter: -20, // -5.0 dB
          ),
        ],
        fetchedAt: DateTime(2026, 5, 11, 12, 34, 56),
      ),
    );

    await tester.pumpWidget(
      _wrap(repeater: repeater, state: state, contacts: [knownNeighbour]),
    );
    await tester.pump();
    await _openSheet(tester);

    // SectionTitle uppercases the whole title string.
    expect(find.text('NEIGHBOURS - REPEATER-ALPHA'), findsOneWidget);
    // Known prefix resolved against the local roster.
    expect(find.text('KnownPeer'), findsOneWidget);
    // Unknown prefix renders as redacted `<8-char-hex>`.
    expect(find.text('<faceb00c>'), findsOneWidget);
    // Heard times.
    expect(find.text('heard 42 s ago'), findsOneWidget);
    expect(find.text('heard 5 m 17 s ago'), findsOneWidget);
    // SNR values.
    expect(find.text('SNR 6.0 dB'), findsOneWidget);
    expect(find.text('SNR -5.0 dB'), findsOneWidget);
    // Footer.
    expect(find.text('Showing 2 of 2 neighbours'), findsOneWidget);

    _expectNoBannedText(tester);
  });

  testWidgets('empty success state (zero rows) renders the no-data hint', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repeater = _repeater();
    final state = MeshCoreNeighborsState(
      status: MeshCoreNeighborsStatus.success,
      lastResponse: MeshCoreNeighborsResponse(
        reportedCount: 0,
        results: const [],
        fetchedAt: DateTime(2026, 5, 11, 12),
      ),
    );

    await tester.pumpWidget(_wrap(repeater: repeater, state: state));
    await tester.pump();
    await _openSheet(tester);

    expect(find.text('No data available'), findsOneWidget);
    _expectNoBannedText(tester);
  });

  testWidgets('failure (timeout) renders the timeout copy', (tester) async {
    tester.view.physicalSize = const Size(440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repeater = _repeater();
    final state = MeshCoreNeighborsState(
      status: MeshCoreNeighborsStatus.failure,
      lastError: 'timeout',
    );

    await tester.pumpWidget(_wrap(repeater: repeater, state: state));
    await tester.pump();
    await _openSheet(tester);

    expect(
      find.text('Request timed out. The repeater did not respond.'),
      findsOneWidget,
    );
    _expectNoBannedText(tester);
  });

  testWidgets('cooling state renders the "Try again in Ns" copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repeater = _repeater();
    final state = MeshCoreNeighborsState(
      status: MeshCoreNeighborsStatus.cooling,
      cooldownUntil: DateTime.now().add(const Duration(seconds: 8)),
    );

    await tester.pumpWidget(_wrap(repeater: repeater, state: state));
    await tester.pump();
    await _openSheet(tester);

    // Allow 1 second of slack on either side - clock advance during
    // pump + DateTime.now() reads can shave a second off the rounding.
    final cooling = find.textContaining(RegExp(r'Try again in [678]s'));
    expect(cooling, findsOneWidget);
    _expectNoBannedText(tester);
  });
}
