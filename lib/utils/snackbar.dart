// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

import '../core/l10n/l10n_extension.dart';
import '../core/widgets/loading_indicator.dart';
import '../core/navigation.dart';
import 'package:socialmesh/core/theme.dart';

// Picks the Row cross-axis alignment for a snackbar based on whether
// the message actually wraps. Single-line messages look better
// vertically centered; multi-line messages need top-alignment so the
// icon sits next to the first line instead of the visual middle.
//
// Approximates the text-cell width by subtracting the icon column
// (36 + 12 spacing) and trailing column (8 + estimated trailingWidth)
// from the constraint passed by LayoutBuilder.
CrossAxisAlignment _snackBarRowAlignment({
  required BoxConstraints constraints,
  required String message,
  required TextStyle? style,
  required double trailingWidth,
}) {
  const iconColumn = 36.0 + AppTheme.spacing12;
  const trailingGap = AppTheme.spacing8;
  final textMaxWidth =
      (constraints.maxWidth - iconColumn - trailingGap - trailingWidth).clamp(
        0,
        double.infinity,
      );
  final painter = TextPainter(
    text: TextSpan(text: message, style: style),
    textDirection: TextDirection.ltr,
    maxLines: null,
  )..layout(maxWidth: textMaxWidth.toDouble());
  final isMultiLine = painter.computeLineMetrics().length > 1;
  return isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center;
}

/// Snackbar types with associated styling.
///
/// Only the icon tint is per-type; the container background is driven by
/// `Theme.of(context).cardColor` in the helpers below. All colours come
/// from the theme — no hardcoded `Color(0x...)` literals.
enum SnackBarType {
  success(icon: Icons.check_circle_rounded, iconColor: ChartColors.green),
  error(icon: Icons.error_rounded, iconColor: AppTheme.errorRed),
  warning(icon: Icons.warning_rounded, iconColor: AppTheme.warningYellow),
  info(icon: Icons.info_rounded, iconColor: SemanticColors.info),
  bug(icon: Icons.bug_report, iconColor: AccentColors.magenta);

  final IconData icon;
  final Color iconColor;

  const SnackBarType({required this.icon, required this.iconColor});
}

/// Shows a success snackbar with check icon
void showSuccessSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 3),
}) {
  _showStyledSnackBar(
    context,
    message,
    type: SnackBarType.success,
    duration: duration,
  );
}

/// Shows an error snackbar with error icon
void showErrorSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 4),
}) {
  _showStyledSnackBar(
    context,
    message,
    type: SnackBarType.error,
    duration: duration,
  );
}

/// Shows a warning snackbar with warning icon
void showWarningSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 4),
}) {
  _showStyledSnackBar(
    context,
    message,
    type: SnackBarType.warning,
    duration: duration,
  );
}

/// Shows an info snackbar with info icon
void showInfoSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 3),
}) {
  _showStyledSnackBar(
    context,
    message,
    type: SnackBarType.info,
    duration: duration,
  );
}

/// Shows a bug snackbar with bug-report icon (founder responses, etc).
void showBugSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 3),
}) {
  _showStyledSnackBar(
    context,
    message,
    type: SnackBarType.bug,
    duration: duration,
  );
}

/// If [error] is a [StateError] thrown by `ProtocolService._assertOperational`
/// (i.e. a TX path was blocked because the Meshtastic readiness state is
/// not yet `ready`), surface the friendly localised snackbar and return
/// `true`. Otherwise return `false` so the caller can fall through to its
/// existing error-display path.
///
/// Wired at UI call sites only (Step 6c) so the protocol return type
/// stays unchanged. The detection key is the `'protocol not ready'`
/// substring written by `_assertOperational`'s `StateError.message` —
/// see `lib/services/protocol/protocol_service.dart`.
bool maybeShowTxBlockedSnackBar(BuildContext context, Object error) {
  if (error is StateError && error.message.contains('protocol not ready')) {
    showInfoSnackBar(context, context.l10n.txBlockedNotReady);
    return true;
  }
  return false;
}

/// Shows a loading snackbar with spinner
void showLoadingSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 3),
}) {
  _showLoadingSnackBar(context, message, duration: duration);
}

/// Legacy function for backwards compatibility - use showSuccessSnackBar instead
void showAppSnackBar(
  BuildContext context,
  String message, {
  String title = 'Success',
  Duration duration = const Duration(seconds: 3),
}) {
  showSuccessSnackBar(context, message, duration: duration);
}

/// Global variants: use the app's global navigator key to show snackbars from
/// asynchronous contexts where a BuildContext might not be available.
void showGlobalSuccessSnackBar(
  String message, {
  Duration duration = const Duration(seconds: 3),
}) {
  final ctx = navigatorKey.currentContext;
  if (ctx == null) return;
  showSuccessSnackBar(ctx, message, duration: duration);
}

void showGlobalErrorSnackBar(
  String message, {
  Duration duration = const Duration(seconds: 4),
}) {
  final ctx = navigatorKey.currentContext;
  if (ctx == null) return;
  showErrorSnackBar(ctx, message, duration: duration);
}

void showGlobalInfoSnackBar(
  String message, {
  Duration duration = const Duration(seconds: 3),
}) {
  final ctx = navigatorKey.currentContext;
  if (ctx == null) return;
  showInfoSnackBar(ctx, message, duration: duration);
}

/// Global variant of [showActionSnackBar] that uses the app's global navigator
/// key. Safe to call from disposed states or async contexts where a
/// [BuildContext] may no longer be valid.
void showGlobalActionSnackBar(
  String message, {
  required String actionLabel,
  required VoidCallback onAction,
  SnackBarType type = SnackBarType.info,
  Duration duration = const Duration(seconds: 5),
}) {
  final ctx = navigatorKey.currentContext;
  if (ctx == null) return;
  showActionSnackBar(
    ctx,
    message,
    actionLabel: actionLabel,
    onAction: onAction,
    type: type,
    duration: duration,
  );
}

void _showStyledSnackBar(
  BuildContext context,
  String message, {
  required SnackBarType type,
  required Duration duration,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  final snackBar = SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    elevation: 0,
    // Ensure the SnackBar overlay matches our top-only rounding to avoid bottom corner artifacts
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(12),
      ),
    ),
    duration: duration,
    margin: const EdgeInsets.all(AppTheme.spacing16),
    padding: EdgeInsets.zero,
    content: ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withValues(alpha: 0.35),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(
              color: type.iconColor.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textStyle = Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      );
                  // Close button: 4px padding + 18px icon + 4px padding = 26px
                  final alignment = _snackBarRowAlignment(
                    constraints: constraints,
                    message: message,
                    style: textStyle,
                    trailingWidth: 26,
                  );
                  return Row(
                    crossAxisAlignment: alignment,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: type.iconColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius10,
                          ),
                        ),
                        child: Icon(type.icon, color: type.iconColor, size: 20),
                      ),
                      const SizedBox(width: AppTheme.spacing12),
                      Expanded(child: Text(message, style: textStyle)),
                      const SizedBox(width: AppTheme.spacing8),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          messenger.hideCurrentSnackBar();
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.all(AppTheme.spacing4),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(snackBar);
}

/// Show a SnackBar with an action button. Uses same styling options as other
/// helpers but allows a user-provided action label and callback.
void showActionSnackBar(
  BuildContext context,
  String message, {
  required String actionLabel,
  required VoidCallback onAction,
  SnackBarType type = SnackBarType.info,
  Duration duration = const Duration(seconds: 5),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  final snackBar = SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    duration: duration,
    margin: const EdgeInsets.all(AppTheme.spacing16),
    padding: EdgeInsets.zero,
    content: ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withValues(alpha: 0.35),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(
              color: type.iconColor.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textStyle = Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      );
                  // TextButton width depends on the action label;
                  // rough estimate of 72px covers common 4-8 char
                  // labels like "View" / "Restore".
                  final alignment = _snackBarRowAlignment(
                    constraints: constraints,
                    message: message,
                    style: textStyle,
                    trailingWidth: 72,
                  );
                  return Row(
                    crossAxisAlignment: alignment,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: type.iconColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius10,
                          ),
                        ),
                        child: Icon(type.icon, color: type.iconColor, size: 20),
                      ),
                      const SizedBox(width: AppTheme.spacing12),
                      Expanded(child: Text(message, style: textStyle)),
                      const SizedBox(width: AppTheme.spacing8),
                      TextButton(
                        onPressed: () {
                          messenger.hideCurrentSnackBar();
                          onAction();
                        },
                        child: Text(
                          actionLabel,
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(color: Colors.white),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(snackBar);
}

void _showLoadingSnackBar(
  BuildContext context,
  String message, {
  required Duration duration,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  final snackBar = SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    duration: duration,
    margin: const EdgeInsets.all(AppTheme.spacing16),
    padding: EdgeInsets.zero,
    content: ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withValues(alpha: 0.35),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(
              color: SnackBarType.info.iconColor.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textStyle = Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      );
                  // Loading snackbar has no trailing widget.
                  final alignment = _snackBarRowAlignment(
                    constraints: constraints,
                    message: message,
                    style: textStyle,
                    trailingWidth: 0,
                  );
                  return Row(
                    crossAxisAlignment: alignment,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: SnackBarType.info.iconColor.withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius10,
                          ),
                        ),
                        child: Center(
                          child: LoadingIndicator(
                            size: 24,
                            color: SnackBarType.info.iconColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacing12),
                      Expanded(child: Text(message, style: textStyle)),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(snackBar);
}

/// Shows a standardized auth-required snackbar with Sign In action.
///
/// Use this whenever an action requires authentication. Shows an info snackbar
/// with a "Sign In" button that navigates to the account screen.
///
/// Usage:
/// ```dart
/// void onTap() {
///   if (user == null) {
///     showSignInRequiredSnackBar(context, 'Sign in to follow users');
///     return;
///   }
///   // ... proceed with action
/// }
/// ```
void showSignInRequiredSnackBar(BuildContext context, String message) {
  showActionSnackBar(
    context,
    message,
    actionLabel: context.l10n.commonSignIn,
    onAction: () => Navigator.pushNamed(context, '/account'),
    type: SnackBarType.info,
  );
}
