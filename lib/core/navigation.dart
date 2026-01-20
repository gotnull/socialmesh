import 'package:flutter/material.dart';

/// Central global navigator key used across the app for safe navigation/snackbar
/// operations from asynchronous contexts.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
