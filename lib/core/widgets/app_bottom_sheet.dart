import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

/// Action item for bottom sheet action menus
class BottomSheetAction<T> {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String? subtitle;
  final T? value;
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool enabled;

  const BottomSheetAction({
    required this.icon,
    this.iconColor,
    required this.label,
    this.subtitle,
    this.value,
    this.onTap,
    this.isDestructive = false,
    this.enabled = true,
  });
}

/// Standard bottom sheet with drag pill and consistent styling.
/// Use this for all modal bottom sheets to ensure UI consistency.
///
/// Example usage:
/// ```dart
/// AppBottomSheet.show(
///   context: context,
///   child: YourContentWidget(),
/// );
/// ```
class AppBottomSheet extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool showDragPill;

  const AppBottomSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 0, 24, 24),
    this.showDragPill = true,
  });

  /// Shows a standard bottom sheet with drag pill
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.fromLTRB(24, 0, 24, 24),
    bool isScrollControlled = true,
    bool showDragPill = true,
    bool useSafeArea = true,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: isScrollControlled,
      transitionAnimationController: AnimationController(
        vsync: Navigator.of(context),
        duration: const Duration(milliseconds: 350),
        reverseDuration: const Duration(milliseconds: 250),
      ),
      builder: (context) => AppBottomSheet(
        padding: padding,
        showDragPill: showDragPill,
        child: useSafeArea ? SafeArea(top: false, child: child) : child,
      ),
    );
  }

  /// Shows a scrollable bottom sheet with drag handle
  static Future<T?> showScrollable<T>({
    required BuildContext context,
    required Widget Function(ScrollController controller) builder,
    double initialChildSize = 0.6,
    double minChildSize = 0.3,
    double maxChildSize = 0.9,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const _DragPill(),
              Expanded(child: builder(scrollController)),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows a confirmation bottom sheet with title, message, and action buttons
  static Future<bool?> showConfirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) {
    return show<bool>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: context.textSecondary),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.grey.shade700),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(cancelLabel),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: isDestructive
                        ? AppTheme.errorRed
                        : context.accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(confirmLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Shows a simple list picker bottom sheet
  static Future<T?> showPicker<T>({
    required BuildContext context,
    required String title,
    required List<T> items,
    required Widget Function(T item, bool isSelected) itemBuilder,
    T? selectedItem,
  }) {
    return show<T>(
      context: context,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Divider(height: 1, color: context.border),
          ...items.map(
            (item) => InkWell(
              onTap: () => Navigator.pop(context, item),
              child: itemBuilder(item, item == selectedItem),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows an action menu bottom sheet with list tiles
  static Future<T?> showActions<T>({
    required BuildContext context,
    required List<BottomSheetAction<T>> actions,
    Widget? header,
  }) {
    return show<T>(
      context: context,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (header != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: header,
            ),
          ],
          ...actions.map(
            (action) => ListTile(
              leading: Icon(
                action.icon,
                color: action.isDestructive
                    ? AppTheme.errorRed
                    : (action.iconColor ?? Colors.white),
              ),
              title: Text(
                action.label,
                style: TextStyle(
                  color: action.isDestructive
                      ? AppTheme.errorRed
                      : Colors.white,
                ),
              ),
              subtitle: action.subtitle != null
                  ? Text(
                      action.subtitle!,
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 12,
                      ),
                    )
                  : null,
              enabled: action.enabled,
              onTap: action.enabled
                  ? () {
                      Navigator.pop(context, action.value);
                      action.onTap?.call();
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDragPill) const _DragPill(),
            Flexible(
              child: Padding(padding: padding, child: child),
            ),
          ],
        ),
      ),
    );
  }
}

/// Standard drag pill indicator for bottom sheets
class _DragPill extends StatelessWidget {
  const _DragPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 12, bottom: 20),
      decoration: BoxDecoration(
        color: context.textTertiary.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Reusable drag pill that can be used standalone
class DragPill extends StatelessWidget {
  final EdgeInsets margin;

  const DragPill({
    super.key,
    this.margin = const EdgeInsets.only(top: 12, bottom: 20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      margin: margin,
      decoration: BoxDecoration(
        color: context.textTertiary.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Standard bottom sheet header with icon and title
class BottomSheetHeader extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;

  const BottomSheetHeader({
    super.key,
    this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    // Simple header without icon
    if (icon == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 14, color: context.textSecondary),
            ),
          ],
        ],
      );
    }

    // Header with icon
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: (iconColor ?? context.accentColor).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor ?? context.accentColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(fontSize: 13, color: context.textTertiary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Standard text field styled for bottom sheets (matches channel wizard)
class BottomSheetTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int? maxLength;
  final int maxLines;
  final bool autofocus;
  final String? errorText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool monospace;

  const BottomSheetTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.maxLength,
    this.maxLines = 1,
    this.autofocus = false,
    this.errorText,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;

    return TextField(
      controller: controller,
      autofocus: autofocus,
      maxLength: maxLength,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontFamily: monospace ? 'monospace' : 'Inter',
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.textSecondary),
        hintText: hint,
        hintStyle: TextStyle(
          color: context.textSecondary.withAlpha(128),
          fontFamily: monospace ? 'monospace' : null,
        ),
        errorText: errorText,
        filled: true,
        fillColor: context.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: hasError ? AppTheme.errorRed : context.accentColor,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.errorRed, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.errorRed, width: 2),
        ),
        counterStyle: TextStyle(color: context.textSecondary),
      ),
    );
  }
}

/// Standard button row for bottom sheets
class BottomSheetButtons extends StatelessWidget {
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final bool isDestructive;
  final bool isConfirmEnabled;

  const BottomSheetButtons({
    super.key,
    this.cancelLabel = 'Cancel',
    required this.confirmLabel,
    this.onCancel,
    required this.onConfirm,
    this.isDestructive = false,
    this.isConfirmEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onCancel ?? () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.grey.shade700),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(cancelLabel),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: isConfirmEnabled ? onConfirm : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: isDestructive
                  ? AppTheme.errorRed
                  : context.accentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(confirmLabel),
          ),
        ),
      ],
    );
  }
}
