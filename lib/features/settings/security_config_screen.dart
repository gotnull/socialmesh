import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Security configuration saved'),
            backgroundColor: AppTheme.darkCard,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _saving ? null : _saveConfig,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryGreen,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Managed Device
          const Text(
            'DEVICE MANAGEMENT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textTertiary,
              letterSpacing: 1,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              title: const Text(
                'Managed Mode',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
              ),
              subtitle: const Text(
                'Device is managed by an external system',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontFamily: 'Inter',
                ),
              ),
              value: _isManaged,
              onChanged: (value) => setState(() => _isManaged = value),
              activeTrackColor: AppTheme.primaryGreen,
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return AppTheme.textSecondary;
              }),
              secondary: const Icon(
                Icons.admin_panel_settings,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Access Controls
          const Text(
            'ACCESS CONTROLS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textTertiary,
              letterSpacing: 1,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Serial Console',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
                    ),
                  ),
                  subtitle: const Text(
                    'Enable USB serial console access',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontFamily: 'Inter',
                    ),
                  ),
                  value: _serialEnabled,
                  onChanged: (value) => setState(() => _serialEnabled = value),
                  activeTrackColor: AppTheme.primaryGreen,
                  thumbColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.white;
                    }
                    return AppTheme.textSecondary;
                  }),
                  secondary: const Icon(
                    Icons.usb,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: AppTheme.darkBorder,
                ),
                SwitchListTile(
                  title: const Text(
                    'Debug Logging',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
                    ),
                  ),
                  subtitle: const Text(
                    'Enable verbose debug log output',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontFamily: 'Inter',
                    ),
                  ),
                  value: _debugLogEnabled,
                  onChanged: (value) =>
                      setState(() => _debugLogEnabled = value),
                  activeTrackColor: AppTheme.primaryGreen,
                  thumbColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.white;
                    }
                    return AppTheme.textSecondary;
                  }),
                  secondary: const Icon(
                    Icons.bug_report,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: AppTheme.darkBorder,
                ),
                SwitchListTile(
                  title: const Text(
                    'Admin Channel',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
                    ),
                  ),
                  subtitle: const Text(
                    'Allow remote admin via admin channel',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontFamily: 'Inter',
                    ),
                  ),
                  value: _adminChannelEnabled,
                  onChanged: (value) =>
                      setState(() => _adminChannelEnabled = value),
                  activeTrackColor: AppTheme.primaryGreen,
                  thumbColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.white;
                    }
                    return AppTheme.textSecondary;
                  }),
                  secondary: const Icon(
                    Icons.security,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Warning card
          Container(
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
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
