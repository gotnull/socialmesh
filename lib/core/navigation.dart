// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

/// Central global navigator key used across the app for safe navigation/snackbar
/// operations from asynchronous contexts.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Global key to capture screenshots of the full app UI.
final GlobalKey appRepaintBoundaryKey = GlobalKey();

/// True when the topmost route on [navigator]'s stack was pushed with
/// `RouteSettings(name: name)`.
///
/// Callers use this to skip a push that would stack a second copy of the
/// screen the user is already looking at - a repeat notification tap for
/// the same conversation, hub or inbox. Reads the stack without changing
/// it: `popUntil`'s predicate returns true on its first call, so it stops
/// before popping anything.
bool isTopRouteNamed(NavigatorState navigator, String name) {
  var isTop = false;
  navigator.popUntil((route) {
    isTop = route.settings.name == name;
    return true; // stop iteration immediately, no actual pop
  });
  return isTop;
}

/// Pushes [builder] tagged with [routeName], unless a route carrying that
/// same tag is already on top of [navigator].
///
/// Returns true when it pushed and false when it declined because the user
/// is already looking at that exact screen. Every repeatable external
/// trigger (a notification tap, a deep link, a companion-device intent)
/// should route through this rather than calling `push` directly.
bool pushRouteUnlessOnTop(
  NavigatorState navigator, {
  required String routeName,
  required WidgetBuilder builder,
}) {
  if (isTopRouteNamed(navigator, routeName)) return false;
  navigator.push(
    MaterialPageRoute<void>(
      builder: builder,
      settings: RouteSettings(name: routeName),
    ),
  );
  return true;
}

/// [NavigatorState.pushNamed] with the same already-on-top guard.
///
/// `pushNamed` stamps `RouteSettings.name` with [routeName] itself, so a
/// repeat push is detectable by exactly the same check.
bool pushNamedUnlessOnTop(NavigatorState navigator, String routeName) {
  if (isTopRouteNamed(navigator, routeName)) return false;
  navigator.pushNamed(routeName);
  return true;
}
