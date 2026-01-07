import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../providers/connection_providers.dart';
import '../../models/mesh_models.dart';
import 'command.dart';

/// Command to send a text message via the mesh network
class SendMessageCommand extends DeviceCommand<int> {
  final String text;
  final int to;
  final int channel;
  final bool wantAck;
  final String? messageId;
  final MessageSource source;
  final int? replyId;
  final bool isEmoji;

  SendMessageCommand({
    required this.text,
    required this.to,
    this.channel = 0,
    this.wantAck = true,
    this.messageId,
    this.source = MessageSource.unknown,
    this.replyId,
    this.isEmoji = false,
  });

  @override
  Set<FeatureRequirement> get requirements => {
    FeatureRequirement.deviceConnection,
  };

  @override
  Future<int> execute(Ref ref) async {
    final protocol = ref.read(protocolServiceProvider);
    return protocol.sendMessage(
      text: text,
      to: to,
      channel: channel,
      wantAck: wantAck,
      messageId: messageId,
      source: source,
      replyId: replyId,
      isEmoji: isEmoji,
    );
  }
}

/// Command to send a message with pre-tracking for ACK handling
class SendMessageWithTrackingCommand extends DeviceCommand<int> {
  final String text;
  final int to;
  final int channel;
  final bool wantAck;
  final String? messageId;
  final void Function(int packetId) onPacketIdGenerated;
  final MessageSource source;
  final int? replyId;
  final bool isEmoji;

  SendMessageWithTrackingCommand({
    required this.text,
    required this.to,
    required this.onPacketIdGenerated,
    this.channel = 0,
    this.wantAck = true,
    this.messageId,
    this.source = MessageSource.unknown,
    this.replyId,
    this.isEmoji = false,
  });

  @override
  Set<FeatureRequirement> get requirements => {
    FeatureRequirement.deviceConnection,
  };

  @override
  Future<int> execute(Ref ref) async {
    final protocol = ref.read(protocolServiceProvider);
    return protocol.sendMessageWithPreTracking(
      text: text,
      to: to,
      channel: channel,
      wantAck: wantAck,
      messageId: messageId,
      onPacketIdGenerated: onPacketIdGenerated,
      source: source,
      replyId: replyId,
      isEmoji: isEmoji,
    );
  }
}

/// Command to request a node's position
class RequestPositionCommand extends DeviceCommand<void> {
  final int nodeNum;

  RequestPositionCommand({required this.nodeNum});

  @override
  Set<FeatureRequirement> get requirements => {
    FeatureRequirement.deviceConnection,
  };

  @override
  Future<void> execute(Ref ref) async {
    final protocol = ref.read(protocolServiceProvider);
    await protocol.requestPosition(nodeNum);
  }
}

/// Command to run a traceroute to a node
class TracerouteCommand extends DeviceCommand<void> {
  final int nodeNum;

  TracerouteCommand({required this.nodeNum});

  @override
  Set<FeatureRequirement> get requirements => {
    FeatureRequirement.deviceConnection,
  };

  @override
  Future<void> execute(Ref ref) async {
    final protocol = ref.read(protocolServiceProvider);
    await protocol.sendTraceroute(nodeNum);
  }
}

/// Command to share current position
class SharePositionCommand extends DeviceCommand<void> {
  final double latitude;
  final double longitude;
  final int? altitude;

  SharePositionCommand({
    required this.latitude,
    required this.longitude,
    this.altitude,
  });

  @override
  Set<FeatureRequirement> get requirements => {
    FeatureRequirement.deviceConnection,
  };

  @override
  Future<void> execute(Ref ref) async {
    final protocol = ref.read(protocolServiceProvider);
    await protocol.sendPosition(
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
    );
  }
}

/// Command to reboot the connected device
class RebootDeviceCommand extends DeviceCommand<void> {
  final int delaySeconds;

  RebootDeviceCommand({this.delaySeconds = 2});

  @override
  Set<FeatureRequirement> get requirements => {
    FeatureRequirement.deviceConnection,
  };

  @override
  Future<void> execute(Ref ref) async {
    final protocol = ref.read(protocolServiceProvider);
    await protocol.reboot(delaySeconds: delaySeconds);
  }
}

/// Command to factory reset config (keeps nodedb)
class FactoryResetConfigCommand extends DeviceCommand<void> {
  @override
  Set<FeatureRequirement> get requirements => {
    FeatureRequirement.deviceConnection,
  };

  @override
  Future<void> execute(Ref ref) async {
    final protocol = ref.read(protocolServiceProvider);
    await protocol.factoryResetConfig();
  }
}

/// Command to factory reset entire device (config + nodedb)
class FactoryResetDeviceCommand extends DeviceCommand<void> {
  @override
  Set<FeatureRequirement> get requirements => {
    FeatureRequirement.deviceConnection,
  };

  @override
  Future<void> execute(Ref ref) async {
    final protocol = ref.read(protocolServiceProvider);
    await protocol.factoryResetDevice();
  }
}

/// Command to shutdown the device
class ShutdownDeviceCommand extends DeviceCommand<void> {
  final int delaySeconds;

  ShutdownDeviceCommand({this.delaySeconds = 2});

  @override
  Set<FeatureRequirement> get requirements => {
    FeatureRequirement.deviceConnection,
  };

  @override
  Future<void> execute(Ref ref) async {
    final protocol = ref.read(protocolServiceProvider);
    await protocol.shutdown(delaySeconds: delaySeconds);
  }
}

/// Command to remove a node from the device's nodedb
class RemoveNodeCommand extends DeviceCommand<void> {
  final int nodeNum;

  RemoveNodeCommand({required this.nodeNum});

  @override
  Set<FeatureRequirement> get requirements => {
    FeatureRequirement.deviceConnection,
  };

  @override
  Future<void> execute(Ref ref) async {
    final protocol = ref.read(protocolServiceProvider);
    await protocol.removeNode(nodeNum);
  }
}

/// Command to set a channel configuration
class SetChannelCommand extends DeviceCommand<void> {
  final ChannelConfig channel;

  SetChannelCommand({required this.channel});

  @override
  Set<FeatureRequirement> get requirements => {
    FeatureRequirement.deviceConnection,
  };

  @override
  Future<void> execute(Ref ref) async {
    final protocol = ref.read(protocolServiceProvider);
    await protocol.setChannel(channel);
  }
}

/// Command to get LoRa configuration from device
class GetLoRaConfigCommand extends DeviceCommand<void> {
  final int? targetNodeNum;

  GetLoRaConfigCommand({this.targetNodeNum});

  @override
  Set<FeatureRequirement> get requirements => {
    FeatureRequirement.deviceConnection,
  };

  @override
  Future<void> execute(Ref ref) async {
    final protocol = ref.read(protocolServiceProvider);
    await protocol.getLoRaConfig(targetNodeNum: targetNodeNum);
  }
}

/// Command to reset the node database
class ResetNodeDbCommand extends DeviceCommand<void> {
  @override
  Set<FeatureRequirement> get requirements => {
    FeatureRequirement.deviceConnection,
  };

  @override
  Future<void> execute(Ref ref) async {
    final protocol = ref.read(protocolServiceProvider);
    await protocol.nodeDbReset();
  }
}

/// Command to enter DFU (firmware update) mode
class EnterDfuModeCommand extends DeviceCommand<void> {
  @override
  Set<FeatureRequirement> get requirements => {
    FeatureRequirement.deviceConnection,
  };

  @override
  Future<void> execute(Ref ref) async {
    final protocol = ref.read(protocolServiceProvider);
    await protocol.enterDfuMode();
  }
}

/// Command to set node as favorite
class SetFavoriteNodeCommand extends DeviceCommand<void> {
  final int nodeNum;

  SetFavoriteNodeCommand({required this.nodeNum});

  @override
  Set<FeatureRequirement> get requirements => {
    FeatureRequirement.deviceConnection,
  };

  @override
  Future<void> execute(Ref ref) async {
    final protocol = ref.read(protocolServiceProvider);
    await protocol.setFavoriteNode(nodeNum);
  }
}

/// Command to remove node from favorites
class RemoveFavoriteNodeCommand extends DeviceCommand<void> {
  final int nodeNum;

  RemoveFavoriteNodeCommand({required this.nodeNum});

  @override
  Set<FeatureRequirement> get requirements => {
    FeatureRequirement.deviceConnection,
  };

  @override
  Future<void> execute(Ref ref) async {
    final protocol = ref.read(protocolServiceProvider);
    await protocol.removeFavoriteNode(nodeNum);
  }
}
