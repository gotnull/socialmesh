// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:url_launcher/url_launcher.dart';

import '../../utils/snackbar.dart';
import '../l10n/l10n_extension.dart';
import '../theme.dart';
import 'app_bottom_sheet.dart';

typedef UrlMatch = ({int start, int end, String url});
typedef CoordinateMatch = ({
  int start,
  int end,
  double latitude,
  double longitude,
});

enum _CoordinateAction { showOnMap, createWaypoint, copy }

// Renders [text] with any http/https URLs and GPS coordinate pairs as tappable
// spans. Mesh peers are untrusted, so tapping a URL opens a confirm bottom
// sheet that shows the full URL before launching the browser. Tapping a
// coordinate opens an action sheet to show it on the map, drop a mesh
// waypoint, or copy it.
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
    final urlMatches = detectUrls(widget.text);
    // Drop any coordinate that falls inside a detected URL (e.g. a maps link
    // with a "?q=lat,lng" query) so the same span isn't linkified twice.
    final coordMatches = detectCoordinates(widget.text)
        .where(
          (c) => !urlMatches.any((u) => c.start < u.end && u.start < c.end),
        )
        .toList();

    if (urlMatches.isEmpty && coordMatches.isEmpty) {
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

    // Merge URL and coordinate ranges into one ordered, non-overlapping list.
    final ranges = <({int start, int end, VoidCallback onTap})>[
      for (final u in urlMatches)
        (start: u.start, end: u.end, onTap: () => _confirmAndOpen(u.url)),
      for (final c in coordMatches)
        (
          start: c.start,
          end: c.end,
          onTap: () => _showCoordinateActions(c.latitude, c.longitude),
        ),
    ]..sort((a, b) => a.start.compareTo(b.start));

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final r in ranges) {
      if (r.start < cursor) continue;
      if (r.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, r.start)));
      }
      final recognizer = TapGestureRecognizer()..onTap = r.onTap;
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: widget.text.substring(r.start, r.end),
          style: linkStyle,
          recognizer: recognizer,
        ),
      );
      cursor = r.end;
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

  Future<void> _showCoordinateActions(double latitude, double longitude) async {
    final l10n = context.l10n;
    final formatted = formatCoordinatePair(latitude, longitude);
    final action = await AppBottomSheet.showActions<_CoordinateAction>(
      context: context,
      header: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_on_outlined, color: context.accentColor),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.coordinateSheetTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  formatted,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: AppTheme.fontFamily,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        BottomSheetAction(
          icon: Icons.map_outlined,
          iconColor: context.accentColor,
          label: l10n.coordinateActionShowOnMap,
          value: _CoordinateAction.showOnMap,
        ),
        BottomSheetAction(
          icon: Icons.add_location_alt_outlined,
          iconColor: context.accentColor,
          label: l10n.coordinateActionCreateWaypoint,
          value: _CoordinateAction.createWaypoint,
        ),
        BottomSheetAction(
          icon: Icons.copy_outlined,
          label: l10n.coordinateActionCopy,
          value: _CoordinateAction.copy,
        ),
      ],
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _CoordinateAction.showOnMap:
        await Navigator.of(context).pushNamed(
          '/map',
          arguments: {
            'latitude': latitude,
            'longitude': longitude,
            'label': l10n.coordinateMapLabel,
          },
        );
      case _CoordinateAction.createWaypoint:
        await Navigator.of(context).pushNamed(
          '/waypoint-form',
          arguments: {'latitude': latitude, 'longitude': longitude},
        );
      case _CoordinateAction.copy:
        await Clipboard.setData(ClipboardData(text: formatted));
        if (mounted) {
          showSuccessSnackBar(context, l10n.mapCoordinatesCopied);
        }
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

// Public for tests. Returns "lat, lng" decimal coordinate ranges in [text].
// A match is a signed decimal pair where latitude is in [-90, 90], longitude
// in [-180, 180], each number carries a decimal fraction, and at least one has
// four or more fractional digits. The precision floor separates real GPS
// coordinates (mesh peers share them at full double precision) from casual
// decimal pairs like a "4.5, 3.2" rating or a version number.
@visibleForTesting
List<CoordinateMatch> detectCoordinates(String text) {
  final regex = RegExp(r'(-?\d{1,3}\.(\d+))\s*,\s*(-?\d{1,3}\.(\d+))');
  final result = <CoordinateMatch>[];
  for (final m in regex.allMatches(text)) {
    final latitude = double.tryParse(m.group(1)!);
    final longitude = double.tryParse(m.group(3)!);
    if (latitude == null || longitude == null) continue;
    if (latitude < -90 || latitude > 90) continue;
    if (longitude < -180 || longitude > 180) continue;
    if (m.group(2)!.length < 4 && m.group(4)!.length < 4) continue;
    result.add((
      start: m.start,
      end: m.end,
      latitude: latitude,
      longitude: longitude,
    ));
  }
  return result;
}

// Public for tests. Formats a coordinate pair for display and clipboard at
// ~1m precision (5 decimal places). Full-precision values are still passed to
// the map and waypoint form, so this rounding only affects the readable string.
@visibleForTesting
String formatCoordinatePair(double latitude, double longitude) =>
    '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
