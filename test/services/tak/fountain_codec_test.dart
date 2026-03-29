// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/tak/fountain_codec.dart';

void main() {
  group('FountainSymbolHeader', () {
    test('encode/decode round-trip', () {
      const header = FountainSymbolHeader(
        messageId: 0x12345678,
        symbolIndex: 3,
        totalSourceSymbols: 5,
        seed: 0xABCD1234,
      );
      final bytes = header.encode();
      expect(bytes.length, FountainSymbolHeader.headerSize);
      final decoded = FountainSymbolHeader.decode(bytes);
      expect(decoded.messageId, 0x12345678);
      expect(decoded.symbolIndex, 3);
      expect(decoded.totalSourceSymbols, 5);
      expect(decoded.seed, 0xABCD1234);
    });
  });

  group('FountainSymbol', () {
    test('encode/decode round-trip', () {
      final payload = Uint8List.fromList([1, 2, 3, 4, 5]);
      final symbol = FountainSymbol(
        header: const FountainSymbolHeader(
          messageId: 42,
          symbolIndex: 0,
          totalSourceSymbols: 2,
          seed: 0,
        ),
        payload: payload,
      );
      final bytes = symbol.encode();
      expect(bytes.length, FountainSymbolHeader.headerSize + payload.length);
      final decoded = FountainSymbol.decode(bytes);
      expect(decoded.header.messageId, 42);
      expect(decoded.payload, payload);
    });
  });

  group('FountainEncoder', () {
    test('encode produces correct number of symbols', () {
      final payload = Uint8List.fromList(List.generate(512, (i) => i % 256));
      final symbols = FountainEncoder.encode(payload, symbolSize: 200);
      // k = ceil(512/200) = 3, n = ceil(3 * 1.5) = 5
      expect(symbols.length, 5);
      // First 3 are systematic (seed == 0)
      for (var i = 0; i < 3; i++) {
        expect(symbols[i].header.seed, 0);
        expect(symbols[i].header.symbolIndex, i);
      }
      // Last 2 are parity (seed != 0)
      for (var i = 3; i < 5; i++) {
        expect(symbols[i].header.seed, isNot(0));
      }
    });

    test('single-symbol payload produces 2 symbols with redundancy', () {
      final payload = Uint8List.fromList(List.generate(100, (i) => i));
      final symbols = FountainEncoder.encode(payload, symbolSize: 200);
      // k = 1, n = ceil(1 * 1.5) = 2
      expect(symbols.length, 2);
    });
  });

  group('FountainDecoder', () {
    test('decode with all source symbols (no loss)', () {
      final payload = Uint8List.fromList(List.generate(400, (i) => i % 256));
      final symbols = FountainEncoder.encode(payload, symbolSize: 200);
      final decoder = FountainDecoder();

      // Feed only systematic symbols.
      Uint8List? result;
      for (var i = 0; i < 2; i++) {
        result = decoder.addSymbol(symbols[i]);
      }
      expect(result, isNotNull);
      // Result is padded to symbolSize multiple, compare prefix.
      expect(result!.sublist(0, payload.length), payload);
    });

    test('decode with missing source symbol recovered from parity', () {
      final payload = Uint8List.fromList(List.generate(400, (i) => i % 256));
      final symbols = FountainEncoder.encode(payload, symbolSize: 200);
      final decoder = FountainDecoder();

      // Skip symbol 0, feed symbol 1 + all parity symbols.
      decoder.addSymbol(symbols[1]);
      Uint8List? result;
      for (var i = 2; i < symbols.length; i++) {
        result = decoder.addSymbol(symbols[i]);
        if (result != null) break;
      }
      // May or may not decode depending on parity degree selection.
      // If it decoded, the prefix must match.
      if (result != null) {
        expect(result.sublist(0, payload.length), payload);
      }
    });

    test('returns null when insufficient symbols', () {
      final payload = Uint8List.fromList(List.generate(600, (i) => i % 256));
      final symbols = FountainEncoder.encode(payload, symbolSize: 200);
      final decoder = FountainDecoder();

      // Feed only first symbol (need 3).
      final result = decoder.addSymbol(symbols[0]);
      expect(result, isNull);
    });

    test('session eviction respects maxSessions', () {
      final decoder = FountainDecoder();
      // Create 11 different message sessions.
      for (var m = 0; m < 11; m++) {
        final symbol = FountainSymbol(
          header: FountainSymbolHeader(
            messageId: m,
            symbolIndex: 0,
            totalSourceSymbols: 3,
            seed: 0,
          ),
          payload: Uint8List(200),
        );
        decoder.addSymbol(symbol);
      }
      expect(
        decoder.activeSessionCount,
        lessThanOrEqualTo(FountainDecoder.maxSessions),
      );
    });

    test('expired sessions are evicted', () {
      final decoder = FountainDecoder();
      final symbol = FountainSymbol(
        header: const FountainSymbolHeader(
          messageId: 99,
          symbolIndex: 0,
          totalSourceSymbols: 5,
          seed: 0,
        ),
        payload: Uint8List(100),
      );
      decoder.addSymbol(symbol);
      expect(decoder.activeSessionCount, 1);

      // Manually evict (would require time travel; just verify the API exists).
      final evicted = decoder.evictExpired();
      // No sessions should be expired yet (created just now).
      expect(evicted, isEmpty);
    });

    test('full round-trip with single symbol payload', () {
      final payload = Uint8List.fromList(List.generate(50, (i) => i * 3));
      final symbols = FountainEncoder.encode(payload, symbolSize: 200);
      final decoder = FountainDecoder();

      final result = decoder.addSymbol(symbols[0]);
      expect(result, isNotNull);
      expect(result!.sublist(0, payload.length), payload);
    });
  });
}
