// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:xml/xml.dart';

import '../../core/logging.dart';
import '../../generated/meshtastic/atak.pb.dart';
import 'team_role_mapper.dart';

/// Converts between Meshtastic [TAKPacket] protobufs and CoT XML strings.
///
/// Handles PLI (position), GeoChat (messaging), and Group/Contact/Status
/// detail elements. This is the codec used by [TakMeshBridge] for
/// bidirectional translation between mesh and TAK wire formats.
abstract final class CotSerializer {
  /// CoT type for friendly ground unit position.
  static const String cotTypePli = 'a-f-G-U-C';

  /// CoT type for chat message.
  static const String cotTypeChat = 'b-t-f';

  /// Default stale duration for position events.
  static const Duration staleDuration = Duration(minutes: 5);

  /// Multiplier to convert protobuf fixed-point lat/lon to degrees.
  static const double _coordScale = 1e-7;

  /// Converts a [TAKPacket] to CoT XML string.
  ///
  /// [nodeNum] is the originating Meshtastic node number.
  /// [callsign] is the display name for this entity.
  static String takPacketToCotXml(
    TAKPacket packet, {
    required int nodeNum,
    required String callsign,
  }) {
    final uid = _meshUid(nodeNum);
    final now = DateTime.now().toUtc();
    final stale = now.add(staleDuration);

    final variant = packet.whichPayloadVariant();
    switch (variant) {
      case TAKPacket_PayloadVariant.pli:
        return _pliToCotXml(packet, uid, callsign, now, stale);
      case TAKPacket_PayloadVariant.chat:
        return _chatToCotXml(packet, uid, callsign, now, stale);
      case TAKPacket_PayloadVariant.detail:
      case TAKPacket_PayloadVariant.notSet:
        return _genericToCotXml(packet, uid, callsign, now, stale);
    }
  }

  /// Parses CoT XML into a [TAKPacket].
  static TAKPacket cotXmlToTakPacket(String cotXml) {
    final doc = XmlDocument.parse(cotXml);
    final event = doc.rootElement;

    final type = event.getAttribute('type') ?? '';
    final detail = event.findElements('detail').firstOrNull;

    final packet = TAKPacket();

    // Parse contact.
    final contactEl = detail?.findElements('contact').firstOrNull;
    if (contactEl != null) {
      packet.contact = Contact()
        ..callsign = contactEl.getAttribute('callsign') ?? ''
        ..deviceCallsign = contactEl.getAttribute('deviceCallsign') ?? '';
    }

    // Parse group.
    final groupEl = detail?.findElements('__group').firstOrNull;
    if (groupEl != null) {
      final teamName = groupEl.getAttribute('name') ?? '';
      final roleName = groupEl.getAttribute('role') ?? '';
      packet.group = Group()
        ..team = TeamRoleMapper.nameToTeam(teamName)
        ..role = TeamRoleMapper.nameToRole(roleName);
    }

    // Parse status.
    final statusEl = detail?.findElements('status').firstOrNull;
    if (statusEl != null) {
      final battery = int.tryParse(statusEl.getAttribute('battery') ?? '');
      if (battery != null) {
        packet.status = Status()..battery = battery;
      }
    }

    // Determine payload variant from CoT type.
    if (type == cotTypeChat || type.startsWith('b-t-f')) {
      _parseChatPayload(packet, detail);
    } else if (type.startsWith('a-')) {
      _parsePliPayload(packet, event);
    }

    final payloadType = packet.whichPayloadVariant().name;
    final size = packet.writeToBuffer().length;
    AppLogging.tak(
      'Deserialized CoT XML -> TAKPacket($payloadType) ($size bytes)',
    );

    return packet;
  }

  // --- Private helpers ---

  static String _meshUid(int nodeNum) =>
      'MESHTASTIC-${nodeNum.toRadixString(16).toUpperCase().padLeft(8, '0')}';

  static String _isoTime(DateTime dt) => dt.toIso8601String();

  static String _pliToCotXml(
    TAKPacket packet,
    String uid,
    String callsign,
    DateTime now,
    DateTime stale,
  ) {
    final pli = packet.pli;
    final lat = pli.latitudeI * _coordScale;
    final lon = pli.longitudeI * _coordScale;
    final hae = pli.altitude.toDouble();

    final cotType = _buildCotType(packet);

    final builder = XmlBuilder();
    builder.element(
      'event',
      attributes: {
        'version': '2.0',
        'uid': uid,
        'type': cotType,
        'time': _isoTime(now),
        'start': _isoTime(now),
        'stale': _isoTime(stale),
        'how': 'h-g-i-g-o',
      },
      nest: () {
        builder.element(
          'point',
          attributes: {
            'lat': lat.toStringAsFixed(7),
            'lon': lon.toStringAsFixed(7),
            'hae': hae.toStringAsFixed(1),
            'ce': '9999999.0',
            'le': '9999999.0',
          },
        );
        builder.element(
          'detail',
          nest: () {
            _addContactElement(builder, packet, callsign);
            _addGroupElement(builder, packet);
            _addStatusElement(builder, packet);
            if (pli.speed > 0 || pli.course > 0) {
              builder.element(
                'track',
                attributes: {
                  'speed': pli.speed.toString(),
                  'course': pli.course.toString(),
                },
              );
            }
          },
        );
      },
    );

    final xml = builder.buildDocument().toXmlString();
    AppLogging.tak(
      'Serialized TAKPacket(PLI) -> CoT XML: uid=$uid, type=$cotType (${xml.length} bytes)',
    );
    return xml;
  }

  static String _chatToCotXml(
    TAKPacket packet,
    String uid,
    String callsign,
    DateTime now,
    DateTime stale,
  ) {
    final chat = packet.chat;
    final chatUid = '$uid-chat-${now.millisecondsSinceEpoch}';

    final builder = XmlBuilder();
    builder.element(
      'event',
      attributes: {
        'version': '2.0',
        'uid': chatUid,
        'type': cotTypeChat,
        'time': _isoTime(now),
        'start': _isoTime(now),
        'stale': _isoTime(stale),
        'how': 'h-g-i-g-o',
      },
      nest: () {
        builder.element(
          'point',
          attributes: {
            'lat': '0.0000000',
            'lon': '0.0000000',
            'hae': '0.0',
            'ce': '9999999.0',
            'le': '9999999.0',
          },
        );
        builder.element(
          'detail',
          nest: () {
            _addContactElement(builder, packet, callsign);
            builder.element(
              '__chat',
              attributes: {
                'senderCallsign': callsign,
                'id': uid,
                if (chat.to.isNotEmpty) 'to': chat.to,
                if (chat.toCallsign.isNotEmpty) 'toCallsign': chat.toCallsign,
              },
              nest: () {
                builder.element(
                  'chatgrp',
                  attributes: {
                    'uid0': uid,
                    'uid1': chat.to.isNotEmpty ? chat.to : 'All Chat Rooms',
                  },
                );
              },
            );
            builder.element(
              'remarks',
              nest: () {
                builder.text(chat.message);
              },
            );
          },
        );
      },
    );

    final xml = builder.buildDocument().toXmlString();
    AppLogging.tak(
      'Serialized TAKPacket(GeoChat) -> CoT XML: uid=$chatUid (${xml.length} bytes)',
    );
    return xml;
  }

  static String _genericToCotXml(
    TAKPacket packet,
    String uid,
    String callsign,
    DateTime now,
    DateTime stale,
  ) {
    final builder = XmlBuilder();
    builder.element(
      'event',
      attributes: {
        'version': '2.0',
        'uid': uid,
        'type': cotTypePli,
        'time': _isoTime(now),
        'start': _isoTime(now),
        'stale': _isoTime(stale),
        'how': 'h-g-i-g-o',
      },
      nest: () {
        builder.element(
          'point',
          attributes: {
            'lat': '0.0000000',
            'lon': '0.0000000',
            'hae': '0.0',
            'ce': '9999999.0',
            'le': '9999999.0',
          },
        );
        builder.element(
          'detail',
          nest: () {
            _addContactElement(builder, packet, callsign);
            _addGroupElement(builder, packet);
            _addStatusElement(builder, packet);
          },
        );
      },
    );

    return builder.buildDocument().toXmlString();
  }

  static String _buildCotType(TAKPacket packet) {
    if (packet.hasGroup()) {
      final suffix = TeamRoleMapper.cotTypeSuffix(packet.group.role);
      if (suffix.isNotEmpty) return 'a-f-G-U-C-$suffix';
    }
    return cotTypePli;
  }

  static void _addContactElement(
    XmlBuilder builder,
    TAKPacket packet,
    String callsign,
  ) {
    final cs = packet.hasContact() && packet.contact.callsign.isNotEmpty
        ? packet.contact.callsign
        : callsign;
    final deviceCs = packet.hasContact() ? packet.contact.deviceCallsign : '';
    builder.element(
      'contact',
      attributes: {
        'callsign': cs,
        if (deviceCs.isNotEmpty) 'deviceCallsign': deviceCs,
      },
    );
  }

  static void _addGroupElement(XmlBuilder builder, TAKPacket packet) {
    if (!packet.hasGroup()) return;
    final attrs = TeamRoleMapper.groupToCoTAttributes(
      packet.group.team,
      packet.group.role,
    );
    builder.element(
      '__group',
      attributes: {'name': attrs.teamName, 'role': attrs.roleName},
    );
  }

  static void _addStatusElement(XmlBuilder builder, TAKPacket packet) {
    if (!packet.hasStatus()) return;
    builder.element(
      'status',
      attributes: {'battery': packet.status.battery.toString()},
    );
  }

  static void _parsePliPayload(TAKPacket packet, XmlElement event) {
    final point = event.findElements('point').firstOrNull;
    if (point == null) return;

    final lat = double.tryParse(point.getAttribute('lat') ?? '') ?? 0;
    final lon = double.tryParse(point.getAttribute('lon') ?? '') ?? 0;
    final hae = double.tryParse(point.getAttribute('hae') ?? '') ?? 0;

    final pli = PLI()
      ..latitudeI = (lat / _coordScale).round()
      ..longitudeI = (lon / _coordScale).round()
      ..altitude = hae.round();

    // Parse track element for speed/course.
    final detail = event.findElements('detail').firstOrNull;
    final track = detail?.findElements('track').firstOrNull;
    if (track != null) {
      pli.speed = int.tryParse(track.getAttribute('speed') ?? '') ?? 0;
      pli.course = int.tryParse(track.getAttribute('course') ?? '') ?? 0;
    }

    packet.pli = pli;
  }

  static void _parseChatPayload(TAKPacket packet, XmlElement? detail) {
    if (detail == null) return;

    final chatEl = detail.findElements('__chat').firstOrNull;
    final remarksEl = detail.findElements('remarks').firstOrNull;

    final chat = GeoChat()
      ..message = remarksEl?.innerText ?? ''
      ..to = chatEl?.getAttribute('to') ?? ''
      ..toCallsign = chatEl?.getAttribute('toCallsign') ?? '';

    packet.chat = chat;
  }
}
