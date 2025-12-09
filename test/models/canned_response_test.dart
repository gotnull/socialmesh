import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/canned_response.dart';

void main() {
  group('CannedResponse', () {
    test('creates with required fields', () {
      final response = CannedResponse(text: 'Hello');

      expect(response.id, isNotEmpty);
      expect(response.text, 'Hello');
      expect(response.sortOrder, 0);
      expect(response.isDefault, false);
    });

    test('creates with all fields', () {
      final response = CannedResponse(
        id: 'custom-id',
        text: 'Custom response',
        sortOrder: 5,
        isDefault: true,
      );

      expect(response.id, 'custom-id');
      expect(response.text, 'Custom response');
      expect(response.sortOrder, 5);
      expect(response.isDefault, true);
    });

    test('copyWith preserves unmodified values', () {
      final original = CannedResponse(
        id: 'test-id',
        text: 'Original',
        sortOrder: 3,
        isDefault: true,
      );

      final copied = original.copyWith(text: 'Modified');

      expect(copied.id, 'test-id');
      expect(copied.text, 'Modified');
      expect(copied.sortOrder, 3);
      expect(copied.isDefault, true);
    });

    test('copyWith can modify any field', () {
      final original = CannedResponse(text: 'Test');

      final modified = original.copyWith(
        id: 'new-id',
        text: 'New text',
        sortOrder: 10,
        isDefault: true,
      );

      expect(modified.id, 'new-id');
      expect(modified.text, 'New text');
      expect(modified.sortOrder, 10);
      expect(modified.isDefault, true);
    });

    test('serializes to JSON', () {
      final response = CannedResponse(
        id: 'json-id',
        text: 'JSON text',
        sortOrder: 2,
        isDefault: true,
      );

      final json = response.toJson();

      expect(json['id'], 'json-id');
      expect(json['text'], 'JSON text');
      expect(json['sortOrder'], 2);
      expect(json['isDefault'], true);
    });

    test('deserializes from JSON', () {
      final json = {
        'id': 'from-json',
        'text': 'From JSON',
        'sortOrder': 4,
        'isDefault': false,
      };

      final response = CannedResponse.fromJson(json);

      expect(response.id, 'from-json');
      expect(response.text, 'From JSON');
      expect(response.sortOrder, 4);
      expect(response.isDefault, false);
    });

    test('deserializes with default values for missing fields', () {
      final json = {'id': 'minimal', 'text': 'Minimal response'};

      final response = CannedResponse.fromJson(json);

      expect(response.id, 'minimal');
      expect(response.text, 'Minimal response');
      expect(response.sortOrder, 0);
      expect(response.isDefault, false);
    });

    test('toString returns readable representation', () {
      final response = CannedResponse(text: 'Test message');
      expect(response.toString(), 'CannedResponse(text: Test message)');
    });

    test('roundtrip JSON serialization', () {
      final original = CannedResponse(
        id: 'roundtrip',
        text: 'Roundtrip test',
        sortOrder: 7,
        isDefault: true,
      );

      final json = original.toJson();
      final restored = CannedResponse.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.text, original.text);
      expect(restored.sortOrder, original.sortOrder);
      expect(restored.isDefault, original.isDefault);
    });
  });

  group('DefaultCannedResponses', () {
    test('provides default responses', () {
      final defaults = DefaultCannedResponses.all;

      expect(defaults, isNotEmpty);
      expect(defaults.length, 8);
    });

    test('all defaults have isDefault true', () {
      final defaults = DefaultCannedResponses.all;

      for (final response in defaults) {
        expect(
          response.isDefault,
          true,
          reason: 'Response "${response.text}" should be default',
        );
      }
    });

    test('all defaults have unique ids', () {
      final defaults = DefaultCannedResponses.all;
      final ids = defaults.map((r) => r.id).toSet();

      expect(ids.length, defaults.length);
    });

    test('all defaults have incrementing sort order', () {
      final defaults = DefaultCannedResponses.all;

      for (int i = 0; i < defaults.length; i++) {
        expect(defaults[i].sortOrder, i);
      }
    });

    test('contains expected responses', () {
      final defaults = DefaultCannedResponses.all;
      final texts = defaults.map((r) => r.text).toList();

      expect(texts, contains('OK'));
      expect(texts, contains('Yes'));
      expect(texts, contains('No'));
      expect(texts, contains('On my way'));
      expect(texts, contains('Need help'));
      expect(texts, contains("I'm safe"));
      expect(texts, contains('Wait for me'));
      expect(texts, contains('Thanks!'));
    });

    test('default IDs follow naming convention', () {
      final defaults = DefaultCannedResponses.all;

      for (final response in defaults) {
        expect(response.id, startsWith('default_'));
      }
    });
  });
}
