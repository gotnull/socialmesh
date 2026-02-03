import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:socialmesh/generated/meshtastic/channel.pb.dart';

void main() {
  // Generate a CORRECT channel protobuf
  debugPrint('=== Generating correct Channel protobuf ===');

  // Create a random 16-byte PSK
  final random = Random.secure();
  final psk = List<int>.generate(16, (_) => random.nextInt(256));
  debugPrint(
    'PSK (16 bytes): ${psk.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
  );

  // Create ChannelSettings
  final settings = ChannelSettings()
    ..psk = psk
    ..name = 'TestChannel';

  debugPrint(
    'Settings proto: ${settings.writeToBuffer().map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
  );

  // Create Channel with index=0 and role=SECONDARY
  final channel = Channel()
    ..index = 0
    ..settings = settings
    ..role = Channel_Role.SECONDARY;

  final channelBytes = channel.writeToBuffer();
  debugPrint(
    'Channel proto (${channelBytes.length} bytes): ${channelBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
  );

  final b64 = base64Encode(channelBytes);
  debugPrint('Base64: $b64');
  debugPrint('');
  debugPrint('Deep link: socialmesh://channel/$b64');

  // Verify we can parse it back
  debugPrint('');
  debugPrint('=== Verify parsing ===');
  final parsed = Channel.fromBuffer(channelBytes);
  debugPrint('Index: ${parsed.index}');
  debugPrint('Role: ${parsed.role}');
  debugPrint('Name: "${parsed.settings.name}"');
  debugPrint('PSK length: ${parsed.settings.psk.length}');
  debugPrint(
    'PSK: ${parsed.settings.psk.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
  );
}
