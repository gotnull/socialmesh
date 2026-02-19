// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/info_table.dart';
import '../../providers/app_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/status_banner.dart';
import '../../providers/countdown_providers.dart';
import '../../generated/meshtastic/config.pb.dart' as config_pb;
import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;
import '../../generated/meshtastic/admin.pbenum.dart' as admin_pbenum;
import '../../services/protocol/admin_target.dart';
import '../../generated/meshtastic/mesh.pb.dart' as pb;
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
    config_pbenum.Config_DeviceConfig_Role.CLIENT_HIDDEN,
    'Client Hidden',
    'Acts as client but hides from the node list. Still routes traffic.',
  ),
  DeviceRoleOption(
    config_pbenum.Config_DeviceConfig_Role.CLIENT_BASE,
    'Client Base',
    'Base station for favorited nodes. Routes their packets like a router, others as client.',
  ),
  DeviceRoleOption(
    config_pbenum.Config_DeviceConfig_Role.ROUTER,
    'Router',
    'Routes mesh packets between nodes. Screen and Bluetooth disabled to conserve power.',
  ),
  DeviceRoleOption(
    config_pbenum.Config_DeviceConfig_Role.ROUTER_LATE,
    'Router Late',
    'Rebroadcasts all packets after other routers. Extends coverage without consuming priority hops.',
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
    config_pbenum.Config_DeviceConfig_Role.TAK_TRACKER,
    'TAK Tracker',
    'Combination of TAK and Tracker modes.',
  ),
  DeviceRoleOption(
    config_pbenum.Config_DeviceConfig_Role.LOST_AND_FOUND,
    'Lost and Found',
    'Optimized for finding lost devices. Sends periodic beacons.',
  ),
];

/// Rebroadcast mode options with descriptions
class RebroadcastModeOption {
  final config_pbenum.Config_DeviceConfig_RebroadcastMode mode;
  final String displayName;
  final String description;

  const RebroadcastModeOption(this.mode, this.displayName, this.description);
}

final rebroadcastModes = [
  RebroadcastModeOption(
    config_pbenum.Config_DeviceConfig_RebroadcastMode.ALL,
    'All',
    'Rebroadcast any observed message. Default behavior.',
  ),
  RebroadcastModeOption(
    config_pbenum.Config_DeviceConfig_RebroadcastMode.ALL_SKIP_DECODING,
    'All (Skip Decoding)',
    'Rebroadcast all messages without decoding. Faster, less CPU.',
  ),
  RebroadcastModeOption(
    config_pbenum.Config_DeviceConfig_RebroadcastMode.LOCAL_ONLY,
    'Local Only',
    'Only rebroadcast messages from local senders. Good for isolated networks.',
  ),
  RebroadcastModeOption(
    config_pbenum.Config_DeviceConfig_RebroadcastMode.KNOWN_ONLY,
    'Known Only',
    'Only rebroadcast messages from nodes in the node database.',
  ),
  RebroadcastModeOption(
    config_pbenum.Config_DeviceConfig_RebroadcastMode.CORE_PORTNUMS_ONLY,
    'Core Port Numbers Only',
    'Rebroadcast only core Meshtastic packets (position, telemetry, etc).',
  ),
  RebroadcastModeOption(
    config_pbenum.Config_DeviceConfig_RebroadcastMode.NONE,
    'None',
    'Do not rebroadcast any messages. Node only receives.',
  ),
];

/// Buzzer mode options with descriptions
class BuzzerModeOption {
  final config_pbenum.Config_DeviceConfig_BuzzerMode mode;
  final String displayName;
  final String description;

  const BuzzerModeOption(this.mode, this.displayName, this.description);
}

final buzzerModes = [
  BuzzerModeOption(
    config_pbenum.Config_DeviceConfig_BuzzerMode.ALL_ENABLED,
    'All Enabled',
    'Buzzer sounds for all feedback including buttons and alerts.',
  ),
  BuzzerModeOption(
    config_pbenum.Config_DeviceConfig_BuzzerMode.NOTIFICATIONS_ONLY,
    'Notifications Only',
    'Buzzer only for notifications and alerts, not button presses.',
  ),
  BuzzerModeOption(
    config_pbenum.Config_DeviceConfig_BuzzerMode.DIRECT_MSG_ONLY,
    'Direct Messages Only',
    'Buzzer only for direct messages and alerts.',
  ),
  BuzzerModeOption(
    config_pbenum.Config_DeviceConfig_BuzzerMode.SYSTEM_ONLY,
    'System Only',
    'Button presses, startup, shutdown sounds only. No alerts.',
  ),
  BuzzerModeOption(
    config_pbenum.Config_DeviceConfig_BuzzerMode.DISABLED,
    'Disabled',
    'All buzzer audio feedback is disabled.',
  ),
];

class DeviceConfigScreen extends ConsumerStatefulWidget {
  const DeviceConfigScreen({super.key});

  @override
  ConsumerState<DeviceConfigScreen> createState() => _DeviceConfigScreenState();
}

class _DeviceConfigScreenState extends ConsumerState<DeviceConfigScreen>
    with LifecycleSafeMixin {
  config_pbenum.Config_DeviceConfig_Role? _selectedRole;
  config_pbenum.Config_DeviceConfig_Role? _originalRole;
  bool _isSaving = false;
  bool _hasChanges = false;
  bool _isLoading = true;
  ProviderSubscription? _deviceSub;
  StreamSubscription<config_pb.Config_DeviceConfig>? _configSubscription;
  StreamSubscription<pb.User>? _userConfigSubscription;

  // Name editing
  late TextEditingController _longNameController;
  late TextEditingController _shortNameController;
  String? _originalLongName;
  String? _originalShortName;

  // Device Config fields
  config_pbenum.Config_DeviceConfig_RebroadcastMode? _rebroadcastMode;
  config_pbenum.Config_DeviceConfig_RebroadcastMode? _originalRebroadcastMode;
  int _nodeInfoBroadcastSecs = 10800;
  int _originalNodeInfoBroadcastSecs = 10800;
  bool _serialEnabled = true;
  bool _originalSerialEnabled = true;
  bool _doubleTapAsButtonPress = false;
  bool _originalDoubleTapAsButtonPress = false;
  bool _disableTripleClick = false;
  bool _originalDisableTripleClick = false;
  bool _ledHeartbeatDisabled = false;
  bool _originalLedHeartbeatDisabled = false;
  String _tzdef = '';
  String _originalTzdef = '';
  int _buttonGpio = 0;
  int _originalButtonGpio = 0;
  int _buzzerGpio = 0;
  int _originalBuzzerGpio = 0;
  config_pbenum.Config_DeviceConfig_BuzzerMode? _buzzerMode;
  config_pbenum.Config_DeviceConfig_BuzzerMode? _originalBuzzerMode;

  // User flags
  bool _isUnmessagable = false;
  bool _originalIsUnmessagable = false;
  bool _isLicensed = false;
  bool _originalIsLicensed = false;

  // Ham mode fields (only used when _isLicensed is true)
  late TextEditingController _frequencyOverrideController;
  int _txPower = 0;
  final int _originalTxPower = 0;

  @override
  void initState() {
    super.initState();
    AppLogging.protocol('DeviceConfigScreen: initState');
    _longNameController = TextEditingController();
    _shortNameController = TextEditingController();
    _frequencyOverrideController = TextEditingController();
    _loadCurrentConfig();

    // Listen for device changes and force rebuild
    _deviceSub = ref.listenManual(connectedDeviceProvider, (previous, next) {
      safeSetState(() {});
    });
  }

  @override
  void dispose() {
    AppLogging.protocol('DeviceConfigScreen: dispose');
    _deviceSub?.close();
    _configSubscription?.cancel();
    _userConfigSubscription?.cancel();
    _longNameController.dispose();
    _shortNameController.dispose();
    _frequencyOverrideController.dispose();
    super.dispose();
  }

  void _applyDeviceConfig(config_pb.Config_DeviceConfig config) {
    setState(() {
      final nodeInfoSecs = config.nodeInfoBroadcastSecs > 0
          ? config.nodeInfoBroadcastSecs
          : 10800;

      // Only overwrite user-facing values when the user has NOT started
      // editing.  Once _hasChanges is true the user has made a selection
      // and we must not clobber it — otherwise the stream response (or
      // the optimistic cache update inside setConfig) silently reverts
      // their choice, _saveConfig recalculates roleChanged as false,
      // and the save is skipped entirely.
      if (!_hasChanges) {
        _selectedRole = config.role;
        _rebroadcastMode = config.rebroadcastMode;
        _nodeInfoBroadcastSecs = nodeInfoSecs;
        _serialEnabled = config.serialEnabled;
        _doubleTapAsButtonPress = config.doubleTapAsButtonPress;
        _disableTripleClick = config.disableTripleClick;
        _ledHeartbeatDisabled = config.ledHeartbeatDisabled;
        _tzdef = config.tzdef;
        _buttonGpio = config.buttonGpio;
        _buzzerGpio = config.buzzerGpio;
        _buzzerMode = config.buzzerMode;
      }

      // Always update the "original" snapshot so change detection stays
      // correct against the latest device state.
      _originalRole = config.role;
      _originalRebroadcastMode = config.rebroadcastMode;
      _originalNodeInfoBroadcastSecs = nodeInfoSecs;
      _originalSerialEnabled = config.serialEnabled;
      _originalDoubleTapAsButtonPress = config.doubleTapAsButtonPress;
      _originalDisableTripleClick = config.disableTripleClick;
      _originalLedHeartbeatDisabled = config.ledHeartbeatDisabled;
      _originalTzdef = config.tzdef;
      _originalButtonGpio = config.buttonGpio;
      _originalBuzzerGpio = config.buzzerGpio;
      _originalBuzzerMode = config.buzzerMode;
    });
  }

  void _applyUserConfig(pb.User user) {
    setState(() {
      // Only overwrite user-facing values when the user has NOT started
      // editing — same guard as _applyDeviceConfig to prevent the stream
      // response from silently reverting in-progress edits.
      if (!_hasChanges) {
        _isUnmessagable = user.isUnmessagable;
        _isLicensed = user.isLicensed;
      }
      _originalIsUnmessagable = user.isUnmessagable;
      _originalIsLicensed = user.isLicensed;
      AppLogging.protocol(
        'DeviceConfigScreen: Applied user config - isUnmessagable=$_isUnmessagable, isLicensed=$_isLicensed',
      );
    });
  }

  Future<void> _loadCurrentConfig() async {
    safeSetState(() => _isLoading = true);

    final targetNodeNum = ref.read(remoteAdminTargetProvider);
    final isRemote = targetNodeNum != null;
    final myNodeNum = ref.read(myNodeNumProvider);
    final nodes = ref.read(nodesProvider);
    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;

    // When remote, use the target node's cached data for initial display.
    // When local, use myNode as before.
    final displayNode = isRemote ? nodes[targetNodeNum] : myNode;

    AppLogging.protocol(
      'DeviceConfigScreen: _loadCurrentConfig - myNodeNum=$myNodeNum, '
      'myNode=${myNode != null ? "found" : "null"}, '
      'isRemote=$isRemote, targetNodeNum=$targetNodeNum, '
      'displayNode=${displayNode != null ? "found" : "null"}',
    );

    if (displayNode != null) {
      // Load names from the relevant node (local or remote target)
      _originalLongName = displayNode.longName ?? '';
      _originalShortName = displayNode.shortName ?? '';
      _longNameController.text = _originalLongName!;
      _shortNameController.text = _originalShortName!;

      AppLogging.protocol(
        'DeviceConfigScreen: Loaded names - long="$_originalLongName", short="$_originalShortName"',
      );

      // Load role
      if (displayNode.role != null) {
        final roleString = displayNode.role!.toUpperCase().replaceAll(' ', '_');
        try {
          _selectedRole = config_pbenum.Config_DeviceConfig_Role.values
              .firstWhere(
                (r) => r.name == roleString,
                orElse: () => config_pbenum.Config_DeviceConfig_Role.CLIENT,
              );
          _originalRole = _selectedRole;
          AppLogging.protocol(
            'DeviceConfigScreen: Loaded role - ${_selectedRole?.name}',
          );
        } catch (e) {
          _selectedRole = config_pbenum.Config_DeviceConfig_Role.CLIENT;
          _originalRole = _selectedRole;
        }
      } else {
        _selectedRole = config_pbenum.Config_DeviceConfig_Role.CLIENT;
        _originalRole = _selectedRole;
      }
    } else {
      _selectedRole = config_pbenum.Config_DeviceConfig_Role.CLIENT;
      _originalRole = _selectedRole;
    }

    // Load device config from protocol service
    try {
      final protocol = ref.read(protocolServiceProvider);

      // Apply cached config immediately if available (local only)
      if (!isRemote) {
        final cached = protocol.currentDeviceConfig;
        if (cached != null) {
          _applyDeviceConfig(cached);
        } else {
          // Set defaults if no cached config
          _rebroadcastMode =
              config_pbenum.Config_DeviceConfig_RebroadcastMode.ALL;
          _originalRebroadcastMode = _rebroadcastMode;
          _buzzerMode =
              config_pbenum.Config_DeviceConfig_BuzzerMode.ALL_ENABLED;
          _originalBuzzerMode = _buzzerMode;
        }
      } else {
        // Remote: set defaults until we get a response
        _rebroadcastMode =
            config_pbenum.Config_DeviceConfig_RebroadcastMode.ALL;
        _originalRebroadcastMode = _rebroadcastMode;
        _buzzerMode = config_pbenum.Config_DeviceConfig_BuzzerMode.ALL_ENABLED;
        _originalBuzzerMode = _buzzerMode;
      }

      // Only request from device if connected
      if (protocol.isConnected) {
        // Listen for config response
        _configSubscription = protocol.deviceConfigStream.listen((config) {
          if (mounted) _applyDeviceConfig(config);
        });

        // Listen for user config response (for isUnmessagable/isLicensed)
        // Only for local device — user flags are not fetched via remote admin.
        if (!isRemote) {
          _userConfigSubscription = protocol.userConfigStream.listen((user) {
            if (mounted) _applyUserConfig(user);
          });

          // Apply cached user config if available
          final cachedUser = protocol.currentUserConfig;
          if (cachedUser != null) {
            _applyUserConfig(cachedUser);
          }
        }

        // Request fresh config from device (or remote node)
        await protocol.getConfig(
          admin_pbenum.AdminMessage_ConfigType.DEVICE_CONFIG,
          target: AdminTarget.fromNullable(targetNodeNum),
        );
      }
    } catch (e) {
      AppLogging.protocol(
        'DeviceConfigScreen: Error loading device config: $e',
      );
      // Set defaults on error
      _rebroadcastMode = config_pbenum.Config_DeviceConfig_RebroadcastMode.ALL;
      _originalRebroadcastMode = _rebroadcastMode;
      _buzzerMode = config_pbenum.Config_DeviceConfig_BuzzerMode.ALL_ENABLED;
      _originalBuzzerMode = _buzzerMode;
    } finally {
      safeSetState(() => _isLoading = false);
    }
  }

  void _checkForChanges() {
    final nameChanged =
        _longNameController.text != _originalLongName ||
        _shortNameController.text != _originalShortName;
    final roleChanged = _selectedRole != _originalRole;
    final rebroadcastChanged = _rebroadcastMode != _originalRebroadcastMode;
    final nodeInfoChanged =
        _nodeInfoBroadcastSecs != _originalNodeInfoBroadcastSecs;
    final serialChanged = _serialEnabled != _originalSerialEnabled;
    final doubleTapChanged =
        _doubleTapAsButtonPress != _originalDoubleTapAsButtonPress;
    final tripleClickChanged =
        _disableTripleClick != _originalDisableTripleClick;
    final ledChanged = _ledHeartbeatDisabled != _originalLedHeartbeatDisabled;
    final tzdefChanged = _tzdef != _originalTzdef;
    final buttonGpioChanged = _buttonGpio != _originalButtonGpio;
    final buzzerGpioChanged = _buzzerGpio != _originalBuzzerGpio;
    final buzzerModeChanged = _buzzerMode != _originalBuzzerMode;
    final unmessagableChanged = _isUnmessagable != _originalIsUnmessagable;
    final licensedChanged = _isLicensed != _originalIsLicensed;
    final txPowerChanged = _isLicensed && _txPower != _originalTxPower;

    setState(() {
      _hasChanges =
          nameChanged ||
          roleChanged ||
          rebroadcastChanged ||
          nodeInfoChanged ||
          serialChanged ||
          doubleTapChanged ||
          tripleClickChanged ||
          ledChanged ||
          tzdefChanged ||
          buttonGpioChanged ||
          buzzerGpioChanged ||
          buzzerModeChanged ||
          unmessagableChanged ||
          licensedChanged ||
          txPowerChanged;
    });
  }

  Future<void> _confirmAndSave() async {
    final isRemote = ref.read(remoteAdminTargetProvider) != null;

    // Remote admin saves don't reboot the local device, skip confirmation.
    if (isRemote) {
      await _saveConfig();
      return;
    }

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: 'Save Changes?',
      message:
          'Saving device configuration will cause the device to reboot. '
          'You will be briefly disconnected while the device restarts.',
      confirmLabel: 'Save & Reboot',
    );

    if (confirmed == true) {
      await _saveConfig();
    }
  }

  Future<void> _saveConfig() async {
    AppLogging.protocol('DeviceConfigScreen: _saveConfig started');

    // Capture remote admin target before any async work.
    final targetNodeNum = ref.read(remoteAdminTargetProvider);
    final isRemote = targetNodeNum != null;

    // Cancel stream subscriptions BEFORE saving. setDeviceConfig calls
    // _applySavedConfigToCache which emits back on deviceConfigStream.
    // If we're still listening, _applyDeviceConfig fires — and once we
    // set _hasChanges=false later, the guard is gone and a late stream
    // event can overwrite _selectedRole back to the old value.
    _configSubscription?.cancel();
    _configSubscription = null;
    _userConfigSubscription?.cancel();
    _userConfigSubscription = null;

    // Snapshot the values we are about to send so no stream or setState
    // can change them between now and the actual BLE write.
    final roleToSend =
        _selectedRole ?? config_pbenum.Config_DeviceConfig_Role.CLIENT;
    final rebroadcastToSend =
        _rebroadcastMode ??
        config_pbenum.Config_DeviceConfig_RebroadcastMode.ALL;
    final buzzerToSend =
        _buzzerMode ?? config_pbenum.Config_DeviceConfig_BuzzerMode.ALL_ENABLED;

    AppLogging.protocol(
      'DeviceConfigScreen: will send role=${roleToSend.name}, '
      'rebroadcast=${rebroadcastToSend.name}, '
      'nodeInfoBroadcastSecs=$_nodeInfoBroadcastSecs'
      '${isRemote ? " (remote admin)" : ""}',
    );

    safeSetState(() => _isSaving = true);

    try {
      final protocol = ref.read(protocolServiceProvider);

      // Determine what changed
      final nameChanged =
          _longNameController.text != _originalLongName ||
          _shortNameController.text != _originalShortName;
      final roleChanged = _selectedRole != _originalRole;
      final deviceConfigChanged =
          roleChanged ||
          _rebroadcastMode != _originalRebroadcastMode ||
          _nodeInfoBroadcastSecs != _originalNodeInfoBroadcastSecs ||
          _serialEnabled != _originalSerialEnabled ||
          _doubleTapAsButtonPress != _originalDoubleTapAsButtonPress ||
          _disableTripleClick != _originalDisableTripleClick ||
          _ledHeartbeatDisabled != _originalLedHeartbeatDisabled ||
          _tzdef != _originalTzdef ||
          _buttonGpio != _originalButtonGpio ||
          _buzzerGpio != _originalBuzzerGpio ||
          _buzzerMode != _originalBuzzerMode;
      final userFlagsChanged =
          _isUnmessagable != _originalIsUnmessagable ||
          _isLicensed != _originalIsLicensed;
      final hamModeChanged = _isLicensed && _txPower != _originalTxPower;

      AppLogging.protocol(
        'DeviceConfigScreen: Changes - nameChanged=$nameChanged, '
        'roleChanged=$roleChanged, deviceConfigChanged=$deviceConfigChanged, '
        'userFlagsChanged=$userFlagsChanged, hamModeChanged=$hamModeChanged',
      );

      if (!nameChanged &&
          !deviceConfigChanged &&
          !userFlagsChanged &&
          !hamModeChanged) {
        AppLogging.protocol('DeviceConfigScreen: No changes to save');
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      // Save device config FIRST — the role lives in Config.DeviceConfig,
      // which is the only place the firmware reads it from.  setOwnerConfig
      // (below) triggers a reboot, so if we sent it first the device would
      // reboot before this packet arrived and the role would never persist.
      if (deviceConfigChanged) {
        AppLogging.protocol(
          'DeviceConfigScreen: sending setDeviceConfig with role=${roleToSend.name}',
        );
        await protocol.setDeviceConfig(
          role: roleToSend,
          rebroadcastMode: rebroadcastToSend,
          serialEnabled: _serialEnabled,
          nodeInfoBroadcastSecs: _nodeInfoBroadcastSecs,
          ledHeartbeatDisabled: _ledHeartbeatDisabled,
          doubleTapAsButtonPress: _doubleTapAsButtonPress,
          buttonGpio: _buttonGpio,
          buzzerGpio: _buzzerGpio,
          disableTripleClick: _disableTripleClick,
          tzdef: _tzdef,
          buzzerMode: buzzerToSend,
          target: AdminTarget.fromNullable(targetNodeNum),
        );
        AppLogging.protocol(
          'DeviceConfigScreen: setDeviceConfig completed (role=${roleToSend.name})',
        );
      }

      // Save name and user flags via setOwnerConfig (setOwner admin message).
      // Role is NOT sent here — it belongs in Config.DeviceConfig above.
      // This is sent AFTER setDeviceConfig so the device processes the
      // device config before the setOwner-triggered reboot.
      if (nameChanged || userFlagsChanged) {
        await protocol.setOwnerConfig(
          longName: nameChanged ? _longNameController.text : null,
          shortName: nameChanged ? _shortNameController.text : null,
          isUnmessagable: _isUnmessagable,
          isLicensed: _isLicensed,
        );
      }

      // If licensed mode is enabled, set HAM mode parameters
      if (_isLicensed && hamModeChanged) {
        final frequency =
            double.tryParse(_frequencyOverrideController.text) ?? 0.0;
        await protocol.setHamMode(
          callSign: _longNameController.text,
          txPower: _txPower,
          frequency: frequency,
        );
      }

      AppLogging.protocol(
        'DeviceConfigScreen: Config saved${isRemote ? " (remote)" : ", device will reboot"}',
      );

      safeSetState(() => _hasChanges = false);
      if (mounted) {
        showSuccessSnackBar(
          context,
          isRemote
              ? 'Configuration sent to remote node'
              : 'Configuration saved - device rebooting',
        );
      }

      // Start global reboot countdown for local saves — banner persists
      // across navigation and auto-cancels when the device reconnects.
      // Remote admin saves don't reboot the local device.
      if (!isRemote) {
        ref
            .read(countdownProvider.notifier)
            .startDeviceRebootCountdown(reason: 'config saved');
      }

      // Pop the screen after a brief delay to let the snackbar appear
      Future.delayed(const Duration(milliseconds: 500), () {
        safeNavigatorPop();
      });
    } catch (e) {
      AppLogging.protocol('DeviceConfigScreen: Error saving config: $e');
      if (mounted) {
        showErrorSnackBar(context, 'Error saving config: $e');
      }
    } finally {
      safeSetState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myNodeNum = ref.watch(myNodeNumProvider);
    final nodes = ref.watch(nodesProvider);
    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;
    final connectedDevice = ref.watch(connectedDeviceProvider);
    final remoteState = ref.watch(remoteAdminProvider);
    final isRemote = remoteState.isRemote;

    final title = isRemote ? 'Device Config (Remote)' : 'Device Config';

    if (_isLoading) {
      return GlassScaffold(
        title: title,
        slivers: [SliverFillRemaining(child: const ScreenLoadingIndicator())],
      );
    }

    return GlassScaffold(
      title: title,
      actions: [
        if (_hasChanges)
          TextButton(
            onPressed: _isSaving ? null : _confirmAndSave,
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
              // Remote admin banner
              if (isRemote) _buildRemoteAdminBanner(context, remoteState),

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
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: context.textTertiary),
                ),
              ),

              SizedBox(height: 24),

              // User Flags Section
              _buildSectionHeader('User Flags'),
              _buildUserFlagsSettings(),

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
                              });
                              _checkForChanges();
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

              // Rebroadcast Mode Section
              _buildSectionHeader('Rebroadcast Mode'),
              _buildRebroadcastModeSelector(),

              const SizedBox(height: 24),

              // Node Info Broadcast Section
              _buildSectionHeader('Node Info Broadcast'),
              _buildNodeInfoBroadcastSetting(),

              const SizedBox(height: 24),

              // Button & Input Section
              _buildSectionHeader('Button & Input'),
              _buildButtonInputSettings(),

              const SizedBox(height: 24),

              // Buzzer Section
              _buildSectionHeader('Buzzer'),
              _buildBuzzerSettings(),

              const SizedBox(height: 24),

              // LED & Display Section
              _buildSectionHeader('LED'),
              _buildLedSettings(),

              const SizedBox(height: 24),

              // Serial Console Section
              _buildSectionHeader('Serial'),
              _buildSerialConsoleSetting(),

              const SizedBox(height: 24),

              // Timezone Section
              _buildSectionHeader('Timezone'),
              _buildTimezoneSettings(),

              const SizedBox(height: 24),

              // GPIO Section (Advanced)
              _buildSectionHeader('GPIO (Advanced)'),
              _buildGpioSettings(),

              const SizedBox(height: 24),

              // Danger Zone — only for local devices
              if (!isRemote) ...[
                _buildSectionHeader('Danger Zone'),
                _buildDangerZone(),
                const SizedBox(height: 24),
              ],

              // Warning
              if (!isRemote)
                StatusBanner.warning(
                  title:
                      'Changes to device configuration will cause the device to reboot.',
                  margin: EdgeInsets.zero,
                ),

              const SizedBox(height: 32),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildRebroadcastModeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: rebroadcastModes.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final isSelected = _rebroadcastMode == option.mode;

            return Column(
              children: [
                InkWell(
                  borderRadius: index == 0
                      ? const BorderRadius.vertical(top: Radius.circular(12))
                      : index == rebroadcastModes.length - 1
                      ? const BorderRadius.vertical(bottom: Radius.circular(12))
                      : BorderRadius.zero,
                  onTap: () {
                    setState(() => _rebroadcastMode = option.mode);
                    _checkForChanges();
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
                                      ? context.textPrimary
                                      : context.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
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
                if (index < rebroadcastModes.length - 1) _buildDivider(),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Broadcast interval options matching the official Meshtastic iOS app.
  /// The minimum is 3 hours (10 800 s); "Never" disables broadcasts.
  static const List<({int seconds, String label})> _broadcastIntervals = [
    (seconds: 10800, label: 'Three Hours'),
    (seconds: 14400, label: 'Four Hours'),
    (seconds: 18000, label: 'Five Hours'),
    (seconds: 21600, label: 'Six Hours'),
    (seconds: 43200, label: 'Twelve Hours'),
    (seconds: 64800, label: 'Eighteen Hours'),
    (seconds: 86400, label: 'Twenty Four Hours'),
    (seconds: 129600, label: 'Thirty Six Hours'),
    (seconds: 172800, label: 'Forty Eight Hours'),
    (seconds: 259200, label: 'Seventy Two Hours'),
    (seconds: 0, label: 'Never'),
  ];

  Widget _buildNodeInfoBroadcastSetting() {
    // Snap any legacy/out-of-range value to the nearest valid option so the
    // picker always has a selection.  This covers devices that were configured
    // before the picker was introduced (e.g. 900 s → snaps to 10 800 s).
    final effectiveValue = _snapToNearestInterval(_nodeInfoBroadcastSecs);

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.broadcast_on_personal,
                    color: context.accentColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Broadcast Interval',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'How often to broadcast node info to the mesh',
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
            ..._broadcastIntervals.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final isSelected = effectiveValue == option.seconds;
              final isLast = index == _broadcastIntervals.length - 1;

              return Column(
                children: [
                  if (index == 0 || true)
                    Divider(height: 1, color: context.border),
                  InkWell(
                    borderRadius: isLast
                        ? const BorderRadius.vertical(
                            bottom: Radius.circular(12),
                          )
                        : BorderRadius.zero,
                    onTap: () {
                      setState(() => _nodeInfoBroadcastSecs = option.seconds);
                      _checkForChanges();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option.label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? context.textPrimary
                                    : context.textSecondary,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check,
                              color: context.accentColor,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Snaps an arbitrary seconds value to the nearest valid broadcast interval.
  /// Returns 0 for disabled, or the closest predefined option for any other
  /// value (covers legacy configs that used the old slider).
  int _snapToNearestInterval(int seconds) {
    if (seconds == 0) return 0;
    int closest = _broadcastIntervals.first.seconds;
    int closestDiff = (seconds - closest).abs();
    for (final option in _broadcastIntervals) {
      if (option.seconds == 0) continue; // skip "Never"
      final diff = (seconds - option.seconds).abs();
      if (diff < closestDiff) {
        closest = option.seconds;
        closestDiff = diff;
      }
    }
    return closest;
  }

  Widget _buildButtonInputSettings() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: [
          _buildToggleRow(
            icon: Icons.touch_app,
            label: 'Double Tap as Button',
            subtitle: 'Treat accelerometer double-tap as button press',
            value: _doubleTapAsButtonPress,
            onChanged: (value) {
              setState(() => _doubleTapAsButtonPress = value);
              _checkForChanges();
            },
          ),
          _buildDivider(),
          _buildToggleRow(
            icon: Icons.touch_app_outlined,
            label: 'Disable Triple Click',
            subtitle: 'Disable triple-click to toggle GPS',
            value: _disableTripleClick,
            onChanged: (value) {
              setState(() => _disableTripleClick = value);
              _checkForChanges();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBuzzerSettings() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: buzzerModes.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final isSelected = _buzzerMode == option.mode;

            return Column(
              children: [
                InkWell(
                  borderRadius: index == 0
                      ? const BorderRadius.vertical(top: Radius.circular(12))
                      : index == buzzerModes.length - 1
                      ? const BorderRadius.vertical(bottom: Radius.circular(12))
                      : BorderRadius.zero,
                  onTap: () {
                    setState(() => _buzzerMode = option.mode);
                    _checkForChanges();
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
                                      ? context.textPrimary
                                      : context.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
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
                if (index < buzzerModes.length - 1) _buildDivider(),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLedSettings() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: _buildToggleRow(
        icon: Icons.lightbulb_outline,
        label: 'Disable LED Heartbeat',
        subtitle: 'Turn off the blinking status LED',
        value: _ledHeartbeatDisabled,
        onChanged: (value) {
          setState(() => _ledHeartbeatDisabled = value);
          _checkForChanges();
        },
      ),
    );
  }

  Widget _buildTimezoneSettings() {
    return Container(
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
              Icon(Icons.schedule, color: context.accentColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'POSIX Timezone',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'e.g. EST5EDT,M3.2.0,M11.1.0',
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
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('tzdef_${_tzdef.hashCode}'),
            initialValue: _tzdef,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.textPrimary),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              hintText: 'Leave empty for UTC',
              hintStyle: TextStyle(color: context.textTertiary),
              filled: true,
              fillColor: context.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: context.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: context.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: context.accentColor),
              ),
            ),
            onChanged: (value) {
              _tzdef = value;
              _checkForChanges();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGpioSettings() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Only change these if you know your hardware requires custom GPIO pins.',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: context.textTertiary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildGpioField(
                  label: 'Button GPIO',
                  value: _buttonGpio,
                  onChanged: (value) {
                    _buttonGpio = value;
                    _checkForChanges();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildGpioField(
                  label: 'Buzzer GPIO',
                  value: _buzzerGpio,
                  onChanged: (value) {
                    _buzzerGpio = value;
                    _checkForChanges();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGpioField({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          key: ValueKey('numField_$value'),
          initialValue: value == 0 ? '' : value.toString(),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            hintText: '0',
            hintStyle: TextStyle(color: context.textTertiary),
            filled: true,
            fillColor: context.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.accentColor),
            ),
          ),
          onChanged: (text) {
            onChanged(int.tryParse(text) ?? 0);
          },
        ),
      ],
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: context.accentColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: context.textTertiary),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: context.accentColor,
          ),
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

  Widget _buildUserFlagsSettings() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: [
          // Unmessagable toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.speaker_notes_off,
                  color: _isUnmessagable
                      ? context.accentColor
                      : context.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unmessagable',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Mark as infrastructure node that won\'t respond to messages',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                ThemedSwitch(
                  value: _isUnmessagable,
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    setState(() => _isUnmessagable = value);
                    _checkForChanges();
                  },
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.border.withValues(alpha: 0.5)),
          // Licensed operator toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.badge,
                  color: _isLicensed
                      ? context.accentColor
                      : context.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Licensed Operator (Ham)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sets call sign, overrides frequency/power, '
                        'disables encryption',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                ThemedSwitch(
                  value: _isLicensed,
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    setState(() => _isLicensed = value);
                    _checkForChanges();
                  },
                ),
              ],
            ),
          ),
          // Ham mode settings (only shown when licensed)
          if (_isLicensed) ...[
            Divider(height: 1, color: context.border.withValues(alpha: 0.5)),
            Container(
              margin: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusBanner.accent(
                    title:
                        'Ham mode uses your long name as call sign (max 8 chars), '
                        'broadcasts node info every 10 minutes, overrides '
                        'frequency, duty cycle, and TX power, and disables '
                        'encryption.',
                    margin: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 12),
                  StatusBanner.warning(
                    title:
                        'HAM nodes cannot relay encrypted traffic. Other '
                        'non-HAM nodes in your mesh will not be able to '
                        'route encrypted messages through this node, '
                        'creating a relay gap in the network.',
                    margin: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),
                  // Frequency override
                  Text(
                    'Frequency Override (MHz)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _frequencyOverrideController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(color: context.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '0.0 (use default)',
                      hintStyle: TextStyle(color: context.textTertiary),
                      filled: true,
                      fillColor: context.background,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: context.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: context.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: context.accentColor),
                      ),
                    ),
                    onChanged: (_) => _checkForChanges(),
                  ),
                  const SizedBox(height: 16),
                  // TX Power
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TX Power',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: context.textPrimary,
                        ),
                      ),
                      Text(
                        '$_txPower dBm',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: context.accentColor,
                      inactiveTrackColor: context.border,
                      thumbColor: context.accentColor,
                      overlayColor: context.accentColor.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: _txPower.toDouble(),
                      min: 1,
                      max: 30,
                      divisions: 29,
                      onChanged: (value) {
                        setState(() => _txPower = value.toInt());
                        _checkForChanges();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRemoteAdminBanner(
    BuildContext context,
    RemoteAdminState remoteState,
  ) {
    final accentColor = context.accentColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.15),
            accentColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.admin_panel_settings, color: accentColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Remote Administration',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Configuring: ${remoteState.targetNodeName ?? '0x${remoteState.targetNodeNum!.toRadixString(16)}'}',
                  style: TextStyle(
                    color: accentColor.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSerialConsoleSetting() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: _buildToggleRow(
        icon: Icons.terminal,
        label: 'Serial Console',
        subtitle: 'Enable serial port for debugging',
        value: _serialEnabled,
        onChanged: (value) {
          setState(() => _serialEnabled = value);
          _checkForChanges();
        },
      ),
    );
  }

  Widget _buildDangerZone() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: [
          // NodeDB Reset
          InkWell(
            onTap: _showNodeDbResetConfirm,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.warningYellow.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.refresh,
                      color: AppTheme.warningYellow,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reset Node Database',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Clear all stored node information',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: context.textTertiary),
                ],
              ),
            ),
          ),
          _buildDivider(),
          // Factory Reset
          InkWell(
            onTap: _showFactoryResetConfirm,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.warning_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Factory Reset',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Reset device to factory defaults',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: context.textTertiary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showNodeDbResetConfirm() async {
    // Capture provider before any await
    final protocol = ref.read(protocolServiceProvider);

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: 'Reset Node Database',
      message:
          'This will clear all stored node information from the device. '
          'The mesh network will need to rediscover all nodes.\n\n'
          'Are you sure you want to continue?',
      confirmLabel: 'Reset',
    );

    if (!mounted) return;
    if (confirmed == true) {
      try {
        await protocol.nodeDbReset();
        if (mounted) {
          showSuccessSnackBar(context, 'Node database reset initiated');
        }
      } catch (e) {
        if (mounted) {
          showErrorSnackBar(context, 'Failed to reset: $e');
        }
      }
    }
  }

  Future<void> _showFactoryResetConfirm() async {
    // Capture provider before any await
    final protocol = ref.read(protocolServiceProvider);

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: 'Factory Reset',
      message:
          'This will reset ALL device settings to factory defaults, '
          'including channels, configuration, and stored data.\n\n'
          'This action cannot be undone!',
      confirmLabel: 'Factory Reset',
    );

    if (!mounted) return;
    if (confirmed == true) {
      AppLogging.protocol('DeviceConfig: Factory reset confirmed');
      try {
        await protocol.factoryResetDevice();
        AppLogging.protocol('DeviceConfig: factoryResetDevice command sent');
        if (mounted) {
          showSuccessSnackBar(
            context,
            'Factory reset initiated - device will restart',
          );
        }
      } catch (e) {
        AppLogging.protocol('DeviceConfig: factoryResetDevice FAILED: $e');
        if (mounted) {
          showErrorSnackBar(context, 'Failed to reset: $e');
        }
      }
    }
  }
}
