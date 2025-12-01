import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../providers/app_providers.dart';
import '../../../core/transport.dart';

/// Quick Actions Widget - Common mesh actions at a glance
class QuickActionsContent extends ConsumerWidget {
  const QuickActionsContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStateAsync = ref.watch(connectionStateProvider);
    final isConnected = connectionStateAsync.maybeWhen(
      data: (state) => state == DeviceConnectionState.connected,
      orElse: () => false,
    );

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _ActionButton(
            icon: Icons.send,
            label: 'Quick\nMessage',
            enabled: isConnected,
            onTap: () => _sendQuickMessage(context),
          ),
          _ActionButton(
            icon: Icons.location_on,
            label: 'Share\nLocation',
            enabled: isConnected,
            onTap: () => _shareLocation(context, ref),
          ),
          _ActionButton(
            icon: Icons.notifications,
            label: 'Traceroute',
            enabled: isConnected,
            onTap: () => _sendTraceroute(context),
          ),
          _ActionButton(
            icon: Icons.refresh,
            label: 'Request\nPositions',
            enabled: isConnected,
            onTap: () => _requestPositions(context, ref),
          ),
        ],
      ),
    );
  }

  void _sendQuickMessage(BuildContext context) {
    _showQuickMessageDialog(context);
  }

  void _shareLocation(BuildContext context, WidgetRef ref) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sharing current location...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _sendTraceroute(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Select a node for traceroute'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _requestPositions(BuildContext context, WidgetRef ref) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Requesting positions from nearby nodes...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showQuickMessageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _QuickMessageDialog(),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppTheme.primaryGreen : AppTheme.textTertiary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: enabled
                ? AppTheme.primaryGreen.withValues(alpha: 0.08)
                : AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled
                  ? AppTheme.primaryGreen.withValues(alpha: 0.2)
                  : AppTheme.darkBorder,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontFamily: 'Inter',
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickMessageDialog extends StatefulWidget {
  const _QuickMessageDialog();

  @override
  State<_QuickMessageDialog> createState() => _QuickMessageDialogState();
}

class _QuickMessageDialogState extends State<_QuickMessageDialog> {
  final _controller = TextEditingController();
  int _selectedPreset = -1;

  static const _presets = [
    'On my way',
    'Running late',
    'Check in OK',
    'Need assistance',
    'At destination',
    'Weather alert',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Quick Message',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(_presets.length, (index) {
              final isSelected = _selectedPreset == index;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPreset = index;
                    _controller.text = _presets[index];
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryGreen.withValues(alpha: 0.15)
                        : AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryGreen
                          : AppTheme.darkBorder,
                    ),
                  ),
                  child: Text(
                    _presets[index],
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? AppTheme.primaryGreen
                          : AppTheme.textSecondary,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'Inter',
            ),
            decoration: InputDecoration(
              hintText: 'Or type custom message...',
              hintStyle: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 14,
                fontFamily: 'Inter',
              ),
              filled: true,
              fillColor: AppTheme.darkBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.darkBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.darkBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.primaryGreen),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            maxLength: 200,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _controller.text.isNotEmpty
              ? () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sent: ${_controller.text}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Send',
            style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter'),
          ),
        ),
      ],
    );
  }
}
