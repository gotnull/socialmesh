import 'package:flutter/material.dart';

/// Central global navigator key used across the app for safe navigation/snackbar
/// operations from asynchronous contexts.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Global key to capture screenshots of the full app UI.
final GlobalKey appRepaintBoundaryKey = GlobalKey();
