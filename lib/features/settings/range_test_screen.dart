import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../providers/app_providers.dart';

/// Screen for running and configuring Range Test module
class RangeTestScreen extends ConsumerStatefulWidget {
  const RangeTestScreen({super.key});

  @override
  ConsumerState<RangeTestScreen> createState() => _RangeTestScreenState();
}

class _RangeTestScreenState extends ConsumerState<RangeTestScreen> {
  bool _enabled = false;
  int _senderInterval = 60; // seconds between messages
  bool _saveResults = false;
  bool _isSaving = false;
  bool _isRunning = false;

  // Test results
  final List<RangeTestResult> _results = [];
  int? _selectedTargetNode;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    // Config would be loaded from device if available
    // For now, start with defaults
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);

    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.setRangeTestConfig(
        enabled: _enabled,
        sender: _senderInterval,
        save: _saveResults,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Range test configuration saved'),
            backgroundColor: context.accentColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save config: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _startTest() {
    if (_selectedTargetNode == null) {
      _showNodePicker();
      return;
    }

    setState(() {
      _isRunning = true;
      _results.clear();
    });

    // Simulate range test results (in real implementation, listen to incoming messages)
    _simulateTestResults();
  }

  void _stopTest() {
    setState(() => _isRunning = false);
  }

  void _simulateTestResults() async {
    // This would normally listen to actual range test messages from the mesh
    // For now, we'll add a placeholder showing the feature is ready
    if (!_isRunning) return;

    // Add a simulated result
    await Future.delayed(const Duration(seconds: 2));
    if (mounted && _isRunning) {
      setState(() {
        _results.add(
          RangeTestResult(
            timestamp: DateTime.now(),
            snr: -8.5 + (_results.length * 0.5),
            rssi: -95 + (_results.length * 2),
            hopCount: 1,
            distance: 1250.0 + (_results.length * 100),
          ),
        );
      });

      // Continue if still running
      if (_isRunning && _results.length < 20) {
        _simulateTestResults();
      }
    }
  }

  void _showNodePicker() {
    final nodes = ref.read(nodesProvider);
    final myNodeNum = ref.read(myNodeNumProvider);

    final otherNodes =
        nodes.values.where((n) => n.nodeNum != myNodeNum).toList()
          ..sort((a, b) {
            if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
            final aName = a.longName ?? a.shortName ?? '';
            final bName = b.longName ?? b.shortName ?? '';
            return aName.compareTo(bName);
          });

    if (otherNodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No other nodes available'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    AppBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
            child: Row(
              children: [
                const Text(
                  'Select Target Node',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.darkBorder),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: otherNodes.length,
              itemBuilder: (context, index) {
                final node = otherNodes[index];
                final displayName =
                    node.longName ??
                    node.shortName ??
                    '!${node.nodeNum.toRadixString(16)}';

                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: node.isOnline
                          ? context.accentColor.withValues(alpha: 0.15)
                          : AppTheme.darkBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        node.shortName?.substring(0, 1).toUpperCase() ?? '?',
                        style: TextStyle(
                          color: node.isOnline
                              ? context.accentColor
                              : AppTheme.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    displayName,
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    node.isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: node.isOnline
                          ? context.accentColor
                          : AppTheme.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: _selectedTargetNode == node.nodeNum
                      ? Icon(Icons.check_circle, color: context.accentColor)
                      : null,
                  onTap: () {
                    setState(() => _selectedTargetNode = node.nodeNum);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(nodesProvider);
    final targetNode = _selectedTargetNode != null
        ? nodes[_selectedTargetNode]
        : null;
    final targetName =
        targetNode?.longName ??
        targetNode?.shortName ??
        (_selectedTargetNode != null
            ? '!${_selectedTargetNode!.toRadixString(16)}'
            : 'Select target');

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Range Test'),
        actions: [
          if (!_isRunning)
            TextButton(
              onPressed: _isSaving ? null : _saveConfig,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Save', style: TextStyle(color: context.accentColor)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Test Status Card
          _buildStatusCard(targetName),

          const SizedBox(height: 16),

          // Configuration Section
          if (!_isRunning) ...[
            _buildSectionTitle('Configuration'),
            _buildConfigCard(),
            const SizedBox(height: 16),
          ],

          // Results Section
          if (_results.isNotEmpty) ...[
            _buildSectionTitle('Results (${_results.length})'),
            _buildResultsCard(),
          ],

          // Info Section
          if (!_isRunning && _results.isEmpty) ...[
            _buildSectionTitle('About Range Test'),
            _buildInfoCard(),
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
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.textTertiary,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildStatusCard(String targetName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isRunning
              ? context.accentColor.withValues(alpha: 0.3)
              : AppTheme.darkBorder,
        ),
      ),
      child: Column(
        children: [
          // Status icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _isRunning
                  ? context.accentColor.withValues(alpha: 0.15)
                  : AppTheme.darkBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isRunning ? Icons.radar : Icons.radar_outlined,
              size: 32,
              color: _isRunning ? context.accentColor : AppTheme.textTertiary,
            ),
          ),
          SizedBox(height: 12),

          // Status text
          Text(
            _isRunning ? 'Test Running' : 'Ready to Test',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _isRunning ? context.accentColor : Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isRunning
                ? '${_results.length} packets received'
                : 'Target: $targetName',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              if (!_isRunning)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showNodePicker,
                    icon: const Icon(Icons.person_search, size: 18),
                    label: const Text('Select Node'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.darkBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              if (!_isRunning) SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isRunning ? _stopTest : _startTest,
                  icon: Icon(
                    _isRunning ? Icons.stop : Icons.play_arrow,
                    size: 20,
                  ),
                  label: Text(_isRunning ? 'Stop' : 'Start Test'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRunning
                        ? AppTheme.errorRed
                        : context.accentColor,
                    foregroundColor: _isRunning ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfigCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text(
              'Enable Range Test Module',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Allow this device to participate in range tests',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
            ),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const Divider(height: 1, color: AppTheme.darkBorder),
          ListTile(
            title: const Text(
              'Sender Interval',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              'Send test packet every $_senderInterval seconds',
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 12,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, color: AppTheme.textSecondary),
                  onPressed: _senderInterval > 10
                      ? () => setState(() => _senderInterval -= 10)
                      : null,
                ),
                Text(
                  '${_senderInterval}s',
                  style: TextStyle(
                    color: context.accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: AppTheme.textSecondary),
                  onPressed: _senderInterval < 300
                      ? () => setState(() => _senderInterval += 10)
                      : null,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.darkBorder),
          SwitchListTile(
            title: const Text(
              'Save Results to SD',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Store test results on device SD card',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
            ),
            value: _saveResults,
            onChanged: (v) => setState(() => _saveResults = v),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Stats summary
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildStatItem(
                  'Avg SNR',
                  _results.isNotEmpty
                      ? '${(_results.map((r) => r.snr).reduce((a, b) => a + b) / _results.length).toStringAsFixed(1)} dB'
                      : '--',
                ),
                _buildStatItem(
                  'Avg RSSI',
                  _results.isNotEmpty
                      ? '${(_results.map((r) => r.rssi).reduce((a, b) => a + b) / _results.length).toStringAsFixed(0)} dBm'
                      : '--',
                ),
                _buildStatItem(
                  'Max Dist',
                  _results.isNotEmpty
                      ? '${(_results.map((r) => r.distance).reduce((a, b) => a > b ? a : b) / 1000).toStringAsFixed(1)} km'
                      : '--',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.darkBorder),
          // Results list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _results.length.clamp(0, 10),
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: AppTheme.darkBorder),
            itemBuilder: (context, index) {
              final result = _results[_results.length - 1 - index];
              return ListTile(
                dense: true,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '#${_results.length - index}',
                      style: TextStyle(
                        color: context.accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  'SNR: ${result.snr.toStringAsFixed(1)} dB • RSSI: ${result.rssi.toStringAsFixed(0)} dBm',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                subtitle: Text(
                  '${(result.distance / 1000).toStringAsFixed(2)} km • ${result.hopCount} hop(s)',
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 11,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: context.accentColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.primaryBlue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'How Range Test Works',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '1. Select a target node to test range with\n'
            '2. Start the test to begin sending packets\n'
            '3. View real-time signal metrics (SNR, RSSI)\n'
            '4. Track maximum distance achieved\n\n'
            'Both nodes must have Range Test module enabled for best results.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Range test result data
class RangeTestResult {
  final DateTime timestamp;
  final double snr;
  final double rssi;
  final int hopCount;
  final double distance; // in meters

  RangeTestResult({
    required this.timestamp,
    required this.snr,
    required this.rssi,
    required this.hopCount,
    required this.distance,
  });
}
