// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/transport.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../utils/snackbar.dart';

/// Dev-only default endpoint for the MeshCore TCP companion radio.
///
/// Used during simulator E2E validation when no BLE peer is available.
/// This must NEVER be referenced from a production code path —
/// [MeshCoreTcpDevSection] is itself gated by [kDebugMode].
const _kMeshCoreTcpDevDefaultHost = '192.168.5.109';
const _kMeshCoreTcpDevDefaultPort = 5000;

/// Debug-build entry point for connecting to a MeshCore companion radio
/// over TCP from the simulator.
///
/// Invisible (returns [SizedBox.shrink]) in release builds. In debug
/// builds it surfaces a single button that opens an inline form with
/// host/port fields prefilled to the dev default endpoint. Tapping
/// "Connect" drives [ConnectionCoordinator.connectMeshCoreTcp] directly,
/// bypassing BLE detection.
///
/// Endpoint values are not persisted in this slice — re-typed on each
/// run. This keeps the surface unmistakably dev-scoped.
class MeshCoreTcpDevSection extends ConsumerStatefulWidget {
  final ValueChanged<DeviceInfo>? onConnectionSuccess;

  const MeshCoreTcpDevSection({super.key, this.onConnectionSuccess});

  @override
  ConsumerState<MeshCoreTcpDevSection> createState() =>
      _MeshCoreTcpDevSectionState();
}

class _MeshCoreTcpDevSectionState extends ConsumerState<MeshCoreTcpDevSection>
    with LifecycleSafeMixin {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  bool _expanded = false;
  bool _connecting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: _kMeshCoreTcpDevDefaultHost);
    _portController = TextEditingController(
      text: _kMeshCoreTcpDevDefaultPort.toString(),
    );
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_connecting) return;
    final host = _hostController.text.trim();
    final portText = _portController.text.trim();
    if (host.isEmpty) {
      safeSetState(() => _errorMessage = 'Host required');
      return;
    }
    final port = int.tryParse(portText);
    if (port == null || port <= 0 || port > 65535) {
      safeSetState(() => _errorMessage = 'Port must be 1–65535');
      return;
    }

    safeSetState(() {
      _connecting = true;
      _errorMessage = null;
    });

    final coordinator = ref.read(connectionCoordinatorProvider);
    AppLogging.connection('MeshCoreTcpDevSection: dev connect to $host:$port');

    try {
      final result = await coordinator.connectMeshCoreTcp(
        host: host,
        port: port,
      );
      if (!mounted) return;
      if (result.success) {
        widget.onConnectionSuccess?.call(
          DeviceInfo(
            id: 'meshcore-tcp:$host:$port',
            name: 'MeshCore TCP $host:$port',
            type: TransportType.network,
          ),
        );
      } else {
        safeSetState(() {
          _errorMessage = result.errorMessage ?? 'Connect failed';
        });
        showErrorSnackBar(
          context,
          'MeshCore TCP: ${result.errorMessage ?? 'failed'}',
        );
      }
    } catch (e) {
      if (mounted) {
        safeSetState(() => _errorMessage = e.toString());
        showErrorSnackBar(context, 'MeshCore TCP: $e');
      }
    } finally {
      if (mounted) {
        safeSetState(() => _connecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    if (!_expanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing8,
        ),
        child: OutlinedButton.icon(
          onPressed: () => safeSetState(() => _expanded = true),
          icon: const Icon(Icons.developer_mode, size: 16),
          // Debug-only label; not localized on purpose.
          label: const Text(
            'Connect MeshCore TCP (dev)',
            // lint-allow: hardcoded-string
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing8,
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.developer_mode, size: 16, color: context.textTertiary),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                // Debug-only label; not localized on purpose.
                'MeshCore TCP (dev)', // lint-allow: hardcoded-string
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: context.textTertiary,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: context.textTertiary,
                onPressed: _connecting
                    ? null
                    : () => safeSetState(() => _expanded = false),
                tooltip: 'Hide', // lint-allow: hardcoded-string
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          TextField(
            controller: _hostController,
            maxLength: 253,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.url,
            textCapitalization: TextCapitalization.none,
            style: TextStyle(color: context.textPrimary),
            decoration: InputDecoration(
              labelText: 'Host', // lint-allow: hardcoded-string
              labelStyle: TextStyle(color: context.textSecondary),
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
              prefixIcon: Icon(Icons.dns, color: context.textSecondary),
              counterText: '',
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          TextField(
            controller: _portController,
            maxLength: 5,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(color: context.textPrimary),
            decoration: InputDecoration(
              labelText: 'Port', // lint-allow: hardcoded-string
              labelStyle: TextStyle(color: context.textSecondary),
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
              prefixIcon: Icon(Icons.numbers, color: context.textSecondary),
              counterText: '',
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppTheme.spacing8),
            Text(
              _errorMessage!,
              style: TextStyle(color: AppTheme.errorRed, fontSize: 12),
            ),
          ],
          const SizedBox(height: AppTheme.spacing12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _connecting ? null : _connect,
              icon: _connecting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bolt, size: 18),
              label: Text(
                _connecting
                    ? 'Connecting…' // lint-allow: hardcoded-string
                    : 'Connect', // lint-allow: hardcoded-string
              ),
            ),
          ),
        ],
      ),
    );
  }
}
