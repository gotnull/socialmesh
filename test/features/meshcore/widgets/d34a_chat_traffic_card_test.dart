// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D34a — `MeshCoreChatTrafficCard` widget regression pins.
//
// Pins:
//   - Card renders the canonical title + progress bar + InfoTable
//     when a session is live.
//   - Card renders the placeholder when no session is connected.
//   - Per-kind rows (Text / Replies / Reactions / Rejected) appear
//     with byte+count formatting.
//   - Peak / Last rejection / Remaining rows render.
//   - No raw payload, pubkey, channel name, MMF, or envelope hex
//     appears in the rendered text tree.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/meshcore/widgets/meshcore_chat_traffic_card.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/meshcore_send_rate_limiter.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';

class _FakeTransport implements MeshCoreTransport {
  final _rx = StreamController<Uint8List>.broadcast();
  bool _connected = true;

  @override
  Stream<Uint8List> get rawRxStream => _rx.stream;

  @override
  Future<void> sendRaw(Uint8List data) async {}

  @override
  bool get isConnected => _connected;

  Future<void> dispose() async {
    _connected = false;
    await _rx.close();
  }
}

Widget _wrap({MeshCoreSession? session}) {
  return ProviderScope(
    overrides: [meshCoreSessionProvider.overrideWithValue(session)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: MeshCoreChatTrafficCard()),
    ),
  );
}

/// Strings that MUST NEVER appear in the card's rendered text tree
/// regardless of input. These regexes guard against accidental
/// payload, envelope, MMF, or pubkey leakage if a future refactor
/// inlines content into the row values.
final List<RegExp> _bannedRenderTextPatterns = [
  RegExp(r'\[mrrp\]'),
  RegExp(r'\[/mrrp\]'),
  RegExp(r'02:[0-9a-f]{12}:'),
  RegExp(r'01:[0-9a-f]{2}:'),
  // 32-byte hex pubkey (any case).
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
  testWidgets('renders title + placeholder when no session is connected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(session: null));
    await tester.pump();

    // SectionTitle uppercases the title; the ARB value is mixed case.
    expect(find.text('CHAT TRAFFIC (60 S)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('meshcore-chat-traffic-no-session')),
      findsOneWidget,
    );
    expect(find.text('No active MeshCore session'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('meshcore-chat-traffic-progress')),
      findsNothing,
    );
    _expectNoBannedText(tester);
  });

  testWidgets('renders progress bar + InfoTable rows when session is live', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final tx = _FakeTransport();
    addTearDown(tx.dispose);
    final lim = MeshCoreSendRateLimiter();
    final session = MeshCoreSession(tx, sendRateLimiter: lim);
    addTearDown(session.dispose);

    // Pre-populate counters so rows render with non-zero values.
    lim.recordSend(
      kind: MeshCoreSendKind.plainContact,
      bytes: 100,
      allowed: true,
    );
    lim.recordSend(
      kind: MeshCoreSendKind.replyContact,
      bytes: 200,
      allowed: true,
    );

    await tester.pumpWidget(_wrap(session: session));
    await tester.pump();

    // SectionTitle uppercases the title; the ARB value is mixed case.
    expect(find.text('CHAT TRAFFIC (60 S)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('meshcore-chat-traffic-progress')),
      findsOneWidget,
    );

    // Row labels.
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Replies'), findsOneWidget);
    expect(find.text('Reactions'), findsOneWidget);
    expect(find.text('Rejected'), findsOneWidget);
    expect(find.text('Peak this session'), findsOneWidget);
    expect(find.text('Last rejection'), findsOneWidget);
    expect(find.text('Remaining budget'), findsOneWidget);

    // Reactions row stays at "0 B (0)".
    expect(find.text('0 B (0)'), findsWidgets);

    // Last rejection placeholder when no rejection has happened.
    expect(find.text('-'), findsOneWidget);

    _expectNoBannedText(tester);
  });

  testWidgets('Last rejection row shows a HH:MM:SS timestamp when a '
      'rejection has been recorded', (tester) async {
    tester.view.physicalSize = const Size(440, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final tx = _FakeTransport();
    addTearDown(tx.dispose);
    final lim = MeshCoreSendRateLimiter();
    final session = MeshCoreSession(tx, sendRateLimiter: lim);
    addTearDown(session.dispose);

    lim.recordSend(
      kind: MeshCoreSendKind.plainChannel,
      bytes: 300,
      allowed: false,
    );

    await tester.pumpWidget(_wrap(session: session));
    await tester.pump();

    // Look for any HH:MM:SS string. Don't pin the exact value to
    // avoid flakiness on slow runs.
    final hms = RegExp(r'^\d{2}:\d{2}:\d{2}$');
    final allTexts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .toList();
    expect(
      allTexts.any(hms.hasMatch),
      isTrue,
      reason:
          'expected at least one HH:MM:SS timestamp in the rendered '
          'tree (Last rejection row), got: $allTexts',
    );
    _expectNoBannedText(tester);
  });
}
