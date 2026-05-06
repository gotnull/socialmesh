// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/meshcore_constants.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/info_table.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/settings_primitives.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../services/meshcore/protocol/meshcore_frame.dart';
import '../../../services/meshcore/protocol/meshcore_messages.dart';
import '../../../services/meshcore/storage/meshcore_node_name_store.dart';
import '../../../utils/snackbar.dart';
import '../../navigation/meshcore_shell.dart';
import '../widgets/meshcore_radio_settings_sheet.dart';

/// MeshCore Settings screen.
///
/// Provides device info, node settings, radio settings, and device actions.
class MeshCoreSettingsScreen extends ConsumerStatefulWidget {
  const MeshCoreSettingsScreen({super.key});

  @override
  ConsumerState<MeshCoreSettingsScreen> createState() =>
      _MeshCoreSettingsScreenState();
}

class _MeshCoreSettingsScreenState extends ConsumerState<MeshCoreSettingsScreen>
    with LifecycleSafeMixin<MeshCoreSettingsScreen> {
  String _appVersion = '';
  bool _isSendingAdvert = false;
  bool _isSyncingTime = false;

  /// Locally cached node name, hydrated from [MeshCoreNodeNameStore].
  /// Used as a fallback for the Node Name tile subtitle when SelfInfo
  /// has not yet loaded (cold-start, post-disconnect window). Null
  /// means no cached value is available.
  String? _cachedNodeName;
  final MeshCoreNodeNameStore _nodeNameStore = MeshCoreNodeNameStore();

  @override
  void initState() {
    super.initState();
    AppLogging.meshcore('event=screen.opened name=settings');
    _loadVersionInfo();
    _hydrateCachedNodeName();
  }

  Future<void> _loadVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    safeSetState(() => _appVersion = packageInfo.version);
  }

  /// Pull the last-applied node name from local storage so the tile
  /// can render something useful before SELF_INFO comes back. Keyed
  /// by the coordinator's deviceInfo.nodeId; null while the
  /// connection has not yet identified a device.
  Future<void> _hydrateCachedNodeName() async {
    final nodeKey = _nodeKey();
    if (nodeKey == null) {
      AppLogging.meshcore('event=node_name.hydrate.skipped reason=no_node_key');
      return;
    }
    try {
      final cached = await _nodeNameStore.load(nodeKey);
      if (!mounted) return;
      if (cached == null) {
        AppLogging.meshcore('event=node_name.hydrate.miss');
        return;
      }
      AppLogging.meshcore('event=node_name.hydrate.hit size=${cached.length}');
      safeSetState(() => _cachedNodeName = cached);
    } catch (e) {
      AppLogging.meshcore(
        'event=node_name.hydrate.failed reason=${e.runtimeType}',
        error: true,
      );
    }
  }

  /// Stable per-device storage key. Mirrors the radio settings sheet
  /// pattern so save/load always agree on the lowercase node id.
  String? _nodeKey() {
    final nodeId = ref.read(connectionCoordinatorProvider).deviceInfo?.nodeId;
    if (nodeId == null || nodeId.isEmpty) return null;
    return nodeId.toLowerCase();
  }

  void _dismissKeyboard() {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
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

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: GlassScaffold(
        leading: const MeshCoreHamburgerMenuButton(),
        title: context.l10n.meshcoreSettingsTitle,
        actions: [const MeshCoreDeviceStatusButton()],
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
            sliver: SliverList.list(
              children: [
                _buildDeviceInfoSection(
                  context,
                  isConnected: isConnected,
                  selfInfo: selfInfo,
                  batteryState: batteryState,
                  contactCount: contactsState.contacts.length,
                  channelCount: channelsState.channels.length,
                ),
                SizedBox(height: AppTheme.spacing16),
                SettingsSectionHeader(title: context.l10n.meshcoreNodeSettings),
                SettingsTile(
                  icon: Icons.person_outline_rounded,
                  title: context.l10n.meshcoreNodeNameSetting,
                  // Prefer the live SelfInfo name; fall back to the
                  // locally-cached value (D13) so the tile renders
                  // a useful string during the pre-SelfInfo /
                  // post-disconnect window instead of "Not set".
                  subtitle:
                      (selfInfo?.nodeName.isNotEmpty == true
                          ? selfInfo!.nodeName
                          : _cachedNodeName) ??
                      context.l10n.meshcoreNotSet,
                  trailing: _chevron(context),
                  onTap: () => _editNodeName(
                    context,
                    selfInfo?.nodeName.isNotEmpty == true
                        ? selfInfo!.nodeName
                        : _cachedNodeName,
                  ),
                ),
                SettingsTile(
                  icon: Icons.radio_rounded,
                  title: context.l10n.meshcoreRadioSettings,
                  subtitle: context.l10n.meshcoreRadioSettingsSubtitle,
                  trailing: _chevron(context),
                  onTap: () => showMeshCoreRadioSettingsSheet(
                    context: context,
                    currentSelfInfo: selfInfo,
                  ),
                ),
                _maybeDisabled(
                  enabled: false,
                  child: SettingsTile(
                    icon: Icons.location_on_outlined,
                    title: context.l10n.meshcoreLocationSetting,
                    subtitle: context.l10n.meshcoreSetNodePosition,
                    trailing: _chevron(context),
                  ),
                ),
                _maybeDisabled(
                  enabled: false,
                  child: SettingsTile(
                    icon: Icons.visibility_off_outlined,
                    title: context.l10n.meshcorePrivacyMode,
                    subtitle: context.l10n.meshcoreControlAdvertVisibility,
                    trailing: _chevron(context),
                  ),
                ),
                SizedBox(height: AppTheme.spacing16),
                SettingsSectionHeader(title: context.l10n.meshcoreActions),
                _maybeDisabled(
                  enabled: isConnected && !_isSendingAdvert,
                  child: SettingsTile(
                    icon: Icons.cell_tower_rounded,
                    title: context.l10n.meshcoreSendAdvertisement,
                    subtitle: _isSendingAdvert
                        ? context.l10n.meshcoreSending
                        : context.l10n.meshcoreBroadcastYourPresence,
                    trailing: _chevron(context),
                    onTap: _sendAdvert,
                  ),
                ),
                _maybeDisabled(
                  enabled: isConnected && !_isSyncingTime,
                  child: SettingsTile(
                    icon: Icons.sync_rounded,
                    title: context.l10n.meshcoreSyncTime,
                    subtitle: _isSyncingTime
                        ? context.l10n.meshcoreSyncing
                        : context.l10n.meshcoreUpdateDeviceClock,
                    trailing: _chevron(context),
                    onTap: _syncTime,
                  ),
                ),
                _maybeDisabled(
                  enabled: isConnected,
                  child: SettingsTile(
                    icon: Icons.refresh_rounded,
                    title: context.l10n.meshcoreRefreshContactsSetting,
                    subtitle: context.l10n.meshcoreReloadContactsFromDevice,
                    trailing: _chevron(context),
                    onTap: () => _refreshContacts(context),
                  ),
                ),
                _maybeDisabled(
                  enabled: isConnected,
                  child: SettingsTile(
                    icon: Icons.restart_alt_rounded,
                    iconColor: AppTheme.warningYellow,
                    title: context.l10n.meshcoreRebootDevice,
                    subtitle: context.l10n.meshcoreRestartMeshCoreDevice,
                    trailing: _chevron(context),
                    onTap: () => _confirmReboot(context),
                  ),
                ),
                SizedBox(height: AppTheme.spacing16),
                SettingsSectionHeader(title: context.l10n.meshcoreDebug),
                SettingsTile(
                  icon: Icons.code_rounded,
                  title: context.l10n.meshcoreProtocolCapture,
                  subtitle: context.l10n.meshcoreViewFrameLogs,
                  trailing: _chevron(context),
                  onTap: () => _showProtocolCapture(context),
                ),
                SizedBox(height: AppTheme.spacing16),
                SettingsSectionHeader(title: context.l10n.meshcoreAbout),
                SettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: context.l10n.meshcoreAboutSocialMesh,
                  subtitle: context.l10n.meshcoreVersion(
                    _appVersion.isEmpty ? '…' : _appVersion,
                  ),
                  trailing: _chevron(context),
                  onTap: () => _showAbout(context),
                ),
                SizedBox(height: AppTheme.spacing32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoSection(
    BuildContext context, {
    required bool isConnected,
    MeshCoreSelfInfo? selfInfo,
    MeshCoreBatteryState? batteryState,
    required int contactCount,
    required int channelCount,
  }) {
    final rows = <InfoTableRow>[
      InfoTableRow(
        label: context.l10n.meshcoreStatusLabel,
        value: isConnected
            ? context.l10n.meshcoreConnected
            : context.l10n.meshcoreDisconnectedStatus,
        icon: Icons.circle,
        iconColor: isConnected ? SemanticColors.success : SemanticColors.error,
      ),
      if (selfInfo != null) ...[
        InfoTableRow(
          label: context.l10n.meshcoreNodeNameLabel,
          value: selfInfo.nodeName,
          icon: Icons.badge_outlined,
        ),
        InfoTableRow(
          label: context.l10n.meshcorePublicKeySettingsLabel,
          value: _bytesToHex(selfInfo.pubKey),
          icon: Icons.key_outlined,
          onTap: () {
            HapticFeedback.selectionClick();
            Clipboard.setData(
              ClipboardData(text: _bytesToHex(selfInfo.pubKey)),
            );
            showSuccessSnackBar(
              context,
              context.l10n.meshcorePublicKeyCopiedSettings,
            );
          },
        ),
      ],
      _batteryRow(batteryState),
      InfoTableRow(
        label: context.l10n.meshcoreContactsLabel,
        value: '$contactCount',
        icon: Icons.contacts_outlined,
      ),
      InfoTableRow(
        label: context.l10n.meshcoreChannelsLabel,
        value: '$channelCount',
        icon: Icons.tag,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: context.l10n.meshcoreDeviceInfo),
          InfoTable(rows: rows),
        ],
      ),
    );
  }

  InfoTableRow _batteryRow(MeshCoreBatteryState? state) {
    // Display preference is a global, persisted app preference (D13)
    // so the toggle survives screen reopen, navigation, and cold
    // restart. Watch via ref so the row redraws as soon as the
    // preference changes, including the cold-start hydration tick.
    final showVoltage = ref.watch(meshCoreShowBatteryVoltageProvider);

    String displayValue;
    IconData icon;
    Color? iconColor;

    if (state == null || state.voltageMillivolts == null) {
      displayValue = context.l10n.meshcoreBatteryUnknown;
      icon = Icons.battery_unknown_rounded;
      iconColor = SemanticColors.disabled;
    } else if (showVoltage) {
      displayValue =
          '${(state.voltageMillivolts! / 1000.0).toStringAsFixed(2)}V';
      icon = Icons.battery_full_rounded;
    } else if (state.percentage != null) {
      displayValue = '${state.percentage}%';
      if (state.percentage! <= 15) {
        icon = Icons.battery_alert_rounded;
        iconColor = SemanticColors.warning;
      } else {
        icon = Icons.battery_full_rounded;
      }
    } else {
      displayValue =
          '${(state.voltageMillivolts! / 1000.0).toStringAsFixed(2)}V';
      icon = Icons.battery_full_rounded;
    }

    return InfoTableRow(
      label: context.l10n.meshcoreBatteryStatusLabel,
      value: displayValue,
      icon: icon,
      iconColor: iconColor,
      // Tapping the battery row toggles between % and voltage display.
      onTap: state?.voltageMillivolts == null
          ? null
          : () async {
              HapticFeedback.selectionClick();
              final next = !showVoltage;
              await ref
                  .read(meshCoreShowBatteryVoltageProvider.notifier)
                  .set(next);
              AppLogging.meshcore(
                'event=settings.battery_display.set value='
                '${next ? "voltage" : "percentage"}',
              );
            },
    );
  }

  /// Right-chevron used as the trailing affordance on action/navigation
  /// tiles. Distinct from a [ThemedSwitch] trailing, which marks a toggle.
  Widget _chevron(BuildContext context) =>
      Icon(Icons.chevron_right, color: context.textTertiary);

  /// Wraps a [SettingsTile] in an [Opacity]+[IgnorePointer] when disabled.
  /// Keeps the tile visible (so the user understands the affordance exists)
  /// but blocks interaction without leaning on the tile API for state.
  Widget _maybeDisabled({required bool enabled, required Widget child}) {
    if (enabled) return child;
    return Opacity(opacity: 0.4, child: IgnorePointer(child: child));
  }

  // ---------------------------------------------------------------------------
  // Action handlers
  // ---------------------------------------------------------------------------

  void _editNodeName(BuildContext context, String? currentName) {
    final controller = TextEditingController(text: currentName ?? '');
    AppBottomSheet.show<void>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.meshcoreEditNodeName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          SizedBox(height: AppTheme.spacing16),
          TextField(
            controller: controller,
            autofocus: true,
            maxLength: 31,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            style: TextStyle(color: context.textPrimary),
            decoration: InputDecoration(
              hintText: context.l10n.meshcoreEnterNodeNameHint,
              hintStyle: TextStyle(color: SemanticColors.muted),
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
              prefixIcon: Icon(
                Icons.person_outline_rounded,
                color: context.textSecondary,
              ),
              counterText: '',
            ),
          ),
          SizedBox(height: AppTheme.spacing16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.meshcoreCancel),
                ),
              ),
              SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: PrimaryGradientButton(
                  label: context.l10n.meshcoreSave,
                  icon: Icons.save_rounded,
                  onPressed: () async {
                    Navigator.pop(context);
                    await _setNodeName(controller.text.trim());
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _setNodeName(String name) async {
    if (name.isEmpty) return;
    if (!mounted) return;

    final session = ref.read(meshCoreSessionProvider);
    final selfInfoNotifier = ref.read(meshCoreSelfInfoProvider.notifier);

    if (session == null || !session.isActive) {
      if (mounted) {
        showErrorSnackBar(context, context.l10n.meshcoreNotConnected);
      }
      return;
    }

    AppLogging.meshcore('event=node_name.apply.attempted size=${name.length}');

    try {
      final payload = Uint8List.fromList([...name.codeUnits, 0]);
      await session.sendFrame(
        MeshCoreFrame(
          command: MeshCoreCommands.setAdvertName,
          payload: payload,
        ),
      );
      if (!mounted) return;

      // Mirror locally AFTER firmware accepted the frame so a failed
      // send never overwrites the cached value. Best-effort: a store
      // failure is non-fatal because the firmware already has the new
      // name; we just lose the cold-start fallback for this change.
      final nodeKey = _nodeKey();
      if (nodeKey != null) {
        try {
          await _nodeNameStore.save(nodeKey, name);
          if (mounted) {
            safeSetState(() => _cachedNodeName = name);
          }
          AppLogging.meshcore('event=node_name.persist.saved');
        } catch (e) {
          AppLogging.meshcore(
            'event=node_name.persist.failed reason=${e.runtimeType}',
            error: true,
          );
        }
      } else {
        AppLogging.meshcore(
          'event=node_name.persist.skipped reason=no_node_key',
        );
      }

      AppLogging.meshcore('event=node_name.apply.succeeded');
      selfInfoNotifier.refresh();
      if (!mounted) return;
      showSuccessSnackBar(context, context.l10n.meshcoreNodeNameUpdated);
    } catch (e) {
      AppLogging.meshcore(
        'event=node_name.apply.failed reason=${e.runtimeType}',
        error: true,
      );
      if (mounted) {
        showErrorSnackBar(context, context.l10n.meshcoreFailedToSetName);
      }
    }
  }

  Future<void> _sendAdvert() async {
    if (_isSendingAdvert) return;
    final session = ref.read(meshCoreSessionProvider);
    if (session == null || !session.isActive) {
      if (mounted) {
        showErrorSnackBar(context, context.l10n.meshcoreNotConnected);
      }
      return;
    }

    safeSetState(() => _isSendingAdvert = true);
    try {
      await session.sendCommand(MeshCoreCommands.sendSelfAdvert);
      if (mounted) {
        showSuccessSnackBar(context, context.l10n.meshcoreAdvertisementSent);
      }
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(
          context,
          context.l10n.meshcoreFailedToSendAdvertisement,
        );
      }
    } finally {
      safeSetState(() => _isSendingAdvert = false);
    }
  }

  Future<void> _syncTime() async {
    if (_isSyncingTime) return;
    final session = ref.read(meshCoreSessionProvider);
    if (session == null || !session.isActive) {
      if (mounted) {
        showErrorSnackBar(context, context.l10n.meshcoreNotConnected);
      }
      return;
    }

    safeSetState(() => _isSyncingTime = true);
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
        showSuccessSnackBar(context, context.l10n.meshcoreTimeSynchronized);
      }
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, context.l10n.meshcoreFailedToSyncTime);
      }
    } finally {
      safeSetState(() => _isSyncingTime = false);
    }
  }

  void _refreshContacts(BuildContext context) {
    ref.read(meshCoreContactsProvider.notifier).refresh();
    showSuccessSnackBar(context, context.l10n.meshcoreRefreshingContacts);
  }

  Future<void> _confirmReboot(BuildContext context) async {
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.meshcoreRebootDeviceTitle,
      message: context.l10n.meshcoreRebootDeviceMessage,
      confirmLabel: context.l10n.meshcoreReboot,
    );

    if (confirmed != true) return;
    if (!mounted) return;

    await _rebootDevice();
  }

  Future<void> _rebootDevice() async {
    final session = ref.read(meshCoreSessionProvider);
    if (session == null || !session.isActive) {
      if (mounted) {
        showErrorSnackBar(context, context.l10n.meshcoreNotConnected);
      }
      return;
    }

    try {
      await session.sendCommand(MeshCoreCommands.reboot);
      if (mounted) {
        showSuccessSnackBar(context, context.l10n.meshcoreRebootCommandSent);
      }
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, context.l10n.meshcoreFailedToRebootDevice);
      }
    }
  }

  void _showProtocolCapture(BuildContext context) {
    final captureState = ref.read(meshCoreCaptureSnapshotProvider);

    AppBottomSheet.show<void>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: context.l10n.meshcoreProtocolCaptureDialogTitle),
          InfoTable(
            rows: [
              InfoTableRow(
                label: context.l10n.meshcoreActiveLabel,
                value: captureState.isActive
                    ? context.l10n.commonYes
                    : context.l10n.commonNo,
                icon: captureState.isActive
                    ? Icons.fiber_manual_record
                    : Icons.fiber_manual_record_outlined,
                iconColor: captureState.isActive
                    ? SemanticColors.success
                    : SemanticColors.disabled,
              ),
              InfoTableRow(
                label: context.l10n.meshcoreFramesLabel,
                value: '${captureState.totalCount}',
                icon: Icons.layers_outlined,
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacing16),
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
                  child: Text(context.l10n.meshcoreRefresh),
                ),
              ),
              if (captureState.hasFrames) ...[
                SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ref
                          .read(meshCoreCaptureSnapshotProvider.notifier)
                          .clear();
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SemanticColors.warning,
                      side: BorderSide(color: SemanticColors.warning),
                    ),
                    child: Text(context.l10n.meshcoreClear),
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
    AppBottomSheet.show<void>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.meshcoreAboutSocialMesh,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          SizedBox(height: AppTheme.spacing12),
          Text(
            context.l10n.meshcoreVersion(_appVersion),
            style: TextStyle(color: context.textSecondary),
          ),
          SizedBox(height: AppTheme.spacing12),
          Text(
            context.l10n.meshcoreAboutDescription,
            style: TextStyle(color: context.textSecondary),
          ),
          SizedBox(height: AppTheme.spacing24),
          SizedBox(
            width: double.infinity,
            child: PrimaryGradientButton(
              label: context.l10n.meshcoreClose,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
