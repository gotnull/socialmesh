// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/logging.dart';
import '../../../core/safe_lat_lng.dart';
import '../../../core/units/geo_distance.dart';
import '../../../models/mesh_models.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/radio_scope_providers.dart';
import '../../../services/location/location_service.dart';
import '../../../services/protocol/protocol_service.dart';
import 'range_test_database.dart';
import 'range_test_models.dart';

/// The radio-scoped store of recorded Range Test sessions.
final rangeTestDatabaseProvider = Provider<RangeTestDatabase>((ref) {
  ref.watch(radioScopeProvider);
  final db = RangeTestDatabase();
  bindStoreToRadioScope(ref, db, db.close);
  return db;
});

class RangeTestState {
  /// Newest first.
  final List<RangeTestSession> sessions;

  /// The session being recorded, if any.
  final int? activeSessionId;

  const RangeTestState({required this.sessions, this.activeSessionId});

  bool get isRecording => activeSessionId != null;

  RangeTestSession? get activeSession {
    for (final s in sessions) {
      if (s.id == activeSessionId) return s;
    }
    return null;
  }

  RangeTestState _updateSession(
    int id,
    RangeTestSession Function(RangeTestSession) update, {
    bool keepActive = true,
  }) {
    return RangeTestState(
      sessions: [for (final s in sessions) s.id == id ? update(s) : s],
      activeSessionId: keepActive ? activeSessionId : null,
    );
  }
}

/// Records Range Test packets into sessions. Kept alive so a recording
/// continues when the screen is closed.
final rangeTestProvider =
    AsyncNotifierProvider<RangeTestNotifier, RangeTestState>(
      RangeTestNotifier.new,
    );

class RangeTestNotifier extends AsyncNotifier<RangeTestState> {
  // A phone fix can take a few seconds; a packet is not held back longer
  // than this waiting for one.
  static const Duration _phoneFixTimeout = Duration(seconds: 10);

  StreamSubscription<RangeTestPacketEvent>? _sub;
  bool _phoneLocationAllowed = false;
  Future<Position?>? _pendingFix;

  @override
  Future<RangeTestState> build() async {
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
    });
    // Watched, not read: a radio switch replaces the store, and an active
    // recording ends with it.
    final db = ref.watch(rangeTestDatabaseProvider);
    await db.init();
    await db.endOpenSessions();
    return RangeTestState(sessions: await db.sessions());
  }

  /// Starts a new session that records every Range Test packet the radio
  /// hears until [stop].
  Future<void> start() async {
    if (state.value?.isRecording ?? true) return;
    final db = ref.read(rangeTestDatabaseProvider);
    final protocol = ref.read(protocolServiceProvider);
    final location = ref.read(locationServiceProvider);

    _phoneLocationAllowed = await location.checkPermissions();
    if (!ref.mounted) return;
    final session = await db.createSession(DateTime.now());
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null || current.isRecording) {
      await db.endSession(session.id, session.startedAt);
      return;
    }
    _sub = protocol.rangeTestPacketStream.listen(
      (event) => unawaited(_record(event)),
    );
    state = AsyncData(
      RangeTestState(
        sessions: [session, ...current.sessions],
        activeSessionId: session.id,
      ),
    );
    AppLogging.settings(
      'Range test: recording session ${session.id} '
      '(phone location ${_phoneLocationAllowed ? 'on' : 'off'})',
    );
  }

  Future<void> stop() async {
    final sessionId = state.value?.activeSessionId;
    if (sessionId == null) return;
    final db = ref.read(rangeTestDatabaseProvider);
    await _sub?.cancel();
    _sub = null;
    final endedAt = DateTime.now();
    await db.endSession(sessionId, endedAt);
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current._updateSession(
        sessionId,
        (s) => s.copyWith(endedAt: endedAt),
        keepActive: false,
      ),
    );
    AppLogging.settings('Range test: stopped session $sessionId');
  }

  /// Deletes a finished session and its readings.
  Future<void> delete(int sessionId) async {
    final current = state.value;
    if (current == null || current.activeSessionId == sessionId) return;
    await ref.read(rangeTestDatabaseProvider).deleteSession(sessionId);
    if (!ref.mounted) return;
    final latest = state.value ?? current;
    state = AsyncData(
      RangeTestState(
        sessions: [
          for (final s in latest.sessions)
            if (s.id != sessionId) s,
        ],
        activeSessionId: latest.activeSessionId,
      ),
    );
  }

  Future<void> _record(RangeTestPacketEvent event) async {
    final sessionId = state.value?.activeSessionId;
    if (sessionId == null) return;
    final db = ref.read(rangeTestDatabaseProvider);
    final location = ref.read(locationServiceProvider);
    final nodes = ref.read(nodesProvider);
    final myNodeNum = ref.read(myNodeNumProvider);
    final sender = nodes[event.senderNodeNum];
    final ownRadio = myNodeNum == null ? null : nodes[myNodeNum];

    final receiver = await _receiverPosition(location, ownRadio);
    if (!ref.mounted) return;

    final senderPosition = safeLatLng(sender?.latitude, sender?.longitude);
    final reading = RangeTestReading(
      sessionId: sessionId,
      receivedAt: event.receivedAt,
      senderNodeNum: event.senderNodeNum,
      senderName: sender?.displayName,
      packetId: event.packetId,
      sequence: event.sequence,
      payload: event.payload,
      rxSnr: event.rxSnr,
      rxRssi: event.rxRssi,
      viaMqtt: event.viaMqtt,
      rxLatitude: receiver?.position.latitude,
      rxLongitude: receiver?.position.longitude,
      rxAltitude: receiver?.altitude,
      rxPositionSource: receiver?.source,
      senderLatitude: senderPosition?.latitude,
      senderLongitude: senderPosition?.longitude,
      distanceMeters: receiver != null && senderPosition != null
          ? distanceMetersBetween(receiver.position, senderPosition)
          : null,
    );
    final inserted = await db.insertReading(reading);
    if (!inserted || !ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current._updateSession(
        sessionId,
        (s) => s.copyWith(readingCount: s.readingCount + 1),
      ),
    );
  }

  /// The phone's own fix, or the connected radio's last reported position
  /// when the phone has no fix or no location permission. The fallback is
  /// the firmware's own rule for the receiver columns of rangetest.csv.
  Future<({LatLng position, int? altitude, RangeTestPositionSource source})?>
  _receiverPosition(LocationService location, MeshNode? ownRadio) async {
    if (_phoneLocationAllowed) {
      // The iOS location plugin keeps one handler for a one-shot request,
      // so a second request overwrites the first and the first never
      // completes. Packets that arrive while a fix is pending share it.
      final fix = await (_pendingFix ??= location
          .getCurrentPosition()
          .timeout(_phoneFixTimeout, onTimeout: () => null)
          .whenComplete(() => _pendingFix = null));
      final phone = safeLatLng(fix?.latitude, fix?.longitude);
      if (fix != null && phone != null) {
        return (
          position: phone,
          altitude: fix.altitude.isFinite ? fix.altitude.round() : null,
          source: RangeTestPositionSource.phone,
        );
      }
    }
    final radio = safeLatLng(ownRadio?.latitude, ownRadio?.longitude);
    if (radio == null) return null;
    return (
      position: radio,
      altitude: ownRadio?.altitude,
      source: RangeTestPositionSource.radio,
    );
  }
}

/// A session's readings in the order received; re-read whenever the
/// session gains a reading.
final rangeTestReadingsProvider = FutureProvider.autoDispose
    .family<List<RangeTestReading>, int>((ref, sessionId) async {
      ref.watch(
        rangeTestProvider.select(
          (s) => s.value?.sessions
              .where((x) => x.id == sessionId)
              .firstOrNull
              ?.readingCount,
        ),
      );
      final db = ref.watch(rangeTestDatabaseProvider);
      await db.init();
      return db.readings(sessionId);
    });
