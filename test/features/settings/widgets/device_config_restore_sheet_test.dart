// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/settings/widgets/device_config_restore_sheet.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/backup/device_config_backup_service.dart';
import 'package:socialmesh/services/backup/device_config_bundle.dart';

final _l10n = AppLocalizationsEn();

void main() {
  testWidgets('shows the title once and one toggle row per section', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.dark(),
        home: Material(
          child: DeviceConfigRestoreSheet(
            bundle: DeviceConfigBundle(
              createdAt: DateTime(2026, 10, 17, 20, 48),
              channels: [
                ChannelConfig(index: 0, name: 'LongFast', psk: [1]),
              ],
            ),
            scrollController: controller,
            onRestore: (_) async => RestoreReport(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text(_l10n.dataExportDeviceConfigRestoreSheetTitle),
      findsOneWidget,
    );
    expect(
      find.text(_l10n.dataExportDeviceConfigRestoreSheetTitle.toUpperCase()),
      findsNothing,
    );
    expect(
      find.text(_l10n.dataExportDeviceConfigRestoreToggleChannels),
      findsOneWidget,
    );
  });
}
