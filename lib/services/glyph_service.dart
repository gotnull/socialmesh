import 'package:nothing_glyph_interface/nothing_glyph_interface.dart';

import '../core/logging.dart';

/// Service for controlling Nothing Phone glyph interface
/// Provides visual feedback for mesh events, notifications, and system status
class GlyphService {
  static final GlyphService _instance = GlyphService._internal();
  factory GlyphService() => _instance;
  GlyphService._internal();

  NothingGlyphInterface? _glyphInterface;
  bool _isSupported = false;
  bool _isInitialized = false;

  /// Check if device supports glyph interface
  bool get isSupported => _isSupported;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the glyph service
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _glyphInterface = NothingGlyphInterface();
      await _glyphInterface!.init();

      // Check if it's a Nothing Phone
      final isPhone1 = await _glyphInterface!.is20111() ?? false;
      final isPhone2 = await _glyphInterface!.is22111() ?? false;
      final isPhone2a = await _glyphInterface!.is23111() ?? false;
      final isPhone2aPlus = await _glyphInterface!.is23113() ?? false;
      final isPhone3a = await _glyphInterface!.is24111() ?? false;

      _isSupported =
          isPhone1 || isPhone2 || isPhone2a || isPhone2aPlus || isPhone3a;
      _isInitialized = true;
      AppLogging.automations(
        'GlyphService: Initialized, supported: $_isSupported',
      );
    } catch (e) {
      AppLogging.automations('GlyphService: Initialization failed: $e');
      _isSupported = false;
      _isInitialized = false;
    }
  }

  /// Close and cleanup the glyph service
  Future<void> close() async {
    if (!_isInitialized) return;

    try {
      await _glyphInterface?.turnOff();
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
      await _glyphInterface?.turnOff();
    } catch (e) {
      AppLogging.automations('GlyphService: TurnOff failed: $e');
    }
  }

  // Preset patterns below using GlyphFrameBuilder API

  /// Show connection established pattern - quick double flash
  Future<void> showConnected() async {
    if (!_isSupported || !_isInitialized) return;

    try {
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
      await _glyphInterface!.displayProgress(percentage);
    } catch (e) {
      AppLogging.automations('showSignalStrength failed: $e');
    }
  }

  /// Custom pattern with full control
  Future<void> customPattern({
    required int period,
    required int cycles,
    int? interval,
  }) async {
    if (!_isSupported || !_isInitialized) return;

    try {
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
}
