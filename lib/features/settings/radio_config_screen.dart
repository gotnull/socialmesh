import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
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

      // Listen for config response
      _configSubscription = protocol.loraConfigStream.listen((config) {
        if (mounted) _applyConfig(config);
      });

      // Request fresh config from device
      await protocol.getConfig(pb.AdminMessage_ConfigType.LORA_CONFIG);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.setLoRaConfig(
        region: _selectedRegion,
        modemPreset: _selectedModemPreset,
        hopLimit: _hopLimit,
        txEnabled: _txEnabled,
        txPower: _txPower > 0 ? _txPower : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Radio configuration saved'),
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
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Radio Configuration'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveConfig,
            child: const Text('Save'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionHeader(title: 'REGION'),
                const SizedBox(height: 8),
                _buildRegionSelector(theme),
                const SizedBox(height: 24),
                _SectionHeader(title: 'MODEM PRESET'),
                const SizedBox(height: 8),
                _buildModemPresetSelector(theme),
                const SizedBox(height: 24),
                _SectionHeader(title: 'TRANSMISSION'),
                const SizedBox(height: 8),
                _buildTransmissionSettings(theme),
                const SizedBox(height: 32),
                _buildInfoCard(theme),
              ],
            ),
    );
  }

  Widget _buildRegionSelector(ThemeData theme) {
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

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Frequency Region',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select the region that matches your country\'s regulations',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: DropdownButton<pbenum.RegionCode>(
                isExpanded: true,
                underline: const SizedBox.shrink(),
                dropdownColor: theme.colorScheme.surface,
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
      ),
    );
  }

  Widget _buildModemPresetSelector(ThemeData theme) {
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

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Modem Preset',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'All devices in the mesh must use the same preset',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ...presets.map((p) {
              final isSelected = _selectedModemPreset == p.$1;
              return ListTile(
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                title: Text(p.$2),
                subtitle: Text(p.$3),
                contentPadding: EdgeInsets.zero,
                dense: true,
                onTap: () => setState(() => _selectedModemPreset = p.$1),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTransmissionSettings(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              value: _txEnabled,
              onChanged: (value) => setState(() => _txEnabled = value),
              title: const Text('Transmission Enabled'),
              subtitle: const Text('Allow device to transmit'),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            const SizedBox(height: 8),
            Text('Hop Limit: $_hopLimit', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Number of times messages can be relayed',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Slider(
              value: _hopLimit.toDouble(),
              min: 0,
              max: 7,
              divisions: 7,
              label: _hopLimit.toString(),
              onChanged: (value) {
                setState(() => _hopLimit = value.toInt());
              },
            ),
            const SizedBox(height: 8),
            Text(
              'TX Power Override: ${_txPower == 0 ? 'Default' : '${_txPower}dBm'}',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Override transmit power (0 = use default)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Slider(
              value: _txPower.toDouble(),
              min: 0,
              max: 30,
              divisions: 30,
              label: _txPower == 0 ? 'Default' : '$_txPower dBm',
              onChanged: (value) {
                setState(() => _txPower = value.toInt());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.primaryContainer.withAlpha(100),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Changing radio settings will cause the device to reboot. '
                'All devices in your mesh network must use the same region and modem preset.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
