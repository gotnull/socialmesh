import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../generated/meshtastic/mesh.pbenum.dart' as pb;

/// Device role options with descriptions
class DeviceRoleOption {
  final pb.Config_DeviceConfig_Role role;
  final String displayName;
  final String description;

  const DeviceRoleOption(this.role, this.displayName, this.description);
}

final deviceRoles = [
  DeviceRoleOption(
    pb.Config_DeviceConfig_Role.CLIENT,
    'Client',
    'Default role. Mesh packets are routed through this node. Can send and receive messages.',
  ),
  DeviceRoleOption(
    pb.Config_DeviceConfig_Role.CLIENT_MUTE,
    'Client Mute',
    'Same as client but will not transmit any messages from itself. Useful for monitoring.',
  ),
  DeviceRoleOption(
    pb.Config_DeviceConfig_Role.ROUTER,
    'Router',
    'Routes mesh packets between nodes. Screen and Bluetooth disabled to conserve power.',
  ),
  DeviceRoleOption(
    pb.Config_DeviceConfig_Role.ROUTER_CLIENT,
    'Router & Client',
    'Combination of Router and Client. Routes packets while allowing full device usage.',
  ),
  DeviceRoleOption(
    pb.Config_DeviceConfig_Role.REPEATER,
    'Repeater',
    'Focuses purely on retransmitting packets. Lowest power mode for extending network range.',
  ),
  DeviceRoleOption(
    pb.Config_DeviceConfig_Role.TRACKER,
    'Tracker',
    'Optimized for GPS tracking. Sends position updates at defined intervals.',
  ),
  DeviceRoleOption(
    pb.Config_DeviceConfig_Role.SENSOR,
    'Sensor',
    'Designed for remote sensing. Reports telemetry data at defined intervals.',
  ),
  DeviceRoleOption(
    pb.Config_DeviceConfig_Role.TAK,
    'TAK',
    'Team Awareness Kit integration. Bridges Meshtastic and TAK systems.',
  ),
  DeviceRoleOption(
    pb.Config_DeviceConfig_Role.CLIENT_HIDDEN,
    'Client Hidden',
    'Acts as client but hides from the node list. Still routes traffic.',
  ),
  DeviceRoleOption(
    pb.Config_DeviceConfig_Role.LOST_AND_FOUND,
    'Lost and Found',
    'Optimized for finding lost devices. Sends periodic beacons.',
  ),
  DeviceRoleOption(
    pb.Config_DeviceConfig_Role.TAK_TRACKER,
    'TAK Tracker',
    'Combination of TAK and Tracker modes.',
  ),
];

class DeviceConfigScreen extends ConsumerStatefulWidget {
  const DeviceConfigScreen({super.key});

  @override
  ConsumerState<DeviceConfigScreen> createState() => _DeviceConfigScreenState();
}

class _DeviceConfigScreenState extends ConsumerState<DeviceConfigScreen> {
  pb.Config_DeviceConfig_Role? _selectedRole;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  void _loadCurrentConfig() {
    final myNodeNum = ref.read(myNodeNumProvider);
    final nodes = ref.read(nodesProvider);
    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;

    if (myNode != null && myNode.role != null) {
      final roleString = myNode.role!.toUpperCase().replaceAll(' ', '_');
      try {
        _selectedRole = pb.Config_DeviceConfig_Role.values.firstWhere(
          (r) => r.name == roleString,
          orElse: () => pb.Config_DeviceConfig_Role.CLIENT,
        );
      } catch (e) {
        _selectedRole = pb.Config_DeviceConfig_Role.CLIENT;
      }
    } else {
      _selectedRole = pb.Config_DeviceConfig_Role.CLIENT;
    }
  }

  Future<void> _saveConfig() async {
    if (_selectedRole == null) return;

    setState(() => _isSaving = true);

    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.setDeviceRole(_selectedRole!);

      if (mounted) {
        setState(() => _hasChanges = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device configuration saved. Device may reboot.'),
            backgroundColor: AppTheme.darkCard,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving config: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myNodeNum = ref.watch(myNodeNumProvider);
    final nodes = ref.watch(nodesProvider);
    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;
    final connectedDevice = ref.watch(connectedDeviceProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'Device Config',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _isSaving ? null : _saveConfig,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
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
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Device Info Section
          _buildSectionHeader('Connected Device'),
          _buildCard([
            _buildInfoRow('Name', connectedDevice?.name ?? 'Unknown'),
            _buildDivider(),
            _buildInfoRow('Long Name', myNode?.longName ?? 'Unknown'),
            _buildDivider(),
            _buildInfoRow('Short Name', myNode?.shortName ?? '???'),
            _buildDivider(),
            _buildInfoRow('Hardware', myNode?.hardwareModel ?? 'Unknown'),
            _buildDivider(),
            _buildInfoRow('Firmware', myNode?.firmwareVersion ?? 'Unknown'),
            _buildDivider(),
            _buildInfoRow('Node Number', '${myNode?.nodeNum ?? 0}'),
          ]),

          const SizedBox(height: 24),

          // Device Role Section
          _buildSectionHeader('Device Role'),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: deviceRoles.asMap().entries.map((entry) {
                  final index = entry.key;
                  final option = entry.value;
                  final isSelected = _selectedRole == option.role;

                  return Column(
                    children: [
                      InkWell(
                        borderRadius: index == 0
                            ? const BorderRadius.vertical(
                                top: Radius.circular(12),
                              )
                            : index == deviceRoles.length - 1
                            ? const BorderRadius.vertical(
                                bottom: Radius.circular(12),
                              )
                            : BorderRadius.zero,
                        onTap: () {
                          setState(() {
                            _selectedRole = option.role;
                            _hasChanges = true;
                          });
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
                                        ? AppTheme.primaryGreen
                                        : AppTheme.darkBorder,
                                    width: 2,
                                  ),
                                  color: isSelected
                                      ? AppTheme.primaryGreen
                                      : Colors.transparent,
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      option.displayName,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                            : AppTheme.textSecondary,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      option.description,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textTertiary,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (index < deviceRoles.length - 1) _buildDivider(),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Warning
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warningYellow.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.warningYellow.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.warningYellow,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Changing device role may cause the device to reboot and temporarily disconnect.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.warningYellow.withValues(alpha: 0.9),
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppTheme.textSecondary,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: AppTheme.darkBorder.withValues(alpha: 0.3),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}
