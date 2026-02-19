// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../services/haptic_service.dart';
import '../providers/tak_settings_provider.dart';

/// Dedicated TAK settings form accessible from the TakScreen overflow menu
/// and from the main Settings screen.
class TakSettingsScreen extends ConsumerStatefulWidget {
  const TakSettingsScreen({super.key});

  @override
  ConsumerState<TakSettingsScreen> createState() => _TakSettingsScreenState();
}

class _TakSettingsScreenState extends ConsumerState<TakSettingsScreen> {
  late TextEditingController _gatewayUrlController;
  late TextEditingController _callsignController;
  bool _controllersInitialized = false;

  @override
  void dispose() {
    if (_controllersInitialized) {
      _gatewayUrlController.dispose();
      _callsignController.dispose();
    }
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(takSettingsProvider);

    return settingsAsync.when(
      loading: () => GlassScaffold.body(
        title: 'TAK Settings',
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => GlassScaffold.body(
        title: 'TAK Settings',
        body: Center(child: Text('Error: $error')),
      ),
      data: (settings) {
        if (!_controllersInitialized) {
          _gatewayUrlController = TextEditingController(
            text: settings.gatewayUrl,
          );
          _callsignController = TextEditingController(text: settings.callsign);
          _controllersInitialized = true;
        }

        return GlassScaffold.body(
          title: 'TAK Settings',
          body: GestureDetector(
            onTap: _dismissKeyboard,
            behavior: HitTestBehavior.opaque,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader(context, 'CONNECTION'),
                const SizedBox(height: 8),
                _buildGatewayUrlField(context, settings),
                const SizedBox(height: 12),
                _buildAutoConnectToggle(context, settings),
                const SizedBox(height: 24),
                _buildSectionHeader(context, 'POSITION PUBLISHING'),
                const SizedBox(height: 8),
                _buildPublishToggle(context, settings),
                const SizedBox(height: 12),
                _buildPublishIntervalSelector(context, settings),
                const SizedBox(height: 12),
                _buildCallsignField(context, settings),
                const SizedBox(height: 24),
                _buildSectionHeader(context, 'MAP'),
                const SizedBox(height: 8),
                _buildMapLayerToggle(context, settings),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: context.labelMediumStyle?.copyWith(
          color: context.textTertiary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildGatewayUrlField(BuildContext context, TakSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gateway URL', style: context.bodyStyle),
        const SizedBox(height: 4),
        Text(
          'Leave empty to use the default gateway',
          style: context.captionMutedStyle,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _gatewayUrlController,
          maxLength: 256,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: 'https://tak.socialmesh.app',
            hintStyle: context.hintStyle,
            filled: true,
            fillColor: context.card,
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          onChanged: (value) {
            ref.read(takSettingsProvider.notifier).setGatewayUrl(value.trim());
          },
        ),
      ],
    );
  }

  Widget _buildAutoConnectToggle(BuildContext context, TakSettings settings) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: SwitchListTile(
        title: Text('Auto-connect on open', style: context.bodyStyle),
        subtitle: Text(
          'Automatically connect to the gateway when TAK screens open',
          style: context.bodySmallStyle?.copyWith(color: context.textSecondary),
        ),
        value: settings.autoConnect,
        activeColor: context.accentColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onChanged: (value) {
          ref.haptics.toggle();
          ref.read(takSettingsProvider.notifier).setAutoConnect(value);
        },
      ),
    );
  }

  Widget _buildPublishToggle(BuildContext context, TakSettings settings) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: SwitchListTile(
        title: Text('Publish my position', style: context.bodyStyle),
        subtitle: Text(
          'Share your node position with ATAK/WinTAK operators via the gateway',
          style: context.bodySmallStyle?.copyWith(color: context.textSecondary),
        ),
        value: settings.publishEnabled,
        activeColor: context.accentColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onChanged: (value) {
          ref.haptics.toggle();
          ref.read(takSettingsProvider.notifier).setPublishEnabled(value);
        },
      ),
    );
  }

  Widget _buildPublishIntervalSelector(
    BuildContext context,
    TakSettings settings,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Publish interval', style: context.bodyStyle),
                Text(
                  'How often to send your position',
                  style: context.bodySmallStyle?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          DropdownButton<int>(
            value: settings.publishInterval,
            underline: const SizedBox.shrink(),
            dropdownColor: context.surface,
            items: takPublishIntervalOptions.map((seconds) {
              final label = seconds < 60 ? '${seconds}s' : '${seconds ~/ 60}m';
              return DropdownMenuItem(value: seconds, child: Text(label));
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                ref.haptics.buttonTap();
                ref
                    .read(takSettingsProvider.notifier)
                    .setPublishInterval(value);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCallsignField(BuildContext context, TakSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Callsign override', style: context.bodyStyle),
        const SizedBox(height: 4),
        Text(
          'Leave empty to use your node name',
          style: context.captionMutedStyle,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _callsignController,
          maxLength: 20,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'e.g., ALPHA-1',
            hintStyle: context.hintStyle,
            filled: true,
            fillColor: context.card,
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          onChanged: (value) {
            ref.read(takSettingsProvider.notifier).setCallsign(value.trim());
          },
        ),
      ],
    );
  }

  Widget _buildMapLayerToggle(BuildContext context, TakSettings settings) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: SwitchListTile(
        title: Text('Show TAK layer on map', style: context.bodyStyle),
        subtitle: Text(
          'Display TAK entity markers on the dedicated TAK map',
          style: context.bodySmallStyle?.copyWith(color: context.textSecondary),
        ),
        value: settings.mapLayerVisible,
        activeColor: context.accentColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onChanged: (value) {
          ref.haptics.toggle();
          ref.read(takSettingsProvider.notifier).setMapLayerVisible(value);
        },
      ),
    );
  }
}
