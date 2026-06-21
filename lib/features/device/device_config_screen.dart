// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: keyboard-dismissal — config screen with TextFormFields in sub-sections
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/transport.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/info_table.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/number_format.dart';
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

List<DeviceRoleOption> _deviceRoleOptions(BuildContext context) => [
  DeviceRoleOption(
    config_pbenum.Config_DeviceConfig_Role.CLIENT,
    context.l10n.deviceConfigRoleClient,
    context.l10n.deviceConfigRoleClientDesc,
  ),
  DeviceRoleOption(
    config_pbenum.Config_DeviceConfig_Role.CLIENT_MUTE,
    context.l10n.deviceConfigRoleClientMute,
    context.l10n.deviceConfigRoleClientMuteDesc,
  ),
  DeviceRoleOption(
    config_pbenum.Config_DeviceConfig_Role.CLIENT_HIDDEN,
    context.l10n.deviceConfigRoleClientHidden,
    context.l10n.deviceConfigRoleClientHiddenDesc,
  ),
  DeviceRoleOption(
    config_pbenum.Config_DeviceConfig_Role.CLIENT_BASE,
    context.l10n.deviceConfigRoleClientBase,
    context.l10n.deviceConfigRoleClientBaseDesc,
  ),
  DeviceRoleOption(
    config_pbenum.Config_DeviceConfig_Role.ROUTER,
    context.l10n.deviceConfigRoleRouter,
    context.l10n.deviceConfigRoleRouterDesc,
  ),
  DeviceRoleOption(
    config_pbenum.Config_DeviceConfig_Role.ROUTER_LATE,
    context.l10n.deviceConfigRoleRouterLate,
    context.l10n.deviceConfigRoleRouterLateDesc,
  ),
  DeviceRoleOption(
    config_pbenum.Config_DeviceConfig_Role.TRACKER,
    context.l10n.deviceConfigRoleTracker,
    context.l10n.deviceConfigRoleTrackerDesc,
  ),
  DeviceRoleOption(
    config_pbenum.Config_DeviceConfig_Role.SENSOR,
    context.l10n.deviceConfigRoleSensor,
    context.l10n.deviceConfigRoleSensorDesc,
  ),
  DeviceRoleOption(
    config_pbenum.Config_DeviceConfig_Role.TAK,
    context.l10n.deviceConfigRoleTak,
    context.l10n.deviceConfigRoleTakDesc,
  ),
  DeviceRoleOption(
    config_pbenum.Config_DeviceConfig_Role.TAK_TRACKER,
    context.l10n.deviceConfigRoleTakTracker,
    context.l10n.deviceConfigRoleTakTrackerDesc,
  ),
  DeviceRoleOption(
    config_pbenum.Config_DeviceConfig_Role.LOST_AND_FOUND,
    context.l10n.deviceConfigRoleLostAndFound,
    context.l10n.deviceConfigRoleLostAndFoundDesc,
  ),
];

/// Rebroadcast mode options with descriptions
class RebroadcastModeOption {
  final config_pbenum.Config_DeviceConfig_RebroadcastMode mode;
  final String displayName;
  final String description;

  const RebroadcastModeOption(this.mode, this.displayName, this.description);
}

List<RebroadcastModeOption> _rebroadcastModeOptions(BuildContext context) => [
  RebroadcastModeOption(
    config_pbenum.Config_DeviceConfig_RebroadcastMode.ALL,
    context.l10n.deviceConfigRebroadcastAll,
    context.l10n.deviceConfigRebroadcastAllDesc,
  ),
  RebroadcastModeOption(
    config_pbenum.Config_DeviceConfig_RebroadcastMode.ALL_SKIP_DECODING,
    context.l10n.deviceConfigRebroadcastAllSkipDecoding,
    context.l10n.deviceConfigRebroadcastAllSkipDecodingDesc,
  ),
  RebroadcastModeOption(
    config_pbenum.Config_DeviceConfig_RebroadcastMode.LOCAL_ONLY,
    context.l10n.deviceConfigRebroadcastLocalOnly,
    context.l10n.deviceConfigRebroadcastLocalOnlyDesc,
  ),
  RebroadcastModeOption(
    config_pbenum.Config_DeviceConfig_RebroadcastMode.KNOWN_ONLY,
    context.l10n.deviceConfigRebroadcastKnownOnly,
    context.l10n.deviceConfigRebroadcastKnownOnlyDesc,
  ),
  RebroadcastModeOption(
    config_pbenum.Config_DeviceConfig_RebroadcastMode.CORE_PORTNUMS_ONLY,
    context.l10n.deviceConfigRebroadcastCorePortnumsOnly,
    context.l10n.deviceConfigRebroadcastCorePortnumsOnlyDesc,
  ),
  RebroadcastModeOption(
    config_pbenum.Config_DeviceConfig_RebroadcastMode.NONE,
    context.l10n.deviceConfigRebroadcastNone,
    context.l10n.deviceConfigRebroadcastNoneDesc,
  ),
];

/// Buzzer mode options with descriptions
class BuzzerModeOption {
  final config_pbenum.Config_DeviceConfig_BuzzerMode mode;
  final String displayName;
  final String description;

  const BuzzerModeOption(this.mode, this.displayName, this.description);
}

List<BuzzerModeOption> _buzzerModeOptions(BuildContext context) => [
  BuzzerModeOption(
    config_pbenum.Config_DeviceConfig_BuzzerMode.ALL_ENABLED,
    context.l10n.deviceConfigBuzzerAllEnabled,
    context.l10n.deviceConfigBuzzerAllEnabledDesc,
  ),
  BuzzerModeOption(
    config_pbenum.Config_DeviceConfig_BuzzerMode.NOTIFICATIONS_ONLY,
    context.l10n.deviceConfigBuzzerNotificationsOnly,
    context.l10n.deviceConfigBuzzerNotificationsOnlyDesc,
  ),
  BuzzerModeOption(
    config_pbenum.Config_DeviceConfig_BuzzerMode.DIRECT_MSG_ONLY,
    context.l10n.deviceConfigBuzzerDirectMsgOnly,
    context.l10n.deviceConfigBuzzerDirectMsgOnlyDesc,
  ),
  BuzzerModeOption(
    config_pbenum.Config_DeviceConfig_BuzzerMode.SYSTEM_ONLY,
    context.l10n.deviceConfigBuzzerSystemOnly,
    context.l10n.deviceConfigBuzzerSystemOnlyDesc,
  ),
  BuzzerModeOption(
    config_pbenum.Config_DeviceConfig_BuzzerMode.DISABLED,
    context.l10n.deviceConfigBuzzerDisabled,
    context.l10n.deviceConfigBuzzerDisabledDesc,
  ),
];

class _DeviceInfoDisplayData {
  const _DeviceInfoDisplayData({
    required this.bleName,
    required this.hardware,
    required this.userId,
    required this.nodeNumber,
  });

  final String bleName;
  final String hardware;
  final String userId;
  final String nodeNumber;

  factory _DeviceInfoDisplayData.fromContext({
    required BuildContext context,
    required bool isRemote,
    required DeviceInfo? connectedDevice,
    required MeshNode? localNode,
    required MeshNode? remoteNode,
    required int? remoteTargetNodeNum,
  }) {
    final unknown = context.l10n.deviceConfigUnknown;
    final displayNode = isRemote ? remoteNode : localNode;

    // Remote config is bound to the selected mesh node, never the local
    // connected peripheral. If the remote cache lacks a field, keep it
    // explicitly missing instead of borrowing unrelated local identity.
    return _DeviceInfoDisplayData(
      bleName: isRemote ? unknown : connectedDevice?.name ?? unknown,
      hardware: displayNode?.hardwareModel ?? unknown,
      userId: displayNode?.userId ?? unknown,
      nodeNumber:
          displayNode?.nodeNum.toString() ??
          (isRemote ? remoteTargetNodeNum?.toString() ?? unknown : unknown),
    );
  }
}

class _DeviceInfoSection extends StatelessWidget {
  const _DeviceInfoSection({required this.deviceInfo});

  final _DeviceInfoDisplayData deviceInfo;

  @override
  Widget build(BuildContext context) {
    return InfoTable(
      rows: [
        InfoTableRow(
          label: context.l10n.deviceConfigBleName,
          value: deviceInfo.bleName,
          icon: Icons.bluetooth,
        ),
        InfoTableRow(
          label: context.l10n.deviceConfigHardware,
          value: deviceInfo.hardware,
          icon: Icons.memory_outlined,
        ),
        InfoTableRow(
          label: context.l10n.deviceConfigUserId,
          value: deviceInfo.userId,
          icon: Icons.fingerprint,
        ),
        InfoTableRow(
          label: context.l10n.deviceConfigNodeNumber,
          value: deviceInfo.nodeNumber,
          icon: Icons.tag,
        ),
      ],
    );
  }
}

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
  late TextEditingController _tzdefController;
  String _originalTzdef = '';
  late TextEditingController _buttonGpioController;
  int _originalButtonGpio = 0;
  late TextEditingController _buzzerGpioController;
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
    _tzdefController = TextEditingController();
    _buttonGpioController = TextEditingController();
    _buzzerGpioController = TextEditingController();
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
    _tzdefController.dispose();
    _buttonGpioController.dispose();
    _buzzerGpioController.dispose();
    super.dispose();
  }

  void _applyDeviceConfig(config_pb.Config_DeviceConfig config) {
    safeSetState(() {
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
        _tzdefController.text = config.tzdef;
        _buttonGpioController.text = config.buttonGpio == 0
            ? ''
            : config.buttonGpio.toString();
        _buzzerGpioController.text = config.buzzerGpio == 0
            ? ''
            : config.buzzerGpio.toString();
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
    safeSetState(() {
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
    final tzdefChanged = _tzdefController.text != _originalTzdef;
    final buttonGpioChanged =
        (int.tryParse(_buttonGpioController.text) ?? 0) != _originalButtonGpio;
    final buzzerGpioChanged =
        (int.tryParse(_buzzerGpioController.text) ?? 0) != _originalBuzzerGpio;
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
      title: context.l10n.deviceConfigSaveChangesTitle,
      message: context.l10n.deviceConfigSaveChangesMessage,
      confirmLabel: context.l10n.deviceConfigSaveAndReboot,
    );

    if (confirmed == true) {
      await _saveConfig();
    }
  }

  Future<void> _saveConfig() async {
    AppLogging.protocol('DeviceConfigScreen: _saveConfig started');

    // Capture remote admin target before any async work.
    if (!mounted) return;
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
          _tzdefController.text != _originalTzdef ||
          (int.tryParse(_buttonGpioController.text) ?? 0) !=
              _originalButtonGpio ||
          (int.tryParse(_buzzerGpioController.text) ?? 0) !=
              _originalBuzzerGpio ||
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
          buttonGpio: int.tryParse(_buttonGpioController.text) ?? 0,
          buzzerGpio: int.tryParse(_buzzerGpioController.text) ?? 0,
          disableTripleClick: _disableTripleClick,
          tzdef: _tzdefController.text,
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
          target: AdminTarget.fromNullable(targetNodeNum),
        );
      }

      // If licensed mode is enabled, set HAM mode parameters.
      // Locale-aware parse: accepts both "869.075" and "869,075".
      if (_isLicensed && hamModeChanged) {
        final frequency =
            NumberFormatUtils.tryParseLocaleDouble(
              _frequencyOverrideController.text,
            ) ??
            0.0;
        await protocol.setHamMode(
          callSign: _longNameController.text,
          txPower: _txPower,
          frequency: frequency,
          target: AdminTarget.fromNullable(targetNodeNum),
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
              ? context.l10n.deviceConfigSavedRemote
              : context.l10n.deviceConfigSavedLocal,
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
        showErrorSnackBar(
          context,
          context.l10n.deviceConfigSaveError(e.toString()),
        );
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
    final targetNodeNum = remoteState.targetNodeNum;
    final remoteNode = targetNodeNum != null ? nodes[targetNodeNum] : null;
    final deviceInfo = _DeviceInfoDisplayData.fromContext(
      context: context,
      isRemote: isRemote,
      connectedDevice: connectedDevice,
      localNode: myNode,
      remoteNode: remoteNode,
      remoteTargetNodeNum: targetNodeNum,
    );
    final deviceRolesList = _deviceRoleOptions(context);

    final title = isRemote
        ? context.l10n.deviceConfigTitleRemote
        : context.l10n.deviceConfigTitle;

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
                    context.l10n.deviceConfigSave,
                    style: TextStyle(
                      color: context.accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
      ],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Remote admin banner
              if (isRemote) _buildRemoteAdminBanner(context, remoteState),

              // Long Name Field
              _buildNameField(
                icon: Icons.badge_outlined,
                label: context.l10n.deviceConfigLongName,
                subtitle: context.l10n.deviceConfigLongNameSubtitle,
                controller: _longNameController,
                maxLength: maxLongNameLength,
                hint: context.l10n.deviceConfigLongNameHint,
                inputFormatters: [
                  Utf8ByteLengthLimitingTextInputFormatter(maxLongNameLength),
                ],
              ),

              SizedBox(height: AppTheme.spacing16),

              // Short Name Field
              _buildNameField(
                icon: Icons.short_text,
                label: context.l10n.deviceConfigShortName,
                subtitle: context.l10n.deviceConfigShortNameSubtitle(
                  maxShortNameLength,
                ),
                controller: _shortNameController,
                maxLength: maxShortNameLength,
                hint: context.l10n.deviceConfigShortNameHint,
                inputFormatters: [
                  Utf8ByteLengthLimitingTextInputFormatter(maxShortNameLength),
                ],
              ),

              const SizedBox(height: AppTheme.spacing8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  context.l10n.deviceConfigNameHelpText,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: context.textTertiary),
                ),
              ),

              SizedBox(height: AppTheme.spacing24),

              // User Flags Section
              _buildSectionHeader(context.l10n.deviceConfigSectionUserFlags),
              _buildUserFlagsSettings(),

              SizedBox(height: AppTheme.spacing24),

              // Device Info Section
              _buildSectionHeader(context.l10n.deviceConfigSectionDeviceInfo),
              _DeviceInfoSection(deviceInfo: deviceInfo),

              const SizedBox(height: AppTheme.spacing24),

              // Device Role Section
              _buildSectionHeader(context.l10n.deviceConfigSectionDeviceRole),
              Container(
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  border: Border.all(color: context.border),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  child: Column(
                    children: deviceRolesList.asMap().entries.map((entry) {
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
                                : index == deviceRolesList.length - 1
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
                                  const SizedBox(width: AppTheme.spacing12),
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
                                        SizedBox(height: AppTheme.spacing2),
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
                          if (index < deviceRolesList.length - 1)
                            _buildDivider(),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.spacing32),

              // Rebroadcast Mode Section
              _buildSectionHeader(
                context.l10n.deviceConfigSectionRebroadcastMode,
              ),
              _buildRebroadcastModeSelector(),

              const SizedBox(height: AppTheme.spacing24),

              // Node Info Broadcast Section
              _buildSectionHeader(
                context.l10n.deviceConfigSectionNodeInfoBroadcast,
              ),
              _buildNodeInfoBroadcastSetting(),

              const SizedBox(height: AppTheme.spacing24),

              // Button & Input Section
              _buildSectionHeader(context.l10n.deviceConfigSectionButtonInput),
              _buildButtonInputSettings(),

              const SizedBox(height: AppTheme.spacing24),

              // Buzzer Section
              _buildSectionHeader(context.l10n.deviceConfigSectionBuzzer),
              _buildBuzzerSettings(),

              const SizedBox(height: AppTheme.spacing24),

              // LED & Display Section
              _buildSectionHeader(context.l10n.deviceConfigSectionLed),
              _buildLedSettings(),

              const SizedBox(height: AppTheme.spacing24),

              // Serial Console Section
              _buildSectionHeader(context.l10n.deviceConfigSectionSerial),
              _buildSerialConsoleSetting(),

              const SizedBox(height: AppTheme.spacing24),

              // Timezone Section
              _buildSectionHeader(context.l10n.deviceConfigSectionTimezone),
              _buildTimezoneSettings(),

              const SizedBox(height: AppTheme.spacing24),

              // GPIO Section (Advanced)
              _buildSectionHeader(context.l10n.deviceConfigSectionGpio),
              _buildGpioSettings(),

              const SizedBox(height: AppTheme.spacing24),

              // Danger Zone — only for local devices
              if (!isRemote) ...[
                _buildSectionHeader(context.l10n.deviceConfigSectionDangerZone),
                _buildDangerZone(),
                const SizedBox(height: AppTheme.spacing24),
              ],

              // Warning
              if (!isRemote)
                StatusBanner.warning(
                  title: context.l10n.deviceConfigRebootWarning,
                  margin: EdgeInsets.zero,
                ),

              const SizedBox(height: AppTheme.spacing32),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildRebroadcastModeSelector() {
    final modes = _rebroadcastModeOptions(context);
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Column(
          children: modes.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final isSelected = _rebroadcastMode == option.mode;

            return Column(
              children: [
                InkWell(
                  borderRadius: index == 0
                      ? const BorderRadius.vertical(top: Radius.circular(12))
                      : index == modes.length - 1
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
                        const SizedBox(width: AppTheme.spacing12),
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
                              const SizedBox(height: AppTheme.spacing2),
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
                if (index < modes.length - 1) _buildDivider(),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Broadcast interval seconds for snapping legacy values.
  static const List<int> _broadcastIntervalSeconds = [
    10800,
    14400,
    18000,
    21600,
    43200,
    64800,
    86400,
    129600,
    172800,
    259200,
    0,
  ];

  /// Broadcast interval options matching the official Meshtastic iOS app.
  /// The minimum is 3 hours (10 800 s); "Never" disables broadcasts.
  List<({int seconds, String label})> _getBroadcastIntervals() => [
    (seconds: 10800, label: context.l10n.deviceConfigBroadcastThreeHours),
    (seconds: 14400, label: context.l10n.deviceConfigBroadcastFourHours),
    (seconds: 18000, label: context.l10n.deviceConfigBroadcastFiveHours),
    (seconds: 21600, label: context.l10n.deviceConfigBroadcastSixHours),
    (seconds: 43200, label: context.l10n.deviceConfigBroadcastTwelveHours),
    (seconds: 64800, label: context.l10n.deviceConfigBroadcastEighteenHours),
    (seconds: 86400, label: context.l10n.deviceConfigBroadcastTwentyFourHours),
    (seconds: 129600, label: context.l10n.deviceConfigBroadcastThirtySixHours),
    (seconds: 172800, label: context.l10n.deviceConfigBroadcastFortyEightHours),
    (seconds: 259200, label: context.l10n.deviceConfigBroadcastSeventyTwoHours),
    (seconds: 0, label: context.l10n.deviceConfigBroadcastNever),
  ];

  Widget _buildNodeInfoBroadcastSetting() {
    final intervals = _getBroadcastIntervals();
    // Snap any legacy/out-of-range value to the nearest valid option so the
    // picker always has a selection.  This covers devices that were configured
    // before the picker was introduced (e.g. 900 s → snaps to 10 800 s).
    final effectiveValue = _snapToNearestInterval(_nodeInfoBroadcastSecs);

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                16,
                16,
                12,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.broadcast_on_personal,
                    color: context.accentColor,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.deviceConfigBroadcastInterval,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing2),
                        Text(
                          context.l10n.deviceConfigBroadcastIntervalSubtitle,
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
            ...intervals.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final isSelected = effectiveValue == option.seconds;
              final isLast = index == intervals.length - 1;

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
    int closest = _broadcastIntervalSeconds.first;
    int closestDiff = (seconds - closest).abs();
    for (final s in _broadcastIntervalSeconds) {
      if (s == 0) continue; // skip "Never"
      final diff = (seconds - s).abs();
      if (diff < closestDiff) {
        closest = s;
        closestDiff = diff;
      }
    }
    return closest;
  }

  Widget _buildButtonInputSettings() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: [
          _buildToggleRow(
            icon: Icons.touch_app,
            label: context.l10n.deviceConfigDoubleTapAsButton,
            subtitle: context.l10n.deviceConfigDoubleTapAsButtonSubtitle,
            value: _doubleTapAsButtonPress,
            onChanged: (value) {
              setState(() => _doubleTapAsButtonPress = value);
              _checkForChanges();
            },
          ),
          _buildDivider(),
          _buildToggleRow(
            icon: Icons.touch_app_outlined,
            label: context.l10n.deviceConfigDisableTripleClick,
            subtitle: context.l10n.deviceConfigDisableTripleClickSubtitle,
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
    final buzzerOptions = _buzzerModeOptions(context);
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Column(
          children: buzzerOptions.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final isSelected = _buzzerMode == option.mode;

            return Column(
              children: [
                InkWell(
                  borderRadius: index == 0
                      ? const BorderRadius.vertical(top: Radius.circular(12))
                      : index == buzzerOptions.length - 1
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
                        const SizedBox(width: AppTheme.spacing12),
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
                              const SizedBox(height: AppTheme.spacing2),
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
                if (index < buzzerOptions.length - 1) _buildDivider(),
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
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: _buildToggleRow(
        icon: Icons.lightbulb_outline,
        label: context.l10n.deviceConfigDisableLedHeartbeat,
        subtitle: context.l10n.deviceConfigDisableLedHeartbeatSubtitle,
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
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: context.accentColor, size: 20),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.deviceConfigPosixTimezone,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    Text(
                      context.l10n.deviceConfigPosixTimezoneExample,
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
          const SizedBox(height: AppTheme.spacing12),
          TextFormField(
            key: const ValueKey('tzdef'),
            controller: _tzdefController,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.textPrimary),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              hintText: context.l10n.deviceConfigPosixTimezoneHint,
              hintStyle: TextStyle(color: context.textTertiary),
              filled: true,
              fillColor: context.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                borderSide: BorderSide(color: context.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                borderSide: BorderSide(color: context.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                borderSide: BorderSide(color: context.accentColor),
              ),
            ),
            onChanged: (_) {
              _checkForChanges();
            },
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            context.l10n.deviceConfigTimezoneScopeNote,
            style: TextStyle(fontSize: 12, color: context.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildGpioSettings() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.deviceConfigGpioWarning,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: context.textTertiary),
          ),
          const SizedBox(height: AppTheme.spacing16),
          Row(
            children: [
              Expanded(
                child: _buildGpioField(
                  label: context.l10n.deviceConfigButtonGpio,
                  fieldKey: 'buttonGpio',
                  controller: _buttonGpioController,
                  onChanged: _checkForChanges,
                ),
              ),
              const SizedBox(width: AppTheme.spacing16),
              Expanded(
                child: _buildGpioField(
                  label: context.l10n.deviceConfigBuzzerGpio,
                  fieldKey: 'buzzerGpio',
                  controller: _buzzerGpioController,
                  onChanged: _checkForChanges,
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
    required String fieldKey,
    required TextEditingController controller,
    required VoidCallback onChanged,
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
        const SizedBox(height: AppTheme.spacing6),
        TextFormField(
          key: ValueKey(fieldKey),
          controller: controller,
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
            hintText: '0', // lint-allow: hardcoded-string
            hintStyle: TextStyle(color: context.textTertiary),
            filled: true,
            fillColor: context.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius8),
              borderSide: BorderSide(color: context.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius8),
              borderSide: BorderSide(color: context.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius8),
              borderSide: BorderSide(color: context.accentColor),
            ),
          ),
          onChanged: (_) => onChanged(),
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
          const SizedBox(width: AppTheme.spacing12),
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
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: context.textTertiary),
                ),
              ],
            ),
          ),
          ThemedSwitch(value: value, onChanged: onChanged),
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
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with label
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radius10),
                  ),
                  child: Icon(icon, color: context.accentColor, size: 20),
                ),
                SizedBox(width: AppTheme.spacing14),
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
                      const SizedBox(height: AppTheme.spacing2),
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
                Builder(
                  builder: (_) {
                    final used = utf8ByteLength(controller.text);
                    final atLimit = used >= maxLength;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: atLimit
                            ? AppTheme.warningYellow.withValues(alpha: 0.15)
                            : context.background,
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                      ),
                      child: Text(
                        '$used/$maxLength',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: atLimit
                              ? AppTheme.warningYellow
                              : context.textTertiary,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Input field area
          Container(
            margin: const EdgeInsets.fromLTRB(AppTheme.spacing16, 0, 16, 16),
            decoration: BoxDecoration(
              color: context.background,
              borderRadius: BorderRadius.circular(AppTheme.radius10),
              border: Border.all(color: context.border.withValues(alpha: 0.5)),
            ),
            child: TextField(
              controller: controller,
              inputFormatters: inputFormatters,
              style: TextStyle(
                fontSize: 15,
                color: context.textPrimary,

                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.all(AppTheme.spacing16),
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
        borderRadius: BorderRadius.circular(AppTheme.radius12),
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
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.deviceConfigUnmessagable,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing2),
                      Text(
                        context.l10n.deviceConfigUnmessagableSubtitle,
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
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.deviceConfigLicensedOperator,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing2),
                      Text(
                        context.l10n.deviceConfigLicensedOperatorSubtitle,
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
              margin: const EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusBanner.accent(
                    title: context.l10n.deviceConfigHamModeInfo,
                    margin: EdgeInsets.zero,
                  ),
                  const SizedBox(height: AppTheme.spacing12),
                  StatusBanner.warning(
                    title: context.l10n.deviceConfigHamModeWarning,
                    margin: EdgeInsets.zero,
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  // Frequency override
                  Text(
                    context.l10n.deviceConfigFrequencyOverride,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  TextField(
                    controller: _frequencyOverrideController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    // Restrict to digits + decimal separators (dot OR
                    // comma). Locale-aware parse normalises on commit.
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    style: TextStyle(color: context.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: context.l10n.deviceConfigFrequencyOverrideHint,
                      hintStyle: TextStyle(color: context.textTertiary),
                      filled: true,
                      fillColor: context.background,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                        borderSide: BorderSide(color: context.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                        borderSide: BorderSide(color: context.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                        borderSide: BorderSide(color: context.accentColor),
                      ),
                    ),
                    onChanged: (_) => _checkForChanges(),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  // TX Power
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.deviceConfigTxPower,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: context.textPrimary,
                        ),
                      ),
                      Text(
                        context.l10n.deviceConfigTxPowerValue(_txPower),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacing8),
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
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.15),
            accentColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: accentColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.admin_panel_settings, color: accentColor, size: 24),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.deviceConfigRemoteAdminTitle,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  context.l10n.deviceConfigRemoteAdminConfiguring(
                    remoteState.targetNodeName ??
                        '0x${remoteState.targetNodeNum!.toRadixString(16)}',
                  ),
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
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: _buildToggleRow(
        icon: Icons.terminal,
        label: context.l10n.deviceConfigSerialConsole,
        subtitle: context.l10n.deviceConfigSerialConsoleSubtitle,
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
        borderRadius: BorderRadius.circular(AppTheme.radius12),
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
                      borderRadius: BorderRadius.circular(AppTheme.radius10),
                    ),
                    child: Icon(
                      Icons.refresh,
                      color: AppTheme.warningYellow,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.deviceConfigResetNodeDb,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing2),
                        Text(
                          context.l10n.deviceConfigResetNodeDbSubtitle,
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
                      color: AppTheme.errorRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radius10),
                    ),
                    child: Icon(
                      Icons.warning_rounded,
                      color: AppTheme.errorRed,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.deviceConfigFactoryReset,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.errorRed,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing2),
                        Text(
                          context.l10n.deviceConfigFactoryResetSubtitle,
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
    // Capture providers before any await
    final protocol = ref.read(protocolServiceProvider);
    final target = AdminTarget.fromNullable(
      ref.read(remoteAdminTargetProvider),
    );

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.deviceConfigResetNodeDbDialogTitle,
      message: context.l10n.deviceConfigResetNodeDbDialogMessage,
      confirmLabel: context.l10n.deviceConfigResetNodeDbDialogConfirm,
    );

    if (!mounted) return;
    if (confirmed == true) {
      try {
        await protocol.nodeDbReset(target: target);
        if (mounted) {
          showSuccessSnackBar(
            context,
            context.l10n.deviceConfigResetNodeDbSuccess,
          );
        }
      } catch (e) {
        if (mounted) {
          showErrorSnackBar(
            context,
            context.l10n.deviceConfigResetNodeDbError(e.toString()),
          );
        }
      }
    }
  }

  Future<void> _showFactoryResetConfirm() async {
    // Capture providers before any await
    final protocol = ref.read(protocolServiceProvider);
    final target = AdminTarget.fromNullable(
      ref.read(remoteAdminTargetProvider),
    );

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.deviceConfigFactoryResetDialogTitle,
      message: context.l10n.deviceConfigFactoryResetDialogMessage,
      confirmLabel: context.l10n.deviceConfigFactoryResetDialogConfirm,
    );

    if (!mounted) return;
    if (confirmed == true) {
      AppLogging.protocol('DeviceConfig: Factory reset confirmed');
      try {
        await protocol.factoryResetDevice(target: target);
        AppLogging.protocol('DeviceConfig: factoryResetDevice command sent');
        if (mounted) {
          if (target.isLocal) {
            ref
                .read(countdownProvider.notifier)
                .startDeviceRebootCountdown(reason: 'factory reset');
          }
          showSuccessSnackBar(
            context,
            context.l10n.deviceConfigFactoryResetSuccess,
          );
        }
      } catch (e) {
        AppLogging.protocol('DeviceConfig: factoryResetDevice FAILED: $e');
        if (mounted) {
          showErrorSnackBar(
            context,
            context.l10n.deviceConfigFactoryResetError(e.toString()),
          );
        }
      }
    }
  }
}
