// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../services/haptic_service.dart';
import '../../navigation/main_shell.dart';
import '../models/tak_event.dart';
import '../providers/tak_providers.dart';
import '../providers/tak_tracking_provider.dart';
import '../utils/cot_affiliation.dart';

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

    return GlassScaffold.body(
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
            AppLogging.tak('Copied event JSON to clipboard: uid=${event.uid}');
            Clipboard.setData(ClipboardData(text: event.toJsonString()));
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Event JSON copied')));
          },
          tooltip: 'Copy JSON',
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
          ]),
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
          ]),
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
          ]),
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
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(
    ThemeData theme,
    Color accentColor,
    String title,
    List<Widget> children,
  ) {
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
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: accentColor,
                letterSpacing: 1.2,
              ),
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
