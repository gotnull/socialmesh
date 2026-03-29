// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/account_subscriptions_screen.dart';

import '../../../core/constants.dart';
import '../../../core/help/help_content.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../providers/auth_providers.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/ico_help_system.dart';
import '../../../core/widgets/search_filter_header.dart';
import '../../../core/widgets/status_filter_chip.dart';
import '../../../services/tak/providers/tak_bridge_providers.dart';
import '../models/tak_event.dart';
import '../providers/tak_filter_provider.dart';
import '../providers/tak_providers.dart';
import '../providers/tak_settings_provider.dart';
import '../services/tak_gateway_client.dart';
import '../utils/cot_affiliation.dart';
import '../widgets/tak_event_tile.dart';
import '../widgets/tak_status_card.dart';
import 'tak_dashboard_screen.dart';
import 'tak_event_detail_screen.dart';
import 'tak_settings_screen.dart';
import 'tak_video_streams_screen.dart';

/// Main TAK screen showing gateway events and/or mesh bridge status.
///
/// Accessible when either [AppFeatureFlags.isTakGatewayEnabled] or
/// [AppFeatureFlags.isTakMeshBridgeEnabled] is true.
class TakScreen extends ConsumerStatefulWidget {
  const TakScreen({super.key});

  @override
  ConsumerState<TakScreen> createState() => _TakScreenState();
}

class _TakScreenState extends ConsumerState<TakScreen> with LifecycleSafeMixin {
  bool _autoConnectDone = false;
  late final TextEditingController _searchController;

  /// All affiliations shown as filter chips.
  static const _primaryAffiliations = [
    CotAffiliation.friendly,
    CotAffiliation.hostile,
    CotAffiliation.neutral,
    CotAffiliation.unknown,
    CotAffiliation.assumedFriend,
    CotAffiliation.suspect,
    CotAffiliation.pending,
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

    // Auto-connect on first build (only if gateway enabled, enabled in settings
    // AND signed in)
    if (AppFeatureFlags.isTakGatewayEnabled) {
      final isSignedIn = ref.read(isSignedInProvider);
      final settings = ref.read(takSettingsProvider).value;
      final shouldAutoConnect = settings?.autoConnect ?? true;
      final client = ref.read(takGatewayClientProvider);
      if (isSignedIn &&
          shouldAutoConnect &&
          client.state == TakConnectionState.disconnected) {
        AppLogging.tak('TakScreen auto-connecting...');
        client.connect();
        _autoConnectDone = true;
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    AppLogging.tak('TakScreen dispose');
    super.dispose();
  }

  void _toggleConnection() {
    final isSignedIn = ref.read(isSignedInProvider);
    if (!isSignedIn) {
      AppLogging.tak('TakScreen: connect blocked — not signed in');
      return;
    }
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
    final rawText = HelpContent.takSectionHelp[key];
    if (rawText == null) return;

    final helpText = HelpContent.localizedTakSectionHelp(key, context.l10n);

    HapticFeedback.selectionClick();
    AppBottomSheet.show<void>(
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppTheme.spacing24, 8, 24, 24),
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
                const SizedBox(width: AppTheme.spacing8),
                Text(
                  _localizedHelpTitleForKey(key),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),
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

  String _localizedHelpTitleForKey(String key) {
    final l10n = context.l10n;
    switch (key) {
      case 'status':
        return l10n.takScreenHelpTitleStatus;
      case 'filters':
        return l10n.takScreenHelpTitleFilters;
      case 'settings':
        return l10n.takScreenHelpTitleSettings;
      default:
        return l10n.takScreenHelpTitleDefault;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = ref.watch(isSignedInProvider);
    final allEvents = ref.watch(takActiveEventsProvider);
    final filteredEvents = ref.watch(filteredTakEventsProvider);
    final filter = ref.watch(takFilterProvider);
    final client = ref.read(takGatewayClientProvider);
    final connectionAsync = ref.watch(takConnectionStateProvider);
    final connectionState =
        connectionAsync.whenOrNull(data: (s) => s) ?? client.state;

    // Auto-connect if provider was rebuilt and client is fresh (only if
    // gateway enabled and signed in)
    if (AppFeatureFlags.isTakGatewayEnabled &&
        isSignedIn &&
        !_autoConnectDone &&
        connectionState == TakConnectionState.disconnected) {
      final settings = ref.read(takSettingsProvider).value;
      if (settings?.autoConnect ?? true) {
        Future.microtask(() {
          AppLogging.tak('TakScreen: deferred auto-connect after rebuild');
          client.connect();
        });
      }
      _autoConnectDone = true;
    }

    // Stale mode label and icon for the cycle chip
    final staleModeLabel = switch (filter.staleMode) {
      TakStaleMode.all => context.l10n.takScreenStaleModeAll,
      TakStaleMode.activeOnly => context.l10n.takScreenStaleModeActiveOnly,
      TakStaleMode.staleOnly => context.l10n.takScreenStaleModeStaleOnly,
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

    final bridgeStatus = ref.watch(takBridgeStatusProvider);

    return HelpTourController(
      topicId: 'tak_gateway_overview',
      stepKeys: const {},
      child: GlassScaffold.body(
        hasScrollBody: true,
        resizeToAvoidBottomInset: false,
        title: context.l10n.takScreenTitle,
        actions: [
          if (bridgeStatus.isRunning)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.cell_tower,
                size: 18,
                color: bridgeStatus.connectedClientCount > 0
                    ? AccentColors.orange
                    : AppTheme.successGreen,
              ),
            ),
          if (AppFeatureFlags.isTakGatewayEnabled)
            IconButton(
              icon: Icon(
                connectionState == TakConnectionState.connected
                    ? Icons.link
                    : Icons.link_off,
                color: connectionState == TakConnectionState.connected
                    ? AppTheme.successGreen
                    : isSignedIn
                    ? SemanticColors.disabled
                    : SemanticColors.disabled.withValues(alpha: 0.4),
              ),
              onPressed: isSignedIn ? _toggleConnection : null,
              tooltip: !isSignedIn
                  ? context.l10n.takScreenTooltipSignInToConnect
                  : connectionState == TakConnectionState.connected
                  ? context.l10n.takScreenTooltipDisconnect
                  : context.l10n.takScreenTooltipConnect,
            ),
          IcoHelpAppBarButton(topicId: 'tak_gateway_overview'),
          AppBarOverflowMenu<String>(
            onSelected: (value) {
              switch (value) {
                case 'dashboard':
                  HapticFeedback.selectionClick();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TakDashboardScreen(),
                    ),
                  );
                case 'video':
                  HapticFeedback.selectionClick();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TakVideoStreamsScreen(),
                    ),
                  );
                case 'settings':
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TakSettingsScreen(),
                    ),
                  );
              }
            },
            itemBuilder: (context) => [
              if (AppFeatureFlags.isTakGatewayEnabled)
                PopupMenuItem(
                  value: 'dashboard',
                  child: Row(
                    children: [
                      const Icon(Icons.dashboard_outlined, size: 18),
                      const SizedBox(width: AppTheme.spacing8),
                      Text(context.l10n.takScreenOverflowDashboard),
                    ],
                  ),
                ),
              if (AppFeatureFlags.isTakVideoEnabled)
                PopupMenuItem(
                  value: 'video',
                  child: Row(
                    children: [
                      const Icon(Icons.videocam_outlined, size: 18),
                      const SizedBox(width: AppTheme.spacing8),
                      Text(context.l10n.takVideoTitle),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    const Icon(Icons.settings, size: 18),
                    const SizedBox(width: AppTheme.spacing8),
                    Text(context.l10n.takScreenOverflowSettings),
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
              if (AppFeatureFlags.isTakGatewayEnabled) ...[
                TakStatusCard(
                  connectionState: connectionState,
                  totalReceived: client.totalEventsReceived,
                  activeEntities: allEvents.length,
                  gatewayUrl: client.gatewayUrl,
                  connectedSince: client.connectedSince,
                  lastError: client.lastError,
                  onInfoTap: () => _showSectionHelp(context, 'status'),
                ),
                const SizedBox(height: AppTheme.spacing8),
                SearchFilterHeader(
                  searchController: _searchController,
                  searchQuery: filter.searchQuery,
                  onSearchChanged: (value) {
                    ref.read(takFilterProvider.notifier).setSearchQuery(value);
                  },
                  hintText: context.l10n.takScreenSearchHint,
                  filterChips: [
                    StatusFilterChip(
                      label: context.l10n.takScreenFilterAll,
                      count: allEvents.length,
                      isSelected: !filter.isActive,
                      onTap: () {
                        ref.read(takFilterProvider.notifier).clearAll();
                        _searchController.clear();
                      },
                    ),
                    for (final aff in _primaryAffiliations)
                      StatusFilterChip(
                        label: aff.displayLabel(context.l10n),
                        count: _countByAffiliation(allEvents, aff),
                        isSelected: filter.affiliations.contains(aff),
                        color: aff.color,
                        onTap: () => ref
                            .read(takFilterProvider.notifier)
                            .toggleAffiliation(aff),
                      ),
                    StatusFilterChip(
                      label: staleModeLabel,
                      count: staleModeCount,
                      isSelected: filter.staleMode != TakStaleMode.all,
                      icon: staleModeIcon,
                      onTap: () =>
                          ref.read(takFilterProvider.notifier).cycleStaleMode(),
                    ),
                  ],
                ),
              ], // end of gateway-only widgets
              if (AppFeatureFlags.isTakGatewayEnabled)
                Expanded(
                  child: filteredEvents.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: context.card,
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radius16,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.radar,
                                    size: 40,
                                    color: context.textTertiary,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spacing24),
                                Text(
                                  context.l10n.takScreenEmptyTitle,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: context.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spacing8),
                                Text(
                                  !isSignedIn
                                      ? context.l10n.takScreenEmptySignIn
                                      : connectionState ==
                                            TakConnectionState.connected
                                      ? context.l10n.takScreenEmptyListening
                                      : context.l10n.takScreenEmptyDisconnected,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: context.textTertiary,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spacing24),
                                if (!isSignedIn)
                                  FilledButton.icon(
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const AccountSubscriptionsScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.person_outline,
                                      size: 18,
                                    ),
                                    label: Text(
                                      context.l10n.takScreenButtonSignIn,
                                    ),
                                  )
                                else if (connectionState !=
                                    TakConnectionState.connected)
                                  FilledButton.icon(
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      _toggleConnection();
                                    },
                                    icon: const Icon(Icons.link, size: 18),
                                    label: Text(
                                      context.l10n.takScreenButtonConnect,
                                    ),
                                  ),
                              ],
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
                )
              else
                // Bridge-only mode: show bridge status and link to settings
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: context.card,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius16,
                              ),
                            ),
                            child: Icon(
                              Icons.cell_tower,
                              size: 40,
                              color: bridgeStatus.isRunning
                                  ? AppTheme.successGreen
                                  : context.textTertiary,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing24),
                          Text(
                            context.l10n.takScreenBridgeOnlyTitle,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: context.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing8),
                          Text(
                            bridgeStatus.isRunning
                                ? context.l10n.takBridgeStatusRunning
                                : context.l10n.takScreenBridgeOnlyDescription,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: context.textTertiary,
                              height: 1.4,
                            ),
                          ),
                          if (bridgeStatus.isRunning &&
                              bridgeStatus.connectedClientCount > 0) ...[
                            const SizedBox(height: AppTheme.spacing8),
                            Text(
                              context.l10n.takBridgeConnectedClients(
                                bridgeStatus.connectedClientCount,
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                color: AccentColors.orange,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppTheme.spacing24),
                          FilledButton.icon(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const TakSettingsScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.settings, size: 18),
                            label: Text(
                              context.l10n.takScreenBridgeOnlyOpenSettings,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
