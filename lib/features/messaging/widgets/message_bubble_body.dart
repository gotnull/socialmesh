// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/widgets/linkified_text.dart';

/// Body of a Meshtastic chat bubble. Renders `text` through [LinkifiedText]
/// when there's something to show, and falls back to a localized
/// "(unable to display)" line when the persisted text is empty or
/// whitespace-only.
///
/// Empty rows reach the chat thread when an inbound packet's payload
/// sanitises to a blank body (e.g. control-char-only bytes). The receive
/// paths now drop such packets, but historical rows may still be in
/// `messages.db`; this widget makes them readable instead of rendering as
/// a zero-height body under the timestamp + lock icon.
class MessageBubbleBody extends StatelessWidget {
  const MessageBubbleBody({
    super.key,
    required this.text,
    required this.bodyStyle,
    required this.fallbackStyle,
    this.linkStyle,
  });

  /// The persisted message body. Trimmed at render time to detect
  /// "blank" content.
  final String text;

  /// Style applied to the non-empty body (via [LinkifiedText]).
  final TextStyle bodyStyle;

  /// Style applied to the localized fallback string when `text` is
  /// empty or whitespace-only.
  final TextStyle fallbackStyle;

  /// Optional override for hyperlink styling inside [LinkifiedText].
  final TextStyle? linkStyle;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) {
      return Text(
        context.l10n.messagingMessageUnableToDisplay,
        style: fallbackStyle,
      );
    }
    return LinkifiedText(text: text, style: bodyStyle, linkStyle: linkStyle);
  }
}
