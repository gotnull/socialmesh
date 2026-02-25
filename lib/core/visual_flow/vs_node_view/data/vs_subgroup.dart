// SPDX-License-Identifier: GPL-3.0-or-later

// Vendored from vs_node_view v2.1.1 — BSD-3-Clause
// Import paths rewritten for Socialmesh vendoring.

/// Small data class used to create a sub group in the context menu.
///
/// Creates contextNodeBuilders and _nodeBuilders inside
/// VSNodeSerializationManager.
class VSSubgroup {
  VSSubgroup({required this.name, required this.subgroup});

  final String name;
  final List<dynamic> subgroup;
}
