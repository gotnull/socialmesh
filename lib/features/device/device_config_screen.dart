import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/widgets/info_table.dart';
import '../../providers/app_providers.dart';
import '../../utils/snackbar.dart';
import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;
import '../../utils/validation.dart';

/// Device role options with descriptions
class DeviceRoleOption {
  final config_pbenum.Config_DeviceConfig_Role role;
  final String displayName;
  final String description;

  const DeviceRoleOption(this.role, this.displayName, this.description);
}

final deviceRoles = [
  DeviceRoleOption(
    config_pbenum.Config_DeviceConfig_Role.CLIENT,
    'Client',
    'Default role. Mesh packets are routed through this node. Can send and receive messages.',
  ),
  DeviceRoleOption(
    config_pbenum.Config_DeviceConfig_Role.CLIENT_MUTE,
    'Client Mute',
    'Same as client but will not transmit any messages from itself. Useful for monitoring.',
  ),
  DeviceRoleOption(
    config_pbenum.Config_DeviceConfig_Role.ROUTER,
    'Router',
    'Routes mesh packets between nodes. Screen and Bluetooth disabled to conserve power.',
  ),
  DeviceRoleOption(
    config_pbenum.Config_DeviceConfig_Role.ROUTER_CLIENT,
    'Router & Client',
    'Combination of Router and Client. Routes packets while allowing full device usage.',
  ),
  DeviceRoleOption(
    config_pbenum.Config_DeviceConfig_Role.REPEATER,
    'Repeater',
    'Focuses purely on retransmitting packets. Lowest power mode for extending network range.',
  ),
  DeviceRoleOption(
    config_pbenum.Config_DeviceConfig_Role.TRACKER,
    'Tracker',
    'Optimized for GPS tracking. Sends position updates at defined intervals.',
  ),
  DeviceRoleOption(
    config_pbenum.Config_DeviceConfig_Role.SENSOR,
    'Sensor',
    'Designed for remote sensing. Reports telemetry data at defined intervals.',
  ),
  DeviceRoleOption(
    config_pbenum.Config_DeviceConfig_Role.TAK,
    'TAK',
    'Team Awareness Kit integration. Bridges Meshtastic and TAK systems.',
  ),
  DeviceRoleOption(
    config_pbenum.Config_DeviceConfig_Role.CLIENT_HIDDEN,
    'Client Hidden',
    'Acts as client but hides from the node list. Still routes traffic.',
  ),
  DeviceRoleOption(
    config_pbenum.Config_DeviceConfig_Role.LOST_AND_FOUND,
    'Lost and Found',
    'Optimized for finding lost devices. Sends periodic beacons.',
  ),
  DeviceRoleOption(
    config_pbenum.Config_DeviceConfig_Role.TAK_TRACKER,
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
  config_pbenum.Config_DeviceConfig_Role? _selectedRole;
  bool _isSaving = false;
  bool _hasChanges = false;

  // Name editing
  late TextEditingController _longNameController;
  late TextEditingController _shortNameController;
  String? _originalLongName;
  String? _originalShortName;

  @override
  void initState() {
    super.initState();
    _longNameController = TextEditingController();
    _shortNameController = TextEditingController();
    _loadCurrentConfig();

    // Listen for device changes and force rebuild
    ref.listen(connectedDeviceProvider, (_, _) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _longNameController.dispose();
    _shortNameController.dispose();
    super.dispose();
  }

  void _loadCurrentConfig() {
    final myNodeNum = ref.read(myNodeNumProvider);
    final nodes = ref.read(nodesProvider);
    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;

    if (myNode != null) {
      // Load names
      _originalLongName = myNode.longName ?? '';
      _originalShortName = myNode.shortName ?? '';
      _longNameController.text = _originalLongName!;
      _shortNameController.text = _originalShortName!;

      // Load role
      if (myNode.role != null) {
        final roleString = myNode.role!.toUpperCase().replaceAll(' ', '_');
        try {
          _selectedRole = config_pbenum.Config_DeviceConfig_Role.values
              .firstWhere(
                (r) => r.name == roleString,
                orElse: () => config_pbenum.Config_DeviceConfig_Role.CLIENT,
              );
        } catch (e) {
          _selectedRole = config_pbenum.Config_DeviceConfig_Role.CLIENT;
        }
      } else {
        _selectedRole = config_pbenum.Config_DeviceConfig_Role.CLIENT;
      }
    } else {
      _selectedRole = config_pbenum.Config_DeviceConfig_Role.CLIENT;
    }
  }

  void _checkForChanges() {
    final nameChanged =
        _longNameController.text != _originalLongName ||
        _shortNameController.text != _originalShortName;
    setState(() {
      _hasChanges = nameChanged || _selectedRole != null;
    });
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);

    try {
      final protocol = ref.read(protocolServiceProvider);

      // Save name if changed
      final nameChanged =
          _longNameController.text != _originalLongName ||
          _shortNameController.text != _originalShortName;
      if (nameChanged) {
        await protocol.setUserName(
          longName: _longNameController.text,
          shortName: _shortNameController.text,
        );
      }

      // Save role if changed
      if (_selectedRole != null) {
        await protocol.setDeviceRole(_selectedRole!);
      }

      if (mounted) {
        setState(() => _hasChanges = false);
        showSuccessSnackBar(context, 'Device configuration saved');
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
    final myNodeNum = ref.watch(myNodeNumProvider);
    final nodes = ref.watch(nodesProvider);
    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;
    final connectedDevice = ref.watch(connectedDeviceProvider);

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        title: Text(
          'Device Config',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
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
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Long Name Field
          _buildNameField(
            icon: Icons.badge_outlined,
            label: 'Long Name',
            subtitle: 'Display name visible on the mesh',
            controller: _longNameController,
            maxLength: maxLongNameLength,
            hint: 'Enter display name',
          ),

          SizedBox(height: 16),

          // Short Name Field
          _buildNameField(
            icon: Icons.short_text,
            label: 'Short Name',
            subtitle: 'Max $maxShortNameLength characters (A-Z, 0-9)',
            controller: _shortNameController,
            maxLength: maxShortNameLength,
            hint: 'e.g. FUZZ',
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              UpperCaseTextFormatter(),
              LengthLimitingTextInputFormatter(maxShortNameLength),
            ],
            textCapitalization: TextCapitalization.characters,
          ),

          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Your device name is broadcast to the mesh and visible to other nodes.',
              style: TextStyle(fontSize: 12, color: context.textTertiary),
            ),
          ),

          SizedBox(height: 24),

          // Device Info Section
          _buildSectionHeader('Device Info'),
          InfoTable(
            rows: [
              InfoTableRow(
                label: 'BLE Name',
                value: connectedDevice?.name ?? 'Unknown',
                icon: Icons.bluetooth,
              ),
              InfoTableRow(
                label: 'Hardware',
                value: myNode?.hardwareModel ?? 'Unknown',
                icon: Icons.memory_outlined,
              ),
              InfoTableRow(
                label: 'User ID',
                value: myNode?.userId ?? 'Unknown',
                icon: Icons.fingerprint,
              ),
              InfoTableRow(
                label: 'Node Number',
                value: '${myNode?.nodeNum ?? 0}',
                icon: Icons.tag,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Device Role Section
          _buildSectionHeader('Device Role'),
          Container(
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.border),
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
                                            ? context.textPrimary
                                            : context.textSecondary,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      option.description,
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
                Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.primaryBlue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Device role determines how your node behaves in the mesh network.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.primaryBlue.withValues(alpha: 0.9),
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

  Widget _buildNameField({
    required IconData icon,
    required String label,
    required String subtitle,
    required TextEditingController controller,
    required int maxLength,
    required String hint,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with label
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: controller.text.length >= maxLength
                        ? AppTheme.warningYellow.withValues(alpha: 0.15)
                        : context.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${controller.text.length}/$maxLength',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: controller.text.length >= maxLength
                          ? AppTheme.warningYellow
                          : context.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Input field area
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: context.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.border.withValues(alpha: 0.5)),
            ),
            child: TextField(
              controller: controller,
              maxLength: maxLength,
              inputFormatters: inputFormatters,
              textCapitalization: textCapitalization,
              style: TextStyle(
                fontSize: 15,
                color: context.textPrimary,

                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.all(16),
                hintText: hint,
                hintStyle: TextStyle(
                  color: context.textTertiary,
                  fontWeight: FontWeight.w400,
                ),
                counterText: '',
              ),
              onChanged: (_) {
                _checkForChanges();
                setState(() {}); // Update character counter
              },
            ),
          ),
        ],
      ),
    );
  }
}
