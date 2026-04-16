// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_services/models/service_schema.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/mesh_feed/mesh_post.dart';
import 'package:socialmesh/utils/text_sanitizer.dart';

/// End-to-end regression tests for the paragraph builder crash.
///
/// Reproduces the exact Crashlytics crash:
///   FlutterError - Invalid argument(s): string is not well-formed UTF-16.
///   at _NativeParagraphBuilder.addText
///   at TextSpan.build
///   inside scrollable_positioned_list viewport
///
/// Each test feeds malformed bytes through a real decode path, puts the result
/// into a widget tree with Text/TextSpan, and pumps — proving the sanitization
/// prevents the crash.
void main() {
  group('E2E: malformed text → decode → render (paragraph builder crash)', () {
    testWidgets('message with unpaired surrogates renders without crash',
        (tester) async {
      // Simulate a message decoded from protocol with an unpaired high surrogate.
      const malformedText = 'Hello \uD800 world';

      // Sanitize as the decode pipeline now does.
      final safeText = sanitizeExternalText(malformedText);

      final message = Message(
        id: 'test-malformed-1',
        from: 42,
        to: 10,
        text: safeText,
        timestamp: DateTime.now(),
        packetId: 1,
        received: true,
      );

      // Render in a layout matching the crash stack:
      // Text inside a Row inside a ListView (scrollable list).
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 1,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: message.text,
                          children: [
                            TextSpan(
                              text: ' — from node ${message.from}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // If we get here without a FlutterError, the crash is fixed.
      expect(find.byType(RichText), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('message with null bytes from protocol renders without crash',
        (tester) async {
      // Simulate bytes that come from a mesh radio containing null bytes —
      // the exact pattern that caused the production crash.
      final protocolBytes = Uint8List.fromList([
        0x48, 0x65, 0x6C, 0x6C, 0x6F, // Hello
        0x00, // null byte (crashes paragraph builder on iOS)
        0x00, // another null
        0x57, 0x6F, 0x72, 0x6C, 0x64, // World
      ]);

      // Decode as the protocol layer does (utf8 + sanitize).
      final decoded = sanitizeExternalText(
        utf8.decode(protocolBytes, allowMalformed: true),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                ListTile(
                  title: Text(decoded),
                  subtitle: Text('Sender: Node-42'), // lint-allow: hardcoded-string
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('HelloWorld'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'mesh service schema with control chars renders without crash',
        (tester) async {
      // Build a schema with control characters embedded in field names —
      // simulates a firmware bug or malicious peer.
      final schemaBytes = _buildSchemaWithControlChars();
      final schema = ServiceSchemaCodec.decode(schemaBytes);

      expect(schema, isNotNull);

      // Render schema fields in a list (matches service detail screen layout).
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                Text(schema!.title),
                Text(schema.serviceType),
                for (final field in schema.fields) ...[
                  Text(field.name),
                  Text(field.unit),
                ],
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('mesh post with corrupt UTF-8 renders without crash',
        (tester) async {
      // Build a mesh post wire payload with corrupt UTF-8 in the content.
      final post = _decodeMeshPostWithCorruptContent();
      expect(post, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                Text(post!.content),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('multiple malformed messages in scrollable list',
        (tester) async {
      // Reproduce the exact crash scenario: multiple messages in a scrollable
      // list, some with malformed text.
      final messages = [
        'Normal message',
        sanitizeExternalText('Has \uD800 unpaired surrogate'),
        sanitizeExternalText(
          String.fromCharCodes([0x4E, 0x6F, 0x64, 0x65, 0x00, 0x7F, 0x80]),
        ),
        sanitizeExternalText('Has \uDC00 lone low surrogate'),
        'Another normal message',
        sanitizeExternalText(
          utf8.decode(
            Uint8List.fromList([0xFF, 0xFE, 0x48, 0x69]),
            allowMalformed: true,
          ),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.all(8),
                child: Text.rich(
                  TextSpan(
                    text: messages[index],
                    children: const [
                      TextSpan(
                        text: ' — sender',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(RichText), findsNWidgets(messages.length));
      expect(tester.takeException(), isNull);
    });
  });
}

/// Build a ServiceSchema binary payload with control characters in strings.
Uint8List _buildSchemaWithControlChars() {
  final builder = BytesBuilder();

  // Service type: "test\x00svc" (with null byte).
  final stBytes = [0x74, 0x65, 0x73, 0x74, 0x00, 0x73, 0x76, 0x63];
  builder.addByte(stBytes.length);
  builder.add(stBytes);

  // Title: "My\x01Service" (with SOH control).
  final titleBytes = [0x4D, 0x79, 0x01, 0x53, 0x65, 0x72, 0x76, 0x69, 0x63, 0x65];
  builder.addByte(titleBytes.length);
  builder.add(titleBytes);

  // 1 field.
  builder.addByte(1);
  // Field: id=1, type=text(0), name="Temp\x7F" (with DEL), unit="C", 0 options.
  builder.addByte(1); // id
  builder.addByte(0); // type = text
  final nameBytes = [0x54, 0x65, 0x6D, 0x70, 0x7F];
  builder.addByte(nameBytes.length);
  builder.add(nameBytes);
  final unitBytes = [0x43]; // "C"
  builder.addByte(unitBytes.length);
  builder.add(unitBytes);
  builder.addByte(0); // 0 options

  // 0 actions.
  builder.addByte(0);

  return Uint8List.fromList(builder.toBytes());
}

/// Build and decode a MeshPost wire payload with corrupt UTF-8 content.
MeshPost? _decodeMeshPostWithCorruptContent() {
  final builder = BytesBuilder();

  // Header byte: SPP version 1, kind 0x0B (mesh post).
  builder.addByte((1 << 4) | 0x0B);

  // Created at (uint32 big-endian) — recent timestamp.
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final ts = ByteData(4)..setUint32(0, now, Endian.big);
  builder.add(ts.buffer.asUint8List());

  // Flags: ttl=0, propagation=0.
  builder.addByte(0);

  // Content: "Hi" + corrupt UTF-8 bytes + "!"
  final contentBytes = [0x48, 0x69, 0xFF, 0xFE, 0xC0, 0x21];
  builder.addByte(contentBytes.length);
  builder.add(contentBytes);

  // authorNodeNum comes from the packet envelope, not the payload.
  return MeshPost.decodeFromLora(
    Uint8List.fromList(builder.toBytes()),
    42,
  );
}
