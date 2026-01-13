import 'dart:io';

import 'package:nothing_glyph_interface/nothing_glyph_interface.dart';

import '../core/logging.dart';
import 'glyph_matrix_service.dart';

/// Service for controlling Nothing Phone glyph interface
/// Provides visual feedback for mesh events, notifications, and system status
///
/// Supports two different SDKs:
/// - Glyph Interface SDK (Phone 1, 2, 2a, 2a Plus, 3a) - zone-based LED strips
/// - GlyphMatrix SDK (Phone 3) - 25x25 pixel LED matrix
class GlyphService {
  static final GlyphService _instance = GlyphService._internal();
  factory GlyphService() => _instance;
  GlyphService._internal();

  NothingGlyphInterface? _glyphInterface;
  final GlyphMatrixService _matrixService = GlyphMatrixService();
  bool _isSupported = false;
  bool _isInitialized = false;
  String _deviceModel = 'Unknown';
  bool _isPhone3 = false; // Phone 3 uses GlyphMatrix SDK, not Glyph Interface

  /// Check if device supports glyph interface
  bool get isSupported => _isSupported;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Get the detected device model
  String get deviceModel => _deviceModel;

  /// Check if this is Phone 3 (uses GlyphMatrix SDK)
  bool get isPhone3 => _isPhone3;

  /// Initialize the glyph service
  Future<void> init() async {
    if (_isInitialized) return;

    AppLogging.automations('GlyphService: Starting initialization...');

    // First, check if this is a Phone 3 (needs GlyphMatrix SDK)
    if (Platform.isAndroid) {
      _isPhone3 = await _matrixService.isPhone3();
      AppLogging.automations('GlyphService: Phone 3 check = $_isPhone3');

      if (_isPhone3) {
        // Phone 3 uses GlyphMatrix SDK
        final matrixInit = await _matrixService.init();
        if (matrixInit) {
          _deviceModel = 'Nothing Phone (3)';
          _isSupported = true;
          _isInitialized = true;
          AppLogging.automations(
            'GlyphService: Phone 3 initialized with GlyphMatrix SDK',
          );
          return;
        } else {
          AppLogging.automations(
            'GlyphService: Phone 3 GlyphMatrix init failed, falling back to Glyph Interface',
          );
        }
      }
    }

    // For other Nothing Phones, use Glyph Interface SDK
    try {
      _glyphInterface = NothingGlyphInterface();
      await _glyphInterface!.init();
      AppLogging.automations('GlyphService: NothingGlyphInterface initialized');

      // Check if it's a Nothing Phone
      final isPhone1 = await _glyphInterface!.is20111() ?? false;
      final isPhone2 = await _glyphInterface!.is22111() ?? false;
      final isPhone2a = await _glyphInterface!.is23111() ?? false;
      final isPhone2aPlus = await _glyphInterface!.is23113() ?? false;
      final isPhone3a = await _glyphInterface!.is24111() ?? false;

      AppLogging.automations(
        'GlyphService: Package detection - Phone1=$isPhone1, Phone2=$isPhone2, '
        'Phone2a=$isPhone2a, Phone2aPlus=$isPhone2aPlus, Phone3a=$isPhone3a',
      );

      // Determine device model (Phone 3 already handled above via GlyphMatrix)
      if (isPhone1) {
        _deviceModel = 'Nothing Phone (1)';
      } else if (isPhone2) {
        _deviceModel = 'Nothing Phone (2)';
      } else if (isPhone2a) {
        _deviceModel = 'Nothing Phone (2a)';
      } else if (isPhone2aPlus) {
        _deviceModel = 'Nothing Phone (2a Plus)';
      } else if (isPhone3a) {
        _deviceModel = 'Nothing Phone (3a)';
      } else {
        _deviceModel = 'Not a Nothing Phone';
      }

      _isSupported =
          isPhone1 || isPhone2 || isPhone2a || isPhone2aPlus || isPhone3a;
      _isInitialized = true;

      AppLogging.automations(
        'GlyphService: Initialized as $_deviceModel, supported: $_isSupported',
      );
    } catch (e, stack) {
      AppLogging.automations('GlyphService: Initialization failed: $e');
      AppLogging.automations('GlyphService: Stack trace: $stack');
      _isSupported = false;
      _isInitialized = false;
    }
  }

  /// Close and cleanup the glyph service
  Future<void> close() async {
    if (!_isInitialized) return;

    try {
      if (_isPhone3) {
        await _matrixService.turnOff();
      } else {
        await _glyphInterface?.turnOff();
      }
      _isInitialized = false;
      AppLogging.automations('GlyphService: Closed');
    } catch (e) {
      AppLogging.automations('GlyphService: Close failed: $e');
    }
  }

  /// Turn off all glyphs
  Future<void> turnOff() async {
    if (!_isSupported || !_isInitialized) return;

    try {
      if (_isPhone3) {
        await _matrixService.turnOff();
      } else {
        await _glyphInterface?.turnOff();
      }
    } catch (e) {
      AppLogging.automations('GlyphService: TurnOff failed: $e');
    }
  }

  // Preset patterns below using GlyphFrameBuilder API

  /// Show connection established pattern - quick double flash
  Future<void> showConnected() async {
    if (!_isSupported || !_isInitialized) return;

    try {
      if (_isPhone3) {
        await _matrixService.showConnected();
        return;
      }

      await _glyphInterface!.buildGlyphFrame(
        GlyphFrameBuilder()
            .buildChannelA()
            .buildPeriod(200)
            .buildCycles(2)
            .buildInterval(150)
            .build(),
      );
      await _glyphInterface!.animate();
    } catch (e) {
      AppLogging.automations('showConnected failed: $e');
    }
  }

  /// Show disconnection pattern - slow fade
  Future<void> showDisconnected() async {
    if (!_isSupported || !_isInitialized) return;

    try {
      if (_isPhone3) {
        await _matrixService.showDisconnected();
        return;
      }

      await _glyphInterface!.buildGlyphFrame(
        GlyphFrameBuilder()
            .buildChannelA()
            .buildPeriod(1000)
            .buildCycles(1)
            .build(),
      );
      await _glyphInterface!.animate();
    } catch (e) {
      AppLogging.automations('showDisconnected failed: $e');
    }
  }

  /// Show message received pattern with DM indicator
  Future<void> showMessageReceived({bool isDM = false}) async {
    if (!_isSupported || !_isInitialized) return;

    try {
      if (_isPhone3) {
        await _matrixService.showMessageReceived();
        return;
      }

      // DMs get 3 flashes, regular messages get 1 flash
      final cycles = isDM ? 3 : 1;
      await _glyphInterface!.buildGlyphFrame(
        GlyphFrameBuilder()
            .buildChannelA()
            .buildPeriod(300)
            .buildCycles(cycles)
            .buildInterval(200)
            .build(),
      );
      await _glyphInterface!.animate();
    } catch (e) {
      AppLogging.automations('showMessageReceived failed: $e');
    }
  }

  /// Show message sent confirmation - quick single flash
  Future<void> showMessageSent() async {
    if (!_isSupported || !_isInitialized) return;

    try {
      if (_isPhone3) {
        await _matrixService.showPattern('pulse');
        await Future.delayed(const Duration(milliseconds: 200));
        await _matrixService.turnOff();
        return;
      }

      await _glyphInterface!.buildGlyphFrame(
        GlyphFrameBuilder()
            .buildChannelA()
            .buildPeriod(150)
            .buildCycles(1)
            .build(),
      );
      await _glyphInterface!.animate();
    } catch (e) {
      AppLogging.automations('showMessageSent failed: $e');
    }
  }

  /// Show node online pattern - welcoming pulse
  Future<void> showNodeOnline() async {
    if (!_isSupported || !_isInitialized) return;

    try {
      if (_isPhone3) {
        await _matrixService.showNodeOnline();
        return;
      }

      await _glyphInterface!.buildGlyphFrame(
        GlyphFrameBuilder()
            .buildChannelA()
            .buildPeriod(500)
            .buildCycles(2)
            .buildInterval(300)
            .build(),
      );
      await _glyphInterface!.animate();
    } catch (e) {
      AppLogging.automations('showNodeOnline failed: $e');
    }
  }

  /// Show node offline pattern - single long fade
  Future<void> showNodeOffline() async {
    if (!_isSupported || !_isInitialized) return;

    try {
      if (_isPhone3) {
        await _matrixService.showPattern('border');
        await Future.delayed(const Duration(milliseconds: 800));
        await _matrixService.turnOff();
        return;
      }

      await _glyphInterface!.buildGlyphFrame(
        GlyphFrameBuilder()
            .buildChannelA()
            .buildPeriod(1200)
            .buildCycles(1)
            .build(),
      );
      await _glyphInterface!.animate();
    } catch (e) {
      AppLogging.automations('showNodeOffline failed: $e');
    }
  }

  /// Show signal nearby pattern - radar-like pulse
  Future<void> showSignalNearby() async {
    if (!_isSupported || !_isInitialized) return;

    try {
      if (_isPhone3) {
        await _matrixService.showPattern('pulse');
        await Future.delayed(const Duration(milliseconds: 600));
        await _matrixService.turnOff();
        return;
      }

      await _glyphInterface!.buildGlyphFrame(
        GlyphFrameBuilder()
            .buildChannelA()
            .buildPeriod(400)
            .buildCycles(3)
            .buildInterval(200)
            .build(),
      );
      await _glyphInterface!.animate();
    } catch (e) {
      AppLogging.automations('showSignalNearby failed: $e');
    }
  }

  /// Show low battery warning - urgent triple flash
  Future<void> showLowBattery() async {
    if (!_isSupported || !_isInitialized) return;

    try {
      if (_isPhone3) {
        await _matrixService.showPattern('cross');
        await Future.delayed(const Duration(milliseconds: 500));
        await _matrixService.turnOff();
        return;
      }

      await _glyphInterface!.buildGlyphFrame(
        GlyphFrameBuilder()
            .buildChannelA()
            .buildPeriod(200)
            .buildCycles(3)
            .buildInterval(150)
            .build(),
      );
      await _glyphInterface!.animate();
    } catch (e) {
      AppLogging.automations('showLowBattery failed: $e');
    }
  }

  /// Show automation triggered - confirmation flash
  Future<void> showAutomationTriggered() async {
    if (!_isSupported || !_isInitialized) return;

    try {
      if (_isPhone3) {
        await _matrixService.showPattern('dots');
        await Future.delayed(const Duration(milliseconds: 400));
        await _matrixService.turnOff();
        return;
      }

      await _glyphInterface!.buildGlyphFrame(
        GlyphFrameBuilder()
            .buildChannelA()
            .buildPeriod(250)
            .buildCycles(2)
            .buildInterval(200)
            .build(),
      );
      await _glyphInterface!.animate();
    } catch (e) {
      AppLogging.automations('showAutomationTriggered failed: $e');
    }
  }

  /// Show syncing pattern - breathing effect
  Future<void> showSyncing() async {
    if (!_isSupported || !_isInitialized) return;

    try {
      if (_isPhone3) {
        await _matrixService.showPattern('full');
        await Future.delayed(const Duration(milliseconds: 800));
        await _matrixService.turnOff();
        return;
      }

      await _glyphInterface!.buildGlyphFrame(
        GlyphFrameBuilder()
            .buildChannelA()
            .buildPeriod(800)
            .buildCycles(3)
            .buildInterval(400)
            .build(),
      );
      await _glyphInterface!.animate();
    } catch (e) {
      AppLogging.automations('showSyncing failed: $e');
    }
  }

  /// Show error pattern - urgent double flash
  Future<void> showError() async {
    if (!_isSupported || !_isInitialized) return;

    try {
      if (_isPhone3) {
        await _matrixService.showPattern('cross');
        await Future.delayed(const Duration(milliseconds: 300));
        await _matrixService.turnOff();
        await Future.delayed(const Duration(milliseconds: 100));
        await _matrixService.showPattern('cross');
        await Future.delayed(const Duration(milliseconds: 300));
        await _matrixService.turnOff();
        return;
      }

      await _glyphInterface!.buildGlyphFrame(
        GlyphFrameBuilder()
            .buildChannelA()
            .buildPeriod(300)
            .buildCycles(2)
            .buildInterval(100)
            .build(),
      );
      await _glyphInterface!.animate();
    } catch (e) {
      AppLogging.automations('showError failed: $e');
    }
  }

  /// Show success pattern - smooth single pulse
  Future<void> showSuccess() async {
    if (!_isSupported || !_isInitialized) return;

    try {
      if (_isPhone3) {
        await _matrixService.showPattern('full');
        await Future.delayed(const Duration(milliseconds: 600));
        await _matrixService.turnOff();
        return;
      }

      await _glyphInterface!.buildGlyphFrame(
        GlyphFrameBuilder()
            .buildChannelA()
            .buildPeriod(600)
            .buildCycles(1)
            .build(),
      );
      await _glyphInterface!.animate();
    } catch (e) {
      AppLogging.automations('showSuccess failed: $e');
    }
  }

  /// Show battery level progress (0-100)
  Future<void> showBatteryLevel(int percentage) async {
    if (!_isSupported || !_isInitialized) return;

    try {
      if (_isPhone3) {
        await _matrixService.showBatteryLevel(percentage);
        return;
      }

      await _glyphInterface!.displayProgress(percentage);
    } catch (e) {
      AppLogging.automations('showBatteryLevel failed: $e');
    }
  }

  /// Show signal strength based on RSSI
  Future<void> showSignalStrength(int rssi) async {
    if (!_isSupported || !_isInitialized) return;

    try {
      // Convert RSSI to percentage (typical range -100 to -40)
      final percentage = ((rssi + 100) / 60 * 100).clamp(0, 100).toInt();

      if (_isPhone3) {
        await _matrixService.showProgress(percentage);
        await Future.delayed(const Duration(seconds: 2));
        await _matrixService.turnOff();
        return;
      }

      await _glyphInterface!.displayProgress(percentage);
    } catch (e) {
      AppLogging.automations('showSignalStrength failed: $e');
    }
  }

  /// Custom pattern with full control (simplified single channel)
  /// Note: For Phone 3, this shows a generic pulse pattern since pixel matrix
  /// doesn't map to channel/period/cycles concept
  Future<void> customPattern({
    required int period,
    required int cycles,
    int? interval,
  }) async {
    if (!_isSupported || !_isInitialized) return;

    try {
      if (_isPhone3) {
        // Phone 3: approximate with timed pulses
        for (var i = 0; i < cycles; i++) {
          await _matrixService.showPattern('pulse');
          await Future.delayed(Duration(milliseconds: period));
          await _matrixService.turnOff();
          if (interval != null && i < cycles - 1) {
            await Future.delayed(Duration(milliseconds: interval));
          }
        }
        return;
      }

      final builder = GlyphFrameBuilder()
          .buildChannelA()
          .buildPeriod(period)
          .buildCycles(cycles);

      if (interval != null) {
        builder.buildInterval(interval);
      }

      await _glyphInterface!.buildGlyphFrame(builder.build());
      await _glyphInterface!.animate();
    } catch (e) {
      AppLogging.automations('customPattern failed: $e');
    }
  }

  /// Advanced multi-channel pattern with full zone control
  /// Allows individual control of all glyph zones (A, B, C, D, E)
  /// Note: Not supported on Phone 3 (uses pixel matrix instead of zones)
  Future<void> advancedPattern({required List<GlyphChannel> channels}) async {
    if (!_isSupported || !_isInitialized) return;

    try {
      if (_isPhone3) {
        // Phone 3 doesn't have zone-based LEDs, just show a generic pattern
        await _matrixService.showPattern('full');
        await Future.delayed(const Duration(milliseconds: 500));
        await _matrixService.turnOff();
        return;
      }

      var builder = GlyphFrameBuilder();

      // Build each channel sequentially
      for (final channel in channels) {
        switch (channel.zone) {
          case GlyphZone.a:
            builder = builder.buildChannelA();
          case GlyphZone.b:
            builder = builder.buildChannelB();
          case GlyphZone.c:
            builder = builder.buildChannelC();
          case GlyphZone.d:
            builder = builder.buildChannelD();
          case GlyphZone.e:
            builder = builder.buildChannelE();
        }

        builder = builder
            .buildPeriod(channel.period)
            .buildCycles(channel.cycles);

        if (channel.interval != null) {
          builder = builder.buildInterval(channel.interval!);
        }
      }

      await _glyphInterface!.buildGlyphFrame(builder.build());
      await _glyphInterface!.animate();
    } catch (e) {
      AppLogging.automations('advancedPattern failed: $e');
    }
  }
}

/// Enum for glyph zones on Nothing Phones
enum GlyphZone {
  a('Zone A', 'Camera'),
  b('Zone B', 'Diagonal Strip'),
  c('Zone C', 'USB-C Port'),
  d('Zone D', 'Lower Strip'),
  e('Zone E', 'Battery');

  const GlyphZone(this.displayName, this.description);
  final String displayName;
  final String description;
}

/// Configuration for a single glyph channel
class GlyphChannel {
  final GlyphZone zone;
  final int period; // Duration in milliseconds
  final int cycles; // Number of repetitions
  final int? interval; // Delay between cycles in milliseconds

  const GlyphChannel({
    required this.zone,
    required this.period,
    required this.cycles,
    this.interval,
  });

  GlyphChannel copyWith({
    GlyphZone? zone,
    int? period,
    int? cycles,
    int? interval,
  }) {
    return GlyphChannel(
      zone: zone ?? this.zone,
      period: period ?? this.period,
      cycles: cycles ?? this.cycles,
      interval: interval ?? this.interval,
    );
  }
}
