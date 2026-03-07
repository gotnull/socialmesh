// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/section_header.dart';
import '../../services/haptic_service.dart';
import '../../services/protocol/sip/mrrp_codec.dart';
import '../../services/protocol/sip/mrrp_types.dart';
import 'widgets/mrrp_fixture_result_tile.dart';

// ---------------------------------------------------------------------------
// Fixture descriptor model
// ---------------------------------------------------------------------------

/// Describes a single test fixture: raw bytes + expected field values.
class _FixtureDescriptor {
  final String name;
  final Uint8List bytes;

  /// Expected field values keyed by field name. Null for fuzz cases.
  final Map<String, String>? expectedFields;

  /// Whether decode should return null (fuzz/reject case).
  final bool expectNull;

  const _FixtureDescriptor({
    required this.name,
    required this.bytes,
    this.expectedFields,
    this.expectNull = false,
  });
}

// ---------------------------------------------------------------------------
// Hex helper (local copy — test-only file cannot be imported from lib/)
// ---------------------------------------------------------------------------

Uint8List _hexToBytes(String hex) {
  final clean = hex.replaceAll(RegExp(r'\s+'), '');
  final bytes = Uint8List(clean.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

// ---------------------------------------------------------------------------
// Test vectors (from MRRP v0.1 specification)
// ---------------------------------------------------------------------------

final List<_FixtureDescriptor> _testVectors = [
  _FixtureDescriptor(
    name: 'SERVICE_ADVERT', // lint-allow: hardcoded-string
    bytes: _hexToBytes(
      '4D 52 00 01 01 00 14 00 00 00 00 00 00 00 00 00'
      '00 00 15 00'
      '02'
      '01 00 00 00 00 01 00 6D 00 00'
      '01 00 FF FF 02 01 00 8C 00 00',
    ),
    expectedFields: {
      'versionMajor': '0', // lint-allow: hardcoded-string
      'versionMinor': '1', // lint-allow: hardcoded-string
      'msgType': '0x01', // lint-allow: hardcoded-string
      'flags': '0x00', // lint-allow: hardcoded-string
      'headerLen': '20', // lint-allow: hardcoded-string
      'requestId': '0', // lint-allow: hardcoded-string
      'serviceId': '0x00000000', // lint-allow: hardcoded-string
      'actionId': '0x0000', // lint-allow: hardcoded-string
      'payloadLen': '21', // lint-allow: hardcoded-string
    },
  ),
  _FixtureDescriptor(
    name: 'SERVICE_DIR_REQ', // lint-allow: hardcoded-string
    bytes: _hexToBytes(
      '4D 52 00 01 02 01 14 00 01 00 00 00 00 00 00 00'
      '00 00 00 00',
    ),
    expectedFields: {
      'versionMajor': '0', // lint-allow: hardcoded-string
      'versionMinor': '1', // lint-allow: hardcoded-string
      'msgType': '0x02', // lint-allow: hardcoded-string
      'flags': '0x01', // lint-allow: hardcoded-string
      'headerLen': '20', // lint-allow: hardcoded-string
      'requestId': '1', // lint-allow: hardcoded-string
      'serviceId': '0x00000000', // lint-allow: hardcoded-string
      'actionId': '0x0000', // lint-allow: hardcoded-string
      'payloadLen': '0', // lint-allow: hardcoded-string
    },
  ),
  _FixtureDescriptor(
    name: 'SERVICE_DIR_RESP', // lint-allow: hardcoded-string
    bytes: _hexToBytes(
      '4D 52 00 01 03 02 14 00 01 00 00 00 00 00 00 00'
      '00 00 0B 00'
      '01'
      '02 00 00 00 00 01 00 7F 00 00',
    ),
    expectedFields: {
      'versionMajor': '0', // lint-allow: hardcoded-string
      'versionMinor': '1', // lint-allow: hardcoded-string
      'msgType': '0x03', // lint-allow: hardcoded-string
      'flags': '0x02', // lint-allow: hardcoded-string
      'headerLen': '20', // lint-allow: hardcoded-string
      'requestId': '1', // lint-allow: hardcoded-string
      'serviceId': '0x00000000', // lint-allow: hardcoded-string
      'actionId': '0x0000', // lint-allow: hardcoded-string
      'payloadLen': '11', // lint-allow: hardcoded-string
    },
  ),
  _FixtureDescriptor(
    name: 'REQUEST', // lint-allow: hardcoded-string
    bytes: _hexToBytes(
      '4D 52 00 01 10 01 14 00 42 00 00 00 01 00 FF FF'
      '01 00 04 00'
      'DE AD BE EF',
    ),
    expectedFields: {
      'versionMajor': '0', // lint-allow: hardcoded-string
      'versionMinor': '1', // lint-allow: hardcoded-string
      'msgType': '0x10', // lint-allow: hardcoded-string
      'flags': '0x01', // lint-allow: hardcoded-string
      'headerLen': '20', // lint-allow: hardcoded-string
      'requestId': '66', // lint-allow: hardcoded-string
      'serviceId': '0xffff0001', // lint-allow: hardcoded-string
      'actionId': '0x0001', // lint-allow: hardcoded-string
      'payloadLen': '4', // lint-allow: hardcoded-string
    },
  ),
  _FixtureDescriptor(
    name: 'RESPONSE', // lint-allow: hardcoded-string
    bytes: _hexToBytes(
      '4D 52 00 01 11 02 14 00 42 00 00 00 01 00 FF FF'
      '01 00 04 00'
      'DE AD BE EF',
    ),
    expectedFields: {
      'versionMajor': '0', // lint-allow: hardcoded-string
      'versionMinor': '1', // lint-allow: hardcoded-string
      'msgType': '0x11', // lint-allow: hardcoded-string
      'flags': '0x02', // lint-allow: hardcoded-string
      'headerLen': '20', // lint-allow: hardcoded-string
      'requestId': '66', // lint-allow: hardcoded-string
      'serviceId': '0xffff0001', // lint-allow: hardcoded-string
      'actionId': '0x0001', // lint-allow: hardcoded-string
      'payloadLen': '4', // lint-allow: hardcoded-string
    },
  ),
  _FixtureDescriptor(
    name: 'ERROR', // lint-allow: hardcoded-string
    bytes: _hexToBytes(
      '4D 52 00 01 12 06 17 00 42 00 00 00 00 00 DE AD'
      '01 00 00 00'
      '05 01 01',
    ),
    expectedFields: {
      'versionMajor': '0', // lint-allow: hardcoded-string
      'versionMinor': '1', // lint-allow: hardcoded-string
      'msgType': '0x12', // lint-allow: hardcoded-string
      'flags': '0x06', // lint-allow: hardcoded-string
      'headerLen': '23', // lint-allow: hardcoded-string
      'requestId': '66', // lint-allow: hardcoded-string
      'serviceId': '0xadde0000', // lint-allow: hardcoded-string
      'actionId': '0x0001', // lint-allow: hardcoded-string
      'payloadLen': '0', // lint-allow: hardcoded-string
      'tlvStatusCode': '1', // lint-allow: hardcoded-string
    },
  ),
  _FixtureDescriptor(
    name: 'CANCEL', // lint-allow: hardcoded-string
    bytes: _hexToBytes(
      '4D 52 00 01 13 00 14 00 42 00 00 00 01 00 FF FF'
      '01 00 00 00',
    ),
    expectedFields: {
      'versionMajor': '0', // lint-allow: hardcoded-string
      'versionMinor': '1', // lint-allow: hardcoded-string
      'msgType': '0x13', // lint-allow: hardcoded-string
      'flags': '0x00', // lint-allow: hardcoded-string
      'headerLen': '20', // lint-allow: hardcoded-string
      'requestId': '66', // lint-allow: hardcoded-string
      'serviceId': '0xffff0001', // lint-allow: hardcoded-string
      'actionId': '0x0001', // lint-allow: hardcoded-string
      'payloadLen': '0', // lint-allow: hardcoded-string
    },
  ),
  _FixtureDescriptor(
    name: 'REQUEST_WITH_TLV', // lint-allow: hardcoded-string
    bytes: _hexToBytes(
      '4D 52 00 01 10 01 18 00 07 00 00 00 01 00 00 00'
      '01 00 00 00'
      '02 02 0F 00',
    ),
    expectedFields: {
      'versionMajor': '0', // lint-allow: hardcoded-string
      'versionMinor': '1', // lint-allow: hardcoded-string
      'msgType': '0x10', // lint-allow: hardcoded-string
      'flags': '0x01', // lint-allow: hardcoded-string
      'headerLen': '24', // lint-allow: hardcoded-string
      'requestId': '7', // lint-allow: hardcoded-string
      'serviceId': '0x00000001', // lint-allow: hardcoded-string
      'actionId': '0x0001', // lint-allow: hardcoded-string
      'payloadLen': '0', // lint-allow: hardcoded-string
      'tlvCount': '1', // lint-allow: hardcoded-string
      'tlvRequestTtlS': '15', // lint-allow: hardcoded-string
    },
  ),
];

// ---------------------------------------------------------------------------
// Fuzz cases (malformed/boundary frames)
// ---------------------------------------------------------------------------

Uint8List _buildMaxSizeFrame() {
  final frame = Uint8List(215);
  frame[0] = 0x4D;
  frame[1] = 0x52;
  frame[2] = 0x00;
  frame[3] = 0x01;
  frame[4] = 0x10; // REQUEST
  frame[5] = 0x00;
  frame[6] = 0x14;
  frame[7] = 0x00;
  frame[8] = 0x01;
  frame[12] = 0x01;
  frame[16] = 0x01;
  frame[18] = 0xC3;
  frame[19] = 0x00;
  for (var i = 20; i < 215; i++) {
    frame[i] = 0xAA;
  }
  return frame;
}

Uint8List _buildOversizedFrame() {
  final frame = Uint8List(216);
  frame[0] = 0x4D;
  frame[1] = 0x52;
  frame[2] = 0x00;
  frame[3] = 0x01;
  frame[4] = 0x10;
  frame[5] = 0x00;
  frame[6] = 0x14;
  frame[7] = 0x00;
  frame[8] = 0x01;
  frame[12] = 0x01;
  frame[16] = 0x01;
  frame[18] = 0xC4;
  frame[19] = 0x00;
  for (var i = 20; i < 216; i++) {
    frame[i] = 0xBB;
  }
  return frame;
}

final List<_FixtureDescriptor> _fuzzCases = [
  _FixtureDescriptor(
    name: 'empty', // lint-allow: hardcoded-string
    bytes: Uint8List(0),
    expectNull: true,
  ),
  _FixtureDescriptor(
    name: 'oneByte', // lint-allow: hardcoded-string
    bytes: Uint8List.fromList([0x4D]),
    expectNull: true,
  ),
  _FixtureDescriptor(
    name: 'magicOnly', // lint-allow: hardcoded-string
    bytes: Uint8List.fromList([0x4D, 0x52]),
    expectNull: true,
  ),
  _FixtureDescriptor(
    name: 'truncatedHeader', // lint-allow: hardcoded-string
    bytes: Uint8List.fromList([
      0x4D,
      0x52,
      0x00,
      0x01,
      0x10,
      0x00,
      0x14,
      0x00,
      0x01,
      0x00,
    ]),
    expectNull: true,
  ),
  _FixtureDescriptor(
    name: 'headerLenTooSmall', // lint-allow: hardcoded-string
    bytes: Uint8List.fromList([
      0x4D,
      0x52,
      0x00,
      0x01,
      0x10,
      0x00,
      0x0A,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
    ]),
    expectNull: true,
  ),
  _FixtureDescriptor(
    name: 'headerLenExceedsData', // lint-allow: hardcoded-string
    bytes: Uint8List.fromList([
      0x4D,
      0x52,
      0x00,
      0x01,
      0x10,
      0x00,
      0x1E,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
    ]),
    expectNull: true,
  ),
  _FixtureDescriptor(
    name: 'payloadLenExceedsRemaining', // lint-allow: hardcoded-string
    bytes: Uint8List.fromList([
      0x4D,
      0x52,
      0x00,
      0x01,
      0x10,
      0x00,
      0x14,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0xFF,
      0x00,
    ]),
    expectNull: true,
  ),
  _FixtureDescriptor(
    name: 'payloadZeroWithTrailing', // lint-allow: hardcoded-string
    bytes: Uint8List.fromList([
      0x4D,
      0x52,
      0x00,
      0x01,
      0x10,
      0x00,
      0x14,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0xAA,
      0xBB,
    ]),
    expectNull: false,
  ),
  _FixtureDescriptor(
    name: 'versionMajor255', // lint-allow: hardcoded-string
    bytes: Uint8List.fromList([
      0x4D,
      0x52,
      0xFF,
      0x01,
      0x10,
      0x00,
      0x14,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
    ]),
    expectNull: true,
  ),
  _FixtureDescriptor(
    name: 'allZero', // lint-allow: hardcoded-string
    bytes: Uint8List(20),
    expectNull: true,
  ),
  _FixtureDescriptor(
    name: 'maxSizeFrame (valid)', // lint-allow: hardcoded-string
    bytes: _buildMaxSizeFrame(),
    // This is actually a valid frame (215 bytes), decode should succeed.
    expectedFields: {
      'versionMajor': '0', // lint-allow: hardcoded-string
      'versionMinor': '1', // lint-allow: hardcoded-string
      'msgType': '0x10', // lint-allow: hardcoded-string
      'headerLen': '20', // lint-allow: hardcoded-string
      'payloadLen': '195', // lint-allow: hardcoded-string
    },
  ),
  _FixtureDescriptor(
    name: 'magicInsideNonMrrp', // lint-allow: hardcoded-string
    bytes: Uint8List.fromList([
      0x00,
      0x00,
      0x4D,
      0x52,
      0x00,
      0x01,
      0x10,
      0x00,
      0x14,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
    ]),
    expectNull: true,
  ),
  _FixtureDescriptor(
    name: 'unknownMsgType', // lint-allow: hardcoded-string
    bytes: Uint8List.fromList([
      0x4D,
      0x52,
      0x00,
      0x01,
      0xFF,
      0x00,
      0x14,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
    ]),
    expectNull: true,
  ),
  _FixtureDescriptor(
    name: 'exceedsSipMtu', // lint-allow: hardcoded-string
    bytes: _buildOversizedFrame(),
    expectNull: true,
  ),
];

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Fixture Replay Panel — replays test vectors through MrrpCodec.decode()
/// and compares decoded output against expected field values.
class MrrpFixtureReplayScreen extends ConsumerStatefulWidget {
  const MrrpFixtureReplayScreen({super.key});

  @override
  ConsumerState<MrrpFixtureReplayScreen> createState() =>
      _MrrpFixtureReplayScreenState();
}

class _MrrpFixtureReplayScreenState
    extends ConsumerState<MrrpFixtureReplayScreen> {
  final List<FixtureReplayResult> _vectorResults = [];
  final List<FixtureReplayResult> _fuzzResults = [];

  void _replaySingleVector(int index) {
    final fixture = _testVectors[index];
    final decoded = MrrpCodec.decode(fixture.bytes);
    final decodeSuccess = decoded != null;

    final fields = <FieldComparison>[];
    if (decodeSuccess && fixture.expectedFields != null) {
      final actual = _extractFields(decoded);
      for (final entry in fixture.expectedFields!.entries) {
        final actualVal =
            actual[entry.key] ?? '(missing)'; // lint-allow: hardcoded-string
        fields.add(
          FieldComparison(
            name: entry.key,
            expected: entry.value,
            actual: actualVal,
            matches: entry.value == actualVal,
          ),
        );
      }
    }

    final result = FixtureReplayResult(
      name: fixture.name,
      decodeSuccess: decodeSuccess,
      fields: fields,
      expectNull: fixture.expectNull,
    );

    AppLogging.mrrpHarness(
      'MRRP_HARNESS: fixture replay ${fixture.name} -> ' // lint-allow: hardcoded-string
      '${decodeSuccess ? "decode OK" : "decode null"}'
      '${fields.isNotEmpty ? ", ${result.matchedFields}/${fields.length} fields match" : ""}',
    );

    setState(() {
      if (index < _vectorResults.length) {
        _vectorResults[index] = result;
      } else {
        // Pad if needed
        while (_vectorResults.length < index) {
          _vectorResults.add(
            FixtureReplayResult(name: '', decodeSuccess: false),
          );
        }
        _vectorResults.add(result);
      }
    });
  }

  void _replaySingleFuzz(int index) {
    final fixture = _fuzzCases[index];
    final decoded = MrrpCodec.decode(fixture.bytes);
    final decodeSuccess = decoded != null;

    final fields = <FieldComparison>[];
    if (decodeSuccess && fixture.expectedFields != null) {
      final actual = _extractFields(decoded);
      for (final entry in fixture.expectedFields!.entries) {
        final actualVal =
            actual[entry.key] ?? '(missing)'; // lint-allow: hardcoded-string
        fields.add(
          FieldComparison(
            name: entry.key,
            expected: entry.value,
            actual: actualVal,
            matches: entry.value == actualVal,
          ),
        );
      }
    }

    final result = FixtureReplayResult(
      name: fixture.name,
      decodeSuccess: decodeSuccess,
      fields: fields,
      expectNull: fixture.expectNull,
    );

    AppLogging.mrrpHarness(
      'MRRP_HARNESS: fixture replay ${fixture.name} -> ' // lint-allow: hardcoded-string
      '${decodeSuccess ? "decode OK" : "decode null"}'
      '${fields.isNotEmpty ? ", ${result.matchedFields}/${fields.length} fields match" : ""}',
    );

    setState(() {
      if (index < _fuzzResults.length) {
        _fuzzResults[index] = result;
      } else {
        while (_fuzzResults.length < index) {
          _fuzzResults.add(FixtureReplayResult(name: '', decodeSuccess: false));
        }
        _fuzzResults.add(result);
      }
    });
  }

  void _replayAll() {
    ref.read(hapticServiceProvider).trigger(HapticType.medium);

    final vectorResults = <FixtureReplayResult>[];
    for (final fixture in _testVectors) {
      vectorResults.add(_runFixture(fixture));
    }

    final fuzzResults = <FixtureReplayResult>[];
    for (final fixture in _fuzzCases) {
      fuzzResults.add(_runFixture(fixture));
    }

    final allResults = [...vectorResults, ...fuzzResults];
    final passed = allResults.where((r) => r.passed).length;
    final total = allResults.length;

    AppLogging.mrrpHarness(
      'MRRP_HARNESS: fixture replay all -> $passed/$total passed, ' // lint-allow: hardcoded-string
      '${total - passed} failed',
    );

    setState(() {
      _vectorResults
        ..clear()
        ..addAll(vectorResults);
      _fuzzResults
        ..clear()
        ..addAll(fuzzResults);
    });
  }

  FixtureReplayResult _runFixture(_FixtureDescriptor fixture) {
    final decoded = MrrpCodec.decode(fixture.bytes);
    final decodeSuccess = decoded != null;

    final fields = <FieldComparison>[];
    if (decodeSuccess && fixture.expectedFields != null) {
      final actual = _extractFields(decoded);
      for (final entry in fixture.expectedFields!.entries) {
        final actualVal =
            actual[entry.key] ?? '(missing)'; // lint-allow: hardcoded-string
        fields.add(
          FieldComparison(
            name: entry.key,
            expected: entry.value,
            actual: actualVal,
            matches: entry.value == actualVal,
          ),
        );
      }
    }

    final result = FixtureReplayResult(
      name: fixture.name,
      decodeSuccess: decodeSuccess,
      fields: fields,
      expectNull: fixture.expectNull,
    );

    AppLogging.mrrpHarness(
      'MRRP_HARNESS: fixture replay ${fixture.name} -> ' // lint-allow: hardcoded-string
      '${decodeSuccess ? "decode OK" : "decode null"}'
      '${fields.isNotEmpty ? ", ${result.matchedFields}/${fields.length} fields match" : ""}',
    );

    return result;
  }

  Map<String, String> _extractFields(dynamic frame) {
    // frame is MrrpFrame — use dynamic to avoid import cycle issues with
    // the concrete type extensions. The fields are standard properties.
    final f = frame as dynamic;
    final map = <String, String>{
      'versionMajor': '${f.versionMajor}', // lint-allow: hardcoded-string
      'versionMinor': '${f.versionMinor}', // lint-allow: hardcoded-string
      'msgType':
          '0x${(f.msgType as MrrpMessageType).code.toRadixString(16).padLeft(2, '0')}', // lint-allow: hardcoded-string
      'flags':
          '0x${(f.flags as int).toRadixString(16).padLeft(2, '0')}', // lint-allow: hardcoded-string
      'headerLen': '${f.headerLen}', // lint-allow: hardcoded-string
      'requestId': '${f.requestId}', // lint-allow: hardcoded-string
      'serviceId':
          '0x${(f.serviceId as int).toRadixString(16).padLeft(8, '0')}', // lint-allow: hardcoded-string
      'actionId':
          '0x${(f.actionId as int).toRadixString(16).padLeft(4, '0')}', // lint-allow: hardcoded-string
      'payloadLen': '${f.payloadLen}', // lint-allow: hardcoded-string
    };

    // TLV extensions
    final extensions = f.headerExtensions as List;
    if (extensions.isNotEmpty) {
      map['tlvCount'] = '${extensions.length}'; // lint-allow: hardcoded-string
      for (final ext in extensions) {
        final tlvType = ext.type as int;
        if (tlvType == MrrpTlvType.statusCode.code) {
          map['tlvStatusCode'] =
              '${ext.value[0]}'; // lint-allow: hardcoded-string
        } else if (tlvType == MrrpTlvType.requestTtlS.code) {
          final value = ext.value as Uint8List;
          final ttl = value.length >= 2
              ? value[0] |
                    (value[1] << 8) // LE uint16
              : value[0];
          map['tlvRequestTtlS'] = '$ttl'; // lint-allow: hardcoded-string
        }
      }
    }

    return map;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final allResults = [..._vectorResults, ..._fuzzResults];
    final hasResults = allResults.isNotEmpty;
    final passed = allResults.where((r) => r.passed).length;
    final total = allResults.length;

    return GlassScaffold(
      title: l10n.mrrpHarnessFixtureTitle,
      actions: [
        IconButton(
          icon: const Icon(Icons.replay),
          tooltip: l10n.mrrpHarnessFixtureReplayAll,
          onPressed: _replayAll,
        ),
      ],
      slivers: [
        // Summary bar (shown after replay)
        if (hasResults)
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing8,
            ),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spacing12),
                decoration: BoxDecoration(
                  color: passed == total
                      ? SemanticColors.success.withValues(alpha: 0.15)
                      : SemanticColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  border: Border.all(
                    color:
                        (passed == total
                                ? SemanticColors.success
                                : SemanticColors.error)
                            .withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  l10n.mrrpHarnessFixtureSummary(passed, total),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: passed == total
                        ? SemanticColors.success
                        : SemanticColors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

        // --- Test Vectors section ---
        SliverPersistentHeader(
          pinned: true,
          delegate: SectionHeaderDelegate(
            title: l10n.mrrpHarnessFixtureVectors,
            count: _testVectors.length,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final fixture = _testVectors[index];
              final result = index < _vectorResults.length
                  ? _vectorResults[index]
                  : null;

              if (result != null) {
                return MrrpFixtureResultTile(result: result);
              }

              return _UnplayedFixtureTile(
                name: fixture.name,
                byteCount: fixture.bytes.length,
                onReplay: () => _replaySingleVector(index),
              );
            }, childCount: _testVectors.length),
          ),
        ),

        // --- Fuzz Cases section ---
        SliverPersistentHeader(
          pinned: true,
          delegate: SectionHeaderDelegate(
            title: l10n.mrrpHarnessFixtureFuzz,
            count: _fuzzCases.length,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final fixture = _fuzzCases[index];
              final result = index < _fuzzResults.length
                  ? _fuzzResults[index]
                  : null;

              if (result != null) {
                return MrrpFixtureResultTile(result: result);
              }

              return _UnplayedFixtureTile(
                name: fixture.name,
                byteCount: fixture.bytes.length,
                onReplay: () => _replaySingleFuzz(index),
              );
            }, childCount: _fuzzCases.length),
          ),
        ),

        // Bottom padding
        const SliverPadding(
          padding: EdgeInsets.only(bottom: AppTheme.spacing32),
        ),
      ],
    );
  }
}

/// Tile for a fixture that hasn't been replayed yet.
class _UnplayedFixtureTile extends StatelessWidget {
  final String name;
  final int byteCount;
  final VoidCallback onReplay;

  const _UnplayedFixtureTile({
    required this.name,
    required this.byteCount,
    required this.onReplay,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(
            color: context.border.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            onTap: onReplay,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                    ),
                    child: Icon(
                      Icons.play_circle_outline,
                      size: 18,
                      color: context.accentColor,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: AppTheme.fontFamily,
                            color: context.textPrimary,
                          ),
                        ),
                        Text(
                          l10n.mrrpHarnessFixtureBytes(byteCount),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    l10n.mrrpHarnessFixtureReplay,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: context.accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
