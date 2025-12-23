import 'dart:math';

import 'package:flutter/material.dart';

/// Neural network activation visualization.
class NeuralPulseAnimation extends StatefulWidget {
  const NeuralPulseAnimation({super.key});

  @override
  State<NeuralPulseAnimation> createState() => _NeuralPulseAnimationState();
}

class _NeuralPulseAnimationState extends State<NeuralPulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _NeuralPulsePainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Neuron {
  _Neuron(this.x, this.y, this.layer);

  final double x, y;
  final int layer;
  double activation = 0;
  double targetActivation = 0;
}

class _NeuralPulsePainter extends CustomPainter {
  _NeuralPulsePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * 2 * pi;

    // Dark background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF08080c),
    );

    // Create neural network layout
    final layers = [5, 8, 10, 8, 5];
    final neurons = <_Neuron>[];
    final layerSpacing = size.width / (layers.length + 1);

    for (var l = 0; l < layers.length; l++) {
      final neuronCount = layers[l];
      final layerHeight = size.height * 0.7;
      final neuronSpacing = layerHeight / (neuronCount + 1);
      final startY = (size.height - layerHeight) / 2;

      for (var n = 0; n < neuronCount; n++) {
        neurons.add(
          _Neuron(layerSpacing * (l + 1), startY + neuronSpacing * (n + 1), l),
        );
      }
    }

    // Update activations with wave pattern
    for (final neuron in neurons) {
      final wavePhase = progress * 3 - neuron.layer * 0.2;
      final rowPhase = neuron.y / size.height;
      neuron.activation = (sin(wavePhase * 2 * pi + rowPhase * pi) + 1) / 2;
      neuron.activation *= (sin(time * 2 + neuron.x * 0.01) + 1) / 2;
    }

    // Draw connections
    for (var l = 0; l < layers.length - 1; l++) {
      final currentLayer = neurons.where((n) => n.layer == l).toList();
      final nextLayer = neurons.where((n) => n.layer == l + 1).toList();

      for (final from in currentLayer) {
        for (final to in nextLayer) {
          final signalStrength = from.activation * to.activation;

          if (signalStrength > 0.1) {
            // Signal traveling along connection
            final pulsePos = (progress * 4 + from.y * 0.001) % 1.0;
            final pulseX = from.x + (to.x - from.x) * pulsePos;
            final pulseY = from.y + (to.y - from.y) * pulsePos;

            // Connection line
            canvas.drawLine(
              Offset(from.x, from.y),
              Offset(to.x, to.y),
              Paint()
                ..color = const Color(
                  0xFF304060,
                ).withValues(alpha: 0.1 + signalStrength * 0.2)
                ..strokeWidth = 0.5,
            );

            // Traveling pulse
            if (signalStrength > 0.3) {
              canvas.drawCircle(
                Offset(pulseX, pulseY),
                2 + signalStrength * 2,
                Paint()
                  ..color = const Color(
                    0xFF60a0ff,
                  ).withValues(alpha: signalStrength * 0.6),
              );
            }
          }
        }
      }
    }

    // Draw neurons
    for (final neuron in neurons) {
      final baseColor = Color.lerp(
        const Color(0xFF203040),
        const Color(0xFF40c0ff),
        neuron.activation,
      )!;

      // Glow
      if (neuron.activation > 0.3) {
        canvas.drawCircle(
          Offset(neuron.x, neuron.y),
          15 + neuron.activation * 10,
          Paint()
            ..color = baseColor.withValues(alpha: neuron.activation * 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }

      // Core
      canvas.drawCircle(
        Offset(neuron.x, neuron.y),
        4 + neuron.activation * 4,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: neuron.activation * 0.8),
                  baseColor,
                  baseColor.withValues(alpha: 0.3),
                ],
              ).createShader(
                Rect.fromCircle(center: Offset(neuron.x, neuron.y), radius: 8),
              ),
      );

      // Dendrite spikes when active
      if (neuron.activation > 0.5) {
        for (var spike = 0; spike < 6; spike++) {
          final spikeAngle = spike * pi / 3 + time + neuron.y * 0.01;
          final spikeLen = 8 * neuron.activation;

          canvas.drawLine(
            Offset(neuron.x, neuron.y),
            Offset(
              neuron.x + cos(spikeAngle) * spikeLen,
              neuron.y + sin(spikeAngle) * spikeLen,
            ),
            Paint()
              ..color = baseColor.withValues(alpha: neuron.activation * 0.5)
              ..strokeWidth = 1,
          );
        }
      }
    }

    // Layer labels
    for (var l = 0; l < layers.length; l++) {
      final labels = ['INPUT', 'HIDDEN', 'HIDDEN', 'HIDDEN', 'OUTPUT'];
      final label = l < labels.length ? labels[l] : '';
      if (l == 0 || l == layers.length - 1) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.2),
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(
            layerSpacing * (l + 1) - textPainter.width / 2,
            size.height - 25,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NeuralPulsePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
