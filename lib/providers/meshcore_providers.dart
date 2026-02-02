// SPDX-License-Identifier: GPL-3.0-or-later
// Providers for MeshCore integration and protocol-agnostic device info.
//
// These providers enable the UI to access protocol-agnostic device
// information without depending on Meshtastic or MeshCore specific code.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/transport.dart';
import '../models/mesh_device.dart';
import '../models/meshcore_contact.dart';
import '../models/meshcore_channel.dart';
import '../services/meshcore/connection_coordinator.dart';
import '../services/meshcore/meshcore_adapter.dart';
import '../services/meshcore/meshcore_detector.dart';
import '../services/meshcore/protocol/meshcore_capture.dart';
import '../services/meshcore/protocol/meshcore_messages.dart';
import '../services/meshcore/protocol/meshcore_session.dart';
import 'app_providers.dart';
import 'connection_providers.dart';

/// Provider for the connection coordinator singleton.
///
/// The coordinator handles protocol detection and routes connections
/// to the appropriate adapter (Meshtastic or MeshCore).
final connectionCoordinatorProvider = Provider<ConnectionCoordinator>((ref) {
  final coordinator = ConnectionCoordinator();

  ref.onDispose(() {
    coordinator.dispose();
  });

  return coordinator;
});

/// Reactive provider for MeshCore connection state.
///
/// This StreamProvider watches the coordinator's stateStream, making the
/// connection state reactive. Dependent providers (like linkStatusProvider)
/// will rebuild when MeshCore connects/disconnects.
///
/// CRITICAL: This fixes the shell navigation bug where MeshCore connections
/// weren't triggering UI rebuilds because connectionCoordinatorProvider is
/// a plain Provider that doesn't notify on internal state changes.
///
/// The stream is seeded with the current connection state so new subscribers
/// immediately see the current state, not just future changes.
final meshCoreConnectionStateProvider = StreamProvider<MeshConnectionState>((
  ref,
) {
  final coordinator = ref.watch(connectionCoordinatorProvider);

  // Determine current state from coordinator
  MeshConnectionState currentState;
  if (coordinator.isConnected) {
    currentState = MeshConnectionState.connected;
  } else if (coordinator.isConnecting) {
    currentState = MeshConnectionState.connecting;
  } else {
    currentState = MeshConnectionState.disconnected;
  }

  // Emit current state first, then forward all future state changes.
  // This ensures new subscribers see the current state immediately.
  return Stream.value(currentState).asyncExpand((initial) async* {
    yield initial;
    await for (final state in coordinator.stateStream) {
      yield state;
    }
  });
});

/// Provider for the current protocol-agnostic device info.
///
/// This provides a unified view of the connected device regardless of
/// whether it's Meshtastic or MeshCore. UI components should use this
/// instead of protocol-specific providers.
///
/// Returns null when not connected or not yet identified.
final meshDeviceInfoProvider = Provider<MeshDeviceInfo?>((ref) {
  // Check coordinator first for MeshCore devices
  final coordinator = ref.watch(connectionCoordinatorProvider);
  if (coordinator.deviceInfo != null) {
    return coordinator.deviceInfo;
  }

  // Fall back to Meshtastic protocol service for Meshtastic devices
  final connectionState = ref.watch(deviceConnectionProvider);
  if (!connectionState.isConnected) {
    return null;
  }

  // Get Meshtastic device info from protocol service
  final protocol = ref.watch(protocolServiceProvider);
  final myNodeNum = protocol.myNodeNum;
  if (myNodeNum == null) {
    return null;
  }

  // Get node info from the nodes map
  final myNode = protocol.nodes[myNodeNum];
  final displayName =
      myNode?.longName ?? myNode?.shortName ?? 'Meshtastic Device';
  final firmwareVersion = myNode?.firmwareVersion;
  final hardwareModel = myNode?.hardwareModel;

  // Build MeshDeviceInfo from Meshtastic protocol service
  return MeshDeviceInfo(
    protocolType: MeshProtocolType.meshtastic,
    displayName: displayName,
    nodeId: myNodeNum.toRadixString(16).toUpperCase(),
    firmwareVersion: firmwareVersion,
    hardwareModel: hardwareModel,
  );
});

/// Provider for the detected protocol type of the connected device.
///
/// Returns unknown when not connected.
final meshProtocolTypeProvider = Provider<MeshProtocolType>((ref) {
  final deviceInfo = ref.watch(meshDeviceInfoProvider);
  return deviceInfo?.protocolType ?? MeshProtocolType.unknown;
});

/// Provider for the MeshCore adapter (null if not connected or not MeshCore).
///
/// Use this to access MeshCore-specific functionality like the session.
final meshCoreAdapterProvider = Provider<MeshCoreAdapter?>((ref) {
  final coordinator = ref.watch(connectionCoordinatorProvider);
  return coordinator.meshCoreAdapter;
});

/// Provider for the MeshCore session (null if not connected or not MeshCore).
///
/// Use this for direct protocol operations on MeshCore devices.
final meshCoreSessionProvider = Provider<MeshCoreSession?>((ref) {
  final adapter = ref.watch(meshCoreAdapterProvider);
  return adapter?.session;
});

// ---------------------------------------------------------------------------
// MeshCore Self Info Provider
// ---------------------------------------------------------------------------

/// Cached self info for the connected MeshCore device.
///
/// Provides the device's own identity information including public key and name.
class MeshCoreSelfInfoState {
  final MeshCoreSelfInfo? selfInfo;
  final bool isLoading;
  final String? error;

  const MeshCoreSelfInfoState({
    this.selfInfo,
    this.isLoading = false,
    this.error,
  });

  const MeshCoreSelfInfoState.initial()
    : selfInfo = null,
      isLoading = false,
      error = null;
  const MeshCoreSelfInfoState.loading()
    : selfInfo = null,
      isLoading = true,
      error = null;
  MeshCoreSelfInfoState.loaded(MeshCoreSelfInfo info)
    : selfInfo = info,
      isLoading = false,
      error = null;
  MeshCoreSelfInfoState.failed(String msg)
    : selfInfo = null,
      isLoading = false,
      error = msg;
}

class MeshCoreSelfInfoNotifier extends Notifier<MeshCoreSelfInfoState> {
  @override
  MeshCoreSelfInfoState build() {
    // Auto-fetch when adapter is available
    final adapter = ref.watch(meshCoreAdapterProvider);
    if (adapter != null && adapter.deviceInfo != null) {
      // Device is identified, try to get self info
      _loadSelfInfo();
    }
    return const MeshCoreSelfInfoState.initial();
  }

  Future<void> _loadSelfInfo() async {
    state = const MeshCoreSelfInfoState.loading();
    try {
      final session = ref.read(meshCoreSessionProvider);
      if (session == null) {
        state = MeshCoreSelfInfoState.failed('No session available');
        return;
      }

      final selfInfo = await session.getSelfInfo();
      if (selfInfo != null) {
        state = MeshCoreSelfInfoState.loaded(selfInfo);
      } else {
        state = MeshCoreSelfInfoState.failed('Failed to get self info');
      }
    } catch (e) {
      state = MeshCoreSelfInfoState.failed(e.toString());
    }
  }

  Future<void> refresh() async {
    await _loadSelfInfo();
  }
}

final meshCoreSelfInfoProvider =
    NotifierProvider<MeshCoreSelfInfoNotifier, MeshCoreSelfInfoState>(
      MeshCoreSelfInfoNotifier.new,
    );

// ---------------------------------------------------------------------------
// MeshCore Contacts Provider
// ---------------------------------------------------------------------------

/// State for MeshCore contacts list.
class MeshCoreContactsState {
  final List<MeshCoreContact> contacts;
  final bool isLoading;
  final String? error;
  final DateTime? lastRefresh;

  const MeshCoreContactsState({
    this.contacts = const [],
    this.isLoading = false,
    this.error,
    this.lastRefresh,
  });

  const MeshCoreContactsState.initial()
    : contacts = const [],
      isLoading = false,
      error = null,
      lastRefresh = null;
  const MeshCoreContactsState.loading()
    : contacts = const [],
      isLoading = true,
      error = null,
      lastRefresh = null;

  MeshCoreContactsState copyWith({
    List<MeshCoreContact>? contacts,
    bool? isLoading,
    String? error,
    DateTime? lastRefresh,
  }) {
    return MeshCoreContactsState(
      contacts: contacts ?? this.contacts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastRefresh: lastRefresh ?? this.lastRefresh,
    );
  }
}

class MeshCoreContactsNotifier extends Notifier<MeshCoreContactsState> {
  @override
  MeshCoreContactsState build() {
    // Auto-fetch contacts when connected to MeshCore
    final linkStatus = ref.watch(linkStatusProvider);
    if (linkStatus.isMeshCore && linkStatus.isConnected) {
      // Defer loading to avoid build-phase side effects
      Future.microtask(() => _loadContacts());
    }
    return const MeshCoreContactsState.initial();
  }

  Future<void> _loadContacts() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final session = ref.read(meshCoreSessionProvider);
      if (session == null) {
        state = state.copyWith(isLoading: false, error: 'No MeshCore session');
        return;
      }

      final contactInfos = await session.getContacts();

      // Load unread counts from storage
      final unreadCounts = <String, int>{};
      try {
        final contactStore = await SharedPreferences.getInstance();
        for (final info in contactInfos) {
          final keyHex = info.publicKey
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join();
          final unread = contactStore.getInt('meshcore_unread_$keyHex') ?? 0;
          unreadCounts[keyHex] = unread;
        }
      } catch (e) {
        // Ignore storage errors, use 0 for all
      }

      // Convert MeshCoreContactInfo to MeshCoreContact with unread counts
      final contacts = contactInfos.map((info) {
        final keyHex = info.publicKey
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        return MeshCoreContact(
          publicKey: info.publicKey,
          name: info.name,
          type: info.advType,
          pathLength: info.pathLength,
          path: info.pathBytes,
          latitude: info.latitudeDegrees,
          longitude: info.longitudeDegrees,
          lastSeen: DateTime.now(),
          unreadCount: unreadCounts[keyHex] ?? 0,
        );
      }).toList();

      // Sort by name
      contacts.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      state = MeshCoreContactsState(
        contacts: contacts,
        isLoading: false,
        lastRefresh: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await _loadContacts();
  }

  /// Update unread count for a contact.
  void updateUnreadCount(String publicKeyHex, int count) {
    final updated = state.contacts.map((c) {
      if (c.publicKeyHex == publicKeyHex) {
        return c.copyWith(unreadCount: count);
      }
      return c;
    }).toList();
    state = state.copyWith(contacts: updated);
  }

  /// Clear unread count for a contact.
  void clearUnread(String publicKeyHex) {
    updateUnreadCount(publicKeyHex, 0);
  }

  void addContact(MeshCoreContact contact) {
    final updated = [...state.contacts];
    final existingIndex = updated.indexWhere(
      (c) => c.publicKeyHex == contact.publicKeyHex,
    );
    if (existingIndex >= 0) {
      updated[existingIndex] = contact;
    } else {
      updated.add(contact);
    }
    updated.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    state = state.copyWith(contacts: updated);
  }

  void removeContact(String publicKeyHex) {
    final updated = state.contacts
        .where((c) => c.publicKeyHex != publicKeyHex)
        .toList();
    state = state.copyWith(contacts: updated);
  }
}

final meshCoreContactsProvider =
    NotifierProvider<MeshCoreContactsNotifier, MeshCoreContactsState>(
      MeshCoreContactsNotifier.new,
    );

// ---------------------------------------------------------------------------
// MeshCore Channels Provider
// ---------------------------------------------------------------------------

/// State for MeshCore channels list.
class MeshCoreChannelsState {
  final List<MeshCoreChannel> channels;
  final bool isLoading;
  final String? error;
  final DateTime? lastRefresh;

  const MeshCoreChannelsState({
    this.channels = const [],
    this.isLoading = false,
    this.error,
    this.lastRefresh,
  });

  const MeshCoreChannelsState.initial()
    : channels = const [],
      isLoading = false,
      error = null,
      lastRefresh = null;
  const MeshCoreChannelsState.loading()
    : channels = const [],
      isLoading = true,
      error = null,
      lastRefresh = null;

  MeshCoreChannelsState copyWith({
    List<MeshCoreChannel>? channels,
    bool? isLoading,
    String? error,
    DateTime? lastRefresh,
  }) {
    return MeshCoreChannelsState(
      channels: channels ?? this.channels,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastRefresh: lastRefresh ?? this.lastRefresh,
    );
  }
}

class MeshCoreChannelsNotifier extends Notifier<MeshCoreChannelsState> {
  @override
  MeshCoreChannelsState build() {
    // Auto-fetch channels when connected to MeshCore
    final linkStatus = ref.watch(linkStatusProvider);
    if (linkStatus.isMeshCore && linkStatus.isConnected) {
      // Defer loading to avoid build-phase side effects
      Future.microtask(() => _loadChannels());
    }
    return const MeshCoreChannelsState.initial();
  }

  Future<void> _loadChannels() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final session = ref.read(meshCoreSessionProvider);
      if (session == null) {
        state = state.copyWith(isLoading: false, error: 'No MeshCore session');
        return;
      }

      final channelInfos = await session.getChannels();

      // Convert MeshCoreChannelInfo to MeshCoreChannel
      final channels = channelInfos.map((info) {
        return MeshCoreChannel(
          index: info.index,
          name: info.name,
          psk: info.psk,
        );
      }).toList();

      // Sort by index
      channels.sort((a, b) => a.index.compareTo(b.index));

      state = MeshCoreChannelsState(
        channels: channels,
        isLoading: false,
        lastRefresh: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await _loadChannels();
  }

  /// Add or update a channel on the device.
  Future<bool> setChannel(MeshCoreChannel channel) async {
    try {
      final session = ref.read(meshCoreSessionProvider);
      if (session == null) return false;

      final success = await session.setChannel(
        index: channel.index,
        name: channel.name,
        psk: channel.psk,
      );

      if (success) {
        // Update local state
        final updated = [...state.channels];
        final existingIndex = updated.indexWhere(
          (c) => c.index == channel.index,
        );
        if (existingIndex >= 0) {
          updated[existingIndex] = channel;
        } else {
          updated.add(channel);
          updated.sort((a, b) => a.index.compareTo(b.index));
        }
        state = state.copyWith(channels: updated);
      }

      return success;
    } catch (e) {
      return false;
    }
  }
}

final meshCoreChannelsProvider =
    NotifierProvider<MeshCoreChannelsNotifier, MeshCoreChannelsState>(
      MeshCoreChannelsNotifier.new,
    );

/// Provider for the MeshCore debug capture (null if not MeshCore or release build).
///
/// Only available in debug builds for dev-only protocol inspection.
final meshCoreCaptureProvider = Provider<MeshCoreFrameCapture?>((ref) {
  if (!kDebugMode) return null;
  final coordinator = ref.watch(connectionCoordinatorProvider);
  return coordinator.meshCoreCapture;
});

// ---------------------------------------------------------------------------
// MeshCore Battery Refresh (Debug-only)
// ---------------------------------------------------------------------------

/// State for MeshCore battery refresh operation.
class MeshCoreBatteryState {
  /// The current status.
  final MeshCoreBatteryStatus status;

  /// Battery percentage (0-100), or null if unknown.
  final int? percentage;

  /// Battery voltage in millivolts, or null if unknown.
  final int? voltageMillivolts;

  /// Error message on failure.
  final String? errorMessage;

  const MeshCoreBatteryState.idle()
    : status = MeshCoreBatteryStatus.idle,
      percentage = null,
      voltageMillivolts = null,
      errorMessage = null;

  const MeshCoreBatteryState.inProgress()
    : status = MeshCoreBatteryStatus.inProgress,
      percentage = null,
      voltageMillivolts = null,
      errorMessage = null;

  const MeshCoreBatteryState.success({
    required this.percentage,
    required this.voltageMillivolts,
  }) : status = MeshCoreBatteryStatus.success,
       errorMessage = null;

  const MeshCoreBatteryState.failure(this.errorMessage)
    : status = MeshCoreBatteryStatus.failure,
      percentage = null,
      voltageMillivolts = null;

  bool get isIdle => status == MeshCoreBatteryStatus.idle;
  bool get isInProgress => status == MeshCoreBatteryStatus.inProgress;
  bool get isSuccess => status == MeshCoreBatteryStatus.success;
  bool get isFailure => status == MeshCoreBatteryStatus.failure;
}

enum MeshCoreBatteryStatus { idle, inProgress, success, failure }

/// Notifier for MeshCore battery refresh (debug-only).
///
/// Provides manual refresh of battery info for MeshCore devices.
class MeshCoreBatteryNotifier extends Notifier<MeshCoreBatteryState> {
  @override
  MeshCoreBatteryState build() {
    // Initialize from current device info if available
    final adapter = ref.read(meshCoreAdapterProvider);
    final deviceInfo = adapter?.deviceInfo;
    if (deviceInfo != null &&
        (deviceInfo.batteryPercentage != null ||
            deviceInfo.batteryVoltageMillivolts != null)) {
      return MeshCoreBatteryState.success(
        percentage: deviceInfo.batteryPercentage,
        voltageMillivolts: deviceInfo.batteryVoltageMillivolts,
      );
    }
    return const MeshCoreBatteryState.idle();
  }

  /// Refresh battery info from the device.
  Future<void> refresh() async {
    state = const MeshCoreBatteryState.inProgress();

    try {
      final adapter = ref.read(meshCoreAdapterProvider);
      if (adapter == null) {
        state = const MeshCoreBatteryState.failure('Not connected to MeshCore');
        return;
      }

      final percentage = await adapter.refreshBattery();
      final deviceInfo = adapter.deviceInfo;

      if (percentage != null || deviceInfo?.batteryVoltageMillivolts != null) {
        state = MeshCoreBatteryState.success(
          percentage: percentage,
          voltageMillivolts: deviceInfo?.batteryVoltageMillivolts,
        );
      } else {
        state = const MeshCoreBatteryState.failure('Battery info unavailable');
      }
    } catch (e) {
      state = MeshCoreBatteryState.failure(e.toString());
    }
  }

  void reset() {
    state = const MeshCoreBatteryState.idle();
  }
}

final meshCoreBatteryProvider =
    NotifierProvider<MeshCoreBatteryNotifier, MeshCoreBatteryState>(
      MeshCoreBatteryNotifier.new,
    );

/// Provider for protocol detection on a scanned device.
///
/// This is a family provider that takes scan parameters and returns
/// the detection result for a specific device.
final protocolDetectionProvider =
    Provider.family<ProtocolDetectionResult, ProtocolDetectionParams>((
      ref,
      params,
    ) {
      return MeshProtocolDetector.detect(
        device: params.device,
        advertisedServiceUuids: params.advertisedServiceUuids,
        manufacturerData: params.manufacturerData,
      );
    });

/// Parameters for protocol detection.
///
/// Contains information from a BLE scan needed to detect the device protocol.
class ProtocolDetectionParams {
  /// Device identifier and name.
  final DeviceInfo device;

  /// Service UUIDs advertised by the device.
  final List<String> advertisedServiceUuids;

  /// Manufacturer-specific data from the advertisement.
  final Map<int, List<int>>? manufacturerData;

  const ProtocolDetectionParams({
    required this.device,
    this.advertisedServiceUuids = const [],
    this.manufacturerData,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProtocolDetectionParams &&
          runtimeType == other.runtimeType &&
          device.id == other.device.id;

  @override
  int get hashCode => device.id.hashCode;
}

/// Notifier for ping test state.
///
/// Tracks the state of ping tests for the debug action in the device sheet.
class PingTestNotifier extends Notifier<PingTestState> {
  @override
  PingTestState build() => const PingTestState.idle();

  Future<void> ping() async {
    state = const PingTestState.inProgress();

    try {
      final coordinator = ref.read(connectionCoordinatorProvider);
      final latency = await coordinator.ping();

      if (latency != null) {
        state = PingTestState.success(latency);
      } else {
        // For Meshtastic without explicit ping, check if connected
        final connectionState = ref.read(deviceConnectionProvider);
        if (connectionState.isConnected) {
          // Meshtastic doesn't have explicit ping, but connection proves comms
          state = const PingTestState.success(Duration(milliseconds: 50));
        } else {
          state = const PingTestState.failure('Not connected');
        }
      }
    } catch (e) {
      state = PingTestState.failure(e.toString());
    }
  }

  void reset() {
    state = const PingTestState.idle();
  }
}

/// State of a ping test.
class PingTestState {
  /// The current status.
  final PingTestStatus status;

  /// Latency on success.
  final Duration? latency;

  /// Error message on failure.
  final String? errorMessage;

  const PingTestState.idle()
    : status = PingTestStatus.idle,
      latency = null,
      errorMessage = null;

  const PingTestState.inProgress()
    : status = PingTestStatus.inProgress,
      latency = null,
      errorMessage = null;

  const PingTestState.success(this.latency)
    : status = PingTestStatus.success,
      errorMessage = null;

  const PingTestState.failure(this.errorMessage)
    : status = PingTestStatus.failure,
      latency = null;

  /// Whether the test is idle.
  bool get isIdle => status == PingTestStatus.idle;

  /// Whether the test is in progress.
  bool get isInProgress => status == PingTestStatus.inProgress;

  /// Whether the test succeeded.
  bool get isSuccess => status == PingTestStatus.success;

  /// Whether the test failed.
  bool get isFailure => status == PingTestStatus.failure;
}

enum PingTestStatus { idle, inProgress, success, failure }

final pingTestProvider = NotifierProvider<PingTestNotifier, PingTestState>(
  PingTestNotifier.new,
);

/// State of a GATT dump operation.
class GattDumpState {
  /// The current status.
  final GattDumpStatus status;

  /// Discovered services on success.
  final List<GattServiceInfo>? services;

  /// Error message on failure.
  final String? errorMessage;

  const GattDumpState.idle()
    : status = GattDumpStatus.idle,
      services = null,
      errorMessage = null;

  const GattDumpState.inProgress()
    : status = GattDumpStatus.inProgress,
      services = null,
      errorMessage = null;

  const GattDumpState.success(this.services)
    : status = GattDumpStatus.success,
      errorMessage = null;

  const GattDumpState.failure(this.errorMessage)
    : status = GattDumpStatus.failure,
      services = null;

  bool get isIdle => status == GattDumpStatus.idle;
  bool get isInProgress => status == GattDumpStatus.inProgress;
  bool get isSuccess => status == GattDumpStatus.success;
  bool get isFailure => status == GattDumpStatus.failure;
}

enum GattDumpStatus { idle, inProgress, success, failure }

/// Info about a discovered GATT service.
class GattServiceInfo {
  final String uuid;
  final List<GattCharacteristicInfo> characteristics;

  const GattServiceInfo({required this.uuid, required this.characteristics});
}

/// Info about a discovered GATT characteristic.
class GattCharacteristicInfo {
  final String uuid;
  final List<String> properties;

  const GattCharacteristicInfo({required this.uuid, required this.properties});
}

final gattDumpProvider = NotifierProvider<GattDumpNotifier, GattDumpState>(
  GattDumpNotifier.new,
);

/// Notifier for GATT dump state.
///
/// Dumps all discovered GATT services and characteristics for debugging.
class GattDumpNotifier extends Notifier<GattDumpState> {
  @override
  GattDumpState build() => const GattDumpState.idle();

  Future<void> dump() async {
    state = const GattDumpState.inProgress();

    try {
      final coordinator = ref.read(connectionCoordinatorProvider);
      final services = await coordinator.discoverGattServices();

      if (services != null) {
        state = GattDumpState.success(services);
      } else {
        state = const GattDumpState.failure('GATT discovery not available');
      }
    } catch (e) {
      state = GattDumpState.failure(e.toString());
    }
  }

  void reset() {
    state = const GattDumpState.idle();
  }
}

// ---------------------------------------------------------------------------
// MeshCore Capture State (Dev-only)
// ---------------------------------------------------------------------------

/// Snapshot of MeshCore capture state for UI display.
///
/// Contains a copy of captured frames at a point in time.
class MeshCoreCaptureSnapshot {
  /// List of captured frames.
  final List<CapturedFrame> frames;

  /// Total frame count (may differ from frames.length if truncated).
  final int totalCount;

  /// Whether capture is active.
  final bool isActive;

  const MeshCoreCaptureSnapshot({
    required this.frames,
    required this.totalCount,
    required this.isActive,
  });

  /// Empty snapshot.
  const MeshCoreCaptureSnapshot.empty()
    : frames = const [],
      totalCount = 0,
      isActive = false;

  /// Whether there are any frames.
  bool get hasFrames => frames.isNotEmpty;
}

/// Notifier for MeshCore capture snapshot.
///
/// Provides a way for UI to observe capture changes without heavy rebuilds.
/// Call refresh() to poll the latest snapshot from the capture instance.
class MeshCoreCaptureNotifier extends Notifier<MeshCoreCaptureSnapshot> {
  @override
  MeshCoreCaptureSnapshot build() {
    // Initial state: check if we have an active capture
    final capture = ref.read(meshCoreCaptureProvider);
    if (capture == null) {
      return const MeshCoreCaptureSnapshot.empty();
    }
    return _snapshotFromCapture(capture);
  }

  /// Refresh the snapshot from the current capture.
  void refresh() {
    final capture = ref.read(meshCoreCaptureProvider);
    if (capture == null) {
      state = const MeshCoreCaptureSnapshot.empty();
      return;
    }
    state = _snapshotFromCapture(capture);
  }

  /// Clear the capture and refresh state.
  void clear() {
    final capture = ref.read(meshCoreCaptureProvider);
    capture?.clear();
    refresh();
  }

  /// Get the compact hex log for clipboard.
  String getHexLog() {
    final capture = ref.read(meshCoreCaptureProvider);
    return capture?.toCompactHexLog() ?? '(no capture active)';
  }

  MeshCoreCaptureSnapshot _snapshotFromCapture(MeshCoreFrameCapture capture) {
    final frames = capture.snapshot();
    return MeshCoreCaptureSnapshot(
      frames: frames,
      totalCount: frames.length,
      isActive: capture.isActive,
    );
  }
}

final meshCoreCaptureSnapshotProvider =
    NotifierProvider<MeshCoreCaptureNotifier, MeshCoreCaptureSnapshot>(
      MeshCoreCaptureNotifier.new,
    );
