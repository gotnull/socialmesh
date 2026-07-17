// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Defensive inline-markdown parser for message bubbles.
//
// Mirrors the reference iOS renderer's inline-only interpretation: bold
// `**`, italic single `*`, strikethrough `~~`, code backtick, and
// `[text](url)` links. No block syntax. Message text comes from untrusted
// mesh peers, so the contract is: malformed or unpaired markup renders as
// literal text and the parser never throws - worst case the whole input
// comes back as one plain segment.

/// One styled run of message text.
class InlineMarkdownSegment {
  final String text;
  final bool bold;
  final bool italic;
  final bool strikethrough;
  final bool code;

  /// Set only for `[text](url)` links whose URL is http/https.
  final String? linkUrl;

  const InlineMarkdownSegment(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.strikethrough = false,
    this.code = false,
    this.linkUrl,
  });

  bool get isPlain =>
      !bold && !italic && !strikethrough && !code && linkUrl == null;
}

class _StyleContext {
  final bool bold;
  final bool italic;
  final bool strikethrough;

  const _StyleContext({
    this.bold = false,
    this.italic = false,
    this.strikethrough = false,
  });

  _StyleContext merge({bool? bold, bool? italic, bool? strikethrough}) =>
      _StyleContext(
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        strikethrough: strikethrough ?? this.strikethrough,
      );
}

const _maxNestingDepth = 4;

/// Cheap pre-filter: true when [text] contains any character that could
/// open an inline markdown span (`*`, `~`, `` ` ``, `[`). Lets render
/// paths skip the parser for the common all-plain message.
bool containsAnyMarkdownCandidate(String text) {
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if (unit == 0x2A || unit == 0x7E || unit == 0x60 || unit == 0x5B) {
      return true;
    }
  }
  return false;
}

/// Parses [text] into styled segments. Never throws: any parse failure
/// falls back to a single plain segment carrying the raw text.
List<InlineMarkdownSegment> parseInlineMarkdown(String text) {
  if (text.isEmpty) return const [];
  try {
    return _parseSpan(text, const _StyleContext(), 0);
  } catch (_) {
    return [InlineMarkdownSegment(text)];
  }
}

List<InlineMarkdownSegment> _parseSpan(
  String text,
  _StyleContext ctx,
  int depth,
) {
  if (depth > _maxNestingDepth) return [_segment(text, ctx)];

  final out = <InlineMarkdownSegment>[];
  final literal = StringBuffer();
  var i = 0;

  void flushLiteral() {
    if (literal.isEmpty) return;
    out.add(_segment(literal.toString(), ctx));
    literal.clear();
  }

  while (i < text.length) {
    final unit = text.codeUnitAt(i);

    // Code span: contents render literally, no nested parsing.
    if (unit == 0x60 /* ` */ ) {
      final closing = text.indexOf('`', i + 1);
      if (closing > i + 1) {
        flushLiteral();
        out.add(
          InlineMarkdownSegment(
            text.substring(i + 1, closing),
            bold: ctx.bold,
            italic: ctx.italic,
            strikethrough: ctx.strikethrough,
            code: true,
          ),
        );
        i = closing + 1;
        continue;
      }
    }

    // Link: [text](url). Only http/https URLs become tappable; anything
    // else renders as the literal source text (untrusted peers must not
    // smuggle other schemes behind display text).
    if (unit == 0x5B /* [ */ ) {
      final link = _tryParseLink(text, i);
      if (link != null) {
        flushLiteral();
        if (link.url != null) {
          out.add(
            InlineMarkdownSegment(
              link.display,
              bold: ctx.bold,
              italic: ctx.italic,
              strikethrough: ctx.strikethrough,
              linkUrl: link.url,
            ),
          );
        } else {
          out.add(_segment(text.substring(i, link.end), ctx));
        }
        i = link.end;
        continue;
      }
    }

    if (unit == 0x2A /* * */ ) {
      // Bold italic: ***text***.
      if (text.startsWith('***', i)) {
        final closing = text.indexOf('***', i + 3);
        if (closing > i + 3) {
          flushLiteral();
          out.addAll(
            _parseSpan(
              text.substring(i + 3, closing),
              ctx.merge(bold: true, italic: true),
              depth + 1,
            ),
          );
          i = closing + 3;
          continue;
        }
      }
      // Bold: **text**.
      if (text.startsWith('**', i)) {
        final closing = text.indexOf('**', i + 2);
        if (closing > i + 2) {
          flushLiteral();
          out.addAll(
            _parseSpan(
              text.substring(i + 2, closing),
              ctx.merge(bold: true),
              depth + 1,
            ),
          );
          i = closing + 2;
          continue;
        }
      } else {
        // Italic: *text* where the content carries no asterisk and the
        // closer is a single asterisk (mirrors the canonical
        // (?<!\*)\*[^*]+\*(?!\*) pattern).
        final closing = text.indexOf('*', i + 1);
        if (closing > i + 1 &&
            (closing + 1 >= text.length ||
                text.codeUnitAt(closing + 1) != 0x2A)) {
          flushLiteral();
          out.addAll(
            _parseSpan(
              text.substring(i + 1, closing),
              ctx.merge(italic: true),
              depth + 1,
            ),
          );
          i = closing + 1;
          continue;
        }
      }
    }

    // Strikethrough: ~~text~~.
    if (unit == 0x7E /* ~ */ && text.startsWith('~~', i)) {
      final closing = text.indexOf('~~', i + 2);
      if (closing > i + 2) {
        flushLiteral();
        out.addAll(
          _parseSpan(
            text.substring(i + 2, closing),
            ctx.merge(strikethrough: true),
            depth + 1,
          ),
        );
        i = closing + 2;
        continue;
      }
    }

    literal.writeCharCode(unit);
    i++;
  }

  flushLiteral();
  return out;
}

InlineMarkdownSegment _segment(String text, _StyleContext ctx) =>
    InlineMarkdownSegment(
      text,
      bold: ctx.bold,
      italic: ctx.italic,
      strikethrough: ctx.strikethrough,
    );

({String display, String? url, int end})? _tryParseLink(String text, int at) {
  final closeBracket = text.indexOf(']', at + 1);
  if (closeBracket <= at + 1) return null;
  if (closeBracket + 1 >= text.length ||
      text.codeUnitAt(closeBracket + 1) != 0x28 /* ( */ ) {
    return null;
  }
  final closeParen = text.indexOf(')', closeBracket + 2);
  if (closeParen <= closeBracket + 2) return null;

  final display = text.substring(at + 1, closeBracket);
  // Nested brackets inside the display text are not a link (mirrors the
  // canonical [^\]]+ pattern).
  if (display.contains('[')) return null;
  final rawUrl = text.substring(closeBracket + 2, closeParen);

  final uri = Uri.tryParse(rawUrl);
  final isHttp = uri != null && (uri.isScheme('http') || uri.isScheme('https'));
  return (display: display, url: isHttp ? rawUrl : null, end: closeParen + 1);
}
