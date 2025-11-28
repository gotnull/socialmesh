import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:logger/logger.dart';
import '../../core/transport.dart';
import '../../models/mesh_models.dart';
import '../../models/device_error.dart';
import '../../generated/meshtastic/mesh.pb.dart' as pb;
import '../../generated/meshtastic/portnums.pb.dart' as pn;
import 'packet_framer.dart';

/// Protocol service for handling Meshtastic protocol
class ProtocolService {
  final DeviceTransport _transport;
  final Logger _logger;
  final PacketFramer _framer;

  final StreamController<Message> _messageController;
  final StreamController<MeshNode> _nodeController;
  final StreamController<ChannelConfig> _channelController;
  final StreamController<DeviceError> _errorController;

  StreamSubscription<List<int>>? _dataSubscription;
  Timer? _configTimeoutTimer;

  int? _myNodeNum;
  final Map<int, MeshNode> _nodes = {};
  final List<ChannelConfig> _channels = [];
  final Random _random = Random();
  bool _configurationComplete = false;

  ProtocolService(this._transport, {Logger? logger})
    : _logger = logger ?? Logger(),
      _framer = PacketFramer(logger: logger),
      _messageController = StreamController<Message>.broadcast(),
      _nodeController = StreamController<MeshNode>.broadcast(),
      _channelController = StreamController<ChannelConfig>.broadcast(),
      _errorController = StreamController<DeviceError>.broadcast();

  /// Stream of received messages
  Stream<Message> get messageStream => _messageController.stream;

  /// Stream of node updates
  Stream<MeshNode> get nodeStream => _nodeController.stream;

  /// Stream of channel updates
  Stream<ChannelConfig> get channelStream => _channelController.stream;

  /// Stream of device errors
  Stream<DeviceError> get errorStream => _errorController.stream;

  /// My node number
  int? get myNodeNum => _myNodeNum;

  /// Configuration complete
  bool get configurationComplete => _configurationComplete;

  /// All known nodes
  Map<int, MeshNode> get nodes => Map.unmodifiable(_nodes);

  /// All channels
  List<ChannelConfig> get channels => List.unmodifiable(_channels);

  /// Start listening to transport
  void start() {
    _logger.i('Starting protocol service');

    _dataSubscription = _transport.dataStream.listen(
      _handleData,
      onError: (error) {
        _logger.e('Transport error: $error');
      },
    );

    // Request configuration after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _requestConfiguration();

      // Set timeout for configuration
      _configTimeoutTimer?.cancel();
      _configTimeoutTimer = Timer(const Duration(seconds: 30), () {
        if (!_configurationComplete) {
          _logger.w('Configuration timeout - continuing anyway');
          _configurationComplete = true;
        }
      });
    });
  }

  /// Stop listening
  void stop() {
    _logger.i('Stopping protocol service');
    _configTimeoutTimer?.cancel();
    _configTimeoutTimer = null;
    _dataSubscription?.cancel();
    _dataSubscription = null;
    _framer.clear();
    _configurationComplete = false;
  }

  /// Handle incoming data
  void _handleData(List<int> data) {
    _logger.d('Received ${data.length} bytes');

    // Extract packets using framer
    final packets = _framer.addData(data);

    for (final packet in packets) {
      _processPacket(packet);
    }
  }

  /// Process a complete packet
  void _processPacket(List<int> packet) {
    try {
      _logger.d('Processing packet: ${packet.length} bytes');

      final fromRadio = pn.FromRadio.fromBuffer(packet);

      if (fromRadio.hasPacket()) {
        _handleMeshPacket(fromRadio.packet);
      } else if (fromRadio.hasMyInfo()) {
        _handleMyNodeInfo(fromRadio.myInfo);
      } else if (fromRadio.hasNodeInfo()) {
        _handleNodeInfo(fromRadio.nodeInfo);
      } else if (fromRadio.hasChannel()) {
        _handleChannel(fromRadio.channel);
      } else if (fromRadio.hasConfigCompleteId()) {
        _logger.i('Configuration complete: ${fromRadio.configCompleteId}');
        _configTimeoutTimer?.cancel();
        _configurationComplete = true;
      }
    } catch (e, stack) {
      _logger.e('Error processing packet: $e', error: e, stackTrace: stack);
    }
  }

  /// Handle incoming mesh packet
  void _handleMeshPacket(pb.MeshPacket packet) {
    _logger.d('Handling mesh packet from ${packet.from} to ${packet.to}');

    if (packet.hasDecoded()) {
      final data = packet.decoded;

      switch (data.portnum) {
        case pb.PortNum.TEXT_MESSAGE_APP:
          _handleTextMessage(packet, data);
          break;
        case pb.PortNum.POSITION_APP:
          _handlePositionUpdate(packet, data);
          break;
        case pb.PortNum.NODEINFO_APP:
          _handleNodeInfoUpdate(packet, data);
          break;
        case pb.PortNum.ADMIN_APP:
          _logger.d('Received admin message');
          break;
        default:
          _logger.d('Received message with portnum: ${data.portnum}');
      }
    }
  }

  /// Handle text message
  void _handleTextMessage(pb.MeshPacket packet, pb.Data data) {
    try {
      final text = utf8.decode(data.payload);
      _logger.i('Text message from ${packet.from}: $text');

      final message = Message(
        from: packet.from,
        to: packet.to,
        text: text,
        channel: packet.channel,
        received: true,
      );

      _messageController.add(message);
    } catch (e) {
      _logger.e('Error decoding text message: $e');
    }
  }

  /// Handle position update
  void _handlePositionUpdate(pb.MeshPacket packet, pb.Data data) {
    try {
      final position = pb.Position.fromBuffer(data.payload);
      _logger.d(
        'Position from ${packet.from}: ${position.latitudeI / 1e7}, ${position.longitudeI / 1e7}',
      );

      final node = _nodes[packet.from];
      if (node != null) {
        final updatedNode = node.copyWith(
          latitude: position.latitudeI / 1e7,
          longitude: position.longitudeI / 1e7,
          altitude: position.altitude,
          lastHeard: DateTime.now(),
        );
        _nodes[packet.from] = updatedNode;
        _nodeController.add(updatedNode);
      }
    } catch (e) {
      _logger.e('Error decoding position: $e');
    }
  }

  /// Handle node info update
  void _handleNodeInfoUpdate(pb.MeshPacket packet, pb.Data data) {
    try {
      final user = pb.User.fromBuffer(data.payload);
      _logger.i('Node info from ${packet.from}: ${user.longName}');

      final existingNode = _nodes[packet.from];
      final updatedNode =
          existingNode?.copyWith(
            longName: user.longName,
            shortName: user.shortName,
            lastHeard: DateTime.now(),
          ) ??
          MeshNode(
            nodeNum: packet.from,
            longName: user.longName,
            shortName: user.shortName,
            lastHeard: DateTime.now(),
          );

      _nodes[packet.from] = updatedNode;
      _nodeController.add(updatedNode);
    } catch (e) {
      _logger.e('Error decoding node info: $e');
    }
  }

  /// Handle my node info
  void _handleMyNodeInfo(pb.MyNodeInfo myInfo) {
    _myNodeNum = myInfo.myNodeNum;
    _logger.i('My node number: $_myNodeNum');
  }

  /// Handle node info
  void _handleNodeInfo(pb.NodeInfo nodeInfo) {
    _logger.i('Node info received: ${nodeInfo.num}');

    final existingNode = _nodes[nodeInfo.num];

    MeshNode updatedNode;
    if (existingNode != null) {
      updatedNode = existingNode.copyWith(
        longName: nodeInfo.hasUser()
            ? nodeInfo.user.longName
            : existingNode.longName,
        shortName: nodeInfo.hasUser()
            ? nodeInfo.user.shortName
            : existingNode.shortName,
        latitude: nodeInfo.hasPosition()
            ? nodeInfo.position.latitudeI / 1e7
            : existingNode.latitude,
        longitude: nodeInfo.hasPosition()
            ? nodeInfo.position.longitudeI / 1e7
            : existingNode.longitude,
        altitude: nodeInfo.hasPosition()
            ? nodeInfo.position.altitude
            : existingNode.altitude,
        lastHeard: DateTime.now(),
      );
    } else {
      updatedNode = MeshNode(
        nodeNum: nodeInfo.num,
        longName: nodeInfo.hasUser() ? nodeInfo.user.longName : '',
        shortName: nodeInfo.hasUser() ? nodeInfo.user.shortName : '',
        latitude: nodeInfo.hasPosition()
            ? nodeInfo.position.latitudeI / 1e7
            : null,
        longitude: nodeInfo.hasPosition()
            ? nodeInfo.position.longitudeI / 1e7
            : null,
        altitude: nodeInfo.hasPosition() ? nodeInfo.position.altitude : null,
        lastHeard: DateTime.now(),
      );
    }

    _nodes[nodeInfo.num] = updatedNode;
    _nodeController.add(updatedNode);
  }

  /// Handle channel configuration
  void _handleChannel(pb.Channel channel) {
    _logger.i('Channel ${channel.index} config received');

    final channelConfig = ChannelConfig(
      index: channel.index,
      name: channel.hasSettings() ? channel.settings.name : '',
      psk: channel.hasSettings() ? channel.settings.psk : [],
      uplink: channel.hasSettings() ? channel.settings.uplinkEnabled : false,
      downlink: channel.hasSettings()
          ? channel.settings.downlinkEnabled
          : false,
    );

    if (_channels.length <= channel.index) {
      _channels.addAll(
        List.filled(
          channel.index - _channels.length + 1,
          ChannelConfig(index: 0, name: '', psk: []),
        ),
      );
    }
    _channels[channel.index] = channelConfig;

    _channelController.add(channelConfig);
  }

  /// Request configuration from device
  Future<void> _requestConfiguration() async {
    try {
      if (!_transport.isConnected) {
        _logger.w('Cannot request configuration: not connected');
        return;
      }

      _logger.i('Requesting device configuration');

      final toRadio = pn.ToRadio()..wantConfigId = true;
      final bytes = toRadio.writeToBuffer();
      final framedBytes = PacketFramer.frame(bytes);

      await _transport.send(framedBytes);
    } catch (e) {
      _logger.e('Error requesting configuration: $e');
    }
  }

  /// Send a text message
  Future<void> sendMessage({
    required String text,
    required int to,
    int channel = 0,
    bool wantAck = false,
  }) async {
    try {
      _logger.i('Sending message to $to: $text');

      final data = pb.Data()
        ..portnum = pb.PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode(text)
        ..wantResponse = wantAck;

      final packet = pb.MeshPacket()
        ..from = _myNodeNum ?? 0
        ..to = to
        ..channel = channel
        ..decoded = data
        ..id = _generatePacketId()
        ..wantAck = wantAck;

      final toRadio = pn.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();
      final framedBytes = PacketFramer.frame(bytes);

      await _transport.send(framedBytes);

      final message = Message(
        from: _myNodeNum ?? 0,
        to: to,
        text: text,
        channel: channel,
        sent: true,
      );

      _messageController.add(message);
    } catch (e) {
      _logger.e('Error sending message: $e');
      rethrow;
    }
  }

  /// Generate a random packet ID
  int _generatePacketId() {
    return _random.nextInt(0x7FFFFFFF);
  }

  /// Send position
  Future<void> sendPosition({
    required double latitude,
    required double longitude,
    int? altitude,
  }) async {
    try {
      _logger.i('Sending position: $latitude, $longitude');

      final position = pb.Position()
        ..latitudeI = (latitude * 1e7).toInt()
        ..longitudeI = (longitude * 1e7).toInt()
        ..time = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      if (altitude != null) {
        position.altitude = altitude;
      }

      final data = pb.Data()
        ..portnum = pb.PortNum.POSITION_APP
        ..payload = position.writeToBuffer();

      final packet = pb.MeshPacket()
        ..from = _myNodeNum ?? 0
        ..to =
            0xFFFFFFFF // Broadcast
        ..decoded = data
        ..id = _generatePacketId();

      final toRadio = pn.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();
      final framedBytes = PacketFramer.frame(bytes);

      await _transport.send(framedBytes);
    } catch (e) {
      _logger.e('Error sending position: $e');
      rethrow;
    }
  }

  /// Request node info
  Future<void> requestNodeInfo(int nodeNum) async {
    try {
      _logger.i('Requesting node info for $nodeNum');

      final data = pb.Data()
        ..portnum = pb.PortNum.NODEINFO_APP
        ..wantResponse = true;

      final packet = pb.MeshPacket()
        ..from = _myNodeNum ?? 0
        ..to = nodeNum
        ..decoded = data
        ..id = _generatePacketId()
        ..wantAck = true;

      final toRadio = pn.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();
      final framedBytes = PacketFramer.frame(bytes);

      await _transport.send(framedBytes);
    } catch (e) {
      _logger.e('Error requesting node info: $e');
    }
  }

  /// Set channel
  Future<void> setChannel(ChannelConfig config) async {
    try {
      _logger.i('Setting channel ${config.index}: ${config.name}');

      final channelSettings = pb.ChannelSettings()
        ..name = config.name
        ..psk = config.psk
        ..uplinkEnabled = config.uplink
        ..downlinkEnabled = config.downlink;

      final channel = pb.Channel()
        ..index = config.index
        ..settings = channelSettings;

      final adminMsg = pb.AdminMessage()..setChannel = channel;

      final data = pb.Data()
        ..portnum = pb.PortNum.ADMIN_APP
        ..payload = adminMsg.writeToBuffer()
        ..wantResponse = true;

      final packet = pb.MeshPacket()
        ..from = _myNodeNum ?? 0
        ..to =
            _myNodeNum ??
            0 // Admin messages to self
        ..decoded = data
        ..id = _generatePacketId();

      final toRadio = pn.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();
      final framedBytes = PacketFramer.frame(bytes);

      await _transport.send(framedBytes);
    } catch (e) {
      _logger.e('Error setting channel: $e');
      rethrow;
    }
  }

  /// Get channel
  Future<void> getChannel(int index) async {
    try {
      _logger.i('Getting channel $index');

      final adminMsg = pb.AdminMessage()..getChannelRequest = index + 1;

      final data = pb.Data()
        ..portnum = pb.PortNum.ADMIN_APP
        ..payload = adminMsg.writeToBuffer()
        ..wantResponse = true;

      final packet = pb.MeshPacket()
        ..from = _myNodeNum ?? 0
        ..to = _myNodeNum ?? 0
        ..decoded = data
        ..id = _generatePacketId();

      final toRadio = pn.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();
      final framedBytes = PacketFramer.frame(bytes);

      await _transport.send(framedBytes);
    } catch (e) {
      _logger.e('Error getting channel: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    _configTimeoutTimer?.cancel();
    await _dataSubscription?.cancel();
    await _messageController.close();
    await _nodeController.close();
    await _channelController.close();
    await _errorController.close();
  }
}
