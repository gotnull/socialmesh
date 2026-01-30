import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/widgets/animations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../generated/meshtastic/config.pb.dart' as config_pb;
import '../../generated/meshtastic/admin.pbenum.dart' as admin_pbenum;
import 'package:cryptography/cryptography.dart';
import '../../core/widgets/loading_indicator.dart';

class SecurityConfigScreen extends ConsumerStatefulWidget {
  const SecurityConfigScreen({super.key});

  @override
  ConsumerState<SecurityConfigScreen> createState() =>
      _SecurityConfigScreenState();
}

class _SecurityConfigScreenState extends ConsumerState<SecurityConfigScreen> {
  bool _isManaged = false;
  bool _serialEnabled = true;
  bool _debugLogEnabled = false;
  bool _adminChannelEnabled = false;
  bool _saving = false;
  bool _loading = false;

  // PKI Keys
  String _publicKey = '';
  String _privateKey = '';
  String _adminKey1 = '';
  String _adminKey2 = '';
  String _adminKey3 = '';
  bool _privateKeyVisible = false;

  StreamSubscription<config_pb.Config_SecurityConfig>? _configSubscription;

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

  void _applyConfig(config_pb.Config_SecurityConfig config) {
    setState(() {
      _isManaged = config.isManaged;
      _serialEnabled = config.serialEnabled;
      _debugLogEnabled = config.debugLogApiEnabled;
      _adminChannelEnabled = config.adminChannelEnabled;

      // PKI Keys
      if (config.publicKey.isNotEmpty) {
        _publicKey = base64Encode(config.publicKey);
      }
      if (config.privateKey.isNotEmpty) {
        _privateKey = base64Encode(config.privateKey);
      }
      // Admin keys are stored as a list
      final adminKeys = config.adminKey;
      if (adminKeys.isNotEmpty) {
        _adminKey1 = base64Encode(adminKeys[0]);
      }
      if (adminKeys.length > 1) {
        _adminKey2 = base64Encode(adminKeys[1]);
      }
      if (adminKeys.length > 2) {
        _adminKey3 = base64Encode(adminKeys[2]);
      }
    });
  }

  Future<void> _loadCurrentConfig() async {
    setState(() => _loading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);

      // Apply cached config immediately if available
      final cached = protocol.currentSecurityConfig;
      if (cached != null) {
        _applyConfig(cached);
      }

      // Only request from device if connected
      if (protocol.isConnected) {
        // Listen for config response
        _configSubscription = protocol.securityConfigStream.listen((config) {
          if (mounted) _applyConfig(config);
        });

        // Request fresh config from device
        await protocol.getConfig(
          admin_pbenum.AdminMessage_ConfigType.SECURITY_CONFIG,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Generate a new Curve25519 private key
  Future<void> _regeneratePrivateKey() async {
    try {
      final algorithm = X25519();
      final keyPair = await algorithm.newKeyPair();
      final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
      final publicKey = await keyPair.extractPublicKey();

      setState(() {
        _privateKey = base64Encode(Uint8List.fromList(privateKeyBytes));
        _publicKey = base64Encode(Uint8List.fromList(publicKey.bytes));
        _privateKeyVisible = true;
      });

      if (mounted) {
        showSuccessSnackBar(context, 'New key pair generated');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to generate key: $e');
      }
    }
  }

  /// Recalculate public key from private key
  Future<void> _recalculatePublicKey() async {
    if (_privateKey.isEmpty) return;

    try {
      final privateKeyBytes = base64Decode(_privateKey);
      if (privateKeyBytes.length != 32) return;

      final algorithm = X25519();
      final keyPair = await algorithm.newKeyPairFromSeed(privateKeyBytes);
      final publicKey = await keyPair.extractPublicKey();

      setState(() {
        _publicKey = base64Encode(Uint8List.fromList(publicKey.bytes));
      });
    } catch (e) {
      AppLogging.settings('Failed to recalculate public key: $e');
    }
  }

  bool _isValidBase64Key(String key) {
    if (key.isEmpty) return true; // Empty is valid (means unset)
    try {
      final bytes = base64Decode(key);
      return bytes.length == 32;
    } catch (e) {
      return false;
    }
  }

  Future<void> _saveConfig() async {
    // Validate keys
    if (!_isValidBase64Key(_privateKey)) {
      showErrorSnackBar(context, 'Invalid private key format');
      return;
    }
    if (!_isValidBase64Key(_adminKey1) ||
        !_isValidBase64Key(_adminKey2) ||
        !_isValidBase64Key(_adminKey3)) {
      showErrorSnackBar(context, 'Invalid admin key format');
      return;
    }

    final protocol = ref.read(protocolServiceProvider);

    setState(() => _saving = true);

    try {
      // Convert base64 keys to bytes
      final privateKeyBytes = _privateKey.isNotEmpty
          ? base64Decode(_privateKey)
          : <int>[];
      final adminKeys = <List<int>>[];
      if (_adminKey1.isNotEmpty) adminKeys.add(base64Decode(_adminKey1));
      if (_adminKey2.isNotEmpty) adminKeys.add(base64Decode(_adminKey2));
      if (_adminKey3.isNotEmpty) adminKeys.add(base64Decode(_adminKey3));

      await protocol.setSecurityConfig(
        isManaged: _isManaged,
        serialEnabled: _serialEnabled,
        debugLogEnabled: _debugLogEnabled,
        adminChannelEnabled: _adminChannelEnabled,
        privateKey: privateKeyBytes,
        adminKeys: adminKeys,
      );

      if (mounted) {
        showSuccessSnackBar(context, 'Security configuration saved');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to save: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        title: Text(
          'Security',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _saving ? null : _saveConfig,
              child: _saving
                  ? LoadingIndicator(size: 20)
                  : Text(
                      'Save',
                      style: TextStyle(
                        color: context.accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const ScreenLoadingIndicator()
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // PKI Keys Section
                const _SectionHeader(title: 'DIRECT MESSAGE KEY'),
                _buildKeySection(),
                SizedBox(height: 16),

                // Admin Keys Section
                const _SectionHeader(title: 'ADMIN KEYS'),
                _buildAdminKeysSection(),
                const SizedBox(height: 16),

                // Managed Device
                const _SectionHeader(title: 'DEVICE MANAGEMENT'),

                _SettingsTile(
                  icon: Icons.admin_panel_settings,
                  iconColor: _isManaged ? context.accentColor : null,
                  title: 'Managed Mode',
                  subtitle: 'Device is managed by an external system',
                  trailing: ThemedSwitch(
                    value: _isManaged,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _isManaged = value);
                    },
                  ),
                ),
                SizedBox(height: 16),

                // Access Controls
                const _SectionHeader(title: 'ACCESS CONTROLS'),

                _SettingsTile(
                  icon: Icons.usb,
                  iconColor: _serialEnabled ? context.accentColor : null,
                  title: 'Serial Console',
                  subtitle: 'Enable USB serial console access',
                  trailing: ThemedSwitch(
                    value: _serialEnabled,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _serialEnabled = value);
                    },
                  ),
                ),
                _SettingsTile(
                  icon: Icons.bug_report,
                  iconColor: _debugLogEnabled ? context.accentColor : null,
                  title: 'Debug Logging',
                  subtitle: 'Enable verbose debug log output',
                  trailing: ThemedSwitch(
                    value: _debugLogEnabled,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _debugLogEnabled = value);
                    },
                  ),
                ),
                _SettingsTile(
                  icon: Icons.security,
                  iconColor: _adminChannelEnabled ? context.accentColor : null,
                  title: 'Admin Channel',
                  subtitle: 'Allow remote admin via admin channel',
                  trailing: ThemedSwitch(
                    value: _adminChannelEnabled,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _adminChannelEnabled = value);
                    },
                  ),
                ),
                SizedBox(height: 16),

                // Warning card
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.errorRed.withValues(alpha: 0.3),
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.shield,
                        color: AppTheme.errorRed.withValues(alpha: 0.8),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Disabling serial console or enabling managed mode may make it difficult to recover the device. Make sure you understand the implications before making changes.',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildKeySection() {
    final isValidPrivateKey = _isValidBase64Key(_privateKey);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Public Key (read-only display)
          Row(
            children: [
              Icon(Icons.key, color: context.textSecondary, size: 20),
              SizedBox(width: 8),
              Text(
                'Public Key',
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.border),
            ),
            child: SelectableText(
              _publicKey.isEmpty ? 'No key set' : _publicKey,
              style: TextStyle(
                color: _publicKey.isEmpty
                    ? context.textTertiary
                    : context.textPrimary,
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
              ),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Your public key is sent to other nodes for secure messaging',
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),

          Divider(height: 24, color: context.border),

          // Private Key
          Row(
            children: [
              Icon(Icons.vpn_key, color: context.textSecondary, size: 20),
              SizedBox(width: 8),
              Text(
                'Private Key',
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  _privateKeyVisible ? Icons.visibility_off : Icons.visibility,
                  color: context.textSecondary,
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _privateKeyVisible = !_privateKeyVisible);
                },
              ),
            ],
          ),
          SizedBox(height: 8),
          TextField(
            obscureText: !_privateKeyVisible,
            style: TextStyle(
              color: context.textPrimary,
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.all(12),
              fillColor: context.background,
              filled: true,
              hintText: 'Base64 encoded 32-byte key',
              hintStyle: TextStyle(color: context.textTertiary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isValidPrivateKey ? context.border : AppTheme.errorRed,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isValidPrivateKey ? context.border : AppTheme.errorRed,
                ),
              ),
            ),
            controller: TextEditingController(text: _privateKey),
            onChanged: (value) {
              setState(() => _privateKey = value);
              _recalculatePublicKey();
            },
          ),
          SizedBox(height: 4),
          Text(
            'Used to compute shared secret with remote devices',
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),

          Divider(height: 24, color: context.border),

          // Regenerate button
          Row(
            children: [
              Icon(Icons.refresh, color: context.textSecondary, size: 20),
              SizedBox(width: 8),
              Text(
                'Regenerate Key Pair',
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _regeneratePrivateKey,
                icon: Icon(Icons.autorenew, size: 18),
                label: const Text('Generate'),
                style: TextButton.styleFrom(
                  foregroundColor: context.accentColor,
                ),
              ),
            ],
          ),
          Text(
            'Generate a new key pair (public key will be automatically derived)',
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),

          Divider(height: 24, color: context.border),

          // Key Backup Section
          Row(
            children: [
              Icon(Icons.cloud_upload, color: context.textSecondary, size: 20),
              SizedBox(width: 8),
              Text(
                'Key Backup',
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Backup your private key to secure storage for recovery. Keys are stored in the device keychain with iCloud sync enabled.',
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _privateKey.isEmpty ? null : _backupPrivateKey,
                  icon: Icon(Icons.backup, size: 18),
                  label: Text('Backup'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.accentColor,
                    side: BorderSide(color: context.accentColor.withValues(alpha: 0.5)),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _restorePrivateKey,
                  icon: Icon(Icons.restore, size: 18),
                  label: Text('Restore'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.textSecondary,
                    side: BorderSide(color: context.border),
                  ),
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                onPressed: _deleteBackup,
                icon: Icon(Icons.delete_outline, size: 20),
                color: AppTheme.errorRed,
                tooltip: 'Delete backup',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Backup private key to secure storage
  Future<void> _backupPrivateKey() async {
    if (_privateKey.isEmpty) return;

    try {
      final nodeNum = ref.read(protocolServiceProvider).myNodeNum;
      if (nodeNum == null) {
        if (mounted) showErrorSnackBar(context, 'No connected device');
        return;
      }

      const storage = FlutterSecureStorage(
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock,
          synchronizable: true, // Enable iCloud Keychain sync
        ),
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );

      await storage.write(
        key: 'PrivateKeyNode$nodeNum',
        value: _privateKey,
      );

      AppLogging.settings('Backed up private key for node $nodeNum');
      if (mounted) {
        showSuccessSnackBar(context, 'Private key backed up to secure storage');
      }
    } catch (e) {
      AppLogging.settings('Failed to backup private key: $e');
      if (mounted) {
        showErrorSnackBar(context, 'Failed to backup key: $e');
      }
    }
  }

  /// Restore private key from secure storage
  Future<void> _restorePrivateKey() async {
    try {
      final nodeNum = ref.read(protocolServiceProvider).myNodeNum;
      if (nodeNum == null) {
        if (mounted) showErrorSnackBar(context, 'No connected device');
        return;
      }

      const storage = FlutterSecureStorage(
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock,
          synchronizable: true,
        ),
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );

      final storedKey = await storage.read(key: 'PrivateKeyNode$nodeNum');
      if (storedKey == null) {
        if (mounted) {
          showErrorSnackBar(context, 'No backup found for this device');
        }
        return;
      }

      setState(() {
        _privateKey = storedKey;
        _privateKeyVisible = true;
      });
      await _recalculatePublicKey();

      AppLogging.settings('Restored private key for node $nodeNum');
      if (mounted) {
        showSuccessSnackBar(context, 'Private key restored from backup');
      }
    } catch (e) {
      AppLogging.settings('Failed to restore private key: $e');
      if (mounted) {
        showErrorSnackBar(context, 'Failed to restore key: $e');
      }
    }
  }

  /// Delete backed up private key
  Future<void> _deleteBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surface,
        title: Text('Delete Backup?', style: TextStyle(color: context.textPrimary)),
        content: Text(
          'This will permanently delete the backed up private key from secure storage. This cannot be undone.',
          style: TextStyle(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final nodeNum = ref.read(protocolServiceProvider).myNodeNum;
      if (nodeNum == null) {
        if (mounted) showErrorSnackBar(context, 'No connected device');
        return;
      }

      const storage = FlutterSecureStorage(
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock,
          synchronizable: true,
        ),
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );

      await storage.delete(key: 'PrivateKeyNode$nodeNum');

      AppLogging.settings('Deleted private key backup for node $nodeNum');
      if (mounted) {
        showSuccessSnackBar(context, 'Backup deleted');
      }
    } catch (e) {
      AppLogging.settings('Failed to delete backup: $e');
      if (mounted) {
        showErrorSnackBar(context, 'Failed to delete backup: $e');
      }
    }
  }

  Widget _buildAdminKeysSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Public keys authorized to send admin messages to this node',
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Admin Key 1
          _buildAdminKeyField(
            label: 'Primary Admin Key',
            value: _adminKey1,
            onChanged: (v) => setState(() => _adminKey1 = v),
          ),
          const SizedBox(height: 12),

          // Admin Key 2
          _buildAdminKeyField(
            label: 'Secondary Admin Key',
            value: _adminKey2,
            onChanged: (v) => setState(() => _adminKey2 = v),
          ),
          const SizedBox(height: 12),

          // Admin Key 3
          _buildAdminKeyField(
            label: 'Tertiary Admin Key',
            value: _adminKey3,
            onChanged: (v) => setState(() => _adminKey3 = v),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminKeyField({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    final isValid = _isValidBase64Key(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.admin_panel_settings,
              color: context.textSecondary,
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          style: TextStyle(
            color: context.textPrimary,
            fontFamily: AppTheme.fontFamily,
            fontSize: 11,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.all(12),
            fillColor: context.background,
            filled: true,
            hintText: 'Base64 encoded public key',
            hintStyle: TextStyle(color: context.textTertiary, fontSize: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isValid ? context.border : AppTheme.errorRed,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isValid ? context.border : AppTheme.errorRed,
              ),
            ),
          ),
          controller: TextEditingController(text: value),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: context.textTertiary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? context.textSecondary),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: context.textTertiary),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
