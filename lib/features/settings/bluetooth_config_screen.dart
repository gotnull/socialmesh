import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/widgets/animations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../providers/app_providers.dart';
import '../../generated/meshtastic/mesh.pbenum.dart' as pb;
import '../../generated/meshtastic/mesh.pb.dart' as pb_config;
import '../../core/widgets/loading_indicator.dart';

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
  bool _loading = false;
  StreamSubscription<pb_config.Config_BluetoothConfig>? _configSubscription;
  final _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pinController.text = _fixedPin.toString().padLeft(6, '0');
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _configSubscription?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  void _applyConfig(pb_config.Config_BluetoothConfig config) {
    setState(() {
      _enabled = config.enabled;
      _mode = config.mode;
      _fixedPin = config.fixedPin > 0 ? config.fixedPin : 123456;
      _pinController.text = _fixedPin.toString().padLeft(6, '0');
    });
  }

  Future<void> _loadCurrentConfig() async {
    setState(() => _loading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);

      // Apply cached config immediately if available
      final cached = protocol.currentBluetoothConfig;
      if (cached != null) {
        _applyConfig(cached);
      }

      // Only request from device if connected
      if (protocol.isConnected) {
        // Listen for config response
        _configSubscription = protocol.bluetoothConfigStream.listen((config) {
          if (mounted) _applyConfig(config);
        });

        // Request fresh config from device
        await protocol.getConfig(
          pb_config.AdminMessage_ConfigType.BLUETOOTH_CONFIG,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveConfig() async {
    // Validate PIN if fixed PIN mode is selected
    if (_mode == pb.Config_BluetoothConfig_PairingMode.FIXED_PIN) {
      final pinText = _pinController.text;
      if (pinText.isEmpty || pinText.length < 6) {
        showErrorSnackBar(context, 'Please enter a valid 6-digit PIN');
        return;
      }
    }

    final protocol = ref.read(protocolServiceProvider);

    setState(() => _saving = true);

    try {
      await protocol.setBluetoothConfig(
        enabled: _enabled,
        mode: _mode,
        fixedPin: _fixedPin,
      );

      if (mounted) {
        showSuccessSnackBar(context, 'Bluetooth configuration saved');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to save: $e');
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

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: context.background,
        appBar: AppBar(
          backgroundColor: context.background,
          title: Text(
            'Bluetooth',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _saving ? null : _saveConfig,
                child: _saving
                    ? LoadingIndicator(size: 20)
                    : Text(
                        'Save',
                        style: TextStyle(
                          color: context.accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
        body: _loading
            ? const ScreenLoadingIndicator()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Bluetooth enabled toggle
                  Container(
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.bluetooth,
                          color: context.textSecondary,
                          size: 22,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bluetooth Enabled',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Enable Bluetooth connectivity',
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ThemedSwitch(
                          value: _enabled,
                          onChanged: (value) {
                            HapticFeedback.selectionClick();
                            setState(() => _enabled = value);
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // Pairing mode section
                  Text(
                    'PAIRING MODE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.textTertiary,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: context.card,
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
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                _getModeDescription(mode),
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              leading: Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                color: isSelected
                                    ? context.accentColor
                                    : context.textTertiary,
                              ),
                              selected: isSelected,
                              onTap: () => setState(() => _mode = mode),
                            ),
                            if (index < modes.length - 1)
                              Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                                color: context.border,
                              ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(height: 24),

                  // Fixed PIN (only show when mode is Fixed PIN)
                  if (_mode ==
                      pb.Config_BluetoothConfig_PairingMode.FIXED_PIN) ...[
                    Text(
                      'FIXED PIN',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.textTertiary,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: context.card,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _pinController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) =>
                                FocusScope.of(context).unfocus(),
                            maxLength: 6,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 8,
                              fontFamily: AppTheme.fontFamily,
                            ),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '123456',
                              hintStyle: TextStyle(
                                color: context.textTertiary.withValues(
                                  alpha: 0.5,
                                ),
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 8,
                                fontFamily: AppTheme.fontFamily,
                              ),
                              filled: true,
                              fillColor: context.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (value) {
                              final pin = int.tryParse(value);
                              if (pin != null) {
                                _fixedPin = pin;
                              } else if (value.isEmpty) {
                                _fixedPin = 0;
                              }
                            },
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Enter a 6-digit PIN code for Bluetooth pairing',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                  ],

                  // Info card
                  Container(
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: context.accentColor.withValues(alpha: 0.8),
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Bluetooth settings control how your device pairs with phones and other devices.',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
