import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/widgets/animations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../utils/snackbar.dart';
import '../../generated/meshtastic/mesh.pb.dart' as pb;

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
  StreamSubscription<pb.Config_SecurityConfig>? _configSubscription;

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

  void _applyConfig(pb.Config_SecurityConfig config) {
    setState(() {
      _isManaged = config.isManaged;
      _serialEnabled = config.serialEnabled;
      _debugLogEnabled = config.debugLogApiEnabled;
      _adminChannelEnabled = config.adminChannelEnabled;
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
        await protocol.getConfig(pb.AdminMessage_ConfigType.SECURITY_CONFIG);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveConfig() async {
    final protocol = ref.read(protocolServiceProvider);

    setState(() => _saving = true);

    try {
      await protocol.setSecurityConfig(
        isManaged: _isManaged,
        serialEnabled: _serialEnabled,
        debugLogEnabled: _debugLogEnabled,
        adminChannelEnabled: _adminChannelEnabled,
      );

      if (mounted) {
        showAppSnackBar(context, 'Security configuration saved');
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
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'Security',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _saving ? null : _saveConfig,
              child: _saving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.accentColor,
                      ),
                    )
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
          ? Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
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
                const SizedBox(height: 16),

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
                      const Expanded(
                        child: Text(
                          'Disabling serial console or enabling managed mode may make it difficult to recover the device. Make sure you understand the implications before making changes.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
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
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.textTertiary,
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
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppTheme.textSecondary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textTertiary,
                    ),
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
