import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/audio/rtttl_library_service.dart';

void main() {
  group('RtttlLibraryItem', () {
    test('creates valid instance from constructor', () {
      const item = RtttlLibraryItem(
        displayName: 'Nokia Tune',
        toneName: 'nokia',
        artist: 'Nokia',
        rtttl: 'nokia:d=4,o=5,b=180:8e6,8d6,f#,g#',
        filename: 'nokia.rtttl',
        isBuiltin: true,
      );

      expect(item.displayName, 'Nokia Tune');
      expect(item.toneName, 'nokia');
      expect(item.artist, 'Nokia');
      expect(item.rtttl, 'nokia:d=4,o=5,b=180:8e6,8d6,f#,g#');
      expect(item.filename, 'nokia.rtttl');
      expect(item.isBuiltin, true);
    });

    test('creates from JSON with all fields', () {
      final json = {
        'displayName': 'Star Wars',
        'toneName': 'starwars',
        'artist': 'John Williams',
        'rtttl': 'starwars:d=4,o=5,b=120:8a,8a,8a,2f',
        'filename': 'starwars.rtttl',
        'builtin': true,
      };

      final item = RtttlLibraryItem.fromJson(json);

      expect(item.displayName, 'Star Wars');
      expect(item.toneName, 'starwars');
      expect(item.artist, 'John Williams');
      expect(item.rtttl, 'starwars:d=4,o=5,b=120:8a,8a,8a,2f');
      expect(item.filename, 'starwars.rtttl');
      expect(item.isBuiltin, true);
    });

    test('creates from JSON with missing optional fields', () {
      final json = {
        'displayName': 'Simple Tone',
        'toneName': 'simple',
        'rtttl': 'simple:d=4,o=5,b=120:c,d,e',
        'filename': 'simple.rtttl',
      };

      final item = RtttlLibraryItem.fromJson(json);

      expect(item.displayName, 'Simple Tone');
      expect(item.toneName, 'simple');
      expect(item.artist, isNull);
      expect(item.isBuiltin, false); // Default value
    });

    test('creates from empty JSON with defaults', () {
      final item = RtttlLibraryItem.fromJson({});

      expect(item.displayName, '');
      expect(item.toneName, '');
      expect(item.artist, isNull);
      expect(item.rtttl, '');
      expect(item.filename, '');
      expect(item.isBuiltin, false);
    });

    test('formattedTitle returns displayName when artist is present', () {
      const item = RtttlLibraryItem(
        displayName: 'Star Wars Theme',
        toneName: 'starwars',
        artist: 'John Williams',
        rtttl: 'starwars:d=4,o=5,b=120:8a',
        filename: 'starwars.rtttl',
      );

      expect(item.formattedTitle, 'Star Wars Theme');
    });

    test('formattedTitle returns formatted toneName when no artist', () {
      const item = RtttlLibraryItem(
        displayName: 'Simple Tone',
        toneName: 'simple_tone_name',
        rtttl: 'simple:d=4,o=5,b=120:c',
        filename: 'simple.rtttl',
      );

      expect(item.formattedTitle, 'simple tone name');
    });

    test('formattedTitle returns displayName when toneName is empty', () {
      const item = RtttlLibraryItem(
        displayName: 'Display Name',
        toneName: '',
        rtttl: 'simple:d=4,o=5,b=120:c',
        filename: 'simple.rtttl',
      );

      expect(item.formattedTitle, 'Display Name');
    });

    test('subtitle returns artist when present', () {
      const item = RtttlLibraryItem(
        displayName: 'Star Wars Theme',
        toneName: 'starwars',
        artist: 'John Williams',
        rtttl: 'starwars:d=4,o=5,b=120:8a',
        filename: 'starwars.rtttl',
      );

      expect(item.subtitle, 'John Williams');
    });

    test('subtitle returns null when artist is null', () {
      const item = RtttlLibraryItem(
        displayName: 'Simple Tone',
        toneName: 'simple',
        rtttl: 'simple:d=4,o=5,b=120:c',
        filename: 'simple.rtttl',
      );

      expect(item.subtitle, isNull);
    });

    test('subtitle returns null when artist is empty', () {
      const item = RtttlLibraryItem(
        displayName: 'Simple Tone',
        toneName: 'simple',
        artist: '',
        rtttl: 'simple:d=4,o=5,b=120:c',
        filename: 'simple.rtttl',
      );

      expect(item.subtitle, isNull);
    });
  });

  group('RtttlLibraryService', () {
    test('maxRtttlLength is 230', () {
      expect(RtttlLibraryService.maxRtttlLength, 230);
    });

    test('clearCache resets loaded state', () {
      final service = RtttlLibraryService();
      service.clearCache();
      // Should not throw and should be ready to load again
      expect(() => service.clearCache(), returnsNormally);
    });
  });
}
