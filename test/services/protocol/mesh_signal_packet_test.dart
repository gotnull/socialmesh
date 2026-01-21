import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MeshSignalPacket payload roundtrip keeps fields and uses compressed keys',
      () {
    final packet = MeshSignalPacket(
      senderNodeId: 0x10,
      packetId: 42,
      signalId: 'signal-uuid',
      content: 'Hello mesh',
      ttlMinutes: 15,
      latitude: 1.23,
      longitude: 4.56,
      hopCount: 2,
      receivedAt: DateTime.now(),
    );

    final payload = packet.toPayload();
    final decoded = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
    expect(decoded['c'], equals('Hello mesh'));
    expect(decoded['t'], equals(15));
    expect(decoded['id'], equals('signal-uuid'));
    expect(decoded['la'], equals(1.23));
    expect(decoded['ln'], equals(4.56));

    final parsed = MeshSignalPacket.fromPayload(
      packet.senderNodeId,
      payload,
      hopCount: packet.hopCount,
      packetId: packet.packetId,
    );

    expect(parsed.content, equals(packet.content));
    expect(parsed.ttlMinutes, equals(packet.ttlMinutes));
    expect(parsed.latitude, equals(packet.latitude));
    expect(parsed.longitude, equals(packet.longitude));
    expect(parsed.signalId, equals(packet.signalId));
    expect(parsed.packetId, equals(packet.packetId));
    expect(parsed.hopCount, equals(packet.hopCount));
  });

  test('MeshSignalPacket.toPayload throws when signalId missing', () {
    final packet = MeshSignalPacket(
      senderNodeId: 0x10,
      packetId: 1,
      signalId: '',
      content: 'missing id',
      ttlMinutes: 10,
      latitude: null,
      longitude: null,
      hopCount: null,
      receivedAt: DateTime.now(),
    );

    expect(packet.toPayload, throwsStateError);
  });
}
