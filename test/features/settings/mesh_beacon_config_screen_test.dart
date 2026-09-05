// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/settings/mesh_beacon_config_screen.dart';
import 'package:socialmesh/models/mesh_models.dart';

ChannelConfig _channel(
  int index, {
  String role = 'SECONDARY',
  List<int>? psk,
}) => ChannelConfig(
  index: index,
  name: 'ch$index',
  psk: psk ?? [index],
  role: role,
);

void main() {
  group('firstFreeChannelIndex', () {
    test('empty channel list yields slot 1', () {
      expect(firstFreeChannelIndex(const []), 1);
    });

    test('skips the primary slot even when it is the only channel', () {
      expect(firstFreeChannelIndex([_channel(0, role: 'PRIMARY')]), 1);
    });

    test('returns the first gap in the slot sequence', () {
      final channels = [_channel(0, role: 'PRIMARY'), _channel(1), _channel(3)];
      expect(firstFreeChannelIndex(channels), 2);
    });

    test('treats a disabled slot as free', () {
      final channels = [
        _channel(0, role: 'PRIMARY'),
        _channel(1),
        _channel(2, role: 'disabled'),
        _channel(3),
      ];
      expect(firstFreeChannelIndex(channels), 2);
    });

    test('returns null when every slot 1..7 is active', () {
      final channels = [
        _channel(0, role: 'PRIMARY'),
        for (var i = 1; i <= kMeshBeaconMaxChannelIndex; i++) _channel(i),
      ];
      expect(firstFreeChannelIndex(channels), isNull);
    });
  });

  group('channelWithPsk', () {
    test('matches on key bytes and ignores the name', () {
      final channels = [
        _channel(0, role: 'PRIMARY', psk: [1]),
        _channel(1, psk: [10, 20, 30]),
      ];
      final match = channelWithPsk(channels, [10, 20, 30]);
      expect(match?.index, 1);
    });

    test('ignores disabled channels', () {
      final channels = [
        _channel(2, role: 'DISABLED', psk: [7, 7]),
      ];
      expect(channelWithPsk(channels, [7, 7]), isNull);
    });

    test('requires identical length', () {
      final channels = [
        _channel(1, psk: [1, 2, 3]),
      ];
      expect(channelWithPsk(channels, [1, 2]), isNull);
      expect(channelWithPsk(channels, [1, 2, 3, 4]), isNull);
    });

    test('returns null when nothing matches', () {
      expect(
        channelWithPsk(
          [
            _channel(1, psk: [1]),
          ],
          [2],
        ),
        isNull,
      );
    });
  });
}
