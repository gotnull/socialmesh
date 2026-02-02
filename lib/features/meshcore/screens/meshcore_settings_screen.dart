// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/meshcore_constants.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/gradient_border_container.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../services/meshcore/protocol/meshcore_frame.dart';
import '../../../services/meshcore/protocol/meshcore_messages.dart';
import '../../../utils/snackbar.dart';
import '../../navigation/meshcore_shell.dart';

/// MeshCore Settings screen.
///
/// Provides device info, node settings, radio settings, and device actions.
class MeshCoreSettingsScreen extends ConsumerStatefulWidget {
  const MeshCoreSettingsScreen({super.key});

  @override
  ConsumerState<MeshCoreSettingsScreen> createState() =>
      _MeshCoreSettingsScreenState();
}

class _MeshCoreSettingsScreenState
    extends ConsumerState<MeshCoreSettingsScreen> {
  String _appVersion = '';
  bool _showBatteryVoltage = false;

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = packageInfo.version;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final linkStatus = ref.watch(linkStatusProvider);
    final isConnected = linkStatus.isConnected;
    final selfInfoState = ref.watch(meshCoreSelfInfoProvider);
    final selfInfo = selfInfoState.selfInfo;
    final batteryState = ref.watch(meshCoreBatteryProvider);
    final contactsState = ref.watch(meshCoreContactsProvider);
    final channelsState = ref.watch(meshCoreChannelsProvider);

    return GlassScaffold.body(
      leading: const MeshCoreHamburgerMenuButton(),
      title: 'Settings',
      actions: [const MeshCoreDeviceStatusButton()],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDeviceInfoCard(
            context,
            isConnected: isConnected,
            selfInfo: selfInfo,
            batteryState: batteryState,
            contactCount: contactsState.contacts.length,
            channelCount: channelsState.channels.length,
          ),
          const SizedBox(height: 16),
          _buildNodeSettingsCard(context, selfInfo),
          const SizedBox(height: 16),
          _buildActionsCard(context, isConnected),
          const SizedBox(height: 16),
          _buildDebugCard(context),
          const SizedBox(height: 16),
          _buildAboutCard(context),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoCard(
    BuildContext context, {
    required bool isConnected,
    MeshCoreSelfInfo? selfInfo,
    MeshCoreBatteryState? batteryState,
    required int contactCount,
    required int channelCount,
  }) {
    return GradientBorderContainer(
      accentColor: AccentColors.cyan,
      borderRadius: 16,
      borderWidth: 1,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AccentColors.cyan),
              const SizedBox(width: 8),
              Text(
                'Device Info',
                style: TextStyle(
                  color: AccentColors.cyan,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            'Status',
            isConnected ? 'Connected' : 'Disconnected',
            valueColor: isConnected ? AccentColors.green : AppTheme.errorRed,
          ),
          if (selfInfo != null) ...[
            _buildInfoRow('Node Name', selfInfo.nodeName),
            _buildInfoRow(
              'Public Key',
              '${_bytesToHex(selfInfo.pubKey).substring(0, 16)}...',
              onTap: () {
                Clipboard.setData(
                  ClipboardData(text: _bytesToHex(selfInfo.pubKey)),
                );
                showSuccessSnackBar(context, 'Public key copied');
              },
            ),
          ],
          _buildBatteryRow(batteryState),
          _buildInfoRow('Contacts', '$contactCount'),
          _buildInfoRow('Channels', '$channelCount'),
        ],
      ),
    );
  }

  Widget _buildBatteryRow(MeshCoreBatteryState? state) {
    String displayValue;
    IconData icon;
    Color? iconColor;
    Color? valueColor;

    if (state == null || state.voltageMillivolts == null) {
      displayValue = 'Unknown';
      icon = Icons.battery_unknown_rounded;
      iconColor = Colors.grey;
    } else if (_showBatteryVoltage) {
      displayValue =
          '${(state.voltageMillivolts! / 1000.0).toStringAsFixed(2)}V';
      icon = Icons.battery_full_rounded;
    } else if (state.percentage != null) {
      displayValue = '${state.percentage}%';
      if (state.percentage! <= 15) {
        icon = Icons.battery_alert_rounded;
        iconColor = Colors.orange;
        valueColor = Colors.orange;
      } else {
        icon = Icons.battery_full_rounded;
      }
    } else {
      displayValue =
          '${(state.voltageMillivolts! / 1000.0).toStringAsFixed(2)}V';
      icon = Icons.battery_full_rounded;
    }

    return _buildInfoRow(
      'Battery',
      displayValue,
      leading: Icon(icon, size: 18, color: iconColor),
      valueColor: valueColor,
      onTap: state?.voltageMillivolts != null
          ? () => setState(() => _showBatteryVoltage = !_showBatteryVoltage)
          : null,
    );
  }

  Widget _buildNodeSettingsCard(
    BuildContext context,
    MeshCoreSelfInfo? selfInfo,
  ) {
    return GradientBorderContainer(
      accentColor: AccentColors.purple,
      borderRadius: 16,
      borderWidth: 1,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, color: AccentColors.purple),
                const SizedBox(width: 8),
                Text(
                  'Node Settings',
                  style: TextStyle(
                    color: AccentColors.purple,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          _buildSettingsTile(
            icon: Icons.person_outline_rounded,
            title: 'Node Name',
            subtitle: selfInfo?.nodeName ?? 'Not set',
            onTap: () => _editNodeName(context, selfInfo?.nodeName),
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.radio_rounded,
            title: 'Radio Settings',
            subtitle: 'Frequency, TX power, bandwidth',
            onTap: () => _showRadioSettings(context),
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.location_on_outlined,
            title: 'Location',
            subtitle: 'Set node position',
            onTap: () => _editLocation(context),
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.visibility_off_outlined,
            title: 'Privacy Mode',
            subtitle: 'Control advertisement visibility',
            onTap: () => _togglePrivacy(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard(BuildContext context, bool isConnected) {
    return GradientBorderContainer(
      accentColor: AccentColors.green,
      borderRadius: 16,
      borderWidth: 1,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Icon(Icons.bolt_rounded, color: AccentColors.green),
                const SizedBox(width: 8),
                Text(
                  'Actions',
                  style: TextStyle(
                    color: AccentColors.green,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          _buildSettingsTile(
            icon: Icons.cell_tower_rounded,
            title: 'Send Advertisement',
            subtitle: 'Broadcast your presence',
            enabled: isConnected,
            onTap: _sendAdvert,
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.sync_rounded,
            title: 'Sync Time',
            subtitle: 'Update device clock',
            enabled: isConnected,
            onTap: _syncTime,
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.refresh_rounded,
            title: 'Refresh Contacts',
            subtitle: 'Reload contacts from device',
            enabled: isConnected,
            onTap: () => _refreshContacts(context),
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.restart_alt_rounded,
            iconColor: Colors.orange,
            title: 'Reboot Device',
            subtitle: 'Restart the MeshCore device',
            enabled: isConnected,
            onTap: () => _confirmReboot(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugCard(BuildContext context) {
    return GradientBorderContainer(
      accentColor: Colors.grey,
      borderRadius: 16,
      borderWidth: 1,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.bug_report_outlined, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Debug',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          _buildSettingsTile(
            icon: Icons.code_rounded,
            title: 'Protocol Capture',
            subtitle: 'View MeshCore frame logs',
            onTap: () => _showProtocolCapture(context),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    return GradientBorderContainer(
      accentColor: Colors.blueGrey,
      borderRadius: 16,
      borderWidth: 1,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.info_outline_rounded, color: Colors.blueGrey[300]),
        title: const Text('About', style: TextStyle(color: Colors.white)),
        subtitle: Text(
          'SocialMesh v${_appVersion.isEmpty ? '...' : _appVersion}',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        ),
        onTap: () => _showAbout(context),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    Widget? leading,
    Color? valueColor,
    VoidCallback? onTap,
  }) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (leading != null) ...[leading, const SizedBox(width: 8)],
              Text(
                label,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
            ],
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: content,
      );
    }
    return content;
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? iconColor,
    bool enabled = true,
    VoidCallback? onTap,
  }) {
    return ListTile(
      enabled: enabled,
      leading: Icon(
        icon,
        color: enabled
            ? (iconColor ?? Colors.white.withValues(alpha: 0.8))
            : Colors.white.withValues(alpha: 0.3),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.4),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: enabled
              ? Colors.white.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.3),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: enabled
            ? Colors.white.withValues(alpha: 0.5)
            : Colors.white.withValues(alpha: 0.2),
      ),
      onTap: enabled ? onTap : null,
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  // ---------------------------------------------------------------------------
  // Action handlers
  // ---------------------------------------------------------------------------

  void _editNodeName(BuildContext context, String? currentName) {
    final controller = TextEditingController(text: currentName ?? '');
    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit Node Name',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            maxLength: 31,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter node name...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.8),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _setNodeName(controller.text.trim());
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AccentColors.cyan.withValues(alpha: 0.3),
                    foregroundColor: AccentColors.cyan,
                  ),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _setNodeName(String name) async {
    if (name.isEmpty) return;

    final session = ref.read(meshCoreSessionProvider);
    if (session == null || !session.isActive) {
      if (mounted) {
        showErrorSnackBar(context, 'Not connected');
      }
      return;
    }

    try {
      // CMD_SET_ADVERT_NAME = 0x08
      final payload = Uint8List.fromList([...name.codeUnits, 0]);
      await session.sendFrame(
        MeshCoreFrame(
          command: MeshCoreCommands.setAdvertName,
          payload: payload,
        ),
      );
      // Refresh self info
      ref.read(meshCoreSelfInfoProvider.notifier).refresh();
      if (mounted) {
        showSuccessSnackBar(context, 'Node name updated');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to set name');
      }
    }
  }

  void _showRadioSettings(BuildContext context) {
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
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildInfoRow('Frequency', 'Not yet implemented'),
                _buildInfoRow('TX Power', 'Not yet implemented'),
                _buildInfoRow('Bandwidth', 'Not yet implemented'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.8),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }

  void _editLocation(BuildContext context) {
    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set Location',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Location settings coming soon.\n\nThis will allow you to manually set your node position or use GPS.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.8),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }

  void _togglePrivacy(BuildContext context) {
    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Privacy Mode',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Privacy settings coming soon.\n\nThis will control whether your node broadcasts advertisements.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.8),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendAdvert() async {
    final session = ref.read(meshCoreSessionProvider);
    if (session == null || !session.isActive) {
      if (mounted) showErrorSnackBar(context, 'Not connected');
      return;
    }

    try {
      await session.sendCommand(MeshCoreCommands.sendSelfAdvert);
      if (mounted) {
        showSuccessSnackBar(context, 'Advertisement sent');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to send advertisement');
      }
    }
  }

  Future<void> _syncTime() async {
    final session = ref.read(meshCoreSessionProvider);
    if (session == null || !session.isActive) {
      if (mounted) showErrorSnackBar(context, 'Not connected');
      return;
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final payload = Uint8List(4);
      payload[0] = timestamp & 0xFF;
      payload[1] = (timestamp >> 8) & 0xFF;
      payload[2] = (timestamp >> 16) & 0xFF;
      payload[3] = (timestamp >> 24) & 0xFF;

      await session.sendFrame(
        MeshCoreFrame(
          command: MeshCoreCommands.setDeviceTime,
          payload: payload,
        ),
      );
      if (mounted) {
        showSuccessSnackBar(context, 'Time synchronized');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to sync time');
      }
    }
  }

  void _refreshContacts(BuildContext context) {
    ref.read(meshCoreContactsProvider.notifier).refresh();
    showSuccessSnackBar(context, 'Refreshing contacts...');
  }

  void _confirmReboot(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        title: const Text(
          'Reboot Device',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to reboot the MeshCore device?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _rebootDevice();
            },
            child: const Text('Reboot', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Future<void> _rebootDevice() async {
    final session = ref.read(meshCoreSessionProvider);
    if (session == null || !session.isActive) {
      showErrorSnackBar(context, 'Not connected');
      return;
    }

    try {
      await session.sendCommand(MeshCoreCommands.reboot);
      if (mounted) {
        showSuccessSnackBar(context, 'Reboot command sent');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to reboot device');
      }
    }
  }

  void _showProtocolCapture(BuildContext context) {
    final captureState = ref.read(meshCoreCaptureSnapshotProvider);

    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Protocol Capture',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Active', captureState.isActive ? 'Yes' : 'No'),
                _buildInfoRow('Frames', '${captureState.totalCount}'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref
                        .read(meshCoreCaptureSnapshotProvider.notifier)
                        .refresh();
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.8),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Text('Refresh'),
                ),
              ),
              if (captureState.hasFrames) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ref
                          .read(meshCoreCaptureSnapshotProvider.notifier)
                          .clear();
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                    ),
                    child: const Text('Clear'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        title: const Text(
          'About SocialMesh',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version $_appVersion',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            const Text(
              'SocialMesh is a mesh radio companion app supporting '
              'Meshtastic and MeshCore devices.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: AccentColors.cyan)),
          ),
        ],
      ),
    );
  }

  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
