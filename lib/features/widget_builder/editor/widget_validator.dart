// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../models/widget_schema.dart';
import '../models/data_binding.dart';

/// Validation constants - these limits prevent abuse and ensure performance
class ValidationLimits {
  /// Maximum depth of nested elements (prevents stack overflow during render)
  static const int maxNestingDepth = 10;

  /// Maximum number of children in a single container
  static const int maxChildrenPerContainer = 50;

  /// Maximum total elements in a widget schema
  static const int maxTotalElements = 200;

  /// Maximum length for text content
  static const int maxTextLength = 1000;

  /// Maximum name/description length
  static const int maxNameLength = 100;
  static const int maxDescriptionLength = 500;

  /// Maximum number of tags
  static const int maxTags = 10;
}

/// Validation issue severity
enum ValidationSeverity {
  error, // Must be fixed before saving
  warning, // Should be fixed but can be saved
  info, // Informational, no action needed
}

/// A single validation issue
class ValidationIssue {
  final ValidationSeverity severity;
  final String message;
  final String? elementId;
  final String? fix; // Suggested fix

  const ValidationIssue({
    required this.severity,
    required this.message,
    this.elementId,
    this.fix,
  });
}

/// Result of widget validation
class ValidationResult {
  final List<ValidationIssue> issues;
  final bool isValid;

  const ValidationResult({required this.issues, required this.isValid});

  bool get hasErrors =>
      issues.any((i) => i.severity == ValidationSeverity.error);
  bool get hasWarnings =>
      issues.any((i) => i.severity == ValidationSeverity.warning);

  List<ValidationIssue> get errors =>
      issues.where((i) => i.severity == ValidationSeverity.error).toList();
  List<ValidationIssue> get warnings =>
      issues.where((i) => i.severity == ValidationSeverity.warning).toList();
}

/// Validates widget schemas for completeness and correctness
class WidgetValidator {
  /// Validate a widget schema
  static ValidationResult validate(WidgetSchema schema) {
    final issues = <ValidationIssue>[];

    // Validate metadata fields
    _validateMetadata(schema, issues);

    // Check if widget has any content
    if (schema.root.children.isEmpty) {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.error,
          message: 'Widget is empty', // lint-allow: hardcoded-string
          fix: 'Add some elements to your widget', // lint-allow: hardcoded-string
        ),
      );
    }

    // Count total elements and check limits
    var totalElements = 0;
    _countElements(schema.root, (count) => totalElements = count);
    if (totalElements > ValidationLimits.maxTotalElements) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          message:
              'Widget has too many elements ($totalElements). Maximum is ${ValidationLimits.maxTotalElements}.', // lint-allow: hardcoded-string
          fix: 'Simplify your widget by removing unnecessary elements', // lint-allow: hardcoded-string
        ),
      );
    }

    // Recursively validate all elements with depth tracking
    _validateElement(schema.root, issues, isRoot: true, depth: 0);

    // Calculate overall validity
    final hasErrors = issues.any((i) => i.severity == ValidationSeverity.error);

    return ValidationResult(issues: issues, isValid: !hasErrors);
  }

  /// Validate widget metadata (name, description, tags)
  static void _validateMetadata(
    WidgetSchema schema,
    List<ValidationIssue> issues,
  ) {
    // Check widget name
    if (schema.name.isEmpty || schema.name == 'New Widget') {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.warning,
          message: 'Give your widget a descriptive name', // lint-allow: hardcoded-string
          fix: 'Tap the title to rename', // lint-allow: hardcoded-string
        ),
      );
    }

    if (schema.name.length > ValidationLimits.maxNameLength) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          message:
              'Widget name is too long (${schema.name.length} characters). Maximum is ${ValidationLimits.maxNameLength}.', // lint-allow: hardcoded-string
          fix: 'Use a shorter name', // lint-allow: hardcoded-string
        ),
      );
    }

    if (schema.description != null &&
        schema.description!.length > ValidationLimits.maxDescriptionLength) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          message:
              'Description is too long. Maximum is ${ValidationLimits.maxDescriptionLength} characters.', // lint-allow: hardcoded-string
          fix: 'Shorten the description', // lint-allow: hardcoded-string
        ),
      );
    }

    if (schema.tags.length > ValidationLimits.maxTags) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.warning,
          message:
              'Too many tags (${schema.tags.length}). Maximum is ${ValidationLimits.maxTags}.', // lint-allow: hardcoded-string
          fix: 'Remove some tags', // lint-allow: hardcoded-string
        ),
      );
    }
  }

  /// Count total elements recursively
  static void _countElements(
    ElementSchema element,
    void Function(int) onCount,
  ) {
    var count = 1;
    for (final child in element.children) {
      _countElements(child, (childCount) => count += childCount);
    }
    onCount(count);
  }

  static void _validateElement(
    ElementSchema element,
    List<ValidationIssue> issues, {
    bool isRoot = false,
    int depth = 0,
  }) {
    // Check nesting depth
    if (depth > ValidationLimits.maxNestingDepth) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          message:
              'Widget nesting is too deep ($depth levels). Maximum is ${ValidationLimits.maxNestingDepth}.', // lint-allow: hardcoded-string
          elementId: element.id,
          fix: 'Flatten your widget structure', // lint-allow: hardcoded-string
        ),
      );
      return; // Stop validating deeper
    }

    // Check children count
    if (element.children.length > ValidationLimits.maxChildrenPerContainer) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          message:
              'Container has too many children (${element.children.length}). Maximum is ${ValidationLimits.maxChildrenPerContainer}.', // lint-allow: hardcoded-string
          elementId: element.id,
          fix: 'Split into multiple containers', // lint-allow: hardcoded-string
        ),
      );
    }

    switch (element.type) {
      case ElementType.text:
        _validateText(element, issues);
        break;
      case ElementType.icon:
        _validateIcon(element, issues);
        break;
      case ElementType.gauge:
        _validateGauge(element, issues);
        break;
      case ElementType.chart:
        _validateChart(element, issues);
        break;
      case ElementType.button:
        _validateButton(element, issues);
        break;
      case ElementType.row:
      case ElementType.column:
        _validateLayout(element, issues);
        break;
      default:
        break;
    }

    // Validate action if present
    if (element.action != null) {
      _validateAction(element, issues);
    }

    // Recursively validate children with incremented depth
    for (final child in element.children) {
      _validateElement(child, issues, depth: depth + 1);
    }
  }

  static void _validateText(
    ElementSchema element,
    List<ValidationIssue> issues,
  ) {
    final hasText = element.text != null && element.text!.isNotEmpty;
    final hasBinding = element.binding != null;

    if (!hasText && !hasBinding) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          message:
              'Text element has no content', // lint-allow: hardcoded-string
          elementId: element.id,
          fix: 'Add text or bind to data', // lint-allow: hardcoded-string
        ),
      );
    }

    // Check text length limit
    if (hasText && element.text!.length > ValidationLimits.maxTextLength) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          message:
              'Text is too long (${element.text!.length} characters). Maximum is ${ValidationLimits.maxTextLength}.', // lint-allow: hardcoded-string
          elementId: element.id,
          fix: 'Shorten the text content', // lint-allow: hardcoded-string
        ),
      );
    }

    if (hasBinding) {
      _validateBinding(element.binding!, element.id, issues);
    }
  }

  static void _validateIcon(
    ElementSchema element,
    List<ValidationIssue> issues,
  ) {
    if (element.iconName == null || element.iconName!.isEmpty) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          message: 'Icon element has no icon selected', // lint-allow: hardcoded-string
          elementId: element.id,
          fix: 'Select an icon', // lint-allow: hardcoded-string
        ),
      );
    }
  }

  static void _validateGauge(
    ElementSchema element,
    List<ValidationIssue> issues,
  ) {
    if (element.binding == null) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.warning,
          message: 'Gauge has no data binding', // lint-allow: hardcoded-string
          elementId: element.id,
          fix: 'Bind to a numeric value like battery or signal', // lint-allow: hardcoded-string
        ),
      );
    } else {
      _validateBinding(element.binding!, element.id, issues);

      // Check if binding is numeric
      final bindingInfo = BindingRegistry.bindings
          .where((b) => b.path == element.binding!.path)
          .firstOrNull;
      if (bindingInfo != null &&
          bindingInfo.valueType != num &&
          bindingInfo.valueType != int &&
          bindingInfo.valueType != double) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.warning,
            message: 'Gauge is bound to non-numeric data', // lint-allow: hardcoded-string
            elementId: element.id,
            fix: 'Gauges work best with numeric values', // lint-allow: hardcoded-string
          ),
        );
      }
    }

    // Validate min/max
    final min = element.gaugeMin ?? 0;
    final max = element.gaugeMax ?? 100;
    if (min >= max) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          message:
              'Gauge min must be less than max', // lint-allow: hardcoded-string
          elementId: element.id,
          fix: 'Set min < max', // lint-allow: hardcoded-string
        ),
      );
    }
  }

  static void _validateChart(
    ElementSchema element,
    List<ValidationIssue> issues,
  ) {
    if (element.binding == null) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.warning,
          message: 'Chart has no data binding', // lint-allow: hardcoded-string
          elementId: element.id,
          fix: 'Bind to data like SNR history', // lint-allow: hardcoded-string
        ),
      );
    } else {
      _validateBinding(element.binding!, element.id, issues);
    }
  }

  static void _validateButton(
    ElementSchema element,
    List<ValidationIssue> issues,
  ) {
    // Buttons should have an action
    if (element.action == null || element.action!.type == ActionType.none) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          message: 'Action button has no action configured', // lint-allow: hardcoded-string
          elementId: element.id,
          fix: 'Configure what happens when tapped', // lint-allow: hardcoded-string
        ),
      );
    }

    // Buttons should have a label
    if ((element.text == null || element.text!.isEmpty) &&
        (element.iconName == null || element.iconName!.isEmpty)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.warning,
          message:
              'Button has no label or icon', // lint-allow: hardcoded-string
          elementId: element.id,
          fix: 'Add text or an icon', // lint-allow: hardcoded-string
        ),
      );
    }
  }

  static void _validateLayout(
    ElementSchema element,
    List<ValidationIssue> issues,
  ) {
    if (element.children.isEmpty) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.info,
          message:
              '${element.type == ElementType.row ? 'Row' : 'Column'} is empty',
          elementId: element.id,
          fix: 'Add elements inside', // lint-allow: hardcoded-string
        ),
      );
    }
  }

  static void _validateAction(
    ElementSchema element,
    List<ValidationIssue> issues,
  ) {
    final action = element.action!;

    switch (action.type) {
      case ActionType.navigate:
        if (action.navigateTo == null || action.navigateTo!.isEmpty) {
          issues.add(
            ValidationIssue(
              severity: ValidationSeverity.error,
              message: 'Navigate action has no destination', // lint-allow: hardcoded-string
              elementId: element.id,
              fix: 'Select where to navigate', // lint-allow: hardcoded-string
            ),
          );
        }
        break;
      case ActionType.openUrl:
        if (action.url == null || action.url!.isEmpty) {
          issues.add(
            ValidationIssue(
              severity: ValidationSeverity.error,
              message:
                  'Open URL action has no URL', // lint-allow: hardcoded-string
              elementId: element.id,
              fix: 'Enter the URL to open', // lint-allow: hardcoded-string
            ),
          );
        } else if (!Uri.tryParse(action.url!)!.hasScheme) {
          issues.add(
            ValidationIssue(
              severity: ValidationSeverity.warning,
              message: 'URL may be invalid', // lint-allow: hardcoded-string
              elementId: element.id,
              fix: 'Make sure URL starts with http:// or https://', // lint-allow: hardcoded-string
            ),
          );
        }
        break;
      default:
        break;
    }
  }

  static void _validateBinding(
    BindingSchema binding,
    String elementId,
    List<ValidationIssue> issues,
  ) {
    // Check if binding path exists
    final exists = BindingRegistry.bindings.any((b) => b.path == binding.path);
    if (!exists) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.warning,
          message: 'Unknown data binding: ${binding.path}', // lint-allow: hardcoded-string
          elementId: elementId,
          fix: 'Select a valid data source', // lint-allow: hardcoded-string
        ),
      );
    }
  }

  /// Get a summary of validation issues
  static String getSummary(ValidationResult result) {
    if (result.isValid && result.issues.isEmpty) {
      return 'Widget looks good!'; // lint-allow: hardcoded-string
    }

    final errors = result.errors.length;
    final warnings = result.warnings.length;

    final parts = <String>[];
    if (errors > 0) {
      parts.add('$errors ${errors == 1 ? 'issue' : 'issues'} to fix');
    }
    if (warnings > 0) {
      parts.add('$warnings ${warnings == 1 ? 'warning' : 'warnings'}');
    }

    return parts.join(', ');
  }
}
