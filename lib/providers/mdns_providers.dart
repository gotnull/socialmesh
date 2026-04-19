// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/transport/mdns_discovery_service.dart';

/// Singleton [MeshtasticMdnsDiscovery] instance with lifecycle management.
///
/// The service is created lazily and disposed when the provider is disposed.
/// Start/stop scanning via [MdnsDiscoveryNotifier.startScan] / [stopScan].
class MdnsDiscoveryNotifier extends Notifier<List<MdnsDeviceInfo>> {
  MeshtasticMdnsDiscovery? _discovery;
  StreamSubscription<List<MdnsDeviceInfo>>? _subscription;

  @override
  List<MdnsDeviceInfo> build() {
    ref.onDispose(_dispose);
    return [];
  }

  /// Start mDNS discovery for `_meshtastic._tcp.` services.
  Future<void> startScan() async {
    _discovery ??= MeshtasticMdnsDiscovery();
    if (_discovery!.isDiscovering) return;

    _subscription?.cancel();
    _subscription = _discovery!.devicesStream.listen((devices) {
      state = devices;
    });

    await _discovery!.startDiscovery();
  }

  /// Stop mDNS discovery.
  Future<void> stopScan() async {
    _subscription?.cancel();
    _subscription = null;
    await _discovery?.stopDiscovery();
    state = [];
  }

  void _dispose() {
    _subscription?.cancel();
    _discovery?.dispose();
  }
}

final mdnsDiscoveryProvider =
    NotifierProvider<MdnsDiscoveryNotifier, List<MdnsDeviceInfo>>(
      MdnsDiscoveryNotifier.new,
    );
