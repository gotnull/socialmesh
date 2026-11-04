// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/remote_admin_target_banner.dart';
import 'package:socialmesh/core/widgets/status_banner.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/app_providers.dart';

class _Remote extends RemoteAdminNotifier {
  _Remote(this.initial);
  final RemoteAdminState initial;

  @override
  RemoteAdminState build() => initial;
}

Future<void> _pump(WidgetTester tester, RemoteAdminState state) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [remoteAdminProvider.overrideWith(() => _Remote(state))],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.dark(),
        home: const Scaffold(body: RemoteAdminTargetBanner()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders nothing while the connected radio is the target', (
    tester,
  ) async {
    await _pump(tester, const RemoteAdminState());

    expect(find.byType(StatusBanner), findsNothing);
  });

  testWidgets('names the remote node the screen is changing', (tester) async {
    await _pump(
      tester,
      const RemoteAdminState(targetNodeNum: 0x2002, targetNodeName: 'Hilltop'),
    );

    expect(find.text('Configuring Remote Node'), findsOneWidget);
    expect(
      find.text(
        'Commands on this screen go to Hilltop, not the radio you are '
        'connected to.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('falls back to the node id when the name is unknown', (
    tester,
  ) async {
    await _pump(tester, const RemoteAdminState(targetNodeNum: 0x2002));

    expect(find.textContaining('!00002002'), findsOneWidget);
  });
}
