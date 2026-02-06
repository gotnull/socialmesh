// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../providers/signal_providers.dart';
import '../../../services/signal_service.dart';
import 'ttl_selector.dart';

/// Inline signal composer widget (for embedding in other screens).
class SignalComposer extends ConsumerStatefulWidget {
  const SignalComposer({super.key, this.onSignalCreated, this.compact = false});

  final VoidCallback? onSignalCreated;
  final bool compact;

  @override
  ConsumerState<SignalComposer> createState() => _SignalComposerState();
}

class _SignalComposerState extends ConsumerState<SignalComposer>
    with LifecycleSafeMixin {
  final TextEditingController _controller = TextEditingController();
  int _ttlMinutes = SignalTTL.defaultTTL;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _controller.text.trim().isNotEmpty &&
      _controller.text.length <= 280 &&
      !_isSubmitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;

    safeSetState(() => _isSubmitting = true);

    try {
      final notifier = ref.read(signalFeedProvider.notifier);
      await notifier.createSignal(
        content: _controller.text.trim(),
        ttlMinutes: _ttlMinutes,
      );

      _controller.clear();
      widget.onSignalCreated?.call();
    } finally {
      safeSetState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompact(context);
    }
    return _buildFull(context);
  }

  Widget _buildCompact(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !_isSubmitting,
              style: TextStyle(color: context.textPrimary),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Send a signal...',
                hintStyle: TextStyle(color: context.textTertiary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _canSubmit ? _submit : null,
            icon: _isSubmitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.accentColor,
                    ),
                  )
                : Icon(
                    Icons.sensors,
                    color: _canSubmit
                        ? context.accentColor
                        : context.textTertiary,
                  ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildFull(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input
          TextField(
            controller: _controller,
            enabled: !_isSubmitting,
            maxLines: 3,
            maxLength: 280,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(280)],
            style: TextStyle(color: context.textPrimary),
            decoration: InputDecoration(
              hintText: 'What are you signaling?',
              hintStyle: TextStyle(color: context.textTertiary),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              counterText: '',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // TTL selector
          Text(
            'Fades in',
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TTLSelector(
            selectedMinutes: _ttlMinutes,
            onChanged: _isSubmitting
                ? null
                : (minutes) => setState(() => _ttlMinutes = minutes),
          ),
          const SizedBox(height: 16),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accentColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: context.border.withValues(alpha: 0.3),
                disabledForegroundColor: context.textTertiary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sensors, size: 18),
              label: Text(_isSubmitting ? 'Sending...' : 'Send signal'),
            ),
          ),
        ],
      ),
    );
  }
}
