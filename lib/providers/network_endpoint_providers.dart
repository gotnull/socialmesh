// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging.dart';
import '../models/network_endpoint.dart';

const String _kEndpointsKey = 'network_endpoints_v1';

/// Manages saved network endpoints (host:port) for TCP connections.
///
/// Persists via SharedPreferences as JSON, following the standard
/// Meshtastic companion app pattern of storing manual connections locally.
class NetworkEndpointsNotifier extends Notifier<List<NetworkEndpoint>> {
  @override
  List<NetworkEndpoint> build() {
    _loadFromDisk();
    return [];
  }

  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_kEndpointsKey);
      if (json != null && json.isNotEmpty) {
        state = NetworkEndpoint.decodeList(json);
        AppLogging.protocol(
          'NetworkEndpoints: Loaded ${state.length} saved endpoints',
        );
      }
    } catch (e) {
      AppLogging.protocol('NetworkEndpoints: Failed to load: $e');
    }
  }

  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kEndpointsKey, NetworkEndpoint.encodeList(state));
    } catch (e) {
      AppLogging.protocol('NetworkEndpoints: Failed to save: $e');
    }
  }

  Future<void> addEndpoint(NetworkEndpoint endpoint) async {
    // Replace if same host:port already exists
    final existing = state.indexWhere(
      (e) => e.host == endpoint.host && e.port == endpoint.port,
    );
    if (existing >= 0) {
      final updated = List<NetworkEndpoint>.from(state);
      updated[existing] = endpoint;
      state = updated;
    } else {
      state = [...state, endpoint];
    }
    await _saveToDisk();
  }

  Future<void> removeEndpoint(String id) async {
    state = state.where((e) => e.id != id).toList();
    await _saveToDisk();
  }

  Future<void> updateLastUsed(String id) async {
    state = state.map((e) {
      if (e.id == id) {
        return e.copyWith(lastUsed: DateTime.now());
      }
      return e;
    }).toList();
    await _saveToDisk();
  }
}

final networkEndpointsProvider =
    NotifierProvider<NetworkEndpointsNotifier, List<NetworkEndpoint>>(
      NetworkEndpointsNotifier.new,
    );
