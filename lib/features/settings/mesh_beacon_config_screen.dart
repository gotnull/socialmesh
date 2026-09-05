// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/meshtastic/modem_preset_metadata.dart';
import '../../core/meshtastic/region_metadata.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/status_banner.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/countdown_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../services/protocol/admin_target.dart';
import '../../services/protocol/protocol_service.dart';
import '../../utils/snackbar.dart';
import '../../generated/meshtastic/admin.pbenum.dart' as admin_pbenum;
import '../../generated/meshtastic/channel.pb.dart' as channel_pb;
import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;
import '../../generated/meshtastic/module_config.pb.dart' as module_pb;
import '../../generated/meshtastic/module_config.pbenum.dart' as module_pbenum;

/// Channel slots a radio can hold. Slot 0 is always the primary channel,
/// so offered channels go into 1..7.
const int kMeshBeaconMaxChannelIndex = 7;

/// First channel slot in 1..[kMeshBeaconMaxChannelIndex] that is either
/// absent from [channels] or disabled. Null when every slot is taken.
int? firstFreeChannelIndex(List<ChannelConfig> channels) {
  for (var index = 1; index <= kMeshBeaconMaxChannelIndex; index++) {
    final existing = channels.where((c) => c.index == index);
    if (existing.isEmpty) return index;
    if (existing.every((c) => c.role.toUpperCase() == 'DISABLED')) {
      return index;
    }
  }
  return null;
}

/// The active channel whose pre-shared key equals [psk], if any. Names are
/// ignored on purpose: two channels with the same key are the same channel
/// on the air whatever they are called.
ChannelConfig? channelWithPsk(List<ChannelConfig> channels, List<int> psk) {
  for (final channel in channels) {
    if (channel.role.toUpperCase() == 'DISABLED') continue;
    if (channel.psk.length != psk.length) continue;
    var same = true;
    for (var i = 0; i < psk.length; i++) {
      if (channel.psk[i] != psk[i]) {
        same = false;
        break;
      }
    }
    if (same) return channel;
  }
  return null;
}

class _PickerOption<T> {
  final T? value;
  final String label;
  final String? subtitle;

  const _PickerOption({
    required this.value,
    required this.label,
    this.subtitle,
  });
}

/// Screen for configuring the Mesh Beacon module (firmware 2.8+) and
/// reviewing the beacons other nodes have announced.
///
/// The module has two halves: listening (beacon text goes to the inbox,
/// offers are kept for the user) and broadcasting (a periodic message with
/// an optional channel, region and preset offer). Nothing offered by a
/// beacon is ever applied without a tap on this screen.
class MeshBeaconConfigScreen extends ConsumerStatefulWidget {
  const MeshBeaconConfigScreen({super.key});

  @override
  ConsumerState<MeshBeaconConfigScreen> createState() =>
      _MeshBeaconConfigScreenState();
}

class _MeshBeaconConfigScreenState extends ConsumerState<MeshBeaconConfigScreen>
    with LifecycleSafeMixin {
  static const int _secondsPerHour = 3600;
  static const int _minIntervalHours = 1;
  static const int _maxIntervalHours = 24;
  static const int _maxMessageBytes = 100;

  // Picker sheet height as a fraction of the screen: a fixed allowance for
  // the title plus one row's worth per option, bounded so short lists stay
  // compact and long ones still leave the page visible behind.
  static const double _pickerSheetBase = 0.16;
  static const double _pickerSheetPerRow = 0.075;
  static const double _pickerSheetMin = 0.3;
  static const double _pickerSheetMax = 0.7;

  bool _isLoading = false;
  bool _isSaving = false;

  bool _listenEnabled = false;
  bool _broadcastEnabled = false;
  bool _legacySplit = false;
  int _intervalSecs = _secondsPerHour;
  ChannelConfig? _offerChannel;
  config_pbenum.Config_LoRaConfig_RegionCode? _offerRegion;
  config_pbenum.Config_LoRaConfig_ModemPreset? _offerPreset;

  // Fields this screen does not edit are carried across a save untouched.
  module_pb.ModuleConfig_MeshBeaconConfig? _loadedConfig;

  List<MeshBeaconEvent> _beacons = const <MeshBeaconEvent>[];

  final _messageController = TextEditingController();
  StreamSubscription<module_pb.ModuleConfig_MeshBeaconConfig>?
  _configSubscription;
  StreamSubscription<MeshBeaconEvent>? _beaconSubscription;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _configSubscription?.cancel();
    _beaconSubscription?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  int get _intervalHours => (_intervalSecs / _secondsPerHour).round().clamp(
    _minIntervalHours,
    1 << 20,
  );

  bool _hasFlag(
    int flags,
    module_pbenum.ModuleConfig_MeshBeaconConfig_Flags f,
  ) => (flags & f.value) != 0;

  void _applyConfig(module_pb.ModuleConfig_MeshBeaconConfig config) {
    final channels = ref.read(channelsProvider);
    safeSetState(() {
      _loadedConfig = config;
      _listenEnabled = _hasFlag(
        config.flags,
        module_pbenum.ModuleConfig_MeshBeaconConfig_Flags.FLAG_LISTEN_ENABLED,
      );
      _broadcastEnabled = _hasFlag(
        config.flags,
        module_pbenum
            .ModuleConfig_MeshBeaconConfig_Flags
            .FLAG_BROADCAST_ENABLED,
      );
      _legacySplit = _hasFlag(
        config.flags,
        module_pbenum.ModuleConfig_MeshBeaconConfig_Flags.FLAG_LEGACY_SPLIT,
      );
      _messageController.text = config.broadcastMessage;
      _intervalSecs = config.broadcastIntervalSecs > 0
          ? config.broadcastIntervalSecs
          : _secondsPerHour;
      _offerRegion =
          config.broadcastOfferRegion !=
              config_pbenum.Config_LoRaConfig_RegionCode.UNSET
          ? config.broadcastOfferRegion
          : null;
      _offerPreset = config.hasBroadcastOfferPreset()
          ? config.broadcastOfferPreset
          : null;
      if (config.hasBroadcastOfferChannel()) {
        final offered = config.broadcastOfferChannel;
        final psk = List<int>.from(offered.psk);
        // Prefer the radio's own copy of the channel so the picker shows
        // it selected; fall back to a detached copy when the offered
        // channel no longer exists on the radio.
        _offerChannel =
            channelWithPsk(channels, psk) ??
            ChannelConfig(index: -1, name: offered.name, psk: psk);
      } else {
        _offerChannel = null;
      }
    });
  }

  Future<void> _loadCurrentConfig() async {
    safeSetState(() => _isLoading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);
      final target = AdminTarget.fromNullable(
        ref.read(remoteAdminTargetProvider),
      );

      _beacons = protocol.recentMeshBeacons;
      _beaconSubscription = protocol.meshBeaconEventStream.listen((_) {
        if (mounted) {
          safeSetState(() => _beacons = protocol.recentMeshBeacons);
        }
      });

      if (target.isLocal) {
        final cached = protocol.currentMeshBeaconConfig;
        if (cached != null) _applyConfig(cached);
      }

      if (protocol.isConnected) {
        _configSubscription = protocol.meshBeaconConfigStream.listen((config) {
          if (mounted) _applyConfig(config);
        });
        await protocol.getModuleConfig(
          admin_pbenum.AdminMessage_ModuleConfigType.MESHBEACON_CONFIG,
          target: target,
        );
      }
    } catch (e) {
      AppLogging.protocol('Mesh beacon config load aborted: $e');
    } finally {
      safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    final l10n = context.l10n;
    safeSetState(() => _isSaving = true);
    try {
      final protocol = ref.read(protocolServiceProvider);
      final target = AdminTarget.fromNullable(
        ref.read(remoteAdminTargetProvider),
      );

      var flags = 0;
      if (_listenEnabled) {
        flags |= module_pbenum
            .ModuleConfig_MeshBeaconConfig_Flags
            .FLAG_LISTEN_ENABLED
            .value;
      }
      if (_broadcastEnabled) {
        flags |= module_pbenum
            .ModuleConfig_MeshBeaconConfig_Flags
            .FLAG_BROADCAST_ENABLED
            .value;
      }
      if (_legacySplit) {
        flags |= module_pbenum
            .ModuleConfig_MeshBeaconConfig_Flags
            .FLAG_LEGACY_SPLIT
            .value;
      }

      final config = module_pb.ModuleConfig_MeshBeaconConfig()
        ..flags = flags
        ..broadcastMessage = _messageController.text.trim()
        ..broadcastIntervalSecs = _intervalSecs;
      final offerChannel = _offerChannel;
      if (offerChannel != null) {
        config.broadcastOfferChannel = channel_pb.ChannelSettings()
          ..name = offerChannel.name
          ..psk = offerChannel.psk;
      }
      final offerRegion = _offerRegion;
      if (offerRegion != null) config.broadcastOfferRegion = offerRegion;
      final offerPreset = _offerPreset;
      if (offerPreset != null) config.broadcastOfferPreset = offerPreset;
      final loaded = _loadedConfig;
      if (loaded != null) {
        config.broadcastTargets.addAll(loaded.broadcastTargets);
      }

      await protocol.setModuleConfig(
        module_pb.ModuleConfig()..meshBeacon = config,
        target: target,
      );

      if (mounted) {
        showSuccessSnackBar(context, l10n.meshBeaconSaved);
        if (target.isLocal) {
          ref
              .read(countdownProvider.notifier)
              .startDeviceRebootCountdown(reason: 'mesh beacon config saved');
        }
        safeNavigatorPop();
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, l10n.meshBeaconSaveFailed(e.toString()));
      }
    } finally {
      safeSetState(() => _isSaving = false);
    }
  }

  Future<void> _addOfferedChannel(MeshBeaconEvent beacon) async {
    final l10n = context.l10n;
    final psk = beacon.offerChannelPsk;
    if (psk == null) return;
    HapticFeedback.mediumImpact();

    final channels = ref.read(channelsProvider);
    if (channelWithPsk(channels, psk) != null) {
      showWarningSnackBar(context, l10n.meshBeaconChannelAlreadyPresent);
      return;
    }
    final index = firstFreeChannelIndex(channels);
    if (index == null) {
      showWarningSnackBar(context, l10n.meshBeaconNoFreeChannelSlot);
      return;
    }
    final offeredName = beacon.offerChannelName ?? '';
    final name = offeredName.isNotEmpty
        ? offeredName
        : l10n.channelsDefaultChannelName(index);
    final channel = ChannelConfig(index: index, name: name, psk: psk);

    final protocol = ref.read(protocolServiceProvider);
    final channelsNotifier = ref.read(channelsProvider.notifier);
    try {
      await protocol.setChannel(channel);
      channelsNotifier.setChannel(channel);
      if (!mounted) return;
      showSuccessSnackBar(context, l10n.meshBeaconChannelAdded(name));
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, l10n.meshBeaconChannelAddFailed(e.toString()));
    }
  }

  Future<void> _showOptionPicker<T>({
    required String title,
    required List<_PickerOption<T>> options,
    required T? selected,
    required ValueChanged<T?> onSelected,
  }) async {
    HapticFeedback.selectionClick();
    // Size the sheet to its rows: a two-entry channel list should not open
    // as a half-screen void, while the region list gets room to scroll.
    final initialSize = (_pickerSheetBase + options.length * _pickerSheetPerRow)
        .clamp(_pickerSheetMin, _pickerSheetMax);
    final choice = await AppBottomSheet.showScrollable<_PickerOption<T>>(
      context: context,
      title: title,
      initialChildSize: initialSize,
      minChildSize: _pickerSheetMin,
      maxChildSize: 0.9,
      builder: (controller) => Builder(
        builder: (sheetContext) => ListView.builder(
          controller: controller,
          itemCount: options.length,
          itemBuilder: (_, i) {
            final option = options[i];
            final isSelected = option.value == selected;
            return ListTile(
              // Line the rows up with the sheet title, which the scrollable
              // sheet insets by spacing24.
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing24,
              ),
              title: Text(
                option.label,
                style: TextStyle(
                  color: isSelected
                      ? sheetContext.accentColor
                      : sheetContext.textPrimary,
                ),
              ),
              subtitle: option.subtitle == null
                  ? null
                  : Text(
                      option.subtitle!,
                      style: TextStyle(
                        color: sheetContext.textTertiary,
                        fontSize: 12,
                      ),
                    ),
              trailing: isSelected
                  ? Icon(Icons.check, color: sheetContext.accentColor)
                  : null,
              onTap: () => Navigator.pop(sheetContext, option),
            );
          },
        ),
      ),
    );
    if (!mounted || choice == null) return;
    onSelected(choice.value);
  }

  String _channelLabel(ChannelConfig channel) {
    if (channel.name.isNotEmpty) return channel.name;
    if (channel.index == 0) return context.l10n.channelFormPrimaryChannelTitle;
    if (channel.index > 0) {
      return context.l10n.channelsDefaultChannelName(channel.index);
    }
    return context.l10n.meshBeaconUnnamedChannel;
  }

  String _regionLabel(config_pbenum.Config_LoRaConfig_RegionCode code) =>
      regionMetadataFor(code)?.regionSelectionName(context.l10n) ?? code.name;

  String _presetLabel(config_pbenum.Config_LoRaConfig_ModemPreset preset) =>
      modemPresetMetadataFor(preset)?.label(context.l10n) ?? preset.name;

  String _senderLabel(int nodeNum) {
    final node = ref.read(nodesProvider)[nodeNum];
    if (node != null) return node.displayName;
    // Meshtastic's canonical node id form, e.g. !a1b2c3d4.
    return '!${nodeNum.toRadixString(16).padLeft(8, '0')}'; // lint-allow: hardcoded-string
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        title: l10n.meshBeaconTitle,
        actions: [
          TextButton(
            onPressed: (_isLoading || _isSaving) ? null : _saveConfig,
            child: Text(
              l10n.meshBeaconSave,
              style: TextStyle(
                color: (_isLoading || _isSaving)
                    ? SemanticColors.disabled
                    : context.accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        slivers: [
          if (_isLoading)
            const SliverFillRemaining(child: ScreenLoadingIndicator())
          else
            SliverPadding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  StatusBanner.info(
                    title: l10n.meshBeaconInfoTitle,
                    subtitle: l10n.meshBeaconInfoDescription,
                    icon: Icons.cell_tower,
                  ),
                  const SizedBox(height: AppTheme.spacing24),
                  _SectionHeader(title: l10n.meshBeaconSectionListen),
                  const SizedBox(height: AppTheme.spacing8),
                  _buildListenSection(),
                  const SizedBox(height: AppTheme.spacing24),
                  _SectionHeader(title: l10n.meshBeaconSectionBroadcast),
                  const SizedBox(height: AppTheme.spacing8),
                  _buildBroadcastSection(),
                  if (_broadcastEnabled) ...[
                    const SizedBox(height: AppTheme.spacing24),
                    _SectionHeader(title: l10n.meshBeaconSectionOffer),
                    const SizedBox(height: AppTheme.spacing8),
                    _buildOfferSection(),
                  ],
                  const SizedBox(height: AppTheme.spacing24),
                  _SectionHeader(title: l10n.meshBeaconSectionReceived),
                  const SizedBox(height: AppTheme.spacing8),
                  _buildReceivedSection(),
                  const SizedBox(height: AppTheme.spacing32),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _rowDivider() => Column(
    children: [
      const SizedBox(height: AppTheme.spacing16),
      Divider(color: context.border),
      const SizedBox(height: AppTheme.spacing16),
    ],
  );

  Widget _buildListenSection() {
    final l10n = context.l10n;
    return _card(
      children: [
        _SettingsTile(
          icon: Icons.hearing,
          title: l10n.meshBeaconListen,
          subtitle: l10n.meshBeaconListenSubtitle,
          trailing: ThemedSwitch(
            value: _listenEnabled,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => _listenEnabled = value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBroadcastSection() {
    final l10n = context.l10n;
    return _card(
      children: [
        _SettingsTile(
          icon: Icons.campaign_outlined,
          title: l10n.meshBeaconBroadcast,
          subtitle: l10n.meshBeaconBroadcastSubtitle,
          trailing: ThemedSwitch(
            value: _broadcastEnabled,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => _broadcastEnabled = value);
            },
          ),
        ),
        if (_broadcastEnabled) ...[
          _rowDivider(),
          TextField(
            controller: _messageController,
            maxLength: _maxMessageBytes,
            maxLines: 2,
            style: TextStyle(color: context.textPrimary),
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            decoration: InputDecoration(
              labelText: l10n.meshBeaconMessage,
              labelStyle: TextStyle(color: context.textSecondary),
              prefixIcon: Icon(Icons.short_text, color: context.textSecondary),
              filled: true,
              fillColor: context.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                borderSide: BorderSide(color: context.accentColor),
              ),
              counterStyle: TextStyle(color: context.textTertiary),
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            l10n.meshBeaconInterval(_intervalHours),
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            l10n.meshBeaconIntervalDesc,
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
          SliderTheme(
            data: SliderThemeData(
              inactiveTrackColor: SemanticColors.divider,
              thumbColor: context.accentColor,
              overlayColor: context.accentColor.withAlpha(30),
            ),
            // The radio may hold an interval beyond the slider's range; pin
            // the thumb at the nearest end and keep the real value until
            // the user moves it.
            child: Slider(
              value: _intervalHours
                  .clamp(_minIntervalHours, _maxIntervalHours)
                  .toDouble(),
              min: _minIntervalHours.toDouble(),
              max: _maxIntervalHours.toDouble(),
              divisions: _maxIntervalHours - _minIntervalHours,
              label: '${_intervalHours}h', // lint-allow: hardcoded-string
              onChanged: (v) =>
                  setState(() => _intervalSecs = v.toInt() * _secondsPerHour),
            ),
          ),
          _rowDivider(),
          _SettingsTile(
            icon: Icons.call_split,
            title: l10n.meshBeaconLegacySplit,
            subtitle: l10n.meshBeaconLegacySplitSubtitle,
            trailing: ThemedSwitch(
              value: _legacySplit,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() => _legacySplit = value);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOfferSection() {
    final l10n = context.l10n;
    final channels = ref
        .watch(channelsProvider)
        .where((c) => c.role.toUpperCase() != 'DISABLED')
        .toList();
    final offerChannel = _offerChannel;
    return _card(
      children: [
        _SettingsTile(
          icon: Icons.tag,
          title: l10n.meshBeaconOfferChannel,
          subtitle: offerChannel == null
              ? l10n.meshBeaconOfferChannelSubtitle
              : _channelLabel(offerChannel),
          trailing: Icon(Icons.chevron_right, color: context.textTertiary),
          onTap: () => _showOptionPicker<ChannelConfig>(
            title: l10n.meshBeaconOfferChannel,
            selected: offerChannel == null
                ? null
                : channelWithPsk(channels, offerChannel.psk),
            options: [
              _PickerOption<ChannelConfig>(
                value: null,
                label: l10n.meshBeaconOfferNone,
              ),
              for (final channel in channels)
                _PickerOption<ChannelConfig>(
                  value: channel,
                  label: _channelLabel(channel),
                ),
            ],
            onSelected: (value) => setState(() => _offerChannel = value),
          ),
        ),
        _rowDivider(),
        _SettingsTile(
          icon: Icons.public,
          title: l10n.meshBeaconOfferRegion,
          subtitle: _offerRegion == null
              ? l10n.meshBeaconOfferNone
              : _regionLabel(_offerRegion!),
          trailing: Icon(Icons.chevron_right, color: context.textTertiary),
          onTap: () =>
              _showOptionPicker<config_pbenum.Config_LoRaConfig_RegionCode>(
                title: l10n.meshBeaconOfferRegion,
                selected: _offerRegion,
                options: [
                  _PickerOption(value: null, label: l10n.meshBeaconOfferNone),
                  for (final region in kRegionMetadata)
                    if (region.code !=
                        config_pbenum.Config_LoRaConfig_RegionCode.UNSET)
                      _PickerOption(
                        value: region.code,
                        label: region.regionSelectionName(l10n),
                        subtitle: region.regionSelectionFrequency(l10n),
                      ),
                ],
                onSelected: (value) => setState(() => _offerRegion = value),
              ),
        ),
        _rowDivider(),
        _SettingsTile(
          icon: Icons.tune,
          title: l10n.meshBeaconOfferPreset,
          subtitle: _offerPreset == null
              ? l10n.meshBeaconOfferNone
              : _presetLabel(_offerPreset!),
          trailing: Icon(Icons.chevron_right, color: context.textTertiary),
          onTap: () =>
              _showOptionPicker<config_pbenum.Config_LoRaConfig_ModemPreset>(
                title: l10n.meshBeaconOfferPreset,
                selected: _offerPreset,
                options: [
                  _PickerOption(value: null, label: l10n.meshBeaconOfferNone),
                  for (final preset in kModemPresetMetadata)
                    _PickerOption(
                      value: preset.preset,
                      label: preset.label(l10n),
                      subtitle: preset.description(l10n),
                    ),
                ],
                onSelected: (value) => setState(() => _offerPreset = value),
              ),
        ),
      ],
    );
  }

  Widget _buildReceivedSection() {
    final l10n = context.l10n;
    if (_beacons.isEmpty) {
      return _card(
        children: [
          Text(
            l10n.meshBeaconReceivedEmpty,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        for (final beacon in _beacons)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
            child: _buildBeaconCard(beacon),
          ),
      ],
    );
  }

  Widget _buildBeaconCard(MeshBeaconEvent beacon) {
    final l10n = context.l10n;
    final channels = ref.watch(channelsProvider);
    final psk = beacon.offerChannelPsk;
    final alreadyPresent = psk != null && channelWithPsk(channels, psk) != null;
    final offeredChannelName = (beacon.offerChannelName ?? '').isNotEmpty
        ? beacon.offerChannelName!
        : l10n.meshBeaconUnnamedChannel;
    final receivedAt = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(beacon.receivedAt));
    final metaStyle = TextStyle(color: context.textSecondary, fontSize: 12);

    return _card(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.cell_tower, color: context.textSecondary, size: 22),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _senderLabel(beacon.senderNodeId),
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    receivedAt,
                    style: TextStyle(color: context.textTertiary, fontSize: 12),
                  ),
                  if (beacon.message.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      beacon.message,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (beacon.hasChannelOffer || beacon.hasRadioOffer) ...[
                    const SizedBox(height: AppTheme.spacing8),
                    Wrap(
                      spacing: AppTheme.spacing12,
                      runSpacing: AppTheme.spacing4,
                      children: [
                        if (beacon.hasChannelOffer)
                          Text(
                            l10n.meshBeaconOfferedChannelLabel(
                              offeredChannelName,
                            ),
                            style: metaStyle,
                          ),
                        if (beacon.offerRegion != null)
                          Text(
                            l10n.meshBeaconOfferedRegionLabel(
                              _regionLabel(beacon.offerRegion!),
                            ),
                            style: metaStyle,
                          ),
                        if (beacon.offerPreset != null)
                          Text(
                            l10n.meshBeaconOfferedPresetLabel(
                              _presetLabel(beacon.offerPreset!),
                            ),
                            style: metaStyle,
                          ),
                      ],
                    ),
                  ],
                  if (alreadyPresent) ...[
                    const SizedBox(height: AppTheme.spacing4),
                    Text(
                      l10n.meshBeaconChannelAlreadyPresent,
                      style: metaStyle,
                    ),
                  ],
                ],
              ),
            ),
            if (beacon.hasChannelOffer && !alreadyPresent)
              IconButton(
                tooltip: l10n.meshBeaconAddChannel,
                icon: Icon(
                  Icons.add_circle_outline,
                  color: context.accentColor,
                ),
                onPressed: () => _addOfferedChannel(beacon),
              ),
          ],
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: context.textSecondary, size: 22),
        const SizedBox(width: AppTheme.spacing12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(color: context.textSecondary, fontSize: 12),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius8),
      child: row,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
      child: Text(
        title,
        style: TextStyle(
          color: context.textTertiary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
