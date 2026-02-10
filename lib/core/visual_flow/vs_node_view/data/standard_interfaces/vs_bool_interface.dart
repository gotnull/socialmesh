// Vendored from vs_node_view v2.1.1 — BSD-3-Clause
// Import paths rewritten for Socialmesh vendoring.

import 'package:flutter/material.dart';

import '../vs_interface.dart';

const Color _interfaceColor = Colors.orange;

class VSBoolInputData extends VSInputData {
  /// Basic boolean input interface.
  VSBoolInputData({
    required super.type,
    super.title,
    super.toolTip,
    super.initialConnection,
    super.interfaceIconBuilder,
  });

  @override
  List<Type> get acceptedTypes => [VSBoolOutputData];

  @override
  Color get interfaceColor => _interfaceColor;
}

class VSBoolOutputData extends VSOutputData<bool> {
  /// Basic boolean output interface.
  VSBoolOutputData({
    required super.type,
    super.title,
    super.toolTip,
    super.outputFunction,
    super.interfaceIconBuilder,
  });

  @override
  Color get interfaceColor => _interfaceColor;
}
