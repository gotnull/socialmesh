// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/glass_scaffold.dart';
import '../models/tak_event.dart';

/// Detail view for a single TAK/CoT event.
class TakEventDetailScreen extends StatelessWidget {
  final TakEvent event;

  const TakEventDetailScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dimStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
    );
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'monospace',
    );

    return GlassScaffold.body(
      title: event.displayName,
      actions: [
        IconButton(
          icon: const Icon(Icons.copy),
          onPressed: () {
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
          _HeaderCard(event: event, theme: theme),
          const SizedBox(height: 16),
          _buildSection(theme, 'Identity', [
            _row('UID', event.uid, dimStyle, valueStyle),
            _row('Type', event.type, dimStyle, valueStyle),
            _row('Description', event.typeDescription, dimStyle, valueStyle),
            if (event.callsign != null)
              _row('Callsign', event.callsign!, dimStyle, valueStyle),
          ]),
          const SizedBox(height: 8),
          _buildSection(theme, 'Position', [
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
          _buildSection(theme, 'Timestamps', [
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
            _buildSection(theme, 'Raw Payload', [
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

  Widget _buildSection(ThemeData theme, String title, List<Widget> children) {
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
                color: Colors.orange.shade400,
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

  const _HeaderCard({required this.event, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (event.isStale ? Colors.red : Colors.green).withValues(
            alpha: 0.3,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.gps_fixed,
              color: Colors.orange.shade400,
              size: 24,
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
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (event.isStale ? Colors.red : Colors.green).withValues(
                alpha: 0.15,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              event.isStale ? 'STALE' : 'ACTIVE',
              style: theme.textTheme.labelSmall?.copyWith(
                color: event.isStale ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
