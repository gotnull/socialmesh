// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../generated/meshtastic/admin.pbenum.dart' as admin_pbenum;
import '../../generated/meshtastic/module_config.pb.dart' as module_pb;
import '../../services/protocol/admin_target.dart';
import '../../providers/app_providers.dart';
import '../../providers/countdown_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/loading_indicator.dart';

/// Screen for configuring Store & Forward module
class StoreForwardConfigScreen extends ConsumerStatefulWidget {
  const StoreForwardConfigScreen({super.key});

  @override
  ConsumerState<StoreForwardConfigScreen> createState() =>
      _StoreForwardConfigScreenState();
}

class _StoreForwardConfigScreenState
    extends ConsumerState<StoreForwardConfigScreen>
    with LifecycleSafeMixin {
  bool _enabled = false;
  bool _isServer = false;
  bool _heartbeat = false;
  int _records = 0;
  int _historyReturnMax = 100;
  int _historyReturnWindow = 240; // minutes
  bool _isSaving = false;
  bool _isLoading = true;
  StreamSubscription<module_pb.ModuleConfig_StoreForwardConfig>?
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

  void _applyConfig(module_pb.ModuleConfig_StoreForwardConfig config) {
    safeSetState(() {
      _enabled = config.enabled;
      _isServer = config.isServer;
      _heartbeat = config.heartbeat;
      _records = config.records;
      _historyReturnMax = config.historyReturnMax > 0
          ? config.historyReturnMax
          : 100;
      _historyReturnWindow = config.historyReturnWindow > 0
          ? config.historyReturnWindow
          : 240;
      _isLoading = false;
    });
  }

  Future<void> _loadCurrentConfig() async {
    AppLogging.settings('[StoreForward] Loading config...');
    final loadFailedMsg = context.l10n.storeForwardLoadFailed;
    try {
      final protocol = ref.read(protocolServiceProvider);
      final target = AdminTarget.fromNullable(
        ref.read(remoteAdminTargetProvider),
      );

      // Apply cached config immediately if available (local only)
      if (target.isLocal) {
        final cached = protocol.currentStoreForwardConfig;
        if (cached != null) {
          AppLogging.settings('[StoreForward] Applying cached config');
          _applyConfig(cached);
        }
      }

      // Only request from device if connected
      if (protocol.isConnected) {
        // Listen for config response
        _configSubscription = protocol.storeForwardConfigStream.listen((
          config,
        ) {
          if (mounted) {
            AppLogging.settings('[StoreForward] Config received via stream');
            _applyConfig(config);
          }
        });

        // Request fresh config from device
        AppLogging.settings('[StoreForward] Requesting config from device');
        await protocol.getModuleConfig(
          admin_pbenum.AdminMessage_ModuleConfigType.STOREFORWARD_CONFIG,
          target: target,
        );
      } else {
        AppLogging.settings('[StoreForward] Not connected, skipping load');
      }
    } catch (e) {
      AppLogging.settings('[StoreForward] Error loading config: $e');
      safeShowSnackBar(loadFailedMsg);
    } finally {
      safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    safeSetState(() => _isSaving = true);

    try {
      final protocol = ref.read(protocolServiceProvider);
      final target = AdminTarget.fromNullable(
        ref.read(remoteAdminTargetProvider),
      );
      await protocol.setStoreForwardConfig(
        enabled: _enabled,
        isServer: _isServer,
        heartbeat: _heartbeat,
        records: _records,
        historyReturnMax: _historyReturnMax,
        historyReturnWindow: _historyReturnWindow,
        target: target,
      );

      if (mounted) {
        showSuccessSnackBar(context, context.l10n.storeForwardSaveSuccess);
        if (target.isLocal) {
          ref
              .read(countdownProvider.notifier)
              .startDeviceRebootCountdown(
                reason: 'Store & Forward config saved',
              );
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, context.l10n.storeForwardSaveFailed('$e'));
      }
    } finally {
      safeSetState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: context.l10n.storeForwardTitle,
      actions: [
        TextButton(
          onPressed: _isSaving ? null : _saveConfig,
          child: _isSaving
              ? LoadingIndicator(size: 20)
              : Text(
                  context.l10n.storeForwardSave,
                  style: TextStyle(color: context.accentColor),
                ),
        ),
      ],
      slivers: _isLoading
          ? [SliverFillRemaining(child: const ScreenLoadingIndicator())]
          : [
              SliverPadding(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Info card
                    _buildInfoCard(),

                    const SizedBox(height: AppTheme.spacing16),

                    // Module settings
                    _buildSectionTitle(context.l10n.storeForwardModuleSettings),
                    _buildConfigCard(),

                    const SizedBox(height: AppTheme.spacing16),

                    // Server settings (only shown if server mode)
                    if (_isServer) ...[
                      _buildSectionTitle(
                        context.l10n.storeForwardServerSettings,
                      ),
                      _buildServerSettingsCard(),
                    ],
                  ]),
                ),
              ),
            ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.textTertiary,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.storage, color: AppTheme.primaryBlue, size: 24),
          SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.storeForwardTitle,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  context.l10n.storeForwardInfoDescription,
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigCard() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              context.l10n.storeForwardEnable,
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              context.l10n.storeForwardEnableSubtitle,
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
            trailing: ThemedSwitch(
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
          ),
          Divider(height: 1, color: context.border),
          ListTile(
            title: Text(
              context.l10n.storeForwardActAsServer,
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              context.l10n.storeForwardActAsServerSubtitle,
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
            trailing: ThemedSwitch(
              value: _isServer,
              onChanged: _enabled ? (v) => setState(() => _isServer = v) : null,
            ),
          ),
          Divider(height: 1, color: context.border),
          ListTile(
            title: Text(
              context.l10n.storeForwardHeartbeat,
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              context.l10n.storeForwardHeartbeatSubtitle,
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
            trailing: ThemedSwitch(
              value: _heartbeat,
              onChanged: _enabled
                  ? (v) => setState(() => _heartbeat = v)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              context.l10n.storeForwardRecordsLimit,
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              _records == 0
                  ? context.l10n.storeForwardRecordsLimitSubtitle
                  : '$_records records',
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.remove, color: context.textSecondary),
                  onPressed: _records > 0
                      ? () => setState(() => _records -= 50)
                      : null,
                ),
                Text(
                  _records == 0 ? context.l10n.storeForwardAuto : '$_records',
                  style: TextStyle(
                    color: context.accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add, color: context.textSecondary),
                  onPressed: _records < 500
                      ? () => setState(() => _records += 50)
                      : null,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.border),
          ListTile(
            title: Text(
              context.l10n.storeForwardHistoryReturnMax,
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              context.l10n.storeForwardHistoryReturnMaxSubtitle(
                _historyReturnMax,
              ),
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.remove, color: context.textSecondary),
                  onPressed: _historyReturnMax > 25
                      ? () => setState(() => _historyReturnMax -= 25)
                      : null,
                ),
                Text(
                  '$_historyReturnMax',
                  style: TextStyle(
                    color: context.accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add, color: context.textSecondary),
                  onPressed: _historyReturnMax < 250
                      ? () => setState(() => _historyReturnMax += 25)
                      : null,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.border),
          ListTile(
            title: Text(
              context.l10n.storeForwardHistoryWindow,
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              context.l10n.storeForwardHistoryWindowSubtitle(
                _historyReturnWindow ~/ 60,
              ),
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.remove, color: context.textSecondary),
                  onPressed: _historyReturnWindow > 60
                      ? () => setState(() => _historyReturnWindow -= 60)
                      : null,
                ),
                Text(
                  '${_historyReturnWindow ~/ 60}h',
                  style: TextStyle(
                    color: context.accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add, color: context.textSecondary),
                  onPressed: _historyReturnWindow < 720
                      ? () => setState(() => _historyReturnWindow += 60)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
