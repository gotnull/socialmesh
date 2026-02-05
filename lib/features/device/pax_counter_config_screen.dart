// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../providers/app_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/status_banner.dart';

/// PAX Counter module configuration screen
class PaxCounterConfigScreen extends ConsumerStatefulWidget {
  const PaxCounterConfigScreen({super.key});

  @override
  ConsumerState<PaxCounterConfigScreen> createState() =>
      _PaxCounterConfigScreenState();
}

class _PaxCounterConfigScreenState
    extends ConsumerState<PaxCounterConfigScreen> {
  bool _paxCounterEnabled = false;
  int _paxCounterUpdateInterval = 1800; // 30 minutes default
  bool _wifiEnabled = true;
  bool _bleEnabled = true;
  bool _hasChanges = false;
  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    final protocol = ref.read(protocolServiceProvider);

    // Check if we're connected before trying to load config
    if (!protocol.isConnected) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    final config = await protocol.getPaxCounterModuleConfig();
    if (config != null && mounted) {
      setState(() {
        _paxCounterEnabled = config.enabled;
        _paxCounterUpdateInterval = config.paxcounterUpdateInterval > 0
            ? config.paxcounterUpdateInterval
            : 1800;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.setPaxCounterConfig(
        enabled: _paxCounterEnabled,
        updateInterval: _paxCounterEnabled ? _paxCounterUpdateInterval : 0,
        wifiEnabled: _wifiEnabled,
        bleEnabled: _bleEnabled,
      );

      setState(() => _hasChanges = false);
      if (mounted) {
        showSuccessSnackBar(context, 'PAX counter config saved');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to save: $e');
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return GlassScaffold(
        title: 'PAX Counter',
        slivers: [
          SliverFillRemaining(
            child: Center(
              child: MeshLoadingIndicator(
                colors: [
                  context.accentColor,
                  context.accentColor.withValues(alpha: 0.6),
                  context.accentColor.withValues(alpha: 0.3),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return GlassScaffold(
      title: 'PAX Counter',
      actions: [
        if (_hasChanges)
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? LoadingIndicator(size: 16)
                : Text(
                    'Save',
                    style: TextStyle(
                      color: context.accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
      ],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Header info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.people, color: context.accentColor, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PAX Counter',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          ),
                          Text(
                            'Counts nearby WiFi and Bluetooth devices',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Enable PAX Counter
              _SettingsTile(
                title: 'Enable PAX Counter',
                subtitle: 'Count nearby devices and report to mesh',
                trailing: ThemedSwitch(
                  value: _paxCounterEnabled,
                  onChanged: (value) {
                    setState(() {
                      _paxCounterEnabled = value;
                      _hasChanges = true;
                    });
                  },
                ),
              ),

              SizedBox(height: 12),

              // Detection Methods
              if (_paxCounterEnabled) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detection Methods',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: context.textSecondary,
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.wifi,
                                size: 20,
                                color: context.accentColor,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'WiFi Scanning',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                          ThemedSwitch(
                            value: _wifiEnabled,
                            onChanged: (value) {
                              setState(() {
                                _wifiEnabled = value;
                                _hasChanges = true;
                              });
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.bluetooth,
                                size: 20,
                                color: context.accentColor,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Bluetooth Scanning',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                          ThemedSwitch(
                            value: _bleEnabled,
                            onChanged: (value) {
                              setState(() {
                                _bleEnabled = value;
                                _hasChanges = true;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 12),

                // Update Interval
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update Interval',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: context.textSecondary,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '${_paxCounterUpdateInterval ~/ 60} minutes',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: context.accentColor,
                        ),
                      ),
                      SizedBox(height: 8),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: context.accentColor,
                          inactiveTrackColor: context.accentColor.withValues(
                            alpha: 0.2,
                          ),
                          thumbColor: context.accentColor,
                          overlayColor: context.accentColor.withValues(
                            alpha: 0.2,
                          ),
                        ),
                        child: Slider(
                          value: _paxCounterUpdateInterval.toDouble(),
                          min: 60,
                          max: 3600,
                          divisions: 59,
                          onChanged: (value) {
                            setState(() {
                              _paxCounterUpdateInterval = value.round();
                              _hasChanges = true;
                            });
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '1 min',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textTertiary,
                            ),
                          ),
                          Text(
                            '60 min',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 24),

              // Info card
              StatusBanner.accent(
                title: 'About PAX Counter',
                subtitle:
                    'PAX Counter passively listens for WiFi and Bluetooth probe requests from nearby devices. '
                    'It does not store MAC addresses or any personal data.',
                margin: EdgeInsets.zero,
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: context.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: context.textTertiary),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
