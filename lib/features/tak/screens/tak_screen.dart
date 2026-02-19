// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../providers/tak_filter_provider.dart';
import '../providers/tak_providers.dart';
import '../services/tak_gateway_client.dart';
import '../widgets/tak_event_tile.dart';
import '../widgets/tak_filter_bar.dart';
import '../widgets/tak_status_card.dart';
import 'tak_event_detail_screen.dart';
import 'tak_settings_screen.dart';

/// Main TAK Gateway screen showing connection status and live events.
///
/// Only accessible when [AppFeatureFlags.isTakGatewayEnabled] is true.
class TakScreen extends ConsumerStatefulWidget {
  const TakScreen({super.key});

  @override
  ConsumerState<TakScreen> createState() => _TakScreenState();
}

class _TakScreenState extends ConsumerState<TakScreen> with LifecycleSafeMixin {
  bool _autoConnectDone = false;

  @override
  void initState() {
    super.initState();
    AppLogging.tak('TakScreen initState');

    // Ensure persistence notifier is alive (loads DB, subscribes to streams)
    ref.read(takPersistenceNotifierProvider);

    // Auto-connect on first build
    final client = ref.read(takGatewayClientProvider);
    if (client.state == TakConnectionState.disconnected) {
      AppLogging.tak('TakScreen auto-connecting...');
      client.connect();
      _autoConnectDone = true;
    }
  }

  @override
  void dispose() {
    AppLogging.tak('TakScreen dispose');
    super.dispose();
  }

  void _toggleConnection() {
    final client = ref.read(takGatewayClientProvider);
    final connState =
        ref.read(takConnectionStateProvider).whenOrNull(data: (s) => s) ??
        client.state;
    if (connState == TakConnectionState.connected) {
      AppLogging.tak('TakScreen: user toggled disconnect');
      client.disconnect();
    } else {
      AppLogging.tak('TakScreen: user toggled connect');
      client.connect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allEvents = ref.watch(takActiveEventsProvider);
    final filteredEvents = ref.watch(filteredTakEventsProvider);
    final client = ref.read(takGatewayClientProvider);
    final connectionAsync = ref.watch(takConnectionStateProvider);
    final connectionState =
        connectionAsync.whenOrNull(data: (s) => s) ?? client.state;

    // Auto-connect if provider was rebuilt and client is fresh
    if (!_autoConnectDone &&
        connectionState == TakConnectionState.disconnected) {
      Future.microtask(() {
        if (!mounted) return;
        AppLogging.tak('TakScreen: deferred auto-connect after rebuild');
        client.connect();
      });
      _autoConnectDone = true;
    }

    return GlassScaffold.body(
      title: 'TAK Gateway',
      actions: [
        IconButton(
          icon: Icon(
            connectionState == TakConnectionState.connected
                ? Icons.link
                : Icons.link_off,
            color: connectionState == TakConnectionState.connected
                ? Colors.green
                : Colors.grey,
          ),
          onPressed: _toggleConnection,
          tooltip: connectionState == TakConnectionState.connected
              ? 'Disconnect'
              : 'Connect',
        ),
        AppBarOverflowMenu<String>(
          onSelected: (value) {
            switch (value) {
              case 'settings':
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TakSettingsScreen(),
                  ),
                );
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings, size: 18),
                  SizedBox(width: 8),
                  Text('TAK Settings'),
                ],
              ),
            ),
          ],
        ),
      ],
      body: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          TakStatusCard(
            connectionState: connectionState,
            totalReceived: client.totalEventsReceived,
            activeEntities: allEvents.length,
            gatewayUrl: AppUrls.takGatewayUrl,
            connectedSince: client.connectedSince,
            lastError: client.lastError,
          ),
          const SizedBox(height: 8),
          const TakFilterBar(),
          const SizedBox(height: 4),
          Expanded(
            child: filteredEvents.isEmpty
                ? Center(
                    child: Text(
                      connectionState == TakConnectionState.connected
                          ? 'Waiting for CoT events...'
                          : 'Not connected to TAK Gateway',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredEvents.length,
                    padding: const EdgeInsets.symmetric(
                      horizontal: UiConstants.defaultPadding,
                    ),
                    itemBuilder: (context, index) {
                      final event = filteredEvents[index];
                      return TakEventTile(
                        event: event,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => TakEventDetailScreen(event: event),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
