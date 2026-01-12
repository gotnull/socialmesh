import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../models/social.dart';
import '../../../providers/signal_bookmark_provider.dart';

/// Footer widget for signal cards showing TTL countdown with urgency animation.
///
/// Features:
/// - Live countdown computed from expiresAt
/// - Orange color when < 5 minutes remaining
/// - Pulsing text animation when expiring soon
/// - Intensity increases as expiry approaches
/// - View count indicator
class SignalTTLFooter extends ConsumerStatefulWidget {
  const SignalTTLFooter({super.key, required this.signal, this.onComment});

  final Post signal;
  final VoidCallback? onComment;

  @override
  ConsumerState<SignalTTLFooter> createState() => _SignalTTLFooterState();
}

class _SignalTTLFooterState extends ConsumerState<SignalTTLFooter>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupPulseIfNeeded();
  }

  @override
  void didUpdateWidget(SignalTTLFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _setupPulseIfNeeded();
  }

  void _setupPulseIfNeeded() {
    final remaining = _remainingDuration;
    final shouldPulse =
        remaining != null && !remaining.isNegative && remaining.inMinutes < 5;

    if (shouldPulse && _pulseController == null) {
      // Start pulsing - faster as time runs out
      final pulseDuration = remaining.inMinutes < 1
          ? const Duration(milliseconds: 400)
          : const Duration(milliseconds: 800);

      _pulseController = AnimationController(
        vsync: this,
        duration: pulseDuration,
      );
      _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
      );
      _pulseController!.repeat(reverse: true);
    } else if (!shouldPulse && _pulseController != null) {
      _pulseController!.dispose();
      _pulseController = null;
      _pulseAnimation = null;
    }
  }

  Duration? get _remainingDuration {
    if (widget.signal.expiresAt == null) return null;
    return widget.signal.expiresAt!.difference(DateTime.now());
  }

  bool get _isExpiringSoon {
    final remaining = _remainingDuration;
    if (remaining == null) return false;
    return remaining.inMinutes < 5 && !remaining.isNegative;
  }

  bool get _isExpiringVerySoon {
    final remaining = _remainingDuration;
    if (remaining == null) return false;
    return remaining.inMinutes < 1 && !remaining.isNegative;
  }

  String get _expiresInText {
    final remaining = _remainingDuration;
    if (remaining == null) return '';
    if (remaining.isNegative) return 'Faded';
    if (remaining.inSeconds < 60) return 'Fades in ${remaining.inSeconds}s';
    if (remaining.inMinutes < 60) return 'Fades in ${remaining.inMinutes}m';
    if (remaining.inHours < 24) return 'Fades in ${remaining.inHours}h';
    return 'Fades in ${remaining.inDays}d';
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urgencyColor = _isExpiringVerySoon
        ? Colors.red
        : _isExpiringSoon
        ? Colors.orange
        : context.textTertiary;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // TTL indicator with urgency animation
          if (widget.signal.expiresAt != null) ...[
            _buildTTLIndicator(context, urgencyColor),
          ],

          const Spacer(),

          // View count indicator
          _ViewCountIndicator(signalId: widget.signal.id),

          const SizedBox(width: 12),

          // Reply indicator
          GestureDetector(
            onTap: widget.onComment,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 14,
                    color: widget.onComment != null
                        ? context.textSecondary
                        : context.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.signal.commentCount}',
                    style: TextStyle(
                      color: widget.onComment != null
                          ? context.textSecondary
                          : context.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTTLIndicator(BuildContext context, Color color) {
    final icon = Icon(Icons.schedule, size: 14, color: color);
    final text = Text(
      _expiresInText,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: _isExpiringSoon ? FontWeight.w600 : FontWeight.normal,
      ),
    );

    if (_pulseAnimation != null) {
      return AnimatedBuilder(
        animation: _pulseAnimation!,
        builder: (context, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(opacity: _pulseAnimation!.value, child: icon),
              const SizedBox(width: 4),
              Opacity(opacity: _pulseAnimation!.value, child: text),
            ],
          );
        },
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [icon, const SizedBox(width: 4), text],
    );
  }
}

/// Widget that displays the view count for a signal.
class _ViewCountIndicator extends ConsumerWidget {
  const _ViewCountIndicator({required this.signalId});

  final String signalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewCountAsync = ref.watch(signalViewCountProvider(signalId));

    return viewCountAsync.when(
      data: (count) {
        if (count == 0) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.visibility_outlined,
              size: 14,
              color: context.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }
}
