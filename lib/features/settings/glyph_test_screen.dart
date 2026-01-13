import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../providers/glyph_provider.dart';
import '../../utils/snackbar.dart';
import 'glyph_pattern_builder_screen.dart';

/// Screen for testing Nothing Phone glyph patterns
class GlyphTestScreen extends ConsumerWidget {
  const GlyphTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glyphService = ref.watch(glyphServiceProvider);
    final isSupported = ref.watch(glyphSupportedProvider);
    final deviceModel = glyphService.deviceModel;

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Glyph Patterns',
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            Text(
              deviceModel,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: isSupported
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Pattern Builder Card
                BouncyTap(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GlyphPatternBuilderScreen(),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          context.primary,
                          context.primary.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: context.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.tune,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pattern Builder',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Create custom multi-zone patterns',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildPatternCard(context, 'Connection', [
                  _PatternButton('Connected', () async {
                    await glyphService.showConnected();
                    if (context.mounted) {
                      showSuccessSnackBar(context, 'Connected pattern');
                    }
                  }),
                  _PatternButton('Disconnected', () async {
                    await glyphService.showDisconnected();
                    if (context.mounted) {
                      showSuccessSnackBar(context, 'Disconnected pattern');
                    }
                  }),
                  _PatternButton('Syncing', () async {
                    await glyphService.showSyncing();
                    if (context.mounted) {
                      showSuccessSnackBar(context, 'Syncing pattern');
                    }
                  }),
                ]),
                const SizedBox(height: 16),
                _buildPatternCard(context, 'Messages', [
                  _PatternButton('Message Received', () async {
                    await glyphService.showMessageReceived();
                    if (context.mounted) {
                      showSuccessSnackBar(context, 'Message pattern');
                    }
                  }),
                  _PatternButton('DM Received', () async {
                    await glyphService.showMessageReceived(isDM: true);
                    if (context.mounted) {
                      showSuccessSnackBar(context, 'DM pattern');
                    }
                  }),
                  _PatternButton('Message Sent', () async {
                    await glyphService.showMessageSent();
                    if (context.mounted) {
                      showSuccessSnackBar(context, 'Sent pattern');
                    }
                  }),
                ]),
                const SizedBox(height: 16),
                _buildPatternCard(context, 'Node Events', [
                  _PatternButton('Node Online', () async {
                    await glyphService.showNodeOnline();
                    if (context.mounted) {
                      showSuccessSnackBar(context, 'Node online pattern');
                    }
                  }),
                  _PatternButton('Node Offline', () async {
                    await glyphService.showNodeOffline();
                    if (context.mounted) {
                      showSuccessSnackBar(context, 'Node offline pattern');
                    }
                  }),
                  _PatternButton('Signal Nearby', () async {
                    await glyphService.showSignalNearby();
                    if (context.mounted) {
                      showSuccessSnackBar(context, 'Signal pattern');
                    }
                  }),
                ]),
                const SizedBox(height: 16),
                _buildPatternCard(context, 'System', [
                  _PatternButton('Success', () async {
                    await glyphService.showSuccess();
                    if (context.mounted) {
                      showSuccessSnackBar(context, 'Success pattern');
                    }
                  }),
                  _PatternButton('Error', () async {
                    await glyphService.showError();
                    if (context.mounted) {
                      showSuccessSnackBar(context, 'Error pattern');
                    }
                  }),
                  _PatternButton('Low Battery', () async {
                    await glyphService.showLowBattery();
                    if (context.mounted) {
                      showSuccessSnackBar(context, 'Low battery pattern');
                    }
                  }),
                  _PatternButton('Automation', () async {
                    await glyphService.showAutomationTriggered();
                    if (context.mounted) {
                      showSuccessSnackBar(context, 'Automation pattern');
                    }
                  }),
                ]),
                const SizedBox(height: 16),
                _buildPatternCard(context, 'Advanced', [
                  _PatternButton('Battery Level (80%)', () async {
                    await glyphService.showBatteryLevel(80);
                    if (context.mounted) {
                      showSuccessSnackBar(context, 'Battery 80%');
                    }
                  }),
                  _PatternButton('Signal Strength (High)', () async {
                    await glyphService.showSignalStrength(-50);
                    if (context.mounted) {
                      showSuccessSnackBar(context, 'Strong signal');
                    }
                  }),
                  _PatternButton('Turn Off', () async {
                    await glyphService.turnOff();
                    if (context.mounted) {
                      showSuccessSnackBar(context, 'Glyphs off');
                    }
                  }),
                ]),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 64,
                    color: context.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Glyph interface not supported',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This feature requires a Nothing Phone',
                    style: TextStyle(color: context.textTertiary, fontSize: 14),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPatternCard(
    BuildContext context,
    String title,
    List<Widget> buttons,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: buttons),
        ],
      ),
    );
  }
}

class _PatternButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _PatternButton(this.label, this.onPressed);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: context.card,
        foregroundColor: context.textPrimary,
        side: BorderSide(color: context.border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Text(label),
    );
  }
}
