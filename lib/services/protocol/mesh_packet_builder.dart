// SPDX-License-Identifier: GPL-3.0-or-later

/// Type-safe MeshPacket construction helpers.
///
/// These builders enforce invariants that prevent local admin packets from
/// accidentally opting into mesh-routing semantics (RELIABLE priority,
/// wantAck) which can cause the firmware to route the packet through the
/// mesh stack instead of processing it as a direct admin command.
///
/// Prefer these builders over inline `pb.MeshPacket()` construction:
///
/// - [MeshPacketBuilder.localAdmin] for admin commands targeting the
///   locally-connected device (from == to == myNodeNum).
/// - [MeshPacketBuilder.remoteAdmin] for admin commands targeting a
///   remote node over the air.
/// - [MeshPacketBuilder.admin] when the target may be local or remote
///   (branches on `targetNodeNum == myNodeNum`).
/// - [MeshPacketBuilder.userPayload] for user-originated payloads
///   (messages, positions, traceroutes, etc.).
library;

import '../../generated/meshtastic/mesh.pb.dart' as pb;
import '../../generated/meshtastic/mesh.pbenum.dart' as pbenum;
import 'admin_target.dart';

/// Centralized MeshPacket construction with enforced local/remote invariants.
abstract final class MeshPacketBuilder {
  /// Builds a packet for a LOCAL admin command (from == to == myNodeNum).
  ///
  /// Local admin packets MUST NOT set [priority] or [wantAck] because
  /// those flags cause the firmware to route the packet through the mesh
  /// stack instead of processing it directly as a local admin command.
  static pb.MeshPacket localAdmin({
    required int myNodeNum,
    required pb.Data data,
    required int packetId,
  }) {
    return pb.MeshPacket()
      ..from = myNodeNum
      ..to = myNodeNum
      ..decoded = data
      ..id = packetId;
  }

  /// Builds a packet for a REMOTE admin command (to != myNodeNum).
  ///
  /// Remote admin packets set RELIABLE priority and wantAck to ensure
  /// delivery through the mesh network to the target node.
  static pb.MeshPacket remoteAdmin({
    required int myNodeNum,
    required int targetNodeNum,
    required pb.Data data,
    required int packetId,
  }) {
    assert(
      targetNodeNum != myNodeNum,
      'Remote admin packet must target a different node. '
      'Use MeshPacketBuilder.localAdmin() for local admin commands.',
    );
    return pb.MeshPacket()
      ..from = myNodeNum
      ..to = targetNodeNum
      ..decoded = data
      ..id = packetId
      ..priority = pbenum.MeshPacket_Priority.RELIABLE
      ..wantAck = true;
  }

  /// Builds an admin packet that may be local or remote, branching
  /// automatically on whether [targetNodeNum] equals [myNodeNum].
  ///
  /// - Local (target == myNodeNum): clean packet, no routing flags
  /// - Remote (target != myNodeNum): RELIABLE priority + wantAck
  static pb.MeshPacket admin({
    required int myNodeNum,
    required int targetNodeNum,
    required pb.Data data,
    required int packetId,
  }) {
    if (targetNodeNum == myNodeNum) {
      final packet = localAdmin(
        myNodeNum: myNodeNum,
        data: data,
        packetId: packetId,
      );
      // Defense-in-depth: verify localAdmin never produces routing flags.
      // If this fires, localAdmin was incorrectly modified to set mesh-routing
      // flags on a self-addressed packet.
      assert(
        !packet.wantAck &&
            packet.priority != pbenum.MeshPacket_Priority.RELIABLE,
        'Local admin packet must not carry wantAck or RELIABLE priority. '
        'This would cause the firmware to route it through the mesh stack.',
      );
      return packet;
    }
    return remoteAdmin(
      myNodeNum: myNodeNum,
      targetNodeNum: targetNodeNum,
      data: data,
      packetId: packetId,
    );
  }

  /// Builds an admin packet using a type-safe [AdminTarget].
  ///
  /// Preferred over [admin] for new code. The sealed [AdminTarget] type
  /// makes the local/remote distinction explicit at the call site and
  /// prevents null-confusion.
  static pb.MeshPacket adminWithTarget({
    required int myNodeNum,
    required AdminTarget target,
    required pb.Data data,
    required int packetId,
  }) {
    final targetNodeNum = target.resolve(myNodeNum);
    return admin(
      myNodeNum: myNodeNum,
      targetNodeNum: targetNodeNum,
      data: data,
      packetId: packetId,
    );
  }

  /// Builds a packet for user-originated payloads (messages, positions,
  /// traceroutes, node info requests, etc.).
  ///
  /// Unlike admin packets, user payloads may legitimately set [wantAck]
  /// and [channel] since they travel over the mesh to other nodes.
  static pb.MeshPacket userPayload({
    required int myNodeNum,
    required int to,
    required pb.Data data,
    required int packetId,
    int channel = 0,
    bool wantAck = false,
  }) {
    final packet = pb.MeshPacket()
      ..from = myNodeNum
      ..to = to
      ..decoded = data
      ..id = packetId;

    if (channel != 0) packet.channel = channel;
    if (wantAck) packet.wantAck = true;

    return packet;
  }
}
