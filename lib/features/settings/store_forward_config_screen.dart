import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../providers/app_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';

/// Screen for configuring Store & Forward module
class StoreForwardConfigScreen extends ConsumerStatefulWidget {
  const StoreForwardConfigScreen({super.key});

  @override
  ConsumerState<StoreForwardConfigScreen> createState() =>
      _StoreForwardConfigScreenState();
}

class _StoreForwardConfigScreenState
    extends ConsumerState<StoreForwardConfigScreen> {
  bool _enabled = false;
  bool _isServer = false;
  bool _heartbeat = false;
  int _records = 0;
  int _historyReturnMax = 100;
  int _historyReturnWindow = 240; // minutes
  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    final protocol = ref.read(protocolServiceProvider);

    // Only request from device if connected
    if (!protocol.isConnected) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final config = await protocol.getStoreForwardModuleConfig();
    if (config != null && mounted) {
      setState(() {
        _enabled = config.enabled;
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
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);

    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.setStoreForwardConfig(
        enabled: _enabled,
        heartbeat: _heartbeat,
        records: _records,
        historyReturnMax: _historyReturnMax,
        historyReturnWindow: _historyReturnWindow,
      );

      if (mounted) {
        showSuccessSnackBar(context, 'Store & Forward configuration saved');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to save config: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.surface,
        title: Text('Store & Forward'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveConfig,
            child: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: MeshLoadingIndicator(size: 20),
                  )
                : Text('Save', style: TextStyle(color: context.accentColor)),
          ),
        ],
      ),
      body: _isLoading
          ? const ScreenLoadingIndicator()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info card
                _buildInfoCard(),

                const SizedBox(height: 16),

                // Module settings
                _buildSectionTitle('Module Settings'),
                _buildConfigCard(),

                const SizedBox(height: 16),

                // Server settings (only shown if server mode)
                if (_isServer) ...[
                  _buildSectionTitle('Server Settings'),
                  _buildServerSettingsCard(),
                ],
              ],
            ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.storage, color: AppTheme.primaryBlue, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Store & Forward',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Allows nodes to store messages and forward them to devices that were offline. '
                  'A "server" node stores messages, while "client" nodes can request missed messages.',
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Enable Store & Forward',
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              'Participate in the S&F network',
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
              'Act as Server',
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              'Store messages for other nodes (uses more RAM)',
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
              'Heartbeat',
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              'Send periodic announcements to the mesh',
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Records Limit',
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              _records == 0 ? 'Use device default' : '$_records records',
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
                  _records == 0 ? 'Auto' : '$_records',
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
              'History Return Max',
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              'Max $_historyReturnMax messages per request',
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
              'History Window',
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              'Keep messages for ${_historyReturnWindow ~/ 60} hours',
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
