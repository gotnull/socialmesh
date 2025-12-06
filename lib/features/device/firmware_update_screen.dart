import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';

/// Provider for firmware update check
final firmwareCheckProvider = FutureProvider.autoDispose<FirmwareInfo?>((
  ref,
) async {
  try {
    // Fetch latest release from Meshtastic GitHub releases API
    final response = await http.get(
      Uri.parse('https://api.github.com/repos/meshtastic/firmware/releases/latest'),
      headers: {'Accept': 'application/vnd.github.v3+json'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      
      // Parse version from tag name (e.g., "v2.3.10" -> "2.3.10")
      final tagName = data['tag_name'] as String? ?? '';
      final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;
      
      // Parse published date
      final publishedAt = data['published_at'] as String?;
      final releaseDate = publishedAt != null 
          ? DateTime.parse(publishedAt) 
          : DateTime.now();
      
      // Get release notes body
      final body = data['body'] as String? ?? 'No release notes available.';
      
      // Get download URL
      final htmlUrl = data['html_url'] as String? ?? 
          'https://github.com/meshtastic/firmware/releases';

      return FirmwareInfo(
        latestVersion: version,
        releaseDate: releaseDate,
        releaseNotes: body,
        downloadUrl: htmlUrl,
      );
    } else {
      debugPrint('Failed to fetch firmware info: ${response.statusCode}');
      return null;
    }
  } catch (e) {
    debugPrint('Error fetching firmware info: $e');
    return null;
  }
});

class FirmwareInfo {
  final String latestVersion;
  final DateTime releaseDate;
  final String releaseNotes;
  final String downloadUrl;

  FirmwareInfo({
    required this.latestVersion,
    required this.releaseDate,
    required this.releaseNotes,
    required this.downloadUrl,
  });
}

class FirmwareUpdateScreen extends ConsumerWidget {
  const FirmwareUpdateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myNodeNum = ref.watch(myNodeNumProvider);
    final nodes = ref.watch(nodesProvider);
    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;
    final firmwareCheck = ref.watch(firmwareCheckProvider);

    final currentVersion = myNode?.firmwareVersion ?? 'Unknown';

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'Firmware Update',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              ref.invalidate(firmwareCheckProvider);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current Version Card
          _buildSectionHeader('Current Version'),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.memory,
                    color: context.accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Installed Firmware',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentVersion,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Device Info
          Container(
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  icon: Icons.developer_board,
                  label: 'Hardware',
                  value: myNode?.hardwareModel ?? 'Unknown',
                  context: context,
                ),
                _buildDivider(),
                _buildInfoRow(
                  icon: Icons.tag,
                  label: 'Node ID',
                  value: myNode?.nodeNum.toString() ?? 'Unknown',
                  context: context,
                ),
                _buildDivider(),
                _buildInfoRow(
                  icon: Icons.schedule,
                  label: 'Uptime',
                  value: myNode?.uptimeSeconds != null
                      ? _formatUptime(myNode!.uptimeSeconds!)
                      : 'Unknown',
                  context: context,
                ),
                if (myNode?.hasWifi == true) ...[
                  _buildDivider(),
                  _buildInfoRow(
                    icon: Icons.wifi,
                    label: 'WiFi',
                    value: 'Supported',
                    context: context,
                  ),
                ],
                if (myNode?.hasBluetooth == true) ...[
                  _buildDivider(),
                  _buildInfoRow(
                    icon: Icons.bluetooth,
                    label: 'Bluetooth',
                    value: 'Supported',
                    context: context,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Update Check
          _buildSectionHeader('Available Update'),
          firmwareCheck.when(
            data: (info) {
              if (info == null) {
                return _buildNoUpdateCard(context);
              }

              final isNewer = _isNewerVersion(
                currentVersion,
                info.latestVersion,
              );

              return Column(
                children: [
                  // Update Status Card
                  Container(
                    decoration: BoxDecoration(
                      color: isNewer
                          ? AppTheme.successGreen.withValues(alpha: 0.1)
                          : AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isNewer
                            ? AppTheme.successGreen.withValues(alpha: 0.3)
                            : AppTheme.darkBorder,
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color:
                                    (isNewer
                                            ? AppTheme.successGreen
                                            : AppTheme.textTertiary)
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isNewer
                                    ? Icons.system_update
                                    : Icons.check_circle,
                                color: isNewer
                                    ? AppTheme.successGreen
                                    : AppTheme.textTertiary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isNewer ? 'Update Available' : 'Up to Date',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isNewer
                                          ? AppTheme.successGreen
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Latest: ${info.latestVersion}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isNewer)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.successGreen,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'NEW',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (isNewer) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () =>
                                  _openDownloadPage(info.downloadUrl),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.successGreen,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.download),
                              label: const Text(
                                'Download Update',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (isNewer) ...[
                    const SizedBox(height: 16),

                    // Release Notes
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.darkBorder),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.notes,
                                color: context.accentColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Release Notes',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatDate(info.releaseDate),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            info.releaseNotes,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
            loading: () => Container(
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: context.accentColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Checking for updates...',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            error: (error, _) => Container(
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.errorRed.withValues(alpha: 0.3),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppTheme.errorRed,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Failed to check for updates',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.errorRed,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          error.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Update Instructions
          _buildSectionHeader('How to Update'),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildStep(
                  1,
                  'Download the firmware file for your device',
                  context,
                ),
                const SizedBox(height: 12),
                _buildStep(2, 'Connect your device via USB', context),
                const SizedBox(height: 12),
                _buildStep(
                  3,
                  'Use the Meshtastic Web Flasher or CLI to flash',
                  context,
                ),
                const SizedBox(height: 12),
                _buildStep(
                  4,
                  'Wait for device to reboot and reconnect',
                  context,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Web Flasher Link
          OutlinedButton.icon(
            onPressed: () => _openWebFlasher(),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.accentColor,
              side: BorderSide(color: context.accentColor),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Open Web Flasher'),
          ),

          const SizedBox(height: 32),

          // Warning
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warningYellow.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.warningYellow.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.warningYellow,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Backup Your Settings',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.warningYellow.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Firmware updates may reset your device configuration. '
                        'Consider exporting your settings before updating.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.warningYellow.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required BuildContext context,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: context.accentColor, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: AppTheme.darkBorder.withValues(alpha: 0.3),
    );
  }

  Widget _buildNoUpdateCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 48,
            color: AppTheme.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Unable to check for updates',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Visit the Meshtastic website for the latest firmware.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String text, BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: context.accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              number.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.accentColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }

  bool _isNewerVersion(String current, String latest) {
    // Simple version comparison
    final currentParts = current.replaceAll(RegExp(r'[^0-9.]'), '').split('.');
    final latestParts = latest.replaceAll(RegExp(r'[^0-9.]'), '').split('.');

    for (int i = 0; i < latestParts.length; i++) {
      final currentNum = i < currentParts.length
          ? int.tryParse(currentParts[i]) ?? 0
          : 0;
      final latestNum = int.tryParse(latestParts[i]) ?? 0;

      if (latestNum > currentNum) return true;
      if (latestNum < currentNum) return false;
    }

    return false;
  }

  String _formatUptime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m';
    if (seconds < 86400) {
      return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
    }
    return '${seconds ~/ 86400}d ${(seconds % 86400) ~/ 3600}h';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _openDownloadPage(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openWebFlasher() async {
    final uri = Uri.parse('https://flasher.meshtastic.org/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
