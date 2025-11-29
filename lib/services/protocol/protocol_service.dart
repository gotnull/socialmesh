import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
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
  final StreamController<int> _myNodeNumController;
  final StreamController<int> _rssiController;
  final StreamController<MessageDeliveryUpdate> _deliveryController;

  StreamSubscription<List<int>>? _dataSubscription;
  Completer<void>? _configCompleter;
  Timer? _rssiTimer;

  int? _myNodeNum;
  int _lastRssi = -90;
  final Map<int, MeshNode> _nodes = {};
  final List<ChannelConfig> _channels = [];
  final Random _random = Random();
  bool _configurationComplete = false;

  // Track pending messages by packet ID for delivery status updates
  final Map<int, String> _pendingMessages = {}; // packetId -> messageId

  ProtocolService(this._transport, {Logger? logger})
    : _logger = logger ?? Logger(),
      _framer = PacketFramer(logger: logger),
      _messageController = StreamController<Message>.broadcast(),
      _nodeController = StreamController<MeshNode>.broadcast(),
      _channelController = StreamController<ChannelConfig>.broadcast(),
      _errorController = StreamController<DeviceError>.broadcast(),
      _myNodeNumController = StreamController<int>.broadcast(),
      _rssiController = StreamController<int>.broadcast(),
      _deliveryController = StreamController<MessageDeliveryUpdate>.broadcast();

  /// Stream of received messages
  Stream<Message> get messageStream => _messageController.stream;

  /// Stream of node updates
  Stream<MeshNode> get nodeStream => _nodeController.stream;

  /// Stream of channel updates
  Stream<ChannelConfig> get channelStream => _channelController.stream;

  /// Stream of RSSI updates
  Stream<int> get rssiStream => _rssiController.stream;

  /// Stream of message delivery updates
  Stream<MessageDeliveryUpdate> get deliveryStream =>
      _deliveryController.stream;

  /// Get last known RSSI
  int get lastRssi => _lastRssi;

  /// Stream of device errors
  Stream<DeviceError> get errorStream => _errorController.stream;

  /// Stream of my node number updates
  Stream<int> get myNodeNumStream => _myNodeNumController.stream;

  /// My node number
  int? get myNodeNum => _myNodeNum;

  /// Configuration complete
  bool get configurationComplete => _configurationComplete;

  /// All known nodes
  Map<int, MeshNode> get nodes => Map.unmodifiable(_nodes);

  /// All channels
  List<ChannelConfig> get channels => List.unmodifiable(_channels);

  /// Start listening to transport and wait for configuration
  Future<void> start() async {
    _logger.i('Starting protocol service');

    _configCompleter = Completer<void>();

    _dataSubscription = _transport.dataStream.listen(
      _handleData,
      onError: (error) {
        _logger.e('Transport error: $error');
      },
    );

    // Enable notifications FIRST - device needs this to respond to config request
    await _transport.enableNotifications();

    // Short delay to let notifications settle
    await Future.delayed(const Duration(milliseconds: 200));

    // NOW request configuration - device will respond via notifications
    await _requestConfiguration();

    // Start polling for configuration response
    // Notifications should work, but poll as backup
    _pollForConfigurationAsync();

    // Wait for config with timeout
    final configFuture = _configCompleter!.future;
    final timeoutFuture = Future.delayed(const Duration(seconds: 15));

    _logger.i('Waiting for config or timeout...');
    await Future.any([configFuture, timeoutFuture]);

    if (!_configCompleter!.isCompleted) {
      _logger.i('Configuration not received, proceeding anyway');
      _configurationComplete = true;
      _configCompleter!.complete();
    } else {
      _logger.i('Configuration was received');
    }

    // Start RSSI polling timer (every 2 seconds)
    _startRssiPolling();

    _logger.i('Protocol service started');
  }

  /// Start periodic RSSI polling from BLE connection
  void _startRssiPolling() {
    _rssiTimer?.cancel();
    _rssiTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final rssi = await _transport.readRssi();
      if (rssi != null && rssi != _lastRssi) {
        _lastRssi = rssi;
        _rssiController.add(rssi);
      }
    });
  }

  /// Poll for configuration data in background (non-blocking)
  void _pollForConfigurationAsync() {
    int pollCount = 0;
    const maxPolls = 100;

    Future.doWhile(() async {
      if (_configurationComplete || pollCount >= maxPolls) {
        return false; // Stop polling
      }

      try {
        await _transport.pollOnce();
        pollCount++;
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        _logger.w('Poll error: $e');
      }
      return true; // Continue polling
    });
  }

  /// Stop listening
  void stop() {
    _logger.i('Stopping protocol service');
    _rssiTimer?.cancel();
    _rssiTimer = null;
    if (_configCompleter != null && !_configCompleter!.isCompleted) {
      _configCompleter!.completeError('Service stopped');
    }
    _configCompleter = null;
    _dataSubscription?.cancel();
    _dataSubscription = null;
    _framer.clear();
    _configurationComplete = false;
  }

  /// Handle incoming data from transport
  void _handleData(List<int> data) {
    _logger.d('Received ${data.length} bytes');

    if (_transport.requiresFraming) {
      // Serial/USB: Extract packets using framer
      final packets = _framer.addData(data);

      for (final packet in packets) {
        _processPacket(packet);
      }
    } else {
      // BLE: Data is already a complete raw protobuf
      if (data.isNotEmpty) {
        _processPacket(data);
      }
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
        _configurationComplete = true;
        if (_configCompleter != null && !_configCompleter!.isCompleted) {
          _configCompleter!.complete();
        }
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
        case pb.PortNum.ROUTING_APP:
          _handleRoutingMessage(packet, data);
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

  /// Handle routing message (ACK/NAK/errors)
  void _handleRoutingMessage(pb.MeshPacket packet, pb.Data data) {
    try {
      // The routing payload contains an error code
      // If requestId is set, it references the original packet that this is a response to
      final requestId = data.requestId;

      if (requestId == 0) {
        _logger.d('Routing message with no requestId, ignoring');
        return;
      }

      // Parse the error code from the payload
      // The Routing message has: errorReason field (uint32)
      int errorCode = 0;
      if (data.payload.isNotEmpty) {
        // Simple parsing - error code is typically the first varint in the routing payload
        // For a proper implementation, we'd need the Routing protobuf message
        // But we can check if it's a success (empty or 0) vs failure
        errorCode = data.payload[0];
      }

      final routingError = RoutingError.fromCode(errorCode);
      final delivered = routingError.isSuccess;

      _logger.i(
        'Routing response for packet $requestId: ${routingError.message} (code: $errorCode)',
      );

      // Check if we're tracking this packet
      final messageId = _pendingMessages[requestId];
      if (messageId != null) {
        _pendingMessages.remove(requestId);
      }

      // Emit delivery update
      final update = MessageDeliveryUpdate(
        packetId: requestId,
        delivered: delivered,
        error: delivered ? null : routingError,
      );
      _deliveryController.add(update);
    } catch (e) {
      _logger.e('Error handling routing message: $e');
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

      final colors = [
        0xFF1976D2,
        0xFFD32F2F,
        0xFF388E3C,
        0xFFF57C00,
        0xFF7B1FA2,
        0xFF00796B,
        0xFFC2185B,
      ];
      final avatarColor = colors[packet.from % colors.length];

      final existingNode = _nodes[packet.from];
      final updatedNode =
          existingNode?.copyWith(
            longName: user.longName,
            shortName: user.shortName,
            snr: packet.hasRxSnr() ? packet.rxSnr.toInt() : existingNode.snr,
            lastHeard: DateTime.now(),
            isOnline: true,
          ) ??
          MeshNode(
            nodeNum: packet.from,
            longName: user.longName,
            shortName: user.shortName,
            snr: packet.hasRxSnr() ? packet.rxSnr.toInt() : null,
            lastHeard: DateTime.now(),
            isOnline: true,
            avatarColor: avatarColor,
            isFavorite: false,
            role: 'CLIENT',
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
    _myNodeNumController.add(_myNodeNum!);
  }

  /// Handle node info
  void _handleNodeInfo(pb.NodeInfo nodeInfo) {
    _logger.i('Node info received: ${nodeInfo.num}');

    final existingNode = _nodes[nodeInfo.num];

    // Generate consistent color from node number
    final colors = [
      0xFF1976D2,
      0xFFD32F2F,
      0xFF388E3C,
      0xFFF57C00,
      0xFF7B1FA2,
      0xFF00796B,
      0xFFC2185B,
    ];
    final avatarColor = colors[nodeInfo.num % colors.length];

    // Assume router role if device has metrics, otherwise client
    final role = nodeInfo.hasDeviceMetrics() ? 'ROUTER' : 'CLIENT';

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
        snr: nodeInfo.hasSnr() ? nodeInfo.snr.toInt() : existingNode.snr,
        batteryLevel: nodeInfo.hasDeviceMetrics()
            ? nodeInfo.deviceMetrics.batteryLevel
            : existingNode.batteryLevel,
        lastHeard: DateTime.now(),
        isOnline: true,
        role: role,
        avatarColor: existingNode.avatarColor,
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
        snr: nodeInfo.hasSnr() ? nodeInfo.snr.toInt() : null,
        batteryLevel: nodeInfo.hasDeviceMetrics()
            ? nodeInfo.deviceMetrics.batteryLevel
            : null,
        lastHeard: DateTime.now(),
        isOnline: true,
        role: role,
        avatarColor: avatarColor,
        isFavorite: false,
      );
    }

    _nodes[nodeInfo.num] = updatedNode;
    _nodeController.add(updatedNode);
  }

  /// Handle channel configuration
  void _handleChannel(pb.Channel channel) {
    _logger.i(
      'Channel ${channel.index} config received (role: ${channel.role.name})',
    );

    // Map protobuf role to string
    String roleStr;
    switch (channel.role) {
      case pb.Channel_Role.PRIMARY:
        roleStr = 'PRIMARY';
        break;
      case pb.Channel_Role.SECONDARY:
        roleStr = 'SECONDARY';
        break;
      case pb.Channel_Role.DISABLED:
      default:
        roleStr = 'DISABLED';
        break;
    }

    final channelConfig = ChannelConfig(
      index: channel.index,
      name: channel.hasSettings() ? channel.settings.name : '',
      psk: channel.hasSettings() ? channel.settings.psk : [],
      uplink: channel.hasSettings() ? channel.settings.uplinkEnabled : false,
      downlink: channel.hasSettings()
          ? channel.settings.downlinkEnabled
          : false,
      role: roleStr,
    );

    // Extend list if needed, but don't add dummy entries to stream
    while (_channels.length <= channel.index) {
      _channels.add(ChannelConfig(index: _channels.length, name: '', psk: []));
    }
    _channels[channel.index] = channelConfig;

    // Emit channel 0 (Primary), emit others only if they're not disabled
    if (channel.index == 0 || channel.role != pb.Channel_Role.DISABLED) {
      _channelController.add(channelConfig);
    }
  }

  /// Request configuration from device
  Future<void> _requestConfiguration() async {
    try {
      if (!_transport.isConnected) {
        _logger.w('Cannot request configuration: not connected');
        return;
      }

      _logger.i('Requesting device configuration');

      // Wake device by sending START2 bytes (only for serial/USB)
      if (_transport.requiresFraming) {
        final wakeBytes = List<int>.filled(32, 0xC3); // 32 START2 bytes
        await _transport.send(Uint8List.fromList(wakeBytes));
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Generate a config ID to track this request
      final configId = _random.nextInt(0x7FFFFFFF);

      // wantConfigId is a uint32 per official proto (not a bool!)
      final toRadio = pn.ToRadio()..wantConfigId = configId;
      final bytes = toRadio.writeToBuffer();

      // BLE uses raw protobufs, Serial/USB requires framing
      final sendBytes = _transport.requiresFraming
          ? PacketFramer.frame(bytes)
          : bytes;

      await _transport.send(sendBytes);
      _logger.i('Configuration request sent');
    } catch (e) {
      _logger.e('Error requesting configuration: $e');
    }
  }

  /// Send a text message
  /// Returns the packet ID for tracking delivery status
  Future<int> sendMessage({
    required String text,
    required int to,
    int channel = 0,
    bool wantAck = true,
    String? messageId,
  }) async {
    try {
      _logger.i('Sending message to $to: $text');

      final packetId = _generatePacketId();

      final data = pb.Data()
        ..portnum = pb.PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode(text)
        ..wantResponse = wantAck;

      final packet = pb.MeshPacket()
        ..from = _myNodeNum ?? 0
        ..to = to
        ..channel = channel
        ..decoded = data
        ..id = packetId
        ..wantAck = wantAck;

      final toRadio = pn.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));

      // Track the message for delivery status
      if (messageId != null && wantAck) {
        _pendingMessages[packetId] = messageId;
      }

      final message = Message(
        id: messageId,
        from: _myNodeNum ?? 0,
        to: to,
        text: text,
        channel: channel,
        sent: true,
        packetId: packetId,
        status: wantAck ? MessageStatus.pending : MessageStatus.sent,
      );

      _messageController.add(message);

      return packetId;
    } catch (e) {
      _logger.e('Error sending message: $e');
      rethrow;
    }
  }

  /// Generate a random packet ID
  int _generatePacketId() {
    return _random.nextInt(0x7FFFFFFF);
  }

  /// Prepare bytes for sending (frame if transport requires it)
  List<int> _prepareForSend(List<int> bytes) {
    return _transport.requiresFraming ? PacketFramer.frame(bytes) : bytes;
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

      await _transport.send(_prepareForSend(bytes));
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

      await _transport.send(_prepareForSend(bytes));
    } catch (e) {
      _logger.e('Error requesting node info: $e');
    }
  }

  /// Set channel
  Future<void> setChannel(ChannelConfig config) async {
    try {
      _logger.i(
        'Setting channel ${config.index}: ${config.name} (role: ${config.role})',
      );

      final channelSettings = pb.ChannelSettings()
        ..name = config.name
        ..psk = config.psk
        ..uplinkEnabled = config.uplink
        ..downlinkEnabled = config.downlink;

      // Determine channel role from config
      pb.Channel_Role role;
      switch (config.role.toUpperCase()) {
        case 'PRIMARY':
          role = pb.Channel_Role.PRIMARY;
          break;
        case 'SECONDARY':
          role = pb.Channel_Role.SECONDARY;
          break;
        case 'DISABLED':
        default:
          role = pb.Channel_Role.DISABLED;
          break;
      }

      final channel = pb.Channel()
        ..index = config.index
        ..settings = channelSettings
        ..role = role;

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

      await _transport.send(_prepareForSend(bytes));
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

      await _transport.send(_prepareForSend(bytes));
    } catch (e) {
      _logger.e('Error getting channel: $e');
    }
  }

  /// Set device role
  Future<void> setDeviceRole(pb.Config_DeviceConfig_Role role) async {
    try {
      _logger.i('Setting device role: ${role.name}');

      // Get current owner info and update role
      final user = pb.User()..role = role;

      final adminMsg = pb.AdminMessage()..setOwner = user;

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

      await _transport.send(_prepareForSend(bytes));
    } catch (e) {
      _logger.e('Error setting device role: $e');
      rethrow;
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _dataSubscription?.cancel();
    await _messageController.close();
    await _nodeController.close();
    await _channelController.close();
    await _errorController.close();
    await _deliveryController.close();
  }
}
