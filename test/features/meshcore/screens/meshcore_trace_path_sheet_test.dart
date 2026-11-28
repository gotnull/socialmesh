// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/widgets/primary_gradient_button.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_tools_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';

class _NullTransport implements MeshCoreTransport {
  @override
  Stream<Uint8List> get rawRxStream => const Stream.empty();

  @override
  Future<void> sendRaw(Uint8List data) async {}

  @override
  bool get isConnected => true;
}

// Answers every trace as if each hop heard it at 6 dB, and records what
// was sent.
class _TraceSession extends MeshCoreSession {
  _TraceSession() : super(_NullTransport());

  final List<List<int>> paths = [];
  final List<int> flags = [];

  @override
  bool get isActive => true;

  @override
  Future<MeshCoreTraceResult?> sendTracePath({
    required int tag,
    required Uint8List path,
    int authCode = 0,
    int flag = 0,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    paths.add(List.of(path));
    flags.add(flag);
    final size = 1 << (flag & 0x03);
    return MeshCoreTraceResult(
      tag: tag,
      flag: flag,
      authCode: authCode,
      hops: [
        for (var i = 0; i + size <= path.length; i += size)
          MeshCoreTraceHop(
            hash: Uint8List.fromList(path.sublist(i, i + size)),
            snrQuarter: 24,
          ),
      ],
      finalSnrQuarter: 20,
    );
  }
}

MeshCoreContact _contact(String name, int first, int type) => MeshCoreContact(
  publicKey: Uint8List.fromList(List.generate(32, (i) => (first + i) & 0xFF)),
  name: name,
  type: type,
  pathLength: 0,
  path: Uint8List(0),
  lastSeen: DateTime(2026, 11, 24, 12),
);

class _Roster extends MeshCoreContactsNotifier {
  @override
  MeshCoreContactsState build() => MeshCoreContactsState(
    contacts: [
      _contact('TerryDev2', 0x79, MeshCoreAdvType.chat),
      _contact('Coburg Hill', 0x30, MeshCoreAdvType.repeater),
      _contact('Bendigo Relay', 0x40, MeshCoreAdvType.repeater),
    ],
    lastRefresh: DateTime(2026, 11, 24),
  );
}

Widget _wrap({MeshCoreSession? session, MeshCoreContact? initialContact}) =>
    ProviderScope(
      overrides: [
        meshCoreSessionProvider.overrideWithValue(session),
        meshCoreContactsProvider.overrideWith(_Roster.new),
        meshCoreSelfPubKeyPrefixProvider.overrideWithValue('5a7e0001'),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.dark(),
        home: Material(
          child: MeshCoreTracePathSheet(
            scrollController: ScrollController(),
            initialContact: initialContact,
          ),
        ),
      ),
    );

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(MeshCoreTracePathSheet)));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

PrimaryGradientButton _primary(WidgetTester tester) =>
    tester.widget<PrimaryGradientButton>(find.byType(PrimaryGradientButton));

const _arrow = ' \u2192 ';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('search narrows the trace targets; Run waits for a pick', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap());
    await tester.pump();

    expect(find.text('TerryDev2'), findsOneWidget);
    expect(find.text('Coburg Hill'), findsOneWidget);
    PrimaryGradientButton run() => tester.widget<PrimaryGradientButton>(
      find.byType(PrimaryGradientButton),
    );
    expect(run().enabled, isFalse);

    await tester.enterText(find.byType(TextField), 'terry');
    await tester.pump();
    expect(find.text('TerryDev2'), findsOneWidget);
    expect(find.text('Coburg Hill'), findsNothing);

    // A key prefix finds a contact too.
    await tester.enterText(find.byType(TextField), '3031');
    await tester.pump();
    expect(find.text('Coburg Hill'), findsOneWidget);
    expect(find.text('TerryDev2'), findsNothing);

    await tester.tap(find.text('Coburg Hill'));
    await tester.pump();
    expect(run().enabled, isTrue);
  });

  testWidgets('a failed trace offers Retry and Back to the picker', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap());
    await tester.pump();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(MeshCoreTracePathSheet)),
    );

    // No session: the trace fails at once.
    await tester.tap(find.text('TerryDev2'));
    await tester.pump();
    await tester.tap(find.text(l10n.meshcoreTracePathRunButton));
    await tester.pump();

    expect(find.text(l10n.meshcoreTracePathFailed), findsOneWidget);
    expect(find.text(l10n.commonRetry), findsOneWidget);
    await tester.tap(find.text(l10n.commonBack));
    await tester.pump();
    expect(find.text(l10n.meshcoreTracePathPickContact), findsOneWidget);
    expect(find.text('TerryDev2'), findsOneWidget);
  });

  testWidgets('each contact row is its own accessible button', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap());
    await tester.pump();

    expect(find.bySemanticsLabel(RegExp(r'^TerryDev2')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Coburg Hill')), findsOneWidget);
    semantics.dispose();
  });

  group('build a route', () {
    testWidgets('repeaters are added by name and traced there and back', (
      tester,
    ) async {
      _tallScreen(tester);
      final session = _TraceSession();
      await tester.pumpWidget(_wrap(session: session));
      await tester.pump();
      final l = _l10n(tester);

      await _tap(tester, find.text(l.meshcoreTraceModeCustom));
      expect(find.text(l.meshcoreTraceRouteEmpty), findsOneWidget);
      // Chat contacts cannot carry a trace, so only repeaters are offered.
      expect(find.text('TerryDev2'), findsNothing);
      expect(_primary(tester).enabled, isFalse);

      await _tap(tester, find.text('Coburg Hill'));
      await _tap(tester, find.text('Bendigo Relay').last);

      final you = l.meshcoreTraceRouteYou;
      expect(
        find.text(
          [
            you,
            'Coburg Hill',
            'Bendigo Relay',
            'Coburg Hill',
            you,
          ].join(_arrow),
        ),
        findsOneWidget,
      );
      expect(find.text(l.meshcoreTraceRouteCapacity(2, 16)), findsOneWidget);
      expect(_primary(tester).enabled, isTrue);

      await _tap(tester, find.text(l.meshcoreTracePathRunButton));
      expect(session.paths.single, [0x30, 0x40, 0x30]);
      expect(session.flags.single, 0);
      expect(find.text(l.meshcoreTraceRouteResultHeadline), findsOneWidget);
      // Hops are named, not shown as bare hashes.
      expect(find.text('Coburg Hill'), findsNWidgets(2));
      expect(find.text('Bendigo Relay'), findsOneWidget);

      // Returning the same way already measures both directions, so the
      // result offers no reversed run.
      expect(find.text(l.meshcoreTraceRouteTraceReversed), findsNothing);

      await _tap(tester, find.text(l.meshcoreTraceRouteEdit));
      expect(
        find.text(
          [
            you,
            'Coburg Hill',
            'Bendigo Relay',
            'Coburg Hill',
            you,
          ].join(_arrow),
        ),
        findsOneWidget,
      );
    });

    testWidgets('one way, reversed and trimmed', (tester) async {
      _tallScreen(tester);
      final session = _TraceSession();
      await tester.pumpWidget(_wrap(session: session));
      await tester.pump();
      final l = _l10n(tester);

      await _tap(tester, find.text(l.meshcoreTraceModeCustom));
      await _tap(tester, find.text('Coburg Hill'));
      await _tap(tester, find.text('Bendigo Relay').last);
      // The row's title toggles it, not only the switch.
      await _tap(tester, find.text(l.meshcoreTraceRouteReturnTitle));
      expect(find.text(l.meshcoreTraceRouteReturnOff), findsOneWidget);

      await _tap(tester, find.byTooltip(l.meshcoreTraceRouteReverse));
      final you = l.meshcoreTraceRouteYou;
      expect(
        find.text([you, 'Bendigo Relay', 'Coburg Hill', you].join(_arrow)),
        findsOneWidget,
      );

      await _tap(tester, find.text(l.meshcoreTracePathRunButton));
      expect(session.paths.single, [0x40, 0x30]);

      // One way, the other order is a different test.
      await _tap(tester, find.text(l.meshcoreTraceRouteTraceReversed));
      expect(session.paths.last, [0x30, 0x40]);

      await _tap(tester, find.text(l.meshcoreTraceRouteEdit));
      await _tap(tester, find.byTooltip(l.meshcoreTraceRouteRemoveHop).first);
      expect(
        find.text([you, 'Bendigo Relay', you].join(_arrow)),
        findsOneWidget,
      );
      await _tap(tester, find.byTooltip(l.meshcoreTraceRouteClear));
      expect(find.text(l.meshcoreTraceRouteEmpty), findsOneWidget);
    });

    testWidgets('an unknown repeater is added by key prefix', (tester) async {
      _tallScreen(tester);
      final session = _TraceSession();
      await tester.pumpWidget(_wrap(session: session));
      await tester.pump();
      final l = _l10n(tester);

      await _tap(tester, find.text(l.meshcoreTraceModeCustom));
      await tester.enterText(find.byType(TextField), 'ee');
      await tester.pump();
      // Searching shows only the matches, so they stay above the keyboard.
      expect(find.text(l.meshcoreTraceRouteReturnTitle), findsNothing);
      await _tap(tester, find.text(l.meshcoreTraceRouteAddPrefix('EE')));
      expect(find.text(l.meshcoreTraceRouteUnknownHop), findsOneWidget);
      expect(find.text(l.meshcoreTraceRouteReturnTitle), findsOneWidget);
      expect(_primary(tester).enabled, isTrue);

      // A one-byte prefix cannot fill a two-byte hop hash.
      await _tap(tester, find.text(l.meshcoreTraceRouteHashBytes(2)));
      expect(find.text(l.meshcoreTraceRouteHopTooShort(2)), findsOneWidget);
      expect(_primary(tester).enabled, isFalse);

      await _tap(tester, find.text(l.meshcoreTraceRouteHashBytes(1)));
      await _tap(tester, find.text(l.meshcoreTracePathRunButton));
      expect(session.paths.single, [0xEE]);
    });

    testWidgets('wider hashes take more of the key and set path_sz', (
      tester,
    ) async {
      _tallScreen(tester);
      final session = _TraceSession();
      await tester.pumpWidget(_wrap(session: session));
      await tester.pump();
      final l = _l10n(tester);

      await _tap(tester, find.text(l.meshcoreTraceModeCustom));
      await _tap(tester, find.text(l.meshcoreTraceRouteHashBytes(2)));
      await _tap(tester, find.text('Coburg Hill'));
      await _tap(tester, find.text(l.meshcoreTracePathRunButton));
      expect(session.paths.single, [0x30, 0x31]);
      expect(session.flags.single, 1);
    });
  });

  testWidgets('opening from a contact preselects it', (tester) async {
    _tallScreen(tester);
    final contact = _contact('Coburg Hill', 0x30, MeshCoreAdvType.repeater);
    await tester.pumpWidget(_wrap(initialContact: contact));
    await tester.pump();

    expect(_primary(tester).enabled, isTrue);
  });
}
