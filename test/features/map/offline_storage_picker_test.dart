// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/core/widgets/chip_selector.dart';
import 'package:socialmesh/core/widgets/status_banner.dart';
import 'package:socialmesh/features/map/offline_tiles/offline_storage_location_notifier.dart';
import 'package:socialmesh/features/map/offline_tiles/offline_storage_picker.dart';
import 'package:socialmesh/features/map/offline_tiles/offline_tile_storage.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

// OfflineStorageSection is the shared storage-location picker embedded
// in the region download sheet and the Settings sheet. Its visibility
// contract: chip picker only when a removable SD card is available,
// fallback warning only when boot fell back to internal, nothing at all
// otherwise (iOS / card-less devices).

class _FixedStorageNotifier extends OfflineStorageLocationNotifier {
  final OfflineStorageState fixed;
  _FixedStorageNotifier(this.fixed);

  @override
  Future<OfflineStorageState> build() async => fixed;
}

Widget _wrap(OfflineStorageState state) {
  return ProviderScope(
    overrides: [
      offlineStorageLocationProvider.overrideWith(
        () => _FixedStorageNotifier(state),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: OfflineStorageSection()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders both location chips when an SD card is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const OfflineStorageState(
          sdAvailable: true,
          location: OfflineTileStorageLocation.internal,
          fellBack: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byType(ChipSelector<OfflineTileStorageLocation>),
      findsOneWidget,
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(OfflineStorageSection)),
    );
    expect(find.text(l10n.offlineStorageInternal), findsOneWidget);
    expect(find.text(l10n.offlineStorageSdCard), findsOneWidget);
    expect(find.byType(StatusBanner), findsNothing);
  });

  testWidgets('renders the fallback warning when boot fell back', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const OfflineStorageState(
          sdAvailable: false,
          location: OfflineTileStorageLocation.internal,
          fellBack: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byType(StatusBanner),
      findsOneWidget,
      reason:
          'The user chose SD storage and must see why tiles are landing '
          'on internal memory instead.',
    );
    expect(
      find.byType(ChipSelector<OfflineTileStorageLocation>),
      findsNothing,
      reason: 'no card mounted - nothing to pick',
    );
  });

  testWidgets('renders nothing when no SD card and no fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const OfflineStorageState(
          sdAvailable: false,
          location: OfflineTileStorageLocation.internal,
          fellBack: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ChipSelector<OfflineTileStorageLocation>), findsNothing);
    expect(find.byType(StatusBanner), findsNothing);
    expect(find.byType(Text), findsNothing);
  });
}
