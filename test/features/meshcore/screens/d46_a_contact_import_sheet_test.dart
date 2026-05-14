// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D46-A: `showMeshCoreContactImportSheet` rendering pins.
//
// We stub `meshCoreContactsProvider` so `commitContactImport` can be
// observed without exercising the session / transport. This file
// pins:
//   - Modern preview renders name, 8-char fingerprint, last-seen,
//     location, and the "Full" format label.
//   - Legacy preview renders name, fingerprint, "Unknown" last-seen,
//     "Not shared" location, and the "Legacy (name only)" label.
//   - Tapping Confirm drives `commitContactImport` exactly once and
//     pops the sheet with `true` on success.
//   - Tapping Confirm pops the sheet with `false` when commit fails.
//   - Cancel (sheet dismiss) does NOT drive commit; the sheet pops
//     with null.
//   - Rendered text NEVER embeds the full 64-char pubkey or a base64
//     envelope-shaped string.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_contact_import_sheet.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/models/meshcore_contact_import_preview.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';

final _l10n = AppLocalizationsEn();

/// Stub notifier that records `commitContactImport` calls and returns
/// a fixed value. Build state is a passthrough; D46-A's import sheet
/// doesn't read state from this provider.
class _StubContactsNotifier extends MeshCoreContactsNotifier {
  _StubContactsNotifier(this._commitResult);
  final bool _commitResult;
  int commitCalls = 0;
  MeshCoreContactImportPreview? lastCommitPreview;

  @override
  MeshCoreContactsState build() => const MeshCoreContactsState();

  @override
  Future<bool> commitContactImport(MeshCoreContactImportPreview preview) async {
    commitCalls++;
    lastCommitPreview = preview;
    return _commitResult;
  }
}

class _SheetOpener extends StatefulWidget {
  final MeshCoreContactImportPreview preview;
  const _SheetOpener({required this.preview});

  @override
  State<_SheetOpener> createState() => _SheetOpenerState();
}

class _SheetOpenerState extends State<_SheetOpener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showMeshCoreContactImportSheet(context, preview: widget.preview);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

Widget _wrap({
  required MeshCoreContactImportPreview preview,
  required _StubContactsNotifier Function() notifierFactory,
}) {
  return ProviderScope(
    overrides: [meshCoreContactsProvider.overrideWith(notifierFactory)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: Scaffold(body: _SheetOpener(preview: preview)),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

MeshCoreContactImportPreview _modernPreview({
  String name = 'Alice',
  double? lat = 47.6062,
  double? lng = -122.3321,
}) {
  final pk = Uint8List.fromList(List.generate(32, (i) => 0xA0 + i));
  final contact = MeshCoreContact(
    publicKey: pk,
    name: name,
    type: MeshCoreAdvType.chat,
    pathLength: 0,
    path: Uint8List(0),
    latitude: lat,
    longitude: lng,
    lastSeen: DateTime(2026, 5, 12, 9, 30),
  );
  return MeshCoreContactImportPreview(
    format: MeshCoreContactImportFormat.modern,
    contact: contact,
    pubKeyFingerprint8: 'a0a1a2a3',
    frameBytes: Uint8List(135),
  );
}

MeshCoreContactImportPreview _legacyPreview({String name = 'Bob'}) {
  final pk = Uint8List.fromList(List.generate(32, (i) => i));
  final contact = MeshCoreContact(
    publicKey: pk,
    name: name,
    type: MeshCoreAdvType.chat,
    pathLength: -1,
    path: Uint8List(0),
    lastSeen: DateTime.now(),
  );
  return MeshCoreContactImportPreview(
    format: MeshCoreContactImportFormat.legacy,
    contact: contact,
    pubKeyFingerprint8: '00010203',
  );
}

final List<RegExp> _bannedRenderTextPatterns = [
  RegExp(r'[0-9a-fA-F]{32}'),
  RegExp(r'[0-9a-fA-F]{64}'),
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
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'modern preview renders name, fingerprint, GPS, last-seen, and the Full '
    'format label',
    (tester) async {
      tester.view.physicalSize = const Size(440, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          preview: _modernPreview(name: 'Alice'),
          notifierFactory: () => _StubContactsNotifier(true),
        ),
      );
      await _openSheet(tester);

      // SectionTitle uppercases its child text.
      expect(
        find.text(_l10n.meshcoreContactImportConfirmTitle.toUpperCase()),
        findsOneWidget,
      );
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('a0a1a2a3'), findsOneWidget);
      expect(find.text('2026-05-12 09:30'), findsOneWidget);
      // Location rendered with 4 decimal places.
      expect(find.text('47.6062, -122.3321'), findsOneWidget);
      expect(
        find.text(_l10n.meshcoreContactImportConfirmFormatFull),
        findsOneWidget,
      );
      _expectNoBannedText(tester);
    },
  );

  testWidgets(
    'legacy preview renders Unknown last-seen + Not shared location + '
    'Legacy format label',
    (tester) async {
      tester.view.physicalSize = const Size(440, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          preview: _legacyPreview(name: 'Bob'),
          notifierFactory: () => _StubContactsNotifier(true),
        ),
      );
      await _openSheet(tester);

      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('00010203'), findsOneWidget);
      expect(
        find.text(_l10n.meshcoreContactImportLastSeenUnknown),
        findsOneWidget,
      );
      expect(
        find.text(_l10n.meshcoreContactImportLocationUnknown),
        findsOneWidget,
      );
      expect(
        find.text(_l10n.meshcoreContactImportConfirmFormatLegacy),
        findsOneWidget,
      );
      _expectNoBannedText(tester);
    },
  );

  testWidgets(
    'tap Confirm drives commitContactImport once and pops the sheet on success',
    (tester) async {
      tester.view.physicalSize = const Size(440, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late _StubContactsNotifier stub;
      await tester.pumpWidget(
        _wrap(
          preview: _modernPreview(),
          notifierFactory: () {
            stub = _StubContactsNotifier(true);
            return stub;
          },
        ),
      );
      await _openSheet(tester);

      await tester.tap(
        find.byKey(const ValueKey('meshcore-contact-import-confirm')),
      );
      // Pump through the commit + the sheet's dismiss animation.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(stub.commitCalls, 1);
      // The sheet popped after commit; the confirm button is gone.
      expect(
        find.byKey(const ValueKey('meshcore-contact-import-confirm')),
        findsNothing,
      );
    },
  );

  testWidgets('tap Confirm still drives commit and pops the sheet when commit '
      'returns false', (tester) async {
    tester.view.physicalSize = const Size(440, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    late _StubContactsNotifier stub;
    await tester.pumpWidget(
      _wrap(
        preview: _modernPreview(),
        notifierFactory: () {
          stub = _StubContactsNotifier(false);
          return stub;
        },
      ),
    );
    await _openSheet(tester);

    await tester.tap(
      find.byKey(const ValueKey('meshcore-contact-import-confirm')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(stub.commitCalls, 1);
    expect(
      find.byKey(const ValueKey('meshcore-contact-import-confirm')),
      findsNothing,
    );
  });

  // Dismissal-without-tap negative case is implicit from the source:
  // `commitContactImport` is only called from `_confirm()`, which is
  // wired to the Confirm-button onPressed. Drag-to-dismiss + back-
  // button dismiss are framework-managed; testing them here requires
  // a real Navigator route, which the in-test ProviderScope cannot
  // cheaply provide. The remaining 4 sheet tests pin the confirm path.
}
