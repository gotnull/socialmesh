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

// Protocol service
final protocolServiceProvider = Provider<ProtocolService>((ref) {
  final transport = ref.watch(transportProvider);
  final logger = ref.watch(loggerProvider);
  return ProtocolService(transport, logger: logger);
});

// Messages
class MessagesNotifier extends StateNotifier<List<Message>> {
  final ProtocolService _protocol;

  MessagesNotifier(this._protocol) : super([]) {
    _protocol.messageStream.listen((message) {
      state = [...state, message];
    });
  }

  void addMessage(Message message) {
    state = [...state, message];
  }

  void clearMessages() {
    state = [];
  }

  List<Message> getMessagesForNode(int nodeNum) {
    return state.where((m) => m.from == nodeNum || m.to == nodeNum).toList();
  }
}

final messagesProvider = StateNotifierProvider<MessagesNotifier, List<Message>>(
  (ref) {
    final protocol = ref.watch(protocolServiceProvider);
    return MessagesNotifier(protocol);
  },
);

// Nodes
class NodesNotifier extends StateNotifier<Map<int, MeshNode>> {
  final ProtocolService _protocol;

  NodesNotifier(this._protocol) : super({}) {
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

  ChannelsNotifier(this._protocol) : super(_protocol.channels) {
    // Start with existing channels from protocol service
    _protocol.channelStream.listen((channel) {
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
    _protocol.myNodeNumStream.listen((nodeNum) {
      state = nodeNum;
    });
  }
}

final myNodeNumProvider = StateNotifierProvider<MyNodeNumNotifier, int?>((ref) {
  final protocol = ref.watch(protocolServiceProvider);
  return MyNodeNumNotifier(protocol);
});
