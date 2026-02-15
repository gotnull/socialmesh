// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/admin_target.dart';

void main() {
  group('AdminTarget.local()', () {
    test('isLocal returns true', () {
      const target = AdminTarget.local();
      expect(target.isLocal, isTrue);
      expect(target.isRemote, isFalse);
    });

    test('resolve returns myNodeNum', () {
      const target = AdminTarget.local();
      expect(target.resolve(0xAABBCCDD), 0xAABBCCDD);
    });

    test('equality: all LocalAdminTarget instances are equal', () {
      const a = AdminTarget.local();
      const b = AdminTarget.local();
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('toString', () {
      const target = AdminTarget.local();
      expect(target.toString(), 'AdminTarget.local()');
    });
  });

  group('AdminTarget.remote()', () {
    test('isRemote returns true', () {
      const target = AdminTarget.remote(0x12345678);
      expect(target.isRemote, isTrue);
      expect(target.isLocal, isFalse);
    });

    test('resolve returns the remote nodeNum', () {
      const target = AdminTarget.remote(0x12345678);
      expect(target.resolve(0xAABBCCDD), 0x12345678);
    });

    test('nodeNum is accessible', () {
      const target = RemoteAdminTarget(0xDEADBEEF);
      expect(target.nodeNum, 0xDEADBEEF);
    });

    test('equality: same nodeNum', () {
      const a = AdminTarget.remote(0x12345678);
      const b = AdminTarget.remote(0x12345678);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('inequality: different nodeNum', () {
      const a = AdminTarget.remote(0x12345678);
      const b = AdminTarget.remote(0xDEADBEEF);
      expect(a, isNot(equals(b)));
    });

    test('inequality: remote vs local', () {
      const a = AdminTarget.remote(0x12345678);
      const b = AdminTarget.local();
      expect(a, isNot(equals(b)));
    });

    test('toString shows hex nodeNum', () {
      const target = AdminTarget.remote(0x12345678);
      expect(target.toString(), 'AdminTarget.remote(0x12345678)');
    });
  });

  group('AdminTarget.fromNullable()', () {
    test('null returns LocalAdminTarget', () {
      final target = AdminTarget.fromNullable(null);
      expect(target, isA<LocalAdminTarget>());
      expect(target.isLocal, isTrue);
    });

    test('non-null returns RemoteAdminTarget', () {
      final target = AdminTarget.fromNullable(0xCAFEBABE);
      expect(target, isA<RemoteAdminTarget>());
      expect((target as RemoteAdminTarget).nodeNum, 0xCAFEBABE);
    });
  });

  group('AdminTarget sealed exhaustive switch', () {
    test('switch covers all cases', () {
      const targets = <AdminTarget>[
        AdminTarget.local(),
        AdminTarget.remote(42),
      ];

      for (final target in targets) {
        final description = switch (target) {
          LocalAdminTarget() => 'local',
          RemoteAdminTarget(:final nodeNum) => 'remote:$nodeNum',
        };
        expect(description, isNotEmpty);
      }
    });
  });
}
