import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../providers/app_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';

class SerialConfigScreen extends ConsumerStatefulWidget {
  const SerialConfigScreen({super.key});

  @override
  ConsumerState<SerialConfigScreen> createState() => _SerialConfigScreenState();
}

class _SerialConfigScreenState extends ConsumerState<SerialConfigScreen> {
  bool _serialEnabled = false;
  bool _rxdGpioEnabled = false;
  bool _txdGpioEnabled = false;
  bool _overrideConsoleSerialPort = false;
  int _baudRate = 115200;
  int _timeout = 5;
  String _mode = 'SIMPLE';
  bool _hasChanges = false;
  bool _isSaving = false;
  bool _isLoading = true;

  final List<int> _baudRates = [
    9600,
    19200,
    38400,
    57600,
    115200,
    230400,
    460800,
    921600,
  ];

  final List<String> _modes = ['SIMPLE', 'PROTO', 'TEXTMSG', 'NMEA', 'CALTOPO'];

  final Map<String, int> _modeValues = {
    'SIMPLE': 0,
    'PROTO': 1,
    'TEXTMSG': 2,
    'NMEA': 3,
    'CALTOPO': 4,
  };

  final Map<int, String> _modeNames = {
    0: 'SIMPLE',
    1: 'PROTO',
    2: 'TEXTMSG',
    3: 'NMEA',
    4: 'CALTOPO',
  };

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

    final config = await protocol.getSerialModuleConfig();
    if (config != null && mounted) {
      setState(() {
        _serialEnabled = config.enabled;
        _rxdGpioEnabled = config.rxd > 0;
        _txdGpioEnabled = config.txd > 0;
        _overrideConsoleSerialPort = config.overrideConsoleSerialPort;
        // baud is stored as index
        if (config.baud.value >= 0 && config.baud.value < _baudRates.length) {
          _baudRate = _baudRates[config.baud.value];
        }
        _timeout = config.timeout > 0 ? config.timeout : 5;
        _mode = _modeNames[config.mode.value] ?? 'SIMPLE';
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String _getModeDescription(String mode) {
    switch (mode) {
      case 'SIMPLE':
        return 'Simple serial output for basic terminal usage';
      case 'PROTO':
        return 'Protobuf binary protocol for programmatic access';
      case 'TEXTMSG':
        return 'Text message mode for SMS-style communication';
      case 'NMEA':
        return 'NMEA GPS sentence output for GPS applications';
      case 'CALTOPO':
        return 'CalTopo format for mapping applications';
      default:
        return '';
    }
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);

    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.setSerialConfig(
        enabled: _serialEnabled,
        echo: false,
        rxd: _rxdGpioEnabled ? 1 : 0,
        txd: _txdGpioEnabled ? 1 : 0,
        baud: _baudRates.indexOf(_baudRate),
        timeout: _timeout,
        mode: _modeValues[_mode] ?? 0,
        overrideConsoleSerialPort: _overrideConsoleSerialPort,
      );

      if (mounted) {
        setState(() => _hasChanges = false);
        showSuccessSnackBar(context, 'Serial configuration saved');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Error saving config: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return GlassScaffold(
        title: 'Serial Config',
        slivers: [SliverFillRemaining(child: const ScreenLoadingIndicator())],
      );
    }

    return GlassScaffold(
      title: 'Serial Config',
      actions: [
        if (_hasChanges)
          TextButton(
            onPressed: _isSaving ? null : _saveConfig,
            child: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
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
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Serial Enable
              _buildSectionHeader('General'),
              Container(
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.border),
                ),
                child: Column(
                  children: [
                    _buildSwitchTile(
                      icon: Icons.usb_rounded,
                      title: 'Serial Enabled',
                      subtitle: 'Enable serial port communication',
                      value: _serialEnabled,
                      onChanged: (value) {
                        setState(() => _serialEnabled = value);
                        _markChanged();
                      },
                    ),
                    _buildDivider(),
                    _buildSwitchTile(
                      icon: Icons.input,
                      title: 'RXD GPIO',
                      subtitle: 'Enable RXD GPIO pin',
                      value: _rxdGpioEnabled,
                      onChanged: (value) {
                        setState(() => _rxdGpioEnabled = value);
                        _markChanged();
                      },
                    ),
                    _buildDivider(),
                    _buildSwitchTile(
                      icon: Icons.output,
                      title: 'TXD GPIO',
                      subtitle: 'Enable TXD GPIO pin',
                      value: _txdGpioEnabled,
                      onChanged: (value) {
                        setState(() => _txdGpioEnabled = value);
                        _markChanged();
                      },
                    ),
                    _buildDivider(),
                    _buildSwitchTile(
                      icon: Icons.terminal,
                      title: 'Override Console Serial',
                      subtitle: 'Use serial module instead of console',
                      value: _overrideConsoleSerialPort,
                      onChanged: (value) {
                        setState(() => _overrideConsoleSerialPort = value);
                        _markChanged();
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Baud Rate
              _buildSectionHeader('Baud Rate'),
              Container(
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.border),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: context.accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.speed,
                            color: context.accentColor,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Baud Rate',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: context.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Serial communication speed',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _baudRates.map((rate) {
                        final isSelected = _baudRate == rate;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _baudRate = rate);
                            _markChanged();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? context.accentColor
                                  : context.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? context.accentColor
                                    : context.border,
                              ),
                            ),
                            child: Text(
                              rate.toString(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : context.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Timeout
              _buildSectionHeader('Timeout'),
              Container(
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.border),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: context.accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.timer_outlined,
                            color: context.accentColor,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Timeout',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: context.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$_timeout seconds',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: context.accentColor,
                        inactiveTrackColor: context.border,
                        thumbColor: context.accentColor,
                        overlayColor: context.accentColor.withValues(
                          alpha: 0.2,
                        ),
                      ),
                      child: Slider(
                        value: _timeout.toDouble(),
                        min: 1,
                        max: 60,
                        divisions: 59,
                        onChanged: (value) {
                          setState(() => _timeout = value.round());
                          _markChanged();
                        },
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Mode Selection
              _buildSectionHeader('Serial Mode'),
              Container(
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.border),
                ),
                child: Column(
                  children: _modes.asMap().entries.map((entry) {
                    final index = entry.key;
                    final mode = entry.value;
                    final isSelected = _mode == mode;

                    return Column(
                      children: [
                        InkWell(
                          borderRadius: index == 0
                              ? const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                )
                              : index == _modes.length - 1
                              ? const BorderRadius.vertical(
                                  bottom: Radius.circular(12),
                                )
                              : BorderRadius.zero,
                          onTap: () {
                            setState(() => _mode = mode);
                            _markChanged();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? context.accentColor
                                          : context.border,
                                      width: 2,
                                    ),
                                    color: isSelected
                                        ? context.accentColor
                                        : Colors.transparent,
                                  ),
                                  child: isSelected
                                      ? Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 16,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mode,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? context.textPrimary
                                              : context.textSecondary,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        _getModeDescription(mode),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: context.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (index < _modes.length - 1) _buildDivider(),
                      ],
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 32),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: context.textSecondary,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: context.border.withValues(alpha: 0.3),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: context.accentColor, size: 20),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: context.textTertiary),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: context.accentColor,
          ),
        ],
      ),
    );
  }
}
