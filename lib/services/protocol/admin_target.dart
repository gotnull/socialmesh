// SPDX-License-Identifier: GPL-3.0-or-later

/// Encodes the intent of an admin operation: local device or remote node.
///
/// Using this type instead of a raw `int?` makes the distinction between
/// local and remote admin paths impossible to confuse at the call site.
///
/// ```dart
/// // Local admin — clean packet, no routing flags
/// await protocol.setConfig(config, target: AdminTarget.local());
///
/// // Remote admin — RELIABLE + wantAck, optional ACK confirmation
/// await protocol.setConfig(
///   config,
///   target: AdminTarget.remote(0x12345678),
/// );
/// ```
sealed class AdminTarget {
  const AdminTarget._();

  /// Target the locally-connected device.
  ///
  /// Packets built for a local target MUST NOT set wantAck or RELIABLE
  /// priority — those flags cause the firmware to route through the mesh
  /// stack instead of processing directly as a local admin command.
  const factory AdminTarget.local() = LocalAdminTarget;

  /// Target a remote node over the air.
  ///
  /// Packets built for a remote target set RELIABLE priority and wantAck
  /// to ensure delivery through the mesh network.
  const factory AdminTarget.remote(int nodeNum) = RemoteAdminTarget;

  /// Whether this target represents the local device.
  bool get isLocal;

  /// Whether this target represents a remote node.
  bool get isRemote => !isLocal;

  /// Resolve the destination node number.
  ///
  /// For [LocalAdminTarget], returns [myNodeNum].
  /// For [RemoteAdminTarget], returns the remote node number.
  int resolve(int myNodeNum);

  /// Create an [AdminTarget] from a nullable node number.
  ///
  /// - `null` → [AdminTarget.local()]
  /// - A node number → [AdminTarget.remote(nodeNum)]
  ///
  /// This is a migration convenience for code that still passes raw
  /// `int? targetNodeNum`. New code should use the explicit constructors.
  static AdminTarget fromNullable(int? targetNodeNum) {
    if (targetNodeNum == null) return const AdminTarget.local();
    return AdminTarget.remote(targetNodeNum);
  }
}

/// Admin operation targeting the locally-connected device.
final class LocalAdminTarget extends AdminTarget {
  const LocalAdminTarget() : super._();

  @override
  bool get isLocal => true;

  @override
  int resolve(int myNodeNum) => myNodeNum;

  @override
  String toString() => 'AdminTarget.local()';

  @override
  bool operator ==(Object other) => other is LocalAdminTarget;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Admin operation targeting a remote node over the air.
final class RemoteAdminTarget extends AdminTarget {
  /// The node number of the remote device.
  final int nodeNum;

  const RemoteAdminTarget(this.nodeNum) : super._();

  @override
  bool get isLocal => false;

  @override
  int resolve(int myNodeNum) => nodeNum;

  @override
  String toString() => 'AdminTarget.remote(0x${nodeNum.toRadixString(16)})';

  @override
  bool operator ==(Object other) =>
      other is RemoteAdminTarget && other.nodeNum == nodeNum;

  @override
  int get hashCode => Object.hash(runtimeType, nodeNum);
}
