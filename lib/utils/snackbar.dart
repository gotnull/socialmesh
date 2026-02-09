// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'dart:ui';

import '../core/widgets/loading_indicator.dart';
import '../core/navigation.dart';

/// Snackbar types with associated styling
enum SnackBarType {
  success(
    icon: Icons.check_circle_rounded,
    backgroundColor: Color(0xFF1B5E20),
    iconColor: Color(0xFF4CAF50),
  ),
  error(
    icon: Icons.error_rounded,
    backgroundColor: Color(0xFF7F1D1D),
    iconColor: Color(0xFFEF5350),
  ),
  warning(
    icon: Icons.warning_rounded,
    backgroundColor: Color(0xFF7C4700),
    iconColor: Color(0xFFFFB74D),
  ),
  info(
    icon: Icons.info_rounded,
    backgroundColor: Color(0xFF0D47A1),
    iconColor: Color(0xFF64B5F6),
  );

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  const SnackBarType({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });
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
    margin: const EdgeInsets.all(16),
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
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: type.iconColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(type.icon, color: type.iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => messenger.hideCurrentSnackBar(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 18,
                      ),
                    ),
                  ),
                ],
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
    margin: const EdgeInsets.all(16),
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
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: type.iconColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(type.icon, color: type.iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
    margin: const EdgeInsets.all(16),
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
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: SnackBarType.info.iconColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(child: LoadingIndicator(size: 24)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
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
    actionLabel: 'Sign In',
    onAction: () => Navigator.pushNamed(context, '/account'),
    type: SnackBarType.info,
  );
}
