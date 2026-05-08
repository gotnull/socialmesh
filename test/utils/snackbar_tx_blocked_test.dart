// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/utils/snackbar.dart';

void main() {
  group('maybeShowTxBlockedSnackBar', () {
    testWidgets('returns true and shows the friendly snackbar for the '
        'protocol-not-ready StateError', (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (ctx) {
              capturedContext = ctx;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );

      final result = maybeShowTxBlockedSnackBar(
        capturedContext,
        StateError(
          'Cannot sendMessage: protocol not ready '
          '(readiness=OperationalReadiness.handshakePhase2)',
        ),
      );

      expect(result, isTrue);
      await tester.pump();
      expect(
        find.text('Still configuring SocialMesh. Try again in a moment.'),
        findsOneWidget,
      );
    });

    testWidgets('returns false and shows nothing for unrelated errors', (
      tester,
    ) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (ctx) {
              capturedContext = ctx;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );

      // Unrelated StateError (not the readiness gate's wording).
      final result1 = maybeShowTxBlockedSnackBar(
        capturedContext,
        StateError('Cannot send message: not connected to device'),
      );
      // Different exception type entirely.
      final result2 = maybeShowTxBlockedSnackBar(
        capturedContext,
        Exception('boom'),
      );

      expect(result1, isFalse);
      expect(result2, isFalse);
      await tester.pump();
      expect(
        find.text('Still configuring SocialMesh. Try again in a moment.'),
        findsNothing,
      );
    });
  });
}
