// Vendored from vs_node_view v2.1.1 — BSD-3-Clause
// Import paths rewritten for Socialmesh vendoring.

import 'package:flutter/material.dart';

import '../vs_interface.dart';

const Color _interfaceColor = Colors.grey;

class VSDynamicInputData extends VSInputData {
  /// Basic dynamic input interface.
  VSDynamicInputData({
    required super.type,
    super.title,
    super.toolTip,
    super.initialConnection,
    super.interfaceIconBuilder,
  });

  @override
  List<Type> get acceptedTypes => [];

  @override
  bool acceptInput(VSOutputData data) {
    return true;
  }

  @override
  Color get interfaceColor => _interfaceColor;
}

class VSDynamicOutputData extends VSOutputData<dynamic> {
  /// Basic dynamic output interface.
  VSDynamicOutputData({
    required super.type,
    super.title,
    super.toolTip,
    super.outputFunction,
    super.interfaceIconBuilder,
  });

  @override
  Color get interfaceColor => _interfaceColor;
}
