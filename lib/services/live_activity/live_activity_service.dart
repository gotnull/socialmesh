import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:live_activities/live_activities.dart';
import 'package:live_activities/models/activity_update.dart';

/// Service for managing iOS Live Activities
/// Shows device connection status on Lock Screen and Dynamic Island
class LiveActivityService {
  static final LiveActivityService _instance = LiveActivityService._internal();
  factory LiveActivityService() => _instance;
  LiveActivityService._internal();

  final _liveActivitiesPlugin = LiveActivities();
  static const String _activityId = 'mesh_device_activity';
  String? _currentActivityId;
  StreamSubscription<ActivityUpdate>? _activityUpdateSubscription;
  bool _initialized = false;

  /// Whether Live Activities are supported on this device
  bool get isSupported => Platform.isIOS;

  /// Whether a Live Activity is currently running
  bool get isActive => _currentActivityId != null;

  /// Initialize the Live Activity service
  Future<void> initialize() async {
    if (!isSupported || _initialized) return;

    try {
      await _liveActivitiesPlugin.init(
        appGroupId: 'group.com.gotnull.socialmesh',
        urlScheme: 'socialmesh',
      );

      // Listen for activity updates
      _activityUpdateSubscription = _liveActivitiesPlugin.activityUpdateStream
          .listen(_onActivityUpdate);

      _initialized = true;
      debugPrint('📱 LiveActivityService initialized');
    } catch (e) {
      debugPrint('📱 Failed to initialize LiveActivityService: $e');
    }
  }

  /// Handle activity updates
  void _onActivityUpdate(ActivityUpdate update) {
    update.map(
      active: (active) {
        debugPrint('📱 Live Activity active: ${active.activityId}');
      },
      ended: (ended) {
        debugPrint('📱 Live Activity ended: ${ended.activityId}');
        if (ended.activityId == _currentActivityId) {
          _currentActivityId = null;
        }
      },
      stale: (stale) {
        debugPrint('📱 Live Activity stale: ${stale.activityId}');
      },
      unknown: (unknown) {
        debugPrint('📱 Live Activity unknown state: ${unknown.activityId}');
      },
    );
  }

  /// Start a mesh device Live Activity
  Future<bool> startMeshActivity({
    required String deviceName,
    required String shortName,
    required int nodeNum,
    int? batteryLevel,
    int? signalStrength,
    int? snr,
    int nodesOnline = 0,
    int totalNodes = 0,
    double? channelUtilization,
    double? airtime,
    int sentPackets = 0,
    int receivedPackets = 0,
    int badPackets = 0,
    int? uptimeSeconds,
    double? temperature,
  }) async {
    if (!isSupported) {
      debugPrint('📱 Live Activities not supported on this platform');
      return false;
    }

    if (!_initialized) {
      debugPrint('📱 Initializing LiveActivityService...');
      await initialize();
      debugPrint('📱 LiveActivityService initialized: $_initialized');
    }

    // Check if activities are enabled
    final enabled = await areActivitiesEnabled();
    debugPrint('📱 Live Activities enabled by user: $enabled');
    if (!enabled) {
      debugPrint('📱 Live Activities are disabled by user');
      return false;
    }

    // End any existing activity first
    if (_currentActivityId != null) {
      debugPrint('📱 Ending existing activity: $_currentActivityId');
      await endActivity();
    }

    try {
      final activityData = _buildActivityData(
        deviceName: deviceName,
        shortName: shortName,
        nodeNum: nodeNum,
        batteryLevel: batteryLevel,
        signalStrength: signalStrength,
        snr: snr,
        nodesOnline: nodesOnline,
        totalNodes: totalNodes,
        channelUtilization: channelUtilization,
        airtime: airtime,
        sentPackets: sentPackets,
        receivedPackets: receivedPackets,
        badPackets: badPackets,
        uptimeSeconds: uptimeSeconds,
        temperature: temperature,
      );

      debugPrint('📱 Creating Live Activity with data: $activityData');

      _currentActivityId = await _liveActivitiesPlugin.createActivity(
        _activityId,
        activityData,
        removeWhenAppIsKilled: false,
      );

      debugPrint('📱 createActivity returned: $_currentActivityId');

      if (_currentActivityId != null) {
        debugPrint('📱 ✅ Started Live Activity: $_currentActivityId');
        return true;
      } else {
        debugPrint(
          '📱 ❌ createActivity returned null - activity was not created',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('📱 ❌ Failed to start Live Activity: $e');
      debugPrint('📱 Stack trace: $stackTrace');
      // Common causes:
      // - ActivityInput error 0: App Group mismatch or provisioning issue
      // - No Dynamic Island on device (still works on Lock Screen)
      // - Widget extension not properly installed
      debugPrint(
        '📱 💡 Tip: Ensure App Group "group.com.gotnull.socialmesh" '
        'is configured in both main app and widget extension provisioning profiles',
      );
    }

    return false;
  }

  /// Update the current Live Activity with new data
  Future<bool> updateActivity({
    String? deviceName,
    String? shortName,
    int? nodeNum,
    int? batteryLevel,
    int? signalStrength,
    int? snr,
    int? nodesOnline,
    int? totalNodes,
    double? channelUtilization,
    double? airtime,
    int? sentPackets,
    int? receivedPackets,
    int? badPackets,
    int? uptimeSeconds,
    double? temperature,
    bool isConnected = true,
  }) async {
    if (!isSupported || _currentActivityId == null) {
      return false;
    }

    try {
      final activityData = <String, dynamic>{};

      if (deviceName != null) activityData['deviceName'] = deviceName;
      if (shortName != null) activityData['shortName'] = shortName;
      if (nodeNum != null) activityData['nodeNum'] = nodeNum;
      if (batteryLevel != null) activityData['batteryLevel'] = batteryLevel;
      if (signalStrength != null) {
        activityData['signalStrength'] = signalStrength;
      }
      if (snr != null) activityData['snr'] = snr;
      if (nodesOnline != null) activityData['nodesOnline'] = nodesOnline;
      if (totalNodes != null) activityData['totalNodes'] = totalNodes;
      if (channelUtilization != null) {
        activityData['channelUtilization'] = channelUtilization;
      }
      if (airtime != null) activityData['airtime'] = airtime;
      if (sentPackets != null) activityData['sentPackets'] = sentPackets;
      if (receivedPackets != null) {
        activityData['receivedPackets'] = receivedPackets;
      }
      if (badPackets != null) activityData['badPackets'] = badPackets;
      if (uptimeSeconds != null) activityData['uptimeSeconds'] = uptimeSeconds;
      if (temperature != null) activityData['temperature'] = temperature;
      activityData['isConnected'] = isConnected;

      // Update timestamp
      activityData['lastUpdated'] = DateTime.now().millisecondsSinceEpoch;

      await _liveActivitiesPlugin.updateActivity(
        _currentActivityId!,
        activityData,
      );

      debugPrint('📱 Updated Live Activity');
      return true;
    } catch (e) {
      debugPrint('📱 Failed to update Live Activity: $e');
    }

    return false;
  }

  /// End the current Live Activity
  Future<void> endActivity() async {
    if (!isSupported || _currentActivityId == null) return;

    try {
      await _liveActivitiesPlugin.endActivity(_currentActivityId!);
      debugPrint('📱 Ended Live Activity: $_currentActivityId');
      _currentActivityId = null;
    } catch (e) {
      debugPrint('📱 Failed to end Live Activity: $e');
    }
  }

  /// End all Live Activities
  Future<void> endAllActivities() async {
    if (!isSupported) return;

    try {
      await _liveActivitiesPlugin.endAllActivities();
      _currentActivityId = null;
      debugPrint('📱 Ended all Live Activities');
    } catch (e) {
      debugPrint('📱 Failed to end all Live Activities: $e');
    }
  }

  /// Check if Live Activities are enabled in settings
  Future<bool> areActivitiesEnabled() async {
    if (!isSupported) return false;

    try {
      return await _liveActivitiesPlugin.areActivitiesEnabled();
    } catch (e) {
      debugPrint('📱 Failed to check Live Activities status: $e');
      return false;
    }
  }

  /// Build activity data map
  /// Note: live_activities package stores these in UserDefaults with the activity ID prefix
  Map<String, dynamic> _buildActivityData({
    required String deviceName,
    required String shortName,
    required int nodeNum,
    int? batteryLevel,
    int? signalStrength,
    int? snr,
    int nodesOnline = 0,
    int totalNodes = 0,
    double? channelUtilization,
    double? airtime,
    int sentPackets = 0,
    int receivedPackets = 0,
    int badPackets = 0,
    int? uptimeSeconds,
    double? temperature,
  }) {
    // All values must be UserDefaults-compatible types
    return <String, dynamic>{
      'deviceName': deviceName,
      'shortName': shortName,
      'nodeNum': nodeNum,
      'batteryLevel': batteryLevel ?? 0,
      'signalStrength': signalStrength ?? -100,
      'snr': snr ?? 0,
      'nodesOnline': nodesOnline,
      'totalNodes': totalNodes,
      'channelUtilization': channelUtilization ?? 0.0,
      'airtime': airtime ?? 0.0,
      'sentPackets': sentPackets,
      'receivedPackets': receivedPackets,
      'badPackets': badPackets,
      'uptimeSeconds': uptimeSeconds ?? 0,
      'temperature': temperature ?? 0.0,
      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      'isConnected': true,
    };
  }

  /// Dispose resources
  void dispose() {
    _activityUpdateSubscription?.cancel();
    endActivity();
  }
}
