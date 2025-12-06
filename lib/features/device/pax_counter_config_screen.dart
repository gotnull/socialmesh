import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../providers/app_providers.dart';

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
  int _paxCounterUpdateInterval = 900; // 15 minutes default
  bool _wifiEnabled = true;
  bool _bleEnabled = true;
  bool _hasChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    final protocol = ref.read(protocolServiceProvider);
    final config = await protocol.getPaxCounterModuleConfig();
    if (config != null && mounted) {
      setState(() {
        _paxCounterEnabled = config.enabled;
        _paxCounterUpdateInterval = config.paxcounterUpdateInterval;
      });
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PAX counter config saved'),
            backgroundColor: AccentColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'PAX Counter',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.accentColor,
                      ),
                    )
                  : Text(
                      'Save',
                      style: TextStyle(
                        color: context.accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                      const Text(
                        'PAX Counter',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Counts nearby WiFi and Bluetooth devices',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.6),
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

          const SizedBox(height: 12),

          // Detection Methods
          if (_paxCounterEnabled) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
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
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                            style: TextStyle(color: Colors.white),
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
                  const SizedBox(height: 8),
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
                            style: TextStyle(color: Colors.white),
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

            const SizedBox(height: 12),

            // Update Interval
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
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
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_paxCounterUpdateInterval ~/ 60} minutes',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: context.accentColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: context.accentColor,
                      inactiveTrackColor:
                          context.accentColor.withValues(alpha: 0.2),
                      thumbColor: context.accentColor,
                      overlayColor: context.accentColor.withValues(alpha: 0.2),
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
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      Text(
                        '60 min',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.accentColor.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: context.accentColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'About PAX Counter',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'PAX Counter passively listens for WiFi and Bluetooth probe requests from nearby devices. '
                  'It does not store MAC addresses or any personal data.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
        color: AppTheme.darkCard,
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
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
