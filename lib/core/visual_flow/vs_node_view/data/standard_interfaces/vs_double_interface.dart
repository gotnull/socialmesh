// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Vendored from vs_node_view v2.1.1 — BSD-3-Clause
// Import paths rewritten for SocialMesh vendoring.

import 'package:flutter/material.dart';

import 'vs_num_interface.dart';
import '../vs_interface.dart';

const Color _interfaceColor = Colors.red;

class VSDoubleInputData extends VSInputData {
  /// Basic double input interface.
  VSDoubleInputData({
    required super.type,
    super.title,
    super.toolTip,
    super.initialConnection,
    super.interfaceIconBuilder,
  });

  @override
  List<Type> get acceptedTypes => [VSDoubleOutputData, VSNumOutputData];

  @override
  Color get interfaceColor => _interfaceColor;
}

class VSDoubleOutputData extends VSOutputData<double> {
  /// Basic double output interface.
  VSDoubleOutputData({
    required super.type,
    super.title,
    super.toolTip,
    super.outputFunction,
    super.interfaceIconBuilder,
  });

  @override
  Color get interfaceColor => _interfaceColor;
}
