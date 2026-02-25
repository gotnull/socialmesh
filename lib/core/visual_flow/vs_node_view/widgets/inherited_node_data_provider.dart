// SPDX-License-Identifier: GPL-3.0-or-later

// Vendored from vs_node_view v2.1.1 — BSD-3-Clause
// Import paths rewritten for Socialmesh vendoring.

import 'package:flutter/material.dart';

import '../data/vs_node_data_provider.dart';

class InheritedNodeDataProvider extends InheritedWidget {
  const InheritedNodeDataProvider({
    super.key,
    required this.provider,
    required super.child,
  });

  final VSNodeDataProvider provider;

  @override
  bool updateShouldNotify(InheritedNodeDataProvider oldWidget) =>
      provider != oldWidget.provider;
}
