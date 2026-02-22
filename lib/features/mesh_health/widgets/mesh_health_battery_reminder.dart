// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../services/mesh_health/mesh_health_providers.dart';

/// Dismissible banner reminding users that Mesh Health monitoring
/// increases battery usage. Persists dismissal via SharedPreferences.
class MeshHealthBatteryReminder extends ConsumerStatefulWidget {
  const MeshHealthBatteryReminder({super.key});

  @override
  ConsumerState<MeshHealthBatteryReminder> createState() =>
      _MeshHealthBatteryReminderState();
}

class _MeshHealthBatteryReminderState
    extends ConsumerState<MeshHealthBatteryReminder>
    with SingleTickerProviderStateMixin, LifecycleSafeMixin {
  bool _isDismissed = false;
  bool _prefsLoaded = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  static const _dismissedKey = 'mesh_health_battery_reminder_dismissed';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      value: 1.0,
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _loadDismissedState();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadDismissedState() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_dismissedKey) ?? false;
    safeSetState(() {
      _isDismissed = dismissed;
      _prefsLoaded = true;
    });
  }

  Future<void> _dismiss() async {
    await _animController.reverse();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
    safeSetState(() => _isDismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    final healthState = ref.watch(meshHealthProvider);

    // Hide while prefs are loading, when dismissed, or when not monitoring
    if (!_prefsLoaded || _isDismissed || !healthState.isMonitoring) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: StatusBanner.warning(
          title: 'Battery usage',
          subtitle:
              'Mesh Health monitoring uses extra battery. '
              'Pause when not needed.',
          onDismiss: _dismiss,
        ),
      ),
    );
  }
}
