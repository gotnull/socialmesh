import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../core/transport.dart';
import '../services/transport/ble_transport.dart';
import '../services/transport/usb_transport.dart';
import '../services/protocol/protocol_service.dart';
import '../services/storage/storage_service.dart';
import '../models/mesh_models.dart';

// Logger
final loggerProvider = Provider<Logger>((ref) {
  return Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );
});

// Storage services
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  final logger = ref.watch(loggerProvider);
  return SecureStorageService(logger: logger);
});

final settingsServiceProvider = FutureProvider<SettingsService>((ref) async {
  final logger = ref.watch(loggerProvider);
  final service = SettingsService(logger: logger);
  await service.init();
  return service;
});

// Message storage service
final messageStorageProvider = FutureProvider<MessageStorageService>((
  ref,
) async {
  final logger = ref.watch(loggerProvider);
  final service = MessageStorageService(logger: logger);
  await service.init();
  return service;
});

// Transport
final transportTypeProvider = StateProvider<TransportType>((ref) {
  return TransportType.ble;
});

final transportProvider = Provider<DeviceTransport>((ref) {
  final type = ref.watch(transportTypeProvider);
  final logger = ref.watch(loggerProvider);

  switch (type) {
    case TransportType.ble:
      return BleTransport(logger: logger);
    case TransportType.usb:
      return UsbTransport(logger: logger);
  }
});

// Connection state - create a stream that emits current state immediately,
// then listens for future updates. This fixes the issue where the dashboard
// subscribes after the state has already changed to connected.
final connectionStateProvider = StreamProvider<DeviceConnectionState>((
  ref,
) async* {
  final transport = ref.watch(transportProvider);

  // Immediately emit the current state
  yield transport.state;

  // Then emit all future state changes
  await for (final state in transport.stateStream) {
    yield state;
  }
});

// Currently connected device
final connectedDeviceProvider = StateProvider<DeviceInfo?>((ref) => null);

// Current RSSI stream from protocol service
final currentRssiProvider = StreamProvider<int>((ref) async* {
  final protocol = ref.watch(protocolServiceProvider);
  await for (final rssi in protocol.rssiStream) {
    yield rssi;
  }
});

// Protocol service - singleton instance that persists across rebuilds
final protocolServiceProvider = Provider<ProtocolService>((ref) {
  final transport = ref.watch(transportProvider);
  final logger = ref.watch(loggerProvider);
  final service = ProtocolService(transport, logger: logger);

  debugPrint(
    '🟢 ProtocolService provider created - instance: ${service.hashCode}',
  );

  // Keep the service alive for the lifetime of the app
  ref.onDispose(() {
    debugPrint(
      '🔴 ProtocolService being disposed - instance: ${service.hashCode}',
    );
    service.stop();
  });

  return service;
});

// Messages with persistence
class MessagesNotifier extends StateNotifier<List<Message>> {
  final ProtocolService _protocol;
  final MessageStorageService? _storage;

  MessagesNotifier(this._protocol, this._storage) : super([]) {
    _init();
  }

  Future<void> _init() async {
    // Load persisted messages
    if (_storage != null) {
      final savedMessages = await _storage.loadMessages();
      if (savedMessages.isNotEmpty) {
        state = savedMessages;
        debugPrint('📨 Loaded ${savedMessages.length} messages from storage');
      }
    }

    // Listen for new messages
    _protocol.messageStream.listen((message) {
      state = [...state, message];
      // Persist the new message
      _storage?.saveMessage(message);
    });
  }

  void addMessage(Message message) {
    state = [...state, message];
    _storage?.saveMessage(message);
  }

  void clearMessages() {
    state = [];
    _storage?.clearMessages();
  }

  List<Message> getMessagesForNode(int nodeNum) {
    return state.where((m) => m.from == nodeNum || m.to == nodeNum).toList();
  }
}

final messagesProvider = StateNotifierProvider<MessagesNotifier, List<Message>>(
  (ref) {
    final protocol = ref.watch(protocolServiceProvider);
    final storageAsync = ref.watch(messageStorageProvider);
    final storage = storageAsync.valueOrNull;
    return MessagesNotifier(protocol, storage);
  },
);

// Nodes
class NodesNotifier extends StateNotifier<Map<int, MeshNode>> {
  final ProtocolService _protocol;

  NodesNotifier(this._protocol) : super({}) {
    // Initialize with existing nodes from protocol service
    state = Map<int, MeshNode>.from(_protocol.nodes);

    _protocol.nodeStream.listen((node) {
      state = {...state, node.nodeNum: node};
    });
  }

  void addOrUpdateNode(MeshNode node) {
    state = {...state, node.nodeNum: node};
  }

  void removeNode(int nodeNum) {
    final newState = Map<int, MeshNode>.from(state);
    newState.remove(nodeNum);
    state = newState;
  }

  void clearNodes() {
    state = {};
  }
}

final nodesProvider = StateNotifierProvider<NodesNotifier, Map<int, MeshNode>>((
  ref,
) {
  final protocol = ref.watch(protocolServiceProvider);
  return NodesNotifier(protocol);
});

// Channels
class ChannelsNotifier extends StateNotifier<List<ChannelConfig>> {
  final ProtocolService _protocol;

  ChannelsNotifier(this._protocol) : super([]) {
    debugPrint(
      '🔵 ChannelsNotifier constructor - protocol has ${_protocol.channels.length} channels',
    );
    for (var c in _protocol.channels) {
      debugPrint(
        '  Channel ${c.index}: name="${c.name}", psk.length=${c.psk.length}',
      );
    }

    // Initialize with existing channels (include Primary even if name is empty)
    state = _protocol.channels
        .where((c) => c.index == 0 || c.name.isNotEmpty)
        .toList();
    debugPrint('🔵 ChannelsNotifier initialized with ${state.length} channels');

    // Listen for future channel updates
    _protocol.channelStream.listen((channel) {
      debugPrint(
        '🔵 ChannelsNotifier received channel update: index=${channel.index}, name="${channel.name}"',
      );
      final index = state.indexWhere((c) => c.index == channel.index);
      if (index >= 0) {
        debugPrint('  Updating existing channel at position $index');
        state = [
          ...state.sublist(0, index),
          channel,
          ...state.sublist(index + 1),
        ];
      } else {
        debugPrint('  Adding new channel');
        state = [...state, channel];
      }
      debugPrint('  Total channels now: ${state.length}');
    });
  }

  void setChannel(ChannelConfig channel) {
    final index = state.indexWhere((c) => c.index == channel.index);
    if (index >= 0) {
      state = [
        ...state.sublist(0, index),
        channel,
        ...state.sublist(index + 1),
      ];
    } else {
      state = [...state, channel];
    }
  }

  void clearChannels() {
    state = [];
  }
}

final channelsProvider =
    StateNotifierProvider<ChannelsNotifier, List<ChannelConfig>>((ref) {
      final protocol = ref.watch(protocolServiceProvider);
      return ChannelsNotifier(protocol);
    });

// My node number - updates when received from device
class MyNodeNumNotifier extends StateNotifier<int?> {
  final ProtocolService _protocol;

  MyNodeNumNotifier(this._protocol) : super(null) {
    // Initialize with existing myNodeNum from protocol service
    state = _protocol.myNodeNum;

    _protocol.myNodeNumStream.listen((nodeNum) {
      state = nodeNum;
    });
  }
}

final myNodeNumProvider = StateNotifierProvider<MyNodeNumNotifier, int?>((ref) {
  final protocol = ref.watch(protocolServiceProvider);
  return MyNodeNumNotifier(protocol);
});
