// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

library;

import 'dart:convert';
import 'dart:typed_data';

import 'mesh_service_instance.dart';
import 'mesh_service_signal_kind.dart';
import 'mesh_service_template.dart';

class MeshServiceRemoteDetailExtension {
  final DateTime? createdAt;
  final List<String> pollOptions;
  final List<int> pollVoteCounts;
  final int pollTotalOptions;
  final int? selectedPollOption;
  final List<String> listItems;
  final List<bool> listItemStates;
  final int listTotalItems;
  final MeshServiceSignalKind? signalKind;
  final String? sensorValue;
  final String? sensorUnit;
  final String? sensorSource;
  final DateTime? sensorCapturedAt;
  final int? gameTypeCode;
  final int? gameRevision;
  final int? gameTurnIndex;
  final int? gameStatusCode;
  final int? gameWinnerIndex;
  final Uint8List? gameStateBlob;

  const MeshServiceRemoteDetailExtension({
    this.createdAt,
    this.pollOptions = const [],
    this.pollVoteCounts = const [],
    this.pollTotalOptions = 0,
    this.selectedPollOption,
    this.listItems = const [],
    this.listItemStates = const [],
    this.listTotalItems = 0,
    this.signalKind,
    this.sensorValue,
    this.sensorUnit,
    this.sensorSource,
    this.sensorCapturedAt,
    this.gameTypeCode,
    this.gameRevision,
    this.gameTurnIndex,
    this.gameStatusCode,
    this.gameWinnerIndex,
    this.gameStateBlob,
  });
}

abstract final class MeshServiceDetailPayloadCodec {
  static const int _version = 1;
  static const int _noSelection = 0xFF;
  static const int _pollOptionLimit = 4;
  static const int _pollOptionBytes = 12;
  static const int _listItemLimit = 6;
  static const int _listItemBytes = 12;
  static const int _sensorValueBytes = 12;
  static const int _sensorUnitBytes = 8;
  static const int _sensorSourceBytes = 18;

  static int titleByteBudgetFor(MeshServiceType type) {
    return switch (type) {
      MeshServiceType.poll => 48,
      MeshServiceType.list => 40,
      MeshServiceType.feed => 40,
      MeshServiceType.signal => 40,
      MeshServiceType.sensor => 40,
      MeshServiceType.game => 40,
    };
  }

  static int descriptionByteBudgetFor(MeshServiceType type) {
    return switch (type) {
      MeshServiceType.poll => 24,
      MeshServiceType.list => 24,
      MeshServiceType.feed => 80,
      MeshServiceType.signal => 60,
      MeshServiceType.sensor => 40,
      MeshServiceType.game => 40,
    };
  }

  static Uint8List encodeExtension({
    required MeshServiceInstance instance,
    required Map<int, Set<int>> pollVotes,
    required Map<int, bool> checklistStates,
    required int requesterNodeId,
  }) {
    final builder = BytesBuilder(copy: false);
    builder.addByte(_version);
    _addUint32(builder, instance.createdAt.millisecondsSinceEpoch ~/ 1000);

    switch (instance.canonicalType) {
      case MeshServiceType.poll:
        final options =
            (instance.config['options'] as List<dynamic>?)?.cast<String>() ??
            const [];
        final visibleOptions = options.take(_pollOptionLimit).toList();
        builder.addByte(options.length);
        builder.addByte(visibleOptions.length);
        builder.addByte(_selectedPollOption(pollVotes, requesterNodeId));
        for (var index = 0; index < visibleOptions.length; index++) {
          _addString(builder, visibleOptions[index], _pollOptionBytes);
          _addUint16(builder, pollVotes[index]?.length ?? 0);
        }
        break;
      case MeshServiceType.list:
        final items =
            (instance.config['items'] as List<dynamic>?)?.cast<String>() ??
            const [];
        final visibleItems = items.take(_listItemLimit).toList();
        builder.addByte(items.length);
        builder.addByte(visibleItems.length);
        for (var index = 0; index < visibleItems.length; index++) {
          _addString(builder, visibleItems[index], _listItemBytes);
          builder.addByte(checklistStates[index] == true ? 1 : 0);
        }
        break;
      case MeshServiceType.signal:
        final kind = MeshServiceSignalKind.fromStorage(
          instance.config['signalKind'],
        );
        builder.addByte(kind.code);
        break;
      case MeshServiceType.sensor:
        _addString(
          builder,
          (instance.config['sensorValue'] as String?) ?? '',
          _sensorValueBytes,
        );
        _addString(
          builder,
          (instance.config['sensorUnit'] as String?) ?? '',
          _sensorUnitBytes,
        );
        _addString(
          builder,
          (instance.config['sensorSource'] as String?) ?? '',
          _sensorSourceBytes,
        );
        final capturedAtMs =
            (instance.config['sensorCapturedAtMs'] as int?) ??
            instance.createdAt.millisecondsSinceEpoch;
        _addUint32(builder, capturedAtMs ~/ 1000);
        break;
      case MeshServiceType.feed:
        break;
      case MeshServiceType.game:
        // Compact game state for remote peers. Format:
        //   gameTypeCode(1) + revision(2 LE) + turnIndex(1) +
        //   statusCode(1) + winnerIndex(1) + stateBlobLen(1) + stateBlob(N)
        final gameTypeCode = (instance.config['gameTypeCode'] as int?) ?? 0;
        final revision = (instance.config['revision'] as int?) ?? 0;
        final turnIndex = (instance.config['turnIndex'] as int?) ?? 0;
        final statusCode = (instance.config['gameStatusCode'] as int?) ?? 1;
        final winnerIndex =
            (instance.config['gameWinnerIndex'] as int?) ?? 0xFF;
        final stateBlob = _decodeStateBlob(instance.config['stateBlob']);
        builder.addByte(gameTypeCode & 0xFF);
        _addUint16(builder, revision);
        builder.addByte(turnIndex & 0xFF);
        builder.addByte(statusCode & 0xFF);
        builder.addByte(winnerIndex & 0xFF);
        final truncated = stateBlob.length > 96
            ? Uint8List.sublistView(stateBlob, 0, 96)
            : stateBlob;
        builder.addByte(truncated.length);
        builder.add(truncated);
        break;
    }

    return Uint8List.fromList(builder.toBytes());
  }

  static Uint8List _decodeStateBlob(Object? raw) {
    if (raw is Uint8List) return raw;
    if (raw is List<int>) return Uint8List.fromList(raw);
    if (raw is String && raw.isNotEmpty) {
      try {
        return Uint8List.fromList(base64Decode(raw));
      } catch (_) {
        return Uint8List(0);
      }
    }
    return Uint8List(0);
  }

  static MeshServiceRemoteDetailExtension decode(
    MeshServiceType? type,
    Uint8List payload,
  ) {
    if (type == null || payload.isEmpty) {
      return const MeshServiceRemoteDetailExtension();
    }

    var offset = 0;
    final version = payload[offset++];
    if (version != _version || offset + 4 > payload.length) {
      return const MeshServiceRemoteDetailExtension();
    }

    final createdAt = _readUint32(payload, offset);
    offset += 4;
    final createdAtDate = createdAt == 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);

    switch (type) {
      case MeshServiceType.poll:
        if (offset + 3 > payload.length) {
          return MeshServiceRemoteDetailExtension(createdAt: createdAtDate);
        }

        final totalOptions = payload[offset++];
        final shownOptions = payload[offset++];
        final selectedOption = payload[offset++];
        final options = <String>[];
        final voteCounts = <int>[];

        for (var index = 0; index < shownOptions; index++) {
          final result = _readString(payload, offset);
          if (result == null) break;
          options.add(result.value);
          offset = result.nextOffset;
          if (offset + 2 > payload.length) break;
          voteCounts.add(_readUint16(payload, offset));
          offset += 2;
        }

        return MeshServiceRemoteDetailExtension(
          createdAt: createdAtDate,
          pollOptions: options,
          pollVoteCounts: voteCounts,
          pollTotalOptions: totalOptions,
          selectedPollOption: selectedOption == _noSelection
              ? null
              : selectedOption,
        );
      case MeshServiceType.list:
        if (offset + 2 > payload.length) {
          return MeshServiceRemoteDetailExtension(createdAt: createdAtDate);
        }

        final totalItems = payload[offset++];
        final shownItems = payload[offset++];
        final items = <String>[];
        final states = <bool>[];

        for (var index = 0; index < shownItems; index++) {
          final result = _readString(payload, offset);
          if (result == null) break;
          items.add(result.value);
          offset = result.nextOffset;
          if (offset >= payload.length) break;
          states.add(payload[offset++] != 0);
        }

        return MeshServiceRemoteDetailExtension(
          createdAt: createdAtDate,
          listItems: items,
          listItemStates: states,
          listTotalItems: totalItems,
        );
      case MeshServiceType.signal:
        if (offset >= payload.length) {
          return MeshServiceRemoteDetailExtension(createdAt: createdAtDate);
        }
        return MeshServiceRemoteDetailExtension(
          createdAt: createdAtDate,
          signalKind: MeshServiceSignalKind.fromCode(payload[offset]),
        );
      case MeshServiceType.sensor:
        final value = _readString(payload, offset);
        if (value == null) {
          return MeshServiceRemoteDetailExtension(createdAt: createdAtDate);
        }
        offset = value.nextOffset;
        final unit = _readString(payload, offset);
        if (unit == null) {
          return MeshServiceRemoteDetailExtension(
            createdAt: createdAtDate,
            sensorValue: value.value,
          );
        }
        offset = unit.nextOffset;
        final source = _readString(payload, offset);
        if (source == null) {
          return MeshServiceRemoteDetailExtension(
            createdAt: createdAtDate,
            sensorValue: value.value,
            sensorUnit: unit.value,
          );
        }
        offset = source.nextOffset;
        DateTime? capturedAt;
        if (offset + 4 <= payload.length) {
          final capturedAtSeconds = _readUint32(payload, offset);
          if (capturedAtSeconds > 0) {
            capturedAt = DateTime.fromMillisecondsSinceEpoch(
              capturedAtSeconds * 1000,
            );
          }
        }
        return MeshServiceRemoteDetailExtension(
          createdAt: createdAtDate,
          sensorValue: value.value,
          sensorUnit: unit.value,
          sensorSource: source.value,
          sensorCapturedAt: capturedAt,
        );
      case MeshServiceType.feed:
        return MeshServiceRemoteDetailExtension(createdAt: createdAtDate);
      case MeshServiceType.game:
        if (offset + 7 > payload.length) {
          return MeshServiceRemoteDetailExtension(createdAt: createdAtDate);
        }
        final gameTypeCode = payload[offset++];
        final revision = _readUint16(payload, offset);
        offset += 2;
        final turnIndex = payload[offset++];
        final statusCode = payload[offset++];
        final winnerIndex = payload[offset++];
        final stateLen = payload[offset++];
        final end = offset + stateLen;
        final stateBlob = end <= payload.length
            ? Uint8List.fromList(payload.sublist(offset, end))
            : Uint8List(0);
        return MeshServiceRemoteDetailExtension(
          createdAt: createdAtDate,
          gameTypeCode: gameTypeCode,
          gameRevision: revision,
          gameTurnIndex: turnIndex,
          gameStatusCode: statusCode,
          gameWinnerIndex: winnerIndex,
          gameStateBlob: stateBlob,
        );
    }
  }

  static int _selectedPollOption(
    Map<int, Set<int>> pollVotes,
    int requesterNodeId,
  ) {
    for (final entry in pollVotes.entries) {
      if (entry.value.contains(requesterNodeId)) {
        return entry.key;
      }
    }
    return _noSelection;
  }

  static void _addUint16(BytesBuilder builder, int value) {
    final bytes = Uint8List(2);
    ByteData.sublistView(bytes).setUint16(0, value, Endian.little);
    builder.add(bytes);
  }

  static void _addUint32(BytesBuilder builder, int value) {
    final bytes = Uint8List(4);
    ByteData.sublistView(bytes).setUint32(0, value, Endian.little);
    builder.add(bytes);
  }

  static int _readUint16(Uint8List payload, int offset) {
    return ByteData.sublistView(
      payload,
      offset,
      offset + 2,
    ).getUint16(0, Endian.little);
  }

  static int _readUint32(Uint8List payload, int offset) {
    return ByteData.sublistView(
      payload,
      offset,
      offset + 4,
    ).getUint32(0, Endian.little);
  }

  static void _addString(BytesBuilder builder, String value, int maxBytes) {
    final truncated = _truncateUtf8(value, maxBytes);
    builder.addByte(truncated.length);
    builder.add(truncated);
  }

  static ({String value, int nextOffset})? _readString(
    Uint8List payload,
    int offset,
  ) {
    if (offset >= payload.length) return null;
    final length = payload[offset++];
    if (offset + length > payload.length) return null;
    return (
      value: utf8.decode(
        payload.sublist(offset, offset + length),
        allowMalformed: true,
      ),
      nextOffset: offset + length,
    );
  }

  static Uint8List _truncateUtf8(String value, int maxBytes) {
    var bytes = utf8.encode(value);
    if (bytes.length <= maxBytes) {
      return Uint8List.fromList(bytes);
    }
    bytes = bytes.sublist(0, maxBytes);
    while (bytes.isNotEmpty && (bytes.last & 0xC0) == 0x80) {
      bytes = bytes.sublist(0, bytes.length - 1);
    }
    return Uint8List.fromList(bytes);
  }
}
