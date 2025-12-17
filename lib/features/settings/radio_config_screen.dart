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
import '../../generated/meshtastic/mesh.pbenum.dart' as pbenum;

/// Screen for configuring LoRa radio settings
class RadioConfigScreen extends ConsumerStatefulWidget {
  const RadioConfigScreen({super.key});

  @override
  ConsumerState<RadioConfigScreen> createState() => _RadioConfigScreenState();
}

class _RadioConfigScreenState extends ConsumerState<RadioConfigScreen> {
  bool _isLoading = false;
  pbenum.RegionCode? _selectedRegion;
  pb.ModemPreset? _selectedModemPreset;
  int _hopLimit = 3;
  bool _txEnabled = true;
  int _txPower = 0;
  // Advanced settings
  bool _usePreset = true;
  int _channelNum = 0;
  int _bandwidth = 0;
  int _spreadFactor = 0;
  int _codingRate = 0;
  bool _rxBoostedGain = false;
  double _overrideFrequency = 0.0;
  bool _ignoreMqtt = false;
  bool _okToMqtt = false;
  StreamSubscription<pb.Config_LoRaConfig>? _configSubscription;

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

  void _applyConfig(pb.Config_LoRaConfig config) {
    setState(() {
      _selectedRegion = config.region;
      _selectedModemPreset = config.modemPreset;
      _hopLimit = config.hopLimit > 0 ? config.hopLimit : 3;
      _txEnabled = config.txEnabled;
      _txPower = config.txPower;
      // Advanced settings
      _usePreset = config.usePreset;
      _channelNum = config.channelNum;
      _bandwidth = config.bandwidth;
      _spreadFactor = config.spreadFactor;
      _codingRate = config.codingRate;
      _rxBoostedGain = config.sx126xRxBoostedGain;
      _overrideFrequency = config.overrideFrequency;
      _ignoreMqtt = config.ignoreMqtt;
      _okToMqtt = config.configOkToMqtt;
    });
  }

  Future<void> _loadCurrentConfig() async {
    setState(() => _isLoading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);

      // Apply cached config immediately if available
      final cached = protocol.currentLoraConfig;
      if (cached != null) {
        _applyConfig(cached);
      }

      // Only request from device if connected
      if (protocol.isConnected) {
        // Listen for config response
        _configSubscription = protocol.loraConfigStream.listen((config) {
          if (mounted) _applyConfig(config);
        });

        // Request fresh config from device
        await protocol.getConfig(pb.AdminMessage_ConfigType.LORA_CONFIG);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.setLoRaConfig(
        region: _selectedRegion ?? pbenum.RegionCode.UNSET_REGION,
        modemPreset: _selectedModemPreset ?? pb.ModemPreset.LONG_FAST,
        hopLimit: _hopLimit,
        txEnabled: _txEnabled,
        txPower: _txPower,
        usePreset: _usePreset,
        channelNum: _channelNum,
        bandwidth: _bandwidth,
        spreadFactor: _spreadFactor,
        codingRate: _codingRate,
        sx126xRxBoostedGain: _rxBoostedGain,
        overrideFrequency: _overrideFrequency,
        ignoreMqtt: _ignoreMqtt,
        configOkToMqtt: _okToMqtt,
      );

      // Mark region as configured if a valid region was set
      if (_selectedRegion != null &&
          _selectedRegion != pbenum.RegionCode.UNSET_REGION) {
        final settings = await ref.read(settingsServiceProvider.future);
        await settings.setRegionConfigured(true);
      }

      if (mounted) {
        showSuccessSnackBar(context, 'Radio configuration saved');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'Radio',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isLoading ? null : _saveConfig,
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: MeshLoadingIndicator(
                        size: 20,
                        colors: [
                          context.accentColor,
                          context.accentColor.withValues(alpha: 0.6),
                          context.accentColor.withValues(alpha: 0.3),
                        ],
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
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: MeshLoadingIndicator(size: 48))
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                const _SectionHeader(title: 'REGION'),
                _buildRegionSelector(),
                SizedBox(height: 16),
                const _SectionHeader(title: 'MODEM PRESET'),
                _buildModemPresetSelector(),
                SizedBox(height: 16),
                const _SectionHeader(title: 'TRANSMISSION'),
                _SettingsTile(
                  icon: Icons.cell_tower,
                  iconColor: _txEnabled ? context.accentColor : null,
                  title: 'Transmission Enabled',
                  subtitle: 'Allow device to transmit',
                  trailing: ThemedSwitch(
                    value: _txEnabled,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _txEnabled = value);
                    },
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Hop Limit',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.accentColor.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$_hopLimit',
                              style: TextStyle(
                                color: context.accentColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Number of times messages can be relayed',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 8),
                      SliderTheme(
                        data: SliderThemeData(
                          inactiveTrackColor: AppTheme.darkBorder,
                          thumbColor: context.accentColor,
                          overlayColor: context.accentColor.withValues(
                            alpha: 0.2,
                          ),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: _hopLimit.toDouble(),
                          min: 0,
                          max: 7,
                          divisions: 7,
                          onChanged: (value) {
                            setState(() => _hopLimit = value.toInt());
                          },
                        ),
                      ),
                      const Divider(height: 24, color: AppTheme.darkBorder),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TX Power Override',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.accentColor.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _txPower == 0 ? 'Default' : '${_txPower}dBm',
                              style: TextStyle(
                                color: context.accentColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Override transmit power (0 = use default)',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 8),
                      SliderTheme(
                        data: SliderThemeData(
                          inactiveTrackColor: AppTheme.darkBorder,
                          thumbColor: context.accentColor,
                          overlayColor: context.accentColor.withValues(
                            alpha: 0.2,
                          ),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: _txPower.toDouble(),
                          min: 0,
                          max: 30,
                          divisions: 30,
                          onChanged: (value) {
                            setState(() => _txPower = value.toInt());
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const _SectionHeader(title: 'ADVANCED'),
                _buildAdvancedSettings(),
                const SizedBox(height: 16),
                _buildInfoCard(),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildAdvancedSettings() {
    final bandwidthOptions = [
      (0, 'Auto'),
      (31, '31.25 kHz'),
      (62, '62.5 kHz'),
      (125, '125 kHz'),
      (250, '250 kHz'),
      (500, '500 kHz'),
    ];

    final spreadFactorOptions = [
      (0, 'Auto'),
      (7, 'SF7'),
      (8, 'SF8'),
      (9, 'SF9'),
      (10, 'SF10'),
      (11, 'SF11'),
      (12, 'SF12'),
    ];

    final codingRateOptions = [
      (0, 'Auto'),
      (5, '4/5'),
      (6, '4/6'),
      (7, '4/7'),
      (8, '4/8'),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Use Preset toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Use Preset',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Use preset modem settings instead of custom',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              ThemedSwitch(
                value: _usePreset,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  setState(() => _usePreset = value);
                },
              ),
            ],
          ),

          // Custom modem settings (only when preset disabled)
          if (!_usePreset) ...[
            const Divider(height: 24, color: AppTheme.darkBorder),
            // Bandwidth
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bandwidth',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButton<int>(
                    underline: const SizedBox.shrink(),
                    dropdownColor: AppTheme.darkCard,
                    style: const TextStyle(color: Colors.white),
                    value: _bandwidth,
                    items: bandwidthOptions.map((b) {
                      return DropdownMenuItem(value: b.$1, child: Text(b.$2));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _bandwidth = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Spread Factor
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Spread Factor',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButton<int>(
                    underline: const SizedBox.shrink(),
                    dropdownColor: AppTheme.darkCard,
                    style: const TextStyle(color: Colors.white),
                    value: _spreadFactor,
                    items: spreadFactorOptions.map((s) {
                      return DropdownMenuItem(value: s.$1, child: Text(s.$2));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _spreadFactor = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Coding Rate
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Coding Rate',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButton<int>(
                    underline: const SizedBox.shrink(),
                    dropdownColor: AppTheme.darkCard,
                    style: const TextStyle(color: Colors.white),
                    value: _codingRate,
                    items: codingRateOptions.map((c) {
                      return DropdownMenuItem(value: c.$1, child: Text(c.$2));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _codingRate = value);
                    },
                  ),
                ),
              ],
            ),
          ],

          const Divider(height: 24, color: AppTheme.darkBorder),

          // Frequency Slot
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Frequency Slot',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Channel number for frequency calculation',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 80,
                child: TextField(
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    fillColor: AppTheme.darkBackground,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.darkBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.darkBorder),
                    ),
                  ),
                  controller: TextEditingController(text: '$_channelNum'),
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null) setState(() => _channelNum = parsed);
                  },
                ),
              ),
            ],
          ),

          const Divider(height: 24, color: AppTheme.darkBorder),

          // RX Boosted Gain
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RX Boosted Gain',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Enable boosted gain on SX126x receivers',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              ThemedSwitch(
                value: _rxBoostedGain,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  setState(() => _rxBoostedGain = value);
                },
              ),
            ],
          ),

          const Divider(height: 24, color: AppTheme.darkBorder),

          // Frequency Override
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Frequency Override',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Override frequency in MHz (0 = disabled)',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 100,
                child: TextField(
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    fillColor: AppTheme.darkBackground,
                    filled: true,
                    hintText: '0.0',
                    hintStyle: TextStyle(color: AppTheme.textTertiary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.darkBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.darkBorder),
                    ),
                  ),
                  controller: TextEditingController(
                    text: _overrideFrequency > 0
                        ? _overrideFrequency.toStringAsFixed(3)
                        : '',
                  ),
                  onChanged: (value) {
                    final parsed = double.tryParse(value);
                    if (parsed != null) {
                      setState(() => _overrideFrequency = parsed);
                    } else if (value.isEmpty) {
                      setState(() => _overrideFrequency = 0.0);
                    }
                  },
                ),
              ),
            ],
          ),

          const Divider(height: 24, color: AppTheme.darkBorder),

          // Ignore MQTT
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ignore MQTT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ignore messages via MQTT from this device',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              ThemedSwitch(
                value: _ignoreMqtt,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  setState(() => _ignoreMqtt = value);
                },
              ),
            ],
          ),

          const Divider(height: 24, color: AppTheme.darkBorder),

          // Ok to MQTT
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ok to MQTT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Config is ok to send via MQTT uplink',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              ThemedSwitch(
                value: _okToMqtt,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  setState(() => _okToMqtt = value);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegionSelector() {
    final regions = [
      (pbenum.RegionCode.UNSET_REGION, 'Unset', 'Not configured'),
      (pbenum.RegionCode.US, 'US', '915MHz'),
      (pbenum.RegionCode.EU_433, 'EU 433', '433MHz'),
      (pbenum.RegionCode.EU_868, 'EU 868', '868MHz'),
      (pbenum.RegionCode.CN, 'China', '470MHz'),
      (pbenum.RegionCode.JP, 'Japan', '920MHz'),
      (pbenum.RegionCode.ANZ, 'ANZ', '915MHz'),
      (pbenum.RegionCode.KR, 'Korea', '920MHz'),
      (pbenum.RegionCode.TW, 'Taiwan', '920MHz'),
      (pbenum.RegionCode.RU, 'Russia', '868MHz'),
      (pbenum.RegionCode.IN, 'India', '865MHz'),
      (pbenum.RegionCode.NZ_865, 'NZ 865', '865MHz'),
      (pbenum.RegionCode.TH, 'Thailand', '920MHz'),
      (pbenum.RegionCode.UA_433, 'Ukraine 433', '433MHz'),
      (pbenum.RegionCode.UA_868, 'Ukraine 868', '868MHz'),
      (pbenum.RegionCode.MY_433, 'Malaysia 433', '433MHz'),
      (pbenum.RegionCode.MY_919, 'Malaysia 919', '919MHz'),
      (pbenum.RegionCode.SG_923, 'Singapore', '923MHz'),
      (pbenum.RegionCode.LORA_24, 'LoRa 2.4GHz', '2.4GHz'),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select the region that matches your country\'s regulations',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.darkBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownButton<pbenum.RegionCode>(
              isExpanded: true,
              underline: const SizedBox.shrink(),
              dropdownColor: AppTheme.darkCard,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'JetBrainsMono',
              ),
              items: regions.map((r) {
                return DropdownMenuItem(
                  value: r.$1,
                  child: Text('${r.$2} (${r.$3})'),
                );
              }).toList(),
              value: _selectedRegion ?? pbenum.RegionCode.UNSET_REGION,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedRegion = value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModemPresetSelector() {
    final presets = [
      (pb.ModemPreset.LONG_FAST, 'Long Fast', 'Best range with good speed'),
      (pb.ModemPreset.LONG_SLOW, 'Long Slow', 'Maximum range, slower'),
      (
        pb.ModemPreset.VERY_LONG_SLOW,
        'Very Long Slow',
        'Extreme range, very slow',
      ),
      (pb.ModemPreset.LONG_MODERATE, 'Long Moderate', 'Good balance'),
      (pb.ModemPreset.MEDIUM_FAST, 'Medium Fast', 'Medium range, fast'),
      (pb.ModemPreset.MEDIUM_SLOW, 'Medium Slow', 'Medium range, reliable'),
      (pb.ModemPreset.SHORT_FAST, 'Short Fast', 'Short range, fastest'),
      (pb.ModemPreset.SHORT_SLOW, 'Short Slow', 'Short range, reliable'),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'All devices in the mesh must use the same preset',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          SizedBox(height: 16),
          ...presets.map((p) {
            final isSelected = _selectedModemPreset == p.$1;
            return InkWell(
              onTap: () => setState(() => _selectedModemPreset = p.$1),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: isSelected
                          ? context.accentColor
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.$2,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            p.$3,
                            style: const TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.warningYellow.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.warningYellow.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber,
            color: AppTheme.warningYellow.withValues(alpha: 0.8),
            size: 20,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Changing radio settings will cause the device to reboot. '
              'All devices in your mesh network must use the same region and modem preset.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.textTertiary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppTheme.textSecondary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
