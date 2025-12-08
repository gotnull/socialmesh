import 'package:flutter/material.dart';

/// Shows a success snackbar with accent color background
void showAppSnackBar(
  BuildContext context,
  String message, {
  String title = 'Success',
  Duration duration = const Duration(seconds: 3),
}) {
  _showSnackBar(
    context,
    message,
    backgroundColor: Theme.of(context).colorScheme.primary,
    duration: duration,
  );
}

/// Shows an error snackbar with red background
void showErrorSnackBar(
  BuildContext context,
  String message, {
  String title = 'Error',
  Duration duration = const Duration(seconds: 4),
}) {
  _showSnackBar(
    context,
    message,
    backgroundColor: Colors.red.shade700,
    duration: duration,
  );
}

/// Shows a warning snackbar with orange background
void showWarningSnackBar(
  BuildContext context,
  String message, {
  String title = 'Warning',
  Duration duration = const Duration(seconds: 4),
}) {
  _showSnackBar(
    context,
    message,
    backgroundColor: Colors.orange.shade700,
    duration: duration,
  );
}

/// Shows an info snackbar with accent color background
void showInfoSnackBar(
  BuildContext context,
  String message, {
  String title = 'Info',
  Duration duration = const Duration(seconds: 3),
}) {
  _showSnackBar(
    context,
    message,
    backgroundColor: Theme.of(context).colorScheme.primary,
    duration: duration,
  );
}

void _showSnackBar(
  BuildContext context,
  String message, {
  required Color backgroundColor,
  required Duration duration,
}) {
  final snackBar = SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: backgroundColor,
    duration: duration,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.all(16),
    content: Text(
      message,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
    ),
    action: SnackBarAction(
      label: '✕',
      textColor: Colors.white,
      onPressed: () {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      },
    ),
  );

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(snackBar);
}
