// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:socialmesh/features/widget_builder/storage/widget_storage_service.dart';

void main() async {
  final outputDir = Directory('assets/widget_templates');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  final encoder = JsonEncoder.withIndent('  ');

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
    final json = encoder.convert(widget.toJson());
    final file = File('${outputDir.path}/$filename');
    await file.writeAsString(json);
    print('Exported: $filename');
  }

  print('\nAll widget templates exported to assets/widget_templates/');
}
