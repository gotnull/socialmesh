// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/utils/validation.dart';

void main() {
  group('Constants', () {
    test('maxChannelNameLength is 11', () {
      expect(maxChannelNameLength, 11);
    });

    test('maxLongNameLength is 39', () {
      expect(maxLongNameLength, 39);
    });

    test('maxShortNameLength is 4', () {
      expect(maxShortNameLength, 4);
    });
  });

  group('sanitizeChannelName', () {
    test('returns empty for empty input', () {
      expect(sanitizeChannelName(''), '');
    });

    test('replaces spaces with underscores', () {
      expect(sanitizeChannelName('my channel'), 'my_channel');
      expect(sanitizeChannelName('a b c'), 'a_b_c');
    });

    test('removes special characters', () {
      expect(sanitizeChannelName('test@#\$%'), 'test');
      expect(sanitizeChannelName('hello!world'), 'helloworld');
      expect(sanitizeChannelName('a.b.c'), 'abc');
    });

    test('preserves alphanumeric, underscore, and hyphen', () {
      expect(sanitizeChannelName('test_123'), 'test_123');
      expect(sanitizeChannelName('ABC_xyz_0'), 'ABC_xyz_0');
      expect(sanitizeChannelName('my-channel'), 'my-channel');
      expect(sanitizeChannelName('test-_mix'), 'test-_mix');
    });

    test('truncates to max length', () {
      expect(sanitizeChannelName('a' * 20), 'a' * 11);
      expect(sanitizeChannelName('verylongchannelname'), 'verylongcha');
    });

    test('handles combined cases', () {
      expect(sanitizeChannelName('My Channel Name!'), 'My_Channel_');
    });
  });

  group('validateChannelName', () {
    test('returns null for empty name', () {
      expect(validateChannelName(''), isNull);
    });

    test('returns null for valid name', () {
      expect(validateChannelName('valid'), isNull);
      expect(validateChannelName('test_123'), isNull);
      expect(validateChannelName('ABC'), isNull);
      expect(validateChannelName('my-channel'), isNull);
      expect(validateChannelName('test-_mix'), isNull);
    });

    test('returns error for spaces', () {
      expect(
        validateChannelName('has space'),
        'Channel name cannot contain spaces',
      );
    });

    test('returns error for too long name', () {
      expect(
        validateChannelName('a' * 12),
        'Channel name must be 11 characters or less',
      );
    });

    test('returns error for special characters', () {
      expect(
        validateChannelName('test@'),
        'Channel name can only contain letters, numbers, underscores, and hyphens',
      );
      expect(
        validateChannelName('a.b'),
        'Channel name can only contain letters, numbers, underscores, and hyphens',
      );
    });
  });

  group('utf8ByteLength', () {
    test('counts ASCII as 1 byte per char', () {
      expect(utf8ByteLength(''), 0);
      expect(utf8ByteLength('A'), 1);
      expect(utf8ByteLength('Hello'), 5);
    });

    test('counts supplementary-plane emoji as 4 bytes', () {
      expect(utf8ByteLength('🎉'), 4);
      expect(utf8ByteLength('A🎉'), 5);
    });

    test('counts BMP-plane emoji as 3 bytes', () {
      expect(utf8ByteLength('☎'), 3);
    });
  });

  group('truncateUtf8', () {
    test('returns input unchanged when within budget', () {
      expect(truncateUtf8('ABCD', 4), 'ABCD');
      expect(truncateUtf8('🎉', 4), '🎉');
    });

    test('truncates ASCII at byte boundary', () {
      expect(truncateUtf8('ABCDE', 4), 'ABCD');
    });

    test('never splits a multi-byte rune', () {
      // 🎉 is one rune, 4 bytes. Budget of 3 bytes drops it entirely
      // rather than splitting into invalid UTF-8.
      expect(truncateUtf8('🎉', 3), '');
      // "A🎉" is 5 bytes. Budget of 4 keeps "A" and drops 🎉.
      expect(truncateUtf8('A🎉', 4), 'A');
    });

    test('keeps the first emoji when there is room', () {
      expect(truncateUtf8('🎉🚀', 4), '🎉');
    });
  });

  group('sanitizeLongName', () {
    test('returns empty for empty input', () {
      expect(sanitizeLongName(''), '');
    });

    test('preserves printable ASCII', () {
      expect(sanitizeLongName('Hello World'), 'Hello World');
      expect(sanitizeLongName('Test 123!'), 'Test 123!');
    });

    test('preserves emoji and non-Latin scripts', () {
      expect(sanitizeLongName('Hello 🎉'), 'Hello 🎉');
      expect(sanitizeLongName('日本語'), '日本語');
      expect(sanitizeLongName('café'), 'café');
    });

    test('truncates by UTF-8 byte length', () {
      expect(sanitizeLongName('a' * 50), 'a' * 39);
    });

    test('trims whitespace', () {
      expect(sanitizeLongName('  hello  '), 'hello');
    });
  });

  group('validateLongName', () {
    test('returns error for empty name', () {
      expect(validateLongName(''), 'Name is required');
    });

    test('returns null for valid name', () {
      expect(validateLongName('Valid Name'), isNull);
      expect(validateLongName('Test 123'), isNull);
      expect(validateLongName('Hello 🎉'), isNull);
    });

    test('returns error when over byte budget', () {
      expect(validateLongName('a' * 40), 'Name must be 39 bytes or less');
    });

    test('counts emoji as multi-byte', () {
      // 9 emoji × 4 bytes = 36 bytes — fits.
      expect(validateLongName('🎉' * 9), isNull);
      // 10 emoji × 4 bytes = 40 bytes — exceeds 39-byte budget.
      expect(validateLongName('🎉' * 10), 'Name must be 39 bytes or less');
    });

    test('accepts max length name', () {
      expect(validateLongName('a' * 39), isNull);
    });
  });

  group('sanitizeShortName', () {
    test('returns empty for empty input', () {
      expect(sanitizeShortName(''), '');
    });

    test('preserves case', () {
      expect(sanitizeShortName('abc'), 'abc');
      expect(sanitizeShortName('aBcD'), 'aBcD');
    });

    test('keeps punctuation and spaces', () {
      expect(sanitizeShortName('a!b'), 'a!b');
      expect(sanitizeShortName('a_b'), 'a_b');
      expect(sanitizeShortName('a b'), 'a b');
    });

    test('keeps a single 4-byte emoji', () {
      expect(sanitizeShortName('🎉'), '🎉');
    });

    test('truncates at UTF-8 byte budget', () {
      expect(sanitizeShortName('abcdef'), 'abcd');
      // Two emoji = 8 bytes; only the first survives 4-byte budget.
      expect(sanitizeShortName('🎉🚀'), '🎉');
      // Emoji + ASCII can't both fit in 4 bytes.
      expect(sanitizeShortName('🎉A'), '🎉');
      expect(sanitizeShortName('A🎉'), 'A');
    });

    test('handles numbers', () {
      expect(sanitizeShortName('ab12'), 'ab12');
      expect(sanitizeShortName('1234'), '1234');
    });
  });

  group('validateShortName', () {
    test('returns error for empty name', () {
      expect(validateShortName(''), 'Short name is required');
    });

    test('returns null for valid name', () {
      expect(validateShortName('ABC'), isNull);
      expect(validateShortName('AB12'), isNull);
      expect(validateShortName('1234'), isNull);
      expect(validateShortName('🎉'), isNull);
    });

    test('returns error when over byte budget', () {
      expect(validateShortName('ABCDE'), 'Short name must be 4 bytes or less');
      // Two 4-byte emojis = 8 bytes.
      expect(validateShortName('🎉🚀'), 'Short name must be 4 bytes or less');
    });

    test('accepts punctuation, spaces, and lowercase', () {
      expect(validateShortName('a_b'), isNull);
      expect(validateShortName('a b'), isNull);
      expect(validateShortName('abcd'), isNull);
    });

    test('accepts max length name', () {
      expect(validateShortName('ABCD'), isNull);
      expect(validateShortName('🎉'), isNull); // Exactly 4 bytes.
    });
  });

  group('Utf8ByteLengthLimitingTextInputFormatter', () {
    late Utf8ByteLengthLimitingTextInputFormatter formatter;

    setUp(() {
      formatter = Utf8ByteLengthLimitingTextInputFormatter(4);
    });

    test('passes input within budget through unchanged', () {
      const newValue = TextEditingValue(
        text: 'AB',
        selection: TextSelection.collapsed(offset: 2),
      );
      final result = formatter.formatEditUpdate(
        const TextEditingValue(),
        newValue,
      );
      expect(result.text, 'AB');
      expect(result.selection.baseOffset, 2);
    });

    test('truncates over-budget input at rune boundary', () {
      const newValue = TextEditingValue(
        text: 'ABCDE',
        selection: TextSelection.collapsed(offset: 5),
      );
      final result = formatter.formatEditUpdate(
        const TextEditingValue(),
        newValue,
      );
      expect(result.text, 'ABCD');
      expect(result.selection.baseOffset, 4);
    });

    test('keeps the first emoji when a second would overflow', () {
      const newValue = TextEditingValue(
        text: '🎉🚀',
        selection: TextSelection.collapsed(offset: 4),
      );
      final result = formatter.formatEditUpdate(
        const TextEditingValue(),
        newValue,
      );
      expect(result.text, '🎉');
    });
  });

  group('UpperCaseTextFormatter', () {
    late UpperCaseTextFormatter formatter;

    setUp(() {
      formatter = UpperCaseTextFormatter();
    });

    test('converts text to uppercase', () {
      final oldValue = const TextEditingValue(text: '');
      final newValue = const TextEditingValue(
        text: 'abc',
        selection: TextSelection.collapsed(offset: 3),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, 'ABC');
      expect(result.selection.baseOffset, 3);
    });

    test('preserves selection position', () {
      final oldValue = const TextEditingValue(text: 'AB');
      final newValue = const TextEditingValue(
        text: 'ABc',
        selection: TextSelection.collapsed(offset: 3),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, 'ABC');
      expect(result.selection.baseOffset, 3);
    });

    test('handles mixed case', () {
      final oldValue = const TextEditingValue(text: '');
      final newValue = const TextEditingValue(
        text: 'AbCdEf',
        selection: TextSelection.collapsed(offset: 6),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, 'ABCDEF');
    });

    test('handles numbers and symbols', () {
      final oldValue = const TextEditingValue(text: '');
      final newValue = const TextEditingValue(
        text: 'abc123!@#',
        selection: TextSelection.collapsed(offset: 9),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, 'ABC123!@#');
    });

    test('handles empty text', () {
      final oldValue = const TextEditingValue(text: 'ABC');
      final newValue = const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '');
    });
  });

  group('Display Name Validation', () {
    group('validateDisplayName - format rules', () {
      test('rejects empty name', () {
        expect(validateDisplayName(''), 'Display name is required');
      });

      test('rejects single character', () {
        expect(
          validateDisplayName('A'),
          'Display name must be at least 2 characters',
        );
      });

      test('accepts 2 character name', () {
        expect(validateDisplayName('AB'), isNull);
      });

      test('accepts 30 character name', () {
        expect(validateDisplayName('a' * 30), isNull);
      });

      test('rejects 31 character name', () {
        expect(
          validateDisplayName('a' * 31),
          'Display name must be 30 characters or less',
        );
      });

      test('rejects spaces', () {
        expect(
          validateDisplayName('hello world'),
          'Only letters, numbers, periods and underscores (no spaces)',
        );
      });

      test('rejects hyphens', () {
        expect(
          validateDisplayName('hello-world'),
          'Only letters, numbers, periods and underscores (no spaces)',
        );
      });

      test('accepts underscores and periods', () {
        expect(validateDisplayName('hello_world'), isNull);
        expect(validateDisplayName('hello.world'), isNull);
      });

      test('rejects leading period', () {
        expect(
          validateDisplayName('.hello'),
          'Display name cannot start or end with a period',
        );
      });

      test('rejects trailing period', () {
        expect(
          validateDisplayName('hello.'),
          'Display name cannot start or end with a period',
        );
      });

      test('rejects consecutive periods', () {
        expect(
          validateDisplayName('hello..world'),
          'Display name cannot have consecutive periods',
        );
      });

      test('rejects all-numeric names', () {
        expect(
          validateDisplayName('12345'),
          'Display name cannot be only numbers',
        );
      });

      test('accepts mixed alphanumeric', () {
        expect(validateDisplayName('user123'), isNull);
        expect(validateDisplayName('123abc'), isNull);
      });
    });

    group('Reserved exact names', () {
      test('blocks all reserved names', () {
        final reserved = [
          'gotnull',
          'socialmesh',
          'admin',
          'administrator',
          'support',
          'help',
          'info',
          'contact',
          'official',
          'verified',
          'mod',
          'moderator',
          'staff',
          'team',
          'root',
          'system',
          'bot',
          'api',
          'dev',
          'developer',
          'meshtastic',
          'mesh',
        ];
        for (final name in reserved) {
          expect(
            validateDisplayName(name),
            'This display name is not available',
            reason: '"$name" should be reserved',
          );
        }
      });

      test('blocks reserved names case-insensitively', () {
        expect(
          validateDisplayName('Admin'),
          'This display name is not available',
        );
        expect(
          validateDisplayName('SUPPORT'),
          'This display name is not available',
        );
        expect(
          validateDisplayName('GoTnUlL'),
          'This display name is not available',
        );
      });

      test('owner can use reserved names', () {
        const ownerUid = '9ltxJGViWHW5aj5HhLGmiVwkrLU2';
        expect(validateDisplayName('admin', userId: ownerUid), isNull);
        expect(validateDisplayName('socialmesh', userId: ownerUid), isNull);
        expect(validateDisplayName('gotnull', userId: ownerUid), isNull);
      });
    });

    group('Brand protection patterns', () {
      test('blocks socialmesh variations', () {
        expect(matchesBlockedPattern('socialmesh'), isTrue);
        expect(matchesBlockedPattern('SocialMesh'), isTrue);
        expect(matchesBlockedPattern('social_mesh'), isTrue);
        expect(matchesBlockedPattern('social.mesh'), isTrue);
        expect(matchesBlockedPattern('socialmesh123'), isTrue);
        expect(matchesBlockedPattern('social_mesh_fan'), isTrue);
      });

      test('blocks gotnull variations', () {
        expect(matchesBlockedPattern('gotnull'), isTrue);
        expect(matchesBlockedPattern('GotNull'), isTrue);
        expect(matchesBlockedPattern('got_null'), isTrue);
        expect(matchesBlockedPattern('got.null'), isTrue);
        expect(matchesBlockedPattern('gotnull123'), isTrue);
      });

      test('blocks meshtastic at start', () {
        expect(matchesBlockedPattern('meshtastic'), isTrue);
        expect(matchesBlockedPattern('Meshtastic'), isTrue);
        expect(matchesBlockedPattern('meshtastic_fan'), isTrue);
      });

      test('allows brand words in other positions', () {
        // "meshtastic" at start is blocked, but brand words embedded
        // in longer unrelated names are handled by exact reserved list
        expect(matchesBlockedPattern('ilovemesh'), isFalse);
      });
    });

    group('Impersonation suffix patterns - require separator', () {
      test('blocks names ending with separator + real', () {
        expect(matchesBlockedPattern('fulvio_real'), isTrue);
        expect(matchesBlockedPattern('fulvio.real'), isTrue);
        expect(matchesBlockedPattern('mesh_real'), isTrue);
      });

      test('allows names ending with real but no separator', () {
        expect(matchesBlockedPattern('Play2BReal'), isFalse);
        expect(matchesBlockedPattern('ForReal'), isFalse);
        expect(matchesBlockedPattern('Surreal'), isFalse);
        expect(matchesBlockedPattern('Unreal'), isFalse);
        expect(matchesBlockedPattern('KeepItReal'), isFalse);
      });

      test('blocks names ending with separator + official', () {
        expect(matchesBlockedPattern('mesh_official'), isTrue);
        expect(matchesBlockedPattern('fulvio.official'), isTrue);
      });

      test('allows names ending with official but no separator', () {
        expect(matchesBlockedPattern('Unofficial'), isFalse);
        expect(matchesBlockedPattern('SemiOfficial'), isFalse);
      });

      test('blocks names ending with separator + verified', () {
        expect(matchesBlockedPattern('fulvio_verified'), isTrue);
        expect(matchesBlockedPattern('mesh.verified'), isTrue);
      });

      test('allows names ending with verified but no separator', () {
        expect(matchesBlockedPattern('Unverified'), isFalse);
        expect(matchesBlockedPattern('NotVerified'), isFalse);
      });

      test('blocks names ending with separator + admin', () {
        expect(matchesBlockedPattern('sys_admin'), isTrue);
        expect(matchesBlockedPattern('super.admin'), isTrue);
      });

      test('allows names containing admin without separator at end', () {
        expect(matchesBlockedPattern('Badminton'), isFalse);
        expect(matchesBlockedPattern('BadmintonFan'), isFalse);
        expect(matchesBlockedPattern('SysAdmin42'), isFalse);
      });

      test('blocks names ending with separator + mod/moderator', () {
        expect(matchesBlockedPattern('game_mod'), isTrue);
        expect(matchesBlockedPattern('server.mod'), isTrue);
        expect(matchesBlockedPattern('chat_moderator'), isTrue);
      });

      test('allows names ending with mod but no separator', () {
        expect(matchesBlockedPattern('GameMod'), isFalse);
      });

      test('blocks names ending with separator + support', () {
        expect(matchesBlockedPattern('tech_support'), isTrue);
        expect(matchesBlockedPattern('mesh.support'), isTrue);
      });

      test('allows names ending with support but no separator', () {
        expect(matchesBlockedPattern('TechSupport'), isFalse);
      });

      test('blocks names ending with separator + help', () {
        expect(matchesBlockedPattern('mesh_help'), isTrue);
        expect(matchesBlockedPattern('tech.help'), isTrue);
      });

      test('allows names ending with help but no separator', () {
        expect(matchesBlockedPattern('SelfHelp'), isFalse);
        expect(matchesBlockedPattern('NeedHelp'), isFalse);
      });
    });

    group('Impersonation prefix patterns - require separator', () {
      test('blocks names starting with real + separator', () {
        expect(matchesBlockedPattern('real_fulvio'), isTrue);
        expect(matchesBlockedPattern('real.mesh'), isTrue);
      });

      test('allows names starting with real but no separator', () {
        expect(matchesBlockedPattern('Reality'), isFalse);
        expect(matchesBlockedPattern('RealTalk'), isFalse);
        expect(matchesBlockedPattern('Realtime'), isFalse);
      });

      test('blocks names starting with official + separator', () {
        expect(matchesBlockedPattern('official_mesh'), isTrue);
        expect(matchesBlockedPattern('official.team'), isTrue);
      });

      test('allows names starting with official but no separator', () {
        expect(matchesBlockedPattern('OfficiallyFun'), isFalse);
      });

      test('blocks names starting with admin + separator', () {
        expect(matchesBlockedPattern('admin_team'), isTrue);
        expect(matchesBlockedPattern('admin.user'), isTrue);
      });

      test('allows names starting with admin but no separator', () {
        expect(matchesBlockedPattern('AdminFan'), isFalse);
      });

      test('blocks names starting with mod + separator', () {
        expect(matchesBlockedPattern('mod_team'), isTrue);
        expect(matchesBlockedPattern('mod.user'), isTrue);
      });

      test('allows names starting with mod but no separator', () {
        expect(matchesBlockedPattern('Modern'), isFalse);
        expect(matchesBlockedPattern('Model'), isFalse);
        expect(matchesBlockedPattern('Modify'), isFalse);
        expect(matchesBlockedPattern('Module'), isFalse);
      });

      test('blocks names starting with support + separator', () {
        expect(matchesBlockedPattern('support_team'), isTrue);
        expect(matchesBlockedPattern('support.desk'), isTrue);
      });

      test('allows names starting with support but no separator', () {
        expect(matchesBlockedPattern('Supportive'), isFalse);
        expect(matchesBlockedPattern('Supporter'), isFalse);
      });

      test('blocks names starting with help + separator', () {
        expect(matchesBlockedPattern('help_desk'), isTrue);
        expect(matchesBlockedPattern('help.me'), isTrue);
      });

      test('allows names starting with help but no separator', () {
        expect(matchesBlockedPattern('Helpful'), isFalse);
        expect(matchesBlockedPattern('Helper'), isFalse);
      });
    });

    group('TheReal pattern - specifically impersonation', () {
      test('blocks thereal variations', () {
        expect(matchesBlockedPattern('thereal'), isTrue);
        expect(matchesBlockedPattern('TheReal'), isTrue);
        expect(matchesBlockedPattern('therealfulvio'), isTrue);
        expect(matchesBlockedPattern('TheRealMesh'), isTrue);
        expect(matchesBlockedPattern('the_real'), isTrue);
        expect(matchesBlockedPattern('the.real'), isTrue);
        expect(matchesBlockedPattern('the_real_fulvio'), isTrue);
        expect(matchesBlockedPattern('the.real.mesh'), isTrue);
      });
    });

    group('Real-world usernames that should be allowed', () {
      test('Play2BReal - the original support ticket', () {
        expect(validateDisplayName('Play2BReal'), isNull);
      });

      test('common names with real', () {
        expect(validateDisplayName('ForReal'), isNull);
        expect(validateDisplayName('Surreal'), isNull);
        expect(validateDisplayName('Unreal'), isNull);
        expect(validateDisplayName('RealTalk'), isNull);
      });

      test('common names with mod', () {
        expect(validateDisplayName('Modern'), isNull);
        expect(validateDisplayName('Model99'), isNull);
      });

      test('common names with help', () {
        expect(validateDisplayName('Helpful'), isNull);
        expect(validateDisplayName('Helper42'), isNull);
      });

      test('common names with admin substring', () {
        expect(validateDisplayName('Badminton'), isNull);
      });

      test('common names with support', () {
        expect(validateDisplayName('Supportive'), isNull);
      });

      test('common names with official', () {
        expect(validateDisplayName('Unofficial'), isNull);
      });
    });

    group('Real-world usernames that should be blocked', () {
      test('impersonation with separators', () {
        expect(
          validateDisplayName('fulvio_real'),
          'This display name is not available',
        );
        expect(
          validateDisplayName('the_real_dev'),
          'This display name is not available',
        );
        expect(
          validateDisplayName('mesh_official'),
          'This display name is not available',
        );
        expect(
          validateDisplayName('sys_admin'),
          'This display name is not available',
        );
        expect(
          validateDisplayName('mod_team'),
          'This display name is not available',
        );
        expect(
          validateDisplayName('help_desk'),
          'This display name is not available',
        );
        expect(
          validateDisplayName('tech_support'),
          'This display name is not available',
        );
      });
    });
  });
}
