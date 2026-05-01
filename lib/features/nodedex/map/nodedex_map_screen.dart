// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodeDex Map entry point.
//
// The NodeDex Map is the canonical `MapScreen` running in
// `nodedexMode: true`. In that mode MapScreen swaps its marker source
// from the live `nodesProvider` to `nodedexMapPinsProvider` and
// synthesizes a `MeshNode` per pin so that every existing MapScreen
// feature — filtering, search, layer toggles, compass, recenter,
// fit-all, info card with "Open in NodeDex", traceroute support — keeps
// working unchanged. This file owns only the entry-point function;
// there is intentionally no parallel NodeDex map screen.

import 'package:flutter/material.dart';

import '../../../core/logging.dart';
import '../../map/map_screen.dart';

Future<void> openNodeDexMap(BuildContext context) {
  AppLogging.nodeDex('Map: opening MapScreen(nodedexMode: true)');
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const MapScreen(nodedexMode: true)),
  );
}
