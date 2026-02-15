// SPDX-License-Identifier: GPL-3.0-or-later

/// Socialmesh binary codec for custom packet types over Meshtastic.
///
/// Encodes and decodes SM_PRESENCE, SM_SIGNAL, and SM_IDENTITY packets
/// using compact binary encoding. All packets are transported via the
/// Meshtastic private portnum range (256-511).
///
/// See docs/firmware/PACKET_TYPES.md for the full wire format specification.
library;

export 'sm_capability_store.dart';
export 'sm_codec.dart';
export 'sm_constants.dart';
export 'sm_feature_flag.dart';
export 'sm_identity.dart';
export 'sm_metrics.dart';
export 'sm_packet_router.dart';
export 'sm_presence.dart';
export 'sm_signal.dart';
