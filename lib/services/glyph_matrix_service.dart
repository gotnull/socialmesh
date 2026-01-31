// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/services.dart';

import '../core/logging.dart';

/// Service for controlling Nothing Phone 3 GlyphMatrix (25x25 LED pixel matrix)
/// Uses native Android GlyphMatrix SDK via method channel
///
/// Device: Nothing Phone (3) - DEVICE_23112
/// Matrix: 25x25 = 625 individually addressable LEDs
class GlyphMatrixService {
  static final GlyphMatrixService _instance = GlyphMatrixService._internal();
  factory GlyphMatrixService() => _instance;
  GlyphMatrixService._internal();

  static const _channel = MethodChannel('glyph_matrix');
  static const int matrixSize = 25;
  static const int totalPixels = matrixSize * matrixSize; // 625

  bool _isInitialized = false;
  bool _isConnected = false;
  bool? _isPhone3Cache;

  /// Check if initialized
  bool get isInitialized => _isInitialized;

  /// Check if connected to GlyphMatrix service
  bool get isConnected => _isConnected;

  /// Check if this is a Nothing Phone 3
  Future<bool> isPhone3() async {
    if (_isPhone3Cache != null) return _isPhone3Cache!;

    try {
      final result = await _channel.invokeMethod<bool>('isPhone3');
      _isPhone3Cache = result ?? false;
      AppLogging.automations(
        'GlyphMatrixService: isPhone3 check = $_isPhone3Cache',
      );
      return _isPhone3Cache!;
    } catch (e) {
      AppLogging.automations('GlyphMatrixService: isPhone3 check failed: $e');
      return false;
    }
  }

  /// Initialize the GlyphMatrix service
  Future<bool> init() async {
    if (_isInitialized) return true;

    try {
      // Set up method call handler for service callbacks
      _channel.setMethodCallHandler(_handleMethodCall);

      final result = await _channel.invokeMethod<bool>('init');
      _isInitialized = result ?? false;
      AppLogging.automations(
        'GlyphMatrixService: init result = $_isInitialized',
      );
      return _isInitialized;
    } catch (e) {
      AppLogging.automations('GlyphMatrixService: init failed: $e');
      return false;
    }
  }

  /// Handle method calls from native side
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onServiceConnected':
        _isConnected = true;
        AppLogging.automations('GlyphMatrixService: Service connected');
        break;
      case 'onServiceDisconnected':
        _isConnected = false;
        AppLogging.automations('GlyphMatrixService: Service disconnected');
        break;
    }
  }

  /// Turn off all LEDs
  Future<void> turnOff() async {
    try {
      await _channel.invokeMethod('turnOff');
    } catch (e) {
      AppLogging.automations('GlyphMatrixService: turnOff failed: $e');
    }
  }

  /// Set a single pixel
  /// [x] and [y] are 0-24, [brightness] is 0-255
  Future<void> setPixel(int x, int y, {int brightness = 255}) async {
    if (!_isConnected) return;

    try {
      await _channel.invokeMethod('setPixel', {
        'x': x.clamp(0, matrixSize - 1),
        'y': y.clamp(0, matrixSize - 1),
        'brightness': brightness.clamp(0, 255),
      });
    } catch (e) {
      AppLogging.automations('GlyphMatrixService: setPixel failed: $e');
    }
  }

  /// Set the entire matrix from a list of 625 brightness values (0-255)
  /// Pixels are in row-major order: [row0col0, row0col1, ..., row24col24]
  Future<void> setMatrix(List<int> pixels) async {
    if (!_isConnected) return;
    if (pixels.length != totalPixels) {
      AppLogging.automations(
        'GlyphMatrixService: Invalid pixel count ${pixels.length}, expected $totalPixels',
      );
      return;
    }

    try {
      await _channel.invokeMethod('setMatrix', {'pixels': pixels});
    } catch (e) {
      AppLogging.automations('GlyphMatrixService: setMatrix failed: $e');
    }
  }

  /// Show a predefined pattern
  /// Patterns: 'pulse', 'border', 'cross', 'dots', 'full'
  Future<void> showPattern(String pattern) async {
    if (!_isConnected) return;

    try {
      await _channel.invokeMethod('showPattern', {'pattern': pattern});
    } catch (e) {
      AppLogging.automations('GlyphMatrixService: showPattern failed: $e');
    }
  }

  /// Show text on the matrix (single character works best)
  Future<void> showText(String text, {int brightness = 255}) async {
    if (!_isConnected) return;

    try {
      await _channel.invokeMethod('showText', {
        'text': text,
        'brightness': brightness.clamp(0, 255),
      });
    } catch (e) {
      AppLogging.automations('GlyphMatrixService: showText failed: $e');
    }
  }

  /// Show progress (0-100) as a bar filling from bottom
  Future<void> showProgress(int progress, {int brightness = 255}) async {
    if (!_isConnected) return;

    try {
      await _channel.invokeMethod('showProgress', {
        'progress': progress.clamp(0, 100),
        'brightness': brightness.clamp(0, 255),
      });
    } catch (e) {
      AppLogging.automations('GlyphMatrixService: showProgress failed: $e');
    }
  }

  // ============== Convenience methods for mesh events ==============

  /// Quick flash pattern for connection established
  Future<void> showConnected() async {
    await showPattern('pulse');
    await Future.delayed(const Duration(milliseconds: 500));
    await turnOff();
  }

  /// Border flash for disconnection
  Future<void> showDisconnected() async {
    await showPattern('border');
    await Future.delayed(const Duration(milliseconds: 300));
    await turnOff();
  }

  /// Cross pattern for message received
  Future<void> showMessageReceived() async {
    await showPattern('cross');
    await Future.delayed(const Duration(milliseconds: 400));
    await turnOff();
  }

  /// Show battery level as progress bar
  Future<void> showBatteryLevel(int percent) async {
    await showProgress(percent);
    await Future.delayed(const Duration(seconds: 2));
    await turnOff();
  }

  /// Dots pattern for node online
  Future<void> showNodeOnline() async {
    await showPattern('dots');
    await Future.delayed(const Duration(milliseconds: 500));
    await turnOff();
  }
}
