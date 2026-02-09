import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodes/node_display_name_resolver.dart';

void main() {
  group('NodeDisplayNameResolver.resolve', () {
    test('prefers longName over shortName and fallback', () {
      final name = NodeDisplayNameResolver.resolve(
        nodeNum: 0x5ed6,
        longName: 'Wismesh',
        shortName: '5ed6',
        bleName: 'Meshtastic_5ed6',
      );
      expect(name, 'Wismesh');
    });

    test('prefers shortName when longName is missing', () {
      final name = NodeDisplayNameResolver.resolve(
        nodeNum: 0x5ed6,
        longName: '   ',
        shortName: '5ed6',
        bleName: 'Meshtastic_5ed6',
      );
      expect(name, '5ed6');
    });

    test('ignores BLE default name and uses default fallback', () {
      final name = NodeDisplayNameResolver.resolve(
        nodeNum: 0x5ed6,
        longName: null,
        shortName: null,
        bleName: 'Meshtastic_5ed6',
      );
      expect(name, 'Meshtastic 5ED6');
    });

    test('uses non-default BLE name when no longName or shortName', () {
      final name = NodeDisplayNameResolver.resolve(
        nodeNum: 0x5ed6,
        longName: null,
        shortName: null,
        bleName: 'Wismesh BLE',
      );
      expect(name, 'Wismesh BLE');
    });

    test('firmware default "Meshtastic XXXX" is a valid display name', () {
      final name = NodeDisplayNameResolver.resolve(
        nodeNum: 0x5ed6,
        longName: 'Meshtastic 5ED6',
        shortName: '5ED6',
      );
      expect(name, 'Meshtastic 5ED6');
    });

    test('firmware default "Meshtastic xxxx" case-insensitive is valid', () {
      final name = NodeDisplayNameResolver.resolve(
        nodeNum: 0xabcd,
        longName: 'Meshtastic abcd',
        shortName: 'abcd',
      );
      expect(name, 'Meshtastic abcd');
    });

    test('filters hex ID placeholder "!AABBCCDD"', () {
      final name = NodeDisplayNameResolver.resolve(
        nodeNum: 0xAABBCCDD,
        longName: '!AABBCCDD',
        shortName: null,
      );
      expect(name, 'Meshtastic CCDD');
    });

    test('filters legacy decimal fallback "Node 12345678"', () {
      final name = NodeDisplayNameResolver.resolve(
        nodeNum: 12345678,
        longName: 'Node 12345678',
        shortName: null,
      );
      expect(name, NodeDisplayNameResolver.defaultName(12345678));
    });

    test('filters BLE underscore name "Meshtastic_XXXX"', () {
      final name = NodeDisplayNameResolver.resolve(
        nodeNum: 0x1234,
        longName: 'Meshtastic_1234',
        shortName: null,
      );
      expect(name, 'Meshtastic 1234');
    });

    test('does not filter custom names that contain "Meshtastic"', () {
      final name = NodeDisplayNameResolver.resolve(
        nodeNum: 0x1234,
        longName: 'My Meshtastic Node',
        shortName: null,
      );
      expect(name, 'My Meshtastic Node');
    });

    test('does not filter custom names that look like hex', () {
      final name = NodeDisplayNameResolver.resolve(
        nodeNum: 0xCAFE,
        longName: null,
        shortName: 'CAFE',
      );
      expect(name, 'CAFE');
    });

    test('falls back to "Meshtastic XXXX" when all names are null', () {
      final name = NodeDisplayNameResolver.resolve(
        nodeNum: 0x5AAD5ED6,
        longName: null,
        shortName: null,
      );
      expect(name, 'Meshtastic 5ED6');
    });

    test('falls back to "Meshtastic XXXX" when all names are empty', () {
      final name = NodeDisplayNameResolver.resolve(
        nodeNum: 0x5AAD5ED6,
        longName: '',
        shortName: '',
      );
      expect(name, 'Meshtastic 5ED6');
    });

    test('falls back to "Meshtastic XXXX" when names are only whitespace', () {
      final name = NodeDisplayNameResolver.resolve(
        nodeNum: 0x5AAD5ED6,
        longName: '   ',
        shortName: '  ',
      );
      expect(name, 'Meshtastic 5ED6');
    });

    test('uses explicit fallback when provided', () {
      final name = NodeDisplayNameResolver.resolve(
        nodeNum: 0x5ed6,
        longName: null,
        shortName: null,
        fallback: 'Custom Fallback',
      );
      expect(name, 'Custom Fallback');
    });

    test('does not use explicit fallback when longName is valid', () {
      final name = NodeDisplayNameResolver.resolve(
        nodeNum: 0x5ed6,
        longName: 'RealName',
        shortName: null,
        fallback: 'Custom Fallback',
      );
      expect(name, 'RealName');
    });
  });

  group('NodeDisplayNameResolver.defaultName', () {
    test('returns "Meshtastic XXXX" with last 4 hex digits', () {
      expect(
        NodeDisplayNameResolver.defaultName(0x5AAD5ED6),
        'Meshtastic 5ED6',
      );
    });

    test('pads short node numbers to 4 hex digits', () {
      expect(NodeDisplayNameResolver.defaultName(0xAB), 'Meshtastic 00AB');
    });

    test('handles single digit node number', () {
      expect(NodeDisplayNameResolver.defaultName(0xF), 'Meshtastic 000F');
    });

    test('uses last 4 hex digits for large node numbers', () {
      expect(
        NodeDisplayNameResolver.defaultName(0xAABBCCDD),
        'Meshtastic CCDD',
      );
    });
  });

  group('NodeDisplayNameResolver.shortHex', () {
    test('returns last 4 hex digits uppercased', () {
      expect(NodeDisplayNameResolver.shortHex(0x5AAD5ED6), '5ED6');
    });

    test('pads short values to 4 digits', () {
      expect(NodeDisplayNameResolver.shortHex(0xAB), '00AB');
    });

    test('returns exactly 4 chars for 4-digit hex', () {
      expect(NodeDisplayNameResolver.shortHex(0x1234), '1234');
    });

    test('truncates to last 4 for 8-digit hex', () {
      expect(NodeDisplayNameResolver.shortHex(0xDEADBEEF), 'BEEF');
    });
  });

  group('NodeDisplayNameResolver.defaultShortName', () {
    test('matches shortHex output', () {
      const nodeNum = 0x5AAD5ED6;
      expect(
        NodeDisplayNameResolver.defaultShortName(nodeNum),
        NodeDisplayNameResolver.shortHex(nodeNum),
      );
    });
  });

  group('NodeDisplayNameResolver.sanitizeName', () {
    test('returns null for null input', () {
      expect(NodeDisplayNameResolver.sanitizeName(null), isNull);
    });

    test('returns null for empty string', () {
      expect(NodeDisplayNameResolver.sanitizeName(''), isNull);
    });

    test('returns null for whitespace-only string', () {
      expect(NodeDisplayNameResolver.sanitizeName('   '), isNull);
    });

    test('returns null for BLE default "Meshtastic_XXXX"', () {
      expect(NodeDisplayNameResolver.sanitizeName('Meshtastic_5ED6'), isNull);
    });

    test('returns null for hex ID placeholder "!AABBCCDD"', () {
      expect(NodeDisplayNameResolver.sanitizeName('!aabbccdd'), isNull);
    });

    test('returns null for short hex ID placeholder "!AB"', () {
      expect(NodeDisplayNameResolver.sanitizeName('!AB'), isNull);
    });

    test('returns null for legacy decimal fallback "Node 12345678"', () {
      expect(NodeDisplayNameResolver.sanitizeName('Node 12345678'), isNull);
    });

    test('passes through firmware default "Meshtastic XXXX" (space)', () {
      expect(
        NodeDisplayNameResolver.sanitizeName('Meshtastic 5ED6'),
        'Meshtastic 5ED6',
      );
    });

    test('passes through genuine user name', () {
      expect(NodeDisplayNameResolver.sanitizeName('MyNode'), 'MyNode');
    });

    test('passes through short hex names like "CAFE"', () {
      expect(NodeDisplayNameResolver.sanitizeName('CAFE'), 'CAFE');
    });

    test(
      'passes through names containing "Node" that are not decimal fallback',
      () {
        expect(
          NodeDisplayNameResolver.sanitizeName('Node Alpha'),
          'Node Alpha',
        );
      },
    );

    test('trims whitespace from valid names', () {
      expect(NodeDisplayNameResolver.sanitizeName('  MyNode  '), 'MyNode');
    });
  });

  group('NodeDisplayNameResolver.isBleDefaultName', () {
    test('matches "Meshtastic_XXXX"', () {
      expect(NodeDisplayNameResolver.isBleDefaultName('Meshtastic_5ED6'), true);
    });

    test('matches lowercase hex in BLE name', () {
      expect(NodeDisplayNameResolver.isBleDefaultName('Meshtastic_abcd'), true);
    });

    test('does not match space variant', () {
      expect(
        NodeDisplayNameResolver.isBleDefaultName('Meshtastic 5ED6'),
        false,
      );
    });

    test('does not match custom names', () {
      expect(NodeDisplayNameResolver.isBleDefaultName('MyDevice'), false);
    });

    test('returns false for null', () {
      expect(NodeDisplayNameResolver.isBleDefaultName(null), false);
    });
  });
}
