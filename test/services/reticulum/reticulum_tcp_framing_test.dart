// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/reticulum/reticulum_tcp_framing.dart';

void main() {
  group('ReticulumTcpFraming.encodeFrame', () {
    test('wraps body with 0x7E ... 0x7E', () {
      final out = ReticulumTcpFraming.encodeFrame(<int>[
        for (var i = 0; i < 25; i++) i,
      ]);
      expect(out.first, hdlcFlag);
      expect(out.last, hdlcFlag);
    });

    test('escapes 0x7D as 0x7D 0x5D', () {
      final out = ReticulumTcpFraming.encodeFrame(<int>[hdlcEsc]);
      expect(out, Uint8List.fromList(<int>[hdlcFlag, 0x7D, 0x5D, hdlcFlag]));
    });

    test('escapes 0x7E as 0x7D 0x5E', () {
      final out = ReticulumTcpFraming.encodeFrame(<int>[hdlcFlag]);
      expect(out, Uint8List.fromList(<int>[hdlcFlag, 0x7D, 0x5E, hdlcFlag]));
    });

    test('escapes both 0x7D and 0x7E in mixed body', () {
      final out = ReticulumTcpFraming.encodeFrame(<int>[
        0x01,
        hdlcEsc,
        0x02,
        hdlcFlag,
        0x03,
      ]);
      expect(
        out,
        Uint8List.fromList(<int>[
          hdlcFlag,
          0x01,
          0x7D, 0x5D, // escaped 0x7D
          0x02,
          0x7D, 0x5E, // escaped 0x7E
          0x03,
          hdlcFlag,
        ]),
      );
    });

    test('escape order — 0x7D escapes do not get re-escaped', () {
      // 0x7D MUST be escaped before 0x7E. If the order were reversed,
      // the 0x7D produced by escaping 0x7E would be re-escaped on the
      // second pass and the encoding would corrupt.
      final out = ReticulumTcpFraming.encodeFrame(<int>[hdlcFlag, hdlcEsc]);
      expect(
        out,
        Uint8List.fromList(<int>[
          hdlcFlag,
          0x7D, 0x5E, // escaped FLAG
          0x7D, 0x5D, // escaped ESC
          hdlcFlag,
        ]),
      );
    });

    test('empty body still produces FLAG FLAG', () {
      final out = ReticulumTcpFraming.encodeFrame(const <int>[]);
      expect(out, Uint8List.fromList(<int>[hdlcFlag, hdlcFlag]));
    });
  });

  group('HdlcFrameDecoder — happy path', () {
    test('emits a frame longer than min size in one feed', () {
      final body = Uint8List.fromList(<int>[for (var i = 0; i < 25; i++) i]);
      final wire = ReticulumTcpFraming.encodeFrame(body);
      final dec = HdlcFrameDecoder();
      final frames = dec.feed(wire);
      expect(frames, hasLength(1));
      expect(frames.single, body);
    });

    test('drops frame whose unescaped body is exactly 19 bytes', () {
      // minFrameSize gate uses `<=`: 19 must be dropped, 20 must pass.
      final body19 = Uint8List.fromList(List<int>.filled(19, 0xAA));
      final wire = ReticulumTcpFraming.encodeFrame(body19);
      final dec = HdlcFrameDecoder();
      final frames = dec.feed(wire);
      expect(frames, isEmpty);
      expect(dec.droppedUndersize, 1);
    });

    test('passes frame whose unescaped body is 20 bytes', () {
      final body20 = Uint8List.fromList(List<int>.filled(20, 0xBB));
      final wire = ReticulumTcpFraming.encodeFrame(body20);
      final dec = HdlcFrameDecoder();
      final frames = dec.feed(wire);
      expect(frames, hasLength(1));
      expect(frames.single, body20);
      expect(dec.droppedUndersize, 0);
    });
  });

  group('HdlcFrameDecoder — split recv chunks (persistent buffer)', () {
    test(
      'feeding a single 20-byte frame one byte at a time emits exactly one frame',
      () {
        final body = Uint8List.fromList(List<int>.filled(20, 0xCC));
        final wire = ReticulumTcpFraming.encodeFrame(body);
        final dec = HdlcFrameDecoder();
        final emitted = <Uint8List>[];
        for (var i = 0; i < wire.length; i++) {
          emitted.addAll(dec.feed(<int>[wire[i]]));
        }
        expect(emitted, hasLength(1));
        expect(emitted.single, body);
      },
    );

    test('split at every possible boundary always yields one frame', () {
      final body = Uint8List.fromList(<int>[
        for (var i = 0; i < 30; i++) i,
        hdlcEsc, // ensure escape sequences in payload
        hdlcFlag,
      ]);
      final wire = ReticulumTcpFraming.encodeFrame(body);
      for (var split = 1; split < wire.length; split++) {
        final dec = HdlcFrameDecoder();
        final part1 = wire.sublist(0, split);
        final part2 = wire.sublist(split);
        final out = <Uint8List>[...dec.feed(part1), ...dec.feed(part2)];
        expect(out, hasLength(1), reason: 'split at $split');
        expect(out.single, body, reason: 'split at $split');
      }
    });
  });

  group('HdlcFrameDecoder — closing flag reused as next opener', () {
    test('three FLAGs encoding two adjacent frames decode to two frames', () {
      // Wire layout: 7E body1 7E body2 7E
      // (the middle 7E is BOTH the close of frame 1 and the open of
      // frame 2 — upstream's `frame_buffer = frame_buffer[end:]`
      // semantics)
      final body1 = Uint8List.fromList(List<int>.filled(20, 0xDD));
      final body2 = Uint8List.fromList(List<int>.filled(22, 0xEE));
      final wire = Uint8List.fromList(<int>[
        ...ReticulumTcpFraming.encodeFrame(body1),
        ...ReticulumTcpFraming.encodeFrame(
          body2,
        ).sublist(1), // skip leading FLAG
      ]);
      // Sanity: there should be exactly 3 FLAGs.
      final flags = wire.where((b) => b == hdlcFlag).length;
      expect(flags, 3);

      final dec = HdlcFrameDecoder();
      final out = dec.feed(wire);
      expect(out, hasLength(2));
      expect(out[0], body1);
      expect(out[1], body2);
    });

    test('two back-to-back encoded frames (4 FLAGs) also decode to two', () {
      // Wire layout: 7E body1 7E 7E body2 7E
      // The close of frame 1 is followed immediately by the open of
      // frame 2. The decoder finds an empty inter-FLAG region first
      // (under min-size, drops it) then the real frame 2.
      final body1 = Uint8List.fromList(List<int>.filled(20, 0xAA));
      final body2 = Uint8List.fromList(List<int>.filled(22, 0xBB));
      final wire = Uint8List.fromList(<int>[
        ...ReticulumTcpFraming.encodeFrame(body1),
        ...ReticulumTcpFraming.encodeFrame(body2),
      ]);
      final flags = wire.where((b) => b == hdlcFlag).length;
      expect(flags, 4);

      final dec = HdlcFrameDecoder();
      final out = dec.feed(wire);
      expect(out, hasLength(2));
      expect(out[0], body1);
      expect(out[1], body2);
      // The empty inter-FLAG region is interpreted as a 0-byte frame
      // and dropped under the min-size gate.
      expect(dec.droppedUndersize, 1);
    });
  });

  group('HdlcFrameDecoder — malformed escape', () {
    test('throws on ESC followed by an invalid byte', () {
      // Payload between FLAGs: 0x7D 0x99 — invalid (0x99 is neither
      // 0x5D nor 0x5E).
      final wire = Uint8List.fromList(<int>[hdlcFlag, 0x7D, 0x99, hdlcFlag]);
      final dec = HdlcFrameDecoder();
      expect(() => dec.feed(wire), throwsA(isA<HdlcDecodeError>()));
    });

    test('throws on dangling ESC at end of frame (no follower byte)', () {
      // Payload between FLAGs: ... 0x7D — escape introduced but the
      // following byte is the closing FLAG, so unescape has nothing
      // to consume.
      final wire = Uint8List.fromList(<int>[
        hdlcFlag,
        0x01,
        0x02,
        0x03,
        0x7D,
        hdlcFlag,
      ]);
      final dec = HdlcFrameDecoder();
      expect(() => dec.feed(wire), throwsA(isA<HdlcDecodeError>()));
    });
  });

  group('HdlcFrameDecoder — buffer hygiene', () {
    test('pre-FLAG junk before the first opening FLAG is discarded', () {
      // We don't want to hold unbounded garbage in memory if the
      // remote sends bytes before we ever see a FLAG.
      final body = Uint8List.fromList(List<int>.filled(20, 0xFF));
      final wire = ReticulumTcpFraming.encodeFrame(body);
      final dec = HdlcFrameDecoder();
      // Feed 100 bytes of pre-FLAG junk first.
      final junk = Uint8List(100);
      expect(dec.feed(junk), isEmpty);
      // Then the real frame.
      expect(dec.feed(wire), [body]);
    });

    test('opening-FLAG-only buffer is preserved across feeds', () {
      final body = Uint8List.fromList(List<int>.filled(25, 0x5A));
      final wire = ReticulumTcpFraming.encodeFrame(body);
      final dec = HdlcFrameDecoder();
      // First feed: opening FLAG plus partial payload.
      expect(dec.feed(wire.sublist(0, wire.length - 1)), isEmpty);
      // Second feed: the closing FLAG completes the frame.
      expect(dec.feed(wire.sublist(wire.length - 1)), [body]);
    });
  });

  group('Round-trip', () {
    test('encode then decode reproduces every body unchanged', () {
      final bodies = <Uint8List>[
        Uint8List.fromList(List<int>.filled(20, 0)),
        Uint8List.fromList(<int>[for (var i = 0; i < 64; i++) i]),
        Uint8List.fromList(<int>[
          for (var i = 0; i < 100; i++) (i * 7 + 3) & 0xFF,
        ]),
        Uint8List.fromList(<int>[
          // pathological: alternating ESC and FLAG
          for (var i = 0; i < 30; i++) i.isEven ? hdlcEsc : hdlcFlag,
        ]),
      ];
      for (final body in bodies) {
        final wire = ReticulumTcpFraming.encodeFrame(body);
        final dec = HdlcFrameDecoder();
        final out = dec.feed(wire);
        expect(out, hasLength(1), reason: 'body length=${body.length}');
        expect(out.single, body);
      }
    });
  });

  group('Real capture round-trip', () {
    test('tcp_capture_v1.bin decodes to a single frame', () {
      // 198-byte capture from a real rnsd TCPClientInterface
      // connecting to a passive dumper on 127.0.0.1:4242. Anchor for
      // the codec — full provenance in
      // tools/rns_bridge/tcp_capture/FINDINGS.md.
      final fixture = File(
        'test/fixtures/reticulum/tcp_capture_v1.bin',
      ).readAsBytesSync();
      expect(fixture, hasLength(198));
      expect(fixture.first, hdlcFlag);
      expect(fixture.last, hdlcFlag);

      final dec = HdlcFrameDecoder();
      final out = dec.feed(fixture);
      expect(out, hasLength(1), reason: 'expected one HDLC frame');
      // Unescaping one 0x7D 0x5D pair → body is 1 byte shorter than
      // the inter-FLAG region (196 escaped bytes → 195 unescaped).
      expect(out.single.length, 195);
    });

    test('tcp_capture_v1.bin re-encodes byte-for-byte', () {
      final fixture = File(
        'test/fixtures/reticulum/tcp_capture_v1.bin',
      ).readAsBytesSync();
      final dec = HdlcFrameDecoder();
      final body = dec.feed(fixture).single;
      final reEncoded = ReticulumTcpFraming.encodeFrame(body);
      expect(reEncoded, fixture);
    });
  });
}
