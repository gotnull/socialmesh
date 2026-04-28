// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
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

/// Write [text] to a temp file with the given [filename] and share it as a
/// proper file (gives the share sheet a real filename + MIME, so "Save to
/// Files" / mail attachments work correctly on iOS).
///
/// Use this for any export larger than a snippet — CSV, GPX, JSON, etc.
/// Plain `shareText` is fine for short copy-to-clipboard snippets but on
/// iOS produces an untitled `.txt` when saved.
Future<void> shareTextAsFile(
  String text, {
  required String filename,
  String? mimeType,
  String? subject,
  BuildContext? context,
  Rect? sharePositionOrigin,
}) async {
  // Resolve the share position before any await so we don't read the
  // caller's BuildContext after an async gap.
  final sharePosition = getSafeSharePosition(context, sharePositionOrigin);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(text);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: mimeType)],
    subject: subject,
    sharePositionOrigin: sharePosition,
  );
}
