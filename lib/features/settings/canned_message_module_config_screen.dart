import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/widgets/animations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../generated/meshtastic/mesh.pb.dart' as pb;

/// Screen for configuring device-side canned message module settings
/// This is different from CannedResponsesScreen which manages local quick responses
class CannedMessageModuleConfigScreen extends ConsumerStatefulWidget {
  const CannedMessageModuleConfigScreen({super.key});

  @override
  ConsumerState<CannedMessageModuleConfigScreen> createState() =>
      _CannedMessageModuleConfigScreenState();
}

class _CannedMessageModuleConfigScreenState
    extends ConsumerState<CannedMessageModuleConfigScreen> {
  bool _isLoading = false;
  bool _enabled = false;
  bool _sendBell = false;
  bool _rotary1Enabled = false;
  bool _updown1Enabled = false;
  int _inputbrokerPinA = 0;
  int _inputbrokerPinB = 0;
  int _inputbrokerPinPress = 0;
  pb.ModuleConfig_CannedMessageConfig_InputEventChar? _inputbrokerEventCw;
  pb.ModuleConfig_CannedMessageConfig_InputEventChar? _inputbrokerEventCcw;
  pb.ModuleConfig_CannedMessageConfig_InputEventChar? _inputbrokerEventPress;
  int _configPreset = 0; // 0=Manual, 1=RAK Rotary Encoder, 2=CardKB
  StreamSubscription<pb.ModuleConfig_CannedMessageConfig>? _configSubscription;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _configSubscription?.cancel();
    super.dispose();
  }

  void _applyConfig(pb.ModuleConfig_CannedMessageConfig config) {
    setState(() {
      _enabled = config.enabled;
      _sendBell = config.sendBell;
      _rotary1Enabled = config.rotary1Enabled;
      _updown1Enabled = config.updown1Enabled;
      _inputbrokerPinA = config.inputbrokerPinA;
      _inputbrokerPinB = config.inputbrokerPinB;
      _inputbrokerPinPress = config.inputbrokerPinPress;
      _inputbrokerEventCw = config.inputbrokerEventCw;
      _inputbrokerEventCcw = config.inputbrokerEventCcw;
      _inputbrokerEventPress = config.inputbrokerEventPress;
    });
  }

  Future<void> _loadCurrentConfig() async {
    setState(() => _isLoading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);

      // Apply cached config immediately if available
      final cached = protocol.currentCannedMessageConfig;
      if (cached != null) {
        _applyConfig(cached);
      }

      // Only request from device if connected
      if (protocol.isConnected) {
        // Listen for config response
        _configSubscription = protocol.cannedMessageConfigStream.listen((
          config,
        ) {
          if (mounted) _applyConfig(config);
        });

        // Request fresh config from device
        await protocol.getModuleConfig(
          pb.AdminMessage_ModuleConfigType.CANNEDMSG_CONFIG,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);

      // Determine allowInputSource based on enabled controls
      String allowInputSource = '_any';
      if (_rotary1Enabled) {
        allowInputSource = 'rotEnc1';
      } else if (_updown1Enabled) {
        allowInputSource = 'upDown1';
      }

      await protocol.setCannedMessageConfig(
        enabled: _enabled,
        sendBell: _sendBell,
        rotary1Enabled: _rotary1Enabled,
        updown1Enabled: _updown1Enabled,
        allowInputSource: allowInputSource,
        inputbrokerPinA: _inputbrokerPinA,
        inputbrokerPinB: _inputbrokerPinB,
        inputbrokerPinPress: _inputbrokerPinPress,
        inputbrokerEventCw:
            _inputbrokerEventCw ??
            pb.ModuleConfig_CannedMessageConfig_InputEventChar.NONE,
        inputbrokerEventCcw:
            _inputbrokerEventCcw ??
            pb.ModuleConfig_CannedMessageConfig_InputEventChar.NONE,
        inputbrokerEventPress:
            _inputbrokerEventPress ??
            pb.ModuleConfig_CannedMessageConfig_InputEventChar.NONE,
      );

      if (mounted) {
        showSuccessSnackBar(context, 'Canned message configuration saved');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to save: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyPreset(int preset) {
    setState(() {
      _configPreset = preset;
      if (preset == 1) {
        // RAK Rotary Encoder
        _updown1Enabled = true;
        _rotary1Enabled = false;
        _inputbrokerPinA = 4;
        _inputbrokerPinB = 10;
        _inputbrokerPinPress = 9;
        _inputbrokerEventCw =
            pb.ModuleConfig_CannedMessageConfig_InputEventChar.DOWN;
        _inputbrokerEventCcw =
            pb.ModuleConfig_CannedMessageConfig_InputEventChar.UP;
        _inputbrokerEventPress =
            pb.ModuleConfig_CannedMessageConfig_InputEventChar.SELECT;
      } else if (preset == 2) {
        // CardKB / RAK Keypad
        _updown1Enabled = false;
        _rotary1Enabled = false;
        _inputbrokerPinA = 0;
        _inputbrokerPinB = 0;
        _inputbrokerPinPress = 0;
        _inputbrokerEventCw =
            pb.ModuleConfig_CannedMessageConfig_InputEventChar.NONE;
        _inputbrokerEventCcw =
            pb.ModuleConfig_CannedMessageConfig_InputEventChar.NONE;
        _inputbrokerEventPress =
            pb.ModuleConfig_CannedMessageConfig_InputEventChar.NONE;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        title: Text('Canned Messages Module'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveConfig,
            child: Text(
              'Save',
              style: TextStyle(
                color: _isLoading ? Colors.grey : context.accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const ScreenLoadingIndicator()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildOptionsSection(),
                const SizedBox(height: 24),
                _buildPresetSection(),
                const SizedBox(height: 24),
                if (_configPreset == 0) ...[
                  _buildControlTypeSection(),
                  const SizedBox(height: 24),
                  _buildInputsSection(),
                  const SizedBox(height: 24),
                  _buildKeyMappingSection(),
                  const SizedBox(height: 24),
                ],
                _buildInfoCard(),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildOptionsSection() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OPTIONS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: context.textTertiary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          _SettingsTile(
            icon: Icons.message,
            title: 'Enabled',
            subtitle: 'Enable canned message module on device',
            trailing: ThemedSwitch(
              value: _enabled,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() => _enabled = value);
              },
            ),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.notifications,
            title: 'Send Bell',
            subtitle: 'Send bell character with messages',
            trailing: ThemedSwitch(
              value: _sendBell,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() => _sendBell = value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetSection() {
    final presets = [
      (0, 'Manual Configuration', 'Custom GPIO and event settings'),
      (1, 'RAK Rotary Encoder', 'Pre-configured for RAK rotary encoder'),
      (2, 'M5 Stack Card KB', 'Pre-configured for Card KB / RAK Keypad'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONFIGURATION PRESET',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: context.textTertiary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          ...presets.map((item) {
            final isSelected = _configPreset == item.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _applyPreset(item.$1);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? context.accentColor
                          : context.border,
                      width: isSelected ? 2 : 1,
                    ),
                    color: isSelected
                        ? context.accentColor.withAlpha(20)
                        : context.background,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isSelected ? context.accentColor : Colors.grey,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.$2,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                            Text(
                              item.$3,
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildControlTypeSection() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONTROL TYPE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: context.textTertiary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          _SettingsTile(
            icon: Icons.radio_button_checked,
            title: 'Rotary Encoder',
            subtitle: 'Dumb encoder sending pulses on A/B pins',
            trailing: ThemedSwitch(
              value: _rotary1Enabled,
              onChanged: _updown1Enabled
                  ? null
                  : (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _rotary1Enabled = value);
                    },
            ),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.arrow_upward,
            title: 'Up/Down Buttons',
            subtitle: 'Uses A/B/Press definitions from input broker',
            trailing: ThemedSwitch(
              value: _updown1Enabled,
              onChanged: _rotary1Enabled
                  ? null
                  : (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _updown1Enabled = value);
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputsSection() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GPIO INPUTS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: context.textTertiary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          _buildGpioPicker('Pin A', _inputbrokerPinA, (value) {
            setState(() => _inputbrokerPinA = value);
          }),
          const SizedBox(height: 12),
          _buildGpioPicker('Pin B', _inputbrokerPinB, (value) {
            setState(() => _inputbrokerPinB = value);
          }),
          const SizedBox(height: 12),
          _buildGpioPicker('Press Pin', _inputbrokerPinPress, (value) {
            setState(() => _inputbrokerPinPress = value);
          }),
        ],
      ),
    );
  }

  Widget _buildGpioPicker(String label, int value, Function(int) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: context.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.border),
          ),
          child: DropdownButton<int>(
            value: value,
            isExpanded: true,
            underline: SizedBox(),
            dropdownColor: context.card,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            items: List.generate(49, (i) => i).map((pin) {
              return DropdownMenuItem(
                value: pin,
                child: Text(pin == 0 ? 'Unset' : 'Pin $pin'),
              );
            }).toList(),
            onChanged: (v) {
              if (v != null) {
                HapticFeedback.selectionClick();
                onChanged(v);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildKeyMappingSection() {
    final eventChars = [
      (pb.ModuleConfig_CannedMessageConfig_InputEventChar.NONE, 'None'),
      (pb.ModuleConfig_CannedMessageConfig_InputEventChar.UP, 'Up'),
      (pb.ModuleConfig_CannedMessageConfig_InputEventChar.DOWN, 'Down'),
      (pb.ModuleConfig_CannedMessageConfig_InputEventChar.LEFT, 'Left'),
      (pb.ModuleConfig_CannedMessageConfig_InputEventChar.RIGHT, 'Right'),
      (pb.ModuleConfig_CannedMessageConfig_InputEventChar.SELECT, 'Select'),
      (pb.ModuleConfig_CannedMessageConfig_InputEventChar.BACK, 'Back'),
      (pb.ModuleConfig_CannedMessageConfig_InputEventChar.CANCEL, 'Cancel'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KEY MAPPING',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: context.textTertiary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          _buildEventPicker(
            'Clockwise Event',
            _inputbrokerEventCw ??
                pb.ModuleConfig_CannedMessageConfig_InputEventChar.NONE,
            eventChars,
            (value) {
              setState(() => _inputbrokerEventCw = value);
            },
          ),
          const SizedBox(height: 12),
          _buildEventPicker(
            'Counter-Clockwise Event',
            _inputbrokerEventCcw ??
                pb.ModuleConfig_CannedMessageConfig_InputEventChar.NONE,
            eventChars,
            (value) {
              setState(() => _inputbrokerEventCcw = value);
            },
          ),
          const SizedBox(height: 12),
          _buildEventPicker(
            'Press Event',
            _inputbrokerEventPress ??
                pb.ModuleConfig_CannedMessageConfig_InputEventChar.NONE,
            eventChars,
            (value) {
              setState(() => _inputbrokerEventPress = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEventPicker(
    String label,
    pb.ModuleConfig_CannedMessageConfig_InputEventChar value,
    List<(pb.ModuleConfig_CannedMessageConfig_InputEventChar, String)> options,
    Function(pb.ModuleConfig_CannedMessageConfig_InputEventChar) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: context.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.border),
          ),
          child:
              DropdownButton<
                pb.ModuleConfig_CannedMessageConfig_InputEventChar
              >(
                value: value,
                isExpanded: true,
                underline: SizedBox(),
                dropdownColor: context.card,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                items: options.map((item) {
                  return DropdownMenuItem(value: item.$1, child: Text(item.$2));
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    HapticFeedback.selectionClick();
                    onChanged(v);
                  }
                },
              ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: context.accentColor.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.accentColor.withAlpha(50)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: context.accentColor, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'This configures the device-side canned message module which '
              'allows sending predefined messages using hardware inputs like '
              'rotary encoders or buttons.',
              style: TextStyle(color: context.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: context.textSecondary, size: 22),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
