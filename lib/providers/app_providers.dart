import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../core/transport.dart';
import '../services/transport/ble_transport.dart';
import '../services/transport/usb_transport.dart';
import '../services/protocol/protocol_service.dart';
import '../services/storage/storage_service.dart';
import '../services/notifications/notification_service.dart';
import '../models/mesh_models.dart';
import '../generated/meshtastic/mesh.pbenum.dart' as pbenum;

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

// App initialization state
enum AppInitState {
  uninitialized,
  initializing,
  initialized,
  needsOnboarding,
  error,
}

class AppInitNotifier extends StateNotifier<AppInitState> {
  final Ref _ref;

  AppInitNotifier(this._ref) : super(AppInitState.uninitialized);

  Future<void> initialize() async {
    if (state == AppInitState.initializing) return;

    state = AppInitState.initializing;
    try {
      // Initialize notification service
      await NotificationService().initialize();

      // Initialize storage services
      await _ref.read(settingsServiceProvider.future);
      await _ref.read(messageStorageProvider.future);

      // Check for onboarding completion
      final settings = await _ref.read(settingsServiceProvider.future);
      if (!settings.onboardingComplete) {
        state = AppInitState.needsOnboarding;
        return;
      }

      // Check for auto-reconnect settings
      final lastDeviceId = settings.lastDeviceId;
      final shouldAutoReconnect = settings.autoReconnect;

      if (lastDeviceId != null && shouldAutoReconnect) {
        _ref.read(autoReconnectStateProvider.notifier).state =
            AutoReconnectState.scanning;

        final transport = _ref.read(transportProvider);
        try {
          DeviceInfo? lastDevice;

          // Scan for devices and try to find the last connected one
          await for (final device in transport.scan(
            timeout: const Duration(seconds: 5),
          )) {
            if (device.id == lastDeviceId) {
              lastDevice = device;
              break;
            }
          }

          if (lastDevice != null) {
            _ref.read(autoReconnectStateProvider.notifier).state =
                AutoReconnectState.connecting;
            await transport.connect(lastDevice);

            // Start protocol service
            final protocol = _ref.read(protocolServiceProvider);
            await protocol.start();

            _ref.read(connectedDeviceProvider.notifier).state = lastDevice;
            _ref.read(autoReconnectStateProvider.notifier).state =
                AutoReconnectState.success;
          } else {
            _ref.read(autoReconnectStateProvider.notifier).state =
                AutoReconnectState.idle;
          }
        } catch (e) {
          debugPrint('Auto-reconnect failed: $e');
          _ref.read(autoReconnectStateProvider.notifier).state =
              AutoReconnectState.failed;
        }
      }

      state = AppInitState.initialized;
    } catch (e) {
      debugPrint('App initialization failed: $e');
      state = AppInitState.error;
    }
  }
}

final appInitProvider = StateNotifierProvider<AppInitNotifier, AppInitState>((
  ref,
) {
  return AppInitNotifier(ref);
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

// Auto-reconnect state
enum AutoReconnectState { idle, scanning, connecting, failed, success }

final autoReconnectStateProvider = StateProvider<AutoReconnectState>((ref) {
  return AutoReconnectState.idle;
});

// Auto-reconnect manager - monitors connection and attempts to reconnect on unexpected disconnect
final autoReconnectManagerProvider = Provider<void>((ref) {
  final connectionState = ref.watch(connectionStateProvider);
  final connectedDevice = ref.watch(connectedDeviceProvider);
  final autoReconnectState = ref.watch(autoReconnectStateProvider);

  connectionState.whenData((state) async {
    // If we were connected and now disconnected, try to reconnect
    if (state == DeviceConnectionState.disconnected &&
        connectedDevice != null &&
        autoReconnectState == AutoReconnectState.idle) {
      debugPrint(
        '🔄 Device disconnected unexpectedly, attempting to reconnect...',
      );

      // Wait a bit before attempting reconnect (device might be rebooting)
      await Future.delayed(const Duration(seconds: 2));

      // Check settings for auto-reconnect preference
      final settings = await ref.read(settingsServiceProvider.future);
      if (!settings.autoReconnect) {
        debugPrint('🔄 Auto-reconnect disabled in settings');
        return;
      }

      // Start reconnection attempt
      ref.read(autoReconnectStateProvider.notifier).state =
          AutoReconnectState.scanning;

      final transport = ref.read(transportProvider);
      final lastDeviceId = connectedDevice.id;

      try {
        DeviceInfo? foundDevice;

        // Scan for the device
        await for (final device in transport.scan(
          timeout: const Duration(seconds: 10),
        )) {
          if (device.id == lastDeviceId) {
            foundDevice = device;
            break;
          }
        }

        if (foundDevice != null) {
          ref.read(autoReconnectStateProvider.notifier).state =
              AutoReconnectState.connecting;
          await transport.connect(foundDevice);

          // Restart protocol service
          final protocol = ref.read(protocolServiceProvider);
          await protocol.start();

          ref.read(autoReconnectStateProvider.notifier).state =
              AutoReconnectState.success;
          debugPrint('🔄 Reconnection successful!');

          // Reset to idle after showing success
          await Future.delayed(const Duration(seconds: 2));
          ref.read(autoReconnectStateProvider.notifier).state =
              AutoReconnectState.idle;
        } else {
          debugPrint('🔄 Device not found during scan');
          ref.read(autoReconnectStateProvider.notifier).state =
              AutoReconnectState.failed;

          // Clear connected device since we couldn't reconnect
          ref.read(connectedDeviceProvider.notifier).state = null;

          // Reset to idle after showing failure
          await Future.delayed(const Duration(seconds: 3));
          ref.read(autoReconnectStateProvider.notifier).state =
              AutoReconnectState.idle;
        }
      } catch (e) {
        debugPrint('🔄 Reconnection failed: $e');
        ref.read(autoReconnectStateProvider.notifier).state =
            AutoReconnectState.failed;

        // Reset to idle after showing failure
        await Future.delayed(const Duration(seconds: 3));
        ref.read(autoReconnectStateProvider.notifier).state =
            AutoReconnectState.idle;
      }
    }
  });
});

// Current RSSI stream from protocol service
final currentRssiProvider = StreamProvider<int>((ref) async* {
  final protocol = ref.watch(protocolServiceProvider);
  await for (final rssi in protocol.rssiStream) {
    yield rssi;
  }
});

// Current SNR (Signal-to-Noise Ratio) stream from protocol service
final currentSnrProvider = StreamProvider<double>((ref) async* {
  final protocol = ref.watch(protocolServiceProvider);
  await for (final snr in protocol.snrStream) {
    yield snr;
  }
});

// Current channel utilization stream from protocol service
final currentChannelUtilProvider = StreamProvider<double>((ref) async* {
  final protocol = ref.watch(protocolServiceProvider);
  await for (final util in protocol.channelUtilStream) {
    yield util;
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
  final Ref _ref;
  final Map<int, String> _packetToMessageId = {};

  MessagesNotifier(this._protocol, this._storage, this._ref) : super([]) {
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
      // Skip sent messages - they're handled via optimistic UI in messaging_screen
      if (message.sent) {
        return;
      }
      state = [...state, message];
      // Persist the new message
      _storage?.saveMessage(message);

      // Trigger notification for received messages
      _notifyNewMessage(message);
    });

    // Listen for delivery status updates
    _protocol.deliveryStream.listen(_handleDeliveryUpdate);
  }

  void _notifyNewMessage(Message message) {
    debugPrint('🔔 _notifyNewMessage called for message from ${message.from}');

    // Check master notification toggle
    final settingsAsync = _ref.read(settingsServiceProvider);
    final settings = settingsAsync.valueOrNull;
    if (settings == null) {
      debugPrint('🔔 Settings not available, skipping notification');
      return;
    }
    if (!settings.notificationsEnabled) {
      debugPrint('🔔 Notifications disabled in settings');
      return;
    }

    // Get sender name from nodes
    final nodes = _ref.read(nodesProvider);
    final senderNode = nodes[message.from];
    final senderName = senderNode?.displayName ?? 'Unknown';
    debugPrint('🔔 Sender: $senderName');

    // Check if it's a channel message or direct message
    final isChannelMessage = message.channel != null && message.channel! > 0;
    debugPrint(
      '🔔 Is channel message: $isChannelMessage (channel: ${message.channel})',
    );

    if (isChannelMessage) {
      // Check channel message setting
      if (!settings.channelMessageNotificationsEnabled) {
        debugPrint('🔔 Channel notifications disabled');
        return;
      }

      // Channel message notification
      final channels = _ref.read(channelsProvider);
      final channel = channels
          .where((c) => c.index == message.channel)
          .firstOrNull;
      final channelName = channel?.name ?? 'Channel ${message.channel}';

      debugPrint(
        '🔔 Showing channel notification: $senderName in $channelName',
      );
      NotificationService().showChannelMessageNotification(
        senderName: senderName,
        channelName: channelName,
        message: message.text,
        channelIndex: message.channel!,
        playSound: settings.notificationSoundEnabled,
        vibrate: settings.notificationVibrationEnabled,
      );
    } else {
      // Check direct message setting
      if (!settings.directMessageNotificationsEnabled) {
        debugPrint('🔔 DM notifications disabled');
        return;
      }

      // Direct message notification
      debugPrint('🔔 Showing DM notification from: $senderName');
      NotificationService().showNewMessageNotification(
        senderName: senderName,
        message: message.text,
        fromNodeNum: message.from,
        playSound: settings.notificationSoundEnabled,
        vibrate: settings.notificationVibrationEnabled,
      );
    }
  }

  void _handleDeliveryUpdate(MessageDeliveryUpdate update) {
    final messageId = _packetToMessageId[update.packetId];
    if (messageId == null) {
      debugPrint('📨 Delivery update for unknown packet ${update.packetId}');
      return;
    }

    final messageIndex = state.indexWhere((m) => m.id == messageId);
    if (messageIndex == -1) {
      debugPrint('📨 Delivery update for message not in state: $messageId');
      return;
    }

    final message = state[messageIndex];
    final updatedMessage = message.copyWith(
      status: update.isSuccess ? MessageStatus.delivered : MessageStatus.failed,
      routingError: update.error,
      errorMessage: update.error?.message,
    );

    state = [
      ...state.sublist(0, messageIndex),
      updatedMessage,
      ...state.sublist(messageIndex + 1),
    ];
    _storage?.saveMessage(updatedMessage);

    debugPrint(
      '📨 Message ${update.isSuccess ? "delivered" : "failed"}: $messageId'
      '${update.error != null ? " - ${update.error!.message}" : ""}',
    );
  }

  void trackPacket(int packetId, String messageId) {
    _packetToMessageId[packetId] = messageId;
  }

  void addMessage(Message message) {
    // Check for duplicate by ID to prevent optimistic UI + stream double-add
    if (state.any((m) => m.id == message.id)) {
      return;
    }
    state = [...state, message];
    _storage?.saveMessage(message);
  }

  void updateMessage(String messageId, Message updatedMessage) {
    state = state.map((m) => m.id == messageId ? updatedMessage : m).toList();
    _storage?.saveMessage(updatedMessage);
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
    return MessagesNotifier(protocol, storage, ref);
  },
);

// Nodes
class NodesNotifier extends StateNotifier<Map<int, MeshNode>> {
  final ProtocolService _protocol;
  final Ref _ref;

  NodesNotifier(this._protocol, this._ref) : super({}) {
    // Initialize with existing nodes from protocol service
    state = Map<int, MeshNode>.from(_protocol.nodes);

    _protocol.nodeStream.listen((node) {
      final isNewNode = !state.containsKey(node.nodeNum);
      state = {...state, node.nodeNum: node};

      // Increment new nodes counter if this is a genuinely new node
      if (isNewNode) {
        _ref.read(newNodesCountProvider.notifier).state++;
        // Trigger notification for new node discovery
        _ref.read(nodeDiscoveryNotifierProvider.notifier).notifyNewNode(node);
      }
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
  return NodesNotifier(protocol, ref);
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

    // Initialize with existing channels (include Primary, exclude DISABLED)
    state = _protocol.channels
        .where((c) => c.index == 0 || c.role != 'DISABLED')
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

  void removeChannel(int channelIndex) {
    state = state.where((c) => c.index != channelIndex).toList();
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

/// Unread messages count provider
/// Returns the count of messages that were received from other nodes
/// and not yet read (messages where received=true and from != myNodeNum)
final unreadMessagesCountProvider = Provider<int>((ref) {
  final messages = ref.watch(messagesProvider);
  final myNodeNum = ref.watch(myNodeNumProvider);

  if (myNodeNum == null) return 0;

  return messages.where((m) => m.received && m.from != myNodeNum).length;
});

/// Has unread messages provider - simple boolean check
final hasUnreadMessagesProvider = Provider<bool>((ref) {
  return ref.watch(unreadMessagesCountProvider) > 0;
});

/// New nodes count - tracks number of newly discovered nodes since last check
/// Reset when user views the Nodes tab
final newNodesCountProvider = StateProvider<int>((ref) => 0);

/// Node discovery notifier - triggers notifications when new nodes are found
class NodeDiscoveryNotifier extends StateNotifier<MeshNode?> {
  final NotificationService _notificationService;
  final Ref _ref;

  NodeDiscoveryNotifier(this._notificationService, this._ref) : super(null);

  Future<void> notifyNewNode(MeshNode node) async {
    // Check master notification toggle and new node setting
    final settingsAsync = _ref.read(settingsServiceProvider);
    final settings = settingsAsync.valueOrNull;
    if (settings == null) return;
    if (!settings.notificationsEnabled) return;
    if (!settings.newNodeNotificationsEnabled) return;

    state = node;
    await _notificationService.showNewNodeNotification(
      node,
      playSound: settings.notificationSoundEnabled,
      vibrate: settings.notificationVibrationEnabled,
    );
  }
}

final nodeDiscoveryNotifierProvider =
    StateNotifierProvider<NodeDiscoveryNotifier, MeshNode?>((ref) {
      return NodeDiscoveryNotifier(NotificationService(), ref);
    });

/// Current device region - stream that emits region updates
final deviceRegionProvider = StreamProvider<pbenum.RegionCode>((ref) async* {
  final protocol = ref.watch(protocolServiceProvider);

  // Emit current region if available
  if (protocol.currentRegion != null) {
    yield protocol.currentRegion!;
  }

  // Emit future updates
  await for (final region in protocol.regionStream) {
    yield region;
  }
});

/// Needs region setup - true if region is UNSET
final needsRegionSetupProvider = Provider<bool>((ref) {
  final regionAsync = ref.watch(deviceRegionProvider);
  return regionAsync.whenOrNull(
        data: (region) => region == pbenum.RegionCode.UNSET_REGION,
      ) ??
      false;
});
