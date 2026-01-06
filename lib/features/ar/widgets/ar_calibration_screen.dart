import 'package:socialmesh/core/theme.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ar_calibration.dart';
import '../ar_state.dart';

/// Full-screen compass calibration widget with figure-8 animation guide
class ARCalibrationScreen extends ConsumerStatefulWidget {
  final VoidCallback? onComplete;
  final VoidCallback? onSkip;

  const ARCalibrationScreen({super.key, this.onComplete, this.onSkip});

  @override
  ConsumerState<ARCalibrationScreen> createState() =>
      _ARCalibrationScreenState();
}

class _ARCalibrationScreenState extends ConsumerState<ARCalibrationScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _figure8Controller;
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late AnimationController _successController;

  // State
  CalibrationPhase _phase = CalibrationPhase.idle;
  double _progress = 0;
  bool _isCalibrating = false;
  StreamSubscription<ARCalibrationState>? _calibrationSub;

  @override
  void initState() {
    super.initState();

    // Figure-8 path animation (3 second loop)
    _figure8Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Pulsing glow effect
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Progress arc animation
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Success checkmark animation
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Subscribe to calibration state
    _subscribeToCalibration();
  }

  void _subscribeToCalibration() {
    final arState = ref.read(arStateProvider);
    _updateFromState(arState.calibration);
  }

  void _updateFromState(ARCalibrationState state) {
    setState(() {
      _phase = state.phase;
      _progress = state.calibrationProgress;
    });

    // Animate progress
    _progressController.animateTo(_progress);

    // Success animation
    if (_phase == CalibrationPhase.complete) {
      _successController.forward().then((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          widget.onComplete?.call();
        });
      });
    }
  }

  Future<void> _startCalibration() async {
    HapticFeedback.mediumImpact();
    setState(() => _isCalibrating = true);

    // Trigger calibration through provider
    ref.read(arStateProvider.notifier).startCompassCalibration();
  }

  @override
  void dispose() {
    _calibrationSub?.cancel();
    _figure8Controller.dispose();
    _pulseController.dispose();
    _progressController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch calibration state
    final arState = ref.watch(arStateProvider);
    if (arState.calibration.phase != _phase ||
        arState.calibration.calibrationProgress != _progress) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateFromState(arState.calibration);
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Main content
            Expanded(child: Center(child: _buildMainContent())),

            // Bottom actions
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onSkip,
            icon: const Icon(Icons.close, color: Colors.white54),
          ),
          const Expanded(
            child: Text(
              'COMPASS CALIBRATION',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: AppTheme.fontFamily,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(width: 48), // Balance the close button
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_phase == CalibrationPhase.complete) {
      return _buildSuccessContent();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Figure-8 visualization
        SizedBox(
          width: 280,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background figure-8 path
              CustomPaint(
                size: const Size(280, 280),
                painter: _Figure8PathPainter(
                  progress: _progress,
                  pulseAnimation: _pulseController,
                ),
              ),

              // Animated guide dot
              if (_isCalibrating)
                AnimatedBuilder(
                  animation: _figure8Controller,
                  builder: (context, child) {
                    final pos = _getFigure8Position(_figure8Controller.value);
                    return Positioned(
                      left: 140 + pos.dx - 12,
                      top: 140 + pos.dy - 12,
                      child: _buildGuideDot(),
                    );
                  },
                ),

              // Progress ring
              SizedBox(
                width: 200,
                height: 200,
                child: AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _ProgressRingPainter(
                        progress: _progressController.value,
                        color: const Color(0xFF00E5FF),
                      ),
                    );
                  },
                ),
              ),

              // Phone icon in center
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + (_pulseController.value * 0.1);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 60,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.8),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF00E5FF,
                            ).withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.phone_android,
                        color: Color(0xFF00E5FF),
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Progress percentage
        Text(
          '${(_progress * 100).toInt()}%',
          style: const TextStyle(
            color: Color(0xFF00E5FF),
            fontSize: 48,
            fontWeight: FontWeight.bold,
            fontFamily: AppTheme.fontFamily,
          ),
        ),

        const SizedBox(height: 16),

        // Instructions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _getInstructions(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessContent() {
    return AnimatedBuilder(
      animation: _successController,
      builder: (context, child) {
        final scale = Curves.elasticOut.transform(_successController.value);
        return Transform.scale(
          scale: scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00E676).withValues(alpha: 0.2),
                  border: Border.all(color: const Color(0xFF00E676), width: 3),
                ),
                child: const Icon(
                  Icons.check,
                  color: Color(0xFF00E676),
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'CALIBRATION COMPLETE',
                style: TextStyle(
                  color: Color(0xFF00E676),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: AppTheme.fontFamily,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Compass accuracy improved',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuideDot() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final opacity = 0.5 + (_pulseController.value * 0.5);
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF00E5FF).withValues(alpha: opacity),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (!_isCalibrating && _phase != CalibrationPhase.complete)
            ElevatedButton(
              onPressed: _startCalibration,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'START CALIBRATION',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: AppTheme.fontFamily,
                  letterSpacing: 1,
                ),
              ),
            ),
          if (_isCalibrating && _phase != CalibrationPhase.complete)
            TextButton(
              onPressed: widget.onSkip,
              child: Text(
                'Skip for now',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
            ),
          if (_phase == CalibrationPhase.complete)
            ElevatedButton(
              onPressed: widget.onComplete,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'CONTINUE TO AR',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: AppTheme.fontFamily,
                  letterSpacing: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getInstructions() {
    if (!_isCalibrating) {
      return 'Move your device in a figure-8 pattern to calibrate the compass for accurate AR navigation.';
    }

    if (_progress < 0.3) {
      return 'Keep moving in a figure-8 pattern...\nFollow the glowing dot.';
    } else if (_progress < 0.7) {
      return 'Great progress!\nContinue the figure-8 motion.';
    } else {
      return 'Almost there!\nJust a bit more.';
    }
  }

  /// Calculate position on figure-8 path (lemniscate of Bernoulli)
  Offset _getFigure8Position(double t) {
    final angle = t * 2 * math.pi;
    final scale = 80.0;

    // Parametric equations for figure-8
    final x = scale * math.sin(angle);
    final y = scale * math.sin(angle) * math.cos(angle);

    return Offset(x, y);
  }
}

/// Paints the figure-8 background path
class _Figure8PathPainter extends CustomPainter {
  final double progress;
  final Animation<double> pulseAnimation;

  _Figure8PathPainter({required this.progress, required this.pulseAnimation})
    : super(repaint: pulseAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = 80.0;

    // Draw figure-8 path
    final path = Path();
    bool firstPoint = true;

    for (int i = 0; i <= 100; i++) {
      final t = i / 100.0;
      final angle = t * 2 * math.pi;

      final x = center.dx + scale * math.sin(angle);
      final y = center.dy + scale * math.sin(angle) * math.cos(angle);

      if (firstPoint) {
        path.moveTo(x, y);
        firstPoint = false;
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Background path
    final bgPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, bgPaint);

    // Progress path (filled portion)
    if (progress > 0) {
      final progressPath = Path();
      bool first = true;
      final progressSteps = (progress * 100).toInt();

      for (int i = 0; i <= progressSteps; i++) {
        final t = i / 100.0;
        final angle = t * 2 * math.pi;

        final x = center.dx + scale * math.sin(angle);
        final y = center.dy + scale * math.sin(angle) * math.cos(angle);

        if (first) {
          progressPath.moveTo(x, y);
          first = false;
        } else {
          progressPath.lineTo(x, y);
        }
      }

      final progressPaint = Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(progressPath, progressPaint);
    }
  }

  @override
  bool shouldRepaint(_Figure8PathPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Paints a circular progress ring
class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ProgressRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Background ring
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        progress * 2 * math.pi,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}

// ═══════════════════════════════════════════════════════════════════════════
// ACCURACY INDICATOR BADGES
// ═══════════════════════════════════════════════════════════════════════════

/// Small badge showing GPS accuracy status
class GPSAccuracyBadge extends StatelessWidget {
  final double? accuracy;
  final bool hasSignal;

  const GPSAccuracyBadge({super.key, this.accuracy, this.hasSignal = true});

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = _getStatus();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
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
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  (Color, String, IconData) _getStatus() {
    if (!hasSignal || accuracy == null) {
      return (Colors.red, 'NO GPS', Icons.gps_off);
    }

    if (accuracy! <= 5) {
      return (
        const Color(0xFF00E676),
        'GPS ±${accuracy!.toInt()}m',
        Icons.gps_fixed,
      );
    } else if (accuracy! <= 15) {
      return (
        const Color(0xFFFFEB3B),
        'GPS ±${accuracy!.toInt()}m',
        Icons.gps_fixed,
      );
    } else if (accuracy! <= 30) {
      return (
        const Color(0xFFFF9800),
        'GPS ±${accuracy!.toInt()}m',
        Icons.gps_not_fixed,
      );
    } else {
      return (Colors.red, 'GPS ±${accuracy!.toInt()}m', Icons.gps_not_fixed);
    }
  }
}

/// Small badge showing compass calibration status
class CompassAccuracyBadge extends StatelessWidget {
  final bool isCalibrated;
  final bool needsCalibration;
  final VoidCallback? onTap;

  const CompassAccuracyBadge({
    super.key,
    required this.isCalibrated,
    required this.needsCalibration,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = _getStatus();

    return GestureDetector(
      onTap: needsCalibration ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
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
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            if (needsCalibration) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.touch_app,
                color: color.withValues(alpha: 0.7),
                size: 12,
              ),
            ],
          ],
        ),
      ),
    );
  }

  (Color, String, IconData) _getStatus() {
    if (needsCalibration) {
      return (const Color(0xFFFF9800), 'CALIBRATE', Icons.explore_off);
    }

    if (isCalibrated) {
      return (const Color(0xFF00E676), 'COMPASS OK', Icons.explore);
    }

    return (const Color(0xFFFFEB3B), 'COMPASS', Icons.explore);
  }
}

/// Combined status bar showing both GPS and compass accuracy
class ARAccuracyStatusBar extends StatelessWidget {
  final double? gpsAccuracy;
  final bool hasGps;
  final bool compassCalibrated;
  final bool needsCompassCalibration;
  final VoidCallback? onCompassTap;

  const ARAccuracyStatusBar({
    super.key,
    this.gpsAccuracy,
    this.hasGps = true,
    this.compassCalibrated = true,
    this.needsCompassCalibration = false,
    this.onCompassTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GPSAccuracyBadge(accuracy: gpsAccuracy, hasSignal: hasGps),
        const SizedBox(width: 8),
        CompassAccuracyBadge(
          isCalibrated: compassCalibrated,
          needsCalibration: needsCompassCalibration,
          onTap: onCompassTap,
        ),
      ],
    );
  }
}
