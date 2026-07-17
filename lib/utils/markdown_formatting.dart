// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Selection-level markdown formatting for the message composer.
//
// Ported from the reference iOS implementation
// (meshtastic-ios/Meshtastic/Helpers/MarkdownFormatting.swift) so both apps
// produce identical wire text for the same gestures. The delimiter set is
// canonical and must not drift: bold `**`, italic single `*`, strikethrough
// `~~`, code backtick, link `[text](url)`.
//
// All offsets are UTF-16 code units - the same space `TextSelection` uses -
// and every public entry point clamps its inputs to character boundaries so
// a selection edge landing inside a surrogate pair can never split an emoji.

/// Inline markdown styles supported by the formatting toolbar.
enum MarkdownStyle {
  bold,
  italic,
  strikethrough,
  code,
  link;

  String get openingDelimiter => switch (this) {
    bold => '**',
    italic => '*',
    strikethrough => '~~',
    code => '`',
    link => '[',
  };

  String get closingDelimiter => switch (this) {
    link => ']',
    _ => openingDelimiter,
  };
}

/// Result of a formatting mutation: the new text plus the selection (in
/// UTF-16 code units) the composer should apply with it.
typedef FormattingResult = ({
  String text,
  int selectionStart,
  int selectionEnd,
});

const _delimiterUnits = <int>[0x2A, 0x7E, 0x60]; // * ~ `

final _markdownLinkPattern = RegExp(r'^\[([^\]]+)\]\(([^)]+)\)$');

bool _isDelimiterUnitAt(String text, int index) =>
    _delimiterUnits.contains(text.codeUnitAt(index));

bool _isWhitespaceAt(String text, int index) {
  final unit = text.codeUnitAt(index);
  // Surrogate halves are never whitespace; skip them before the trim probe.
  if (unit >= 0xD800 && unit <= 0xDFFF) return false;
  return String.fromCharCode(unit).trim().isEmpty;
}

/// Clamps [offset] into [0, text.length] and snaps it off a low surrogate so
/// mutations never split an emoji in half.
int clampToCharacterBoundary(String text, int offset) {
  var clamped = offset.clamp(0, text.length);
  if (clamped > 0 && clamped < text.length) {
    final unit = text.codeUnitAt(clamped);
    final prev = text.codeUnitAt(clamped - 1);
    final isLowSurrogate = unit >= 0xDC00 && unit <= 0xDFFF;
    final prevIsHighSurrogate = prev >= 0xD800 && prev <= 0xDBFF;
    if (isLowSurrogate && prevIsHighSurrogate) clamped -= 1;
  }
  return clamped;
}

(int, int) _normalizeRange(String text, int start, int end) {
  final s = clampToCharacterBoundary(text, start);
  final e = clampToCharacterBoundary(text, end);
  return s <= e ? (s, e) : (e, s);
}

/// Wraps the selection with [style]'s delimiters, or removes them when the
/// selection is already exactly wrapped (toggle-off). Expands the selection
/// over adjacent delimiter characters and cleans up orphaned delimiters so
/// partial selections through existing formatting cannot leave stray
/// markers.
FormattingResult wrapSelection(
  String text,
  int start,
  int end,
  MarkdownStyle style,
) {
  final (s, e) = _normalizeRange(text, start, end);
  final opening = style.openingDelimiter;
  final closing = style.closingDelimiter;

  final hasOpeningBefore =
      s >= opening.length && text.substring(s - opening.length, s) == opening;
  final hasClosingAfter =
      e + closing.length <= text.length &&
      text.substring(e, e + closing.length) == closing;

  if (hasOpeningBefore && hasClosingAfter) {
    // Toggle off - remove the delimiters, keep the content selected.
    final newText =
        text.substring(0, s - opening.length) +
        text.substring(s, e) +
        text.substring(e + closing.length);
    final resultStart = s - opening.length;
    return (
      text: newText,
      selectionStart: resultStart,
      selectionEnd: resultStart + (e - s),
    );
  }

  final (expandedStart, expandedEnd) = _expandToDelimiterBoundaries(text, s, e);
  final selectedText = text.substring(expandedStart, expandedEnd);
  final cleanedText = _stripMarkdownDelimiters(selectedText);

  // Trim whitespace so delimiters hug content.
  var firstNonWs = 0;
  while (firstNonWs < cleanedText.length &&
      _isWhitespaceAt(cleanedText, firstNonWs)) {
    firstNonWs++;
  }
  if (firstNonWs == cleanedText.length) {
    return insertDelimiters(text, expandedStart, style);
  }
  var lastNonWs = cleanedText.length - 1;
  while (lastNonWs > firstNonWs && _isWhitespaceAt(cleanedText, lastNonWs)) {
    lastNonWs--;
  }
  final leadingWs = cleanedText.substring(0, firstNonWs);
  final trimmed = cleanedText.substring(firstNonWs, lastNonWs + 1);
  final trailingWs = cleanedText.substring(lastNonWs + 1);

  final wrapped = '$leadingWs$opening$trimmed$closing$trailingWs';
  var newText = text.replaceRange(expandedStart, expandedEnd, wrapped);
  newText = _cleanOrphanedDelimiters(newText);

  // Selection includes the delimiters so the user can see and toggle them.
  // First-occurrence recovery is canonical behavior (matches the reference
  // implementation): in repetitive text it can select an earlier identical
  // occurrence.
  final fullWrapped = '$opening$trimmed$closing';
  final fullIndex = newText.indexOf(fullWrapped);
  if (fullIndex >= 0) {
    return (
      text: newText,
      selectionStart: fullIndex,
      selectionEnd: fullIndex + fullWrapped.length,
    );
  }
  final contentStart = leadingWs.length.clamp(0, newText.length);
  final contentEnd = (contentStart + fullWrapped.length).clamp(
    contentStart,
    newText.length,
  );
  return (
    text: newText,
    selectionStart: contentStart,
    selectionEnd: contentEnd,
  );
}

/// Inserts an opening+closing delimiter pair at [offset] and places the
/// collapsed cursor between them.
FormattingResult insertDelimiters(
  String text,
  int offset,
  MarkdownStyle style,
) {
  final at = clampToCharacterBoundary(text, offset);
  final opening = style.openingDelimiter;
  final closing = style.closingDelimiter;
  final newText = text.replaceRange(at, at, '$opening$closing');
  final cursor = at + opening.length;
  return (text: newText, selectionStart: cursor, selectionEnd: cursor);
}

/// True when [text] is exactly one `[text](url)` markdown link.
bool isMarkdownLink(String text) => _markdownLinkPattern.hasMatch(text);

/// Wraps the selection as `[selection](url)`, or inserts a
/// `[link text](url)` placeholder at a collapsed cursor. The resulting link
/// stays selected so the link button can toggle it back off.
FormattingResult wrapSelectionWithLink(
  String text,
  int start,
  int end,
  String url,
) {
  final (s, e) = _normalizeRange(text, start, end);
  final selectedText = text.substring(s, e);
  final linkMarkdown = selectedText.isEmpty
      ? '[link text]($url)'
      : '[$selectedText]($url)';
  final newText = text.replaceRange(s, e, linkMarkdown);
  return (
    text: newText,
    selectionStart: s,
    selectionEnd: s + linkMarkdown.length,
  );
}

/// Replaces a selected `[text](url)` link with its display text. Returns
/// null when the selection is not exactly a markdown link.
FormattingResult? unwrapLink(String text, int start, int end) {
  final (s, e) = _normalizeRange(text, start, end);
  final selectedText = text.substring(s, e);
  final match = _markdownLinkPattern.firstMatch(selectedText);
  if (match == null) return null;
  final displayText = match.group(1)!;
  final newText = text.replaceRange(s, e, displayText);
  return (
    text: newText,
    selectionStart: s,
    selectionEnd: s + displayText.length,
  );
}

/// True when [text] contains at least one properly paired markdown span.
bool containsMarkdownSyntax(String text) {
  if (text.isEmpty) return false;
  if (RegExp(r'\*\*[^*]+\*\*').hasMatch(text)) return true;
  if (RegExp(r'(?<!\*)\*[^*]+\*(?!\*)').hasMatch(text)) return true;
  if (RegExp(r'~~[^~]+~~').hasMatch(text)) return true;
  if (RegExp(r'`[^`]+`').hasMatch(text)) return true;
  if (RegExp(r'\[[^\]]+\]\([^)]+\)').hasMatch(text)) return true;
  return false;
}

/// Expands a range to absorb contiguous delimiter characters (`*`, `~`,
/// `` ` ``) touching or contained in the selection, so a selection cutting
/// through existing formatting never strands half a delimiter.
(int, int) _expandToDelimiterBoundaries(String text, int start, int end) {
  var hasDelimitersInside = false;
  for (var i = start; i < end; i++) {
    if (_isDelimiterUnitAt(text, i)) {
      hasDelimitersInside = true;
      break;
    }
  }
  final hasDelimiterBefore = start > 0 && _isDelimiterUnitAt(text, start - 1);
  final hasDelimiterAfter = end < text.length && _isDelimiterUnitAt(text, end);
  if (!hasDelimitersInside && !hasDelimiterBefore && !hasDelimiterAfter) {
    return (start, end);
  }

  var lower = start;
  while (lower > 0 && _isDelimiterUnitAt(text, lower - 1)) {
    lower--;
  }
  var upper = end;
  while (upper < text.length && _isDelimiterUnitAt(text, upper)) {
    upper++;
  }
  return (lower, upper);
}

/// Strips every markdown delimiter character, returning plain text.
String _stripMarkdownDelimiters(String text) {
  final buf = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (!_isDelimiterUnitAt(text, i)) buf.writeCharCode(text.codeUnitAt(i));
  }
  return buf.toString();
}

/// Removes orphaned (odd-count) delimiters while preserving paired ones.
/// Order matters: `**` and `~~` before the single-`*` pass.
String _cleanOrphanedDelimiters(String text) {
  var result = text;
  result = _cleanOrphanedPairs(result, '**');
  result = _cleanOrphanedPairs(result, '~~');
  result = _cleanOrphanedPairs(result, '`');
  result = _cleanOrphanedPairs(result, '*');
  return result;
}

/// Removes the last occurrence of [delimiter] when its non-overlapping
/// occurrence count is odd (i.e. at least one orphan exists).
String _cleanOrphanedPairs(String text, String delimiter) {
  var count = 0;
  var searchStart = 0;
  while (true) {
    final found = text.indexOf(delimiter, searchStart);
    if (found < 0) break;
    count++;
    searchStart = found + delimiter.length;
  }
  if (count.isEven) return text;
  final lastIndex = text.lastIndexOf(delimiter);
  if (lastIndex < 0) return text;
  return text.replaceRange(lastIndex, lastIndex + delimiter.length, '');
}
