import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../providers/social_providers.dart';
import '../../../services/content_moderation_service.dart';

/// Dialog shown when user has unacknowledged strikes.
/// User must acknowledge to continue using the app.
class StrikeAcknowledgmentDialog extends ConsumerStatefulWidget {
  final List<UserStrike> unacknowledgedStrikes;

  const StrikeAcknowledgmentDialog({
    super.key,
    required this.unacknowledgedStrikes,
  });

  /// Show the dialog and return true if user acknowledged
  static Future<bool> show(
    BuildContext context,
    List<UserStrike> strikes,
  ) async {
    if (strikes.isEmpty) return true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          StrikeAcknowledgmentDialog(unacknowledgedStrikes: strikes),
    );

    return result ?? false;
  }

  @override
  ConsumerState<StrikeAcknowledgmentDialog> createState() =>
      _StrikeAcknowledgmentDialogState();
}

class _StrikeAcknowledgmentDialogState
    extends ConsumerState<StrikeAcknowledgmentDialog> {
  bool _isAcknowledging = false;
  int _currentIndex = 0;

  UserStrike get _currentStrike => widget.unacknowledgedStrikes[_currentIndex];

  bool get _isLastStrike =>
      _currentIndex >= widget.unacknowledgedStrikes.length - 1;

  Future<void> _acknowledge() async {
    setState(() => _isAcknowledging = true);

    try {
      await ref
          .read(moderationStatusProvider.notifier)
          .acknowledgeStrike(_currentStrike.id);

      if (_isLastStrike) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _currentIndex++;
          _isAcknowledging = false;
        });
      }
    } catch (e) {
      setState(() => _isAcknowledging = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _contactSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@socialmesh.app',
      queryParameters: {
        'subject': 'Question about ${_currentStrike.typeDisplayName}',
        'body':
            'Hi,\n\nI have a question about a recent moderation action '
            'on my account.\n\nStrike ID: ${_currentStrike.id}\n'
            'Type: ${_currentStrike.typeDisplayName}\n'
            'Reason: ${_currentStrike.reason}\n\nThank you.',
      },
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalStrikes = widget.unacknowledgedStrikes.length;
    final strike = _currentStrike;

    Color typeColor;
    IconData typeIcon;

    switch (strike.type) {
      case 'strike':
        typeColor = Colors.orange;
        typeIcon = Icons.warning_amber_rounded;
      case 'suspension':
        typeColor = Colors.red;
        typeIcon = Icons.block_rounded;
      default: // warning
        typeColor = Colors.amber;
        typeIcon = Icons.info_outline;
    }

    return Dialog(
      backgroundColor: context.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress indicator for multiple strikes
            if (totalStrikes > 1) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalStrikes, (i) {
                  final isActive = i == _currentIndex;
                  final isDone = i < _currentIndex;
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? Colors.green
                          : (isActive
                                ? typeColor
                                : Colors.white.withValues(alpha: 0.2)),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Text(
                '${_currentIndex + 1} of $totalStrikes',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: typeColor.withValues(alpha: 0.15),
              ),
              child: Icon(typeIcon, size: 48, color: typeColor),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Content ${strike.typeDisplayName}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: typeColor,
              ),
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              strike.type == 'strike'
                  ? 'You have received a strike on your account due to a community guideline violation.'
                  : 'You have received a warning. Please review our community guidelines.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Reason box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: typeColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.flag_outlined,
                        size: 16,
                        color: typeColor.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Reason',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: typeColor.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strike.reason,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                  if (strike.contentType != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Content: ${strike.contentType}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Strike count warning for strikes
            if (strike.type == 'strike') ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '3 strikes result in account suspension',
                        style: TextStyle(
                          color: Colors.red.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Contact support link
            TextButton.icon(
              onPressed: _contactSupport,
              icon: Icon(
                Icons.help_outline,
                size: 18,
                color: context.accentColor.withValues(alpha: 0.8),
              ),
              label: Text(
                'Questions? Contact Support',
                style: TextStyle(
                  color: context.accentColor.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Acknowledge button
            SizedBox(
              width: double.infinity,
              child: BouncyTap(
                onTap: _isAcknowledging ? null : _acknowledge,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isAcknowledging
                          ? [Colors.grey, Colors.grey.shade700]
                          : [typeColor, typeColor.withValues(alpha: 0.8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: _isAcknowledging
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _isLastStrike ? 'I Understand' : 'Next',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
