import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/app_bottom_sheet.dart';
import '../../utils/share_utils.dart';
import '../../utils/snackbar.dart';
import 'ar_calibration.dart';
import 'ar_engine.dart';
import 'ar_hud_painter.dart';
import 'ar_state.dart';
import 'widgets/ar_calibration_screen.dart';
import 'widgets/ar_node_detail_card.dart';
import 'widgets/ar_settings_panel.dart';
import 'widgets/ar_view_mode_selector.dart';

/// Production-grade AR Node Radar screen with advanced HUD overlay
class ARRadarScreen extends ConsumerStatefulWidget {
  const ARRadarScreen({super.key});

  @override
  ConsumerState<ARRadarScreen> createState() => _ARRadarScreenState();
}

class _ARRadarScreenState extends ConsumerState<ARRadarScreen>
    with TickerProviderStateMixin {
  // Camera
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  String? _cameraError;

  // Animation
  late AnimationController _pulseController;
  late AnimationController _scanController;

  // UI state
  bool _isLocked = false;
  bool _showDebug = false;

  @override
  void initState() {
    super.initState();

    // Lock to portrait for consistent experience
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // Hide status bar for immersion
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Animation controllers
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Initialize
    _initializeCamera();
    _startAR();
  }

  @override
  void dispose() {
    // Capture refs before dispose
    final arNotifier = ref.read(arStateProvider.notifier);

    // Stop AR first
    try {
      arNotifier.stop();
    } catch (_) {}

    // Clean up animations
    _pulseController.dispose();
    _scanController.dispose();

    // Clean up camera
    _cameraController?.dispose();

    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);

    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraError = 'No cameras available');
        return;
      }

      // Use back camera
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      // Lock exposure and focus for stability
      if (_cameraController!.value.isInitialized) {
        try {
          await _cameraController!.setExposureMode(ExposureMode.auto);
          await _cameraController!.setFocusMode(FocusMode.auto);
        } catch (_) {}
      }

      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cameraError = 'Camera error: $e');
      }
    }
  }

  Future<void> _startAR() async {
    await ref.read(arStateProvider.notifier).start();
  }

  void _onTap(TapDownDetails details, Size size) {
    if (_isLocked) return;

    ref
        .read(arStateProvider.notifier)
        .selectNodeAt(
          details.localPosition.dx,
          details.localPosition.dy,
          size.width,
          size.height,
        );
  }

  void _showSettings() {
    AppBottomSheet.show(
      context: context,
      child: ARSettingsPanel(
        state: ref.read(arStateProvider),
        onViewModeChanged: (mode) {
          ref.read(arStateProvider.notifier).setViewMode(mode);
        },
        onMaxDistanceChanged: (dist) {
          ref.read(arStateProvider.notifier).setMaxDistance(dist);
        },
        onToggleElement: (element) {
          ref.read(arStateProvider.notifier).toggleHudElement(element);
        },
        onToggleOfflineNodes: () {
          ref.read(arStateProvider.notifier).toggleOfflineNodes();
        },
        onToggleFavoritesOnly: () {
          ref.read(arStateProvider.notifier).toggleFavoritesOnly();
        },
      ),
    );
  }

  void _showCalibrationScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ARCalibrationScreen(
          onComplete: () => Navigator.of(context).pop(),
          onSkip: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final arState = ref.watch(arStateProvider);
    final stats = ref.watch(arStatsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          _buildCameraPreview(),

          // AR HUD overlay
          if (arState.isRunning)
            GestureDetector(
              onTapDown: (details) =>
                  _onTap(details, MediaQuery.of(context).size),
              child: AnimatedBuilder(
                animation: _scanController,
                builder: (context, _) {
                  final padding = MediaQuery.of(context).padding;
                  return CustomPaint(
                    painter: ARHudPainter(
                      orientation: arState.orientation,
                      position: arState.position,
                      nodes: arState.nodes,
                      clusters: arState.clusters,
                      alerts: arState.alerts,
                      selectedNode: arState.selectedNode,
                      config: arState.hudConfig.copyWith(
                        safeAreaTop: padding.top,
                        safeAreaBottom: padding.bottom,
                      ),
                      animationValue: _scanController.value,
                    ),
                    size: MediaQuery.of(context).size,
                  );
                },
              ),
            ),

          // Top controls
          _buildTopControls(arState, stats),

          // Selected node detail card
          if (arState.selectedNode != null)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 16,
              right: 16,
              child: ARNodeDetailCard(
                node: arState.selectedNode!,
                onClose: () =>
                    ref.read(arStateProvider.notifier).selectNode(null),
                onNavigate: () => _navigateToNode(arState.selectedNode!),
                onFavorite: () {
                  final nodeNum = arState.selectedNode!.node.nodeNum;
                  if (arState.favoriteNodeNums.contains(nodeNum)) {
                    ref.read(arStateProvider.notifier).removeFavorite(nodeNum);
                  } else {
                    ref.read(arStateProvider.notifier).addFavorite(nodeNum);
                  }
                },
                onShare: () => _shareNode(arState.selectedNode!),
                isFavorite: arState.favoriteNodeNums.contains(
                  arState.selectedNode!.node.nodeNum,
                ),
              ),
            ),

          // View mode selector (bottom left)
          Positioned(
            bottom: arState.selectedNode != null ? 180 : 100,
            left: 16,
            child: ARViewModeSelector(
              currentMode: arState.viewMode,
              onModeChanged: (mode) {
                ref.read(arStateProvider.notifier).setViewMode(mode);
                HapticFeedback.selectionClick();
              },
            ),
          ),

          // Loading overlay
          if (arState.isInitializing) _buildLoadingOverlay(),

          // Error overlay
          if (arState.error != null) _buildErrorOverlay(arState.error!),

          // Debug info
          if (_showDebug) _buildDebugInfo(arState, stats),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraError != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                color: Colors.white24,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                _cameraError!,
                style: const TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (!_isCameraInitialized || _cameraController == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
        ),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cameraController!.value.previewSize?.height ?? 0,
          height: _cameraController!.value.previewSize?.width ?? 0,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  Widget _buildTopControls(ARState arState, ARStats stats) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Back button
                _buildControlButton(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.of(context).pop(),
                ),

                const Spacer(),

                // Status indicators
                _buildStatusChip(
                  icon: Icons.blur_on,
                  label: '${stats.totalNodes}',
                  color: const Color(0xFF00E5FF),
                ),
                const SizedBox(width: 8),
                _buildStatusChip(
                  icon: Icons.visibility,
                  label: '${stats.visibleNodes}',
                  color: const Color(0xFF00FF88),
                ),
                if (stats.warningNodes > 0) ...[
                  const SizedBox(width: 8),
                  _buildStatusChip(
                    icon: Icons.warning_amber,
                    label: '${stats.warningNodes}',
                    color: const Color(0xFFFFAB00),
                  ),
                ],

                const Spacer(),

                // Lock button
                _buildControlButton(
                  icon: _isLocked ? Icons.lock : Icons.lock_open,
                  isActive: _isLocked,
                  onTap: () {
                    setState(() => _isLocked = !_isLocked);
                    HapticFeedback.mediumImpact();
                    showInfoSnackBar(
                      context,
                      _isLocked ? 'Touch locked' : 'Touch unlocked',
                    );
                  },
                ),
                const SizedBox(width: 8),
                // Debug button
                _buildControlButton(
                  icon: Icons.bug_report,
                  isActive: _showDebug,
                  onTap: () => setState(() => _showDebug = !_showDebug),
                ),
                const SizedBox(width: 8),
                // Settings button
                _buildControlButton(icon: Icons.tune, onTap: _showSettings),
              ],
            ),
          ),

          // GPS/Compass accuracy status bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ARAccuracyStatusBar(
              gpsAccuracy: arState.position?.accuracy,
              hasGps: arState.position != null,
              compassCalibrated:
                  arState.calibration.compassStatus == CalibrationStatus.good ||
                  arState.calibration.compassStatus ==
                      CalibrationStatus.excellent,
              needsCompassCalibration: arState.needsCalibration,
              onCompassTap: _showCalibrationScreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF00E5FF).withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? const Color(0xFF00E5FF)
                : Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? const Color(0xFF00E5FF) : Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _LoadingPainter(progress: _pulseController.value),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'INITIALIZING AR ENGINE',
              style: TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Calibrating sensors...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorOverlay(String error) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Color(0xFFFF1744),
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'AR ENGINE ERROR',
                style: TextStyle(
                  color: Color(0xFFFF1744),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _startAR,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                ),
                child: const Text('RETRY'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDebugInfo(ARState arState, ARStats stats) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _debugRow(
              'HDG',
              '${arState.orientation.heading.toStringAsFixed(1)}°',
            ),
            _debugRow(
              'PIT',
              '${arState.orientation.pitch.toStringAsFixed(1)}°',
            ),
            _debugRow('ROL', '${arState.orientation.roll.toStringAsFixed(1)}°'),
            _debugRow(
              'ACC',
              '${(arState.orientation.accuracy * 100).toStringAsFixed(0)}%',
            ),
            const Divider(color: Color(0xFF00E5FF), height: 8),
            if (arState.position != null) ...[
              _debugRow('LAT', arState.position!.latitude.toStringAsFixed(6)),
              _debugRow('LON', arState.position!.longitude.toStringAsFixed(6)),
              _debugRow(
                'ALT',
                '${arState.position!.altitude.toStringAsFixed(1)}m',
              ),
              _debugRow(
                'GPS',
                '±${arState.position!.accuracy.toStringAsFixed(0)}m',
              ),
            ],
            const Divider(color: Color(0xFF00E5FF), height: 8),
            _debugRow('NOD', '${stats.totalNodes}'),
            _debugRow('VIS', '${stats.visibleNodes}'),
            _debugRow('CLU', '${stats.clusters}'),
            _debugRow('MOV', '${stats.movingNodes}'),
          ],
        ),
      ),
    );
  }

  Widget _debugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF00E5FF),
              fontSize: 10,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToNode(ARWorldNode node) async {
    final meshNode = node.node;
    if (meshNode.latitude == null || meshNode.longitude == null) {
      showInfoSnackBar(context, 'Node has no GPS position');
      return;
    }

    final lat = meshNode.latitude!;
    final lon = meshNode.longitude!;
    final name = meshNode.displayName;

    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lon',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        showInfoSnackBar(context, 'Could not open maps for $name');
      }
    }
  }

  void _shareNode(ARWorldNode arNode) {
    final meshNode = arNode.node;
    final name = meshNode.displayName;
    final nodeId = '!${meshNode.nodeNum.toRadixString(16)}';

    final buffer = StringBuffer();
    buffer.writeln('📡 $name');
    buffer.writeln('Node ID: $nodeId');

    if (meshNode.hasPosition) {
      buffer.writeln(
        'Position: ${meshNode.latitude!.toStringAsFixed(6)}, '
        '${meshNode.longitude!.toStringAsFixed(6)}',
      );
      buffer.writeln(
        'Distance: ${arNode.worldPosition.distance.toStringAsFixed(0)}m',
      );
      buffer.writeln(
        'Bearing: ${arNode.worldPosition.bearing.toStringAsFixed(0)}°',
      );
    }

    if (meshNode.altitude != null) {
      buffer.writeln('Altitude: ${meshNode.altitude!.toStringAsFixed(0)}m');
    }

    if (meshNode.batteryLevel != null && meshNode.batteryLevel! > 0) {
      buffer.writeln('Battery: ${meshNode.batteryLevel}%');
    }

    if (meshNode.snr != null) {
      buffer.writeln('SNR: ${meshNode.snr!.toStringAsFixed(1)} dB');
    }

    buffer.writeln();
    buffer.writeln('Shared via Socialmesh AR');

    shareText(buffer.toString(), subject: 'Mesh Node: $name', context: context);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LOADING PAINTER
// ═══════════════════════════════════════════════════════════════════════════

class _LoadingPainter extends CustomPainter {
  final double progress;

  _LoadingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Background circle
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Animated arc
    final sweepAngle = math.pi * 1.5;
    final startAngle = progress * math.pi * 2 - math.pi / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Inner hexagon
    final hexRadius = radius * 0.5;
    final hexPath = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (i * 60 - 30 + progress * 360) * math.pi / 180;
      final x = center.dx + hexRadius * math.cos(angle);
      final y = center.dy + hexRadius * math.sin(angle);
      if (i == 0) {
        hexPath.moveTo(x, y);
      } else {
        hexPath.lineTo(x, y);
      }
    }
    hexPath.close();

    canvas.drawPath(
      hexPath,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_LoadingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
