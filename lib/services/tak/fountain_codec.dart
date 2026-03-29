// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:math';
import 'dart:typed_data';

import '../../core/logging.dart';

/// Header prepended to each encoding symbol for reassembly.
///
/// Layout: messageId (4) + symbolIndex (2) + totalSourceSymbols (2) + seed (4) = 12 bytes.
class FountainSymbolHeader {
  final int messageId;
  final int symbolIndex;
  final int totalSourceSymbols;
  final int seed;

  const FountainSymbolHeader({
    required this.messageId,
    required this.symbolIndex,
    required this.totalSourceSymbols,
    required this.seed,
  });

  static const int headerSize = 12;

  Uint8List encode() {
    final bd = ByteData(headerSize);
    bd.setUint32(0, messageId, Endian.big);
    bd.setUint16(4, symbolIndex, Endian.big);
    bd.setUint16(6, totalSourceSymbols, Endian.big);
    bd.setUint32(8, seed, Endian.big);
    return bd.buffer.asUint8List();
  }

  static FountainSymbolHeader decode(Uint8List data) {
    final bd = ByteData.sublistView(data);
    return FountainSymbolHeader(
      messageId: bd.getUint32(0, Endian.big),
      symbolIndex: bd.getUint16(4, Endian.big),
      totalSourceSymbols: bd.getUint16(6, Endian.big),
      seed: bd.getUint32(8, Endian.big),
    );
  }
}

/// A single encoding symbol: header + payload bytes.
class FountainSymbol {
  final FountainSymbolHeader header;
  final Uint8List payload;

  const FountainSymbol({required this.header, required this.payload});

  Uint8List encode() {
    final headerBytes = header.encode();
    final result = Uint8List(headerBytes.length + payload.length);
    result.setAll(0, headerBytes);
    result.setAll(headerBytes.length, payload);
    return result;
  }

  static FountainSymbol decode(Uint8List data) {
    final header = FountainSymbolHeader.decode(data);
    final payload = data.sublist(FountainSymbolHeader.headerSize);
    return FountainSymbol(header: header, payload: Uint8List.fromList(payload));
  }
}

/// Encodes payloads into fountain-coded symbols for reliable mesh delivery.
///
/// Uses systematic LT codes: first `k` symbols are raw source blocks,
/// additional symbols are XOR combinations for redundancy.
class FountainEncoder {
  /// Default symbol payload size (bytes), leaving room for header in 237-byte packets.
  static const int defaultSymbolSize = 200;

  /// Default redundancy factor (1.5 = 50% extra symbols).
  static const double defaultRedundancy = 1.5;

  static final _rng = Random();

  /// Encodes [payload] into a list of [FountainSymbol]s.
  ///
  /// Returns source symbols plus redundancy symbols. The receiver
  /// needs any `k` symbols to reconstruct the original payload.
  static List<FountainSymbol> encode(
    Uint8List payload, {
    int symbolSize = defaultSymbolSize,
    double redundancy = defaultRedundancy,
  }) {
    final k = (payload.length / symbolSize).ceil();
    final n = (k * redundancy).ceil();

    // Pad payload to exact multiple of symbolSize.
    final padded = Uint8List(k * symbolSize);
    padded.setAll(0, payload);

    // Split into source symbols.
    final sourceSymbols = <Uint8List>[];
    for (var i = 0; i < k; i++) {
      sourceSymbols.add(padded.sublist(i * symbolSize, (i + 1) * symbolSize));
    }

    final messageId = _rng.nextInt(0xFFFFFFFF);

    final result = <FountainSymbol>[];

    // First k symbols are systematic (raw source blocks).
    for (var i = 0; i < k; i++) {
      result.add(
        FountainSymbol(
          header: FountainSymbolHeader(
            messageId: messageId,
            symbolIndex: i,
            totalSourceSymbols: k,
            seed: 0, // seed=0 means systematic (direct source symbol)
          ),
          payload: sourceSymbols[i],
        ),
      );
    }

    // Additional symbols are XOR combinations.
    for (var i = k; i < n; i++) {
      final seed = _rng.nextInt(0xFFFFFFFF) | 1; // ensure non-zero
      final degree = _degree(seed, k);
      final indices = _selectIndices(seed, k, degree);
      final xored = _xorSymbols(sourceSymbols, indices, symbolSize);

      result.add(
        FountainSymbol(
          header: FountainSymbolHeader(
            messageId: messageId,
            symbolIndex: i,
            totalSourceSymbols: k,
            seed: seed,
          ),
          payload: xored,
        ),
      );
    }

    AppLogging.tak(
      'Fountain: encoding ${payload.length} byte payload -> $k source symbols, $n encoding symbols ($symbolSize byte symbols)',
    );

    return result;
  }

  /// Determines the degree (number of source symbols to XOR) from a seed.
  static int _degree(int seed, int k) {
    if (k <= 1) return 1;
    // Simple degree distribution biased towards low degree for small k.
    final r = Random(seed);
    final d = r.nextInt(k) + 1;
    // Bias towards degree 1-2 for better peeling decode.
    return d <= 2 ? d : (r.nextBool() ? 2 : d);
  }

  /// Selects [degree] distinct source symbol indices using [seed].
  static List<int> _selectIndices(int seed, int k, int degree) {
    final r = Random(seed + 1);
    final indices = <int>{};
    while (indices.length < degree) {
      indices.add(r.nextInt(k));
    }
    return indices.toList();
  }

  /// XORs the source symbols at [indices] together.
  static Uint8List _xorSymbols(
    List<Uint8List> sources,
    List<int> indices,
    int symbolSize,
  ) {
    final result = Uint8List(symbolSize);
    for (final idx in indices) {
      for (var b = 0; b < symbolSize; b++) {
        result[b] ^= sources[idx][b];
      }
    }
    return result;
  }
}

/// Tracks state for a single in-progress fountain decode session.
class _DecodeSession {
  final int messageId;
  final int k;
  final int symbolSize;
  final int originalPayloadLength;
  final DateTime created;
  final Map<int, Uint8List> receivedSource = {};
  final List<FountainSymbol> paritySymbols = [];

  _DecodeSession({
    required this.messageId,
    required this.k,
    required this.symbolSize,
    required this.originalPayloadLength,
  }) : created = DateTime.now();
}

/// Decodes fountain-coded symbols back into the original payload.
class FountainDecoder {
  /// Decode timeout (discard incomplete sessions after this duration).
  static const Duration timeout = Duration(seconds: 60);

  /// Maximum concurrent decode sessions.
  static const int maxSessions = 10;

  final Map<int, _DecodeSession> _sessions = {};

  /// Adds a received [symbol] to the decoder.
  ///
  /// Returns the decoded payload when enough symbols are received,
  /// or `null` if more symbols are needed.
  Uint8List? addSymbol(FountainSymbol symbol) {
    _evictExpired();

    final hdr = symbol.header;
    final session = _sessions.putIfAbsent(hdr.messageId, () {
      _evictOldestIfFull();
      return _DecodeSession(
        messageId: hdr.messageId,
        k: hdr.totalSourceSymbols,
        symbolSize: symbol.payload.length,
        originalPayloadLength: 0,
      );
    });

    // Systematic symbol (seed == 0): direct source block.
    if (hdr.seed == 0 && hdr.symbolIndex < session.k) {
      session.receivedSource[hdr.symbolIndex] = symbol.payload;
    } else {
      session.paritySymbols.add(symbol);
    }

    AppLogging.tak(
      'Fountain: received symbol ${hdr.symbolIndex}/${session.k} for message ${hdr.messageId.toRadixString(16)} '
      '(have ${session.receivedSource.length} source + ${session.paritySymbols.length} parity)',
    );

    // Try to decode.
    final decoded = _tryDecode(session);
    if (decoded != null) {
      _sessions.remove(hdr.messageId);
      AppLogging.tak(
        'Fountain: decoded message ${hdr.messageId.toRadixString(16)} '
        'from ${session.receivedSource.length} source + ${session.paritySymbols.length} parity symbols '
        '(${decoded.length} bytes recovered)',
      );
    }

    return decoded;
  }

  /// Returns IDs of timed-out sessions that were evicted.
  List<int> evictExpired() {
    return _evictExpired();
  }

  /// Number of active decode sessions.
  int get activeSessionCount => _sessions.length;

  List<int> _evictExpired() {
    final now = DateTime.now();
    final expired = <int>[];
    _sessions.removeWhere((id, session) {
      final isExpired = now.difference(session.created) > timeout;
      if (isExpired) {
        expired.add(id);
        AppLogging.tak(
          'Fountain: decode timeout for message ${id.toRadixString(16)} '
          'after ${timeout.inSeconds}s '
          '(received ${session.receivedSource.length}/${session.k} symbols)',
        );
      }
      return isExpired;
    });
    return expired;
  }

  void _evictOldestIfFull() {
    while (_sessions.length >= maxSessions) {
      final oldest = _sessions.entries.reduce(
        (a, b) => a.value.created.isBefore(b.value.created) ? a : b,
      );
      _sessions.remove(oldest.key);
      AppLogging.tak(
        'Fountain: evicted oldest session ${oldest.key.toRadixString(16)} (max $maxSessions sessions)',
      );
    }
  }

  /// Attempts to decode the session using available symbols.
  ///
  /// Uses iterative peeling: resolve degree-1 parity symbols first,
  /// then propagate to resolve higher-degree symbols.
  Uint8List? _tryDecode(_DecodeSession session) {
    if (session.receivedSource.length == session.k) {
      return _assemblePayload(session);
    }

    // Iterative peeling decoder.
    var progress = true;
    while (progress) {
      progress = false;
      for (final parity in List.of(session.paritySymbols)) {
        final hdr = parity.header;
        if (hdr.seed == 0) continue;

        final degree = FountainEncoder._degree(hdr.seed, session.k);
        final indices = FountainEncoder._selectIndices(
          hdr.seed,
          session.k,
          degree,
        );

        // Find unknown indices.
        final unknown = indices
            .where((i) => !session.receivedSource.containsKey(i))
            .toList();

        if (unknown.length == 1) {
          // Can resolve: XOR known sources with parity to get missing.
          final resolved = Uint8List(session.symbolSize);
          resolved.setAll(0, parity.payload);
          for (final i in indices) {
            if (session.receivedSource.containsKey(i)) {
              for (var b = 0; b < session.symbolSize; b++) {
                resolved[b] ^= session.receivedSource[i]![b];
              }
            }
          }
          session.receivedSource[unknown.first] = resolved;
          session.paritySymbols.remove(parity);
          progress = true;
        } else if (unknown.isEmpty) {
          // Already resolved, discard parity.
          session.paritySymbols.remove(parity);
        }
      }
    }

    if (session.receivedSource.length == session.k) {
      return _assemblePayload(session);
    }

    return null;
  }

  Uint8List _assemblePayload(_DecodeSession session) {
    final result = Uint8List(session.k * session.symbolSize);
    for (var i = 0; i < session.k; i++) {
      result.setAll(i * session.symbolSize, session.receivedSource[i]!);
    }
    return result;
  }
}
