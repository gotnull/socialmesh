import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';

/// Default margin for snackbars - gives space for the bubble icon
const _snackBarMargin = EdgeInsets.fromLTRB(24, 0, 24, 16);

/// Shows a success snackbar at the bottom of the screen
void showAppSnackBar(
  BuildContext context,
  String message, {
  String title = 'Success',
  Duration duration = const Duration(seconds: 3),
}) {
  final snackBar = SnackBar(
    elevation: 0,
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    margin: _snackBarMargin,
    duration: duration,
    content: AwesomeSnackbarContent(
      title: title,
      message: message,
      contentType: ContentType.success,
    ),
  );

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(snackBar);
}

/// Shows an error snackbar at the bottom of the screen
void showErrorSnackBar(
  BuildContext context,
  String message, {
  String title = 'Error',
  Duration duration = const Duration(seconds: 4),
}) {
  final snackBar = SnackBar(
    elevation: 0,
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    margin: _snackBarMargin,
    duration: duration,
    content: AwesomeSnackbarContent(
      title: title,
      message: message,
      contentType: ContentType.failure,
    ),
  );

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(snackBar);
}

/// Shows a warning snackbar at the bottom of the screen
void showWarningSnackBar(
  BuildContext context,
  String message, {
  String title = 'Warning',
  Duration duration = const Duration(seconds: 4),
}) {
  final snackBar = SnackBar(
    elevation: 0,
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    margin: _snackBarMargin,
    duration: duration,
    content: AwesomeSnackbarContent(
      title: title,
      message: message,
      contentType: ContentType.warning,
    ),
  );

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(snackBar);
}

/// Shows a help/info snackbar at the bottom of the screen
void showInfoSnackBar(
  BuildContext context,
  String message, {
  String title = 'Info',
  Duration duration = const Duration(seconds: 3),
}) {
  final snackBar = SnackBar(
    elevation: 0,
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    margin: _snackBarMargin,
    duration: duration,
    content: AwesomeSnackbarContent(
      title: title,
      message: message,
      contentType: ContentType.help,
    ),
  );

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(snackBar);
}
