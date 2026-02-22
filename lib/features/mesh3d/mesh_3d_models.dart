// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

/// View modes for the 3D mesh visualization.
///
/// Reduced to 4 focused modes — each backed by real data we actually have.
/// Removed: channelUtilization (niche), signalPropagation (fabricated range
/// rings), traceroute (fabricated routes — we don't know inter-node paths).
enum Mesh3DViewMode { topology, signalStrength, activity, terrain }

/// Node filters for the 3D visualization.
enum Mesh3DNodeFilter { all, active, activeFading, gpsOnly }

// ---------------------------------------------------------------------------
// Mesh3DNodeFilter extensions
// ---------------------------------------------------------------------------

extension Mesh3DNodeFilterExt on Mesh3DNodeFilter {
  String get label {
    switch (this) {
      case Mesh3DNodeFilter.all:
        return 'All Nodes';
      case Mesh3DNodeFilter.active:
        return 'Active';
      case Mesh3DNodeFilter.activeFading:
        return 'Recent';
      case Mesh3DNodeFilter.gpsOnly:
        return 'GPS Only';
    }
  }

  IconData get icon {
    switch (this) {
      case Mesh3DNodeFilter.all:
        return Icons.group;
      case Mesh3DNodeFilter.active:
        return Icons.wifi;
      case Mesh3DNodeFilter.activeFading:
        return Icons.wifi_tethering;
      case Mesh3DNodeFilter.gpsOnly:
        return Icons.gps_fixed;
    }
  }
}

// ---------------------------------------------------------------------------
// Mesh3DViewMode extensions
// ---------------------------------------------------------------------------

extension Mesh3DViewModeExt on Mesh3DViewMode {
  String get label {
    switch (this) {
      case Mesh3DViewMode.topology:
        return 'Topology';
      case Mesh3DViewMode.signalStrength:
        return 'Signal Bars';
      case Mesh3DViewMode.activity:
        return 'Activity';
      case Mesh3DViewMode.terrain:
        return 'Terrain';
    }
  }

  String get description {
    switch (this) {
      case Mesh3DViewMode.topology:
        return 'Star layout from your node — signal quality as distance';
      case Mesh3DViewMode.signalStrength:
        return 'RSSI and SNR bars per node';
      case Mesh3DViewMode.activity:
        return 'Node activity sorted by recency';
      case Mesh3DViewMode.terrain:
        return 'GPS nodes on interpolated terrain';
    }
  }

  IconData get icon {
    switch (this) {
      case Mesh3DViewMode.topology:
        return Icons.hub;
      case Mesh3DViewMode.signalStrength:
        return Icons.signal_cellular_alt;
      case Mesh3DViewMode.activity:
        return Icons.bar_chart;
      case Mesh3DViewMode.terrain:
        return Icons.terrain;
    }
  }
}
