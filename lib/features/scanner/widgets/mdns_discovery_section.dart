// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/transport.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/connection_providers.dart';
import '../../../providers/mdns_providers.dart';
import '../../../services/haptic_service.dart';
import '../../../services/transport/mdns_discovery_service.dart';
import '../../../utils/snackbar.dart';

/// Displays Meshtastic devices discovered via mDNS on the local network.
///
/// Starts scanning when mounted, stops when disposed. Each discovered
/// device shows its display name and host:port, with a connect action.
class MdnsDiscoverySection extends ConsumerStatefulWidget {
  final ValueChanged<DeviceInfo>? onConnectionSuccess;

  const MdnsDiscoverySection({super.key, this.onConnectionSuccess});

  @override
  ConsumerState<MdnsDiscoverySection> createState() =>
      _MdnsDiscoverySectionState();
}

class _MdnsDiscoverySectionState extends ConsumerState<MdnsDiscoverySection>
    with LifecycleSafeMixin {
  String? _connectingDeviceKey;

  @override
  void initState() {
    super.initState();
    // Start mDNS scanning if not already running.
    // We do NOT stop scanning on dispose — the provider manages its own
    // lifecycle via ref.onDispose. This prevents the device list from
    // being cleared on widget rebuilds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(mdnsDiscoveryProvider.notifier).startScan();
    });
  }

  Future<void> _connectToDevice(MdnsDeviceInfo device) async {
    final l10n = context.l10n;
    final haptics = ref.haptics;
    haptics.buttonTap();

    final key = '${device.host}:${device.port}';
    safeSetState(() {
      _connectingDeviceKey = key;
    });

    try {
      // Set network transport host/port
      ref.read(networkTransportHostProvider.notifier).set(device.host);
      ref.read(networkTransportPortProvider.notifier).set(device.port);

      // Switch transport type to network
      ref.read(transportTypeProvider.notifier).setType(TransportType.network);

      // Connect via the standard connection flow
      final deviceInfo = device.toDeviceInfo();
      final connectionNotifier = ref.read(deviceConnectionProvider.notifier);
      await connectionNotifier.connectToDevice(deviceInfo);

      if (!mounted) return;
      widget.onConnectionSuccess?.call(deviceInfo);
    } catch (e) {
      AppLogging.protocol('mDNS: Connection failed to ${device.host}: $e');
      if (!mounted) return;

      String errorMsg;
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('timeout')) {
        errorMsg = l10n.networkConnectionTimeout;
      } else if (errorStr.contains('connection refused')) {
        errorMsg = l10n.networkConnectionRefused;
      } else {
        errorMsg = l10n.networkConnectionFailed(
          '${device.host}:${device.port}',
        );
      }

      showErrorSnackBar(context, errorMsg);
    } finally {
      if (mounted) {
        safeSetState(() {
          _connectingDeviceKey = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(mdnsDiscoveryProvider);
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header — matches BLE "Available Devices" style
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Text(
                l10n.mdnsDiscoveredRadios,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              if (devices.isNotEmpty) ...[
                const SizedBox(width: AppTheme.spacing8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  child: Text(
                    '${devices.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.accentColor,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (devices.isEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: context.textTertiary,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing4),
                    Text(
                      l10n.mdnsScanning,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // Device list or empty state
        if (devices.isEmpty)
          _buildEmptyState(l10n)
        else
          ...devices.map((device) {
            final key = '${device.host}:${device.port}';
            return _MdnsDeviceCard(
              device: device,
              isConnecting: _connectingDeviceKey == key,
              onTap: () => _connectToDevice(device),
            );
          }),
      ],
    );
  }

  Widget _buildEmptyState(dynamic l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.wifi_find,
              size: 36,
              color: context.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              l10n.mdnsNoDevicesFound,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacing4),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing32,
              ),
              child: Text(
                l10n.mdnsNoDevicesDescription,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: context.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card displaying a discovered mDNS Meshtastic device.
class _MdnsDeviceCard extends StatelessWidget {
  final MdnsDeviceInfo device;
  final bool isConnecting;
  final VoidCallback onTap;

  const _MdnsDeviceCard({
    required this.device,
    required this.isConnecting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
      child: Semantics(
        container: true,
        button: true,
        enabled: !isConnecting,
        label:
            '${device.displayName}, ${device.host}:${device.port}, ${l10n.mdnsTransportTcp}',
        child: Material(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          child: InkWell(
            onTap: isConnecting ? null : onTap,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            splashColor: context.accentColor.withValues(alpha: 0.2),
            highlightColor: context.accentColor.withValues(alpha: 0.1),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                border: Border.all(color: context.border),
              ),
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: context.background,
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                    child: isConnecting
                        ? Padding(
                            padding: const EdgeInsets.all(AppTheme.spacing12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.accentColor,
                            ),
                          )
                        : Icon(
                            Icons.wifi,
                            color: context.accentColor,
                            size: 24,
                          ),
                  ),
                  const SizedBox(width: AppTheme.spacing16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.displayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing4),
                        Text(
                          '${device.host}:${device.port}',
                          style: TextStyle(
                            fontSize: 14,
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing8,
                      vertical: AppTheme.spacing4,
                    ),
                    decoration: BoxDecoration(
                      color: AccentColors.cyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radius4),
                    ),
                    child: Text(
                      l10n.mdnsTransportTcp,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AccentColors.cyan,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
