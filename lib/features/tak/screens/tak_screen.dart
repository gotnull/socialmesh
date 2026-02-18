// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../models/tak_event.dart';
import '../providers/tak_providers.dart';
import '../services/tak_gateway_client.dart';
import '../widgets/tak_event_tile.dart';
import '../widgets/tak_status_card.dart';
import 'tak_event_detail_screen.dart';

/// Main TAK Gateway screen showing connection status and live events.
///
/// Only accessible when [AppFeatureFlags.isTakGatewayEnabled] is true.
class TakScreen extends ConsumerStatefulWidget {
  const TakScreen({super.key});

  @override
  ConsumerState<TakScreen> createState() => _TakScreenState();
}

class _TakScreenState extends ConsumerState<TakScreen> with LifecycleSafeMixin {
  final List<TakEvent> _events = [];
  StreamSubscription<TakEvent>? _eventSub;
  StreamSubscription<List<TakEvent>>? _snapshotSub;
  StreamSubscription<TakConnectionState>? _stateSub;
  TakConnectionState _connectionState = TakConnectionState.disconnected;
  int _totalReceived = 0;

  @override
  void initState() {
    super.initState();
    AppLogging.tak('TakScreen initState');
    _initClient();
  }

  void _initClient() {
    final client = ref.read(takGatewayClientProvider);
    AppLogging.tak('TakScreen _initClient: gateway=${client.gatewayUrl}');

    _stateSub = client.stateStream.listen((state) {
      if (!mounted) return;
      AppLogging.tak('TakScreen connection state: ${state.name}');
      safeSetState(() {
        _connectionState = state;
      });
    });

    _eventSub = client.eventStream.listen((event) {
      if (!mounted) return;
      _totalReceived++;
      AppLogging.tak(
        'TakScreen event received: uid=${event.uid}, '
        'callsign=${event.callsign ?? "none"}, '
        'total=$_totalReceived, inMemory=${_events.length}',
      );
      safeSetState(() {
        // Update or insert by uid+type
        final idx = _events.indexWhere(
          (e) => e.uid == event.uid && e.type == event.type,
        );
        if (idx >= 0) {
          _events[idx] = event;
        } else {
          _events.insert(0, event);
        }
        // Cap at 200 in-memory
        if (_events.length > 200) {
          _events.removeLast();
        }
      });
    });

    _snapshotSub = client.snapshotStream.listen((snapshot) {
      if (!mounted) return;
      AppLogging.tak('TakScreen snapshot received: ${snapshot.length} events');
      safeSetState(() {
        _totalReceived += snapshot.length;
        for (final event in snapshot) {
          final idx = _events.indexWhere(
            (e) => e.uid == event.uid && e.type == event.type,
          );
          if (idx >= 0) {
            _events[idx] = event;
          } else {
            _events.add(event);
          }
        }
        // Sort: most recent first
        _events.sort((a, b) => b.receivedUtcMs.compareTo(a.receivedUtcMs));
      });
      AppLogging.tak(
        'TakScreen snapshot applied: inMemory=${_events.length}, '
        'totalReceived=$_totalReceived',
      );
    });

    // Auto-connect
    AppLogging.tak('TakScreen auto-connecting...');
    client.connect();
  }

  @override
  void dispose() {
    AppLogging.tak('TakScreen dispose');
    _eventSub?.cancel();
    _snapshotSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  void _toggleConnection() {
    final client = ref.read(takGatewayClientProvider);
    if (_connectionState == TakConnectionState.connected) {
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

    return GlassScaffold.body(
      title: 'TAK Gateway',
      actions: [
        IconButton(
          icon: Icon(
            _connectionState == TakConnectionState.connected
                ? Icons.link
                : Icons.link_off,
            color: _connectionState == TakConnectionState.connected
                ? Colors.green
                : Colors.grey,
          ),
          onPressed: _toggleConnection,
          tooltip: _connectionState == TakConnectionState.connected
              ? 'Disconnect'
              : 'Connect',
        ),
      ],
      body: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          TakStatusCard(
            connectionState: _connectionState,
            totalReceived: _totalReceived,
            activeEntities: _events.length,
            gatewayUrl: AppUrls.takGatewayUrl,
            connectedSince: ref.read(takGatewayClientProvider).connectedSince,
            lastError: ref.read(takGatewayClientProvider).lastError,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _events.isEmpty
                ? Center(
                    child: Text(
                      _connectionState == TakConnectionState.connected
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
                    itemCount: _events.length,
                    padding: const EdgeInsets.symmetric(
                      horizontal: UiConstants.defaultPadding,
                    ),
                    itemBuilder: (context, index) {
                      final event = _events[index];
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
