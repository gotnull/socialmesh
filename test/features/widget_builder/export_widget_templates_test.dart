import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/widget_builder/storage/widget_storage_service.dart';

/// Run this test to export all widget templates as JSON files
/// to assets/widget_templates/ for learning and reference.
///
/// Command: flutter test test/features/widget_builder/export_widget_templates_test.dart
void main() {
  test('Export widget templates to JSON files', () async {
    final outputDir = Directory('assets/widget_templates');
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final templates = [
      ('battery_widget.json', WidgetTemplates.batteryWidget()),
      ('signal_widget.json', WidgetTemplates.signalWidget()),
      ('environment_widget.json', WidgetTemplates.environmentWidget()),
      ('node_info_widget.json', WidgetTemplates.nodeInfoWidget()),
      ('gps_widget.json', WidgetTemplates.gpsWidget()),
      ('network_overview_widget.json', WidgetTemplates.networkOverviewWidget()),
      ('quick_actions_widget.json', WidgetTemplates.quickActionsWidget()),
    ];

    for (final (filename, widget) in templates) {
      final file = File('${outputDir.path}/$filename');
      file.writeAsStringSync(widget.toJsonString());
      // ignore: avoid_print
      print('Exported: $filename');
    }

    // Verify files were created
    for (final (filename, _) in templates) {
      expect(File('${outputDir.path}/$filename').existsSync(), isTrue);
    }

    // ignore: avoid_print
    print('\n✅ All widget templates exported to assets/widget_templates/');
  });
}
