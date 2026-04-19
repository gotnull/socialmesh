// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_mail_launcher/open_mail_launcher.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/utils/email_launcher.dart';

class _FakeProbe implements EmailAppsProbe {
  _FakeProbe({this.apps = const [], this.throwOnGetApps = false});

  final List<MailApp> apps;
  final bool throwOnGetApps;
  bool openSpecificResult = true;
  bool launchMailtoResult = true;

  int getAppsCalls = 0;
  int openSpecificCalls = 0;
  int launchMailtoCalls = 0;
  MailApp? lastOpenedApp;
  EmailContent? lastOpenedContent;
  Uri? lastMailtoUri;

  @override
  Future<List<MailApp>> getMailApps() async {
    getAppsCalls++;
    if (throwOnGetApps) throw StateError('platform failure');
    return apps;
  }

  @override
  Future<bool> openSpecific(MailApp app, EmailContent content) async {
    openSpecificCalls++;
    lastOpenedApp = app;
    lastOpenedContent = content;
    return openSpecificResult;
  }

  @override
  Future<bool> launchMailto(Uri uri) async {
    launchMailtoCalls++;
    lastMailtoUri = uri;
    return launchMailtoResult;
  }
}

Widget _hostWidget({required void Function(BuildContext) onPressed}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => onPressed(context),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  tearDown(resetEmailAppsProbeForTest);

  testWidgets('launches mailto fallback when no apps are reported', (
    tester,
  ) async {
    final probe = _FakeProbe(apps: const []);
    setEmailAppsProbeForTest(probe);

    await tester.pumpWidget(
      _hostWidget(
        onPressed: (ctx) => launchEmailCompose(
          context: ctx,
          to: 'support@socialmesh.app',
          subject: 'hi',
          body: 'b',
        ),
      ),
    );
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(probe.launchMailtoCalls, 1);
    expect(probe.openSpecificCalls, 0);
    expect(probe.lastMailtoUri!.scheme, 'mailto');
    expect(probe.lastMailtoUri!.path, 'support@socialmesh.app');
    expect(probe.lastMailtoUri!.query, contains('subject=hi'));
  });

  testWidgets('launches the single app directly without showing a picker', (
    tester,
  ) async {
    final probe = _FakeProbe(
      apps: const [MailApp(name: 'Mail', id: 'mailto', isDefault: true)],
    );
    setEmailAppsProbeForTest(probe);

    await tester.pumpWidget(
      _hostWidget(
        onPressed: (ctx) =>
            launchEmailCompose(context: ctx, to: 'x@y.z', subject: 's'),
      ),
    );
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(probe.openSpecificCalls, 1);
    expect(probe.launchMailtoCalls, 0);
    expect(probe.lastOpenedApp!.id, 'mailto');
    expect(probe.lastOpenedContent!.to, ['x@y.z']);
    expect(probe.lastOpenedContent!.subject, 's');
    expect(find.text('Choose email app'), findsNothing);
  });

  testWidgets('shows picker when multiple apps are present', (tester) async {
    final probe = _FakeProbe(
      apps: const [
        MailApp(name: 'Gmail', id: 'googlegmail', isDefault: true),
        MailApp(name: 'Outlook', id: 'ms-outlook'),
      ],
    );
    setEmailAppsProbeForTest(probe);

    await tester.pumpWidget(
      _hostWidget(
        onPressed: (ctx) =>
            launchEmailCompose(context: ctx, to: 'x@y.z', subject: 's'),
      ),
    );
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('Choose email app'), findsOneWidget);
    expect(find.text('Gmail'), findsOneWidget);
    expect(find.text('Outlook'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);

    await tester.tap(find.text('Outlook'));
    await tester.pumpAndSettle();

    expect(probe.openSpecificCalls, 1);
    expect(probe.lastOpenedApp!.id, 'ms-outlook');
  });

  testWidgets('dedupes duplicate Mail entries (mailto + message scheme)', (
    tester,
  ) async {
    final probe = _FakeProbe(
      apps: const [
        MailApp(name: 'Mail', id: 'mailto:', isDefault: true),
        MailApp(name: 'Mail', id: 'message://'),
        MailApp(name: 'Gmail', id: 'googlegmail://'),
      ],
    );
    setEmailAppsProbeForTest(probe);

    await tester.pumpWidget(
      _hostWidget(
        onPressed: (ctx) => launchEmailCompose(context: ctx, to: 'x@y.z'),
      ),
    );
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('Mail'), findsOneWidget);
    expect(find.text('Gmail'), findsOneWidget);
  });

  testWidgets('falls back to mailto when getMailApps throws', (tester) async {
    final probe = _FakeProbe(throwOnGetApps: true);
    setEmailAppsProbeForTest(probe);

    await tester.pumpWidget(
      _hostWidget(
        onPressed: (ctx) => launchEmailCompose(context: ctx, to: 'a@b.c'),
      ),
    );
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(probe.launchMailtoCalls, 1);
    expect(probe.lastMailtoUri!.path, 'a@b.c');
  });
}
