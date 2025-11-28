import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
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

  StreamSubscription<List<int>>? _dataSubscription;
  Completer<void>? _configCompleter;

  int? _myNodeNum;
  int _lastRssi = -90;
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
      _errorController = StreamController<DeviceError>.broadcast(),
      _myNodeNumController = StreamController<int>.broadcast(),
      _rssiController = StreamController<int>.broadcast();

  /// Stream of received messages
  Stream<Message> get messageStream => _messageController.stream;

  /// Stream of node updates
  Stream<MeshNode> get nodeStream => _nodeController.stream;

  /// Stream of channel updates
  Stream<ChannelConfig> get channelStream => _channelController.stream;

  /// Stream of RSSI updates
  Stream<int> get rssiStream => _rssiController.stream;

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
    debugPrint('🔔 Enabling fromNum notifications BEFORE config request...');
    await _transport.enableNotifications();
    debugPrint('🔔 Notifications enabled, now sending config request...');

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
    _logger.i('Future.any completed');

    if (!_configCompleter!.isCompleted) {
      _logger.i('Configuration not received, proceeding anyway');
      _configurationComplete = true;
      _configCompleter!.complete();
    } else {
      _logger.i('Configuration was received');
    }

    _logger.i('start() method completing');
  }

  /// Poll for configuration data in background (non-blocking)
  void _pollForConfigurationAsync() {
    debugPrint('🔁 Starting background polling for config response...');
    int pollCount = 0;
    const maxPolls = 100;

    Future.doWhile(() async {
      if (_configurationComplete || pollCount >= maxPolls) {
        debugPrint(
          '🔁 Stopping poll loop: configComplete=$_configurationComplete, polls=$pollCount',
        );
        return false; // Stop polling
      }

      try {
        await _transport.pollOnce();
        pollCount++;
        if (pollCount % 20 == 0) {
          debugPrint('🔁 Poll count: $pollCount/$maxPolls');
        }
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        debugPrint('🔁 Poll error: $e');
      }
      return true; // Continue polling
    });
  }

  /// Stop listening
  void stop() {
    _logger.i('Stopping protocol service');
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
    debugPrint(
      '📥 RAW DATA RECEIVED: ${data.length} bytes - ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );

    if (_transport.requiresFraming) {
      // Serial/USB: Extract packets using framer
      final packets = _framer.addData(data);
      debugPrint('📥 Framer extracted ${packets.length} complete packet(s)');

      if (packets.isEmpty) {
        debugPrint(
          '📥 WARNING: No complete packets extracted from ${data.length} bytes!',
        );
      }

      for (final packet in packets) {
        debugPrint(
          '📥 Processing packet ${packets.indexOf(packet) + 1}/${packets.length}',
        );
        _processPacket(packet);
      }
    } else {
      // BLE: Data is already a complete raw protobuf
      if (data.isNotEmpty) {
        debugPrint('📥 BLE: Processing raw protobuf (${data.length} bytes)');
        _processPacket(data);
      }
    }
  }

  /// Process a complete packet
  void _processPacket(List<int> packet) {
    try {
      _logger.d('Processing packet: ${packet.length} bytes');
      debugPrint(
        '📦 Processing packet: ${packet.length} bytes - ${packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );

      final fromRadio = pn.FromRadio.fromBuffer(packet);

      debugPrint(
        '📦 _processPacket: hasPacket=${fromRadio.hasPacket()}, hasMyInfo=${fromRadio.hasMyInfo()}, hasNodeInfo=${fromRadio.hasNodeInfo()}, hasChannel=${fromRadio.hasChannel()}, hasConfigCompleteId=${fromRadio.hasConfigCompleteId()}',
      );

      if (fromRadio.hasPacket()) {
        _handleMeshPacket(fromRadio.packet);
      } else if (fromRadio.hasMyInfo()) {
        _handleMyNodeInfo(fromRadio.myInfo);
      } else if (fromRadio.hasNodeInfo()) {
        _handleNodeInfo(fromRadio.nodeInfo);
      } else if (fromRadio.hasChannel()) {
        debugPrint('📦 HAS CHANNEL! Calling _handleChannel');
        _handleChannel(fromRadio.channel);
      } else if (fromRadio.hasConfigCompleteId()) {
        _logger.i('Configuration complete: ${fromRadio.configCompleteId}');
        debugPrint('📦 CONFIG COMPLETE ID received');
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

      // Track RSSI from incoming packets
      if (packet.hasRxSnr()) {
        _lastRssi = packet.rxSnr.toInt();
        _rssiController.add(_lastRssi);
      }

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

      // Track RSSI from incoming packets
      if (packet.hasRxSnr()) {
        _lastRssi = packet.rxSnr.toInt();
        _rssiController.add(_lastRssi);
      }

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
    debugPrint('📄 _handleMyNodeInfo: myNodeNum=$_myNodeNum');
    _myNodeNumController.add(_myNodeNum!);
  }

  /// Handle node info
  void _handleNodeInfo(pb.NodeInfo nodeInfo) {
    _logger.i('Node info received: ${nodeInfo.num}');
    debugPrint('📋 _handleNodeInfo START: nodeNum=${nodeInfo.num}');
    debugPrint(
      '📋   hasUser=${nodeInfo.hasUser()}, hasPosition=${nodeInfo.hasPosition()}, hasDeviceMetrics=${nodeInfo.hasDeviceMetrics()}',
    );

    if (nodeInfo.hasUser()) {
      debugPrint(
        '📋   longName="${nodeInfo.user.longName}", shortName="${nodeInfo.user.shortName}"',
      );
    }

    final existingNode = _nodes[nodeInfo.num];
    debugPrint('📋   existingNode=${existingNode != null ? 'EXISTS' : 'NEW'}');

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
    debugPrint(
      '📋   role=$role, avatarColor=0x${avatarColor.toRadixString(16)}',
    );

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
    debugPrint(
      '📋 _handleNodeInfo: Adding node ${nodeInfo.num} to stream. Total nodes: ${_nodes.length}',
    );
    _nodeController.add(updatedNode);
    debugPrint(
      '📋 _handleNodeInfo COMPLETE: Node ${nodeInfo.num} added successfully',
    );
  }

  /// Handle channel configuration
  void _handleChannel(pb.Channel channel) {
    _logger.i('Channel ${channel.index} config received');
    debugPrint(
      '📡 _handleChannel START: index=${channel.index}, hasSettings=${channel.hasSettings()}',
    );

    if (channel.hasSettings()) {
      debugPrint(
        '📡   settings.name="${channel.settings.name}", psk.length=${channel.settings.psk.length}',
      );
      debugPrint(
        '📡   uplinkEnabled=${channel.settings.uplinkEnabled}, downlinkEnabled=${channel.settings.downlinkEnabled}',
      );
    }

    final channelConfig = ChannelConfig(
      index: channel.index,
      name: channel.hasSettings() ? channel.settings.name : '',
      psk: channel.hasSettings() ? channel.settings.psk : [],
      uplink: channel.hasSettings() ? channel.settings.uplinkEnabled : false,
      downlink: channel.hasSettings()
          ? channel.settings.downlinkEnabled
          : false,
    );

    debugPrint(
      '📡 Created ChannelConfig: index=${channelConfig.index}, name="${channelConfig.name}", psk.length=${channelConfig.psk.length}',
    );

    // Extend list if needed, but don't add dummy entries to stream
    while (_channels.length <= channel.index) {
      _channels.add(ChannelConfig(index: _channels.length, name: '', psk: []));
    }
    _channels[channel.index] = channelConfig;
    debugPrint('📡 _channels list now has ${_channels.length} entries');

    // Always emit channel 0 (Primary), emit others only if they have names
    if (channel.index == 0 || channelConfig.name.isNotEmpty) {
      debugPrint('📡 Emitting channel ${channel.index} to stream');
      _channelController.add(channelConfig);
      debugPrint(
        '📡 _handleChannel COMPLETE: Channel ${channel.index} emitted to stream',
      );
    } else {
      debugPrint(
        '📡 NOT emitting channel ${channel.index} (empty name and not Primary)',
      );
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
        debugPrint('🚀 Waking device with START2 sequence (serial mode)...');
        final wakeBytes = List<int>.filled(32, 0xC3); // 32 START2 bytes
        await _transport.send(Uint8List.fromList(wakeBytes));
        debugPrint('🚀 Sent 32 START2 bytes to wake device');
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Generate a config ID to track this request
      final configId = _random.nextInt(0x7FFFFFFF);
      debugPrint('🚀 SENDING wantConfigId=$configId to device');

      // wantConfigId is a uint32 per official proto (not a bool!)
      final toRadio = pn.ToRadio()..wantConfigId = configId;
      final bytes = toRadio.writeToBuffer();
      debugPrint(
        '🚀 ToRadio protobuf size: ${bytes.length} bytes - ${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );

      // BLE uses raw protobufs, Serial/USB requires framing
      final sendBytes = _transport.requiresFraming
          ? PacketFramer.frame(bytes)
          : bytes;
      debugPrint(
        '🚀 Sending ${sendBytes.length} bytes (framed=${_transport.requiresFraming})',
      );

      await _transport.send(sendBytes);
      debugPrint('🚀 Configuration request SENT successfully');
      // Polling will be handled by background polling loop
    } catch (e) {
      _logger.e('Error requesting configuration: $e');
      debugPrint('🚀 ERROR sending config request: $e');
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

      await _transport.send(_prepareForSend(bytes));

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

  /// Dispose resources
  Future<void> dispose() async {
    await _dataSubscription?.cancel();
    await _messageController.close();
    await _nodeController.close();
    await _channelController.close();
    await _errorController.close();
  }
}
