// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../../generated/meshtastic/mesh.pb.dart' as pb;
import '../../generated/meshtastic/portnums.pbenum.dart' as pn;

// Firmware 2.8 keeps a node's latest device and environment telemetry in
// per-node NodeDB records and, after config completes, hands each record to
// the phone as a TELEMETRY_APP packet shaped like a live broadcast. The
// record holds no capture time, so the packet's rxTime and Telemetry.time
// are both the node's last_heard: the last time the radio heard anything
// from that node, which can be days after the values were measured.
//
// Such a packet is recognisable by its id. Live packets carry a random
// 32-bit id; a replayed record's id is derived from (node, rxTime, kind) so
// that an unchanged record keeps the same id across reconnects. Recomputing
// it identifies a replay exactly; a live packet matches by chance with
// probability 2^-32.

/// `kind` the firmware mixes into a replayed device-metrics record's id: the
/// `device_metrics` field number in the Telemetry oneof.
const int firmwareReplayKindDeviceMetrics = 2;

/// `kind` the firmware mixes into a replayed environment-metrics record's id:
/// the `environment_metrics` field number in the Telemetry oneof.
const int firmwareReplayKindEnvironmentMetrics = 3;

const int _mask32 = 0xFFFFFFFF;
const int _goldenRatio32 = 2654435761;

/// The id firmware 2.8 assigns to a replayed NodeDB record
/// (`makeReplayPacketId` in PhoneAPI.cpp), computed in uint32 arithmetic.
int firmwareReplayPacketId(int nodeNum, int timestamp, int kind) {
  var h = nodeNum & _mask32;
  h = (_mul32(h, _goldenRatio32) + (timestamp & _mask32)) & _mask32;
  h = (_mul32(h, _goldenRatio32) + kind) & _mask32;
  return h == 0 ? 1 : h;
}

// uint32 multiply that stays exact where ints are doubles (web): each
// partial product is below 2^48.
int _mul32(int a, int b) {
  final low = (a & 0xFFFF) * b;
  final high = (((a >>> 16) * b) & 0xFFFF) * 0x10000;
  return (low + high) & _mask32;
}

/// Whether [packet] is firmware 2.8's replay of a cached NodeDB record of
/// [kind] rather than a packet the radio just heard.
bool isFirmwareReplayOfKind(pb.MeshPacket packet, int kind) =>
    packet.id == firmwareReplayPacketId(packet.from, packet.rxTime, kind);

/// Whether [packet] is any firmware 2.8 NodeDB replay (position, device or
/// environment telemetry, status) rather than a packet the radio received.
/// Positions and status records use their portnum as the kind.
bool isFirmwareSatelliteReplay(pb.MeshPacket packet) {
  if (!packet.hasDecoded()) return false;
  final portnum = packet.decoded.portnum;
  if (portnum == pn.PortNum.TELEMETRY_APP) {
    return isFirmwareReplayOfKind(packet, firmwareReplayKindDeviceMetrics) ||
        isFirmwareReplayOfKind(packet, firmwareReplayKindEnvironmentMetrics);
  }
  if (portnum == pn.PortNum.POSITION_APP ||
      portnum == pn.PortNum.NODE_STATUS_APP) {
    return isFirmwareReplayOfKind(packet, portnum.value);
  }
  return false;
}
