// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/help/help_content.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/ico_help_system.dart';
import '../../../core/widgets/search_filter_header.dart';
import '../../../core/widgets/section_header.dart';
import '../models/tak_event.dart';
import '../providers/tak_filter_provider.dart';
import '../providers/tak_providers.dart';
import '../providers/tak_settings_provider.dart';
import '../services/tak_gateway_client.dart';
import '../utils/cot_affiliation.dart';
import '../widgets/tak_event_tile.dart';
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
  late final TextEditingController _searchController;

  /// Primary affiliations shown as filter chips.
  static const _primaryAffiliations = [
    CotAffiliation.friendly,
    CotAffiliation.hostile,
    CotAffiliation.neutral,
    CotAffiliation.unknown,
  ];

  @override
  void initState() {
    super.initState();
    AppLogging.tak('TakScreen initState');

    _searchController = TextEditingController(
      text: ref.read(takFilterProvider).searchQuery,
    );

    // Ensure persistence notifier is alive (loads DB, subscribes to streams)
    ref.read(takPersistenceNotifierProvider);

    // Auto-connect on first build (only if enabled in settings)
    final settings = ref.read(takSettingsProvider).value;
    final shouldAutoConnect = settings?.autoConnect ?? true;
    final client = ref.read(takGatewayClientProvider);
    if (shouldAutoConnect && client.state == TakConnectionState.disconnected) {
      AppLogging.tak('TakScreen auto-connecting...');
      client.connect();
      _autoConnectDone = true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  int _countByAffiliation(List<TakEvent> events, CotAffiliation target) {
    return events.where((e) => parseAffiliation(e.type) == target).length;
  }

  void _showSectionHelp(BuildContext context, String key) {
    final helpText = HelpContent.takSectionHelp[key];
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
                  _helpTitleForKey(key),
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

  static String _helpTitleForKey(String key) {
    switch (key) {
      case 'status':
        return 'Connection Status';
      case 'filters':
        return 'Filters';
      case 'settings':
        return 'Settings';
      default:
        return 'Info';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allEvents = ref.watch(takActiveEventsProvider);
    final filteredEvents = ref.watch(filteredTakEventsProvider);
    final filter = ref.watch(takFilterProvider);
    final client = ref.read(takGatewayClientProvider);
    final connectionAsync = ref.watch(takConnectionStateProvider);
    final connectionState =
        connectionAsync.whenOrNull(data: (s) => s) ?? client.state;

    // Auto-connect if provider was rebuilt and client is fresh
    if (!_autoConnectDone &&
        connectionState == TakConnectionState.disconnected) {
      final settings = ref.read(takSettingsProvider).value;
      if (settings?.autoConnect ?? true) {
        Future.microtask(() {
          if (!mounted) return;
          AppLogging.tak('TakScreen: deferred auto-connect after rebuild');
          client.connect();
        });
      }
      _autoConnectDone = true;
    }

    // Stale mode label and icon for the cycle chip
    final staleModeLabel = switch (filter.staleMode) {
      TakStaleMode.all => 'Status: All',
      TakStaleMode.activeOnly => 'Active Only',
      TakStaleMode.staleOnly => 'Stale Only',
    };
    final staleModeIcon = switch (filter.staleMode) {
      TakStaleMode.all => Icons.filter_list,
      TakStaleMode.activeOnly => Icons.timer,
      TakStaleMode.staleOnly => Icons.timer_off,
    };
    final staleModeCount = switch (filter.staleMode) {
      TakStaleMode.all => allEvents.length,
      TakStaleMode.activeOnly => allEvents.where((e) => !e.isStale).length,
      TakStaleMode.staleOnly => allEvents.where((e) => e.isStale).length,
    };

    return HelpTourController(
      topicId: 'tak_gateway_overview',
      stepKeys: const {},
      child: GlassScaffold.body(
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
          IcoHelpAppBarButton(topicId: 'tak_gateway_overview'),
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
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: Column(
            children: [
              TakStatusCard(
                connectionState: connectionState,
                totalReceived: client.totalEventsReceived,
                activeEntities: allEvents.length,
                gatewayUrl: client.gatewayUrl,
                connectedSince: client.connectedSince,
                lastError: client.lastError,
                onInfoTap: () => _showSectionHelp(context, 'status'),
              ),
              const SizedBox(height: 8),
              SearchFilterHeader(
                searchController: _searchController,
                searchQuery: filter.searchQuery,
                onSearchChanged: (value) {
                  ref.read(takFilterProvider.notifier).setSearchQuery(value);
                },
                hintText: 'Search callsign or UID',
                filterChips: [
                  SectionFilterChip(
                    label: 'All',
                    count: allEvents.length,
                    isSelected: !filter.isActive,
                    onTap: () {
                      ref.read(takFilterProvider.notifier).clearAll();
                      _searchController.clear();
                    },
                  ),
                  for (final aff in _primaryAffiliations)
                    SectionFilterChip(
                      label: aff.label,
                      count: _countByAffiliation(allEvents, aff),
                      isSelected: filter.affiliations.contains(aff),
                      color: aff.color,
                      onTap: () => ref
                          .read(takFilterProvider.notifier)
                          .toggleAffiliation(aff),
                    ),
                  SectionFilterChip(
                    label: staleModeLabel,
                    count: staleModeCount,
                    isSelected: filter.staleMode != TakStaleMode.all,
                    icon: staleModeIcon,
                    onTap: () =>
                        ref.read(takFilterProvider.notifier).cycleStaleMode(),
                  ),
                ],
              ),
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
                                builder: (_) =>
                                    TakEventDetailScreen(event: event),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
