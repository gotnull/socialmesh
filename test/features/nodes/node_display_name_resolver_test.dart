import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodes/node_display_name_resolver.dart';

void main() {
  test('resolve prefers longName over shortName and fallback', () {
    final name = NodeDisplayNameResolver.resolve(
      nodeNum: 0x5ed6,
      longName: 'Wismesh',
      shortName: '5ed6',
      bleName: 'Meshtastic_5ed6',
    );
    expect(name, 'Wismesh');
  });

  test('resolve prefers shortName when longName missing', () {
    final name = NodeDisplayNameResolver.resolve(
      nodeNum: 0x5ed6,
      longName: '   ',
      shortName: '5ed6',
      bleName: 'Meshtastic_5ed6',
    );
    expect(name, '5ed6');
  });

  test('resolve ignores default BLE name and falls back', () {
    final name = NodeDisplayNameResolver.resolve(
      nodeNum: 0x5ed6,
      longName: null,
      shortName: null,
      bleName: 'Meshtastic_5ed6',
      fallback: 'Node 24278',
    );
    expect(name, 'Node 24278');
  });

  test('resolve uses BLE name for local device when non-default', () {
    final name = NodeDisplayNameResolver.resolve(
      nodeNum: 0x5ed6,
      longName: null,
      shortName: null,
      bleName: 'Wismesh BLE',
      fallback: 'Node 24278',
    );
    expect(name, 'Wismesh BLE');
  });
}
