// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/chip_selector.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/remote_admin_target_banner.dart';
import '../../core/widgets/settings_primitives.dart';
import '../../core/widgets/status_banner.dart';
import '../../generated/meshtastic/admin.pbenum.dart' as admin_pbenum;
import '../../generated/meshtastic/module_config.pb.dart' as module_pb;
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/countdown_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../services/protocol/admin_target.dart';
import '../../utils/snackbar.dart';
import '../../utils/time_format.dart';
import '../../utils/uptime_formatter.dart';
import 'range_test/range_test_models.dart';
import 'range_test/range_test_providers.dart';
import 'range_test/range_test_session_screen.dart';

// Sender intervals offered, in seconds; 0 makes the radio a receiver.
// Matches the official iOS app's list.
const List<int> _kSenderIntervals = [
  0,
  15,
  30,
  45,
  60,
  300,
  600,
  900,
  1800,
  3600,
];

/// Range Test module settings, and recording of the Range Test packets the
/// connected radio hears.
class RangeTestScreen extends ConsumerStatefulWidget {
  const RangeTestScreen({super.key});

  @override
  ConsumerState<RangeTestScreen> createState() => _RangeTestScreenState();
}

class _RangeTestScreenState extends ConsumerState<RangeTestScreen>
    with LifecycleSafeMixin {
  bool _enabled = false;
  int _senderInterval = 0;
  bool _saveResults = false;
  bool _isSaving = false;
  bool _isLoading = true;
  bool _hasChanges = false;

  StreamSubscription<module_pb.ModuleConfig_RangeTestConfig>?
  _configSubscription;

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

  void _applyConfig(module_pb.ModuleConfig_RangeTestConfig config) {
    safeSetState(() {
      _enabled = config.enabled;
      _senderInterval = config.sender;
      _saveResults = config.save;
      _isLoading = false;
      _hasChanges = false;
    });
  }

  Future<void> _loadCurrentConfig() async {
    try {
      final protocol = ref.read(protocolServiceProvider);
      final target = AdminTarget.fromNullable(
        ref.read(remoteAdminTargetProvider),
      );

      // Apply cached config immediately if available (local only)
      if (target.isLocal) {
        final cached = protocol.currentRangeTestConfig;
        if (cached != null) {
          _applyConfig(cached);
        }
      }

      // Only request from device if connected
      if (protocol.isConnected) {
        _configSubscription = protocol.rangeTestConfigStream.listen((config) {
          if (mounted) _applyConfig(config);
        });

        await protocol.getModuleConfig(
          admin_pbenum.AdminMessage_ModuleConfigType.RANGETEST_CONFIG,
          target: target,
        );
      }
    } finally {
      safeSetState(() => _isLoading = false);
    }
  }

  void _edit(VoidCallback change) {
    HapticFeedback.selectionClick();
    setState(() {
      change();
      _hasChanges = true;
    });
  }

  Future<void> _saveConfig() async {
    safeSetState(() => _isSaving = true);

    try {
      final protocol = ref.read(protocolServiceProvider);
      final target = AdminTarget.fromNullable(
        ref.read(remoteAdminTargetProvider),
      );
      await protocol.setRangeTestConfig(
        enabled: _enabled,
        sender: _senderInterval,
        save: _saveResults,
        target: target,
      );

      if (mounted) {
        safeSetState(() => _hasChanges = false);
        showSuccessSnackBar(context, context.l10n.rangeTestSaveSuccess);
        if (target.isLocal) {
          ref
              .read(countdownProvider.notifier)
              .startDeviceRebootCountdown(reason: 'range test config saved');
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, context.l10n.rangeTestSaveFailed('$e'));
      }
    } finally {
      safeSetState(() => _isSaving = false);
    }
  }

  // The sender broadcasts on the primary channel. On a public key that
  // floods every radio in range, so sending is refused there, as the
  // official iOS app does. Receiving is harmless and stays allowed.
  bool _primaryChannelIsPublic(List<ChannelConfig> channels) {
    for (final c in channels) {
      if (c.index == 0) {
        return c.encryption(channels) != ChannelEncryption.privateKey;
      }
    }
    return false;
  }

  bool _targetHasWifi() {
    final nodes = ref.read(nodesProvider);
    final nodeNum =
        ref.read(remoteAdminTargetProvider) ?? ref.read(myNodeNumProvider);
    return nodeNum != null && (nodes[nodeNum]?.hasWifi ?? false);
  }

  String _intervalLabel(int seconds) {
    if (seconds == 0) return context.l10n.rangeTestIntervalOff;
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m';
    return '${seconds ~/ 3600}h';
  }

  Future<void> _toggleRecording(RangeTestState state) async {
    HapticFeedback.mediumImpact();
    final notifier = ref.read(rangeTestProvider.notifier);
    if (state.isRecording) {
      await notifier.stop();
    } else {
      await notifier.start();
    }
  }

  void _openSession(int sessionId) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RangeTestSessionScreen(sessionId: sessionId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final channels = ref.watch(channelsProvider);
    final publicPrimary = _primaryChannelIsPublic(channels);
    final blockedSender = publicPrimary && _enabled && _senderInterval > 0;
    final canSave = !_isLoading && !_isSaving && _hasChanges && !blockedSender;

    return GlassScaffold(
      title: l10n.rangeTestTitle,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppTheme.spacing8),
          child: TextButton(
            onPressed: canSave ? _saveConfig : null,
            child: _isSaving
                ? LoadingIndicator(size: 20)
                : Text(
                    l10n.rangeTestSave,
                    style: TextStyle(
                      color: canSave
                          ? context.accentColor
                          : context.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
      slivers: [
        const SliverToBoxAdapter(child: RemoteAdminTargetBanner()),
        if (_isLoading)
          const SliverFillRemaining(child: ScreenLoadingIndicator())
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
            sliver: SliverList.list(
              children: [
                if (publicPrimary)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
                    child: StatusBanner.warning(
                      title: l10n.rangeTestPublicChannelWarning,
                      icon: Icons.lock_open,
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing16,
                      ),
                    ),
                  ),
                ..._recordingSection(),
                const SizedBox(height: AppTheme.spacing16),
                ..._configSection(publicPrimary),
                const SizedBox(height: AppTheme.spacing16),
                ..._historySection(),
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> _recordingSection() {
    final l10n = context.l10n;
    final state = ref.watch(rangeTestProvider).value;
    final isConnected = ref.watch(isLinkConnectedProvider);
    final active = state?.activeSession;
    final recording = active != null;

    final String subtitle;
    if (recording) {
      subtitle = l10n.rangeTestPacketsHeard(active.readingCount);
    } else if (isConnected) {
      subtitle = l10n.rangeTestRecordingIdleSubtitle;
    } else {
      subtitle = l10n.rangeTestConnectToRecord;
    }

    return [
      SettingsSectionHeader(title: l10n.rangeTestSectionRecord),
      SettingsTile(
        icon: recording ? Icons.radar : Icons.radar_outlined,
        iconColor: recording ? context.accentColor : null,
        title: recording
            ? l10n.rangeTestRecordingActive
            : l10n.rangeTestRecordingIdle,
        subtitle: subtitle,
        crossAxisAlignment: CrossAxisAlignment.start,
        onTap: recording ? () => _openSession(active.id) : null,
        trailing: TextButton(
          onPressed: state == null || (!recording && !isConnected)
              ? null
              : () => _toggleRecording(state),
          child: Text(
            recording ? l10n.rangeTestStop : l10n.rangeTestStart,
            style: TextStyle(
              color: recording ? AppTheme.errorRed : context.accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _configSection(bool publicPrimary) {
    final l10n = context.l10n;
    final hasWifi = _targetHasWifi();
    final intervals = [
      ..._kSenderIntervals,
      if (!_kSenderIntervals.contains(_senderInterval)) _senderInterval,
    ]..sort();

    return [
      SettingsSectionHeader(title: l10n.rangeTestConfiguration),
      SettingsTile(
        icon: Icons.radar,
        iconColor: _enabled ? context.accentColor : null,
        title: l10n.rangeTestEnableModule,
        subtitle: l10n.rangeTestEnableModuleSubtitle,
        trailing: ThemedSwitch(
          value: _enabled,
          onChanged: (v) => _edit(() => _enabled = v),
        ),
      ),
      if (_enabled) ...[
        FieldGroupCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.rangeTestSenderInterval,
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppTheme.spacing4),
              Text(
                publicPrimary
                    ? l10n.rangeTestSenderIntervalPublicHelp
                    : l10n.rangeTestSenderIntervalHelp,
                style: context.bodySmallStyle?.copyWith(
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),
              ChipSelector<int>(
                scrollable: true,
                value: _senderInterval,
                options: [
                  for (final v in intervals)
                    ChipOption<int>(
                      value: v,
                      label: _intervalLabel(v),
                      icon: v == 0 ? Icons.hearing : Icons.schedule,
                      color: context.accentColor,
                    ),
                ],
                onChanged: (v) => _edit(() => _senderInterval = v),
              ),
            ],
          ),
        ),
        SettingsTile(
          icon: Icons.save_outlined,
          title: l10n.rangeTestSaveResultsToSd,
          subtitle: l10n.rangeTestSaveResultsToSdSubtitle,
          crossAxisAlignment: CrossAxisAlignment.start,
          trailing: ThemedSwitch(
            value: _saveResults,
            // Saving is served over the radio's Wi-Fi; a radio without it
            // can only turn a stale setting off.
            onChanged: hasWifi || _saveResults
                ? (v) => _edit(() => _saveResults = v)
                : null,
          ),
        ),
      ],
    ];
  }

  List<Widget> _historySection() {
    final l10n = context.l10n;
    final sessions = ref.watch(rangeTestProvider).value?.sessions ?? const [];
    if (sessions.isEmpty) {
      return [
        SettingsSectionHeader(title: l10n.rangeTestAbout),
        SettingsTile(
          icon: Icons.info_outline,
          title: l10n.rangeTestHowItWorks,
          subtitle: l10n.rangeTestHowItWorksDescription,
          crossAxisAlignment: CrossAxisAlignment.start,
        ),
      ];
    }
    final dateTime = AppTimeFormat.fullDateAndTime(context);
    return [
      SettingsSectionHeader(title: l10n.rangeTestSectionHistory),
      for (final s in sessions)
        SettingsTile(
          icon: Icons.history,
          title: dateTime.format(s.startedAt),
          subtitle: _sessionSubtitle(s),
          crossAxisAlignment: CrossAxisAlignment.start,
          onTap: () => _openSession(s.id),
          trailing: Icon(Icons.chevron_right, color: context.textTertiary),
        ),
    ];
  }

  String _sessionSubtitle(RangeTestSession s) {
    final l10n = context.l10n;
    final endedAt = s.endedAt;
    return l10n.rangeTestSessionSubtitle(
      l10n.rangeTestPacketCount(s.readingCount),
      endedAt == null
          ? l10n.rangeTestRecordingActive
          : formatUptime(endedAt.difference(s.startedAt).inSeconds),
    );
  }
}
