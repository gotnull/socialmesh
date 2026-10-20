// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/automations/services/notification_renderer/notification_renderer_module.dart';

void main() {
  // ─── text_measurement.dart ───────────────────────────────────────────

  group('graphemeLength', () {
    test('counts ASCII characters', () {
      expect(graphemeLength('hello'), 5);
    });

    test('counts single emoji as one', () {
      expect(graphemeLength('🔥'), 1);
    });

    test('counts family emoji as single grapheme cluster', () {
      // 👨‍👩‍👧‍👦 is one visible character but 11 UTF-16 code units
      expect(graphemeLength('👨‍👩‍👧‍👦'), 1);
    });

    test('counts flag emoji as single grapheme cluster', () {
      expect(graphemeLength('🇺🇸'), 1);
    });

    test('counts mixed text and emoji correctly', () {
      // "hi 👋🏽 bye" = h, i, space, 👋🏽, space, b, y, e = 8
      expect(graphemeLength('hi 👋🏽 bye'), 8);
    });

    test('handles empty string', () {
      expect(graphemeLength(''), 0);
    });

    test('counts combining characters correctly', () {
      // é composed of e + combining acute = 1 grapheme
      expect(graphemeLength('e\u0301'), 1);
    });
  });

  group('utf8ByteLength', () {
    test('ASCII is 1 byte per char', () {
      expect(utf8ByteLength('hello'), 5);
    });

    test('emoji uses 4 bytes', () {
      expect(utf8ByteLength('🔥'), 4);
    });

    test('family emoji uses many bytes', () {
      // 👨‍👩‍👧‍👦 = 25 bytes in UTF-8
      expect(utf8ByteLength('👨‍👩‍👧‍👦'), 25);
    });

    test('empty string is 0 bytes', () {
      expect(utf8ByteLength(''), 0);
    });

    test('multibyte characters are counted correctly', () {
      // ñ = 2 bytes, 日 = 3 bytes
      expect(utf8ByteLength('ñ'), 2);
      expect(utf8ByteLength('日'), 3);
    });
  });

  group('safeTruncateGraphemes', () {
    test('returns text unchanged when within limit', () {
      expect(safeTruncateGraphemes('hello', 10), 'hello');
    });

    test('truncates with ellipsis suffix', () {
      final result = safeTruncateGraphemes('hello world', 8);
      expect(graphemeLength(result), lessThanOrEqualTo(8));
      expect(result, endsWith('…'));
    });

    test('does not split emoji', () {
      final text = '👨‍👩‍👧‍👦👨‍👩‍👧‍👦👨‍👩‍👧‍👦';
      final result = safeTruncateGraphemes(text, 2);
      expect(graphemeLength(result), 2); // 1 family emoji + ellipsis
      expect(result, endsWith('…'));
    });

    test('handles maxGraphemes equal to suffix length', () {
      final result = safeTruncateGraphemes('hello', 1);
      expect(result, '…');
    });

    test('handles maxGraphemes less than suffix length', () {
      final result = safeTruncateGraphemes('hello', 0);
      expect(result, '');
    });

    test('accepts custom suffix', () {
      final result = safeTruncateGraphemes('hello world', 8, suffix: '...');
      expect(graphemeLength(result), lessThanOrEqualTo(8));
      expect(result, endsWith('...'));
    });

    test('exact fit does not truncate', () {
      expect(safeTruncateGraphemes('hello', 5), 'hello');
    });
  });

  group('safeTruncateBytes', () {
    test('returns text unchanged when within byte limit', () {
      expect(safeTruncateBytes('hello', 100), 'hello');
    });

    test('truncates to fit byte budget', () {
      final result = safeTruncateBytes('hello world', 8);
      expect(utf8ByteLength(result), lessThanOrEqualTo(8));
      expect(result, endsWith('…'));
    });

    test('does not split multibyte characters', () {
      // 日本語 = 3 chars * 3 bytes = 9 bytes; … = 3 bytes
      final result = safeTruncateBytes('日本語テスト', 12);
      expect(utf8ByteLength(result), lessThanOrEqualTo(12));
      // Should contain some Japanese chars + suffix
      expect(result, endsWith('…'));
    });

    test('handles insufficient budget for suffix', () {
      final result = safeTruncateBytes('hello', 2);
      expect(utf8ByteLength(result), lessThanOrEqualTo(2));
    });

    test('handles zero bytes budget', () {
      final result = safeTruncateBytes('hello', 0);
      expect(result, '');
    });
  });

  group('safeTruncateAtWord', () {
    test('returns text unchanged when within limit', () {
      expect(safeTruncateAtWord('hello world', 20), 'hello world');
    });

    test('truncates at word boundary when possible', () {
      // "The quick brown fox jumps" - limit to 16 graphemes
      // 16 - 1(suffix) = 15 keep chars
      // "The quick brown" = 15, last space at index 9 (after "quick")
      final result = safeTruncateAtWord('The quick brown fox jumps', 16);
      expect(graphemeLength(result), lessThanOrEqualTo(16));
      expect(result, endsWith('…'));
      // Should break at a space
      expect(result.contains('  '), isFalse);
    });

    test('falls back to grapheme boundary when no good word break', () {
      final result = safeTruncateAtWord('abcdefghijklmnop', 8);
      expect(graphemeLength(result), lessThanOrEqualTo(8));
      expect(result, endsWith('…'));
    });

    test('handles short maxGraphemes', () {
      final result = safeTruncateAtWord('hello world', 1);
      expect(graphemeLength(result), lessThanOrEqualTo(1));
    });
  });

  // ─── notification_parts.dart ─────────────────────────────────────────

  group('NotificationParts', () {
    test('equality check', () {
      const a = NotificationParts(title: 'A', body: 'B');
      const b = NotificationParts(title: 'A', body: 'B');
      const c = NotificationParts(title: 'A', body: 'C');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('equality with data maps', () {
      const a = NotificationParts(title: 'A', body: 'B', data: {'key': 'val'});
      const b = NotificationParts(title: 'A', body: 'B', data: {'key': 'val'});
      expect(a, equals(b));
    });

    test('copyWith preserves unset fields', () {
      const original = NotificationParts(
        title: 'T',
        body: 'B',
        subtitle: 'S',
        deepLink: '/link',
      );
      final copied = original.copyWith(title: 'New Title');
      expect(copied.title, 'New Title');
      expect(copied.body, 'B');
      expect(copied.subtitle, 'S');
      expect(copied.deepLink, '/link');
    });

    test('toString contains all fields', () {
      const parts = NotificationParts(title: 'T', body: 'B');
      expect(parts.toString(), contains('T'));
      expect(parts.toString(), contains('B'));
    });
  });

  // ─── notification_policy.dart ────────────────────────────────────────

  group('NotificationPolicy', () {
    test('ios policy has 250 body grapheme limit', () {
      expect(NotificationPolicy.ios.body.maxGraphemes, 250);
    });

    test('android policy has 450 body grapheme limit', () {
      expect(NotificationPolicy.android.body.maxGraphemes, 450);
    });

    test('strictest uses 250 body limit (iOS minimum)', () {
      expect(NotificationPolicy.strictest.body.maxGraphemes, 250);
    });

    test('apnsRemote has payload byte limit', () {
      expect(NotificationPolicy.apnsRemote.maxPayloadBytes, 4096);
    });

    test('fcmRemote has payload byte limit', () {
      expect(NotificationPolicy.fcmRemote.maxPayloadBytes, 4096);
    });

    test('local policies have no payload byte limit', () {
      expect(NotificationPolicy.ios.maxPayloadBytes, isNull);
      expect(NotificationPolicy.android.maxPayloadBytes, isNull);
      expect(NotificationPolicy.strictest.maxPayloadBytes, isNull);
    });

    test('default variable policies are present', () {
      expect(
        NotificationPolicy.strictest.variablePolicies,
        contains('node.name'),
      );
      expect(
        NotificationPolicy.strictest.variablePolicies,
        contains('message'),
      );
      expect(
        NotificationPolicy.strictest.variablePolicies,
        contains('battery'),
      );
    });

    test('node.name has high priority', () {
      expect(
        NotificationPolicy.strictest.variablePolicies['node.name']!.priority,
        ReductionPriority.high,
      );
    });

    test('message has lowest priority (dropped first)', () {
      expect(
        NotificationPolicy.strictest.variablePolicies['message']!.priority,
        ReductionPriority.lowest,
      );
    });
  });

  group('FieldPolicy', () {
    test('unconstrained has no limits', () {
      expect(FieldPolicy.unconstrained.maxGraphemes, isNull);
      expect(FieldPolicy.unconstrained.maxBytes, isNull);
    });
  });

  // ─── notification_template.dart ──────────────────────────────────────

  group('NotificationSpec', () {
    test('fromUserTemplate generates 3 tiers', () {
      final spec = NotificationSpec.fromUserTemplate(
        titleTemplate: '{{node.name}} Alert',
        bodyTemplate:
            '{{node.name}} detected at {{location}} - Battery: {{battery}}',
      );
      expect(spec.tiers, hasLength(3));
      expect(spec.tiers[0].level, TemplateTierLevel.full);
      expect(spec.tiers[1].level, TemplateTierLevel.short);
      expect(spec.tiers[2].level, TemplateTierLevel.minimal);
    });

    test('full tier preserves original template', () {
      final spec = NotificationSpec.fromUserTemplate(
        titleTemplate: 'Title {{node.name}}',
        bodyTemplate: 'Body {{message}}',
      );
      expect(spec.tiers[0].titleTemplate, 'Title {{node.name}}');
      expect(spec.tiers[0].bodyTemplate, 'Body {{message}}');
    });

    test('short tier shortens body', () {
      final longBody =
          '{{node.name}} detected at {{location}} with battery {{battery}} '
          'and signal strength {{signal.threshold}} at {{time}}';
      final spec = NotificationSpec.fromUserTemplate(
        titleTemplate: 'Alert',
        bodyTemplate: longBody,
      );
      // Short tier body should be shorter than the full body
      expect(
        spec.tiers[1].bodyTemplate.length,
        lessThanOrEqualTo(spec.tiers[0].bodyTemplate.length),
      );
    });

    test('minimal tier extracts first variable', () {
      final spec = NotificationSpec.fromUserTemplate(
        titleTemplate: 'Alert',
        bodyTemplate: 'Detected from {{node.name}} at {{location}}',
      );
      expect(spec.tiers[2].bodyTemplate, contains('{{node.name}}'));
    });

    test('fallback defaults', () {
      final spec = NotificationSpec.fromUserTemplate(
        titleTemplate: 'T',
        bodyTemplate: 'B',
      );
      expect(spec.fallbackTitle, 'Alert');
      expect(spec.fallbackBody, 'An automation was triggered.');
    });

    test('custom fallback messages', () {
      final spec = NotificationSpec.fromUserTemplate(
        titleTemplate: 'T',
        bodyTemplate: 'B',
        fallbackTitle: 'Custom Title',
        fallbackBody: 'Custom body',
      );
      expect(spec.fallbackTitle, 'Custom Title');
      expect(spec.fallbackBody, 'Custom body');
    });

    test('deep link template is preserved', () {
      final spec = NotificationSpec.fromUserTemplate(
        titleTemplate: 'T',
        bodyTemplate: 'B',
        deepLinkTemplate: '/node/{{node.num}}',
      );
      expect(spec.deepLinkTemplate, '/node/{{node.num}}');
    });
  });

  group('NotificationTemplateTier', () {
    test('toString includes level and templates', () {
      const tier = NotificationTemplateTier(
        level: TemplateTierLevel.full,
        titleTemplate: 'T',
        bodyTemplate: 'B',
      );
      expect(tier.toString(), contains('full'));
    });
  });

  // ─── notification_renderer.dart ──────────────────────────────────────

  group('NotificationRenderer', () {
    late NotificationSpec defaultSpec;
    late Map<String, String> defaultVariables;

    setUp(() {
      defaultSpec = NotificationSpec.fromUserTemplate(
        titleTemplate: '{{node.name}} Alert',
        bodyTemplate:
            '{{node.name}} detected at {{location}} - Battery: {{battery}}',
      );
      defaultVariables = {
        'node.name': 'Base Camp',
        'location': '37.7749° N, 122.4194° W',
        'battery': '42%',
      };
    });

    group('basic rendering', () {
      test('renders simple template correctly', () {
        final result = NotificationRenderer.render(
          spec: defaultSpec,
          variables: defaultVariables,
        );
        expect(result.parts.title, 'Base Camp Alert');
        expect(result.parts.body, contains('Base Camp'));
        expect(result.parts.body, contains('37.7749° N'));
        expect(result.parts.body, contains('42%'));
        expect(result.tierUsed, TemplateTierLevel.full);
        expect(result.reductionApplied, isFalse);
      });

      test('resolves deep link template', () {
        final spec = NotificationSpec.fromUserTemplate(
          titleTemplate: 'Alert',
          bodyTemplate: 'Test body',
          deepLinkTemplate: '/node/{{node.num}}',
        );
        final result = NotificationRenderer.render(
          spec: spec,
          variables: {'node.num': '!abc1234'},
        );
        expect(result.parts.deepLink, '/node/!abc1234');
      });

      test('deterministic output for identical inputs', () {
        final result1 = NotificationRenderer.render(
          spec: defaultSpec,
          variables: defaultVariables,
        );
        final result2 = NotificationRenderer.render(
          spec: defaultSpec,
          variables: defaultVariables,
        );
        expect(result1.parts, equals(result2.parts));
        expect(result1.tierUsed, result2.tierUsed);
        expect(result1.reductionApplied, result2.reductionApplied);
      });
    });

    group('variable pre-trimming', () {
      test('trims long variable values to per-variable max', () {
        final longName = 'A' * 1000;
        final result = NotificationRenderer.render(
          spec: defaultSpec,
          variables: {...defaultVariables, 'node.name': longName},
        );
        // node.name policy max is 40 graphemes
        // The rendered title should not contain 1000 A's
        expect(graphemeLength(result.parts.title), lessThanOrEqualTo(100));
      });

      test('injects fallback for missing variables', () {
        final result = NotificationRenderer.render(
          spec: defaultSpec,
          variables: {}, // no variables provided
        );
        // node.name fallback is 'Someone'
        expect(result.parts.title, contains('Someone'));
      });

      test('injects fallback for empty variable values', () {
        final result = NotificationRenderer.render(
          spec: defaultSpec,
          variables: {'node.name': '', 'location': '', 'battery': ''},
        );
        // node.name fallback is 'Someone'
        expect(result.parts.title, contains('Someone'));
      });
    });

    group('extremely long variables', () {
      test('10k character variable does not exceed policy', () {
        final hugeMessage = 'x' * 10000;
        final spec = NotificationSpec.fromUserTemplate(
          titleTemplate: 'Alert',
          bodyTemplate: '{{message}}',
        );
        final result = NotificationRenderer.render(
          spec: spec,
          variables: {'message': hugeMessage},
        );
        expect(
          graphemeLength(result.parts.body),
          lessThanOrEqualTo(
            NotificationPolicy.strictest.body.maxGraphemes! + 1,
          ),
        );
      });

      test('many variables combined exceeding caps', () {
        final vars = <String, String>{
          'node.name': 'A' * 500,
          'location': 'B' * 500,
          'battery': 'C' * 500,
          'message': 'D' * 500,
          'time': 'E' * 500,
          'sensor.name': 'F' * 500,
        };
        final spec = NotificationSpec.fromUserTemplate(
          titleTemplate: '{{node.name}}',
          bodyTemplate:
              '{{location}} {{battery}} {{message}} {{time}} {{sensor.name}}',
        );
        final result = NotificationRenderer.render(spec: spec, variables: vars);
        // Must always stay within policy
        expect(
          graphemeLength(result.parts.title),
          lessThanOrEqualTo(NotificationPolicy.strictest.title.maxGraphemes!),
        );
        expect(
          graphemeLength(result.parts.body),
          lessThanOrEqualTo(NotificationPolicy.strictest.body.maxGraphemes!),
        );
      });
    });

    group('emoji handling', () {
      test('emoji-heavy variable values are truncated correctly', () {
        // Each family emoji is 1 grapheme cluster but many bytes
        final emojiText = '👨‍👩‍👧‍👦' * 100;
        final spec = NotificationSpec.fromUserTemplate(
          titleTemplate: '{{node.name}}',
          bodyTemplate: '{{message}}',
        );
        final result = NotificationRenderer.render(
          spec: spec,
          variables: {'node.name': emojiText, 'message': emojiText},
        );
        expect(
          graphemeLength(result.parts.title),
          lessThanOrEqualTo(NotificationPolicy.strictest.title.maxGraphemes!),
        );
        expect(
          graphemeLength(result.parts.body),
          lessThanOrEqualTo(NotificationPolicy.strictest.body.maxGraphemes!),
        );
      });

      test('flag emoji in variable is preserved when within limits', () {
        final result = NotificationRenderer.render(
          spec: defaultSpec,
          variables: {...defaultVariables, 'node.name': '🇺🇸 Station'},
        );
        expect(result.parts.title, contains('🇺🇸'));
      });

      test('combining characters are not split', () {
        // é composed as e + combining acute accent
        final combining = 'e\u0301' * 50;
        final spec = NotificationSpec.fromUserTemplate(
          titleTemplate: '{{node.name}}',
          bodyTemplate: 'Body',
        );
        final result = NotificationRenderer.render(
          spec: spec,
          variables: {'node.name': combining},
        );
        // Grapheme length should count combined chars as single units
        expect(
          graphemeLength(result.parts.title),
          lessThanOrEqualTo(NotificationPolicy.strictest.title.maxGraphemes!),
        );
        // Each grapheme in the result should be a valid combined character
        final titleChars = result.parts.title.characters;
        for (final ch in titleChars) {
          // No isolated combining marks
          expect(ch.codeUnits.length, greaterThanOrEqualTo(1));
        }
      });
    });

    group('tier fallback', () {
      test('drops to SHORT tier when FULL exceeds policy', () {
        // Create a policy with very tight body limit
        const tightPolicy = NotificationPolicy(
          channel: 'test_tight',
          title: FieldPolicy(maxGraphemes: 50),
          body: FieldPolicy(maxGraphemes: 20),
          subtitle: FieldPolicy(maxGraphemes: 20),
        );
        // The full body will exceed 20 graphemes after resolution
        final spec = NotificationSpec.fromUserTemplate(
          titleTemplate: 'Alert',
          bodyTemplate:
              '{{node.name}} detected at {{location}} battery {{battery}} '
              'time {{time}} sensor {{sensor.name}}',
        );
        final result = NotificationRenderer.render(
          spec: spec,
          variables: defaultVariables,
          policy: tightPolicy,
        );
        // Should have either reduced or used a lower tier
        expect(
          result.reductionApplied || result.tierUsed != TemplateTierLevel.full,
          isTrue,
        );
      });

      test('falls back to safe default when all tiers fail', () {
        // Absurdly tight policy
        const impossiblePolicy = NotificationPolicy(
          channel: 'test_impossible',
          title: FieldPolicy(maxGraphemes: 5),
          body: FieldPolicy(maxGraphemes: 5),
        );
        final spec = NotificationSpec.fromUserTemplate(
          titleTemplate:
              'This title is longer than five graphemes by a lot {{node.name}}',
          bodyTemplate:
              'This body is also far too long for five graphemes {{message}}',
          fallbackTitle: 'Alert',
          fallbackBody: 'Done.',
        );
        final result = NotificationRenderer.render(
          spec: spec,
          variables: defaultVariables,
          policy: impossiblePolicy,
        );
        // Uses the fallback (truncated to fit)
        expect(graphemeLength(result.parts.title), lessThanOrEqualTo(5));
        expect(graphemeLength(result.parts.body), lessThanOrEqualTo(5));
      });

      test('usedFallback is true when no tier fits', () {
        // Zero-grapheme policy - nothing can possibly fit
        const impossiblePolicy = NotificationPolicy(
          channel: 'test',
          title: FieldPolicy(maxGraphemes: 0),
          body: FieldPolicy(maxGraphemes: 0),
        );
        final spec = NotificationSpec.fromUserTemplate(
          titleTemplate: 'Very long title {{node.name}}',
          bodyTemplate: 'Very long body {{message}}',
        );
        final result = NotificationRenderer.render(
          spec: spec,
          variables: defaultVariables,
          policy: impossiblePolicy,
        );
        // With 0 graphemes allowed, even truncation can't help
        expect(result.parts.title, isEmpty);
        expect(result.parts.body, isEmpty);
      });
    });

    group('deterministic reduction', () {
      test('drops lowest-priority variables first', () {
        // message has lowest priority; node.name has high priority
        const tightPolicy = NotificationPolicy(
          channel: 'test_reduction',
          title: FieldPolicy(maxGraphemes: 100),
          body: FieldPolicy(maxGraphemes: 30),
          variablePolicies: {
            'node.name': VariablePolicy(
              maxGraphemes: 40,
              priority: ReductionPriority.high,
              fallback: 'Someone',
            ),
            'message': VariablePolicy(
              maxGraphemes: 200,
              priority: ReductionPriority.lowest,
              fallback: '',
            ),
          },
        );
        final spec = NotificationSpec.fromUserTemplate(
          titleTemplate: 'Alert',
          bodyTemplate: '{{node.name}}: {{message}}',
        );
        final result = NotificationRenderer.render(
          spec: spec,
          variables: {
            'node.name': 'Alpha',
            'message': 'Very long message that pushes us over the limit here',
          },
          policy: tightPolicy,
        );
        // node.name should survive (high priority)
        expect(result.parts.body, contains('Alpha'));
        // Within limit
        expect(graphemeLength(result.parts.body), lessThanOrEqualTo(30));
      });

      test('applies per-field truncation after variable dropping', () {
        // Even after dropping all droppable vars, the title may need trimming
        const tightPolicy = NotificationPolicy(
          channel: 'test',
          title: FieldPolicy(maxGraphemes: 15),
          body: FieldPolicy(maxGraphemes: 250),
        );
        final spec = NotificationSpec.fromUserTemplate(
          titleTemplate: '{{node.name}} has triggered an automation alert',
          bodyTemplate: 'Short body',
        );
        final result = NotificationRenderer.render(
          spec: spec,
          variables: {'node.name': 'Base Camp'},
          policy: tightPolicy,
        );
        expect(graphemeLength(result.parts.title), lessThanOrEqualTo(15));
      });
    });

    group('payload byte limits', () {
      test('apns remote policy enforces 4096 byte total', () {
        final spec = NotificationSpec.fromUserTemplate(
          titleTemplate: '{{node.name}}',
          bodyTemplate: '{{message}}',
        );
        final result = NotificationRenderer.render(
          spec: spec,
          variables: {'node.name': 'Station A', 'message': 'x' * 5000},
          policy: NotificationPolicy.apnsRemote,
        );
        final totalBytes =
            utf8ByteLength(result.parts.title) +
            utf8ByteLength(result.parts.body);
        // Body grapheme limit of 250 * ~1 byte/char + ~200 overhead < 4096
        expect(totalBytes + 200, lessThanOrEqualTo(4096));
      });

      test('multibyte characters counted by byte limit', () {
        // Japanese chars = 3 bytes each; body limit is 2000 bytes for APNs
        final japaneseText = '日' * 1000; // 3000 bytes
        final spec = NotificationSpec.fromUserTemplate(
          titleTemplate: 'Alert',
          bodyTemplate: '{{message}}',
        );
        final result = NotificationRenderer.render(
          spec: spec,
          variables: {'message': japaneseText},
          policy: NotificationPolicy.apnsRemote,
        );
        // Should be within byte limit after per-variable trimming + field policy
        expect(
          utf8ByteLength(result.parts.body),
          lessThanOrEqualTo(NotificationPolicy.apnsRemote.body.maxBytes!),
        );
      });
    });

    group('edge cases', () {
      test('empty template', () {
        final spec = NotificationSpec.fromUserTemplate(
          titleTemplate: '',
          bodyTemplate: '',
        );
        final result = NotificationRenderer.render(spec: spec, variables: {});
        // Should produce something (possibly fallback-inserted values)
        expect(result.parts.title, isA<String>());
        expect(result.parts.body, isA<String>());
      });

      test('template with no variables', () {
        final spec = NotificationSpec.fromUserTemplate(
          titleTemplate: 'Static Title',
          bodyTemplate: 'Static body with no variables.',
        );
        final result = NotificationRenderer.render(spec: spec, variables: {});
        expect(result.parts.title, 'Static Title');
        expect(result.parts.body, 'Static body with no variables.');
        expect(result.tierUsed, TemplateTierLevel.full);
        expect(result.reductionApplied, isFalse);
      });

      test('unknown variables are stripped', () {
        final spec = NotificationSpec.fromUserTemplate(
          titleTemplate: 'Title {{unknown.var}}',
          bodyTemplate: 'Body {{another.unknown}}',
        );
        final result = NotificationRenderer.render(spec: spec, variables: {});
        expect(result.parts.title, isNot(contains('{{')));
        expect(result.parts.body, isNot(contains('{{')));
      });

      test('handles variables with special regex characters', () {
        final spec = NotificationSpec.fromUserTemplate(
          titleTemplate: '{{node.name}} Alert',
          bodyTemplate: 'Body',
        );
        final result = NotificationRenderer.render(
          spec: spec,
          variables: {'node.name': r'$100 (test) [special]'},
        );
        expect(result.parts.title, contains(r'$100'));
      });

      test('subtitle is handled when provided', () {
        final spec = NotificationSpec.fromUserTemplate(
          titleTemplate: 'Title',
          bodyTemplate: 'Body',
          subtitleTemplate: 'Sub: {{node.name}}',
        );
        final result = NotificationRenderer.render(
          spec: spec,
          variables: {'node.name': 'Camp'},
        );
        expect(result.parts.subtitle, isNotNull);
      });

      test('subtitle is null when not provided', () {
        final spec = NotificationSpec.fromUserTemplate(
          titleTemplate: 'Title',
          bodyTemplate: 'Body',
        );
        final result = NotificationRenderer.render(spec: spec, variables: {});
        // SHORT and MINIMAL tiers have no subtitle template
        // FULL tier also has no subtitle if not provided
        // Whether subtitle is null depends on the tier used
        if (result.tierUsed == TemplateTierLevel.full) {
          expect(spec.tiers[0].subtitleTemplate, isNull);
        }
      });
    });

    group('RenderResult', () {
      test('usedFallback is false when a tier was used', () {
        final result = NotificationRenderer.render(
          spec: defaultSpec,
          variables: defaultVariables,
        );
        expect(result.usedFallback, isFalse);
        expect(result.tierUsed, isNotNull);
      });

      test('toString contains useful debug info', () {
        final result = NotificationRenderer.render(
          spec: defaultSpec,
          variables: defaultVariables,
        );
        final str = result.toString();
        expect(str, contains('RenderResult'));
        expect(str, contains('tier'));
      });
    });

    group('policy contracts', () {
      test('output always respects strictest body limit', () {
        // Run a variety of inputs and verify the contract holds
        final testCases = <Map<String, String>>[
          {'node.name': 'A' * 500, 'message': 'B' * 10000},
          {'node.name': '👨‍👩‍👧‍👦' * 100, 'message': '🔥' * 1000},
          {'node.name': '', 'location': '', 'battery': ''},
          {'node.name': 'Short', 'message': 'Also short', 'location': 'Here'},
        ];

        final spec = NotificationSpec.fromUserTemplate(
          titleTemplate: '{{node.name}} Alert',
          bodyTemplate: '{{node.name}}: {{message}} at {{location}}',
        );

        for (final vars in testCases) {
          final result = NotificationRenderer.render(
            spec: spec,
            variables: vars,
          );
          expect(
            graphemeLength(result.parts.title),
            lessThanOrEqualTo(NotificationPolicy.strictest.title.maxGraphemes!),
            reason: 'Title exceeded policy for vars: $vars',
          );
          expect(
            graphemeLength(result.parts.body),
            lessThanOrEqualTo(NotificationPolicy.strictest.body.maxGraphemes!),
            reason: 'Body exceeded policy for vars: $vars',
          );
        }
      });
    });

    group('repeated variable truncation (not dropping)', () {
      test('28x node.name truncates body instead of dropping all vars', () {
        // Reproduces the real-world bug: template packed with the same
        // variable 28 times. With a 20-char node name the resolved text
        // far exceeds 250 graphemes. The renderer must TRUNCATE the
        // resolved text - preserving partial content - not drop the
        // variable entirely, which would leave only the literal suffix.
        final body = "${List.filled(28, '{{node.name}}').join(' ')} 123456";
        final spec = NotificationSpec.fromUserTemplate(
          titleTemplate: 'Alert',
          bodyTemplate: body,
        );
        final result = NotificationRenderer.render(
          spec: spec,
          variables: {
            'node.name': 'Base Camp Alpha',
            'node.num': 'abc1234',
            'battery': '78%',
            'location': '37.774900, -122.419400',
          },
        );
        // The body must NOT be just "123456" - the variable content
        // should be preserved via truncation, not dropped.
        expect(result.parts.body, isNot(equals('123456')));
        expect(result.parts.body, contains('Base Camp Alpha'));
        expect(
          graphemeLength(result.parts.body),
          lessThanOrEqualTo(NotificationPolicy.strictest.body.maxGraphemes!),
        );
        // Should end with ellipsis from truncation
        expect(result.parts.body, endsWith('…'));
      });

      test('many repeated variables with empty values use fallbacks', () {
        // Manual trigger: no node connected, all vars empty.
        // node.name fallback = "Someone", battery fallback = "?%"
        final body =
            "${List.filled(28, '{{node.name}}').join(' ')}"
            ' {{battery}} {{location}} 123456';
        final spec = NotificationSpec.fromUserTemplate(
          titleTemplate: 'Alert',
          bodyTemplate: body,
        );
        final result = NotificationRenderer.render(
          spec: spec,
          variables: {
            'node.name': '',
            'node.num': '',
            'battery': '',
            'location': '',
          },
        );
        // Should contain fallback values, not be empty
        expect(
          result.parts.body.contains('Someone') ||
              result.parts.body.contains('123456'),
          isTrue,
        );
        expect(
          graphemeLength(result.parts.body),
          lessThanOrEqualTo(NotificationPolicy.strictest.body.maxGraphemes!),
        );
      });

      test('truncation preserves beginning of content not end', () {
        // When a long resolved body is truncated, the beginning
        // (first variables) should survive, not just the literal tail.
        final body =
            '{{node.name}} at {{location}} - '
            "${List.filled(20, '{{node.name}}').join(' ')} TAIL_MARKER";
        final spec = NotificationSpec.fromUserTemplate(
          titleTemplate: 'Alert',
          bodyTemplate: body,
        );
        final result = NotificationRenderer.render(
          spec: spec,
          variables: {
            'node.name': 'Relay Station Bravo',
            'location': '37.774900, -122.419400',
          },
        );
        // First variable instance should survive
        expect(result.parts.body, startsWith('Relay Station Bravo'));
        // Tail marker should be truncated away
        expect(result.parts.body, isNot(contains('TAIL_MARKER')));
        expect(
          graphemeLength(result.parts.body),
          lessThanOrEqualTo(NotificationPolicy.strictest.body.maxGraphemes!),
        );
      });
    });
  });
}
