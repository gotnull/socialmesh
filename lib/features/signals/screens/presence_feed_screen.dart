import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../models/social.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/signal_providers.dart';
import '../widgets/signal_card.dart';
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.mediumImpact();
    await ref.read(signalFeedProvider.notifier).refresh();
  }

  void _openCreateSignal() {
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

    return Scaffold(
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
          if (feedState.signals.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${feedState.signals.length} active',
                    style: TextStyle(
                      color: context.accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: feedState.isLoading && feedState.signals.isEmpty
          ? _buildLoading()
          : feedState.signals.isEmpty
          ? _buildEmptyState()
          : _buildSignalList(feedState),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSignal,
        backgroundColor: context.accentColor,
        icon: const Icon(Icons.sensors, color: Colors.white),
        label: const Text(
          'Go active',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: context.accentColor, strokeWidth: 2),
          const SizedBox(height: 16),
          Text(
            'Scanning for active signals...',
            style: TextStyle(color: context.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.card,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.sensors_off,
                size: 48,
                color: context.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No active signals nearby',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nothing active here right now.\nWhen someone nearby goes active, it will appear here.',
              style: TextStyle(color: context.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            BouncyTap(
              onTap: _openCreateSignal,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradientHorizontal,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sensors, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Go active',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
          // TTL info banner
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
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
              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: index == feedState.signals.length - 1 ? 100 : 12,
                ),
                child: SignalCard(
                  signal: signal,
                  onTap: () => _openSignalDetail(signal),
                  onComment: () => _openSignalDetail(signal),
                  onDelete: isOwnSignal ? () => _deleteSignal(signal) : null,
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
}
