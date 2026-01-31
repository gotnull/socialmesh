// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// Get a safe share position for iOS/iPadOS popover
/// On iOS, Share sheet requires a valid non-zero rect for positioning the popover
/// Returns a centered rect that works for popover positioning on iPad
Rect getSafeSharePosition(BuildContext? context, [Rect? origin]) {
  // If a valid origin is provided, use it
  if (origin != null && origin.width > 0 && origin.height > 0) {
    return origin;
  }

  // Try to get position from context's render object
  if (context != null) {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final position = box.localToGlobal(Offset.zero);
      if (position.dx >= 0 && position.dy >= 0) {
        return position & box.size;
      }
    }
  }

  // Default fallback for iOS - center of a reasonable screen area
  if (Platform.isIOS) {
    return const Rect.fromLTWH(100, 200, 200, 100);
  }

  // Android doesn't need sharePositionOrigin
  return Rect.zero;
}

/// Share text with proper iOS/iPad support
/// Automatically handles popover positioning on iPad
Future<void> shareText(
  String text, {
  String? subject,
  BuildContext? context,
  Rect? sharePositionOrigin,
}) async {
  await Share.share(
    text,
    subject: subject,
    sharePositionOrigin: getSafeSharePosition(context, sharePositionOrigin),
  );
}

/// Share files with proper iOS/iPad support
Future<void> shareFiles(
  List<XFile> files, {
  String? subject,
  String? text,
  BuildContext? context,
  Rect? sharePositionOrigin,
}) async {
  await Share.shareXFiles(
    files,
    subject: subject,
    text: text,
    sharePositionOrigin: getSafeSharePosition(context, sharePositionOrigin),
  );
}
