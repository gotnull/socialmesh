import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/ico_help_system.dart';
import '../../../core/widgets/edge_fade.dart';
import '../../../providers/help_providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../models/social.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/connection_providers.dart';
import '../../../providers/signal_bookmark_provider.dart';
import '../../../providers/signal_providers.dart';
import '../../../providers/social_providers.dart';
import '../../../utils/snackbar.dart';
import '../../navigation/main_shell.dart';
import '../../settings/settings_screen.dart';
import '../widgets/double_tap_heart.dart';
import '../widgets/signal_card.dart';
import '../widgets/signal_grid_card.dart';
import '../widgets/signal_gallery_view.dart';
import '../widgets/signal_map_view.dart';
import '../widgets/signal_skeleton.dart';
import '../widgets/signals_empty_state.dart';
import '../widgets/swipeable_signal_item.dart';
import '../widgets/active_signals_banner.dart';
import 'create_signal_screen.dart';
import 'signal_detail_screen.dart';

/// Filter options for the signals list
enum SignalFilter {
  all,
  saved, // bookmarked signals
  nearby, // hop count 0-1
  meshOnly, // from mesh (authorId starts with mesh_)
  withMedia, // has images
  expiringSoon, // < 5 minutes TTL remaining
}

/// Sort options for the signals list
enum SignalSortOrder {
  proximity, // by hop count (closer first)
  expiring, // by TTL (expiring soon first)
  newest, // by creation time (newest first)
}

/// The Presence Feed screen - local view of active signals.
///
/// Signals are:
/// - Sorted by proximity (if mesh data available), then expiry, then time
/// - Filtered to only show active (non-expired) signals
/// - Updated in real-time as signals expire
/// - Viewable in list or compact grid mode
class PresenceFeedScreen extends ConsumerStatefulWidget {
  const PresenceFeedScreen({super.key});

  @override
  ConsumerState<PresenceFeedScreen> createState() => _PresenceFeedScreenState();
}

class _PresenceFeedScreenState extends ConsumerState<PresenceFeedScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool _isRefreshing = false;
  String _searchQuery = '';
  SignalFilter _activeFilter = SignalFilter.all;
  SignalSortOrder _sortOrder = SignalSortOrder.newest;

  // Sticky header state
  bool _showStickyHeader = false;
  static const double _stickyThreshold = 100.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final shouldShow = _scrollController.offset > _stickyThreshold;
    if (shouldShow != _showStickyHeader) {
      setState(() => _showStickyHeader = shouldShow);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.mediumImpact();

    // Start refresh animation
    setState(() => _isRefreshing = true);

    // Small delay to let the slide-out animation start
    await Future<void>.delayed(const Duration(milliseconds: 100));

    await ref.read(signalFeedProvider.notifier).refresh();

    // End refresh animation (triggers slide-back-in)
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  void _openCreateSignal() {
    // Auth gating check - use authStateProvider.value directly
    final authState = ref.read(authStateProvider);
    if (authState.value == null) {
      AppLogging.signals('🔒 Go Active blocked: user not authenticated');
      showErrorSnackBar(context, 'Sign in required to go active');
      return;
    }

    // Connection gating check
    if (!ref.read(isDeviceConnectedProvider)) {
      AppLogging.signals('🚫 Go Active blocked: device not connected');
      showErrorSnackBar(context, 'Connect to a device to go active');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const CreateSignalScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  List<Post> _applyFilter(List<Post> signals) {
    // First filter out hidden signals (unless viewing saved)
    final hiddenIds = ref.read(hiddenSignalsProvider);
    final bookmarkedIds = ref.read(signalBookmarksProvider).value ?? {};

    // Don't filter hidden from saved view
    if (_activeFilter != SignalFilter.saved) {
      signals = signals.where((s) => !hiddenIds.contains(s.id)).toList();
    }

    switch (_activeFilter) {
      case SignalFilter.all:
        return signals;
      case SignalFilter.saved:
        return signals.where((s) => bookmarkedIds.contains(s.id)).toList();
      case SignalFilter.nearby:
        return signals
            .where((s) => s.hopCount != null && s.hopCount! <= 1)
            .toList();
      case SignalFilter.meshOnly:
        return signals.where((s) => s.authorId.startsWith('mesh_')).toList();
      case SignalFilter.withMedia:
        return signals
            .where((s) => s.mediaUrls.isNotEmpty || s.imageLocalPath != null)
            .toList();
      case SignalFilter.expiringSoon:
        return signals.where((s) {
          if (s.expiresAt == null) return false;
          final remaining = s.expiresAt!.difference(DateTime.now());
          return remaining.inMinutes < 5 && !remaining.isNegative;
        }).toList();
    }
  }

  List<Post> _applySort(List<Post> signals) {
    final sorted = List<Post>.from(signals);
    switch (_sortOrder) {
      case SignalSortOrder.proximity:
        sorted.sort((a, b) {
          // Primary: hop count (closer first, null = furthest)
          final aHop = a.hopCount ?? 999;
          final bHop = b.hopCount ?? 999;
          if (aHop != bHop) return aHop.compareTo(bHop);
          // Secondary: newest first
          return b.createdAt.compareTo(a.createdAt);
        });
      case SignalSortOrder.expiring:
        sorted.sort((a, b) {
          // Primary: expiry time (expiring soon first, null = last)
          if (a.expiresAt == null && b.expiresAt == null) {
            return b.createdAt.compareTo(a.createdAt);
          }
          if (a.expiresAt == null) return 1;
          if (b.expiresAt == null) return -1;
          final expiryCompare = a.expiresAt!.compareTo(b.expiresAt!);
          if (expiryCompare != 0) return expiryCompare;
          // Secondary: newest first
          return b.createdAt.compareTo(a.createdAt);
        });
      case SignalSortOrder.newest:
        sorted.sort((a, b) {
          // Primary: newest first
          final dateCompare = b.createdAt.compareTo(a.createdAt);
          if (dateCompare != 0) return dateCompare;
          // Secondary: closer signals first (lower hop count)
          final aHop = a.hopCount ?? 999;
          final bHop = b.hopCount ?? 999;
          return aHop.compareTo(bHop);
        });
    }
    return sorted;
  }

  List<Post> _applySearch(List<Post> signals) {
    if (_searchQuery.isEmpty) return signals;
    final query = _searchQuery.toLowerCase();
    return signals.where((s) {
      // Search in content
      if (s.content.toLowerCase().contains(query)) return true;
      // Search in author name
      if (s.authorSnapshot?.displayName.toLowerCase().contains(query) == true) {
        return true;
      }
      // Search in mesh node ID (hex)
      if (s.meshNodeId != null &&
          s.meshNodeId!.toRadixString(16).toLowerCase().contains(query)) {
        return true;
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(signalFeedProvider);

    // Watch auth state directly to properly handle async loading
    final authState = ref.watch(authStateProvider);
    final isSignedIn = authState.value != null;
    final isConnected = ref.watch(isDeviceConnectedProvider);
    final canGoActive = isSignedIn && isConnected;

    // Watch bookmarks for saved count
    final bookmarkedIds = ref.watch(signalBookmarksProvider).value ?? {};

    // Get all signals then apply filters
    var signals = feedState.signals;

    // Calculate counts before filtering for badges
    final allCount = signals.length;
    final savedCount = signals
        .where((s) => bookmarkedIds.contains(s.id))
        .length;
    final nearbyCount = signals
        .where((s) => s.hopCount != null && s.hopCount! <= 1)
        .length;
    final meshCount = signals
        .where((s) => s.authorId.startsWith('mesh_'))
        .length;
    final mediaCount = signals
        .where((s) => s.mediaUrls.isNotEmpty || s.imageLocalPath != null)
        .length;
    final expiringSoonCount = signals.where((s) {
      if (s.expiresAt == null) return false;
      final remaining = s.expiresAt!.difference(DateTime.now());
      return remaining.inMinutes < 5 && !remaining.isNegative;
    }).length;

    // Apply filter, sort, and search
    signals = _applyFilter(signals);
    signals = _applySort(signals);
    signals = _applySearch(signals);

    // Extract unique active authors for sticky header (most recent first)
    final activeAuthors = _getUniqueAuthors(feedState.signals);

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: HelpTourController(
        topicId: 'signals_overview',
        stepKeys: const {},
        child: Scaffold(
          backgroundColor: context.background,
          appBar: AppBar(
            backgroundColor: context.background,
            leading: const HamburgerMenuButton(),
            centerTitle: true,
            title: Text(
              'Presence${allCount > 0 ? ' ($allCount)' : ''}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            actions: [
              // Go Active button
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _buildGoActiveButton(
                  canGoActive,
                  isSignedIn,
                  isConnected,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'help') {
                    ref
                        .read(helpProvider.notifier)
                        .startTour('signals_overview');
                  } else if (value == 'settings') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'help',
                    child: ListTile(
                      leading: Icon(Icons.help_outline),
                      title: Text('Help'),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.settings_outlined),
                      title: Text('Settings'),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: TextStyle(color: context.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search signals',
                      hintStyle: TextStyle(color: context.textTertiary),
                      prefixIcon: Icon(
                        Icons.search,
                        color: context.textTertiary,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: context.textTertiary,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),

              // Filter chips row with view toggle at end
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    // Scrollable filter chips and sort button
                    Expanded(
                      child: EdgeFade.end(
                        fadeSize: 32,
                        fadeColor: context.background,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(left: 16),
                          children: [
                            _FilterChip(
                              label: 'All',
                              count: allCount,
                              isSelected: _activeFilter == SignalFilter.all,
                              onTap: () => setState(
                                () => _activeFilter = SignalFilter.all,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Saved',
                              count: savedCount,
                              isSelected: _activeFilter == SignalFilter.saved,
                              color: AccentColors.yellow,
                              icon: Icons.bookmark_rounded,
                              onTap: () => setState(
                                () => _activeFilter = SignalFilter.saved,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Nearby',
                              count: nearbyCount,
                              isSelected: _activeFilter == SignalFilter.nearby,
                              color: AccentColors.green,
                              icon: Icons.near_me,
                              onTap: () => setState(
                                () => _activeFilter = SignalFilter.nearby,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Mesh',
                              count: meshCount,
                              isSelected:
                                  _activeFilter == SignalFilter.meshOnly,
                              color: AccentColors.cyan,
                              icon: Icons.router,
                              onTap: () => setState(
                                () => _activeFilter = SignalFilter.meshOnly,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Media',
                              count: mediaCount,
                              isSelected:
                                  _activeFilter == SignalFilter.withMedia,
                              color: AccentColors.purple,
                              icon: Icons.image,
                              onTap: () => setState(
                                () => _activeFilter = SignalFilter.withMedia,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Expiring',
                              count: expiringSoonCount,
                              isSelected:
                                  _activeFilter == SignalFilter.expiringSoon,
                              color: AppTheme.warningYellow,
                              icon: Icons.schedule,
                              onTap: () => setState(
                                () => _activeFilter = SignalFilter.expiringSoon,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _SortButton(
                              sortOrder: _sortOrder,
                              onChanged: (order) =>
                                  setState(() => _sortOrder = order),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
                    // View toggle at end
                    const SizedBox(width: 8),
                    _ViewModeSelector(
                      viewMode: ref.watch(signalViewModeProvider),
                      onModeChanged: (mode) => ref
                          .read(signalViewModeProvider.notifier)
                          .setMode(mode),
                    ),
                    // Gallery button (only visible when media signals exist)
                    if (mediaCount > 0) ...[
                      const SizedBox(width: 8),
                      _GalleryButton(
                        onTap: () =>
                            SignalGalleryView.show(context, signals: signals),
                      ),
                    ],
                    const SizedBox(width: 12),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Divider
              Container(
                height: 1,
                color: context.border.withValues(alpha: 0.3),
              ),

              // Signal list/grid/map based on view mode with sticky header overlay
              Expanded(
                child: Stack(
                  children: [
                    // Content
                    feedState.isLoading && feedState.signals.isEmpty
                        ? _buildLoading()
                        : signals.isEmpty
                            ? _buildEmptyState()
                            : _buildSignalView(
                                signals,
                                ref.watch(signalViewModeProvider),
                              ),

                    // Sticky header overlay with overlapping author avatars
                    if (activeAuthors.isNotEmpty)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _ActiveAuthorsHeader(
                          authors: activeAuthors,
                          signalCount: feedState.signals.length,
                          isVisible: _showStickyHeader,
                          onTap: _scrollToTop,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// Extract unique authors from signals, sorted by most recent signal first.
  List<_AuthorInfo> _getUniqueAuthors(List<Post> signals) {
    final Map<String, _AuthorInfo> authorMap = {};

    for (final signal in signals) {
      if (!authorMap.containsKey(signal.authorId)) {
        authorMap[signal.authorId] = _AuthorInfo(
          authorId: signal.authorId,
          displayName: signal.authorSnapshot?.displayName ?? 'Anonymous',
          avatarUrl: signal.authorSnapshot?.avatarUrl,
          meshNodeId: signal.meshNodeId,
          signalCount: 1,
          mostRecentSignal: signal.createdAt,
        );
      } else {
        final existing = authorMap[signal.authorId]!;
        authorMap[signal.authorId] = existing.copyWith(
          signalCount: existing.signalCount + 1,
          mostRecentSignal: signal.createdAt.isAfter(existing.mostRecentSignal)
              ? signal.createdAt
              : existing.mostRecentSignal,
        );
      }
    }

    // Sort by most recent signal
    final authors = authorMap.values.toList()
      ..sort((a, b) => b.mostRecentSignal.compareTo(a.mostRecentSignal));

    return authors;
  }

  Widget _buildSignalView(List<Post> signals, SignalViewMode viewMode) {
    switch (viewMode) {
      case SignalViewMode.list:
        return _buildSignalList(signals);
      case SignalViewMode.grid:
        return _buildSignalGrid(signals);
      case SignalViewMode.gallery:
        // Gallery is shown via overlay, just show list
        return _buildSignalList(signals);
      case SignalViewMode.map:
        return _buildSignalMap(signals);
    }
  }

  Widget _buildGoActiveButton(
    bool canGoActive,
    bool isSignedIn,
    bool isConnected,
  ) {
    String? blockedReason;
    if (!isSignedIn) {
      blockedReason = 'Sign in required';
    } else if (!isConnected) {
      blockedReason = 'Device not connected';
    }

    final accentColor = context.accentColor;
    final gradient = LinearGradient(
      colors: [accentColor, Color.lerp(accentColor, Colors.white, 0.2)!],
    );

    return Tooltip(
      message: blockedReason ?? 'Broadcast your presence',
      child: BouncyTap(
        onTap: _openCreateSignal,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: canGoActive ? gradient : null,
            color: canGoActive ? null : context.border.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            Icons.sensors,
            size: 20,
            color: canGoActive ? Colors.white : context.textTertiary,
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const SingleChildScrollView(child: SignalListSkeleton(itemCount: 3));
  }

  Widget _buildEmptyState() {
    // Watch auth state directly to properly handle async loading
    final authState = ref.watch(authStateProvider);
    final isSignedIn = authState.value != null;
    final isConnected = ref.watch(isDeviceConnectedProvider);
    final canGoActive = isSignedIn && isConnected;

    String? blockedReason;
    if (!isSignedIn) {
      blockedReason = 'Sign in required';
    } else if (!isConnected) {
      blockedReason = 'Device not connected';
    }

    // Show different empty state if filtering
    if (_activeFilter != SignalFilter.all || _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.filter_list_off,
                size: 40,
                color: context.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No signals match this filter',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() {
                _activeFilter = SignalFilter.all;
                _searchQuery = '';
                _searchController.clear();
              }),
              child: const Text('Show all signals'),
            ),
          ],
        ),
      );
    }

    return SignalsEmptyState(
      canGoActive: canGoActive,
      blockedReason: blockedReason,
      onGoActive: _openCreateSignal,
    );
  }

  Widget _buildSignalList(List<Post> signals) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: context.accentColor,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Active count badge header
          if (signals.isNotEmpty)
            SliverToBoxAdapter(
              child: ActiveSignalsBanner(count: signals.length),
            ),
          // TTL info banner
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.fromLTRB(16, signals.isEmpty ? 16 : 8, 16, 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.border.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 18, color: context.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Signals fade automatically. Only what\'s still active can be seen.',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Signal list
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final signal = signals[index];
              final currentUser = ref.watch(currentUserProvider);
              final isOwnSignal =
                  currentUser != null && signal.authorId == currentUser.uid;
              final canReport = currentUser != null && !isOwnSignal;
              final isBookmarked = ref.watch(
                isSignalBookmarkedProvider(signal.id),
              );
              final hasRecentActivity =
                  signal.commentCount > 0 &&
                  DateTime.now().difference(signal.createdAt).inMinutes < 10;

              return AnimatedSignalItem(
                key: ValueKey('animated_${signal.id}'),
                index: index,
                isRefreshing: _isRefreshing,
                child: Padding(
                  key: ValueKey(signal.id),
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: index == signals.length - 1 ? 100 : 12,
                  ),
                  child: SwipeableSignalItem(
                    isBookmarked: isBookmarked,
                    onSwipeRight: () {
                      ref
                          .read(signalBookmarksProvider.notifier)
                          .toggleBookmark(signal.id);
                      showSuccessSnackBar(
                        context,
                        isBookmarked ? 'Removed from saved' : 'Signal saved',
                      );
                    },
                    onSwipeLeft: () {
                      ref
                          .read(hiddenSignalsProvider.notifier)
                          .hideSignal(signal.id);
                      showSuccessSnackBar(context, 'Signal hidden');
                    },
                    child: DoubleTapLikeWrapper(
                      onDoubleTap: () {
                        HapticFeedback.mediumImpact();
                        ref
                            .read(signalBookmarksProvider.notifier)
                            .addBookmark(signal.id);
                        showSuccessSnackBar(context, 'Signal saved');
                      },
                      child: SignalCard(
                        key: ValueKey('card_${signal.id}'),
                        signal: signal,
                        isBookmarked: isBookmarked,
                        isLive: hasRecentActivity,
                        onTap: () => _openSignalDetail(signal),
                        onComment: () => _openSignalDetail(signal),
                        onDelete: isOwnSignal
                            ? () => _deleteSignal(signal)
                            : null,
                        onReport: canReport
                            ? () => _reportSignal(signal)
                            : null,
                      ),
                    ),
                  ),
                ),
              );
            }, childCount: signals.length),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalGrid(List<Post> signals) {
    final user = ref.watch(currentUserProvider);
    final bookmarkedIds = ref.watch(signalBookmarksProvider).value ?? {};

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: context.accentColor,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Active count badge header
          if (signals.isNotEmpty)
            SliverToBoxAdapter(
              child: ActiveSignalsBanner(count: signals.length),
            ),

          // Grid of signals
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final signal = signals[index];
                final isBookmarked = bookmarkedIds.contains(signal.id);
                final isOwn = user?.uid == signal.authorId;

                return AnimatedGridItem(
                  key: ValueKey('animated_grid_${signal.id}'),
                  index: index,
                  isRefreshing: _isRefreshing,
                  child: DoubleTapLikeWrapper(
                    onDoubleTap: () async {
                      HapticFeedback.mediumImpact();
                      if (isOwn) return; // Can't bookmark own signal

                      if (!isBookmarked) {
                        await ref
                            .read(signalBookmarksProvider.notifier)
                            .addBookmark(signal.id);
                      }
                    },
                    child: Stack(
                      children: [
                        SignalGridCard(
                          key: ValueKey('grid_${signal.id}'),
                          signal: signal,
                          onTap: () => _openSignalDetail(signal),
                        ),
                        // Bookmark indicator - top left with matching badge style
                        if (isBookmarked)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  width: 0.5,
                                ),
                              ),
                              child: Icon(
                                Icons.bookmark_rounded,
                                size: 12,
                                color: AccentColors.yellow,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }, childCount: signals.length),
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildSignalMap(List<Post> signals) {
    return SignalMapView(signals: signals, onSignalTap: _openSignalDetail);
  }

  void _openSignalDetail(Post signal) {
    // Record view for stats
    final user = ref.read(currentUserProvider);
    if (user != null && signal.authorId != user.uid) {
      recordSignalView(signal.id, user.uid);
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SignalDetailScreen(signal: signal),
      ),
    );
  }

  Future<void> _deleteSignal(Post signal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.card,
        title: Text(
          'Delete Signal?',
          style: TextStyle(color: context.textPrimary),
        ),
        content: Text(
          'This signal will fade immediately.',
          style: TextStyle(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(signalFeedProvider.notifier).deleteSignal(signal.id);
    }
  }

  Future<void> _reportSignal(Post signal) async {
    final reason = await AppBottomSheet.showActions<String>(
      context: context,
      header: Text(
        'Why are you reporting this signal?',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: context.textPrimary,
        ),
      ),
      actions: [
        BottomSheetAction(
          icon: Icons.warning_outlined,
          label: 'Spam or misleading',
          value: 'spam',
        ),
        BottomSheetAction(
          icon: Icons.person_off_outlined,
          label: 'Harassment or bullying',
          value: 'harassment',
        ),
        BottomSheetAction(
          icon: Icons.dangerous_outlined,
          label: 'Violence or dangerous content',
          value: 'violence',
        ),
        BottomSheetAction(
          icon: Icons.no_adult_content,
          label: 'Nudity or sexual content',
          value: 'nudity',
        ),
        BottomSheetAction(
          icon: Icons.copyright,
          label: 'Copyright violation',
          value: 'copyright',
        ),
        BottomSheetAction(
          icon: Icons.more_horiz,
          label: 'Other',
          value: 'other',
        ),
      ],
    );

    if (reason != null && mounted) {
      try {
        final socialService = ref.read(socialServiceProvider);
        await socialService.reportSignal(
          signalId: signal.id,
          reason: reason,
          authorId: signal.authorId,
          content: signal.content,
          imageUrl: signal.mediaUrls.isNotEmpty ? signal.mediaUrls.first : null,
        );
        if (mounted) {
          showSuccessSnackBar(context, 'Report submitted. Thank you.');
        }
      } catch (e) {
        if (mounted) {
          showErrorSnackBar(context, 'Failed to report: $e');
        }
      }
    }
  }
}

/// Filter chip widget (styled consistently with nodes screen)
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.color,
    this.icon,
  });

  final String label;
  final int count;
  final bool isSelected;
  final Color? color;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppTheme.primaryBlue;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withValues(alpha: 0.2) : context.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? chipColor.withValues(alpha: 0.5)
                : context.border.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? chipColor : context.textTertiary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? chipColor : context.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? chipColor.withValues(alpha: 0.3)
                    : context.border.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? chipColor : context.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sort button with dropdown
class _SortButton extends StatelessWidget {
  const _SortButton({required this.sortOrder, required this.onChanged});

  final SignalSortOrder sortOrder;
  final ValueChanged<SignalSortOrder> onChanged;

  String get _sortLabel {
    switch (sortOrder) {
      case SignalSortOrder.proximity:
        return 'Closest';
      case SignalSortOrder.expiring:
        return 'Expiring';
      case SignalSortOrder.newest:
        return 'Newest';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: context.card,
        child: InkWell(
          onTap: () => _showSortMenu(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.border.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sort, size: 14, color: context.textTertiary),
                const SizedBox(width: 4),
                Text(
                  _sortLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: context.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSortMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject()! as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final Offset offset = button.localToGlobal(
      Offset(0, button.size.height + 4),
      ancestor: overlay,
    );

    showMenu<SignalSortOrder>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy,
        overlay.size.width - offset.dx - button.size.width,
        0,
      ),
      color: context.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        _buildMenuItem(
          SignalSortOrder.proximity,
          'By Proximity',
          Icons.near_me,
          context,
        ),
        _buildMenuItem(
          SignalSortOrder.expiring,
          'Expiring Soon',
          Icons.schedule,
          context,
        ),
        _buildMenuItem(
          SignalSortOrder.newest,
          'Most Recent',
          Icons.schedule,
          context,
        ),
      ],
    ).then((value) {
      if (value != null) {
        onChanged(value);
      }
    });
  }

  PopupMenuItem<SignalSortOrder> _buildMenuItem(
    SignalSortOrder value,
    String label,
    IconData icon,
    BuildContext context,
  ) {
    final isSelected = sortOrder == value;
    final accentColor = context.accentColor;
    return PopupMenuItem<SignalSortOrder>(
      value: value,
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.check : icon,
            size: 18,
            color: isSelected ? accentColor : context.textSecondary,
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}

/// View mode toggle button
/// View mode selector supporting list, grid, and map
class _ViewModeSelector extends StatelessWidget {
  const _ViewModeSelector({
    required this.viewMode,
    required this.onModeChanged,
  });

  final SignalViewMode viewMode;
  final void Function(SignalViewMode) onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ViewModeButton(
          icon: Icons.view_list_rounded,
          isSelected: viewMode == SignalViewMode.list,
          onTap: () => onModeChanged(SignalViewMode.list),
          tooltip: 'List view',
        ),
        const SizedBox(width: 4),
        _ViewModeButton(
          icon: Icons.grid_view_rounded,
          isSelected: viewMode == SignalViewMode.grid,
          onTap: () => onModeChanged(SignalViewMode.grid),
          tooltip: 'Grid view',
        ),
        const SizedBox(width: 4),
        _ViewModeButton(
          icon: Icons.map_outlined,
          isSelected: viewMode == SignalViewMode.map,
          onTap: () => onModeChanged(SignalViewMode.map),
          tooltip: 'Map view',
        ),
      ],
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  const _ViewModeButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isSelected
                ? context.accentColor.withValues(alpha: 0.2)
                : context.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? context.accentColor.withValues(alpha: 0.5)
                  : context.border.withValues(alpha: 0.3),
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isSelected ? context.accentColor : context.textTertiary,
          ),
        ),
      ),
    );
  }
}

/// Gallery view button with media count badge
class _GalleryButton extends StatelessWidget {
  const _GalleryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'View gallery',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AccentColors.purple.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AccentColors.purple.withValues(alpha: 0.4),
            ),
          ),
          child: Icon(
            Icons.photo_library_outlined,
            size: 16,
            color: AccentColors.purple,
          ),
        ),
      ),
    );
  }
}

/// Animated item wrapper for stagger animations
class AnimatedSignalItem extends StatefulWidget {
  const AnimatedSignalItem({
    super.key,
    required this.child,
    required this.index,
    required this.isRefreshing,
  });

  final Widget child;
  final int index;
  final bool isRefreshing;

  @override
  State<AnimatedSignalItem> createState() => _AnimatedSignalItemState();
}

class _AnimatedSignalItemState extends State<AnimatedSignalItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Stagger animation based on index
    Future<void>.delayed(Duration(milliseconds: 50 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void didUpdateWidget(AnimatedSignalItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isRefreshing && !oldWidget.isRefreshing) {
      // Slide out when refreshing
      _controller.reverse();
    } else if (!widget.isRefreshing && oldWidget.isRefreshing) {
      // Slide back in after refresh
      Future<void>.delayed(Duration(milliseconds: 50 * widget.index), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(opacity: _fadeAnimation, child: widget.child),
    );
  }
}

/// Animated wrapper for grid items with scale and fade animations
class AnimatedGridItem extends StatefulWidget {
  const AnimatedGridItem({
    super.key,
    required this.child,
    required this.index,
    required this.isRefreshing,
  });

  final Widget child;
  final int index;
  final bool isRefreshing;

  @override
  State<AnimatedGridItem> createState() => _AnimatedGridItemState();
}

class _AnimatedGridItemState extends State<AnimatedGridItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Staggered animation - grid alternates for visual interest
    final row = widget.index ~/ 2;
    final col = widget.index % 2;
    final delay = (row * 60) + (col * 30);
    Future<void>.delayed(Duration(milliseconds: delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void didUpdateWidget(AnimatedGridItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isRefreshing && !oldWidget.isRefreshing) {
      _controller.reverse();
    } else if (!widget.isRefreshing && oldWidget.isRefreshing) {
      final row = widget.index ~/ 2;
      final col = widget.index % 2;
      final delay = (row * 60) + (col * 30);
      Future<void>.delayed(Duration(milliseconds: delay), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(opacity: _fadeAnimation, child: widget.child),
    );
  }
}

/// Author info for the sticky header
class _AuthorInfo {
  final String authorId;
  final String displayName;
  final String? avatarUrl;
  final int? meshNodeId;
  final int signalCount;
  final DateTime mostRecentSignal;

  const _AuthorInfo({
    required this.authorId,
    required this.displayName,
    this.avatarUrl,
    this.meshNodeId,
    required this.signalCount,
    required this.mostRecentSignal,
  });

  _AuthorInfo copyWith({
    String? authorId,
    String? displayName,
    String? avatarUrl,
    int? meshNodeId,
    int? signalCount,
    DateTime? mostRecentSignal,
  }) {
    return _AuthorInfo(
      authorId: authorId ?? this.authorId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      meshNodeId: meshNodeId ?? this.meshNodeId,
      signalCount: signalCount ?? this.signalCount,
      mostRecentSignal: mostRecentSignal ?? this.mostRecentSignal,
    );
  }
}

/// Instagram-style sticky header with overlapping author avatars
class _ActiveAuthorsHeader extends StatefulWidget {
  const _ActiveAuthorsHeader({
    required this.authors,
    required this.signalCount,
    required this.isVisible,
    this.onTap,
  });

  final List<_AuthorInfo> authors;
  final int signalCount;
  final bool isVisible;
  final VoidCallback? onTap;

  @override
  State<_ActiveAuthorsHeader> createState() => _ActiveAuthorsHeaderState();
}

class _ActiveAuthorsHeaderState extends State<_ActiveAuthorsHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    if (widget.isVisible) {
      _slideController.forward();
    }
  }

  @override
  void didUpdateWidget(_ActiveAuthorsHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _slideController.forward();
      } else {
        _slideController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;
    final maxAvatars = 5;
    final displayAuthors = widget.authors.take(maxAvatars).toList();
    final remainingCount = widget.authors.length - maxAvatars;

    return IgnorePointer(
      ignoring: !widget.isVisible,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: GestureDetector(
                onTap: widget.onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: context.card.withValues(alpha: 0.7),
                    border: Border(
                      bottom: BorderSide(
                        color: accentColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                child: Row(
                  children: [
                    // Overlapping avatars (Instagram-style)
                    SizedBox(
                      height: 36,
                      width: 36.0 + (displayAuthors.length - 1) * 20.0,
                      child: Stack(
                        children: [
                          for (var i = displayAuthors.length - 1; i >= 0; i--)
                            Positioned(
                              left: i * 20.0,
                              child: _AuthorAvatar(
                                author: displayAuthors[i],
                                size: 36,
                                borderColor: context.card,
                                accentColor: accentColor,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Extra count badge
                    if (remainingCount > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.surface,
                          border: Border.all(color: context.card, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            '+$remainingCount',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(width: 12),

                    // Text info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${widget.authors.length} ${widget.authors.length == 1 ? "person" : "people"} active',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${widget.signalCount} ${widget.signalCount == 1 ? "signal" : "signals"} nearby',
                            style: TextStyle(
                              color: context.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Scroll to top indicator
                    Icon(
                      Icons.keyboard_arrow_up,
                      color: context.textTertiary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}

/// Individual author avatar with glow effect
class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({
    required this.author,
    required this.size,
    required this.borderColor,
    required this.accentColor,
  });

  final _AuthorInfo author;
  final double size;
  final Color borderColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final isMeshNode = author.authorId.startsWith('mesh_');

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.3),
            blurRadius: 4,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipOval(
        child: author.avatarUrl != null
            ? Image.network(
                author.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _buildPlaceholder(context, isMeshNode),
              )
            : _buildPlaceholder(context, isMeshNode),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context, bool isMeshNode) {
    // Generate color from author ID
    final hash = author.authorId.hashCode;
    final hue = (hash % 360).toDouble();
    final color = HSLColor.fromAHSL(1, hue, 0.6, 0.4).toColor();

    return Container(
      color: color,
      child: Center(
        child: isMeshNode
            ? Icon(
                Icons.router,
                color: Colors.white.withValues(alpha: 0.9),
                size: size * 0.5,
              )
            : Text(
                author.displayName.isNotEmpty
                    ? author.displayName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
