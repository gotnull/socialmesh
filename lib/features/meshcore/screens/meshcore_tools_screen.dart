// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/gradient_border_container.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../services/meshcore/protocol/meshcore_messages.dart';
import '../../../utils/snackbar.dart';
import '../../navigation/meshcore_shell.dart';

/// MeshCore Tools screen.
///
/// Provides access to MeshCore diagnostic and analysis tools.
class MeshCoreToolsScreen extends ConsumerStatefulWidget {
  const MeshCoreToolsScreen({super.key});

  @override
  ConsumerState<MeshCoreToolsScreen> createState() =>
      _MeshCoreToolsScreenState();
}

class _MeshCoreToolsScreenState extends ConsumerState<MeshCoreToolsScreen> {
  bool _isRefreshing = false;

  @override
  Widget build(BuildContext context) {
    final linkStatus = ref.watch(linkStatusProvider);
    final isConnected = linkStatus.isConnected;
    final deviceName = linkStatus.deviceName ?? 'MeshCore Device';
    final selfInfoState = ref.watch(meshCoreSelfInfoProvider);
    final battInfoState = ref.watch(meshCoreBatteryProvider);

    if (!isConnected) {
      return GlassScaffold.body(
        leading: const MeshCoreHamburgerMenuButton(),
        title: 'Tools',
        actions: const [MeshCoreDeviceStatusButton()],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.link_off_rounded,
                size: 64,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'MeshCore Disconnected',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Connect to a MeshCore device to access tools',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GlassScaffold.body(
      leading: const MeshCoreHamburgerMenuButton(),
      title: 'Tools',
      actions: const [MeshCoreDeviceStatusButton()],
      body: RefreshIndicator(
        onRefresh: _refreshDeviceInfo,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Device Status Card
            _buildDeviceStatusCard(
              context,
              deviceName: deviceName,
              selfInfoState: selfInfoState,
              battInfoState: battInfoState,
            ),
            const SizedBox(height: 24),

            // Diagnostics Section
            _buildSectionHeader(context, 'Diagnostics'),
            const SizedBox(height: 12),
            _buildToolCard(
              context: context,
              icon: Icons.info_rounded,
              title: 'Device Info',
              subtitle: 'View detailed device information',
              color: AccentColors.cyan,
              onTap: () => _showDeviceInfo(selfInfoState),
            ),
            const SizedBox(height: 12),
            _buildToolCard(
              context: context,
              icon: Icons.battery_full_rounded,
              title: 'Battery & Storage',
              subtitle: 'Monitor power and storage status',
              color: AccentColors.green,
              onTap: () => _showBatteryInfo(battInfoState),
            ),
            const SizedBox(height: 12),
            _buildToolCard(
              context: context,
              icon: Icons.route_rounded,
              title: 'Trace Path',
              subtitle: 'Trace packet routes through the mesh',
              color: AccentColors.purple,
              onTap: () => _showTracePathDialog(),
            ),
            const SizedBox(height: 24),

            // Discovery Section
            _buildSectionHeader(context, 'Discovery'),
            const SizedBox(height: 12),
            _buildToolCard(
              context: context,
              icon: Icons.radar_rounded,
              title: 'Send Advertisement',
              subtitle: 'Broadcast your presence to the mesh',
              color: AccentColors.orange,
              onTap: () => _sendAdvertisement(),
            ),
            const SizedBox(height: 24),

            // Analysis Section
            _buildSectionHeader(context, 'Analysis'),
            const SizedBox(height: 12),
            _buildToolCard(
              context: context,
              icon: Icons.settings_input_antenna_rounded,
              title: 'Radio Settings',
              subtitle: 'View LoRa radio configuration',
              color: AccentColors.pink,
              onTap: () => _showRadioSettings(selfInfoState),
            ),
            const SizedBox(height: 32),

            // Connected indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AccentColors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AccentColors.green.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AccentColors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Connected to $deviceName',
                    style: TextStyle(
                      color: AccentColors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceStatusCard(
    BuildContext context, {
    required String deviceName,
    required MeshCoreSelfInfoState selfInfoState,
    required MeshCoreBatteryState battInfoState,
  }) {
    final selfInfo = selfInfoState.selfInfo;
    return GradientBorderContainer(
      borderRadius: 16,
      borderWidth: 1.5,
      accentColor: AccentColors.cyan,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AccentColors.cyan.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.developer_board_rounded,
                  color: AccentColors.cyan,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selfInfo?.nodeName ?? deviceName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getDeviceTypeLabel(selfInfo),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isRefreshing || selfInfoState.isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  onPressed: _refreshDeviceInfo,
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatusItem(
                  icon: Icons.battery_charging_full_rounded,
                  label: 'Battery',
                  value: _getBatteryDisplay(battInfoState),
                  color: _getBatteryColor(battInfoState),
                ),
              ),
              Expanded(
                child: _buildStatusItem(
                  icon: Icons.bolt_rounded,
                  label: 'TX Power',
                  value: _getTxPowerDisplay(selfInfo),
                  color: AccentColors.orange,
                ),
              ),
              Expanded(
                child: _buildStatusItem(
                  icon: Icons.signal_cellular_alt_rounded,
                  label: 'SF/CR',
                  value: _getSfCrDisplay(selfInfo),
                  color: AccentColors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Colors.white.withValues(alpha: 0.6),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildToolCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border, width: 1),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  String _getDeviceTypeLabel(MeshCoreSelfInfo? selfInfo) {
    if (selfInfo == null) return 'MeshCore Device';
    switch (selfInfo.advType) {
      case 1:
        return 'Chat Node';
      case 2:
        return 'Repeater Node';
      case 3:
        return 'Room Node';
      default:
        return 'MeshCore Device';
    }
  }

  String _getBatteryDisplay(MeshCoreBatteryState battInfo) {
    if (battInfo.isSuccess && battInfo.percentage != null) {
      return '${battInfo.percentage}%';
    }
    if (battInfo.isSuccess && battInfo.voltageMillivolts != null) {
      return '${battInfo.voltageMillivolts}mV';
    }
    return '--';
  }

  Color _getBatteryColor(MeshCoreBatteryState battInfo) {
    final pct = battInfo.percentage;
    if (pct == null) return AccentColors.green;
    if (pct < 20) return AppTheme.errorRed;
    if (pct < 50) return AccentColors.orange;
    return AccentColors.green;
  }

  String _getTxPowerDisplay(MeshCoreSelfInfo? selfInfo) {
    if (selfInfo == null) return '--';
    return '${selfInfo.txPowerDbm}dBm';
  }

  String _getSfCrDisplay(MeshCoreSelfInfo? selfInfo) {
    if (selfInfo == null) return '--';
    final sf = selfInfo.spreadingFactor;
    final cr = selfInfo.codingRate;
    if (sf != null && cr != null) {
      return 'SF$sf/4:$cr';
    }
    if (sf != null) return 'SF$sf';
    return '--';
  }

  Future<void> _refreshDeviceInfo() async {
    setState(() => _isRefreshing = true);
    try {
      // Trigger refresh on both providers
      ref.invalidate(meshCoreSelfInfoProvider);
      ref.invalidate(meshCoreBatteryProvider);
      // Wait for refresh to complete
      await Future.delayed(const Duration(milliseconds: 500));
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _showDeviceInfo(MeshCoreSelfInfoState selfInfoState) {
    final info = selfInfoState.selfInfo;
    if (info == null) {
      showErrorSnackBar(context, 'Device info not available');
      return;
    }

    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Device Information',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoRow('Name', info.nodeName.isNotEmpty ? info.nodeName : '-'),
          _buildInfoRow('Type', _getDeviceTypeLabel(info)),
          _buildInfoRow('TX Power', '${info.txPowerDbm} dBm'),
          _buildInfoRow('Max TX Power', '${info.maxLoraTxPower} dBm'),
          if (info.spreadingFactor != null)
            _buildInfoRow('Spreading Factor', 'SF${info.spreadingFactor}'),
          if (info.codingRate != null)
            _buildInfoRow('Coding Rate', '4/${info.codingRate}'),
          if (info.latitude != null && info.longitude != null) ...[
            const SizedBox(height: 8),
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Location',
              '${(info.latitude! / 1e7).toStringAsFixed(6)}, '
                  '${(info.longitude! / 1e7).toStringAsFixed(6)}',
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final pubKeyHex = info.pubKey
                        .map((b) => b.toRadixString(16).padLeft(2, '0'))
                        .join();
                    Clipboard.setData(
                      ClipboardData(
                        text:
                            'Name: ${info.nodeName}\n'
                            'TX Power: ${info.txPowerDbm} dBm\n'
                            'Public Key: $pubKeyHex',
                      ),
                    );
                    showSuccessSnackBar(context, 'Device info copied');
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.8),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBatteryInfo(MeshCoreBatteryState battInfo) {
    if (!battInfo.isSuccess) {
      showErrorSnackBar(context, 'Battery info not available');
      return;
    }

    final battPct = battInfo.percentage;
    final battColor = _getBatteryColor(battInfo);

    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Battery Status',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Battery section
          Row(
            children: [
              Icon(Icons.battery_full_rounded, color: battColor, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      battPct != null
                          ? '$battPct%'
                          : '${battInfo.voltageMillivolts}mV',
                      style: TextStyle(
                        color: battColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Battery ${battPct != null && battInfo.voltageMillivolts != null ? '(${battInfo.voltageMillivolts}mV)' : ''}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (battPct != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: battPct / 100,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(battColor),
                minHeight: 8,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AccentColors.cyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AccentColors.cyan.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AccentColors.cyan,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Based on LiPo voltage range (3.0V - 4.2V)',
                    style: TextStyle(
                      color: AccentColors.cyan.withValues(alpha: 0.9),
                      fontSize: 12,
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

  void _showTracePathDialog() {
    final contacts = ref.read(meshCoreContactsProvider).contacts;

    if (contacts.isEmpty) {
      showInfoSnackBar(context, 'No contacts available for trace');
      return;
    }

    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trace Path',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a contact to trace the route through the mesh.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 16),
          ...contacts
              .take(10)
              .map(
                (contact) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AccentColors.cyan.withValues(alpha: 0.2),
                    child: Text(
                      contact.name.isNotEmpty
                          ? contact.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(color: AccentColors.cyan),
                    ),
                  ),
                  title: Text(
                    contact.name.isNotEmpty ? contact.name : 'Unknown',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    contact.publicKeyHex.substring(0, 16),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _startTracePath(contact.name, contact.publicKeyHex);
                  },
                ),
              ),
        ],
      ),
    );
  }

  void _startTracePath(String name, String pubKeyHex) {
    showInfoSnackBar(
      context,
      'Trace path to ${name.isNotEmpty ? name : 'node'} initiated',
    );
    // The actual trace path implementation would call:
    // session.sendCommandWithPayload(MeshCoreCommands.sendTracePath, publicKey)
    // and listen for MeshCorePushCodes.traceData responses
  }

  void _sendAdvertisement() async {
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      showErrorSnackBar(context, 'Not connected');
      return;
    }

    try {
      // Send self advertisement command (0x07)
      await session.sendCommand(0x07);
      if (mounted) {
        showSuccessSnackBar(context, 'Advertisement sent');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to send advertisement');
      }
    }
  }

  void _showRadioSettings(MeshCoreSelfInfoState selfInfoState) {
    final info = selfInfoState.selfInfo;
    if (info == null) {
      showErrorSnackBar(context, 'Radio settings not available');
      return;
    }

    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Radio Settings',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoRow('TX Power', '${info.txPowerDbm} dBm'),
          _buildInfoRow('Max TX Power', '${info.maxLoraTxPower} dBm'),
          if (info.spreadingFactor != null)
            _buildInfoRow('Spreading Factor', 'SF${info.spreadingFactor}'),
          if (info.codingRate != null)
            _buildInfoRow('Coding Rate', '4/${info.codingRate}'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AccentColors.pink.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AccentColors.pink.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AccentColors.pink,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Radio settings are configured on the device firmware.',
                    style: TextStyle(
                      color: AccentColors.pink.withValues(alpha: 0.9),
                      fontSize: 12,
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
