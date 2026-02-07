// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/utils/version_compare.dart';

void main() {
  // ===========================================================================
  // SemanticVersion.tryParse
  // ===========================================================================

  group('SemanticVersion.tryParse', () {
    test('parses standard major.minor.patch', () {
      final v = SemanticVersion.tryParse('1.2.3');
      expect(v, isNotNull);
      expect(v!.major, 1);
      expect(v.minor, 2);
      expect(v.patch, 3);
    });

    test('parses two-part version with implicit patch zero', () {
      final v = SemanticVersion.tryParse('2.5');
      expect(v, isNotNull);
      expect(v!.major, 2);
      expect(v.minor, 5);
      expect(v.patch, 0);
    });

    test('strips build metadata after +', () {
      final v = SemanticVersion.tryParse('1.2.0+103');
      expect(v, isNotNull);
      expect(v!.major, 1);
      expect(v.minor, 2);
      expect(v.patch, 0);
    });

    test('strips pre-release suffix after -', () {
      final v = SemanticVersion.tryParse('1.3.0-beta.1');
      expect(v, isNotNull);
      expect(v!.major, 1);
      expect(v.minor, 3);
      expect(v.patch, 0);
    });

    test('strips both pre-release and build metadata', () {
      final v = SemanticVersion.tryParse('2.0.1-rc.2+42');
      expect(v, isNotNull);
      expect(v!.major, 2);
      expect(v.minor, 0);
      expect(v.patch, 1);
    });

    test('handles whitespace around version string', () {
      final v = SemanticVersion.tryParse('  1.0.0  ');
      expect(v, isNotNull);
      expect(v!.major, 1);
    });

    test('returns null for empty string', () {
      expect(SemanticVersion.tryParse(''), isNull);
    });

    test('returns null for single number', () {
      expect(SemanticVersion.tryParse('42'), isNull);
    });

    test('returns null for four-part version', () {
      expect(SemanticVersion.tryParse('1.2.3.4'), isNull);
    });

    test('returns null for non-numeric parts', () {
      expect(SemanticVersion.tryParse('a.b.c'), isNull);
    });

    test('returns null for negative numbers', () {
      expect(SemanticVersion.tryParse('-1.0.0'), isNull);
    });

    test('parses zero version', () {
      final v = SemanticVersion.tryParse('0.0.0');
      expect(v, isNotNull);
      expect(v!.major, 0);
      expect(v.minor, 0);
      expect(v.patch, 0);
    });

    test('parses large version numbers', () {
      final v = SemanticVersion.tryParse('100.200.300');
      expect(v, isNotNull);
      expect(v!.major, 100);
      expect(v.minor, 200);
      expect(v.patch, 300);
    });
  });

  // ===========================================================================
  // SemanticVersion.parse (throwing)
  // ===========================================================================

  group('SemanticVersion.parse', () {
    test('returns version for valid input', () {
      final v = SemanticVersion.parse('3.1.4');
      expect(v.major, 3);
      expect(v.minor, 1);
      expect(v.patch, 4);
    });

    test('throws FormatException for invalid input', () {
      expect(
        () => SemanticVersion.parse('not-a-version'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  // ===========================================================================
  // SemanticVersion.compareTo / operators
  // ===========================================================================

  group('SemanticVersion.compareTo', () {
    test('equal versions compare to zero', () {
      final a = SemanticVersion(1, 2, 3);
      final b = SemanticVersion(1, 2, 3);
      expect(a.compareTo(b), 0);
      expect(a == b, isTrue);
    });

    test('major version takes priority', () {
      final a = SemanticVersion(2, 0, 0);
      final b = SemanticVersion(1, 9, 9);
      expect(a.compareTo(b), greaterThan(0));
      expect(b.compareTo(a), lessThan(0));
    });

    test('minor version compared when major equal', () {
      final a = SemanticVersion(1, 3, 0);
      final b = SemanticVersion(1, 2, 9);
      expect(a.compareTo(b), greaterThan(0));
    });

    test('patch version compared when major and minor equal', () {
      final a = SemanticVersion(1, 2, 5);
      final b = SemanticVersion(1, 2, 3);
      expect(a.compareTo(b), greaterThan(0));
    });
  });

  // ===========================================================================
  // SemanticVersion.isNewerThan / isAtLeast
  // ===========================================================================

  group('SemanticVersion.isNewerThan', () {
    test('returns true when strictly newer', () {
      expect(
        SemanticVersion(1, 2, 0).isNewerThan(SemanticVersion(1, 1, 0)),
        isTrue,
      );
    });

    test('returns false when equal', () {
      expect(
        SemanticVersion(1, 2, 0).isNewerThan(SemanticVersion(1, 2, 0)),
        isFalse,
      );
    });

    test('returns false when older', () {
      expect(
        SemanticVersion(1, 0, 0).isNewerThan(SemanticVersion(1, 2, 0)),
        isFalse,
      );
    });
  });

  group('SemanticVersion.isAtLeast', () {
    test('returns true when strictly newer', () {
      expect(
        SemanticVersion(2, 0, 0).isAtLeast(SemanticVersion(1, 0, 0)),
        isTrue,
      );
    });

    test('returns true when equal', () {
      expect(
        SemanticVersion(1, 2, 0).isAtLeast(SemanticVersion(1, 2, 0)),
        isTrue,
      );
    });

    test('returns false when older', () {
      expect(
        SemanticVersion(1, 0, 0).isAtLeast(SemanticVersion(1, 2, 0)),
        isFalse,
      );
    });
  });

  // ===========================================================================
  // SemanticVersion.toString / hashCode
  // ===========================================================================

  group('SemanticVersion.toString', () {
    test('formats as major.minor.patch', () {
      expect(SemanticVersion(1, 2, 3).toString(), '1.2.3');
    });

    test('zero version formats correctly', () {
      expect(SemanticVersion(0, 0, 0).toString(), '0.0.0');
    });
  });

  group('SemanticVersion.hashCode', () {
    test('equal versions have same hashCode', () {
      final a = SemanticVersion(1, 2, 3);
      final b = SemanticVersion(1, 2, 3);
      expect(a.hashCode, b.hashCode);
    });

    test('different versions likely have different hashCode', () {
      final a = SemanticVersion(1, 2, 3);
      final b = SemanticVersion(3, 2, 1);
      expect(a.hashCode, isNot(b.hashCode));
    });
  });

  // ===========================================================================
  // compareVersions (top-level helper)
  // ===========================================================================

  group('compareVersions', () {
    test('returns positive when a is newer', () {
      expect(compareVersions('2.0.0', '1.0.0'), greaterThan(0));
    });

    test('returns negative when a is older', () {
      expect(compareVersions('1.0.0', '2.0.0'), lessThan(0));
    });

    test('returns zero when equal', () {
      expect(compareVersions('1.2.0', '1.2.0'), 0);
    });

    test('returns null when a is invalid', () {
      expect(compareVersions('bad', '1.0.0'), isNull);
    });

    test('returns null when b is invalid', () {
      expect(compareVersions('1.0.0', 'bad'), isNull);
    });

    test('handles build metadata in both operands', () {
      expect(compareVersions('1.2.0+100', '1.2.0+200'), 0);
    });
  });

  // ===========================================================================
  // isVersionNewer (top-level helper)
  // ===========================================================================

  group('isVersionNewer', () {
    test('returns true when current is newer', () {
      expect(isVersionNewer('1.2.0', '1.1.0'), isTrue);
    });

    test('returns false when equal', () {
      expect(isVersionNewer('1.2.0', '1.2.0'), isFalse);
    });

    test('returns false when current is older', () {
      expect(isVersionNewer('1.0.0', '1.2.0'), isFalse);
    });

    test('returns false for invalid strings', () {
      expect(isVersionNewer('bad', '1.0.0'), isFalse);
      expect(isVersionNewer('1.0.0', 'bad'), isFalse);
    });
  });

  // ===========================================================================
  // isVersionAtLeast (top-level helper)
  // ===========================================================================

  group('isVersionAtLeast', () {
    test('returns true when current is newer', () {
      expect(isVersionAtLeast('1.3.0', '1.2.0'), isTrue);
    });

    test('returns true when equal', () {
      expect(isVersionAtLeast('1.2.0', '1.2.0'), isTrue);
    });

    test('returns false when current is older', () {
      expect(isVersionAtLeast('1.1.0', '1.2.0'), isFalse);
    });

    test('returns false for invalid strings', () {
      expect(isVersionAtLeast('bad', '1.0.0'), isFalse);
    });
  });
}
