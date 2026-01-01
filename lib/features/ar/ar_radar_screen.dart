import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation, SystemChrome;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_bottom_sheet.dart';
import '../../models/mesh_models.dart';
import 'ar_models.dart';
import 'ar_overlay_painter.dart';
import 'ar_providers.dart';

/// Main AR Node Radar screen
class ARRadarScreen extends ConsumerStatefulWidget {
  const ARRadarScreen({super.key});

  @override
  ConsumerState<ARRadarScreen> createState() => _ARRadarScreenState();
}

class _ARRadarScreenState extends ConsumerState<ARRadarScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isInitializing = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initializeCamera();
    _startAR();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _cameraController?.dispose();
    ref.read(arViewProvider.notifier).stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No cameras available';
          _isInitializing = false;
        });
        return;
      }

      // Use back camera
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint('[AR] Camera initialization failed: $e');
      setState(() {
        _errorMessage = 'Camera error: $e';
        _isInitializing = false;
      });
    }
  }

  Future<void> _startAR() async {
    await ref.read(arViewProvider.notifier).start();
  }

  @override
  Widget build(BuildContext context) {
    final arState = ref.watch(arViewProvider);
    final stats = ref.watch(arStatsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'AR NODE RADAR',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              arState.config.showDistanceLabels
                  ? Icons.straighten
                  : Icons.straighten_outlined,
              color: arState.config.showDistanceLabels
                  ? Colors.cyan
                  : Colors.white54,
            ),
            tooltip: 'Toggle distance labels',
            onPressed: () {
              ref.read(arViewProvider.notifier).toggleDistanceLabels();
            },
          ),
          IconButton(
            icon: Icon(
              arState.config.showSignalStrength
                  ? Icons.signal_cellular_alt
                  : Icons.signal_cellular_alt_outlined,
              color: arState.config.showSignalStrength
                  ? Colors.cyan
                  : Colors.white54,
            ),
            tooltip: 'Toggle signal strength',
            onPressed: () {
              ref.read(arViewProvider.notifier).toggleSignalStrength();
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.white),
            tooltip: 'Settings',
            onPressed: () => _showSettingsSheet(arState),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_isCameraInitialized && _cameraController != null)
            CameraPreview(controller: _cameraController!)
          else if (_isInitializing)
            const Center(child: CircularProgressIndicator(color: Colors.cyan))
          else
            Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.camera_alt_outlined,
                      size: 64,
                      color: Colors.white24,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage ?? 'Camera unavailable',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),

          // AR Overlay
          if (arState.isActive)
            AROverlay(
              nodes: arState.arNodes,
              orientation: arState.orientation,
              config: arState.config,
              selectedNode: arState.selectedNode != null
                  ? arState.arNodes.cast<ARNode?>().firstWhere(
                      (n) => n?.node.nodeNum == arState.selectedNode!.nodeNum,
                      orElse: () => null,
                    )
                  : null,
              onNodeTap: (arNode) {
                ref.read(arViewProvider.notifier).selectNode(arNode.node);
              },
            ),

          // Error message
          if (arState.errorMessage != null)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  arState.errorMessage!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // Stats panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildStatsPanel(arState, stats),
          ),

          // Selected node detail
          if (arState.selectedNode != null)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: _buildSelectedNodeCard(arState),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsPanel(ARViewState arState, ARStats stats) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.9),
            Colors.black.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.radar,
            label: 'NODES',
            value: '${stats.totalNodes}',
          ),
          _buildStatItem(
            icon: Icons.near_me,
            label: 'NEAREST',
            value: stats.totalNodes > 0
                ? _formatDistance(stats.nearestDistance)
                : '--',
          ),
          _buildStatItem(
            icon: Icons.explore,
            label: 'HEADING',
            value: '${arState.orientation.heading.round()}°',
          ),
          _buildStatItem(
            icon: Icons.gps_fixed,
            label: 'GPS',
            value: arState.userPosition != null ? 'LOCK' : 'NO FIX',
            valueColor: arState.userPosition != null
                ? Colors.green
                : Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.cyan.withValues(alpha: 0.7), size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showSettingsSheet(ARViewState arState) {
    AppBottomSheet.show(
      context: context,
      child: _ARSettingsContent(
        arState: arState,
        onMaxDistanceChanged: (value) {
          ref.read(arViewProvider.notifier).setMaxDistance(value);
        },
        onToggleDistanceLabels: () {
          ref.read(arViewProvider.notifier).toggleDistanceLabels();
        },
        onToggleSignalStrength: () {
          ref.read(arViewProvider.notifier).toggleSignalStrength();
        },
      ),
    );
  }

  Widget _buildSelectedNodeCard(ARViewState arState) {
    final node = arState.selectedNode!;
    final arNode = arState.arNodes.firstWhere(
      (n) => n.node.nodeNum == node.nodeNum,
      orElse: () => ARNode(
        node: node,
        distance: 0,
        bearing: 0,
        elevation: 0,
        signalQuality: 0.5,
      ),
    );

    return GestureDetector(
      onTap: () {
        // Dismiss card on tap - could be extended to show full node details
        ref.read(arViewProvider.notifier).selectNode(null);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.cyan.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.cyan.withValues(alpha: 0.2),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            _buildNodeAvatar(node),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    node.longName ?? node.shortName ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.near_me,
                        size: 14,
                        color: Colors.cyan.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${arNode.formattedDistance} ${arNode.compassDirection}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.signal_cellular_alt,
                        size: 14,
                        color: Colors.cyan.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${(arNode.signalQuality * 100).round()}%',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54),
              onPressed: () {
                ref.read(arViewProvider.notifier).selectNode(null);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeAvatar(MeshNode node) {
    final text = node.shortName ?? node.nodeNum.toRadixString(16).toUpperCase();
    final color = Color(node.avatarColor ?? 0xFF00BCD4);

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text(
          text.length > 4 ? text.substring(0, 4) : text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: text.length > 2 ? 12 : 16,
          ),
        ),
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }
}

/// Camera preview widget
class CameraPreview extends StatelessWidget {
  final CameraController controller;

  const CameraPreview({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Container(color: Colors.black);
    }

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.previewSize?.height ?? 0,
            height: controller.value.previewSize?.width ?? 0,
            child: CameraPreview._raw(controller),
          ),
        ),
      ),
    );
  }

  // Inner raw preview
  static Widget _raw(CameraController controller) {
    return controller.buildPreview();
  }
}

/// Settings content widget for AppBottomSheet
class _ARSettingsContent extends StatefulWidget {
  final ARViewState arState;
  final ValueChanged<double> onMaxDistanceChanged;
  final VoidCallback onToggleDistanceLabels;
  final VoidCallback onToggleSignalStrength;

  const _ARSettingsContent({
    required this.arState,
    required this.onMaxDistanceChanged,
    required this.onToggleDistanceLabels,
    required this.onToggleSignalStrength,
  });

  @override
  State<_ARSettingsContent> createState() => _ARSettingsContentState();
}

class _ARSettingsContentState extends State<_ARSettingsContent> {
  late double _maxDistance;
  late bool _showDistanceLabels;
  late bool _showSignalStrength;

  @override
  void initState() {
    super.initState();
    _maxDistance = widget.arState.config.maxDisplayDistance;
    _showDistanceLabels = widget.arState.config.showDistanceLabels;
    _showSignalStrength = widget.arState.config.showSignalStrength;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BottomSheetHeader(icon: Icons.tune, title: 'AR Settings'),
        const SizedBox(height: 16),
        Text(
          'Max Distance: ${(_maxDistance / 1000).round()} km',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 8),
        Slider(
          value: _maxDistance,
          min: 1000,
          max: 100000,
          divisions: 99,
          activeColor: Colors.cyan,
          inactiveColor: Colors.white24,
          onChanged: (value) {
            setState(() => _maxDistance = value);
            widget.onMaxDistanceChanged(value);
          },
        ),
        const SizedBox(height: 16),
        _buildSwitch(
          'Distance Labels',
          'Show distance to each node',
          _showDistanceLabels,
          (value) {
            setState(() => _showDistanceLabels = value);
            widget.onToggleDistanceLabels();
          },
        ),
        const SizedBox(height: 8),
        _buildSwitch(
          'Signal Strength',
          'Show signal quality bars',
          _showSignalStrength,
          (value) {
            setState(() => _showSignalStrength = value);
            widget.onToggleSignalStrength();
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSwitch(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
      ),
      value: value,
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Colors.cyan : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.cyan.withValues(alpha: 0.5)
            : null,
      ),
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }
}
