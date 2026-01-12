import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/ico_help_system.dart';
import '../../../providers/help_providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../models/social.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/connection_providers.dart';
import '../../../providers/signal_providers.dart';
import '../../../providers/social_providers.dart';
import '../../../utils/snackbar.dart';
import '../widgets/signal_card.dart';
import '../widgets/signal_skeleton.dart';
import '../widgets/signals_empty_state.dart';
import '../widgets/active_signals_banner.dart';
import 'create_signal_screen.dart';
import 'signal_detail_screen.dart';

/// The Presence Feed screen - local view of active signals.
///
/// Signals are:
/// - Sorted by proximity (if mesh data available), then expiry, then time
/// - Filtered to only show active (non-expired) signals
/// - Updated in real-time as signals expire
class PresenceFeedScreen extends ConsumerStatefulWidget {
  const PresenceFeedScreen({super.key});

  @override
  ConsumerState<PresenceFeedScreen> createState() => _PresenceFeedScreenState();
}

class _PresenceFeedScreenState extends ConsumerState<PresenceFeedScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isRefreshing = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    // Auth gating check
    if (!ref.read(isSignedInProvider)) {
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

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(signalFeedProvider);

    // Watch providers for reactive updates
    final isSignedIn = ref.watch(isSignedInProvider);
    final isConnected = ref.watch(isDeviceConnectedProvider);
    final canGoActive = isSignedIn && isConnected;

    return HelpTourController(
      topicId: 'signals_overview',
      stepKeys: const {},
      child: Scaffold(
        backgroundColor: context.background,
        appBar: AppBar(
          backgroundColor: context.background,
          title: Row(
            children: [
              Icon(Icons.sensors, color: context.accentColor, size: 24),
              const SizedBox(width: 8),
              Text(
                'Presence',
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            // Go Active button in AppBar
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _buildGoActiveButton(canGoActive, isSignedIn, isConnected),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'help') {
                  ref.read(helpProvider.notifier).startTour('signals_overview');
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
              ],
            ),
          ],
        ),
        body: feedState.isLoading && feedState.signals.isEmpty
            ? _buildLoading()
            : feedState.signals.isEmpty
            ? _buildEmptyState()
            : _buildSignalList(feedState),
      ),
    );
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
    return const SingleChildScrollView(
      child: SignalListSkeleton(itemCount: 3),
    );
  }

  Widget _buildEmptyState() {
    // Watch providers for reactive updates
    final isSignedIn = ref.watch(isSignedInProvider);
    final isConnected = ref.watch(isDeviceConnectedProvider);
    final canGoActive = isSignedIn && isConnected;

    String? blockedReason;
    if (!isSignedIn) {
      blockedReason = 'Sign in required';
    } else if (!isConnected) {
      blockedReason = 'Device not connected';
    }

    return SignalsEmptyState(
      canGoActive: canGoActive,
      blockedReason: blockedReason,
      onGoActive: _openCreateSignal,
    );
  }

  Widget _buildSignalList(SignalFeedState feedState) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: context.accentColor,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Active count badge header with pulsing indicator
          if (feedState.signals.isNotEmpty)
            SliverToBoxAdapter(
              child: ActiveSignalsBanner(count: feedState.signals.length),
            ),
          // TTL info banner
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.fromLTRB(
                16,
                feedState.signals.isEmpty ? 16 : 8,
                16,
                16,
              ),
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
              final signal = feedState.signals[index];
              final currentUser = ref.watch(currentUserProvider);
              final isOwnSignal =
                  currentUser != null && signal.authorId == currentUser.uid;
              final canReport = currentUser != null && !isOwnSignal;
              return AnimatedSignalItem(
                key: ValueKey('animated_${signal.id}'),
                index: index,
                isRefreshing: _isRefreshing,
                child: Padding(
                  key: ValueKey(signal.id), // Use signalId as stable key
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: index == feedState.signals.length - 1 ? 100 : 12,
                  ),
                  child: SignalCard(
                    key: ValueKey('card_${signal.id}'), // Stable key for card
                    signal: signal,
                    onTap: () => _openSignalDetail(signal),
                    onComment: () => _openSignalDetail(signal),
                    onDelete: isOwnSignal ? () => _deleteSignal(signal) : null,
                    onReport: canReport ? () => _reportSignal(signal) : null,
                  ),
                ),
              );
            }, childCount: feedState.signals.length),
          ),
        ],
      ),
    );
  }

  void _openSignalDetail(Post signal) {
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
