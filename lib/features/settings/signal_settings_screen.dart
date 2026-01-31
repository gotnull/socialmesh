import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../providers/social_providers.dart';
import '../../core/widgets/animations.dart';
import '../../providers/app_providers.dart';
import '../../services/notifications/push_notification_service.dart';
import '../../utils/location_privacy.dart';
import '../../utils/snackbar.dart';

/// Screen for configuring signal privacy settings.
class SignalSettingsScreen extends ConsumerStatefulWidget {
  const SignalSettingsScreen({super.key});

  @override
  ConsumerState<SignalSettingsScreen> createState() =>
      _SignalSettingsScreenState();
}

class _SignalSettingsScreenState extends ConsumerState<SignalSettingsScreen> {
  bool _isLoading = false;
  bool _notificationsLoading = true;
  int _signalLocationRadiusMeters = kDefaultSignalLocationRadiusMeters;
  int _maxSignalImages = 4;
  bool _signalsEnabled = true;
  bool _votesEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await ref.read(settingsServiceProvider.future);
      if (!mounted) return;
      setState(() {
        _signalLocationRadiusMeters = settings.signalLocationRadiusMeters;
        _maxSignalImages = settings.maxSignalImages;
      });
    } catch (_) {
      // Ignore errors - defaults already set
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    await _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final settings = await PushNotificationService()
          .getNotificationSettings();
      if (mounted) {
        setState(() {
          _signalsEnabled = settings['signals'] ?? true;
          _votesEnabled = settings['votes'] ?? true;
          _notificationsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _notificationsLoading = false);
      }
    }
  }

  Future<void> _updateNotificationSetting(String type, bool value) async {
    HapticFeedback.selectionClick();

    setState(() {
      switch (type) {
        case 'signals':
          _signalsEnabled = value;
          break;
        case 'votes':
          _votesEnabled = value;
          break;
      }
    });

    await PushNotificationService().updateNotificationSettings(
      signalNotifications: type == 'signals' ? value : null,
      voteNotifications: type == 'votes' ? value : null,
    );
  }

  Future<void> _updateSignalLocationRadius(int meters) async {
    setState(() => _signalLocationRadiusMeters = meters);
    try {
      final settings = await ref.read(settingsServiceProvider.future);
      await settings.setSignalLocationRadiusMeters(meters);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          'Failed to update signal location radius: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdminAsync = ref.watch(isAdminProvider);
    final isAdmin = isAdminAsync.value ?? false;

    return GlassScaffold(
      title: 'Signals',
      slivers: [
        if (_isLoading)
          const SliverFillRemaining(child: ScreenLoadingIndicator())
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _SectionHeader(title: 'SIGNAL PRIVACY'),
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Signal location radius',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.accentColor.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${_signalLocationRadiusMeters}m',
                              style: TextStyle(
                                color: context.accentColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Signals are rounded to this radius, not an exact address',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 8),
                      SliderTheme(
                        data: SliderThemeData(
                          inactiveTrackColor: context.border,
                          thumbColor: context.accentColor,
                          overlayColor: context.accentColor.withValues(
                            alpha: 0.2,
                          ),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: _signalLocationRadiusMeters.toDouble(),
                          min: 100,
                          max: 500,
                          divisions: 8,
                          onChanged: (value) {
                            _updateSignalLocationRadius(value.toInt());
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Admin-only section
                if (isAdmin) ...[
                  const _SectionHeader(title: 'SIGNAL CONTENT'),
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.photo_library_outlined,
                                color: context.textSecondary,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Max Images per Signal',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: context.textPrimary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: context.accentColor.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$_maxSignalImages',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: context.accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Limit: 1-4 images',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.textTertiary,
                            ),
                          ),
                          SizedBox(height: 8),
                          SliderTheme(
                            data: SliderThemeData(
                              inactiveTrackColor: context.border,
                              thumbColor: context.accentColor,
                              overlayColor: context.accentColor.withValues(
                                alpha: 0.2,
                              ),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: _maxSignalImages.toDouble(),
                              min: 1,
                              max: 4,
                              divisions: 3,
                              onChanged: (value) async {
                                final newValue = value.toInt();
                                setState(() => _maxSignalImages = newValue);
                                HapticFeedback.selectionClick();
                                try {
                                  final settings = await ref.read(
                                    settingsServiceProvider.future,
                                  );
                                  await settings.setMaxSignalImages(newValue);
                                } catch (e) {
                                  // Error updating setting - ignore silently since UI already updated
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const _SectionHeader(title: 'SIGNAL NOTIFICATIONS'),
                if (!_notificationsLoading) ...[
                  _SettingsTile(
                    icon: Icons.wifi_tethering_outlined,
                    title: 'Signals',
                    subtitle: 'Notify when someone posts a signal',
                    trailing: ThemedSwitch(
                      value: _signalsEnabled,
                      onChanged: (value) =>
                          _updateNotificationSetting('signals', value),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.arrow_upward,
                    title: 'Votes',
                    subtitle: 'When someone upvotes your signal comments',
                    trailing: ThemedSwitch(
                      value: _votesEnabled,
                      onChanged: (value) =>
                          _updateNotificationSetting('votes', value),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ]),
            ),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: context.textTertiary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: context.textSecondary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: context.textTertiary),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              Align(alignment: Alignment.topCenter, child: trailing!),
          ],
        ),
      ),
    );
  }
}
