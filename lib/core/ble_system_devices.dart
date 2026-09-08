// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Canonical BLE service UUIDs for supported mesh radios, plus the one
// correct way to enumerate OS-level connected peripherals.
//
// iOS maps FlutterBluePlus.systemDevices() to CoreBluetooth's
// retrieveConnectedPeripheralsWithServices:, which returns NOTHING for an
// empty service list. Any stale-connection cleanup or connected-device
// lookup built on `systemDevices([])` is therefore dead code on iOS: a
// radio the OS still holds a GATT link to stops advertising, scans never
// see it, and reconnect loops fail until the app is killed. Always go
// through [meshSystemDevices] instead of calling
// FlutterBluePlus.systemDevices directly.

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'logging.dart';
import 'meshcore_constants.dart';

/// ATT MTU requested on every mesh radio link. 512 is the ATT ceiling; the
/// peripheral answers with what it supports.
const int kMeshBleRequestedMtu = 512;

/// Negotiate the ATT MTU on a freshly connected mesh radio link.
///
/// Android keeps the 23-byte default until the central asks, and every
/// supported radio firmware fragments a notification at MTU - 3, so a
/// frame longer than 20 bytes reaches a notification-per-frame decoder in
/// pieces it cannot reassemble. iOS negotiates the MTU itself during
/// connection and rejects explicit requests, so the request is
/// Android-only.
///
/// [requestMtu] and [isConnected] are the device's own calls, passed in so
/// the retry policy is testable without a GATT stack. Returns the
/// negotiated MTU, or null when the platform negotiates on its own or
/// every attempt failed and the caller proceeds on the default. Throws
/// when the link drops between attempts; callers treat that as a failed
/// connect.
Future<int?> negotiateMeshBleMtu({
  required Future<int> Function(int desiredMtu) requestMtu,
  required bool Function() isConnected,
  TargetPlatform? platform,
  int attempts = 3,
  Duration retryDelay = const Duration(milliseconds: 300),
}) async {
  if ((platform ?? defaultTargetPlatform) != TargetPlatform.android) {
    return null;
  }
  for (var attempt = 1; attempt <= attempts; attempt++) {
    try {
      final mtu = await requestMtu(kMeshBleRequestedMtu);
      AppLogging.ble('MTU negotiated: $mtu (attempt $attempt/$attempts)');
      return mtu;
    } catch (e) {
      AppLogging.ble('MTU request attempt $attempt/$attempts failed: $e');
      if (attempt == attempts) {
        AppLogging.ble('Proceeding without MTU negotiation');
        return null;
      }
      await Future.delayed(retryDelay);
      if (!isConnected()) {
        throw Exception('Device disconnected during MTU negotiation');
      }
    }
  }
  return null;
}

/// Meshtastic BLE service UUIDs.
///
/// See https://meshtastic.org/docs/development/device/client-api/
class MeshtasticBleUuids {
  MeshtasticBleUuids._();

  /// Primary Meshtastic GATT service UUID.
  static const String serviceUuid = '6ba1b218-15a8-461f-9fa8-5dcae273eafd';
}

/// Service UUIDs of every mesh radio protocol the app can talk to.
///
/// Used as the iOS `withServices` filter when retrieving connected
/// peripherals. Android ignores the filter and returns all connected
/// GATT devices.
final List<Guid> knownMeshServiceGuids = [
  Guid(MeshtasticBleUuids.serviceUuid),
  Guid(MeshCoreBleUuids.serviceUuid),
];

/// Returns peripherals the OS currently holds a connection to that expose
/// a known mesh radio service, unioned with peripherals this app itself
/// is connected to (deduplicated by remote id).
///
/// The union matters: `systemDevices` covers links held by other apps or
/// the OS, while `FlutterBluePlus.connectedDevices` covers links this app
/// owns regardless of service filtering, so a radio stuck in either state
/// is always visible to cleanup and reconnect paths.
Future<List<BluetoothDevice>> meshSystemDevices() async {
  final byId = <String, BluetoothDevice>{};
  try {
    for (final device in await FlutterBluePlus.systemDevices(
      knownMeshServiceGuids,
    )) {
      byId[device.remoteId.toString()] = device;
    }
  } catch (_) {
    // Fall through to app-owned connections.
  }
  for (final device in FlutterBluePlus.connectedDevices) {
    byId[device.remoteId.toString()] = device;
  }
  return byId.values.toList();
}
