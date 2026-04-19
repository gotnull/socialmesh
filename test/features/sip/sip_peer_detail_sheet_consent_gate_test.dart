// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Consent-gate widget tests for SipPeerDetailSheet.
//
// Guards the invariant from docs/overlay/AGENT_GUIDE.md §2.1:
// pendingApproval is owned by the dedicated Incoming Requests tile
// above the peer list. The detail sheet MUST NOT offer any tappable
// action that stands in for Accept / Decline. Any regression that
// re-introduces a tappable CTA in pendingApproval is a consent-bypass.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/legal/age_group.dart';
import 'package:socialmesh/core/legal/age_safety_policy.dart';
import 'package:socialmesh/features/sip/sip_peer_detail_sheet.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/age_eligibility_provider.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/sip_providers.dart';
import 'package:socialmesh/services/protocol/sip/sip_discovery.dart';
import 'package:socialmesh/services/protocol/sip/sip_handshake.dart';

SipPeerCapability _peer({int nodeId = 0x1A2B, int features = 0x03}) {
  return SipPeerCapability(
    nodeId: nodeId,
    features: features,
    deviceClass: 1,
    maxProtoMinor: 0,
    mtuHint: 200,
    rxWindowS: 5,
    capsHash: 0,
    lastSeenMs: DateTime.now().millisecondsSinceEpoch,
  );
}

/// Minimal adult policy so the handshake button is not suppressed by the
/// minor contact restriction branch.
const _adultPolicy = AgeSafetyPolicy(
  ageGroup: AgeGroup.adult,
  source: AgeSource.selfAttestation,
);

Widget _harness({
  required SipPeerCapability peer,
  required SipHandshakeState hsState,
}) {
  return ProviderScope(
    overrides: [
      sipHandshakeStateProvider(peer.nodeId).overrideWith((_) => hsState),
      ageSafetyPolicyProvider.overrideWith((_) => _adultPolicy),
      meshPrivacyDmAvailableProvider.overrideWith(
        () => _MeshPrivacyDmAvailableStub(true),
      ),
      sipDmManagerProvider.overrideWith((_) => null),
      sipHandshakeProvider.overrideWith((_) => null),
      nodesProvider.overrideWith(() => _NodesStub()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SipPeerDetailSheet(peer: peer),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('SipPeerDetailSheet consent gate', () {
    testWidgets('pendingApproval hides the handshake button entirely '
        '(no tile-tap accept shortcut)', (tester) async {
      await tester.pumpWidget(
        _harness(peer: _peer(), hsState: SipHandshakeState.pendingApproval),
      );
      await tester.pump();

      // No button whatsoever — neither Start handshake nor Open chat
      // nor Handshake complete. Consent gate is mandatory.
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('idle state renders Start handshake CTA (enabled)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(peer: _peer(), hsState: SipHandshakeState.idle),
      );
      await tester.pump();

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byIcon(Icons.handshake_outlined), findsOneWidget);
    });

    testWidgets('accepted state shows complete CTA (disabled) when no DM', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(peer: _peer(), hsState: SipHandshakeState.accepted),
      );
      await tester.pump();

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('helloSent (in-progress) shows disabled in-progress CTA', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(peer: _peer(), hsState: SipHandshakeState.helloSent),
      );
      await tester.pump();

      expect(find.byIcon(Icons.hourglass_top), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('overlay capability chips render based on features bitmap', (
      tester,
    ) async {
      // features covering sip1, overlay link+resource+secure.
      await tester.pumpWidget(
        _harness(peer: _peer(features: 0xFF), hsState: SipHandshakeState.idle),
      );
      await tester.pump();

      expect(find.textContaining('Overlay link'), findsOneWidget);
      expect(find.textContaining('Overlay resource'), findsOneWidget);
      expect(find.textContaining('Overlay secure'), findsOneWidget);
    });
  });
}

/// Minimal Notifier stub for a boolean privacy flag.
class _MeshPrivacyDmAvailableStub extends MeshPrivacyDmAvailableNotifier {
  _MeshPrivacyDmAvailableStub(this._initial);
  final bool _initial;

  @override
  bool build() => _initial;
}

/// Empty-map nodes notifier to satisfy the sheet's nodesProvider watch
/// without pulling in the full NodesNotifier pipeline.
class _NodesStub extends NodesNotifier {
  @override
  Map<int, MeshNode> build() => const {};
}
