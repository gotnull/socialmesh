// SPDX-License-Identifier: GPL-3.0-or-later

/// Portnum allocations within the Meshtastic private range (256-511).
///
/// These values are used as the `portnum` field in `MeshPacket.decoded.portnum`.
/// Stock Meshtastic firmware routes these identically to any other portnum.
abstract final class SmPortnum {
  /// Legacy JSON-encoded signals (backward compatible with existing releases).
  static const int legacy = 256;

  /// Compact binary presence beacon.
  static const int presence = 260;

  /// Binary-encoded signal broadcast.
  static const int signal = 261;

  /// NodeDex identity digest.
  static const int identity = 262;

  /// All Socialmesh portnums for capability detection.
  static const Set<int> all = {presence, signal, identity};

  /// Returns true if the portnum is a Socialmesh extension portnum.
  static bool isSocialmesh(int portnum) => all.contains(portnum);
}

/// Protocol version. High nibble of the header byte.
abstract final class SmVersion {
  /// Current protocol version.
  static const int current = 0;

  /// Maximum supported version for forward compatibility.
  static const int maxSupported = 0;
}

/// Packet kind values (low nibble of hdr0). Globally unique across portnums.
abstract final class SmPacketKind {
  /// SM_PRESENCE.
  static const int presence = 1;

  /// SM_SIGNAL.
  static const int signal = 2;

  /// SM_IDENTITY.
  static const int identity = 3;
}

/// Rate limiting intervals for each packet type.
abstract final class SmRateLimit {
  /// Minimum interval between presence beacons.
  static const Duration presenceInterval = Duration(minutes: 5);

  /// Minimum interval between signal broadcasts.
  static const Duration signalInterval = Duration(seconds: 30);

  /// Maximum emergency signals per hour.
  static const int maxEmergencyPerHour = 3;

  /// Minimum interval between unsolicited identity broadcasts.
  static const Duration identityBroadcastInterval = Duration(minutes: 30);

  /// Minimum interval between identity requests to the same node.
  static const Duration identityRequestInterval = Duration(minutes: 10);
}

/// Transport parameters for each packet type.
abstract final class SmTransport {
  /// Default hop limit for presence beacons (local range).
  static const int presenceHopLimit = 2;

  /// Default hop limit for signals.
  static const int signalHopLimit = 3;

  /// Hop limit for emergency signals.
  static const int emergencyHopLimit = 5;

  /// Default hop limit for unsolicited identity broadcasts.
  static const int identityBroadcastHopLimit = 1;

  /// Hop limit for identity request/response (needs to reach specific node).
  static const int identityRequestHopLimit = 3;
}

/// Maximum payload sizes for validation.
abstract final class SmPayloadLimit {
  /// Maximum presence status string length in bytes.
  static const int presenceStatusMaxBytes = 63;

  /// Maximum signal content string length in bytes.
  static const int signalContentMaxBytes = 140;

  /// LoRa MTU target ceiling for the Data.payload field.
  ///
  /// Actual maximum depends on radio settings (SF, BW, CR) and regional
  /// regulatory constraints. All SM packets enforce hard content caps well
  /// below this ceiling (presence: 63 B, signal: 140 B content).
  static const int loraMtu = 237;
}
