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

    test('preserves alphanumeric and underscore', () {
      expect(sanitizeChannelName('test_123'), 'test_123');
      expect(sanitizeChannelName('ABC_xyz_0'), 'ABC_xyz_0');
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
        'Channel name can only contain letters, numbers, and underscores',
      );
      expect(
        validateChannelName('a.b'),
        'Channel name can only contain letters, numbers, and underscores',
      );
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

    test('removes non-printable characters', () {
      expect(sanitizeLongName('Hello\x00World'), 'HelloWorld');
      expect(sanitizeLongName('Test\x1F'), 'Test');
    });

    test('truncates to max length', () {
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
    });

    test('returns error for too long name', () {
      expect(validateLongName('a' * 40), 'Name must be 39 characters or less');
    });

    test('accepts max length name', () {
      expect(validateLongName('a' * 39), isNull);
    });
  });

  group('sanitizeShortName', () {
    test('returns empty for empty input', () {
      expect(sanitizeShortName(''), '');
    });

    test('converts to uppercase', () {
      expect(sanitizeShortName('abc'), 'ABC');
      expect(sanitizeShortName('aBcD'), 'ABCD');
    });

    test('removes non-alphanumeric characters', () {
      expect(sanitizeShortName('ab!c'), 'ABC');
      expect(sanitizeShortName('a_b'), 'AB');
      expect(sanitizeShortName('a b'), 'AB');
    });

    test('truncates to max length', () {
      expect(sanitizeShortName('abcdef'), 'ABCD');
    });

    test('handles numbers', () {
      expect(sanitizeShortName('ab12'), 'AB12');
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
    });

    test('returns error for too long name', () {
      expect(
        validateShortName('ABCDE'),
        'Short name must be 4 characters or less',
      );
    });

    test('returns error for special characters', () {
      expect(
        validateShortName('AB_C'),
        'Short name can only contain letters and numbers',
      );
      expect(
        validateShortName('A B'),
        'Short name can only contain letters and numbers',
      );
    });

    test('accepts max length name', () {
      expect(validateShortName('ABCD'), isNull);
    });

    test('validates lowercase as valid (converts internally)', () {
      // validateShortName converts to uppercase before regex check
      expect(validateShortName('abcd'), isNull);
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
}
