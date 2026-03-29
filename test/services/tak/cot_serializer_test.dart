// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/generated/meshtastic/atak.pb.dart';
import 'package:socialmesh/services/tak/cot_serializer.dart';
import 'package:xml/xml.dart';

void main() {
  group('CotSerializer', () {
    group('PLI serialization', () {
      test('takPacketToCotXml generates valid CoT XML for PLI', () {
        final packet = TAKPacket()
          ..pli = (PLI()
            ..latitudeI =
                377749000 // 37.7749
            ..longitudeI =
                -1224194000 // -122.4194
            ..altitude = 50
            ..speed = 5
            ..course = 180)
          ..contact = (Contact()
            ..callsign = 'ALPHA-1'
            ..deviceCallsign = 'MESHTASTIC')
          ..group = (Group()
            ..team = Team.Cyan
            ..role = MemberRole.TeamLead)
          ..status = (Status()..battery = 85);

        final xml = CotSerializer.takPacketToCotXml(
          packet,
          nodeNum: 0x1A2B3C4D,
          callsign: 'ALPHA-1',
        );

        final doc = XmlDocument.parse(xml);
        final event = doc.rootElement;
        expect(event.getAttribute('version'), '2.0');
        expect(event.getAttribute('uid'), 'MESHTASTIC-1A2B3C4D');
        expect(event.getAttribute('type'), contains('a-f-G-U-C'));
        expect(event.getAttribute('how'), 'h-g-i-g-o');

        final point = event.findElements('point').first;
        expect(point.getAttribute('lat'), '37.7749000');
        expect(point.getAttribute('lon'), '-122.4194000');
        expect(point.getAttribute('hae'), '50.0');

        final detail = event.findElements('detail').first;
        final contact = detail.findElements('contact').first;
        expect(contact.getAttribute('callsign'), 'ALPHA-1');

        final group = detail.findElements('__group').first;
        expect(group.getAttribute('name'), 'Cyan');
        expect(group.getAttribute('role'), 'Team Lead');

        final status = detail.findElements('status').first;
        expect(status.getAttribute('battery'), '85');

        final track = detail.findElements('track').first;
        expect(track.getAttribute('speed'), '5');
        expect(track.getAttribute('course'), '180');
      });

      test('PLI with no speed/course omits track element', () {
        final packet = TAKPacket()
          ..pli = (PLI()
            ..latitudeI = 0
            ..longitudeI = 0
            ..altitude = 0);

        final xml = CotSerializer.takPacketToCotXml(
          packet,
          nodeNum: 1,
          callsign: 'TEST',
        );

        final doc = XmlDocument.parse(xml);
        final detail = doc.rootElement.findElements('detail').first;
        expect(detail.findElements('track'), isEmpty);
      });
    });

    group('GeoChat serialization', () {
      test('takPacketToCotXml generates valid CoT XML for GeoChat', () {
        final packet = TAKPacket()
          ..chat = (GeoChat()
            ..message = 'Hello from mesh!'
            ..to = 'MESHTASTIC-5E6F7A8B'
            ..toCallsign = 'BRAVO-2')
          ..contact = (Contact()..callsign = 'ALPHA-1');

        final xml = CotSerializer.takPacketToCotXml(
          packet,
          nodeNum: 0x1A2B3C4D,
          callsign: 'ALPHA-1',
        );

        final doc = XmlDocument.parse(xml);
        final event = doc.rootElement;
        expect(event.getAttribute('type'), 'b-t-f');

        final detail = event.findElements('detail').first;
        final chatEl = detail.findElements('__chat').first;
        expect(chatEl.getAttribute('senderCallsign'), 'ALPHA-1');
        expect(chatEl.getAttribute('to'), 'MESHTASTIC-5E6F7A8B');
        expect(chatEl.getAttribute('toCallsign'), 'BRAVO-2');

        final remarks = detail.findElements('remarks').first;
        expect(remarks.innerText, 'Hello from mesh!');
      });
    });

    group('deserialization', () {
      test('cotXmlToTakPacket parses PLI from CoT XML', () {
        const xml =
            '<?xml version="1.0"?>'
            '<event version="2.0" uid="MESHTASTIC-1A2B3C4D" '
            'type="a-f-G-U-C" time="2025-01-01T00:00:00.000Z" '
            'start="2025-01-01T00:00:00.000Z" '
            'stale="2025-01-01T00:05:00.000Z" how="h-g-i-g-o">'
            '<point lat="37.7749000" lon="-122.4194000" hae="50.0" '
            'ce="9999999.0" le="9999999.0"/>'
            '<detail>'
            '<contact callsign="ALPHA-1"/>'
            '<__group name="Cyan" role="Team Lead"/>'
            '<status battery="85"/>'
            '<track speed="5" course="180"/>'
            '</detail>'
            '</event>';

        final packet = CotSerializer.cotXmlToTakPacket(xml);

        expect(packet.whichPayloadVariant(), TAKPacket_PayloadVariant.pli);
        expect(packet.pli.latitudeI, 377749000);
        expect(packet.pli.longitudeI, -1224194000);
        expect(packet.pli.altitude, 50);
        expect(packet.pli.speed, 5);
        expect(packet.pli.course, 180);
        expect(packet.contact.callsign, 'ALPHA-1');
        expect(packet.group.team, Team.Cyan);
        expect(packet.group.role, MemberRole.TeamLead);
        expect(packet.status.battery, 85);
      });

      test('cotXmlToTakPacket parses GeoChat from CoT XML', () {
        const xml =
            '<?xml version="1.0"?>'
            '<event version="2.0" uid="chat-123" '
            'type="b-t-f" time="2025-01-01T00:00:00.000Z" '
            'start="2025-01-01T00:00:00.000Z" '
            'stale="2025-01-01T00:05:00.000Z" how="h-g-i-g-o">'
            '<point lat="0" lon="0" hae="0" ce="9999999" le="9999999"/>'
            '<detail>'
            '<contact callsign="SENDER"/>'
            '<__chat to="RECV-UID" toCallsign="RECEIVER">'
            '<chatgrp uid0="SENDER" uid1="RECV-UID"/>'
            '</__chat>'
            '<remarks>Test message</remarks>'
            '</detail>'
            '</event>';

        final packet = CotSerializer.cotXmlToTakPacket(xml);

        expect(packet.whichPayloadVariant(), TAKPacket_PayloadVariant.chat);
        expect(packet.chat.message, 'Test message');
        expect(packet.chat.to, 'RECV-UID');
        expect(packet.chat.toCallsign, 'RECEIVER');
        expect(packet.contact.callsign, 'SENDER');
      });
    });

    group('round-trip', () {
      test('PLI round-trip preserves data', () {
        final original = TAKPacket()
          ..pli = (PLI()
            ..latitudeI = 377749000
            ..longitudeI = -1224194000
            ..altitude = 100
            ..speed = 10
            ..course = 270)
          ..contact = (Contact()..callsign = 'ROUND-TRIP')
          ..group = (Group()
            ..team = Team.Blue
            ..role = MemberRole.Medic)
          ..status = (Status()..battery = 42);

        final xml = CotSerializer.takPacketToCotXml(
          original,
          nodeNum: 0xDEADBEEF,
          callsign: 'ROUND-TRIP',
        );
        final restored = CotSerializer.cotXmlToTakPacket(xml);

        expect(restored.pli.latitudeI, original.pli.latitudeI);
        expect(restored.pli.longitudeI, original.pli.longitudeI);
        expect(restored.pli.altitude, original.pli.altitude);
        expect(restored.pli.speed, original.pli.speed);
        expect(restored.pli.course, original.pli.course);
        expect(restored.contact.callsign, original.contact.callsign);
        expect(restored.group.team, original.group.team);
        expect(restored.group.role, original.group.role);
        expect(restored.status.battery, original.status.battery);
      });

      test('GeoChat round-trip preserves data', () {
        final original = TAKPacket()
          ..chat = (GeoChat()
            ..message = 'Test round-trip'
            ..to = 'MESHTASTIC-12345678'
            ..toCallsign = 'TARGET')
          ..contact = (Contact()..callsign = 'SENDER');

        final xml = CotSerializer.takPacketToCotXml(
          original,
          nodeNum: 0xAABBCCDD,
          callsign: 'SENDER',
        );
        final restored = CotSerializer.cotXmlToTakPacket(xml);

        expect(restored.chat.message, original.chat.message);
        expect(restored.chat.to, original.chat.to);
        expect(restored.chat.toCallsign, original.chat.toCallsign);
        expect(restored.contact.callsign, original.contact.callsign);
      });
    });
  });
}
