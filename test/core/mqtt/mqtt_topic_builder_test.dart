// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/mqtt/mqtt_constants.dart';
import 'package:socialmesh/core/mqtt/mqtt_topic_builder.dart';

void main() {
  group('TopicBuilder.resolve', () {
    test('resolves all placeholders when values provided', () {
      const pattern = '{root}/chat/{channel}';
      final result = TopicBuilder.resolve(pattern, {
        'root': 'msh',
        'channel': 'primary',
      });
      expect(result, 'msh/chat/primary');
    });

    test('resolves partial placeholders leaving unmatched intact', () {
      const pattern = '{root}/telemetry/{nodeId}';
      final result = TopicBuilder.resolve(pattern, {'root': 'msh'});
      expect(result, 'msh/telemetry/{nodeId}');
    });

    test('handles empty values map by returning pattern unchanged', () {
      const pattern = '{root}/chat/{channel}';
      final result = TopicBuilder.resolve(pattern, {});
      expect(result, pattern);
    });

    test('handles pattern with no placeholders', () {
      const pattern = 'static/topic/path';
      final result = TopicBuilder.resolve(pattern, {'root': 'msh'});
      expect(result, 'static/topic/path');
    });

    test('resolves multiple occurrences of the same placeholder', () {
      const pattern = '{root}/{root}/echo';
      final result = TopicBuilder.resolve(pattern, {'root': 'msh'});
      expect(result, 'msh/msh/echo');
    });

    test('handles empty string values', () {
      const pattern = '{root}/chat/{channel}';
      final result = TopicBuilder.resolve(pattern, {
        'root': '',
        'channel': 'test',
      });
      expect(result, '/chat/test');
    });

    test('handles values with special characters', () {
      const pattern = '{root}/chat/{channel}';
      final result = TopicBuilder.resolve(pattern, {
        'root': 'my-mesh',
        'channel': 'chan_01',
      });
      expect(result, 'my-mesh/chat/chan_01');
    });
  });

  group('TopicBuilder.resolveWithConfig', () {
    test('uses provided topicRoot', () {
      final result = TopicBuilder.resolveWithConfig(
        pattern: '{root}/chat/{channel}',
        topicRoot: 'custom',
        channel: 'primary',
      );
      expect(result, 'custom/chat/primary');
    });

    test('falls back to default topic root when empty', () {
      final result = TopicBuilder.resolveWithConfig(
        pattern: '{root}/chat/{channel}',
        topicRoot: '',
        channel: 'primary',
      );
      expect(result, '${GlobalLayerConstants.defaultTopicRoot}/chat/primary');
    });

    test('leaves channel placeholder when channel is null', () {
      final result = TopicBuilder.resolveWithConfig(
        pattern: '{root}/chat/{channel}',
        topicRoot: 'msh',
      );
      expect(result, 'msh/chat/{channel}');
    });

    test('leaves channel placeholder when channel is empty', () {
      final result = TopicBuilder.resolveWithConfig(
        pattern: '{root}/chat/{channel}',
        topicRoot: 'msh',
        channel: '',
      );
      expect(result, 'msh/chat/{channel}');
    });

    test('resolves nodeId when provided', () {
      final result = TopicBuilder.resolveWithConfig(
        pattern: '{root}/telemetry/{nodeId}',
        topicRoot: 'msh',
        nodeId: '!a1b2c3d4',
      );
      expect(result, 'msh/telemetry/!a1b2c3d4');
    });

    test('leaves nodeId placeholder when nodeId is null', () {
      final result = TopicBuilder.resolveWithConfig(
        pattern: '{root}/telemetry/{nodeId}',
        topicRoot: 'msh',
      );
      expect(result, 'msh/telemetry/{nodeId}');
    });
  });

  group('TopicBuilder.resolveTemplate', () {
    test('resolves a TopicTemplate with all values', () {
      const template = TopicTemplate(
        label: 'Chat',
        iconName: 'chat',
        description: 'Chat messages',
        pattern: '{root}/chat/{channel}',
      );

      final resolved = TopicBuilder.resolveTemplate(
        template: template,
        topicRoot: 'msh',
        channel: 'primary',
      );

      expect(resolved.topic, 'msh/chat/primary');
      expect(resolved.label, 'Chat');
      expect(resolved.pattern, '{root}/chat/{channel}');
      expect(resolved.substitutions, {'root': 'msh', 'channel': 'primary'});
    });

    test('preserves metadata from template', () {
      const template = TopicTemplate(
        label: 'Telemetry',
        iconName: 'monitor_heart_outlined',
        description: 'Device health data',
        pattern: '{root}/telemetry/{nodeId}',
      );

      final resolved = TopicBuilder.resolveTemplate(
        template: template,
        topicRoot: 'myroot',
        nodeId: 'node123',
      );

      expect(resolved.label, 'Telemetry');
      expect(resolved.topic, 'myroot/telemetry/node123');
    });
  });

  group('TopicBuilder.resolveAllTemplates', () {
    test('resolves all built-in templates', () {
      final results = TopicBuilder.resolveAllTemplates(
        topicRoot: 'msh',
        channel: 'LongFast',
        nodeId: '!deadbeef',
      );

      expect(results.length, TopicTemplate.builtIn.length);

      // Verify each result has the correct root
      for (final result in results) {
        expect(result.topic, startsWith('msh/'));
        expect(result.label, isNotEmpty);
        expect(result.substitutions.containsKey('root'), isTrue);
      }
    });

    test('all built-in templates resolve with full values', () {
      final results = TopicBuilder.resolveAllTemplates(
        topicRoot: 'test',
        channel: 'primary',
        nodeId: '!12345678',
      );

      for (final result in results) {
        expect(
          TopicBuilder.isFullyResolved(result.topic),
          isTrue,
          reason:
              'Template "${result.label}" has unresolved placeholders: '
              '${result.topic}',
        );
      }
    });
  });

  group('TopicBuilder.validateTopic', () {
    test('accepts a valid simple topic', () {
      final result = TopicBuilder.validateTopic('msh/chat/primary');
      expect(result.isValid, isTrue);
    });

    test('accepts a single-level topic', () {
      final result = TopicBuilder.validateTopic('mytopic');
      expect(result.isValid, isTrue);
    });

    test('rejects empty topic', () {
      final result = TopicBuilder.validateTopic('');
      expect(result.isValid, isFalse);
      expect(result.error, contains('empty'));
    });

    test('rejects topic containing null character', () {
      final result = TopicBuilder.validateTopic('msh/chat\u0000/test');
      expect(result.isValid, isFalse);
      expect(result.error, contains('null character'));
    });

    test('rejects topic exceeding max length', () {
      final longTopic = 'a' * (GlobalLayerConstants.maxTopicLength + 1);
      final result = TopicBuilder.validateTopic(longTopic);
      expect(result.isValid, isFalse);
      expect(result.error, contains('maximum length'));
    });

    test('accepts topic at exactly max length', () {
      final maxTopic = 'a' * GlobalLayerConstants.maxTopicLength;
      final result = TopicBuilder.validateTopic(maxTopic);
      expect(result.isValid, isTrue);
    });

    group('wildcards in publish topics (disallowed)', () {
      test('rejects single-level wildcard', () {
        final result = TopicBuilder.validateTopic('msh/+/chat');
        expect(result.isValid, isFalse);
        expect(result.error, contains('+'));
      });

      test('rejects multi-level wildcard', () {
        final result = TopicBuilder.validateTopic('msh/#');
        expect(result.isValid, isFalse);
        expect(result.error, contains('#'));
      });
    });

    group('wildcards in subscribe topics (allowed)', () {
      test('accepts single-level wildcard in valid position', () {
        final result = TopicBuilder.validateTopic(
          'msh/+/chat',
          allowWildcards: true,
        );
        expect(result.isValid, isTrue);
      });

      test('accepts multi-level wildcard at end', () {
        final result = TopicBuilder.validateTopic(
          'msh/#',
          allowWildcards: true,
        );
        expect(result.isValid, isTrue);
      });

      test('accepts multi-level wildcard as only character', () {
        final result = TopicBuilder.validateTopic('#', allowWildcards: true);
        expect(result.isValid, isTrue);
      });

      test('accepts single-level wildcard at start', () {
        final result = TopicBuilder.validateTopic(
          '+/chat/primary',
          allowWildcards: true,
        );
        expect(result.isValid, isTrue);
      });

      test('accepts single-level wildcard at end', () {
        final result = TopicBuilder.validateTopic(
          'msh/chat/+',
          allowWildcards: true,
        );
        expect(result.isValid, isTrue);
      });

      test('accepts multiple single-level wildcards', () {
        final result = TopicBuilder.validateTopic(
          '+/+/+',
          allowWildcards: true,
        );
        expect(result.isValid, isTrue);
      });

      test('rejects multi-level wildcard not at end', () {
        final result = TopicBuilder.validateTopic(
          'msh/#/chat',
          allowWildcards: true,
        );
        expect(result.isValid, isFalse);
        expect(result.error, contains('#'));
      });

      test('rejects multi-level wildcard without preceding separator', () {
        final result = TopicBuilder.validateTopic('msh#', allowWildcards: true);
        expect(result.isValid, isFalse);
        expect(result.error, contains('#'));
      });

      test('rejects single-level wildcard not occupying entire level', () {
        final result = TopicBuilder.validateTopic(
          'msh/cha+t/primary',
          allowWildcards: true,
        );
        expect(result.isValid, isFalse);
        expect(result.error, contains('+'));
      });

      test('rejects single-level wildcard mixed with text', () {
        final result = TopicBuilder.validateTopic(
          'msh/+chat/primary',
          allowWildcards: true,
        );
        expect(result.isValid, isFalse);
      });
    });
  });

  group('TopicBuilder.validateTopicRoot', () {
    test('accepts a valid simple root', () {
      final result = TopicBuilder.validateTopicRoot('msh');
      expect(result.isValid, isTrue);
    });

    test('accepts a multi-level root', () {
      final result = TopicBuilder.validateTopicRoot('org/mesh/prod');
      expect(result.isValid, isTrue);
    });

    test('rejects empty root', () {
      final result = TopicBuilder.validateTopicRoot('');
      expect(result.isValid, isFalse);
      expect(result.error, contains('empty'));
    });

    test('rejects root exceeding max length', () {
      final longRoot = 'a' * (GlobalLayerConstants.maxTopicRootLength + 1);
      final result = TopicBuilder.validateTopicRoot(longRoot);
      expect(result.isValid, isFalse);
      expect(result.error, contains('maximum length'));
    });

    test('rejects root with single-level wildcard', () {
      final result = TopicBuilder.validateTopicRoot('msh/+');
      expect(result.isValid, isFalse);
      expect(result.error, contains('wildcards'));
    });

    test('rejects root with multi-level wildcard', () {
      final result = TopicBuilder.validateTopicRoot('msh/#');
      expect(result.isValid, isFalse);
      expect(result.error, contains('wildcards'));
    });

    test('rejects root with null character', () {
      final result = TopicBuilder.validateTopicRoot('msh\u0000');
      expect(result.isValid, isFalse);
      expect(result.error, contains('null character'));
    });

    test('rejects root starting with separator', () {
      final result = TopicBuilder.validateTopicRoot('/msh');
      expect(result.isValid, isFalse);
      expect(result.error, contains('start'));
    });

    test('rejects root ending with separator', () {
      final result = TopicBuilder.validateTopicRoot('msh/');
      expect(result.isValid, isFalse);
      expect(result.error, contains('end'));
    });

    test('rejects root with consecutive separators', () {
      final result = TopicBuilder.validateTopicRoot('msh//test');
      expect(result.isValid, isFalse);
      expect(result.error, contains('consecutive'));
    });
  });

  group('TopicBuilder.unresolvedPlaceholders', () {
    test('returns empty list for fully resolved topic', () {
      expect(TopicBuilder.unresolvedPlaceholders('msh/chat/primary'), isEmpty);
    });

    test('identifies root placeholder', () {
      final result = TopicBuilder.unresolvedPlaceholders('{root}/chat/primary');
      expect(result, ['{root}']);
    });

    test('identifies channel placeholder', () {
      final result = TopicBuilder.unresolvedPlaceholders('msh/chat/{channel}');
      expect(result, ['{channel}']);
    });

    test('identifies nodeId placeholder', () {
      final result = TopicBuilder.unresolvedPlaceholders(
        'msh/telemetry/{nodeId}',
      );
      expect(result, ['{nodeId}']);
    });

    test('identifies multiple unresolved placeholders', () {
      final result = TopicBuilder.unresolvedPlaceholders(
        '{root}/chat/{channel}',
      );
      expect(result, containsAll(['{root}', '{channel}']));
      expect(result.length, 2);
    });

    test('identifies all three placeholders', () {
      final result = TopicBuilder.unresolvedPlaceholders(
        '{root}/{channel}/{nodeId}',
      );
      expect(result.length, 3);
      expect(result, containsAll(['{root}', '{channel}', '{nodeId}']));
    });
  });

  group('TopicBuilder.isFullyResolved', () {
    test('returns true for topic with no placeholders', () {
      expect(TopicBuilder.isFullyResolved('msh/chat/primary'), isTrue);
    });

    test('returns false for topic with root placeholder', () {
      expect(TopicBuilder.isFullyResolved('{root}/chat/primary'), isFalse);
    });

    test('returns false for topic with channel placeholder', () {
      expect(TopicBuilder.isFullyResolved('msh/chat/{channel}'), isFalse);
    });

    test('returns false for topic with nodeId placeholder', () {
      expect(TopicBuilder.isFullyResolved('msh/telemetry/{nodeId}'), isFalse);
    });
  });

  group('TopicBuilder.placeholderDescription', () {
    test('returns description for root placeholder', () {
      final desc = TopicBuilder.placeholderDescription('{root}');
      expect(desc, isNotEmpty);
      expect(desc, isNot('Unknown placeholder'));
    });

    test('returns description for channel placeholder', () {
      final desc = TopicBuilder.placeholderDescription('{channel}');
      expect(desc, isNotEmpty);
      expect(desc, isNot('Unknown placeholder'));
    });

    test('returns description for nodeId placeholder', () {
      final desc = TopicBuilder.placeholderDescription('{nodeId}');
      expect(desc, isNotEmpty);
      expect(desc, isNot('Unknown placeholder'));
    });

    test('returns unknown for unrecognized placeholder', () {
      final desc = TopicBuilder.placeholderDescription('{bogus}');
      expect(desc, 'Unknown placeholder');
    });
  });

  group('TopicBuilder.buildTestTopic', () {
    test('uses provided root', () {
      final topic = TopicBuilder.buildTestTopic('msh');
      expect(topic, startsWith('msh'));
      expect(topic, contains(GlobalLayerConstants.testTopicSuffix));
    });

    test('falls back to default root when empty', () {
      final topic = TopicBuilder.buildTestTopic('');
      expect(topic, startsWith(GlobalLayerConstants.defaultTopicRoot));
      expect(topic, contains(GlobalLayerConstants.testTopicSuffix));
    });

    test('produces a valid topic', () {
      final topic = TopicBuilder.buildTestTopic('msh');
      // Test topics should not contain wildcards
      final validation = TopicBuilder.validateTopic(topic);
      expect(validation.isValid, isTrue);
    });

    test('uses custom root correctly', () {
      final topic = TopicBuilder.buildTestTopic('my/custom/root');
      expect(topic, 'my/custom/root${GlobalLayerConstants.testTopicSuffix}');
    });
  });

  group('TopicTemplate built-in templates', () {
    test('all built-in templates have non-empty labels', () {
      for (final template in TopicTemplate.builtIn) {
        expect(template.label, isNotEmpty, reason: 'Template has empty label');
      }
    });

    test('all built-in templates have non-empty descriptions', () {
      for (final template in TopicTemplate.builtIn) {
        expect(
          template.description,
          isNotEmpty,
          reason: 'Template "${template.label}" has empty description',
        );
      }
    });

    test('all built-in templates have non-empty icon names', () {
      for (final template in TopicTemplate.builtIn) {
        expect(
          template.iconName,
          isNotEmpty,
          reason: 'Template "${template.label}" has empty icon name',
        );
      }
    });

    test('all built-in templates contain root placeholder', () {
      for (final template in TopicTemplate.builtIn) {
        expect(
          template.pattern,
          contains('{root}'),
          reason: 'Template "${template.label}" is missing {root} placeholder',
        );
      }
    });

    test(
      'all built-in templates have valid patterns after root resolution',
      () {
        for (final template in TopicTemplate.builtIn) {
          final resolved = TopicBuilder.resolveWithConfig(
            pattern: template.pattern,
            topicRoot: 'msh',
            channel: 'test',
            nodeId: 'node1',
          );
          final validation = TopicBuilder.validateTopic(resolved);
          expect(
            validation.isValid,
            isTrue,
            reason:
                'Template "${template.label}" produces invalid topic: '
                '$resolved — ${validation.error}',
          );
        }
      },
    );

    test('all built-in templates default to disabled', () {
      for (final template in TopicTemplate.builtIn) {
        expect(
          template.enabledByDefault,
          isFalse,
          reason: 'Template "${template.label}" should default to disabled',
        );
      }
    });

    test('there are at least 3 built-in templates', () {
      expect(TopicTemplate.builtIn.length, greaterThanOrEqualTo(3));
    });
  });

  group('TopicValidationResult', () {
    test('valid result has isValid true and null error', () {
      const result = TopicValidationResult.valid();
      expect(result.isValid, isTrue);
      expect(result.error, isNull);
    });

    test('invalid result has isValid false and non-null error', () {
      const result = TopicValidationResult.invalid('some error');
      expect(result.isValid, isFalse);
      expect(result.error, 'some error');
    });

    test('toString for valid result', () {
      const result = TopicValidationResult.valid();
      expect(result.toString(), 'Valid');
    });

    test('toString for invalid result includes error', () {
      const result = TopicValidationResult.invalid('bad topic');
      expect(result.toString(), contains('bad topic'));
    });
  });

  group('ResolvedTopic', () {
    test('toString includes label and topic', () {
      const resolved = ResolvedTopic(
        pattern: '{root}/chat/{channel}',
        topic: 'msh/chat/primary',
        label: 'Chat',
        substitutions: {'root': 'msh', 'channel': 'primary'},
      );
      final str = resolved.toString();
      expect(str, contains('Chat'));
      expect(str, contains('msh/chat/primary'));
    });
  });
}
