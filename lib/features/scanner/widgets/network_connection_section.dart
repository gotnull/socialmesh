// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/transport.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/chip_selector.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/network_endpoint.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/connection_providers.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../providers/network_endpoint_providers.dart';
import '../../../services/haptic_service.dart';
import '../../../services/transport/network_transport.dart';
import '../../../utils/snackbar.dart';

/// Network connection section shown in the scanner screen.
///
/// Displays saved endpoints, allows adding new ones, and initiating
/// TCP connections. Shows "Manual Connections" with a host:port entry,
/// following the standard Meshtastic companion app UX pattern.
class NetworkConnectionSection extends ConsumerStatefulWidget {
  final ValueChanged<DeviceInfo>? onConnectionSuccess;

  /// When true, shows a minimal empty state (no icon, description, or
  /// duplicate add button). Used in the scanner screen where space is tight.
  final bool compact;

  const NetworkConnectionSection({
    super.key,
    this.onConnectionSuccess,
    this.compact = false,
  });

  @override
  ConsumerState<NetworkConnectionSection> createState() =>
      _NetworkConnectionSectionState();
}

class _NetworkConnectionSectionState
    extends ConsumerState<NetworkConnectionSection>
    with LifecycleSafeMixin {
  String? _connectingEndpointId;
  String? _errorMessage;

  Future<void> _connectToEndpoint(NetworkEndpoint endpoint) async {
    final l10n = context.l10n;
    final haptics = ref.haptics;
    haptics.buttonTap();

    safeSetState(() {
      _connectingEndpointId = endpoint.id;
      _errorMessage = null;
    });

    try {
      if (endpoint.protocol == NetworkEndpointProtocol.meshcore) {
        await _connectMeshCoreEndpoint(endpoint, l10n);
      } else {
        await _connectMeshtasticEndpoint(endpoint, l10n);
      }
    } catch (e) {
      AppLogging.protocol('Network connection failed: $e');
      if (!mounted) return;

      String errorMsg;
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('socketexception') &&
          errorStr.contains('no route to host')) {
        errorMsg = l10n.networkDnsResolutionFailed;
      } else if (errorStr.contains('timeout')) {
        errorMsg = l10n.networkConnectionTimeout;
      } else if (errorStr.contains('connection refused')) {
        errorMsg = l10n.networkConnectionRefused;
      } else {
        errorMsg = l10n.networkConnectionFailed(endpoint.displayAddress);
      }

      safeSetState(() {
        _errorMessage = errorMsg;
      });

      if (mounted) {
        showErrorSnackBar(context, errorMsg);
      }
    } finally {
      if (mounted) {
        safeSetState(() {
          _connectingEndpointId = null;
        });
      }
    }
  }

  /// Existing Meshtastic TCP path — wired through `deviceConnectionProvider`
  /// and `transportTypeProvider`. Behaviour unchanged from the
  /// pre-protocol-selector flow.
  Future<void> _connectMeshtasticEndpoint(
    NetworkEndpoint endpoint,
    AppLocalizations l10n,
  ) async {
    // Set network transport host/port
    ref.read(networkTransportHostProvider.notifier).set(endpoint.host);
    ref.read(networkTransportPortProvider.notifier).set(endpoint.port);

    // Switch transport type to network (triggers transportProvider rebuild)
    ref.read(transportTypeProvider.notifier).setType(TransportType.network);

    // Create DeviceInfo for the network endpoint
    final deviceInfo = DeviceInfo(
      id: 'tcp:${endpoint.host}:${endpoint.port}',
      name: endpoint.name ?? endpoint.displayAddress,
      type: TransportType.network,
      address: endpoint.displayAddress,
    );

    final connectionNotifier = ref.read(deviceConnectionProvider.notifier);
    final endpointsNotifier = ref.read(networkEndpointsProvider.notifier);
    await connectionNotifier.connectToDevice(deviceInfo);

    await endpointsNotifier.updateLastUsed(endpoint.id);

    if (!mounted) return;
    widget.onConnectionSuccess?.call(deviceInfo);
  }

  /// Dev/debug MeshCore TCP path — bypasses the Meshtastic transport
  /// stack entirely and drives [ConnectionCoordinator.connectMeshCoreTcp].
  /// Endpoint persistence is the same as Meshtastic, but the connect
  /// flow has no provider/transport overlap.
  ///
  /// Also persists `lastDeviceId` and `lastDeviceProtocol` so the
  /// auto-reconnect path on next app launch can re-dispatch through
  /// the TCP fast-path in `_startMeshCoreBackgroundConnection`.
  Future<void> _connectMeshCoreEndpoint(
    NetworkEndpoint endpoint,
    AppLocalizations l10n,
  ) async {
    // Capture providers before any await — ref invalidation is safe
    // here because we re-check `mounted` after each await boundary.
    final coordinator = ref.read(connectionCoordinatorProvider);
    final endpointsNotifier = ref.read(networkEndpointsProvider.notifier);
    final settingsFuture = ref.read(settingsServiceProvider.future);

    final result = await coordinator.connectMeshCoreTcp(
      host: endpoint.host,
      port: endpoint.port,
    );

    if (!mounted) return;
    if (!result.success) {
      throw Exception(result.errorMessage ?? 'MeshCore TCP connect failed');
    }
    await endpointsNotifier.updateLastUsed(endpoint.id);

    final deviceId = 'meshcore-tcp:${endpoint.host}:${endpoint.port}';
    final deviceName = endpoint.name ?? 'MeshCore ${endpoint.displayAddress}';

    // Persist for auto-reconnect on next launch. The synthesized id
    // (`meshcore-tcp:host:port`) is recognised by the TCP fast-path in
    // `_startMeshCoreBackgroundConnection`, which parses host/port from
    // the prefix and re-dispatches via `connectMeshCoreTcp`.
    final settings = await settingsFuture;
    await settings.setLastDevice(
      deviceId,
      'network', // matches TransportType.network → string mapping
      deviceName: deviceName,
      protocol: 'meshcore',
    );

    if (!mounted) return;
    widget.onConnectionSuccess?.call(
      DeviceInfo(
        id: deviceId,
        name: deviceName,
        type: TransportType.network,
        address: endpoint.displayAddress,
      ),
    );
  }

  void _showAddEndpointSheet() {
    ref.haptics.buttonTap();
    final notifier = ref.read(networkEndpointsProvider.notifier);
    AppBottomSheet.show(
      context: context,
      child: _AddEndpointForm(
        onSave: (endpoint) async {
          await notifier.addEndpoint(endpoint);
        },
      ),
    );
  }

  Future<void> _deleteEndpoint(NetworkEndpoint endpoint) async {
    final l10n = context.l10n;
    final notifier = ref.read(networkEndpointsProvider.notifier);
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.networkDeleteEndpoint,
      message: l10n.networkDeleteEndpointConfirm(endpoint.displayAddress),
    );
    if (confirmed == true && mounted) {
      await notifier.removeEndpoint(endpoint.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final endpoints = ref.watch(networkEndpointsProvider);
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
                l10n.networkSavedEndpoints,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              if (endpoints.isNotEmpty) ...[
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
                    '${endpoints.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.accentColor,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              FilledButton.icon(
                onPressed: _showAddEndpointSheet,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.networkAddEndpoint),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing16,
                    vertical: AppTheme.spacing8,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Error banner
        if (_errorMessage != null)
          Container(
            margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
            padding: const EdgeInsets.all(AppTheme.spacing12),
            decoration: BoxDecoration(
              color: SemanticColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radius8),
              border: Border.all(
                color: SemanticColors.error.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: SemanticColors.error,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(fontSize: 14, color: SemanticColors.error),
                  ),
                ),
              ],
            ),
          ),

        // Endpoint list or empty state
        if (endpoints.isEmpty)
          _buildEmptyState(l10n)
        else
          ...endpoints.map(
            (endpoint) => _EndpointCard(
              endpoint: endpoint,
              isConnecting: _connectingEndpointId == endpoint.id,
              onTap: () => _connectToEndpoint(endpoint),
              onDelete: () => _deleteEndpoint(endpoint),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(dynamic l10n) {
    if (widget.compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
        child: Center(
          child: Text(
            l10n.networkNoSavedEndpoints,
            style: TextStyle(fontSize: 14, color: context.textTertiary),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.lan_outlined,
              size: 48,
              color: context.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              l10n.networkNoSavedEndpoints,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing32,
              ),
              child: Text(
                l10n.networkNoSavedEndpointsDescription,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: context.textTertiary),
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            FilledButton.icon(
              onPressed: _showAddEndpointSheet,
              icon: const Icon(Icons.add),
              label: Text(l10n.networkAddEndpoint),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card displaying a saved network endpoint.
class _EndpointCard extends StatelessWidget {
  final NetworkEndpoint endpoint;
  final bool isConnecting;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _EndpointCard({
    required this.endpoint,
    required this.isConnecting,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
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
                      : Icon(Icons.lan, color: context.accentColor, size: 24),
                ),
                const SizedBox(width: AppTheme.spacing16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              endpoint.name ?? endpoint.displayAddress,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: context.textPrimary,
                              ),
                            ),
                          ),
                          if (endpoint.protocol ==
                              NetworkEndpointProtocol.meshcore) ...[
                            const SizedBox(width: AppTheme.spacing8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AccentColors.purple.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius4,
                                ),
                              ),
                              child: Text(
                                // Brand identifier; not localized.
                                'MeshCore', // lint-allow: hardcoded-string
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AccentColors.purple,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacing4),
                      if (endpoint.name != null)
                        Text(
                          endpoint.displayAddress,
                          style: TextStyle(
                            fontSize: 14,
                            color: context.textTertiary,
                          ),
                        ),
                      Text(
                        context.l10n.networkLastUsed(
                          _formatLastUsed(context, endpoint.lastUsed),
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: context.textTertiary,
                    size: 20,
                  ),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatLastUsed(BuildContext context, DateTime lastUsed) {
    final l10n = context.l10n;
    final diff = DateTime.now().difference(lastUsed);
    if (diff.inMinutes < 1) {
      return l10n.commonJustNow;
    }
    if (diff.inHours < 1) {
      return l10n.commonMinutesAgo(diff.inMinutes);
    }
    if (diff.inDays < 1) {
      return l10n.commonHoursAgo(diff.inHours);
    }
    return l10n.commonDaysAgo(diff.inDays);
  }
}

/// Bottom sheet form for adding a new network endpoint.
class _AddEndpointForm extends ConsumerStatefulWidget {
  final Future<void> Function(NetworkEndpoint endpoint) onSave;

  const _AddEndpointForm({required this.onSave});

  @override
  ConsumerState<_AddEndpointForm> createState() => _AddEndpointFormState();
}

class _AddEndpointFormState extends ConsumerState<_AddEndpointForm>
    with LifecycleSafeMixin {
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(
    text: kMeshtasticDefaultPort.toString(),
  );
  final _nameController = TextEditingController();
  bool _saving = false;
  NetworkEndpointProtocol _protocol = NetworkEndpointProtocol.meshtastic;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// Default the port (and clear it from any previous default) when the
  /// user toggles the protocol chip. Only changes the field if it
  /// currently holds the *other* protocol's default — never overrides a
  /// user-entered custom value.
  void _setProtocol(NetworkEndpointProtocol next) {
    if (_protocol == next) return;
    final currentText = _portController.text.trim();
    final isMeshtasticDefault =
        currentText == kMeshtasticDefaultPort.toString();
    final isMeshcoreDefault = currentText == kMeshCoreDefaultTcpPort.toString();
    setState(() {
      _protocol = next;
      if (next == NetworkEndpointProtocol.meshcore && isMeshtasticDefault) {
        _portController.text = kMeshCoreDefaultTcpPort.toString();
      } else if (next == NetworkEndpointProtocol.meshtastic &&
          isMeshcoreDefault) {
        _portController.text = kMeshtasticDefaultPort.toString();
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final host = _hostController.text.trim();
    final fallbackPort = _protocol == NetworkEndpointProtocol.meshcore
        ? kMeshCoreDefaultTcpPort
        : kMeshtasticDefaultPort;
    final port = int.tryParse(_portController.text.trim()) ?? fallbackPort;
    final name = _nameController.text.trim();

    final endpoint = NetworkEndpoint.create(
      host: host,
      port: port,
      name: name.isEmpty ? null : name,
      protocol: _protocol,
    );

    await widget.onSave(endpoint);

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.networkAddEndpoint,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            if (AppFeatureFlags.isMeshCoreEnabled) ...[
              const SizedBox(height: AppTheme.spacing16),
              ChipSelector<NetworkEndpointProtocol>(
                value: _protocol,
                onChanged: _saving ? null : _setProtocol,
                options: [
                  ChipOption(
                    value: NetworkEndpointProtocol.meshtastic,
                    label: l10n.networkProtocolMeshtastic,
                    icon: Icons.lan,
                    color: context.accentColor,
                  ),
                  ChipOption(
                    value: NetworkEndpointProtocol.meshcore,
                    label: l10n.networkProtocolMeshcoreDev,
                    icon: Icons.developer_mode,
                    color: AccentColors.purple,
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppTheme.spacing24),
            TextFormField(
              controller: _hostController,
              maxLength: 253,
              decoration: InputDecoration(
                labelText: l10n.networkHost,
                hintText: l10n.networkHostHint,
                prefixIcon: const Icon(Icons.lan),
                counterText: '',
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.networkHostRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacing16),
            TextFormField(
              controller: _portController,
              maxLength: 5,
              decoration: InputDecoration(
                labelText: l10n.networkPort,
                hintText: kMeshtasticDefaultPort.toString(),
                prefixIcon: const Icon(Icons.tag),
                counterText: '',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                final port = int.tryParse(value.trim());
                if (port == null || port < 1 || port > 65535) {
                  return l10n.networkPortInvalid;
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacing16),
            TextFormField(
              controller: _nameController,
              maxLength: 64,
              decoration: InputDecoration(
                labelText: l10n.networkEndpointName,
                hintText: l10n.networkEndpointNameHint,
                prefixIcon: const Icon(Icons.label_outline),
                counterText: '',
              ),
            ),
            const SizedBox(height: AppTheme.spacing24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spacing16,
                  horizontal: AppTheme.spacing24,
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n.networkAddEndpoint),
            ),
          ],
        ),
      ),
    );
  }
}
