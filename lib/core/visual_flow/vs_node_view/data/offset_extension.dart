// Vendored from vs_node_view v2.1.1 — BSD-3-Clause
// Import paths rewritten for Socialmesh vendoring.

import 'package:flutter/material.dart';

extension ToJson on Offset {
  Map<String, dynamic> toJson() {
    return {"dx": dx, "dy": dy};
  }
}

Offset offsetFromJson(Map<String, dynamic> data) {
  final dx = (data["dx"] as num).toDouble();
  final dy = (data["dy"] as num).toDouble();
  return Offset(dx, dy);
}

extension ToOffset on Size {
  Offset toOffset() {
    return Offset(width, height);
  }
}
