// SPDX-License-Identifier: GPL-3.0-or-later
import '../../core/logging.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../providers/app_providers.dart';
import '../../models/mesh_models.dart';
import '../../models/presence_confidence.dart';
import '../../utils/presence_utils.dart';
import '../../providers/presence_providers.dart';
import '../../core/widgets/loading_indicator.dart';

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
  bool _isLoading = true;

  // Test results
  final List<RangeTestResult> _results = [];
  int? _selectedTargetNode;

  // Stream subscription for incoming range test messages
  StreamSubscription<MeshNode>? _nodeSubscription;
  Timer? _sendTimer;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _nodeSubscription?.cancel();
    _sendTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentConfig() async {
    final protocol = ref.read(protocolServiceProvider);

    // Only request from device if connected
    if (!protocol.isConnected) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final config = await protocol.getRangeTestModuleConfig();
    if (config != null && mounted) {
      setState(() {
        _enabled = config.enabled;
        _senderInterval = config.sender > 0 ? config.sender : 60;
        _saveResults = config.save;
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
      await protocol.setRangeTestConfig(
        enabled: _enabled,
        sender: _senderInterval,
        save: _saveResults,
      );

      if (mounted) {
        showSuccessSnackBar(context, 'Range test configuration saved');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to save config: $e');
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

    // Listen for node updates (which include RSSI/SNR from range test responses)
    _startRangeTestListener();

    // Start sending range test packets at configured interval
    _startSendingPackets();
  }

  void _stopTest() {
    _nodeSubscription?.cancel();
    _nodeSubscription = null;
    _sendTimer?.cancel();
    _sendTimer = null;
    setState(() => _isRunning = false);
  }

  void _startRangeTestListener() {
    final protocol = ref.read(protocolServiceProvider);

    // Listen for node updates from the target node
    _nodeSubscription = protocol.nodeStream.listen((node) {
      if (!_isRunning || _selectedTargetNode == null) return;

      // Check if this update is from our target node
      if (node.nodeNum == _selectedTargetNode) {
        // Extract signal metrics from the node update
        final snr = node.snr?.toDouble() ?? -10.0;
        final rssi = node.rssi?.toDouble() ?? -100.0;

        // Calculate distance if we have position data
        double? distance;
        final nodes = ref.read(nodesProvider);
        final myNodeNum = ref.read(myNodeNumProvider);
        final myNode = myNodeNum != null ? nodes[myNodeNum] : null;

        if (myNode?.latitude != null &&
            myNode?.longitude != null &&
            node.latitude != null &&
            node.longitude != null) {
          distance = _calculateDistance(
            myNode!.latitude!,
            myNode.longitude!,
            node.latitude!,
            node.longitude!,
          );
        }

        if (mounted) {
          setState(() {
            _results.add(
              RangeTestResult(
                timestamp: DateTime.now(),
                snr: snr,
                rssi: rssi,
                hopCount: 0, // Hop count not available in node data
                distance: distance ?? 0,
              ),
            );
          });
        }
      }
    });
  }

  void _startSendingPackets() {
    // Send initial packet immediately
    _sendRangeTestPacket();

    // Then send at configured interval
    _sendTimer = Timer.periodic(
      Duration(seconds: _senderInterval),
      (_) => _sendRangeTestPacket(),
    );
  }

  Future<void> _sendRangeTestPacket() async {
    if (!_isRunning || _selectedTargetNode == null) return;

    try {
      final protocol = ref.read(protocolServiceProvider);
      // Send a range test message to the target node
      await protocol.sendMessage(
        text: 'RT ${DateTime.now().millisecondsSinceEpoch}',
        to: _selectedTargetNode!,
      );
    } catch (e) {
      AppLogging.settings('Error sending range test packet: $e');
    }
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Haversine formula for distance calculation
    const double earthRadius = 6371000; // meters
    final dLat = (lat2 - lat1) * (math.pi / 180);
    final dLon = (lon2 - lon1) * (math.pi / 180);
    final a =
        (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        math.cos(lat1 * (math.pi / 180)) *
            math.cos(lat2 * (math.pi / 180)) *
            (math.sin(dLon / 2) * math.sin(dLon / 2));
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  void _showNodePicker() {
    final nodes = ref.read(nodesProvider);
    final myNodeNum = ref.read(myNodeNumProvider);
    final presenceMap = ref.read(presenceMapProvider);

    final otherNodes =
        nodes.values.where((n) => n.nodeNum != myNodeNum).toList()
          ..sort((a, b) {
            final aActive = presenceConfidenceFor(presenceMap, a).isActive;
            final bActive = presenceConfidenceFor(presenceMap, b).isActive;
            if (aActive != bActive) return aActive ? -1 : 1;
            final aName = a.longName ?? a.shortName ?? '';
            final bName = b.longName ?? b.shortName ?? '';
            return aName.compareTo(bName);
          });

    if (otherNodes.isEmpty) {
      showInfoSnackBar(context, 'No other nodes available');
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
                Text(
                  'Select Target Node',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: context.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.border),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: otherNodes.length,
              itemBuilder: (context, index) {
                final node = otherNodes[index];
                final presence = presenceConfidenceFor(presenceMap, node);
                final displayName =
                    node.longName ??
                    node.shortName ??
                    '!${node.nodeNum.toRadixString(16)}';

                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: presence.isActive
                          ? context.accentColor.withValues(alpha: 0.15)
                          : context.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        node.shortName?.substring(0, 1).toUpperCase() ?? '?',
                        style: TextStyle(
                          color: presence.isActive
                              ? context.accentColor
                              : context.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    displayName,
                    style: TextStyle(color: context.textPrimary),
                  ),
                  subtitle: Text(
                    presenceStatusText(
                      presence,
                      lastHeardAgeFor(presenceMap, node),
                    ),
                    style: TextStyle(
                      color: presence.isActive
                          ? context.accentColor
                          : context.textTertiary,
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

    return GlassScaffold(
      title: 'Range Test',
      actions: [
        if (!_isRunning)
          TextButton(
            onPressed: _isSaving ? null : _saveConfig,
            child: _isSaving
                ? LoadingIndicator(size: 20)
                : Text('Save', style: TextStyle(color: context.accentColor)),
          ),
      ],
      slivers: [
        if (_isLoading)
          const SliverFillRemaining(child: ScreenLoadingIndicator())
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
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

  Widget _buildStatusCard(String targetName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isRunning
              ? context.accentColor.withValues(alpha: 0.3)
              : context.border,
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
                  : context.background,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isRunning ? Icons.radar : Icons.radar_outlined,
              size: 32,
              color: _isRunning ? context.accentColor : context.textTertiary,
            ),
          ),
          SizedBox(height: 12),

          // Status text
          Text(
            _isRunning ? 'Test Running' : 'Ready to Test',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _isRunning ? context.accentColor : context.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            _isRunning
                ? '${_results.length} packets received'
                : 'Target: $targetName',
            style: TextStyle(fontSize: 13, color: context.textSecondary),
          ),

          SizedBox(height: 16),

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
                      foregroundColor: context.textSecondary,
                      side: BorderSide(color: context.border),
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
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Enable Range Test Module',
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              'Allow this device to participate in range tests',
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
              'Sender Interval',
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              'Send test packet every $_senderInterval seconds',
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.remove, color: context.textSecondary),
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
                  icon: Icon(Icons.add, color: context.textSecondary),
                  onPressed: _senderInterval < 300
                      ? () => setState(() => _senderInterval += 10)
                      : null,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.border),
          ListTile(
            title: Text(
              'Save Results to SD',
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              'Store test results on device SD card',
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
            trailing: ThemedSwitch(
              value: _saveResults,
              onChanged: (v) => setState(() => _saveResults = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsCard() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
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
          Divider(height: 1, color: context.border),
          // Results list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _results.length.clamp(0, 10),
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: context.border),
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
                  style: TextStyle(color: context.textPrimary, fontSize: 13),
                ),
                subtitle: Text(
                  '${(result.distance / 1000).toStringAsFixed(2)} km • ${result.hopCount} hop(s)',
                  style: TextStyle(color: context.textTertiary, fontSize: 11),
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
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: context.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.primaryBlue, size: 20),
              SizedBox(width: 8),
              Text(
                'How Range Test Works',
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '1. Select a target node to test range with\n'
            '2. Start the test to begin sending packets\n'
            '3. View real-time signal metrics (SNR, RSSI)\n'
            '4. Track maximum distance achieved\n\n'
            'Both nodes must have Range Test module enabled for best results.',
            style: TextStyle(
              color: context.textSecondary,
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
