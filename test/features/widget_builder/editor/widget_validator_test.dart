// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/widget_builder/editor/widget_validator.dart';
import 'package:socialmesh/features/widget_builder/models/widget_schema.dart';

void main() {
  group('WidgetValidator', () {
    group('basic validation', () {
      test('valid widget passes validation', () {
        final widget = WidgetSchema(
          name: 'My Widget',
          description: 'A test widget',
          root: ElementSchema(
            type: ElementType.column,
            children: [ElementSchema(type: ElementType.text, text: 'Hello')],
          ),
        );

        final result = WidgetValidator.validate(widget);

        expect(result.isValid, isTrue);
        expect(result.hasErrors, isFalse);
      });

      test('empty widget fails validation', () {
        final widget = WidgetSchema(
          name: 'Empty Widget',
          root: ElementSchema(type: ElementType.column),
        );

        final result = WidgetValidator.validate(widget);

        expect(result.isValid, isFalse);
        expect(result.hasErrors, isTrue);
        expect(result.errors.any((e) => e.message.contains('empty')), isTrue);
      });

      test('default name generates warning', () {
        final widget = WidgetSchema(
          name: 'New Widget',
          root: ElementSchema(
            type: ElementType.column,
            children: [ElementSchema(type: ElementType.text, text: 'Hello')],
          ),
        );

        final result = WidgetValidator.validate(widget);

        expect(result.hasWarnings, isTrue);
        expect(
          result.warnings.any((w) => w.message.contains('descriptive name')),
          isTrue,
        );
      });
    });

    group('metadata validation', () {
      test('name too long fails validation', () {
        final longName = 'A' * (ValidationLimits.maxNameLength + 1);
        final widget = WidgetSchema(
          name: longName,
          root: ElementSchema(
            type: ElementType.column,
            children: [ElementSchema(type: ElementType.text, text: 'Hello')],
          ),
        );

        final result = WidgetValidator.validate(widget);

        expect(result.hasErrors, isTrue);
        expect(
          result.errors.any((e) => e.message.contains('too long')),
          isTrue,
        );
      });

      test('description too long fails validation', () {
        final longDesc = 'A' * (ValidationLimits.maxDescriptionLength + 1);
        final widget = WidgetSchema(
          name: 'Test Widget',
          description: longDesc,
          root: ElementSchema(
            type: ElementType.column,
            children: [ElementSchema(type: ElementType.text, text: 'Hello')],
          ),
        );

        final result = WidgetValidator.validate(widget);

        expect(result.hasErrors, isTrue);
        expect(
          result.errors.any(
            (e) => e.message.contains('Description is too long'),
          ),
          isTrue,
        );
      });

      test('too many tags generates warning', () {
        final widget = WidgetSchema(
          name: 'Test Widget',
          tags: List.generate(ValidationLimits.maxTags + 5, (i) => 'tag$i'),
          root: ElementSchema(
            type: ElementType.column,
            children: [ElementSchema(type: ElementType.text, text: 'Hello')],
          ),
        );

        final result = WidgetValidator.validate(widget);

        expect(result.hasWarnings, isTrue);
        expect(
          result.warnings.any((w) => w.message.contains('Too many tags')),
          isTrue,
        );
      });
    });

    group('nesting depth validation', () {
      test('deeply nested widget fails validation', () {
        // Create deeply nested structure exceeding max depth
        ElementSchema createNestedColumn(int depth) {
          if (depth > ValidationLimits.maxNestingDepth + 2) {
            return ElementSchema(type: ElementType.text, text: 'Deep');
          }
          return ElementSchema(
            type: ElementType.column,
            children: [createNestedColumn(depth + 1)],
          );
        }

        final widget = WidgetSchema(
          name: 'Deep Widget',
          root: createNestedColumn(0),
        );

        final result = WidgetValidator.validate(widget);

        expect(result.hasErrors, isTrue);
        expect(
          result.errors.any((e) => e.message.contains('too deep')),
          isTrue,
        );
      });

      test('acceptable nesting depth passes', () {
        // Create nested structure within limits
        ElementSchema createNestedColumn(int depth) {
          if (depth >= 5) {
            return ElementSchema(type: ElementType.text, text: 'OK');
          }
          return ElementSchema(
            type: ElementType.column,
            children: [createNestedColumn(depth + 1)],
          );
        }

        final widget = WidgetSchema(
          name: 'Valid Nested Widget',
          root: createNestedColumn(0),
        );

        final result = WidgetValidator.validate(widget);

        expect(result.isValid, isTrue);
      });
    });

    group('children count validation', () {
      test('too many children fails validation', () {
        final widget = WidgetSchema(
          name: 'Many Children Widget',
          root: ElementSchema(
            type: ElementType.column,
            children: List.generate(
              ValidationLimits.maxChildrenPerContainer + 1,
              (i) => ElementSchema(type: ElementType.text, text: 'Item $i'),
            ),
          ),
        );

        final result = WidgetValidator.validate(widget);

        expect(result.hasErrors, isTrue);
        expect(
          result.errors.any((e) => e.message.contains('too many children')),
          isTrue,
        );
      });
    });

    group('total elements validation', () {
      test('too many total elements fails validation', () {
        // Create a widget that exceeds max total elements
        final widget = WidgetSchema(
          name: 'Huge Widget',
          root: ElementSchema(
            type: ElementType.column,
            children: List.generate(
              5,
              (i) => ElementSchema(
                type: ElementType.column,
                children: List.generate(
                  45, // 5 * 45 = 225 > 200 max
                  (j) => ElementSchema(type: ElementType.text, text: 'Item'),
                ),
              ),
            ),
          ),
        );

        final result = WidgetValidator.validate(widget);

        expect(result.hasErrors, isTrue);
        expect(
          result.errors.any((e) => e.message.contains('too many elements')),
          isTrue,
        );
      });
    });

    group('text element validation', () {
      test('text element without content fails', () {
        final widget = WidgetSchema(
          name: 'Test Widget',
          root: ElementSchema(
            type: ElementType.column,
            children: [ElementSchema(type: ElementType.text)],
          ),
        );

        final result = WidgetValidator.validate(widget);

        expect(result.hasErrors, isTrue);
        expect(
          result.errors.any((e) => e.message.contains('no content')),
          isTrue,
        );
      });

      test('text element with binding passes', () {
        final widget = WidgetSchema(
          name: 'Test Widget',
          root: ElementSchema(
            type: ElementType.column,
            children: [
              ElementSchema(
                type: ElementType.text,
                binding: const BindingSchema(path: 'node.batteryLevel'),
              ),
            ],
          ),
        );

        final result = WidgetValidator.validate(widget);

        // Valid binding should pass (no "no content" error)
        expect(
          result.errors.any((e) => e.message.contains('no content')),
          isFalse,
        );
      });

      test('text too long fails validation', () {
        final longText = 'A' * (ValidationLimits.maxTextLength + 1);
        final widget = WidgetSchema(
          name: 'Test Widget',
          root: ElementSchema(
            type: ElementType.column,
            children: [ElementSchema(type: ElementType.text, text: longText)],
          ),
        );

        final result = WidgetValidator.validate(widget);

        expect(result.hasErrors, isTrue);
        expect(
          result.errors.any((e) => e.message.contains('Text is too long')),
          isTrue,
        );
      });
    });

    group('icon element validation', () {
      test('icon without name fails', () {
        final widget = WidgetSchema(
          name: 'Test Widget',
          root: ElementSchema(
            type: ElementType.column,
            children: [ElementSchema(type: ElementType.icon)],
          ),
        );

        final result = WidgetValidator.validate(widget);

        expect(result.hasErrors, isTrue);
        expect(
          result.errors.any((e) => e.message.contains('no icon selected')),
          isTrue,
        );
      });

      test('icon with name passes', () {
        final widget = WidgetSchema(
          name: 'Test Widget',
          root: ElementSchema(
            type: ElementType.column,
            children: [ElementSchema(type: ElementType.icon, iconName: 'star')],
          ),
        );

        final result = WidgetValidator.validate(widget);

        expect(
          result.errors.any((e) => e.message.contains('no icon selected')),
          isFalse,
        );
      });
    });

    group('gauge element validation', () {
      test('gauge without binding generates warning', () {
        final widget = WidgetSchema(
          name: 'Test Widget',
          root: ElementSchema(
            type: ElementType.column,
            children: [ElementSchema(type: ElementType.gauge)],
          ),
        );

        final result = WidgetValidator.validate(widget);

        expect(result.hasWarnings, isTrue);
        expect(
          result.warnings.any((w) => w.message.contains('no data binding')),
          isTrue,
        );
      });

      test('gauge with invalid min/max fails', () {
        final widget = WidgetSchema(
          name: 'Test Widget',
          root: ElementSchema(
            type: ElementType.column,
            children: [
              ElementSchema(
                type: ElementType.gauge,
                gaugeMin: 100,
                gaugeMax: 50, // Invalid: min > max
                binding: const BindingSchema(path: 'node.batteryLevel'),
              ),
            ],
          ),
        );

        final result = WidgetValidator.validate(widget);

        expect(result.hasErrors, isTrue);
        expect(
          result.errors.any(
            (e) => e.message.contains('min must be less than max'),
          ),
          isTrue,
        );
      });
    });

    group('button element validation', () {
      test('button without action fails', () {
        final widget = WidgetSchema(
          name: 'Test Widget',
          root: ElementSchema(
            type: ElementType.column,
            children: [
              ElementSchema(type: ElementType.button, text: 'Click me'),
            ],
          ),
        );

        final result = WidgetValidator.validate(widget);

        expect(result.hasErrors, isTrue);
        expect(
          result.errors.any((e) => e.message.contains('no action configured')),
          isTrue,
        );
      });

      test('button without label/icon generates warning', () {
        final widget = WidgetSchema(
          name: 'Test Widget',
          root: ElementSchema(
            type: ElementType.column,
            children: [
              ElementSchema(
                type: ElementType.button,
                action: const ActionSchema(
                  type: ActionType.navigate,
                  navigateTo: '/home',
                ),
              ),
            ],
          ),
        );

        final result = WidgetValidator.validate(widget);

        expect(result.hasWarnings, isTrue);
        expect(
          result.warnings.any((w) => w.message.contains('no label or icon')),
          isTrue,
        );
      });
    });

    group('ValidationResult', () {
      test('filters errors correctly', () {
        final result = ValidationResult(
          issues: [
            const ValidationIssue(
              severity: ValidationSeverity.error,
              message: 'Error 1',
            ),
            const ValidationIssue(
              severity: ValidationSeverity.warning,
              message: 'Warning 1',
            ),
            const ValidationIssue(
              severity: ValidationSeverity.error,
              message: 'Error 2',
            ),
          ],
          isValid: false,
        );

        expect(result.errors.length, 2);
        expect(result.warnings.length, 1);
      });
    });

    group('ValidationLimits', () {
      test('limits are reasonable', () {
        expect(ValidationLimits.maxNestingDepth, greaterThanOrEqualTo(5));
        expect(
          ValidationLimits.maxChildrenPerContainer,
          greaterThanOrEqualTo(20),
        );
        expect(ValidationLimits.maxTotalElements, greaterThanOrEqualTo(100));
        expect(ValidationLimits.maxTextLength, greaterThanOrEqualTo(500));
        expect(ValidationLimits.maxNameLength, greaterThanOrEqualTo(50));
        expect(
          ValidationLimits.maxDescriptionLength,
          greaterThanOrEqualTo(200),
        );
      });
    });
  });
}
