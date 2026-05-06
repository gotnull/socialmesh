// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/meshcore_constants.dart';
import '../../../l10n/app_localizations.dart';
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
  // D26: gate the Node Location tile while a set/clear-location
  // command is in flight so the user can't dispatch a second one
  // before the first either OK's or fails.
  bool _isApplyingLocation = false;

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
                  enabled: isConnected && !_isApplyingLocation,
                  child: SettingsTile(
                    icon: Icons.location_on_outlined,
                    title: context.l10n.meshcoreLocationSetting,
                    subtitle: _isApplyingLocation
                        ? context.l10n.meshcoreApplying
                        : context.l10n.meshcoreSetNodePosition,
                    trailing: _chevron(context),
                    onTap: _editLocation,
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

    // D26: route through the typed `setAdvertName` helper so we get
    // (a) UTF-8 byte encoding (the previous `name.codeUnits` was
    // UTF-16 so non-ASCII characters were silently corrupted), (b)
    // pre-validated 31-byte limit matching firmware's `node_name[32]`
    // buffer (with reserved null), and (c) the spurious trailing
    // `0` removed (firmware truncates by length, no terminator on
    // wire).
    AppLogging.meshcore('event=node_name.apply.attempted size=${name.length}');

    try {
      final ok = await session.setAdvertName(name);
      if (!ok) {
        AppLogging.meshcore(
          'event=node_name.apply.failed reason=device_rejected',
          error: true,
        );
        if (mounted) {
          showErrorSnackBar(context, context.l10n.meshcoreFailedToSetName);
        }
        return;
      }
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

  /// D26: open the lat/lon editor sheet. Validates `lat ∈ [-90,
  /// 90]` and `lon ∈ [-180, 180]` before dispatching; routes through
  /// the typed `setAdvertLatLon` helper. Logs are coordinate-free —
  /// only `cleared=` and `location_set=true`. Includes a "Clear"
  /// action that sends `(0, 0)` (firmware's clear-stored-location
  /// convention).
  Future<void> _editLocation() async {
    // Use the State's `this.context` and capture l10n upfront so
    // the analyzer's `use_build_context_synchronously` lint can
    // verify the `mounted` guard is the canonical State one (not a
    // shadowed parameter).
    final l10n = context.l10n;
    // D26: use the same `showScrollable` variant as the Radio
    // Settings sheet (`device_sheet.dart` style: Column ->
    // Padding(header) -> Expanded(ListView with widget
    // .scrollController)). The compact `.show` variant landed too
    // high on the screen for a 2-field form and tripped the
    // gray-area cosmetic bug per the project's bottom-sheet variant
    // rule — content-heavy sheets MUST use showScrollable.
    final result = await AppBottomSheet.showScrollable<_EditLocationResult>(
      context: context,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (controller) => _EditLocationSheet(scrollController: controller),
    );
    if (result == null) return;
    if (!mounted) return;

    final session = ref.read(meshCoreSessionProvider);
    if (session == null || !session.isActive) {
      showErrorSnackBar(context, l10n.meshcoreNotConnected);
      return;
    }

    safeSetState(() => _isApplyingLocation = true);
    try {
      final ok = await session.setAdvertLatLon(result.lat, result.lon);
      if (!mounted) return;
      if (ok) {
        if (result.cleared) {
          showSuccessSnackBar(context, l10n.meshcoreLocationCleared);
        } else {
          showSuccessSnackBar(context, l10n.meshcoreLocationUpdated);
        }
      } else {
        showErrorSnackBar(context, l10n.meshcoreFailedToSetLocation);
      }
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, l10n.meshcoreFailedToSetLocation);
      }
    } finally {
      safeSetState(() => _isApplyingLocation = false);
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
      // D26: route through the typed `setDeviceTime` helper. Firmware
      // is forward-only — if its RTC is already ahead of the phone
      // (drift, manual adjustment), the helper returns `false` and we
      // surface a different snackbar so the user knows the sync was
      // not silently dropped on the floor.
      final ok = await session.setDeviceTime();
      if (!mounted) return;
      if (ok) {
        showSuccessSnackBar(context, context.l10n.meshcoreTimeSynchronized);
      } else {
        showErrorSnackBar(context, context.l10n.meshcoreSyncTimeRejected);
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
      // D26: route through `rebootDevice` so the magic-word "reboot"
      // payload is appended. The pre-D26 path called
      // `sendCommand(MeshCoreCommands.reboot)` with no payload — the
      // firmware's `memcmp(&cmd_frame[1], "reboot", 6)` check rejects
      // that frame silently, so the tile never actually rebooted the
      // radio. Fire-and-forget; firmware does not send OK.
      await session.rebootDevice();
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

/// D26: outcome returned from [_EditLocationSheet] via
/// `Navigator.pop`. The sheet itself is pure UI; the calling state
/// performs the actual `setAdvertLatLon` dispatch and toast.
class _EditLocationResult {
  final double lat;
  final double lon;

  /// True when the user explicitly tapped "Clear" (lat/lon both 0).
  /// Used by the caller to switch the success snackbar copy.
  final bool cleared;

  const _EditLocationResult({
    required this.lat,
    required this.lon,
    required this.cleared,
  });
}

/// D26: lat/lon editor sheet. Two `TextFormField`s with range
/// validation (`lat ∈ [-90, 90]`, `lon ∈ [-180, 180]`) plus three
/// actions: "Use my location" prefills from the phone GPS,
/// "Clear" dispatches `(0, 0)` (firmware's clear convention), and
/// "Apply" sends the entered values. Coordinates never appear in
/// logs — the caller logs only `cleared=` and `location_set=true`.
///
/// Body shape mirrors the canonical content-heavy bottom sheet
/// pattern (`device_sheet.dart` style): Column -> Padding(header)
/// -> Expanded(ListView with widget.scrollController). Required by
/// the project's bottom-sheet variant rule for any non-prompt
/// surface to avoid the gray-area cosmetic bug.
class _EditLocationSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;

  const _EditLocationSheet({required this.scrollController});

  @override
  ConsumerState<_EditLocationSheet> createState() => _EditLocationSheetState();
}

class _EditLocationSheetState extends ConsumerState<_EditLocationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  bool _fetchingGps = false;

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  /// Prefill the lat/lon fields from the phone's GPS via the shared
  /// [LocationService]. Failure (denied permission, no fix yet) just
  /// surfaces a snackbar — the user can still type values manually.
  Future<void> _useMyLocation() async {
    if (_fetchingGps) return;
    final l10n = context.l10n;
    setState(() => _fetchingGps = true);
    try {
      final svc = ref.read(locationServiceProvider);
      final pos = await svc.getCurrentPosition();
      if (!mounted) return;
      if (pos == null) {
        showErrorSnackBar(context, l10n.meshcoreLocationGpsUnavailable);
        return;
      }
      // 6-decimal precision matches the firmware's 1e6 wire scale.
      _latController.text = pos.latitude.toStringAsFixed(6);
      _lonController.text = pos.longitude.toStringAsFixed(6);
    } finally {
      if (mounted) setState(() => _fetchingGps = false);
    }
  }

  String? _validateLat(String? value, AppLocalizations l10n) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return l10n.meshcoreLocationLatRangeError;
    final v = double.tryParse(raw);
    if (v == null || v < -90 || v > 90) {
      return l10n.meshcoreLocationLatRangeError;
    }
    return null;
  }

  String? _validateLon(String? value, AppLocalizations l10n) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return l10n.meshcoreLocationLonRangeError;
    final v = double.tryParse(raw);
    if (v == null || v < -180 || v > 180) {
      return l10n.meshcoreLocationLonRangeError;
    }
    return null;
  }

  void _apply() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final lat = double.parse(_latController.text.trim());
    final lon = double.parse(_lonController.text.trim());
    Navigator.of(
      context,
    ).pop(_EditLocationResult(lat: lat, lon: lon, cleared: false));
  }

  void _clear() {
    Navigator.of(
      context,
    ).pop(const _EditLocationResult(lat: 0, lon: 0, cleared: true));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Form(
      key: _formKey,
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacing16,
          AppTheme.spacing8,
          AppTheme.spacing16,
          AppTheme.spacing16,
        ),
        children: [
          Text(
            l10n.meshcoreLocationSheetTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            l10n.meshcoreLocationSheetPrivacyHint,
            style: TextStyle(fontSize: 13, color: context.textTertiary),
          ),
          const SizedBox(height: AppTheme.spacing16),
          TextFormField(
            controller: _latController,
            maxLength: 12,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
            ],
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            style: TextStyle(color: context.textPrimary),
            validator: (v) => _validateLat(v, l10n),
            decoration: InputDecoration(
              labelText: l10n.meshcoreLocationLatLabel,
              labelStyle: TextStyle(color: context.textSecondary),
              hintText: l10n.meshcoreLocationLatHint,
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
                Icons.my_location_outlined,
                color: context.textSecondary,
              ),
              counterText: '',
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          TextFormField(
            controller: _lonController,
            maxLength: 12,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
            ],
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            style: TextStyle(color: context.textPrimary),
            validator: (v) => _validateLon(v, l10n),
            decoration: InputDecoration(
              labelText: l10n.meshcoreLocationLonLabel,
              labelStyle: TextStyle(color: context.textSecondary),
              hintText: l10n.meshcoreLocationLonHint,
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
                Icons.location_searching_outlined,
                color: context.textSecondary,
              ),
              counterText: '',
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          // Tertiary "use my location" — full-width, text-style so
          // it never competes with the primary Apply button. Sits
          // above the Apply/Clear row so the two halved buttons keep
          // single-line labels and matching widths.
          OutlinedButton.icon(
            onPressed: _fetchingGps ? null : _useMyLocation,
            icon: _fetchingGps
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded),
            label: Text(l10n.meshcoreLocationUseGps),
          ),
          const SizedBox(height: AppTheme.spacing12),
          // Apply + Clear: equal-width Row. Labels intentionally
          // short (one word each) so they NEVER wrap to two lines.
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clear,
                  icon: const Icon(Icons.location_off_outlined),
                  label: Text(l10n.meshcoreLocationClearAction),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: PrimaryGradientButton(
                  label: l10n.meshcoreLocationApplyAction,
                  icon: Icons.check_rounded,
                  onPressed: _apply,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
