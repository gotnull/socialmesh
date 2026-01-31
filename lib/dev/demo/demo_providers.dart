// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/mesh_models.dart';
import 'demo_config.dart';
import 'demo_data.dart';

/// Provider that supplies demo nodes when demo mode is enabled.
/// Returns empty map when demo mode is disabled.
final demoNodesProvider = Provider<Map<int, MeshNode>>((ref) {
  if (!DemoConfig.isEnabled) return {};
  return {for (final node in DemoData.sampleNodes) node.nodeNum: node};
});

/// Provider that supplies demo messages when demo mode is enabled.
/// Returns empty list when demo mode is disabled.
final demoMessagesProvider = Provider<List<Message>>((ref) {
  if (!DemoConfig.isEnabled) return [];
  return DemoData.sampleMessages;
});

/// Provider that returns the demo user's node number.
/// Returns null when demo mode is disabled.
final demoMyNodeNumProvider = Provider<int?>((ref) {
  if (!DemoConfig.isEnabled) return null;
  return DemoData.myNodeNum;
});
