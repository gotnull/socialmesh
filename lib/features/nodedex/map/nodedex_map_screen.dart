// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodeDex Map entry point. NodeDex builds its entries from
// nodesProvider, so the canonical MapScreen already shows every node
// the user has discovered with a position. Opening MapScreen
// directly guarantees 1:1 parity — same shell, overlays, controls,
// marker preview card, camera helpers, animations and theme handling
// because it is the same screen.

import 'package:flutter/material.dart';

import '../../../core/logging.dart';
import '../../map/map_screen.dart';

Future<void> openNodeDexMap(BuildContext context) {
  AppLogging.nodeDex('Map: opening canonical MapScreen from NodeDex');
  return Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const MapScreen()));
}
