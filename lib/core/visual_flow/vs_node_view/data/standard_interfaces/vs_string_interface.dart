// Vendored from vs_node_view v2.1.1 — BSD-3-Clause
// Import paths rewritten for Socialmesh vendoring.

import 'package:flutter/material.dart';

import '../vs_interface.dart';

const Color _interfaceColor = Colors.green;

class VSStringInputData extends VSInputData {
  /// Basic String input interface.
  VSStringInputData({
    required super.type,
    super.title,
    super.toolTip,
    super.initialConnection,
    super.interfaceIconBuilder,
  });

  @override
  List<Type> get acceptedTypes => [VSStringOutputData];

  @override
  Color get interfaceColor => _interfaceColor;
}

class VSStringOutputData extends VSOutputData<String> {
  /// Basic String output interface.
  VSStringOutputData({
    required super.type,
    super.title,
    super.toolTip,
    super.outputFunction,
    super.interfaceIconBuilder,
  });

  @override
  Color get interfaceColor => _interfaceColor;
}
