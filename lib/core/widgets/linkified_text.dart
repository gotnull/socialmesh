// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/snackbar.dart';
import '../l10n/l10n_extension.dart';
import '../theme.dart';
import 'app_bottom_sheet.dart';

typedef UrlMatch = ({int start, int end, String url});

// Renders [text] with any http/https URLs as tappable spans. Mesh peers are
// untrusted, so tapping opens a confirm bottom sheet that shows the full URL
// before launching the browser.
class LinkifiedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;
  final TextAlign? textAlign;

  const LinkifiedText({
    super.key,
    required this.text,
    this.style,
    this.linkStyle,
    this.textAlign,
  });

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  void _clearRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();
    final matches = detectUrls(widget.text);
    if (matches.isEmpty) {
      return Text(
        widget.text,
        style: widget.style,
        textAlign: widget.textAlign,
      );
    }

    final baseStyle = widget.style ?? const TextStyle();
    final linkStyle = widget.linkStyle != null
        ? baseStyle.merge(widget.linkStyle)
        : baseStyle.copyWith(
            color: context.accentColor,
            decoration: TextDecoration.underline,
            decorationColor: context.accentColor,
          );

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, m.start)));
      }
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _confirmAndOpen(m.url);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(text: m.url, style: linkStyle, recognizer: recognizer),
      );
      cursor = m.end;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(style: widget.style, children: spans),
      textAlign: widget.textAlign,
    );
  }

  Future<void> _confirmAndOpen(String url) async {
    final l10n = context.l10n;
    final confirmed = await AppBottomSheet.show<bool>(
      context: context,
      child: _OpenLinkSheet(url: url),
    );
    if (confirmed != true || !mounted) return;
    final uri = Uri.tryParse(url);
    if (uri == null) {
      showErrorSnackBar(context, l10n.openLinkLaunchFailed);
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      showErrorSnackBar(context, l10n.openLinkLaunchFailed);
    }
  }
}

class _OpenLinkSheet extends StatelessWidget {
  final String url;

  const _OpenLinkSheet({required this.url});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.openLinkTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        Text(
          l10n.openLinkDescription,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.textSecondary),
        ),
        const SizedBox(height: AppTheme.spacing16),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing12,
            vertical: AppTheme.spacing12,
          ),
          decoration: BoxDecoration(
            color: context.background,
            borderRadius: BorderRadius.circular(AppTheme.radius8),
          ),
          child: SelectableText(
            url,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              color: context.accentColor,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacing24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacing16,
                  ),
                  side: BorderSide(color: SemanticColors.divider),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                ),
                child: Text(l10n.openLinkCancelAction),
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacing16,
                  ),
                  backgroundColor: context.accentColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                ),
                child: Text(l10n.openLinkOpenAction),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Public for tests. Returns URL ranges in [text], stripping common trailing
// punctuation (".,;:!?\">'") and unbalanced closing brackets so that
// "See https://example.com/foo." detects the URL without the trailing period
// while "https://en.wikipedia.org/wiki/Foo_(bar)" keeps its closing paren.
@visibleForTesting
List<UrlMatch> detectUrls(String text) {
  final regex = RegExp(r'https?://\S+');
  final result = <UrlMatch>[];
  for (final m in regex.allMatches(text)) {
    var end = m.end;
    var url = m.group(0)!;
    var changed = true;
    while (changed && url.isNotEmpty) {
      changed = false;
      final last = url[url.length - 1];
      if ('.,;:!?>"\''.contains(last)) {
        url = url.substring(0, url.length - 1);
        end--;
        changed = true;
        continue;
      }
      if (last == ')' && !url.contains('(')) {
        url = url.substring(0, url.length - 1);
        end--;
        changed = true;
        continue;
      }
      if (last == ']' && !url.contains('[')) {
        url = url.substring(0, url.length - 1);
        end--;
        changed = true;
        continue;
      }
      if (last == '}' && !url.contains('{')) {
        url = url.substring(0, url.length - 1);
        end--;
        changed = true;
        continue;
      }
    }
    if (url.length <= 'https://'.length) continue;
    result.add((start: m.start, end: end, url: url));
  }
  return result;
}
