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
  final messenger = ScaffoldMessenger.of(context);

  final snackBar = SnackBar(
    behavior: SnackBarBehavior.fixed,
    backgroundColor: backgroundColor,
    duration: duration,
    content: Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => messenger.hideCurrentSnackBar(),
          child: const Icon(Icons.close, color: Colors.white, size: 20),
        ),
      ],
    ),
  );

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(snackBar);
}
