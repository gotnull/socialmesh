// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:bonsoir/bonsoir.dart';

import '../../core/logging.dart';
import '../../core/transport.dart';
import '../../models/mesh_device.dart';
import '../../services/transport/network_transport.dart';

/// Discovered Meshtastic device via mDNS/Bonjour on the local network.
///
/// Contains the resolved host, port, and optional identity extracted from
/// the Meshtastic mDNS TXT records (`shortname` and `id` fields).
class MdnsDeviceInfo {
  final String host;
  final int port;
  final String serviceName;
  final String? shortName;
  final String? nodeId;

  /// Protocol the device speaks. Bonjour service type determines this:
  /// `_meshtastic._tcp` → meshtastic. Reserved for future MeshCore mDNS
  /// service-type discovery — UI groups and badges keys off this value.
  final MeshProtocolType protocol;

  MdnsDeviceInfo({
    required this.host,
    required this.port,
    required this.serviceName,
    this.shortName,
    this.nodeId,
    this.protocol = MeshProtocolType.meshtastic,
  });

  /// Display name following the standard Meshtastic discovery format:
  /// `shortname_nodeIdSuffix` (e.g., "0864_0864") or fallback to
  /// `serviceName (host)`.
  String get displayName {
    final parts = <String>[];
    if (shortName != null && shortName!.isNotEmpty) {
      parts.add(shortName!);
    }
    if (nodeId != null && nodeId!.length >= 4) {
      parts.add(nodeId!.substring(nodeId!.length - 4));
    }
    if (parts.isNotEmpty) return parts.join('_');
    return '$serviceName ($host)';
  }

  /// Convert to a [DeviceInfo] for the standard connection flow.
  DeviceInfo toDeviceInfo() => DeviceInfo(
    id: 'tcp:$host:$port',
    name: displayName,
    type: TransportType.network,
    address: '$host:$port',
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MdnsDeviceInfo && host == other.host && port == other.port;

  @override
  int get hashCode => Object.hash(host, port);
}

/// Browses for Meshtastic devices advertised via mDNS (`_meshtastic._tcp.`).
///
/// Uses the `bonsoir` package which wraps Apple Bonjour (iOS/macOS) and
/// Android NSD natively. The Meshtastic firmware advertises itself with
/// TXT records containing `shortname` and `id` fields when WiFi is enabled.
///
/// Lifecycle: call [startDiscovery] when the scanner screen appears,
/// [stopDiscovery] when it disappears. The [devicesStream] emits the
/// current set of discovered devices on every change.
class MeshtasticMdnsDiscovery {
  static const String _serviceType = '_meshtastic._tcp';

  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _subscription;

  final _devices = <String, MdnsDeviceInfo>{};
  final _controller = StreamController<List<MdnsDeviceInfo>>.broadcast();

  /// Pending removal timers — cancelled if the service reappears within
  /// the grace period, preventing flicker from mDNS cache refresh cycles.
  final _pendingRemovals = <String, Timer>{};

  /// Stream of currently-visible Meshtastic mDNS devices.
  /// Emits a new list whenever a device is found, resolved, or lost.
  Stream<List<MdnsDeviceInfo>> get devicesStream => _controller.stream;

  /// Current snapshot of discovered devices.
  List<MdnsDeviceInfo> get currentDevices => _devices.values.toList();

  /// Whether discovery is actively running.
  bool get isDiscovering => _discovery != null && !_discovery!.isStopped;

  /// Start browsing for `_meshtastic._tcp.` services on the local network.
  Future<void> startDiscovery() async {
    if (isDiscovering) return;

    AppLogging.protocol('mDNS: Starting discovery for $_serviceType');

    // Keep existing devices — they will be updated/removed via events.
    // Only stopDiscovery() clears the list.
    _discovery = BonsoirDiscovery(type: _serviceType, printLogs: false);

    await _discovery!.initialize();

    _subscription = _discovery!.eventStream?.listen(_handleEvent);

    await _discovery!.start();
  }

  /// Stop browsing.
  Future<void> stopDiscovery() async {
    AppLogging.protocol('mDNS: Stopping discovery');
    _subscription?.cancel();
    _subscription = null;

    for (final timer in _pendingRemovals.values) {
      timer.cancel();
    }
    _pendingRemovals.clear();

    if (_discovery != null && !_discovery!.isStopped) {
      await _discovery!.stop();
    }
    _discovery = null;

    _devices.clear();
    _emitDevices();
  }

  void _handleEvent(BonsoirDiscoveryEvent event) {
    switch (event) {
      case BonsoirDiscoveryStartedEvent():
        AppLogging.protocol('mDNS: Discovery started');

      case BonsoirDiscoveryServiceFoundEvent():
        // Service found but not yet resolved — resolve to get host/port/TXT.
        // Cancel any pending removal: the service is back before the grace
        // period expired, so don't let the timer remove it.
        _pendingRemovals.remove(_serviceKey(event.service))?.cancel();
        AppLogging.protocol(
          'mDNS: Service found: ${event.service.name} '
          '(type=${event.service.type})',
        );
        event.service.resolve(_discovery!.serviceResolver);

      case BonsoirDiscoveryServiceResolvedEvent():
        _onServiceResolved(event.service);

      case BonsoirDiscoveryServiceUpdatedEvent():
        _onServiceResolved(event.service);

      case BonsoirDiscoveryServiceLostEvent():
        final key = _serviceKey(event.service);
        if (_devices.containsKey(key)) {
          // Defer removal — mDNS cache refreshes cause transient lost events.
          // If the service reappears within the grace period the timer is
          // cancelled and the device stays in the list without UI flicker.
          _pendingRemovals[key]?.cancel();
          _pendingRemovals[key] = Timer(const Duration(seconds: 5), () {
            _pendingRemovals.remove(key);
            if (_devices.remove(key) != null) {
              AppLogging.protocol('mDNS: Service lost: ${event.service.name}');
              _emitDevices();
            }
          });
        }

      case BonsoirDiscoveryServiceResolveFailedEvent():
        AppLogging.protocol('mDNS: Service resolve failed');

      case BonsoirDiscoveryStoppedEvent():
        AppLogging.protocol('mDNS: Discovery stopped');

      default:
        break;
    }
  }

  void _onServiceResolved(BonsoirService service) {
    final host = service.host;
    final port = service.port;

    if (host == null || host.isEmpty) {
      AppLogging.protocol(
        'mDNS: Service resolved but no host: ${service.name}',
      );
      return;
    }

    // Extract Meshtastic TXT record fields
    final attrs = service.attributes;
    final shortName = attrs['shortname'];
    final nodeId = attrs['id'];

    // --- SECURITY AUDIT LOGGING ---
    // Log raw TXT record details for injection detection
    AppLogging.protocol('mDNS SECURITY: Raw TXT records from ${service.name}:');
    for (final entry in attrs.entries) {
      final keyLen = entry.key.length;
      final valLen = entry.value.length;
      final codeUnits = entry.value.codeUnits;
      final hasControl = codeUnits.any((c) => c < 0x20 || c == 0x7F);
      final hasBidi = codeUnits.any((c) => c >= 0x200E && c <= 0x2069);
      AppLogging.protocol(
        '  TXT[${entry.key}] len=$valLen keyLen=$keyLen '
        'hasControlChars=$hasControl hasBidiChars=$hasBidi '
        'value="${_truncateForLog(entry.value, 80)}"',
      );
      if (valLen > 100) {
        AppLogging.protocol(
          '  ⚠️ SECURITY: Oversized TXT value ($valLen chars) for key=${entry.key}',
        );
      }
      if (hasControl) {
        AppLogging.protocol(
          '  ⚠️ SECURITY: Control characters detected in TXT[${entry.key}]: '
          'codeUnits=${codeUnits.where((c) => c < 0x20 || c == 0x7F).toList()}',
        );
      }
      if (hasBidi) {
        AppLogging.protocol(
          '  ⚠️ SECURITY: Bidi/RTL override characters detected in TXT[${entry.key}]: '
          'codeUnits=${codeUnits.where((c) => c >= 0x200E && c <= 0x2069).map((c) => 'U+${c.toRadixString(16).padLeft(4, '0').toUpperCase()}').toList()}',
        );
      }
    }
    AppLogging.protocol(
      'mDNS SECURITY: serviceName="${service.name}" (len=${service.name.length}) '
      'host="$host" (len=${host.length}) port=$port',
    );
    // --- END SECURITY AUDIT LOGGING ---

    final device = MdnsDeviceInfo(
      host: host,
      port: port > 0 ? port : kMeshtasticDefaultPort,
      serviceName: service.name,
      shortName: shortName,
      nodeId: nodeId,
    );

    AppLogging.protocol(
      'mDNS: Service resolved: ${device.displayName} '
      'at $host:${device.port} (shortname=$shortName, id=$nodeId)',
    );

    final key = _serviceKey(service);
    // Cancel any pending removal — service reappeared before grace expired.
    _pendingRemovals.remove(key)?.cancel();
    _devices[key] = device;
    _emitDevices();
  }

  String _serviceKey(BonsoirService service) =>
      '${service.name}::${service.type}';

  void _emitDevices() {
    if (!_controller.isClosed) {
      _controller.add(currentDevices);
    }
  }

  /// Truncate a string for safe logging (prevents log flooding from
  /// oversized mDNS TXT values).
  static String _truncateForLog(String s, int maxLen) {
    if (s.length <= maxLen) return s;
    return '${s.substring(0, maxLen)}... [TRUNCATED ${s.length - maxLen} chars]';
  }

  /// Clean up resources.
  Future<void> dispose() async {
    await stopDiscovery();
    await _controller.close();
  }
}
