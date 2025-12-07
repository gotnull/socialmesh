import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Shows a styled snackbar at the top of the screen with accent color background
void showAppSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 3),
  SnackBarAction? action,
}) {
  final mediaQuery = MediaQuery.of(context);
  // Position snackbar below status bar with proper safe area padding
  final topInset = mediaQuery.padding.top + 56; // safe area + app bar height

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: context.accentColor,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
        top: topInset,
        bottom: mediaQuery.size.height - topInset - 60,
        left: 16,
        right: 16,
      ),
      duration: duration,
      action: action,
    ),
  );
}

/// Shows an error snackbar at the top of the screen
void showErrorSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 4),
}) {
  final mediaQuery = MediaQuery.of(context);
  // Position snackbar below status bar with proper safe area padding
  final topInset = mediaQuery.padding.top + 56; // safe area + app bar height

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
        top: topInset,
        bottom: mediaQuery.size.height - topInset - 60,
        left: 16,
        right: 16,
      ),
      duration: duration,
    ),
  );
}
