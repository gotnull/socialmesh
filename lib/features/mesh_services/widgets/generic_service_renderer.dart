// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Generic service renderer — renders unknown services from schema.
///
/// Maps [SchemaFieldType] to UI widgets:
///   text      → label
///   number    → numeric display with unit
///   boolean   → toggle indicator
///   choice    → radio button group
///   list      → list view
///   action    → button
///   timestamp → relative time label
///
/// Handles missing fields safely. Never crashes on unknown types.
library;

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../models/service_schema.dart';

/// Renders a [ServiceSchema] dynamically using schema-driven field mapping.
///
/// [data] is a map of field ID (int) → value (dynamic) from the service
/// response payload. Unknown field IDs are ignored; missing fields show
/// a placeholder.
class GenericServiceRenderer extends StatelessWidget {
  /// The schema describing the service structure.
  final ServiceSchema schema;

  /// Field values keyed by field ID.
  final Map<int, dynamic> data;

  /// Callback when an action button is tapped.
  final void Function(SchemaAction action)? onAction;

  const GenericServiceRenderer({
    super.key,
    required this.schema,
    this.data = const {},
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Service title header.
        _buildHeader(context),
        const SizedBox(height: AppTheme.spacing16),

        // Fields.
        ...schema.fields.map((field) => _buildField(context, field)),

        // Actions.
        if (schema.actions.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacing16),
          Wrap(
            spacing: AppTheme.spacing8,
            runSpacing: AppTheme.spacing8,
            children: schema.actions
                .map((action) => _buildAction(context, action))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.extension_outlined, size: 20, color: context.textSecondary),
        const SizedBox(width: AppTheme.spacing8),
        Expanded(
          child: Text(
            schema.title,
            style: context.titleStyle?.copyWith(color: context.textPrimary),
          ),
        ),
        Text(
          schema.serviceType,
          style: context.captionStyle?.copyWith(color: context.textTertiary),
        ),
      ],
    );
  }

  Widget _buildField(BuildContext context, SchemaField field) {
    final value = data[field.id];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: switch (field.type) {
        SchemaFieldType.text => _TextFieldWidget(field: field, value: value),
        SchemaFieldType.number => _NumberFieldWidget(
          field: field,
          value: value,
        ),
        SchemaFieldType.boolean => _BooleanFieldWidget(
          field: field,
          value: value,
        ),
        SchemaFieldType.choice => _ChoiceFieldWidget(
          field: field,
          value: value,
        ),
        SchemaFieldType.list => _ListFieldWidget(field: field, value: value),
        SchemaFieldType.action => _ActionFieldWidget(
          field: field,
          onAction: onAction,
        ),
        SchemaFieldType.timestamp => _TimestampFieldWidget(
          field: field,
          value: value,
        ),
      },
    );
  }

  Widget _buildAction(BuildContext context, SchemaAction action) {
    final isWrite = action.method != SchemaActionMethod.read;
    return FilledButton.tonal(
      onPressed: onAction != null ? () => onAction!(action) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isWrite ? Icons.edit_outlined : Icons.visibility_outlined,
            size: 16,
          ),
          const SizedBox(width: AppTheme.spacing4),
          Text(action.name),
        ],
      ),
    );
  }
}

/// Text field: displays as a label.
class _TextFieldWidget extends StatelessWidget {
  final SchemaField field;
  final dynamic value;

  const _TextFieldWidget({required this.field, this.value});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final displayValue = value?.toString() ?? l10n.schemaFieldNoData;
    return _FieldRow(
      label: field.name,
      child: Text(
        displayValue,
        style: context.bodySecondaryStyle?.copyWith(color: context.textPrimary),
      ),
    );
  }
}

/// Number field: numeric display with optional unit.
class _NumberFieldWidget extends StatelessWidget {
  final SchemaField field;
  final dynamic value;

  const _NumberFieldWidget({required this.field, this.value});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final numValue = value is num ? value : null;
    final displayText = numValue != null
        ? field.unit.isNotEmpty
              ? '$numValue${field.unit}' // lint-allow: hardcoded-string
              : '$numValue'
        : l10n.schemaFieldNoData;
    return _FieldRow(
      label: field.name,
      child: Text(
        displayText,
        style: context.titleStyle?.copyWith(
          color: context.textPrimary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Boolean field: toggle indicator.
class _BooleanFieldWidget extends StatelessWidget {
  final SchemaField field;
  final dynamic value;

  const _BooleanFieldWidget({required this.field, this.value});

  @override
  Widget build(BuildContext context) {
    final boolValue = value == true;
    return _FieldRow(
      label: field.name,
      child: Icon(
        boolValue ? Icons.check_circle : Icons.radio_button_unchecked,
        size: 20,
        color: boolValue ? AccentColors.emerald : context.textTertiary,
      ),
    );
  }
}

/// Choice field: displays selected option.
class _ChoiceFieldWidget extends StatelessWidget {
  final SchemaField field;
  final dynamic value;

  const _ChoiceFieldWidget({required this.field, this.value});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String displayText;
    if (value is int && value >= 0 && value < field.options.length) {
      displayText = field.options[value as int];
    } else if (value is String) {
      displayText = value as String;
    } else {
      displayText = l10n.schemaFieldNoData;
    }

    return _FieldRow(
      label: field.name,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing8,
          vertical: AppTheme.spacing4,
        ),
        decoration: BoxDecoration(
          color: context.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppTheme.spacing6),
        ),
        child: Text(
          displayText,
          style: context.bodySecondaryStyle?.copyWith(
            color: context.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// List field: shows items as a compact list.
class _ListFieldWidget extends StatelessWidget {
  final SchemaField field;
  final dynamic value;

  const _ListFieldWidget({required this.field, this.value});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = value is List ? value as List : const [];
    if (items.isEmpty) {
      return _FieldRow(
        label: field.name,
        child: Text(
          l10n.schemaFieldEmptyList,
          style: context.captionStyle?.copyWith(color: context.textTertiary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: field.name),
        const SizedBox(height: AppTheme.spacing4),
        ...items
            .take(8)
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(
                  left: AppTheme.spacing16,
                  bottom: AppTheme.spacing2,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.textTertiary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Expanded(
                      child: Text(
                        item.toString(),
                        style: context.bodySecondaryStyle?.copyWith(
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        if (items.length > 8)
          Padding(
            padding: const EdgeInsets.only(left: AppTheme.spacing16),
            child: Text(
              l10n.schemaFieldMoreItems(items.length - 8),
              style: context.captionStyle?.copyWith(
                color: context.textTertiary,
              ),
            ),
          ),
      ],
    );
  }
}

/// Action field: renders as a button.
class _ActionFieldWidget extends StatelessWidget {
  final SchemaField field;
  final void Function(SchemaAction action)? onAction;

  const _ActionFieldWidget({required this.field, this.onAction});

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(onPressed: null, child: Text(field.name));
  }
}

/// Timestamp field: relative time label.
class _TimestampFieldWidget extends StatelessWidget {
  final SchemaField field;
  final dynamic value;

  const _TimestampFieldWidget({required this.field, this.value});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String displayText;
    if (value is int && value > 0) {
      final dt = DateTime.fromMillisecondsSinceEpoch(value as int);
      final diff = DateTime.now().difference(dt);
      displayText = _formatRelativeTime(diff, l10n);
    } else {
      displayText = l10n.schemaFieldNoData;
    }

    return _FieldRow(
      label: field.name,
      child: Text(
        displayText,
        style: context.bodySecondaryStyle?.copyWith(
          color: context.textSecondary,
        ),
      ),
    );
  }

  String _formatRelativeTime(Duration diff, dynamic l10n) {
    if (diff.isNegative) return l10n.schemaFieldJustNow;
    if (diff.inMinutes < 1) return l10n.schemaFieldJustNow;
    if (diff.inMinutes < 60) return l10n.schemaFieldMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.schemaFieldHoursAgo(diff.inHours);
    return l10n.schemaFieldDaysAgo(diff.inDays);
  }
}

/// Shared field row layout: label on left, value on right.
class _FieldRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _FieldRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _FieldLabel(label: label),
        Flexible(child: child),
      ],
    );
  }
}

/// Field label text widget.
class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: context.bodySecondaryStyle?.copyWith(color: context.textSecondary),
    );
  }
}
