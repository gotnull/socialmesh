// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import 'auto_scroll_text.dart';

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
    this.padding = const EdgeInsets.fromLTRB(AppTheme.spacing24, 0, 24, 24),
    this.showDragPill = true,
  });

  /// Shows a standard bottom sheet with drag pill
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.fromLTRB(
      AppTheme.spacing24,
      0,
      24,
      24,
    ),
    bool isScrollControlled = true,
    bool showDragPill = true,
    bool useSafeArea = true,
    bool isDismissible = true,
    double? maxHeightFraction,
  }) {
    HapticFeedback.lightImpact();
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    Widget content = useSafeArea ? SafeArea(top: false, child: child) : child;

    // Constrain height if maxHeightFraction is specified
    if (maxHeightFraction != null) {
      content = Builder(
        builder: (context) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * maxHeightFraction,
          ),
          child: content,
        ),
      );
    }

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      transitionAnimationController: AnimationController(
        vsync: Navigator.of(context),
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 350),
        reverseDuration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 250),
      ),
      builder: (context) => _BounceInWrapper(
        enabled: !disableAnimations,
        child: AppBottomSheet(
          padding: padding,
          showDragPill: showDragPill,
          child: content,
        ),
      ),
    );
  }

  // Raw modal entry point for sheets that supply their own visual shell
  // (transparent backgrounds, custom container widgets, floating panels).
  // Skips the canonical drag-pill + Container shell but keeps modal route
  // management, haptic, disableAnimations handling, and the bounce arrival.
  // Prefer [show] / [showScrollable] / [showActions] / [showConfirm] /
  // [showPicker] when the canonical shell fits.
  static Future<T?> showRaw<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isDismissible = true,
    bool isScrollControlled = true,
  }) {
    HapticFeedback.lightImpact();
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      transitionAnimationController: AnimationController(
        vsync: Navigator.of(context),
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 350),
        reverseDuration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 250),
      ),
      builder: (ctx) =>
          _BounceInWrapper(enabled: !disableAnimations, child: builder(ctx)),
    );
  }

  /// Shows a scrollable bottom sheet with drag handle.
  ///
  /// Optionally provide [title] to pin a header above the scrollable content,
  /// and [footer] to pin a widget (typically a button) below it. Both stay
  /// fixed while the body scrolls, matching the pattern used in the create
  /// signal screen.
  static Future<T?> showScrollable<T>({
    required BuildContext context,
    required Widget Function(ScrollController controller) builder,
    double initialChildSize = 0.6,
    double minChildSize = 0.3,
    double maxChildSize = 0.9,
    String? title,
    Widget? footer,
  }) {
    HapticFeedback.lightImpact();
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      transitionAnimationController: AnimationController(
        vsync: Navigator.of(context),
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 350),
        reverseDuration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 250),
      ),
      builder: (context) => _BounceInWrapper(
        enabled: !disableAnimations,
        child: DraggableScrollableSheet(
          initialChildSize: initialChildSize,
          minChildSize: minChildSize,
          maxChildSize: maxChildSize,
          expand: false,
          // The full-width pin is mandatory: during the dismiss
          // animation `showModalBottomSheet`'s SlideTransition can
          // briefly invalidate the inherited BoxConstraints. A
          // Container with no explicit width then collapses to its
          // children's intrinsic min-width, which renders the sheet
          // as a thin vertical bar mid-dismiss before disappearing.
          // Pinning to `double.infinity` keeps the sheet at screen
          // width through the entire reverse animation.
          builder: (context, scrollController) => Container(
            width: double.infinity,
            decoration: BoxDecoration(
              // Sheet shell uses `context.background` (darker) so the
              // entire sheet — drag pill, body, button area — is one
              // consistent dark surface. Nested cards (`context.card`,
              // lighter) and `InfoTable`-style read-only blocks (`context
              // .background` + border) both delineate naturally on top.
              color: context.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const _DragPill(),
                  // Pinned title row
                  if (title != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spacing24,
                        0,
                        AppTheme.spacing24,
                        AppTheme.spacing12,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  Expanded(child: builder(scrollController)),
                  // Pinned footer
                  if (footer != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spacing24,
                        AppTheme.spacing8,
                        AppTheme.spacing24,
                        AppTheme.spacing16,
                      ),
                      child: footer,
                    ),
                ],
              ),
            ),
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
      // Builder gives the action buttons a context that lives inside the
      // sheet's route subtree. Capturing the caller's `context` was unsafe:
      // when the underlying screen unmounted (system back, programmatic
      // nav) while the sheet was still up, the tap fired
      // `Navigator.of(deadContext)` and `StatefulElement.state!` threw.
      // Crashlytics ec04559d.
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: sheetContext.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                color: sheetContext.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacing24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetContext, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: SemanticColors.divider),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                      ),
                    ),
                    child: Text(cancelLabel),
                  ),
                ),
                SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: isDestructive
                          ? AppTheme.errorRed
                          : sheetContext.accentColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                      ),
                    ),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(AppTheme.spacing0, 0, 0, 16),
      // Sheet-local context (see showConfirm above for the rationale).
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.spacing24, 0, 24, 16),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: sheetContext.textPrimary,
                ),
              ),
            ),
            Divider(height: 1, color: sheetContext.border),
            ...items.map(
              (item) => InkWell(
                onTap: () => Navigator.pop(sheetContext, item),
                child: itemBuilder(item, item == selectedItem),
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(AppTheme.spacing0, 0, 0, 8),
      // Use Builder to obtain the bottom sheet's own context for
      // Navigator.pop. The caller's context may be stale if the
      // parent widget was disposed while the sheet was showing.
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (header != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacing16,
                  0,
                  16,
                  16,
                ),
                child: header,
              ),
            ],
            ...actions.map(
              (action) => ListTile(
                leading: Icon(
                  action.icon,
                  color: action.isDestructive
                      ? AppTheme.errorRed
                      : (action.iconColor ?? SemanticColors.onAccent),
                ),
                title: Text(
                  action.label,
                  style: TextStyle(
                    color: action.isDestructive
                        ? AppTheme.errorRed
                        : SemanticColors.onAccent,
                  ),
                ),
                subtitle: action.subtitle != null
                    ? Text(
                        action.subtitle!,
                        style: TextStyle(
                          color: sheetContext.textTertiary,
                          fontSize: 12,
                        ),
                      )
                    : null,
                enabled: action.enabled,
                onTap: action.enabled
                    ? () {
                        Navigator.pop(sheetContext, action.value);
                        action.onTap?.call();
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Pin width: ScaleTransition (from _BounceInWrapper) passes loose
      // constraints. Without width: infinity the Container collapses to
      // the children's intrinsic min-width, rendering the sheet as a
      // narrow card centered in the screen instead of edge-to-edge.
      // Same rationale as `showScrollable`'s `Container(width: double
      // .infinity, ...)` pin.
      width: double.infinity,
      decoration: BoxDecoration(
        // Match `showScrollable` shell color: consistent `context
        // .background` across the entire sheet so the drag-pill area,
        // body, and bottom padding share one dark surface.
        color: context.background,
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

// Scale-pop wrapper layered on top of Flutter's slide. Flutter hardcodes
// the modal bottom sheet slide curve (decelerate), so the bounce arrival
// is added here as a one-shot scale tween anchored to the bottom edge.
// Subtle bounce-in arrival for bottom sheets. When `enabled` is false
// (reduced-motion accessibility, widget tests, etc.) the wrapper is a
// pass-through: no AnimationController is constructed and no Ticker is
// registered with the SchedulerBinding. The earlier implementation
// always created the controller eagerly and just skipped `.forward()`
// when disabled, which left a live (muted) Ticker attached to the
// sheet's element subtree. That broke widget tests of consumers that
// open a sheet: pump-driven tests hung indefinitely waiting for a
// frame that never arrived.
class _BounceInWrapper extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const _BounceInWrapper({required this.child, required this.enabled});

  @override
  State<_BounceInWrapper> createState() => _BounceInWrapperState();
}

class _BounceInWrapperState extends State<_BounceInWrapper>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _scale;

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) return;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _controller = controller;
    _scale = Tween<double>(
      begin: 0.94,
      end: 1.0,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutBack));
    controller.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = _scale;
    if (!widget.enabled || scale == null) return widget.child;
    return ScaleTransition(
      scale: scale,
      alignment: Alignment.bottomCenter,
      child: widget.child,
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
        borderRadius: BorderRadius.circular(AppTheme.radius2),
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
        borderRadius: BorderRadius.circular(AppTheme.radius2),
      ),
    );
  }
}

/// Standard bottom sheet header with icon and title
/// Supports marquee scrolling for long titles
class BottomSheetHeader extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final bool enableMarquee;

  const BottomSheetHeader({
    super.key,
    this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.enableMarquee = true,
  });

  @override
  Widget build(BuildContext context) {
    // Simple header without icon
    if (icon == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (enableMarquee)
            AutoScrollText(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            )
          else
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          if (subtitle != null) ...[
            const SizedBox(height: AppTheme.spacing8),
            Text(
              subtitle!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.textSecondary),
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
            borderRadius: BorderRadius.circular(AppTheme.radius12),
          ),
          child: Icon(icon, color: iconColor ?? context.accentColor, size: 24),
        ),
        const SizedBox(width: AppTheme.spacing16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (enableMarquee)
                AutoScrollText(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                )
              else
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              if (subtitle != null) ...[
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  subtitle!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.textTertiary),
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
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(
        color: context.textPrimary,
        fontSize: 16,
        fontFamily: AppTheme.fontFamily,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: context.textSecondary,
          fontFamily: AppTheme.fontFamily,
        ),
        hintText: hint,
        hintStyle: TextStyle(
          color: context.textSecondary.withAlpha(128),
          fontFamily: AppTheme.fontFamily,
        ),
        errorText: errorText,
        filled: true,
        fillColor: context.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          borderSide: BorderSide(
            color: hasError ? AppTheme.errorRed : context.accentColor,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          borderSide: const BorderSide(color: AppTheme.errorRed, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          borderSide: const BorderSide(color: AppTheme.errorRed, width: 2),
        ),
        counterStyle: TextStyle(
          color: context.textSecondary,
          fontFamily: AppTheme.fontFamily,
        ),
        counterText: '',
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
              side: BorderSide(color: SemanticColors.divider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
              ),
            ),
            child: Text(cancelLabel),
          ),
        ),
        SizedBox(width: AppTheme.spacing12),
        Expanded(
          child: FilledButton(
            onPressed: isConfirmEnabled ? onConfirm : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: isDestructive
                  ? AppTheme.errorRed
                  : context.accentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
              ),
            ),
            child: Text(confirmLabel),
          ),
        ),
      ],
    );
  }
}
