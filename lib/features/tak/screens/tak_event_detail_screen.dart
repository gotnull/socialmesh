// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_content.dart';
import '../../../core/logging.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/ico_help_system.dart';
import '../../../services/haptic_service.dart';
import '../../navigation/main_shell.dart';
import '../models/tak_event.dart';
import '../providers/tak_providers.dart';
import '../providers/tak_tracking_provider.dart';
import '../services/tak_database.dart';
import '../utils/cot_affiliation.dart';
import 'tak_navigate_screen.dart';

/// Detail view for a single TAK/CoT event.
class TakEventDetailScreen extends ConsumerWidget {
  final TakEvent event;

  const TakEventDetailScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AppLogging.tak(
      'TakEventDetailScreen build: uid=${event.uid}, '
      'type=${event.type}, callsign=${event.callsign ?? "none"}, '
      'isStale=${event.isStale}',
    );
    final theme = Theme.of(context);
    final affiliation = parseAffiliation(event.type);
    final affiliationColor = affiliation.color;
    final dimStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
    );
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'monospace',
    );

    final trackedUids = ref.watch(takTrackedUidsProvider);
    final isTracked = trackedUids.contains(event.uid);

    return HelpTourController(
      topicId: 'tak_gateway_overview',
      stepKeys: const {},
      child: GlassScaffold.body(
        title: event.displayName,
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            onPressed: () {
              AppLogging.tak(
                'Show on map: uid=${event.uid}, '
                'lat=${event.lat}, lon=${event.lon}',
              );
              ref.read(takShowOnMapProvider.notifier).request(event);
              ref.read(mapTakModeProvider.notifier).request();
              ref.read(mainShellIndexProvider.notifier).setIndex(1);
              Navigator.of(context).popUntil((route) => route.isFirst);
              ref.haptics.itemSelect();
            },
            tooltip: 'Show on Map',
          ),
          IconButton(
            icon: Icon(
              isTracked ? Icons.push_pin : Icons.push_pin_outlined,
              color: affiliationColor,
            ),
            onPressed: () async {
              await ref.read(takTrackingProvider.notifier).toggle(event.uid);
              ref.haptics.toggle();
            },
            tooltip: isTracked ? 'Untrack' : 'Track',
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              AppLogging.tak(
                'Copied event JSON to clipboard: uid=${event.uid}',
              );
              Clipboard.setData(ClipboardData(text: event.toJsonString()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Event JSON copied')),
              );
            },
            tooltip: 'Copy JSON',
          ),
          AppBarOverflowMenu<String>(
            onSelected: (value) {
              switch (value) {
                case 'navigate':
                  ref.haptics.itemSelect();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TakNavigateScreen(
                        targetUid: event.uid,
                        initialCallsign: event.callsign ?? event.uid,
                      ),
                    ),
                  );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'navigate',
                child: Row(
                  children: [
                    Icon(Icons.navigation_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Navigate to'),
                  ],
                ),
              ),
            ],
          ),
        ],
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HeaderCard(
              event: event,
              theme: theme,
              affiliationColor: affiliationColor,
              affiliationLabel: affiliation.label,
            ),
            const SizedBox(height: 16),
            _buildSection(theme, affiliationColor, 'Identity', [
              _row('UID', event.uid, dimStyle, valueStyle),
              _row('Type', event.type, dimStyle, valueStyle),
              _row('Description', event.typeDescription, dimStyle, valueStyle),
              if (event.callsign != null)
                _row('Callsign', event.callsign!, dimStyle, valueStyle),
            ], helpKey: 'identity'),
            const SizedBox(height: 8),
            _buildSection(theme, affiliationColor, 'Position', [
              _row(
                'Latitude',
                event.lat.toStringAsFixed(6),
                dimStyle,
                valueStyle,
              ),
              _row(
                'Longitude',
                event.lon.toStringAsFixed(6),
                dimStyle,
                valueStyle,
              ),
            ], helpKey: 'position'),
            if (event.hasMotionData) ...[
              const SizedBox(height: 8),
              _buildSection(theme, affiliationColor, 'Motion', [
                _row('Speed', event.formattedSpeed, dimStyle, valueStyle),
                if (event.formattedCourse != null)
                  _row('Course', event.formattedCourse!, dimStyle, valueStyle),
                if (event.formattedAltitude != null)
                  _row(
                    'Altitude',
                    event.formattedAltitude!,
                    dimStyle,
                    valueStyle,
                  ),
              ], helpKey: 'motion'),
            ],
            const SizedBox(height: 8),
            _buildSection(theme, affiliationColor, 'Timestamps', [
              _row(
                'Event Time',
                _formatTimestamp(event.timeUtcMs),
                dimStyle,
                valueStyle,
              ),
              _row(
                'Stale Time',
                _formatTimestamp(event.staleUtcMs),
                dimStyle,
                valueStyle,
              ),
              _row(
                'Received',
                _formatTimestamp(event.receivedUtcMs),
                dimStyle,
                valueStyle,
              ),
              _row(
                'Status',
                event.isStale ? 'STALE' : 'ACTIVE',
                dimStyle,
                valueStyle?.copyWith(
                  color: event.isStale ? Colors.red : Colors.green,
                ),
              ),
            ], helpKey: 'timestamps'),
            const SizedBox(height: 8),
            _PositionHistorySection(
              event: event,
              theme: theme,
              affiliationColor: affiliationColor,
              dimStyle: dimStyle,
              valueStyle: valueStyle,
            ),
            if (event.rawPayloadJson != null) ...[
              const SizedBox(height: 8),
              _buildSection(theme, affiliationColor, 'Raw Payload', [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: SelectableText(
                    event.rawPayloadJson!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ], helpKey: 'raw_payload'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    ThemeData theme,
    Color accentColor,
    String title,
    List<Widget> children, {
    String? helpKey,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accentColor,
                    letterSpacing: 1.2,
                  ),
                ),
                if (helpKey != null) ...[
                  const SizedBox(width: 4),
                  _TakSectionInfoButton(helpKey: helpKey),
                ],
              ],
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    String value,
    TextStyle? dimStyle,
    TextStyle? valueStyle,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: dimStyle)),
          Expanded(child: SelectableText(value, style: valueStyle)),
        ],
      ),
    );
  }

  String _formatTimestamp(int utcMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(utcMs, isUtc: true);
    return '${dt.toIso8601String().replaceAll('T', ' ').split('.').first} UTC';
  }
}

class _HeaderCard extends StatelessWidget {
  final TakEvent event;
  final ThemeData theme;
  final Color affiliationColor;
  final String affiliationLabel;

  const _HeaderCard({
    required this.event,
    required this.theme,
    required this.affiliationColor,
    required this.affiliationLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isStale = event.isStale;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: affiliationColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Icon matching map marker affiliation color
          Opacity(
            opacity: isStale ? 0.4 : 1.0,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: affiliationColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: affiliationColor.withValues(alpha: 0.4),
                ),
              ),
              child: Icon(
                cotTypeIcon(event.type),
                color: affiliationColor,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.displayName, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '${event.typeDescription}  \u2022  '
                  '${event.lat.toStringAsFixed(4)}, '
                  '${event.lon.toStringAsFixed(4)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                // Affiliation badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: affiliationColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: affiliationColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    affiliationLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: affiliationColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (isStale ? Colors.red : Colors.green).withValues(
                alpha: 0.15,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isStale ? 'STALE' : 'ACTIVE',
              style: theme.textTheme.labelSmall?.copyWith(
                color: isStale ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Position History Section — shows movement timeline from position_history DB
// =============================================================================

class _PositionHistorySection extends ConsumerStatefulWidget {
  final TakEvent event;
  final ThemeData theme;
  final Color affiliationColor;
  final TextStyle? dimStyle;
  final TextStyle? valueStyle;

  const _PositionHistorySection({
    required this.event,
    required this.theme,
    required this.affiliationColor,
    required this.dimStyle,
    required this.valueStyle,
  });

  @override
  ConsumerState<_PositionHistorySection> createState() =>
      _PositionHistorySectionState();
}

class _PositionHistorySectionState
    extends ConsumerState<_PositionHistorySection> {
  bool _expanded = false;

  /// Collapsed view shows this many entries.
  static const _collapsedCount = 5;

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(
      takPositionHistoryProvider(widget.event.uid),
    );

    return historyAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (history) {
        if (history.isEmpty) return const SizedBox.shrink();

        final entries = _expanded
            ? history
            : history.take(_collapsedCount).toList();
        final hasMore = history.length > _collapsedCount;

        return Container(
          decoration: BoxDecoration(
            color: widget.theme.colorScheme.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Text(
                      'POSITION HISTORY',
                      style: widget.theme.textTheme.labelSmall?.copyWith(
                        color: widget.affiliationColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${history.length} positions)',
                      style: widget.theme.textTheme.labelSmall?.copyWith(
                        color: widget.theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (history.length == 1)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text('No movement recorded', style: widget.dimStyle),
                )
              else
                ...entries.asMap().entries.map((mapEntry) {
                  final idx = mapEntry.key;
                  final point = mapEntry.value;
                  // Distance from previous point (next in list since
                  // newest-first)
                  final nextIdx = idx + 1;
                  String? distance;
                  if (nextIdx < history.length) {
                    final prev = history[nextIdx];
                    distance = _formatDistance(
                      _haversineMeters(
                        point.lat,
                        point.lon,
                        prev.lat,
                        prev.lon,
                      ),
                    );
                  }
                  return _buildHistoryEntry(point, distance);
                }),
              if (hasMore && !_expanded)
                TextButton(
                  onPressed: () => setState(() => _expanded = true),
                  child: Text(
                    'Show all ${history.length} positions',
                    style: TextStyle(
                      color: widget.affiliationColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (_expanded && hasMore)
                TextButton(
                  onPressed: () => setState(() => _expanded = false),
                  child: Text(
                    'Show less',
                    style: TextStyle(
                      color: widget.affiliationColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryEntry(PositionHistoryPoint point, String? distance) {
    final age = _formatAge(point.timeUtcMs);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(age, style: widget.dimStyle)),
          Expanded(
            child: Text(
              '${point.lat.toStringAsFixed(5)}, '
              '${point.lon.toStringAsFixed(5)}',
              style: widget.valueStyle?.copyWith(fontSize: 12),
            ),
          ),
          if (distance != null)
            Text(distance, style: widget.dimStyle?.copyWith(fontSize: 11)),
        ],
      ),
    );
  }

  static String _formatAge(int utcMs) {
    final diff = DateTime.now().millisecondsSinceEpoch - utcMs;
    if (diff < 60000) return '${(diff / 1000).round()}s ago';
    if (diff < 3600000) return '${(diff / 60000).round()}m ago';
    if (diff < 86400000) return '${(diff / 3600000).round()}h ago';
    return '${(diff / 86400000).round()}d ago';
  }

  static String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }

  /// Haversine formula for great-circle distance in meters.
  static double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0; // Earth radius in meters
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = _sin2(dLat / 2) + _cos(lat1) * _cos(lat2) * _sin2(dLon / 2);
    return r * 2 * _asin(_sqrt(a));
  }

  static double _toRad(double deg) => deg * 3.141592653589793 / 180;
  static double _sin2(double x) {
    final s = _sin(x);
    return s * s;
  }

  static double _sin(double x) => math.sin(x);
  static double _cos(double x) => math.cos(x);
  static double _asin(double x) => math.asin(x);
  static double _sqrt(double x) => math.sqrt(x);
}

// =============================================================================
// Section Info Button — inline contextual help for TAK detail sections
// =============================================================================

class _TakSectionInfoButton extends StatelessWidget {
  final String helpKey;

  const _TakSectionInfoButton({required this.helpKey});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showHelp(context),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.info_outline,
          size: 14,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    final helpText = HelpContent.takSectionHelp[helpKey];
    if (helpText == null) return;

    HapticFeedback.selectionClick();
    AppBottomSheet.show<void>(
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _titleForKey(helpKey),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              helpText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _titleForKey(String key) {
    switch (key) {
      case 'status':
        return 'Connection Status';
      case 'affiliation':
        return 'Affiliation';
      case 'cot_type':
        return 'CoT Type String';
      case 'identity':
        return 'Identity';
      case 'position':
        return 'Position';
      case 'motion':
        return 'Motion Data';
      case 'timestamps':
        return 'Timestamps';
      case 'tracking':
        return 'Tracking';
      case 'raw_payload':
        return 'Raw Payload';
      case 'filters':
        return 'Filters';
      case 'settings':
        return 'Settings';
      default:
        return 'Info';
    }
  }
}
