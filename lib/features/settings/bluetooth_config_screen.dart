import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../generated/meshtastic/mesh.pbenum.dart' as pb;

class BluetoothConfigScreen extends ConsumerStatefulWidget {
  const BluetoothConfigScreen({super.key});

  @override
  ConsumerState<BluetoothConfigScreen> createState() =>
      _BluetoothConfigScreenState();
}

class _BluetoothConfigScreenState extends ConsumerState<BluetoothConfigScreen> {
  bool _enabled = true;
  pb.Config_BluetoothConfig_PairingMode _mode =
      pb.Config_BluetoothConfig_PairingMode.FIXED_PIN;
  int _fixedPin = 123456;
  bool _saving = false;

  Future<void> _saveConfig() async {
    final protocol = ref.read(protocolServiceProvider);

    setState(() => _saving = true);

    try {
      await protocol.setBluetoothConfig(
        enabled: _enabled,
        mode: _mode,
        fixedPin: _fixedPin,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth configuration saved'),
            backgroundColor: AppTheme.darkCard,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _getModeLabel(pb.Config_BluetoothConfig_PairingMode mode) {
    switch (mode) {
      case pb.Config_BluetoothConfig_PairingMode.RANDOM_PIN:
        return 'Random PIN';
      case pb.Config_BluetoothConfig_PairingMode.FIXED_PIN:
        return 'Fixed PIN';
      case pb.Config_BluetoothConfig_PairingMode.NO_PIN:
        return 'No PIN';
      default:
        return 'Unknown';
    }
  }

  String _getModeDescription(pb.Config_BluetoothConfig_PairingMode mode) {
    switch (mode) {
      case pb.Config_BluetoothConfig_PairingMode.RANDOM_PIN:
        return 'Generate random PIN on each boot';
      case pb.Config_BluetoothConfig_PairingMode.FIXED_PIN:
        return 'Use a fixed PIN code';
      case pb.Config_BluetoothConfig_PairingMode.NO_PIN:
        return 'No PIN required (insecure)';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final modes = [
      pb.Config_BluetoothConfig_PairingMode.RANDOM_PIN,
      pb.Config_BluetoothConfig_PairingMode.FIXED_PIN,
      pb.Config_BluetoothConfig_PairingMode.NO_PIN,
    ];

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'Bluetooth',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _saving ? null : _saveConfig,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryGreen,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Bluetooth enabled toggle
          Container(
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              title: const Text(
                'Bluetooth Enabled',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
              ),
              subtitle: const Text(
                'Enable Bluetooth connectivity',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontFamily: 'Inter',
                ),
              ),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
              activeTrackColor: AppTheme.primaryGreen,
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return AppTheme.textSecondary;
              }),
            ),
          ),
          const SizedBox(height: 24),

          // Pairing mode section
          const Text(
            'PAIRING MODE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textTertiary,
              letterSpacing: 1,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: modes.asMap().entries.map((entry) {
                final index = entry.key;
                final mode = entry.value;
                final isSelected = _mode == mode;
                return Column(
                  children: [
                    ListTile(
                      title: Text(
                        _getModeLabel(mode),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Inter',
                        ),
                      ),
                      subtitle: Text(
                        _getModeDescription(mode),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontFamily: 'Inter',
                        ),
                      ),
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? AppTheme.primaryGreen
                            : AppTheme.textTertiary,
                      ),
                      selected: isSelected,
                      onTap: () => setState(() => _mode = mode),
                    ),
                    if (index < modes.length - 1)
                      const Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: AppTheme.darkBorder,
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // Fixed PIN (only show when mode is Fixed PIN)
          if (_mode == pb.Config_BluetoothConfig_PairingMode.FIXED_PIN) ...[
            const Text(
              'FIXED PIN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textTertiary,
                letterSpacing: 1,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 8,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '123456',
                      hintStyle: TextStyle(
                        color: AppTheme.textTertiary.withValues(alpha: 0.5),
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 8,
                        fontFamily: 'monospace',
                      ),
                      filled: true,
                      fillColor: AppTheme.darkBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    controller: TextEditingController(
                      text: _fixedPin.toString().padLeft(6, '0'),
                    ),
                    onChanged: (value) {
                      final pin = int.tryParse(value);
                      if (pin != null) {
                        setState(() => _fixedPin = pin);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter a 6-digit PIN code for Bluetooth pairing',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Info card
          Container(
            decoration: BoxDecoration(
              color: AppTheme.graphBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.graphBlue.withValues(alpha: 0.3),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.graphBlue.withValues(alpha: 0.8),
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Bluetooth settings control how your device pairs with phones and other devices. Changes require a device reboot to take effect.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontFamily: 'Inter',
                    ),
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
