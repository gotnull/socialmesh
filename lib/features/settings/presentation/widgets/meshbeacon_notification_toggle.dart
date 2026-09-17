import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User preference for mesh beacon notifications.
///
/// Mesh beacon announcements are periodic and can become noisy once a user is
/// in or near a mesh. This setting gives users an in-app mute toggle without
/// disabling all app notifications.
class MeshBeaconNotificationSettings extends ChangeNotifier {
  static const String _key = 'meshbeacon_notifications_enabled';
  static final MeshBeaconNotificationSettings instance =
      MeshBeaconNotificationSettings._();

  MeshBeaconNotificationSettings._() {
    _load();
  }

  bool _enabled = true;

  bool get enabled => _enabled;

  bool get muted => !_enabled;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_key);
    if (value != null && value != _enabled) {
      _enabled = value;
      notifyListeners();
    }
  }

  Future<void> setEnabled(bool value) async {
    if (value == _enabled) {
      return;
    }

    _enabled = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

/// Reusable settings tile for silencing mesh beacon notifications.
class MeshBeaconNotificationToggle extends StatelessWidget {
  const MeshBeaconNotificationToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MeshBeaconNotificationSettings.instance,
      builder: (context, _) {
        final enabled = MeshBeaconNotificationSettings.instance.enabled;

        return SwitchListTile.adaptive(
          title: const Text('Mesh beacon notifications'),
          subtitle: const Text(
            'Silence periodic mesh beacon announcements while keeping other '
            'notifications enabled.',
          ),
          value: enabled,
          onChanged: (value) =>
              MeshBeaconNotificationSettings.instance.setEnabled(value),
        );
      },
    );
  }
}
