// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// The MeshCore QR scanner can decode a contact or channel QR from an image
// in the photo library. The image picker and the barcode analyser are
// driven through their platform channels, so these tests cover the screen's
// handling of each outcome: cancel, no code, an unrecognised code, a picker
// failure.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_qr_scanner_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';

final _l10n = AppLocalizationsEn();

const _pickerChannel = MethodChannel('plugins.flutter.io/image_picker');
const _scannerChannel = MethodChannel(
  'dev.steenbakker.mobile_scanner/scanner/method',
);
const _scannerEvents = EventChannel(
  'dev.steenbakker.mobile_scanner/scanner/event',
);
const _orientationEvents = EventChannel(
  'dev.steenbakker.mobile_scanner/scanner/deviceOrientation',
);

class _StubContactsNotifier extends MeshCoreContactsNotifier {
  @override
  MeshCoreContactsState build() => const MeshCoreContactsState.initial();
}

// Each test sets what the picker returns (or throws) and what the analyser
// decodes; null means cancelled or no code respectively.
Object? _pickerResult;
Map<Object?, Object?>? _analyseResult;
final List<String> _analysedPaths = [];

void _installChannelMocks() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_pickerChannel, (call) async {
    if (call.method != 'pickImage') return null;
    final result = _pickerResult;
    if (result is PlatformException) throw result;
    return result;
  });
  messenger.setMockMethodCallHandler(_scannerChannel, (call) async {
    if (call.method == 'analyzeImage') {
      final args = call.arguments as Map<Object?, Object?>;
      _analysedPaths.add(args['filePath']! as String);
      return _analyseResult;
    }
    return null;
  });
  for (final channel in [_scannerEvents, _orientationEvents]) {
    messenger.setMockStreamHandler(
      channel,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  }
}

void _removeChannelMocks() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_pickerChannel, null);
  messenger.setMockMethodCallHandler(_scannerChannel, null);
  messenger.setMockStreamHandler(_scannerEvents, null);
  messenger.setMockStreamHandler(_orientationEvents, null);
}

Future<void> _pumpScanner(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        meshCoreContactsProvider.overrideWith(_StubContactsNotifier.new),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MeshCoreQrScannerScreen(mode: MeshCoreScanMode.contact),
      ),
    ),
  );
  await tester.pump();
}

Finder get _photosButton => find.byTooltip(_l10n.meshcoreQrPickFromPhotos);

// Lets snackbar and scanner-reset timers run out before teardown.
Future<void> _drainTimers(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  setUp(() {
    _pickerResult = null;
    _analyseResult = null;
    _analysedPaths.clear();
    _installChannelMocks();
  });

  tearDown(_removeChannelMocks);

  testWidgets('app bar offers the photo library', (tester) async {
    await _pumpScanner(tester);

    expect(_photosButton, findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
  });

  testWidgets('cancelling the picker shows nothing and re-enables the button', (
    tester,
  ) async {
    await _pumpScanner(tester);

    await tester.tap(_photosButton);
    await tester.pump();
    await tester.pump();

    expect(_analysedPaths, isEmpty);
    expect(find.text(_l10n.meshcoreQrPhotoNoCodeFound), findsNothing);
    final button = tester.widget<IconButton>(
      find.ancestor(of: _photosButton, matching: find.byType(IconButton)),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('an image without a QR code reports that no code was found', (
    tester,
  ) async {
    _pickerResult = '/photos/screenshot.png';
    await _pumpScanner(tester);

    await tester.tap(_photosButton);
    await tester.pump();
    await tester.pump();

    expect(_analysedPaths, ['/photos/screenshot.png']);
    expect(find.text(_l10n.meshcoreQrPhotoNoCodeFound), findsOneWidget);
    await _drainTimers(tester);
  });

  testWidgets('a decoded code goes through the contact import parser', (
    tester,
  ) async {
    _pickerResult = '/photos/other.png';
    _analyseResult = {
      'data': [
        {'rawValue': 'https://example.com/not-a-contact', 'format': 256},
      ],
    };
    await _pumpScanner(tester);

    await tester.tap(_photosButton);
    await tester.pump();
    await tester.pump();

    expect(find.text(_l10n.meshcoreNotValidContactQr), findsOneWidget);
    expect(find.text(_l10n.meshcoreQrPhotoNoCodeFound), findsNothing);
    await _drainTimers(tester);
  });

  testWidgets('a picker failure says the photos could not be opened', (
    tester,
  ) async {
    _pickerResult = PlatformException(code: 'photo_access_denied');
    await _pumpScanner(tester);

    await tester.tap(_photosButton);
    await tester.pump();
    await tester.pump();

    expect(_analysedPaths, isEmpty);
    expect(find.text(_l10n.meshcoreQrPhotoOpenFailed), findsOneWidget);
    await _drainTimers(tester);
  });
}
