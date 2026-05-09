// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../../core/logging.dart';
import '../../core/l10n/l10n_extension.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../generated/meshtastic/admin.pbenum.dart' as admin_pbenum;
import '../../generated/meshtastic/module_config.pb.dart' as module_pb;
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../providers/app_providers.dart';
import '../../providers/countdown_providers.dart';
import '../../services/protocol/admin_target.dart';
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

class _RangeTestScreenState extends ConsumerState<RangeTestScreen>
    with LifecycleSafeMixin {
  void _dismissKeyboard() {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
  }

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
  StreamSubscription<module_pb.ModuleConfig_RangeTestConfig>?
  _configSubscription;
  Timer? _sendTimer;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _configSubscription?.cancel();
    _nodeSubscription?.cancel();
    _sendTimer?.cancel();
    super.dispose();
  }

  void _applyConfig(module_pb.ModuleConfig_RangeTestConfig config) {
    safeSetState(() {
      _enabled = config.enabled;
      _senderInterval = config.sender > 0 ? config.sender : 60;
      _saveResults = config.save;
      _isLoading = false;
    });
  }

  Future<void> _loadCurrentConfig() async {
    try {
      final protocol = ref.read(protocolServiceProvider);
      final target = AdminTarget.fromNullable(
        ref.read(remoteAdminTargetProvider),
      );

      // Apply cached config immediately if available (local only)
      if (target.isLocal) {
        final cached = protocol.currentRangeTestConfig;
        if (cached != null) {
          _applyConfig(cached);
        }
      }

      // Only request from device if connected
      if (protocol.isConnected) {
        // Listen for config response
        _configSubscription = protocol.rangeTestConfigStream.listen((config) {
          if (mounted) _applyConfig(config);
        });

        // Request fresh config from device
        await protocol.getModuleConfig(
          admin_pbenum.AdminMessage_ModuleConfigType.RANGETEST_CONFIG,
          target: target,
        );
      }
    } finally {
      safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    safeSetState(() => _isSaving = true);

    try {
      final protocol = ref.read(protocolServiceProvider);
      final target = AdminTarget.fromNullable(
        ref.read(remoteAdminTargetProvider),
      );
      await protocol.setRangeTestConfig(
        enabled: _enabled,
        sender: _senderInterval,
        save: _saveResults,
        target: target,
      );

      if (mounted) {
        showSuccessSnackBar(context, context.l10n.rangeTestSaveSuccess);
        if (target.isLocal) {
          ref
              .read(countdownProvider.notifier)
              .startDeviceRebootCountdown(reason: 'range test config saved');
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, context.l10n.rangeTestSaveFailed('$e'));
      }
    } finally {
      safeSetState(() => _isSaving = false);
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
    final nodesMap = ref.read(nodesProvider);
    final myNum = ref.read(myNodeNumProvider);

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
        final nodes = nodesMap;
        final myNodeNum = myNum;
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
          safeSetState(() {
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
      final protocol = ref.read(
        protocolServiceProvider,
      ); // captured before await
      // Send a range test message to the target node
      await protocol.sendMessage(
        text:
            'RT ${DateTime.now().millisecondsSinceEpoch}', // lint-allow: hardcoded-string
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
      showInfoSnackBar(context, context.l10n.rangeTestNoNodes);
      return;
    }

    AppBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return _NodePickerContent(
            otherNodes: otherNodes,
            presenceMap: presenceMap,
            selectedTargetNode: _selectedTargetNode,
            onNodeSelected: (nodeNum) {
              setState(() => _selectedTargetNode = nodeNum);
              Navigator.pop(context);
            },
          );
        },
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
            : context.l10n.rangeTestSelectTarget);

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: GlassScaffold(
        title: context.l10n.rangeTestTitle,
        actions: [
          if (!_isRunning)
            TextButton(
              onPressed: _isSaving ? null : _saveConfig,
              child: _isSaving
                  ? LoadingIndicator(size: 20)
                  : Text(
                      context.l10n.rangeTestSave,
                      style: TextStyle(color: context.accentColor),
                    ),
            ),
        ],
        slivers: [
          if (_isLoading)
            const SliverFillRemaining(child: ScreenLoadingIndicator())
          else
            SliverPadding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Test Status Card
                  _buildStatusCard(targetName),

                  const SizedBox(height: AppTheme.spacing16),

                  // Configuration Section
                  if (!_isRunning) ...[
                    _buildSectionTitle(context.l10n.rangeTestConfiguration),
                    _buildConfigCard(),
                    const SizedBox(height: AppTheme.spacing16),
                  ],

                  // Results Section
                  if (_results.isNotEmpty) ...[
                    _buildSectionTitle(
                      context.l10n.rangeTestResultsCount(_results.length),
                    ),
                    _buildResultsCard(),
                  ],

                  // Info Section
                  if (!_isRunning && _results.isEmpty) ...[
                    _buildSectionTitle(context.l10n.rangeTestAbout),
                    _buildInfoCard(),
                  ],
                ]),
              ),
            ),
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

  Widget _buildStatusCard(String targetName) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
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
          SizedBox(height: AppTheme.spacing12),

          // Status text
          Text(
            _isRunning
                ? context.l10n.rangeTestRunning
                : context.l10n.rangeTestReady,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _isRunning ? context.accentColor : context.textPrimary,
            ),
          ),
          SizedBox(height: AppTheme.spacing4),
          Text(
            _isRunning
                ? context.l10n.rangeTestPacketsReceived(_results.length)
                : 'Target: $targetName',
            style: context.bodySmallStyle?.copyWith(
              color: context.textSecondary,
            ),
          ),

          SizedBox(height: AppTheme.spacing16),

          // Action buttons
          Row(
            children: [
              if (!_isRunning)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showNodePicker,
                    icon: const Icon(Icons.person_search, size: 18),
                    label: Text(context.l10n.rangeTestSelectNode),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.textSecondary,
                      side: BorderSide(color: context.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius10),
                      ),
                    ),
                  ),
                ),
              if (!_isRunning) SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isRunning ? _stopTest : _startTest,
                  icon: Icon(
                    _isRunning ? Icons.stop : Icons.play_arrow,
                    size: 20,
                  ),
                  label: Text(
                    _isRunning
                        ? context.l10n.rangeTestStop
                        : context.l10n.rangeTestStartTest,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRunning
                        ? AppTheme.errorRed
                        : context.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius10),
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
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              context.l10n.rangeTestEnableModule,
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              context.l10n.rangeTestEnableModuleSubtitle,
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
              context.l10n.rangeTestSenderInterval,
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              context.l10n.rangeTestSenderIntervalSubtitle(_senderInterval),
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
              context.l10n.rangeTestSaveResultsToSd,
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              context.l10n.rangeTestSaveResultsToSdSubtitle,
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
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        children: [
          // Stats summary
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Row(
              children: [
                _buildStatItem(
                  context.l10n.rangeTestAvgSnr,
                  _results.isNotEmpty
                      ? '${(_results.map((r) => r.snr).reduce((a, b) => a + b) / _results.length).toStringAsFixed(1)} dB'
                      : '--',
                ),
                _buildStatItem(
                  context.l10n.rangeTestAvgRssi,
                  _results.isNotEmpty
                      ? '${(_results.map((r) => r.rssi).reduce((a, b) => a + b) / _results.length).toStringAsFixed(0)} dBm'
                      : '--',
                ),
                _buildStatItem(
                  context.l10n.rangeTestMaxDist,
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
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
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
                  'SNR: ${result.snr.toStringAsFixed(1)} dB • RSSI: ${result.rssi.toStringAsFixed(0)} dBm', // lint-allow: hardcoded-string
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
          SizedBox(height: AppTheme.spacing4),
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
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.primaryBlue, size: 20),
              SizedBox(width: AppTheme.spacing8),
              Text(
                context.l10n.rangeTestHowItWorks,
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            context.l10n.rangeTestHowItWorksDescription,
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

/// Node picker content with search for the range test bottom sheet.
class _NodePickerContent extends StatefulWidget {
  final List<MeshNode> otherNodes;
  final Map<int, NodePresence> presenceMap;
  final int? selectedTargetNode;
  final ValueChanged<int> onNodeSelected;

  const _NodePickerContent({
    required this.otherNodes,
    required this.presenceMap,
    required this.selectedTargetNode,
    required this.onNodeSelected,
  });

  @override
  State<_NodePickerContent> createState() => _NodePickerContentState();
}

class _NodePickerContentState extends State<_NodePickerContent> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MeshNode> get _filteredNodes {
    if (_searchQuery.isEmpty) return widget.otherNodes;
    final query = _searchQuery.toLowerCase();
    return widget.otherNodes.where((node) {
      final longName = node.longName?.toLowerCase() ?? '';
      final shortName = node.shortName?.toLowerCase() ?? '';
      final hexId = '!${node.nodeNum.toRadixString(16)}';
      return longName.contains(query) ||
          shortName.contains(query) ||
          hexId.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNodes;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.spacing24, 16, 16, 0),
          child: Row(
            children: [
              Text(
                context.l10n.rangeTestSelectTargetNode,
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
                  context.l10n.commonCancel,
                  style: TextStyle(color: context.textSecondary),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing12,
            AppTheme.spacing16,
            AppTheme.spacing8,
          ),
          child: TextField(
            controller: _searchController,
            maxLength: 40,
            style: TextStyle(color: context.textPrimary, fontSize: 14),
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            decoration: InputDecoration(
              hintText: context.l10n.rangeTestSearchNodes,
              hintStyle: TextStyle(color: context.textTertiary),
              prefixIcon: Icon(
                Icons.search,
                color: context.textTertiary,
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: context.textTertiary,
                        size: 18,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              counterText: '',
              filled: true,
              fillColor: context.background.withValues(alpha: 0.6),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing12,
                vertical: AppTheme.spacing10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                borderSide: BorderSide(
                  color: context.accentColor.withValues(alpha: 0.5),
                ),
              ),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        Divider(height: 1, color: context.border),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing50),
            child: Column(
              children: [
                Icon(Icons.search_off, color: context.textTertiary, size: 32),
                const SizedBox(height: AppTheme.spacing8),
                Text(
                  context.l10n.rangeTestNoNodesMatch(_searchQuery),
                  style: TextStyle(color: context.textTertiary, fontSize: 13),
                ),
              ],
            ),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.35,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final node = filtered[index];
                final presence = presenceConfidenceFor(
                  widget.presenceMap,
                  node,
                );
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
                      borderRadius: BorderRadius.circular(AppTheme.radius10),
                    ),
                    child: Center(
                      child: Text(
                        (node.shortName?.isNotEmpty == true)
                            ? node.shortName!.characters.first.toUpperCase()
                            : '?',
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
                      lastHeardAgeFor(widget.presenceMap, node),
                    ),
                    style: TextStyle(
                      color: presence.isActive
                          ? context.accentColor
                          : context.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: widget.selectedTargetNode == node.nodeNum
                      ? Icon(Icons.check_circle, color: context.accentColor)
                      : null,
                  onTap: () => widget.onNodeSelected(node.nodeNum),
                );
              },
            ),
          ),
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ],
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
