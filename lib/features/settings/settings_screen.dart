// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: scaffold — InAppWebView browser, glass blur would obscure web content
import '../feedback/bug_report_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../config/revenuecat_config.dart';
import '../../core/transport.dart' show DeviceConnectionState;
import '../../models/user_profile.dart';
import '../../providers/app_providers.dart';
import '../../providers/age_eligibility_provider.dart';
import '../../core/legal/age_group.dart';
import '../../providers/auth_providers.dart';
import '../../providers/profile_providers.dart';
// import '../../providers/social_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../providers/subscription_providers.dart';
import '../../providers/signal_bookmark_provider.dart';
import '../../providers/signal_providers.dart';
import '../../providers/glyph_provider.dart';
import '../../models/subscription_models.dart';
import '../../services/storage/storage_service.dart';
import '../../services/notifications/push_notification_service.dart';
import '../../services/haptic_service.dart';
import 'background_connection_screen.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/info_table.dart';
import '../../core/widgets/search_filter_header.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../core/widgets/legal_document_sheet.dart';
import '../../core/widgets/remote_admin_selector_sheet.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/verified_badge.dart';
import '../../providers/help_providers.dart';
import '../../utils/snackbar.dart';
import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;
import '../device/region_selection_screen.dart';
import 'device_management_screen.dart';
import '../device/device_config_screen.dart';
import 'radio_config_screen.dart';
import 'position_config_screen.dart';
import 'display_config_screen.dart';
import 'mqtt_config_screen.dart';
import 'bluetooth_config_screen.dart';
import 'network_config_screen.dart';
import 'power_config_screen.dart';
import 'security_config_screen.dart';
import 'ringtone_screen.dart';
import 'subscription_screen.dart';
import 'ifttt_config_screen.dart';
import 'theme_settings_screen.dart';
import 'appearance_accessibility_screen.dart';
import 'privacy_settings_screen.dart';
import '../automations/automations_screen.dart';
import '../automations/automation_providers.dart';
import 'canned_responses_screen.dart';
import 'canned_message_module_config_screen.dart';
import 'range_test_screen.dart';
import 'glyph_test_screen.dart';
import 'store_forward_config_screen.dart';
import 'detection_sensor_config_screen.dart';
import 'external_notification_config_screen.dart';
import 'account_subscriptions_screen.dart';
import 'linked_devices_screen.dart';
import 'data_export_screen.dart';
import '../device/serial_config_screen.dart';
import 'traffic_management_config_screen.dart';
import '../device/gps_status_screen.dart';
import '../device/firmware_update_screen.dart';
import '../device/ambient_lighting_config_screen.dart';
import '../device/pax_counter_config_screen.dart';
import '../device/telemetry_config_screen.dart';
import '../debug/app_log_screen.dart';
import '../telemetry/device_metrics_log_screen.dart';
import '../telemetry/environment_metrics_log_screen.dart';
import '../telemetry/position_log_screen.dart';
import '../telemetry/traceroute_log_screen.dart';
import '../telemetry/air_quality_log_screen.dart';
import '../telemetry/pax_counter_log_screen.dart';
import '../telemetry/detection_sensor_log_screen.dart';
import '../routes/routes_screen.dart';
import '../widget_builder/widget_builder_screen.dart';
import 'screens/help_center_screen.dart';
import '../../core/whats_new/whats_new_sheet.dart';
// import '../social/screens/follow_requests_screen.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/constants.dart';
import '../../providers/reticulum_providers.dart';
import '../tak/screens/tak_settings_screen.dart';
import 'network_endpoints_screen.dart';
import 'reticulum_bridge_screen.dart';
import 'reticulum_diagnostics_screen.dart';
import 'translation_settings_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  /// Optional search query to pre-fill on open, allowing callers to
  /// deep-link directly to a specific setting (e.g. "phone location").
  final String? initialSearchQuery;

  const SettingsScreen({super.key, this.initialSearchQuery});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with LifecycleSafeMixin<SettingsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSearchQuery;
    if (initial != null && initial.isNotEmpty) {
      _searchQuery = initial;
      _searchController.text = initial;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Get all searchable settings items
  List<_SearchableSettingItem> _getSearchableSettings(
    BuildContext context,
    WidgetRef ref,
  ) {
    final settingsServiceAsync = ref.read(settingsServiceProvider);
    final purchaseState = ref.watch(purchaseStateProvider);
    final storeProductsAsync = ref.watch(storeProductsProvider);
    final storeProducts = storeProductsAsync.when(
      data: (data) => data,
      loading: () => <String, StoreProductInfo>{},
      error: (e, s) => <String, StoreProductInfo>{},
    );

    return settingsServiceAsync.maybeWhen(
      data: (settingsService) => [
        // Premium
        _SearchableSettingItem(
          icon: Icons.rocket_launch_rounded,
          title: context.l10n.settingsPremiumUnlockFeaturesTitle,
          subtitle: context.l10n.settingsSearchPremiumSubtitle,
          keywords: ['premium', 'upgrade', 'purchase', 'buy', 'subscription'],
          section: context.l10n.settingsSectionPremium,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.music_note,
          title:
              storeProducts[RevenueCatConfig.ringtonePackProductId]?.title ??
              context.l10n.settingsSearchRingtonePackTitle,
          subtitle: context.l10n.settingsSearchRingtonePackSubtitle,
          keywords: ['sound', 'audio', 'tone', 'music', 'alert'],
          section: context.l10n.settingsSectionPremium,
          onTap: () {
            if (purchaseState.hasFeature(PremiumFeature.customRingtones)) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RingtoneScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            }
          },
        ),
        _SearchableSettingItem(
          icon: Icons.bug_report_outlined,
          title: context.l10n.settingsTileShakeToReportTitle,
          subtitle: context.l10n.settingsTileShakeToReportSubtitle,
          keywords: ['bug', 'report', 'shake', 'feedback', 'support'],
          section: context.l10n.settingsSectionFeedback,
          hasSwitch: true,
          switchBuilder: (context, ref, settingsService) => ThemedSwitch(
            value: settingsService.shakeToReportEnabled,
            onChanged: (value) async {
              HapticFeedback.selectionClick();
              await ref.read(bugReportServiceProvider).setEnabled(value);
              safeSetState(() {});
            },
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.forum_outlined,
          title: context.l10n.settingsTileMyBugReportsTitle,
          subtitle: context.l10n.settingsTileMyBugReportsSubtitle,
          keywords: ['bug', 'report', 'feedback', 'support', 'response'],
          section: context.l10n.settingsSectionFeedback,
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.pushNamed(context, '/my-bug-reports');
          },
        ),
        _SearchableSettingItem(
          icon: Icons.palette,
          title:
              storeProducts[RevenueCatConfig.themePackProductId]?.title ??
              context.l10n.settingsSearchThemePackTitle,
          subtitle: context.l10n.settingsSearchThemePackSubtitle,
          keywords: ['color', 'accent', 'visual', 'appearance', 'dark'],
          section: context.l10n.settingsSectionPremium,
          onTap: () {
            if (purchaseState.hasFeature(PremiumFeature.premiumThemes)) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ThemeSettingsScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            }
          },
        ),
        _SearchableSettingItem(
          icon: Icons.bolt,
          title:
              storeProducts[RevenueCatConfig.automationsPackProductId]?.title ??
              context.l10n.settingsSearchAutomationsPackTitle,
          subtitle: context.l10n.settingsSearchAutomationsPackSubtitle,
          keywords: ['auto', 'trigger', 'action', 'rule', 'automatic'],
          section: context.l10n.settingsSectionPremium,
          onTap: () {
            if (purchaseState.hasFeature(PremiumFeature.automations)) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AutomationsScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            }
          },
        ),
        _SearchableSettingItem(
          icon: Icons.webhook,
          title:
              storeProducts[RevenueCatConfig.iftttPackProductId]?.title ??
              context.l10n.settingsSearchIftttPackTitle,
          subtitle: context.l10n.settingsSearchIftttPackSubtitle,
          keywords: ['integration', 'webhook', 'external', 'connect'],
          section: context.l10n.settingsSectionPremium,
          onTap: () {
            if (purchaseState.hasFeature(PremiumFeature.iftttIntegration)) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const IftttConfigScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            }
          },
        ),
        _SearchableSettingItem(
          icon: Icons.widgets,
          title:
              storeProducts[RevenueCatConfig.widgetPackProductId]?.title ??
              context.l10n.settingsSearchWidgetPackTitle,
          subtitle: context.l10n.settingsSearchWidgetPackSubtitle,
          keywords: ['home', 'widget', 'screen', 'launcher'],
          section: context.l10n.settingsSectionPremium,
          onTap: () {
            if (purchaseState.hasFeature(PremiumFeature.homeWidgets)) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WidgetBuilderScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            }
          },
        ),
        if (AppFeatureFlags.isTranslationEnabled)
          _SearchableSettingItem(
            icon: Icons.translate,
            title: purchaseState.hasFeature(PremiumFeature.translation)
                ? context.l10n.translationSettingsSearchTitle
                : storeProducts[RevenueCatConfig.translationPackProductId]
                          ?.title ??
                      context.l10n.settingsSearchTranslationPackTitle,
            subtitle: purchaseState.hasFeature(PremiumFeature.translation)
                ? context.l10n.translationSettingsSearchSubtitle
                : context.l10n.settingsSearchTranslationPackSubtitle,
            keywords: [
              'translation',
              'translate',
              'language',
              'foreign',
              'multilingual',
              'privacy',
              'api',
              'key',
              'byo',
              'cache',
            ],
            section: context.l10n.settingsSectionPremium,
            onTap: () {
              if (purchaseState.hasFeature(PremiumFeature.translation)) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TranslationSettingsScreen(),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                );
              }
            },
          ),

        // Profile
        _SearchableSettingItem(
          icon: Icons.person_outline,
          title: context.l10n.settingsProfileTitle,
          subtitle: context.l10n.settingsSearchProfileSubtitle,
          keywords: ['user', 'name', 'avatar', 'account', 'bio'],
          section: context.l10n.settingsSectionAccount,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AccountSubscriptionsScreen(),
            ),
          ),
        ),

        // Age Group
        _SearchableSettingItem(
          icon: Icons.cake_outlined,
          title: context.l10n.settingsAgeGroupTitle,
          subtitle: context.l10n.settingsAgeGroupSubtitleUnknown,
          keywords: ['age', 'minor', 'teen', 'adult', 'eligibility', 'safety'],
          section: context.l10n.settingsSectionAccount,
        ),

        // Social Notifications
        _SearchableSettingItem(
          icon: Icons.person_add_outlined,
          title: context.l10n.settingsSocialNewFollowersTitle,
          subtitle: context.l10n.settingsSearchNewFollowersSubtitle,
          keywords: ['social', 'notification', 'follow', 'follower'],
          section: context.l10n.settingsSectionSocialNotifications,
          hasSwitch: true,
        ),
        _SearchableSettingItem(
          icon: Icons.favorite_outline,
          title: context.l10n.settingsSocialLikesTitle,
          subtitle: context.l10n.settingsSearchLikesSubtitle,
          keywords: ['social', 'notification', 'like', 'heart'],
          section: context.l10n.settingsSectionSocialNotifications,
          hasSwitch: true,
        ),
        _SearchableSettingItem(
          icon: Icons.chat_bubble_outline,
          title: context.l10n.settingsSocialCommentsTitle,
          subtitle: context.l10n.settingsSearchCommentsSubtitle,
          keywords: ['social', 'notification', 'comment', 'mention', 'reply'],
          section: context.l10n.settingsSectionSocialNotifications,
          hasSwitch: true,
        ),
        _SearchableSettingItem(
          icon: Icons.devices,
          title: context.l10n.settingsSearchLinkedDevicesTitle,
          subtitle: context.l10n.settingsSearchLinkedDevicesSubtitle,
          keywords: ['device', 'node', 'link', 'mesh', 'meshtastic', 'connect'],
          section: context.l10n.settingsSectionProfile,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LinkedDevicesScreen()),
          ),
        ),

        // Connection
        _SearchableSettingItem(
          icon: Icons.bluetooth,
          title: context.l10n.settingsTileAutoReconnectTitle,
          subtitle: context.l10n.settingsTileAutoReconnectSubtitle,
          keywords: ['bluetooth', 'connect', 'device', 'auto'],
          section: context.l10n.settingsSectionConnection,
          hasSwitch: true,
        ),
        _SearchableSettingItem(
          icon: Icons.bluetooth_connected,
          title: context.l10n.settingsTileBackgroundConnectionTitle,
          subtitle: context.l10n.settingsTileBackgroundConnectionSubtitle,
          keywords: [
            'background',
            'ble',
            'foreground',
            'service',
            'notification',
            'battery',
          ],
          section: context.l10n.settingsSectionConnection,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const BackgroundConnectionScreen(),
            ),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.my_location,
          title: context.l10n.settingsTileProvideLocationTitle,
          subtitle: context.l10n.settingsTileProvideLocationSubtitle,
          keywords: [
            'gps',
            'location',
            'phone',
            'position',
            'provide',
            'share',
          ],
          section: context.l10n.settingsSectionConnection,
          hasSwitch: true,
          switchBuilder: (context, ref, settingsService) => ThemedSwitch(
            value: settingsService.providePhoneLocation,
            onChanged: (value) async {
              HapticFeedback.selectionClick();
              if (value) {
                // Check location services are enabled on the device.
                final serviceEnabled =
                    await Geolocator.isLocationServiceEnabled();
                if (!serviceEnabled) {
                  if (context.mounted) {
                    showActionSnackBar(
                      context,
                      context.l10n.settingsLocationServicesDisabled,
                      actionLabel: context.l10n.settingsLocationOpenSettings,
                      onAction: () => Geolocator.openLocationSettings(),
                      type: SnackBarType.warning,
                    );
                  }
                  return;
                }

                // Check and request OS location permission.
                var permission = await Geolocator.checkPermission();
                if (permission == LocationPermission.denied) {
                  permission = await Geolocator.requestPermission();
                  if (permission == LocationPermission.denied) {
                    if (context.mounted) {
                      showActionSnackBar(
                        context,
                        context.l10n.settingsLocationPermissionDenied,
                        actionLabel: context.l10n.settingsLocationOpenSettings,
                        onAction: () => Geolocator.openAppSettings(),
                        type: SnackBarType.warning,
                      );
                    }
                    return;
                  }
                }

                if (permission == LocationPermission.deniedForever) {
                  if (context.mounted) {
                    showActionSnackBar(
                      context,
                      context.l10n.settingsLocationPermissionPermanentlyDenied,
                      actionLabel: context.l10n.settingsLocationOpenSettings,
                      onAction: () => Geolocator.openAppSettings(),
                      type: SnackBarType.warning,
                    );
                  }
                  return;
                }
              }
              await settingsService.setProvidePhoneLocation(value);
              ref.invalidate(settingsServiceProvider);
            },
          ),
        ),

        _SearchableSettingItem(
          icon: Icons.lan,
          title: context.l10n.settingsTileNetworkEndpointsTitle,
          subtitle: context.l10n.settingsTileNetworkEndpointsSubtitle,
          keywords: [
            'network',
            'tcp',
            'ip',
            'endpoint',
            'wifi',
            'mdns',
            'connect',
          ],
          section: context.l10n.settingsSectionConnection,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NetworkEndpointsScreen()),
          ),
        ),
        if (AppFeatureFlags.isReticulumTunnelEnabled)
          _SearchableSettingItem(
            icon: Icons.podcasts,
            title: context.l10n.settingsReticulumTunnelTitle,
            subtitle: context.l10n.settingsReticulumTunnelSubtitle,
            keywords: const [
              'reticulum',
              'rns',
              'tunnel',
              'port 76',
              'fragment',
              'capture',
              'observability',
            ],
            section: context.l10n.settingsSectionConnection,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ReticulumDiagnosticsScreen(),
              ),
            ),
          ),
        if (AppFeatureFlags.isReticulumTunnelEnabled &&
            ref.watch(reticulumFlagsProvider).diagnosticsEnabled &&
            ref.watch(reticulumFlagsProvider).reassemblyEnabled)
          _SearchableSettingItem(
            icon: Icons.cable,
            title: context.l10n.settingsReticulumBridgeTitle,
            subtitle: context.l10n.settingsReticulumBridgeSubtitle,
            keywords: const [
              'reticulum',
              'rns',
              'bridge',
              'tcp',
              'rnsd',
              'forward',
              'tunnel',
            ],
            section: context.l10n.settingsSectionConnection,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReticulumBridgeScreen()),
            ),
          ),

        // TAK Gateway (feature-gated)
        if (AppFeatureFlags.isTakGatewayEnabled ||
            AppFeatureFlags.isTakMeshBridgeEnabled)
          _SearchableSettingItem(
            icon: Icons.military_tech,
            title: context.l10n.settingsSearchTakGatewayTitle,
            subtitle: context.l10n.settingsSearchTakGatewaySubtitle,
            keywords: [
              'tak',
              'gateway',
              'cot',
              'atak',
              'military',
              'publish',
              'callsign',
            ],
            section: context.l10n.settingsSectionConnection,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TakSettingsScreen()),
            ),
          ),

        // Haptic Feedback
        _SearchableSettingItem(
          icon: Icons.vibration,
          title: context.l10n.settingsTileHapticFeedbackTitle,
          subtitle: context.l10n.settingsTileHapticFeedbackSubtitle,
          keywords: ['vibration', 'haptic', 'touch', 'feedback'],
          section: context.l10n.settingsSectionHapticFeedback,
          hasSwitch: true,
        ),
        _SearchableSettingItem(
          icon: Icons.tune,
          title: context.l10n.settingsTileIntensityTitle,
          subtitle: context.l10n.settingsSearchHapticIntensitySubtitle,
          keywords: ['vibration', 'strength', 'intensity'],
          section: context.l10n.settingsSectionHapticFeedback,
          onTap: () =>
              _showHapticIntensityPicker(context, ref, settingsService),
        ),

        // Appearance & Accessibility
        _SearchableSettingItem(
          icon: Icons.accessibility_new_rounded,
          title: context.l10n.settingsTileAppearanceTitle,
          subtitle: context.l10n.settingsTileAppearanceSubtitle,
          keywords: [
            'accessibility',
            'font',
            'text',
            'size',
            'scale',
            'density',
            'contrast',
            'motion',
            'reduce',
            'appearance',
            'readable',
          ],
          section: context.l10n.settingsSectionAppearance,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AppearanceAccessibilityScreen(),
            ),
          ),
        ),

        // What's New
        _SearchableSettingItem(
          icon: Icons.auto_awesome_outlined,
          title: context.l10n.settingsTileWhatsNewTitle,
          subtitle: context.l10n.settingsTileWhatsNewSubtitle,
          keywords: [
            'new',
            'update',
            'feature',
            'changelog',
            'release',
            'whats',
          ],
          section: context.l10n.settingsSectionWhatsNew,
          onTap: () => WhatsNewSheet.showHistory(context),
        ),

        // Animations
        _SearchableSettingItem(
          icon: Icons.animation,
          title: context.l10n.settingsTileListAnimationsTitle,
          subtitle: context.l10n.settingsTileListAnimationsSubtitle,
          keywords: ['animation', 'motion', 'effect', 'slide', 'bounce'],
          section: context.l10n.settingsSectionAnimations,
          hasSwitch: true,
        ),
        _SearchableSettingItem(
          icon: Icons.view_in_ar,
          title: context.l10n.settingsTile3dEffectsTitle,
          subtitle: context.l10n.settingsTile3dEffectsSubtitle,
          keywords: ['3d', 'depth', 'perspective', 'transform'],
          section: context.l10n.settingsSectionAnimations,
          hasSwitch: true,
        ),

        // Notifications
        _SearchableSettingItem(
          icon: Icons.notifications_outlined,
          title: context.l10n.settingsTilePushNotificationsTitle,
          subtitle: context.l10n.settingsTilePushNotificationsSubtitle,
          keywords: ['notification', 'alert', 'push', 'notify'],
          section: context.l10n.settingsSectionNotifications,
          hasSwitch: true,
        ),
        _SearchableSettingItem(
          icon: Icons.person_add_outlined,
          title: context.l10n.settingsSearchNewNodesNotificationsTitle,
          subtitle: context.l10n.settingsSearchNewNodesNotificationsSubtitle,
          keywords: ['notification', 'node', 'join', 'new'],
          section: context.l10n.settingsSectionNotifications,
          hasSwitch: true,
        ),
        _SearchableSettingItem(
          icon: Icons.chat_bubble_outline,
          title: context.l10n.settingsSearchDmNotificationsTitle,
          subtitle: context.l10n.settingsSearchDmNotificationsSubtitle,
          keywords: ['notification', 'dm', 'direct', 'message', 'private'],
          section: context.l10n.settingsSectionNotifications,
          hasSwitch: true,
        ),
        _SearchableSettingItem(
          icon: Icons.forum_outlined,
          title: context.l10n.settingsSearchChannelNotificationsTitle,
          subtitle: context.l10n.settingsSearchChannelNotificationsSubtitle,
          keywords: ['notification', 'channel', 'broadcast', 'group'],
          section: context.l10n.settingsSectionNotifications,
          hasSwitch: true,
        ),
        _SearchableSettingItem(
          icon: Icons.volume_up_outlined,
          title: context.l10n.settingsSearchNotificationSoundTitle,
          subtitle: context.l10n.settingsSearchNotificationSoundSubtitle,
          keywords: ['sound', 'audio', 'alert', 'ring'],
          section: context.l10n.settingsSectionNotifications,
          hasSwitch: true,
        ),
        _SearchableSettingItem(
          icon: Icons.vibration,
          title: context.l10n.settingsSearchNotificationVibrationTitle,
          subtitle: context.l10n.settingsSearchNotificationVibrationSubtitle,
          keywords: ['vibrate', 'haptic', 'buzz'],
          section: context.l10n.settingsSectionNotifications,
          hasSwitch: true,
        ),

        // Messaging
        _SearchableSettingItem(
          icon: Icons.bolt,
          title: context.l10n.settingsTileQuickResponsesTitle,
          subtitle: context.l10n.settingsTileQuickResponsesSubtitle,
          keywords: ['quick', 'response', 'reply', 'fast', 'canned'],
          section: context.l10n.settingsSectionMessaging,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CannedResponsesScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.message_outlined,
          title: context.l10n.settingsSearchCannedMessagesTitle,
          subtitle: context.l10n.settingsSearchCannedMessagesSubtitle,
          keywords: ['canned', 'preset', 'template', 'message'],
          section: context.l10n.settingsSectionMessaging,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CannedMessageModuleConfigScreen(),
            ),
          ),
        ),

        // File Transfer
        if (AppFeatureFlags.isFileTransferEnabled)
          _SearchableSettingItem(
            icon: Icons.swap_vert,
            title: context.l10n.settingsSearchFileTransferTitle,
            subtitle: context.l10n.settingsSearchFileTransferSubtitle,
            keywords: ['file', 'transfer', 'send', 'receive', 'share'],
            section: context.l10n.settingsSectionFileTransfer,
            hasSwitch: true,
            switchBuilder: (context, ref, settingsService) => ThemedSwitch(
              value: settingsService.fileTransferEnabled,
              onChanged: (value) async {
                HapticFeedback.selectionClick();
                await settingsService.setFileTransferEnabled(value);
                safeSetState(() {});
              },
            ),
          ),
        if (AppFeatureFlags.isFileTransferEnabled)
          _SearchableSettingItem(
            icon: Icons.auto_awesome,
            title: context.l10n.settingsSearchAutoAcceptTransfersTitle,
            subtitle: context.l10n.settingsSearchAutoAcceptTransfersSubtitle,
            keywords: [
              'auto',
              'accept',
              'file',
              'transfer',
              'receive',
              'automatic',
            ],
            section: context.l10n.settingsSectionFileTransfer,
            hasSwitch: true,
            switchBuilder: (context, ref, settingsService) => ThemedSwitch(
              value: settingsService.fileTransferAutoAccept,
              onChanged: (value) async {
                HapticFeedback.selectionClick();
                await settingsService.setFileTransferAutoAccept(value);
                safeSetState(() {});
              },
            ),
          ),
        if (AppFeatureFlags.isSipEnabled)
          _SearchableSettingItem(
            icon: Icons.verified_user,
            title: context.l10n.stlSigningTitle,
            subtitle: context.l10n.stlSigningSubtitle,
            keywords: [
              'stl',
              'signing',
              'trust',
              'security',
              'signature',
              'verify',
              'file',
              'transfer',
            ],
            section: context.l10n.settingsSectionFileTransfer,
            hasSwitch: true,
            switchBuilder: (context, ref, settingsService) => ThemedSwitch(
              value: settingsService.stlSigningEnabled,
              onChanged: (value) async {
                HapticFeedback.selectionClick();
                await settingsService.setStlSigningEnabled(value);
                safeSetState(() {});
              },
            ),
          ),

        // Data & Storage
        _SearchableSettingItem(
          icon: Icons.history,
          title: context.l10n.settingsSearchHistoryLimitTitle,
          subtitle: context.l10n.settingsSearchHistoryLimitSubtitle,
          keywords: ['history', 'limit', 'storage', 'message', 'keep'],
          section: context.l10n.settingsSectionDataStorage,
          onTap: () => _showHistoryLimitDialog(context, settingsService),
        ),
        _SearchableSettingItem(
          icon: Icons.download,
          title: context.l10n.settingsTileExportMessagesTitle,
          subtitle: context.l10n.settingsTileExportMessagesSubtitle,
          keywords: ['export', 'message', 'pdf', 'csv', 'download'],
          section: context.l10n.settingsSectionDataStorage,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DataExportScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.ios_share,
          title: context.l10n.settingsSearchExportDataTitle,
          subtitle: context.l10n.settingsSearchExportDataSubtitle,
          keywords: ['export', 'backup', 'download', 'save'],
          section: context.l10n.settingsSectionDataStorage,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DataExportScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.delete_outline,
          title: context.l10n.settingsSearchClearAllMessagesTitle,
          subtitle: context.l10n.settingsSearchClearAllMessagesSubtitle,
          keywords: ['clear', 'delete', 'remove', 'message', 'clean'],
          section: context.l10n.settingsSectionDataStorage,
          onTap: () => _confirmClearMessages(context, ref),
        ),
        _SearchableSettingItem(
          icon: Icons.refresh,
          title: context.l10n.settingsSearchResetLocalDataTitle,
          subtitle: context.l10n.settingsSearchResetLocalDataSubtitle,
          keywords: ['reset', 'clear', 'local', 'data', 'factory'],
          section: context.l10n.settingsSectionDataStorage,
          onTap: () => _confirmResetLocalData(context, ref),
        ),
        _SearchableSettingItem(
          icon: Icons.delete_forever,
          title: context.l10n.settingsTileClearAllDataTitle,
          subtitle: context.l10n.settingsSearchClearAllDataSubtitle,
          keywords: [
            'clear',
            'delete',
            'all',
            'data',
            'keys',
            'factory',
            'wipe',
          ],
          section: context.l10n.settingsSectionDataStorage,
          onTap: () => _confirmClearData(context, ref),
        ),

        // Remote Administration
        _SearchableSettingItem(
          icon: Icons.settings_remote,
          title: context.l10n.settingsSearchRemoteAdminTitle,
          subtitle: context.l10n.settingsSearchRemoteAdminSubtitle,
          keywords: [
            'remote',
            'admin',
            'administration',
            'node',
            'pki',
            'configure',
          ],
          section: context.l10n.settingsSectionRemoteAdmin,
          onTap: () async {
            final currentTarget = ref.read(remoteAdminProvider).targetNodeNum;
            final adminNotifier = ref.read(remoteAdminProvider.notifier);
            final selection = await RemoteAdminSelectorSheet.show(
              context,
              currentTarget: currentTarget,
            );
            if (!mounted) return;
            if (selection != null) {
              if (selection.isLocal) {
                adminNotifier.clearTarget();
              } else {
                adminNotifier.setTarget(selection.nodeNum!, selection.nodeName);
              }
            }
          },
        ),

        // Device
        _SearchableSettingItem(
          icon: Icons.sync,
          title: context.l10n.settingsSearchForceSyncTitle,
          subtitle: context.l10n.settingsSearchForceSyncSubtitle,
          keywords: ['sync', 'force', 'refresh', 'update'],
          section: context.l10n.settingsSectionDevice,
          onTap: () => _forceSync(context, ref),
        ),
        _SearchableSettingItem(
          icon: Icons.qr_code_scanner,
          title: context.l10n.settingsSearchScanForDeviceTitle,
          subtitle: context.l10n.settingsSearchScanForDeviceSubtitle,
          keywords: ['scan', 'qr', 'device', 'setup', 'connect'],
          section: context.l10n.settingsSectionDevice,
          onTap: () => Navigator.pushNamed(context, '/qr-scanner'),
        ),
        _SearchableSettingItem(
          icon: Icons.public,
          title: context.l10n.settingsSearchRegionTitle,
          subtitle: context.l10n.settingsSearchRegionSubtitle,
          keywords: ['region', 'frequency', 'country', 'radio'],
          section: context.l10n.settingsSectionDevice,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegionSelectionScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.settings,
          title: context.l10n.settingsTileDeviceRoleTitle,
          subtitle: context.l10n.settingsTileDeviceRoleSubtitle,
          keywords: ['device', 'config', 'name', 'role', 'settings'],
          section: context.l10n.settingsSectionDevice,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DeviceConfigScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.radio,
          title: context.l10n.settingsTileRadioConfigTitle,
          subtitle: context.l10n.settingsTileRadioConfigSubtitle,
          keywords: ['radio', 'lora', 'modem', 'channel', 'frequency'],
          section: context.l10n.settingsSectionDevice,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RadioConfigScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.my_location,
          title: context.l10n.settingsTilePositionTitle,
          subtitle: context.l10n.settingsTilePositionSubtitle,
          keywords: ['gps', 'position', 'location', 'share'],
          section: context.l10n.settingsSectionDevice,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PositionConfigScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.display_settings_outlined,
          title: context.l10n.settingsTileDisplaySettingsTitle,
          subtitle: context.l10n.settingsTileDisplaySettingsSubtitle,
          keywords: ['display', 'screen', 'brightness', 'oled', 'timeout'],
          section: context.l10n.settingsSectionDevice,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DisplayConfigScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.bluetooth_searching,
          title: context.l10n.settingsTileBluetoothTitle,
          subtitle: context.l10n.settingsTileBluetoothSubtitle,
          keywords: ['bluetooth', 'ble', 'pin', 'pairing'],
          section: context.l10n.settingsSectionDevice,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BluetoothConfigScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.wifi,
          title: context.l10n.settingsTileNetworkTitle,
          subtitle: context.l10n.settingsTileNetworkSubtitle,
          keywords: ['wifi', 'network', 'internet', 'ip', 'dhcp'],
          section: context.l10n.settingsSectionDevice,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NetworkConfigScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.battery_saver,
          title: context.l10n.settingsTilePowerManagementTitle,
          subtitle: context.l10n.settingsTilePowerManagementSubtitle,
          keywords: ['power', 'battery', 'sleep', 'save', 'energy'],
          section: context.l10n.settingsSectionDevice,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PowerConfigScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.security,
          title: context.l10n.settingsTileSecurityTitle,
          subtitle: context.l10n.settingsTileSecuritySubtitle,
          keywords: ['security', 'access', 'lock', 'admin', 'managed'],
          section: context.l10n.settingsSectionDevice,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SecurityConfigScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.power_settings_new,
          title: context.l10n.settingsTileDeviceManagementTitle,
          subtitle: context.l10n.settingsTileDeviceManagementSubtitle,
          keywords: ['reboot', 'shutdown', 'reset', 'restart', 'factory'],
          section: context.l10n.settingsSectionDevice,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DeviceManagementScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.info_outline,
          title: context.l10n.settingsTileDeviceInfoTitle,
          subtitle: context.l10n.settingsTileDeviceInfoSubtitle,
          keywords: ['info', 'details', 'hardware', 'version'],
          section: context.l10n.settingsSectionDevice,
          onTap: () => _showDeviceInfo(context, ref),
        ),
        _SearchableSettingItem(
          icon: Icons.qr_code_scanner,
          title: context.l10n.settingsTileScanQrCodeTitle,
          subtitle: context.l10n.settingsTileScanQrCodeSubtitle,
          keywords: ['qr', 'channel', 'import', 'scan'],
          section: context.l10n.settingsSectionDevice,
          onTap: () => Navigator.pushNamed(context, '/qr-scanner'),
        ),

        // Modules
        _SearchableSettingItem(
          icon: Icons.cloud,
          title: context.l10n.settingsTileMqttTitle,
          subtitle: context.l10n.settingsTileMqttSubtitle,
          keywords: ['mqtt', 'internet', 'bridge', 'server', 'broker'],
          section: context.l10n.settingsSectionModules,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MqttConfigScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.radar,
          title: context.l10n.settingsTileRangeTestTitle,
          subtitle: context.l10n.settingsTileRangeTestSubtitle,
          keywords: ['range', 'test', 'signal', 'distance'],
          section: context.l10n.settingsSectionModules,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RangeTestScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.storage,
          title: context.l10n.settingsTileStoreForwardTitle,
          subtitle: context.l10n.settingsTileStoreForwardSubtitle,
          keywords: ['store', 'forward', 'relay', 'offline', 'cache'],
          section: context.l10n.settingsSectionModules,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StoreForwardConfigScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.sensors,
          title: context.l10n.settingsTileDetectionSensorTitle,
          subtitle: context.l10n.settingsTileDetectionSensorSubtitle,
          keywords: ['sensor', 'motion', 'door', 'gpio', 'detection'],
          section: context.l10n.settingsSectionModules,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const DetectionSensorConfigScreen(),
            ),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.notifications_active,
          title: context.l10n.settingsTileExternalNotificationTitle,
          subtitle: context.l10n.settingsTileExternalNotificationSubtitle,
          keywords: ['buzzer', 'led', 'vibration', 'external', 'alert'],
          section: context.l10n.settingsSectionModules,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ExternalNotificationConfigScreen(),
            ),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.lightbulb_outline,
          title: context.l10n.settingsTileAmbientLightingTitle,
          subtitle: context.l10n.settingsTileAmbientLightingSubtitle,
          keywords: ['led', 'rgb', 'light', 'ambient', 'neopixel'],
          section: context.l10n.settingsSectionModules,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AmbientLightingConfigScreen(),
            ),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.people_outline,
          title: context.l10n.settingsTilePaxCounterTitle,
          subtitle: context.l10n.settingsTilePaxCounterSubtitle,
          keywords: ['pax', 'counter', 'wifi', 'ble', 'detection', 'people'],
          section: context.l10n.settingsSectionModules,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PaxCounterConfigScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.analytics_outlined,
          title: context.l10n.settingsTileTelemetryIntervalsTitle,
          subtitle: context.l10n.settingsTileTelemetryIntervalsSubtitle,
          keywords: ['telemetry', 'interval', 'frequency', 'update'],
          section: context.l10n.settingsSectionModules,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TelemetryConfigScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.usb_rounded,
          title: context.l10n.settingsTileSerialTitle,
          subtitle: context.l10n.settingsTileSerialSubtitle,
          keywords: ['serial', 'usb', 'port', 'uart'],
          section: context.l10n.settingsSectionModules,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SerialConfigScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.traffic,
          title: context.l10n.settingsTileTrafficManagementTitle,
          subtitle: context.l10n.settingsTileTrafficManagementSubtitle,
          keywords: ['traffic', 'management', 'rate', 'limit', 'dedup', 'hop'],
          section: context.l10n.settingsSectionModules,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const TrafficManagementConfigScreen(),
            ),
          ),
        ),

        // Telemetry Logs
        _SearchableSettingItem(
          icon: Icons.battery_charging_full,
          title: context.l10n.settingsTileDeviceMetricsTitle,
          subtitle: context.l10n.settingsTileDeviceMetricsSubtitle,
          keywords: ['battery', 'voltage', 'metrics', 'device', 'history'],
          section: context.l10n.settingsSectionTelemetryLogs,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DeviceMetricsLogScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.thermostat,
          title: context.l10n.settingsTileEnvironmentMetricsTitle,
          subtitle: context.l10n.settingsTileEnvironmentMetricsSubtitle,
          keywords: [
            'temperature',
            'humidity',
            'pressure',
            'environment',
            'weather',
          ],
          section: context.l10n.settingsSectionTelemetryLogs,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const EnvironmentMetricsLogScreen(),
            ),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.air,
          title: context.l10n.settingsTileAirQualityTitle,
          subtitle: context.l10n.settingsTileAirQualitySubtitle,
          keywords: ['air', 'quality', 'pm25', 'pm10', 'co2', 'pollution'],
          section: context.l10n.settingsSectionTelemetryLogs,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AirQualityLogScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.location_on_outlined,
          title: context.l10n.settingsTilePositionHistoryTitle,
          subtitle: context.l10n.settingsTilePositionHistorySubtitle,
          keywords: ['position', 'gps', 'location', 'history', 'track'],
          section: context.l10n.settingsSectionTelemetryLogs,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PositionLogScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.timeline,
          title: context.l10n.settingsTileTracerouteHistoryTitle,
          subtitle: context.l10n.settingsTileTracerouteHistorySubtitle,
          keywords: ['traceroute', 'path', 'network', 'hop', 'route'],
          section: context.l10n.settingsSectionTelemetryLogs,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TraceRouteLogScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.people_alt_outlined,
          title: context.l10n.settingsTilePaxCounterLogsTitle,
          subtitle: context.l10n.settingsTilePaxCounterLogsSubtitle,
          keywords: ['pax', 'counter', 'log', 'detection', 'history'],
          section: context.l10n.settingsSectionTelemetryLogs,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PaxCounterLogScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.sensors,
          title: context.l10n.settingsTileDetectionSensorLogsTitle,
          subtitle: context.l10n.settingsTileDetectionSensorLogsSubtitle,
          keywords: ['sensor', 'detection', 'log', 'event', 'history'],
          section: context.l10n.settingsSectionTelemetryLogs,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DetectionSensorLogScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.route,
          title: context.l10n.settingsTileRoutesTitle,
          subtitle: context.l10n.settingsTileRoutesSubtitle,
          keywords: ['route', 'gps', 'track', 'record', 'path'],
          section: context.l10n.settingsSectionTelemetryLogs,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RoutesScreen()),
          ),
        ),

        // Tools
        _SearchableSettingItem(
          icon: Icons.gps_fixed,
          title: context.l10n.settingsTileGpsStatusTitle,
          subtitle: context.l10n.settingsTileGpsStatusSubtitle,
          keywords: ['gps', 'status', 'satellite', 'location', 'fix'],
          section: context.l10n.settingsSectionTools,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GpsStatusScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.system_update,
          title: context.l10n.settingsTileFirmwareUpdateTitle,
          subtitle: context.l10n.settingsTileFirmwareUpdateSubtitle,
          keywords: ['firmware', 'update', 'ota', 'upgrade', 'version'],
          section: context.l10n.settingsSectionTools,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FirmwareUpdateScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.ios_share,
          title: context.l10n.settingsTileExportDataTitle,
          subtitle: context.l10n.settingsTileExportDataSubtitle,
          keywords: ['export', 'data', 'backup', 'messages', 'telemetry'],
          section: context.l10n.settingsSectionTools,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DataExportScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.article_outlined,
          title: context.l10n.settingsTileAppLogTitle,
          subtitle: context.l10n.settingsTileAppLogSubtitle,
          keywords: ['log', 'debug', 'app', 'error', 'console'],
          section: context.l10n.settingsSectionTools,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AppLogScreen()),
          ),
        ),
        // Glyph Test - only show on Nothing Phone 3
        if (ref.watch(glyphServiceProvider).deviceModel.contains('Phone (3)'))
          _SearchableSettingItem(
            icon: Icons.lightbulb,
            title: context.l10n.settingsTileGlyphMatrixTitle,
            subtitle: context.l10n.settingsTileGlyphMatrixSubtitle,
            keywords: ['glyph', 'nothing', 'led', 'test', 'light', 'matrix'],
            section: context.l10n.settingsSectionTools,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GlyphTestScreen()),
            ),
          ),

        // About
        _SearchableSettingItem(
          icon: Icons.info,
          title: context.l10n.settingsTileSocialmeshTitle,
          subtitle: context.l10n.settingsTileSocialmeshSubtitle,
          keywords: ['about', 'version', 'app', 'info'],
          section: context.l10n.settingsSectionAbout,
          onTap: () {
            final appVersion = ref.read(appVersionProvider);
            final version = appVersion.maybeWhen(
              data: (v) => v,
              orElse: () => 'unknown',
            );
            showSuccessSnackBar(
              context,
              context.l10n.settingsSocialmeshVersionSnackbar(version),
            );
          },
        ),
        _SearchableSettingItem(
          icon: Icons.phone_android,
          title: context.l10n.settingsTileDeviceInfoTitle,
          subtitle: ref.watch(glyphServiceProvider).deviceModel,
          keywords: ['device', 'phone', 'model', 'hardware', 'nothing'],
          section: context.l10n.settingsSectionAbout,
          onTap: () => _showDeviceInfo(context, ref),
        ),
        _SearchableSettingItem(
          icon: Icons.help,
          title: context.l10n.settingsTileHelpCenterTitle,
          subtitle: context.l10n.settingsTileHelpCenterSubtitle,
          keywords: ['help', 'guide', 'tutorial', 'ico', 'learn', 'tour'],
          section: context.l10n.settingsSectionAbout,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
          ),
        ),
        _SearchableSettingItem(
          icon: Icons.help_outline,
          title: context.l10n.settingsTileHelpSupportTitle,
          subtitle: context.l10n.settingsTileHelpSupportSubtitle,
          keywords: ['help', 'support', 'faq', 'contact', 'troubleshoot'],
          section: context.l10n.settingsSectionAbout,
          onTap: () => LegalDocumentSheet.showSupport(context),
        ),
        _SearchableSettingItem(
          icon: Icons.description_outlined,
          title: context.l10n.settingsTileTermsOfServiceTitle,
          subtitle: context.l10n.settingsTileTermsOfServiceSubtitle,
          keywords: ['terms', 'service', 'legal', 'tos'],
          section: context.l10n.settingsSectionAbout,
          onTap: () => LegalDocumentSheet.showTerms(context),
        ),
        _SearchableSettingItem(
          icon: Icons.privacy_tip_outlined,
          title: context.l10n.settingsTilePrivacyPolicyTitle,
          subtitle: context.l10n.settingsTilePrivacyPolicySubtitle,
          keywords: ['privacy', 'policy', 'data', 'gdpr'],
          section: context.l10n.settingsSectionAbout,
          onTap: () => LegalDocumentSheet.showPrivacy(context),
        ),
        _SearchableSettingItem(
          icon: Icons.source_outlined,
          title: context.l10n.settingsTileOpenSourceTitle,
          subtitle: context.l10n.settingsTileOpenSourceSubtitle,
          keywords: ['license', 'open', 'source', 'library', 'attribution'],
          section: context.l10n.settingsSectionAbout,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const _OpenSourceLicensesScreen(),
            ),
          ),
        ),
      ],
      orElse: () => <_SearchableSettingItem>[],
    );
  }

  /// Filter settings based on search query
  List<_SearchableSettingItem> _filterSettings(
    List<_SearchableSettingItem> settings,
    String query,
  ) {
    if (query.isEmpty) return settings;

    final lowerQuery = query.toLowerCase();
    return settings.where((item) {
      // Check title
      if (item.title.toLowerCase().contains(lowerQuery)) return true;
      // Check subtitle
      if (item.subtitle?.toLowerCase().contains(lowerQuery) ?? false) {
        return true;
      }
      // Check section
      if (item.section.toLowerCase().contains(lowerQuery)) return true;
      // Check keywords
      if (item.keywords.any((k) => k.toLowerCase().contains(lowerQuery))) {
        return true;
      }
      return false;
    }).toList();
  }

  List<Widget> _buildSearchResultsSlivers(
    BuildContext context,
    List<_SearchableSettingItem> results,
  ) {
    final settingsServiceAsync = ref.watch(settingsServiceProvider);
    if (results.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 64,
                  color: context.textTertiary.withValues(alpha: 0.5),
                ),
                SizedBox(height: AppTheme.spacing16),
                Text(
                  context.l10n.settingsNoSettingsFound,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: context.textSecondary,
                  ),
                ),
                SizedBox(height: AppTheme.spacing8),
                Text(
                  context.l10n.settingsTryDifferentSearch,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: context.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    // Group results by section
    final grouped = <String, List<_SearchableSettingItem>>{};
    for (final item in results) {
      grouped.putIfAbsent(item.section, () => []).add(item);
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final section = grouped.keys.elementAt(index);
            final items = grouped[section]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(title: section),
                ...items.map(
                  (item) => _SettingsTile(
                    icon: item.icon,
                    title: item.title,
                    subtitle: item.subtitle,
                    trailing: item.switchBuilder != null
                        ? settingsServiceAsync.when(
                            data: (settingsService) => item.switchBuilder!(
                              context,
                              ref,
                              settingsService,
                            ),
                            loading: () => Icon(
                              Icons.toggle_on_outlined,
                              color: context.textTertiary,
                              size: 24,
                            ),
                            error: (_, _) => Icon(
                              Icons.toggle_on_outlined,
                              color: context.textTertiary,
                              size: 24,
                            ),
                          )
                        : item.hasSwitch
                        ? Icon(
                            Icons.toggle_on_outlined,
                            color: context.textTertiary,
                            size: 24,
                          )
                        : null,
                    onTap:
                        item.onTap ??
                        () {
                          // Clear search when tapping an item without onTap
                          safeSetState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                  ),
                ),
                const SizedBox(height: AppTheme.spacing8),
              ],
            );
          }, childCount: grouped.length),
        ),
      ),
    ];
  }

  Widget _buildPremiumSection(BuildContext context) {
    final purchaseState = ref.watch(purchaseStateProvider);
    final storeProductsAsync = ref.watch(storeProductsProvider);
    final storeProducts = storeProductsAsync.when(
      data: (data) => data,
      loading: () => <String, StoreProductInfo>{},
      error: (e, s) => <String, StoreProductInfo>{},
    );
    final accentColor = context.accentColor;

    // Count owned items
    final ownedCount = OneTimePurchases.allPurchases
        .where((p) => purchaseState.hasPurchased(p.productId))
        .length;
    final totalCount = OneTimePurchases.allPurchases.length;

    // Calculate discount for the badge
    final bundlePrice =
        storeProducts[RevenueCatConfig.completePackProductId]?.price;
    final individualTotal = [
      RevenueCatConfig.themePackProductId,
      RevenueCatConfig.ringtonePackProductId,
      RevenueCatConfig.widgetPackProductId,
      RevenueCatConfig.automationsPackProductId,
      RevenueCatConfig.iftttPackProductId,
      RevenueCatConfig.translationPackProductId,
    ].fold<double>(0, (sum, id) => sum + (storeProducts[id]?.price ?? 0));
    final discountPercent = (bundlePrice != null && individualTotal > 0)
        ? ((1 - bundlePrice / individualTotal) * 100).round()
        : OneTimePurchases.bundleDiscountPercent;

    final ownsAll =
        ownedCount == totalCount ||
        purchaseState.hasPurchased(RevenueCatConfig.completePackProductId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: context.l10n.settingsSectionPremium),
        // Complete Pack mini hero card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: ownsAll
                  ? [
                      accentColor.withValues(alpha: 0.15),
                      accentColor.withValues(alpha: 0.05),
                    ]
                  : [
                      accentColor.withValues(alpha: 0.25),
                      AppTheme.primaryPurple.withValues(alpha: 0.15),
                    ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            border: Border.all(
              color: accentColor.withValues(alpha: ownsAll ? 0.5 : 0.7),
              width: 1.5,
            ),
            boxShadow: ownsAll
                ? null
                : [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.15),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              ),
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: ownsAll
                                ? null
                                : LinearGradient(
                                    colors: [
                                      accentColor,
                                      AppTheme.primaryPurple,
                                    ],
                                  ),
                            color: ownsAll
                                ? accentColor.withValues(alpha: 0.2)
                                : null,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius12,
                            ),
                          ),
                          child: Icon(
                            ownsAll ? Icons.verified : Icons.all_inclusive,
                            color: ownsAll ? accentColor : Colors.white,
                            size: 26,
                          ),
                        ),
                        if (!ownsAll)
                          const Positioned(
                            top: -10,
                            right: -10,
                            child: SimpleVerifiedBadge(size: 20),
                          ),
                      ],
                    ),
                    SizedBox(width: AppTheme.spacing16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ownsAll
                                ? context.l10n.settingsPremiumAllUnlocked
                                : context.l10n.subscriptionCompletePack,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: ownsAll ? accentColor : Colors.white,
                            ),
                          ),
                          if (!ownsAll) ...[
                            const SizedBox(height: AppTheme.spacing4),
                            Wrap(
                              spacing: AppTheme.spacing6,
                              runSpacing: AppTheme.spacing4,
                              children: [
                                _PremiumBadge(
                                  text: context.l10n.subscriptionPopularBadge,
                                  backgroundColor: accentColor,
                                  textColor: Colors.white,
                                ),
                                _PremiumBadge(
                                  text: context.l10n.subscriptionSavePercent(
                                    discountPercent.toString(),
                                  ),
                                  backgroundColor: AppTheme.warningYellow,
                                  textColor: Colors.black,
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: AppTheme.spacing2),
                          Text(
                            ownsAll
                                ? context.l10n.subscriptionThankYou
                                : context.l10n.subscriptionCompletePackSubtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: ownsAll
                                  ? context.textSecondary
                                  : Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: ownsAll ? accentColor : Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacing8),
        // Premium feature tiles - Translation Pack first (new), then others
        if (AppFeatureFlags.isTranslationEnabled)
          _PremiumFeatureTile(
            icon: Icons.translate_outlined,
            iconColor: AccentColors.teal,
            title:
                storeProducts[RevenueCatConfig.translationPackProductId]
                    ?.title ??
                context.l10n.settingsSearchTranslationPackTitle,
            feature: PremiumFeature.translation,
            onTap: () {
              if (purchaseState.hasFeature(PremiumFeature.translation)) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TranslationSettingsScreen(),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                );
              }
            },
          ),
        _PremiumFeatureTile(
          icon: Icons.palette_outlined,
          iconColor: AccentColors.purple,
          title:
              storeProducts[RevenueCatConfig.themePackProductId]?.title ??
              context.l10n.settingsSearchThemePackTitle,
          feature: PremiumFeature.premiumThemes,
          onTap: () {
            final hasFeature = purchaseState.hasFeature(
              PremiumFeature.premiumThemes,
            );
            final showUpsell = ref.read(
              premiumFeatureGateProvider('premiumThemes'),
            );
            if (hasFeature || showUpsell) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ThemeSettingsScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            }
          },
        ),
        _PremiumFeatureTile(
          icon: Icons.music_note_outlined,
          iconColor: AccentColors.pink,
          title:
              storeProducts[RevenueCatConfig.ringtonePackProductId]?.title ??
              context.l10n.settingsSearchRingtonePackTitle,
          feature: PremiumFeature.customRingtones,
          onTap: () {
            final hasFeature = purchaseState.hasFeature(
              PremiumFeature.customRingtones,
            );
            final showUpsell = ref.read(
              premiumFeatureGateProvider('customRingtones'),
            );
            if (hasFeature || showUpsell) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RingtoneScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            }
          },
        ),
        _PremiumFeatureTile(
          icon: Icons.widgets_outlined,
          iconColor: AccentColors.coral,
          title:
              storeProducts[RevenueCatConfig.widgetPackProductId]?.title ??
              context.l10n.settingsSearchWidgetPackTitle,
          feature: PremiumFeature.homeWidgets,
          onTap: () {
            final hasFeature = purchaseState.hasFeature(
              PremiumFeature.homeWidgets,
            );
            final showUpsell = ref.read(
              premiumFeatureGateProvider('homeWidgets'),
            );
            if (hasFeature || showUpsell) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WidgetBuilderScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            }
          },
        ),
        _PremiumFeatureTile(
          icon: Icons.bolt,
          iconColor: AppTheme.warningYellow,
          title:
              storeProducts[RevenueCatConfig.automationsPackProductId]?.title ??
              context.l10n.settingsSearchAutomationsPackTitle,
          feature: PremiumFeature.automations,
          onTap: () {
            final hasFeature = purchaseState.hasFeature(
              PremiumFeature.automations,
            );
            final showUpsell = ref.read(
              premiumFeatureGateProvider('automations'),
            );
            if (hasFeature || showUpsell) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AutomationsScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            }
          },
        ),
        _PremiumFeatureTile(
          icon: Icons.webhook_outlined,
          iconColor: AccentColors.blue,
          title:
              storeProducts[RevenueCatConfig.iftttPackProductId]?.title ??
              context.l10n.settingsSearchIftttPackTitle,
          feature: PremiumFeature.iftttIntegration,
          onTap: () {
            final hasFeature = purchaseState.hasFeature(
              PremiumFeature.iftttIntegration,
            );
            final showUpsell = ref.read(
              premiumFeatureGateProvider('iftttIntegration'),
            );
            if (hasFeature || showUpsell) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const IftttConfigScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            }
          },
        ),
      ],
    );
  }

  /// Build the Remote Administration selector widget
  /// Shows a tappable tile that opens a bottom sheet to select target node
  Widget _buildRemoteAdminSelector(BuildContext context, WidgetRef ref) {
    final remoteState = ref.watch(remoteAdminProvider);
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final connectedDevice = ref.watch(connectedDeviceProvider);
    final accentColor = context.accentColor;

    // Only show if we have other nodes to configure
    // Filter to nodes with public keys (can accept admin messages via PKI)
    final adminableNodes = nodes.values.where((node) {
      // Exclude our own node
      if (node.nodeNum == myNodeNum) return false;
      // Node must have a public key for PKI admin messages
      return node.hasPublicKey;
    }).toList();

    // If no other nodes, don't show the selector
    if (adminableNodes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: context.l10n.settingsSectionRemoteAdmin),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          decoration: BoxDecoration(
            color: remoteState.isRemote
                ? accentColor.withValues(alpha: 0.1)
                : context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            border: remoteState.isRemote
                ? Border.all(color: accentColor.withValues(alpha: 0.5))
                : null,
          ),
          child: Column(
            children: [
              ListTile(
                onTap: () async {
                  final selection = await RemoteAdminSelectorSheet.show(
                    context,
                    currentTarget: remoteState.targetNodeNum,
                  );
                  if (!mounted) return;
                  if (selection != null) {
                    if (selection.isLocal) {
                      ref.read(remoteAdminProvider.notifier).clearTarget();
                    } else {
                      ref
                          .read(remoteAdminProvider.notifier)
                          .setTarget(selection.nodeNum!, selection.nodeName);
                    }
                  }
                },
                leading: Icon(
                  remoteState.isRemote
                      ? Icons.admin_panel_settings
                      : Icons.settings_remote,
                  color: remoteState.isRemote
                      ? accentColor
                      : context.textSecondary,
                ),
                title: Text(
                  remoteState.isRemote
                      ? context.l10n.settingsRemoteAdminConfiguringTitle
                      : context.l10n.settingsRemoteAdminConfigureTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: remoteState.isRemote
                        ? accentColor
                        : context.textPrimary,
                    fontWeight: remoteState.isRemote
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Flexible(
                      child: Text(
                        remoteState.isRemote
                            ? remoteState.targetNodeName ??
                                  '0x${remoteState.targetNodeNum!.toRadixString(16)}'
                            : connectedDevice?.name ??
                                  context
                                      .l10n
                                      .settingsRemoteAdminConnectedDevice,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: remoteState.isRemote
                              ? accentColor.withValues(alpha: 0.8)
                              : context.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (remoteState.isRemote) ...[
                      const SizedBox(width: AppTheme.spacing6),
                      Icon(
                        Icons.lock,
                        size: 12,
                        color: accentColor.withValues(alpha: 0.7),
                      ),
                    ],
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.settingsRemoteAdminNodeCount(
                        adminableNodes.length,
                      ),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.textTertiary,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing4),
                    Icon(
                      Icons.chevron_right,
                      color: remoteState.isRemote
                          ? accentColor
                          : context.textSecondary,
                    ),
                  ],
                ),
              ),
              if (remoteState.isRemote)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacing16,
                    0,
                    16,
                    12,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.spacing12),
                    decoration: BoxDecoration(
                      color: AccentColors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                      border: Border.all(
                        color: AccentColors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AccentColors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: AppTheme.spacing8),
                        Expanded(
                          child: Text(
                            context.l10n.settingsRemoteAdminWarning,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: AccentColors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),
      ],
    );
  }

  void _dismissKeyboard() {
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final settingsServiceAsync = ref.watch(settingsServiceProvider);

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: HelpTourController(
        topicId: 'settings_overview',
        stepKeys: const {},
        child: GlassScaffold(
          resizeToAvoidBottomInset: false,
          title: context.l10n.settingsTitle,
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: context.l10n.settingsHelpTooltip,
              onPressed: () => ref
                  .read(helpProvider.notifier)
                  .startTour('settings_overview'),
            ),
          ],
          slivers: [
            // Pinned search header
            SliverPersistentHeader(
              pinned: true,
              delegate: SearchFilterHeaderDelegate(
                searchController: _searchController,
                searchQuery: _searchQuery,
                onSearchChanged: (value) =>
                    safeSetState(() => _searchQuery = value),
                hintText: context.l10n.settingsSearchHint,
                focusNode: _searchFocusNode,
                textScaler: MediaQuery.textScalerOf(context),
              ),
            ),
            // Content - search results or settings list
            if (_searchQuery.isNotEmpty)
              ..._buildSearchResultsSlivers(
                context,
                _filterSettings(
                  _getSearchableSettings(context, ref),
                  _searchQuery,
                ),
              )
            else
              ...settingsServiceAsync.when(
                loading: () => [
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: ScreenLoadingIndicator(),
                  ),
                ],
                error: (error, stack) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: AppTheme.errorRed,
                          ),
                          const SizedBox(height: AppTheme.spacing16),
                          Text(
                            context.l10n.settingsErrorLoading(error.toString()),
                            style: TextStyle(color: context.textSecondary),
                          ),
                          const SizedBox(height: AppTheme.spacing16),
                          ElevatedButton(
                            onPressed: () =>
                                ref.invalidate(settingsServiceProvider),
                            style:
                                ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                ).copyWith(
                                  backgroundColor: WidgetStateProperty.all(
                                    Colors.transparent,
                                  ),
                                ),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    context.accentColor,
                                    context.accentColor.withOpacity(0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius8,
                                ),
                              ),
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: 48,
                                ),
                                alignment: Alignment.center,
                                child: Text(context.l10n.commonRetry),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                data: (settingsService) {
                  // Watch accent color for dynamic updates (triggers rebuild when changed)
                  final accentColorAsync = ref.watch(accentColorProvider);
                  final _ =
                      accentColorAsync.asData?.value; // Just to trigger rebuild

                  // Get current region for display
                  final regionAsync = ref.watch(deviceRegionProvider);
                  final regionSubtitle = regionAsync.when(
                    data: (region) {
                      if (region ==
                          config_pbenum.Config_LoRaConfig_RegionCode.UNSET) {
                        return context.l10n.settingsNotConfigured;
                      }
                      // Find the region info for display
                      final regionInfo = getAvailableRegions(
                        context,
                      ).where((r) => r.code == region).firstOrNull;
                      if (regionInfo != null) {
                        return '${regionInfo.name} (${regionInfo.frequency})';
                      }
                      return region.name;
                    },
                    loading: () => context.l10n.settingsLoadingStatus,
                    error: (e, _) =>
                        context.l10n.settingsRegionConfigureSubtitle,
                  );

                  return [
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // Subscription Section
                          _buildPremiumSection(context),

                          const SizedBox(height: AppTheme.spacing16),

                          // Profile Section - right after Premium, before Connection
                          _SectionHeader(
                            title: context.l10n.settingsSectionAccount,
                          ),
                          _ProfileTile(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const AccountSubscriptionsScreen(),
                              ),
                            ),
                          ),

                          _SettingsTile(
                            icon: Icons.shield_outlined,
                            title: context.l10n.settingsTilePrivacyTitle,
                            subtitle: context.l10n.settingsTilePrivacySubtitle,
                            trailing: Icon(
                              Icons.chevron_right,
                              color: context.textTertiary,
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PrivacySettingsScreen(),
                              ),
                            ),
                          ),

                          _AgeGroupTile(),

                          // _FollowRequestsTile()

                          // Social Notifications Section (only for signed-in users)
                          // const _SocialNotificationsSection(),
                          const SizedBox(height: AppTheme.spacing16),

                          // Feedback Section
                          _SectionHeader(
                            title: context.l10n.settingsSectionFeedback,
                          ),
                          _SettingsTile(
                            icon: Icons.bug_report_outlined,
                            title: context.l10n.settingsTileShakeToReportTitle,
                            subtitle:
                                context.l10n.settingsTileShakeToReportSubtitle,
                            trailing: ThemedSwitch(
                              value: settingsService.shakeToReportEnabled,
                              onChanged: (value) async {
                                HapticFeedback.selectionClick();
                                await ref
                                    .read(bugReportServiceProvider)
                                    .setEnabled(value);
                                safeSetState(() {});
                              },
                            ),
                          ),
                          if (ref.watch(currentUserProvider) != null)
                            _SettingsTile(
                              icon: Icons.forum_outlined,
                              title: context.l10n.settingsTileMyBugReportsTitle,
                              subtitle:
                                  context.l10n.settingsTileMyBugReportsSubtitle,
                              trailing: Consumer(
                                builder: (context, ref, _) {
                                  final countAsync = ref.watch(
                                    bugReportUnreadCountProvider,
                                  );
                                  final count = countAsync.when(
                                    data: (c) => c,
                                    loading: () => 0,
                                    error: (_, _) => 0,
                                  );
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (count > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          margin: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: context.accentColor,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            '$count',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      Icon(
                                        Icons.chevron_right,
                                        color: context.textTertiary,
                                      ),
                                    ],
                                  );
                                },
                              ),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                Navigator.pushNamed(context, '/my-bug-reports');
                              },
                            )
                          else
                            Opacity(
                              opacity: 0.5,
                              child: _SettingsTile(
                                icon: Icons.forum_outlined,
                                title:
                                    context.l10n.settingsTileMyBugReportsTitle,
                                subtitle: context
                                    .l10n
                                    .settingsTileMyBugReportsNotSignedIn,
                                trailing: Icon(
                                  Icons.chevron_right,
                                  color: context.textTertiary,
                                ),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const AccountSubscriptionsScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),

                          const SizedBox(height: AppTheme.spacing16),

                          // Connection Section
                          _SectionHeader(
                            title: context.l10n.settingsSectionConnection,
                          ),
                          _SettingsTile(
                            icon: Icons.bluetooth,
                            title: context.l10n.settingsTileAutoReconnectTitle,
                            subtitle:
                                context.l10n.settingsTileAutoReconnectSubtitle,
                            trailing: ThemedSwitch(
                              value: settingsService.autoReconnect,
                              onChanged: (value) async {
                                HapticFeedback.selectionClick();
                                await settingsService.setAutoReconnect(value);
                                safeSetState(() {});
                              },
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.bluetooth_connected,
                            title: context
                                .l10n
                                .settingsTileBackgroundConnectionTitle,
                            subtitle: context
                                .l10n
                                .settingsTileBackgroundConnectionSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const BackgroundConnectionScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.my_location,
                            title:
                                context.l10n.settingsTileProvideLocationTitle,
                            subtitle: context
                                .l10n
                                .settingsTileProvideLocationSubtitle,
                            trailing: ThemedSwitch(
                              value: settingsService.providePhoneLocation,
                              onChanged: (value) async {
                                HapticFeedback.selectionClick();
                                await settingsService.setProvidePhoneLocation(
                                  value,
                                );
                                safeSetState(() {});
                              },
                            ),
                          ),

                          const SizedBox(height: AppTheme.spacing16),

                          // Haptic Feedback Section
                          _SectionHeader(
                            title: context.l10n.settingsSectionHapticFeedback,
                          ),
                          _SettingsTile(
                            icon: Icons.vibration,
                            title: context.l10n.settingsTileHapticFeedbackTitle,
                            subtitle:
                                context.l10n.settingsTileHapticFeedbackSubtitle,
                            trailing: ThemedSwitch(
                              value: settingsService.hapticFeedbackEnabled,
                              onChanged: (value) async {
                                if (value) {
                                  ref.haptics.toggle();
                                }
                                await settingsService.setHapticFeedbackEnabled(
                                  value,
                                );
                                ref
                                    .read(userProfileProvider.notifier)
                                    .updatePreferences(
                                      UserPreferences(
                                        hapticFeedbackEnabled: value,
                                      ),
                                    );
                                safeSetState(() {});
                              },
                            ),
                          ),
                          if (settingsService.hapticFeedbackEnabled)
                            _SettingsTile(
                              icon: Icons.tune,
                              title: context.l10n.settingsTileIntensityTitle,
                              subtitle: HapticIntensity.fromValue(
                                settingsService.hapticIntensity,
                              ).label,
                              onTap: () => _showHapticIntensityPicker(
                                context,
                                ref,
                                settingsService,
                              ),
                            ),

                          const SizedBox(height: AppTheme.spacing16),

                          // Appearance & Accessibility Section
                          _SectionHeader(
                            title: context.l10n.settingsSectionAppearance,
                          ),
                          _SettingsTile(
                            icon: Icons.accessibility_new_rounded,
                            title: context.l10n.settingsTileAppearanceTitle,
                            subtitle:
                                context.l10n.settingsTileAppearanceSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const AppearanceAccessibilityScreen(),
                              ),
                            ),
                          ),

                          const SizedBox(height: AppTheme.spacing16),

                          // What's New Section
                          _SectionHeader(
                            title: context.l10n.settingsSectionWhatsNew,
                          ),
                          _SettingsTile(
                            icon: Icons.auto_awesome_outlined,
                            title: context.l10n.settingsTileWhatsNewTitle,
                            subtitle: context.l10n.settingsTileWhatsNewSubtitle,
                            iconColor: AppTheme.warningYellow,
                            onTap: () => WhatsNewSheet.showHistory(context),
                          ),

                          const SizedBox(height: AppTheme.spacing16),

                          // Animations Section
                          _SectionHeader(
                            title: context.l10n.settingsSectionAnimations,
                          ),
                          _SettingsTile(
                            icon: Icons.animation,
                            title: context.l10n.settingsTileListAnimationsTitle,
                            subtitle:
                                context.l10n.settingsTileListAnimationsSubtitle,
                            trailing: ThemedSwitch(
                              value: settingsService.animationsEnabled,
                              onChanged: (value) async {
                                HapticFeedback.selectionClick();
                                await settingsService.setAnimationsEnabled(
                                  value,
                                );
                                ref
                                    .read(userProfileProvider.notifier)
                                    .updatePreferences(
                                      UserPreferences(animationsEnabled: value),
                                    );
                                ref
                                    .read(settingsRefreshProvider.notifier)
                                    .refresh();
                                safeSetState(() {});
                              },
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.view_in_ar,
                            title: context.l10n.settingsTile3dEffectsTitle,
                            subtitle:
                                context.l10n.settingsTile3dEffectsSubtitle,
                            trailing: ThemedSwitch(
                              value: settingsService.animations3DEnabled,
                              onChanged: (value) async {
                                HapticFeedback.selectionClick();
                                await settingsService.setAnimations3DEnabled(
                                  value,
                                );
                                ref
                                    .read(userProfileProvider.notifier)
                                    .updatePreferences(
                                      UserPreferences(
                                        animations3DEnabled: value,
                                      ),
                                    );
                                ref
                                    .read(settingsRefreshProvider.notifier)
                                    .refresh();
                                safeSetState(() {});
                              },
                            ),
                          ),

                          const SizedBox(height: AppTheme.spacing16),

                          // Notifications Section
                          _SectionHeader(
                            title: context.l10n.settingsSectionNotifications,
                          ),
                          _SettingsTile(
                            icon: Icons.notifications_outlined,
                            title:
                                context.l10n.settingsTilePushNotificationsTitle,
                            subtitle: context
                                .l10n
                                .settingsTilePushNotificationsSubtitle,
                            trailing: ThemedSwitch(
                              value: settingsService.notificationsEnabled,
                              onChanged: (value) async {
                                HapticFeedback.selectionClick();
                                await settingsService.setNotificationsEnabled(
                                  value,
                                );
                                ref
                                    .read(userProfileProvider.notifier)
                                    .updatePreferences(
                                      UserPreferences(
                                        notificationsEnabled: value,
                                      ),
                                    );
                                safeSetState(() {});
                              },
                            ),
                          ),
                          if (settingsService.notificationsEnabled) ...[
                            _SettingsTile(
                              icon: Icons.person_add_outlined,
                              title: context.l10n.settingsTileNewNodesTitle,
                              subtitle:
                                  context.l10n.settingsTileNewNodesSubtitle,
                              trailing: ThemedSwitch(
                                value:
                                    settingsService.newNodeNotificationsEnabled,
                                onChanged: (value) async {
                                  HapticFeedback.selectionClick();
                                  await settingsService
                                      .setNewNodeNotificationsEnabled(value);
                                  ref
                                      .read(userProfileProvider.notifier)
                                      .updatePreferences(
                                        UserPreferences(
                                          newNodeNotificationsEnabled: value,
                                        ),
                                      );
                                  safeSetState(() {});
                                },
                              ),
                            ),
                            _SettingsTile(
                              icon: Icons.chat_bubble_outline,
                              title:
                                  context.l10n.settingsTileDirectMessagesTitle,
                              subtitle: context
                                  .l10n
                                  .settingsTileDirectMessagesSubtitle,
                              trailing: ThemedSwitch(
                                value: settingsService
                                    .directMessageNotificationsEnabled,
                                onChanged: (value) async {
                                  HapticFeedback.selectionClick();
                                  await settingsService
                                      .setDirectMessageNotificationsEnabled(
                                        value,
                                      );
                                  ref
                                      .read(userProfileProvider.notifier)
                                      .updatePreferences(
                                        UserPreferences(
                                          directMessageNotificationsEnabled:
                                              value,
                                        ),
                                      );
                                  safeSetState(() {});
                                },
                              ),
                            ),
                            _SettingsTile(
                              icon: Icons.forum_outlined,
                              title:
                                  context.l10n.settingsTileChannelMessagesTitle,
                              subtitle: context
                                  .l10n
                                  .settingsTileChannelMessagesSubtitle,
                              trailing: ThemedSwitch(
                                value: settingsService
                                    .channelMessageNotificationsEnabled,
                                onChanged: (value) async {
                                  HapticFeedback.selectionClick();
                                  await settingsService
                                      .setChannelMessageNotificationsEnabled(
                                        value,
                                      );
                                  ref
                                      .read(userProfileProvider.notifier)
                                      .updatePreferences(
                                        UserPreferences(
                                          channelMessageNotificationsEnabled:
                                              value,
                                        ),
                                      );
                                  safeSetState(() {});
                                },
                              ),
                            ),
                            _SettingsTile(
                              icon: Icons.volume_up_outlined,
                              title: context.l10n.settingsTileSoundTitle,
                              subtitle: context.l10n.settingsTileSoundSubtitle,
                              trailing: ThemedSwitch(
                                value: settingsService.notificationSoundEnabled,
                                onChanged: (value) async {
                                  HapticFeedback.selectionClick();
                                  await settingsService
                                      .setNotificationSoundEnabled(value);
                                  ref
                                      .read(userProfileProvider.notifier)
                                      .updatePreferences(
                                        UserPreferences(
                                          notificationSoundEnabled: value,
                                        ),
                                      );
                                  safeSetState(() {});
                                },
                              ),
                            ),
                            _SettingsTile(
                              icon: Icons.vibration,
                              title: context.l10n.settingsTileVibrationTitle,
                              subtitle:
                                  context.l10n.settingsTileVibrationSubtitle,
                              trailing: ThemedSwitch(
                                value: settingsService
                                    .notificationVibrationEnabled,
                                onChanged: (value) async {
                                  HapticFeedback.selectionClick();
                                  await settingsService
                                      .setNotificationVibrationEnabled(value);
                                  ref
                                      .read(userProfileProvider.notifier)
                                      .updatePreferences(
                                        UserPreferences(
                                          notificationVibrationEnabled: value,
                                        ),
                                      );
                                  safeSetState(() {});
                                },
                              ),
                            ),
                          ],

                          const SizedBox(height: AppTheme.spacing16),

                          // Messaging Section
                          _SectionHeader(
                            title: context.l10n.settingsSectionMessaging,
                          ),
                          _SettingsTile(
                            icon: Icons.bolt,
                            title: context.l10n.settingsTileQuickResponsesTitle,
                            subtitle:
                                context.l10n.settingsTileQuickResponsesSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CannedResponsesScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.message,
                            title: context.l10n.settingsTileCannedMessagesTitle,
                            subtitle:
                                context.l10n.settingsTileCannedMessagesSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const CannedMessageModuleConfigScreen(),
                              ),
                            ),
                          ),

                          const SizedBox(height: AppTheme.spacing16),

                          // Data Section
                          _SectionHeader(
                            title: context.l10n.settingsSectionDataStorage,
                          ),
                          _SettingsTile(
                            icon: Icons.history,
                            title: context.l10n.settingsTileMessageHistoryTitle,
                            subtitle: context.l10n
                                .settingsTileMessageHistorySubtitle(
                                  settingsService.messageHistoryLimit,
                                ),
                            onTap: () => _showHistoryLimitDialog(
                              context,
                              settingsService,
                            ),
                          ),
                          // Message Export
                          _SettingsTile(
                            icon: Icons.download,
                            title: context.l10n.settingsTileExportMessagesTitle,
                            subtitle:
                                context.l10n.settingsTileExportMessagesSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DataExportScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.delete_sweep_outlined,
                            title: context
                                .l10n
                                .settingsTileClearMessageHistoryTitle,
                            subtitle: context
                                .l10n
                                .settingsTileClearMessageHistorySubtitle,
                            onTap: () => _confirmClearMessages(context, ref),
                          ),
                          _SettingsTile(
                            icon: Icons.refresh,
                            iconColor: AccentColors.orange,
                            title: context.l10n.settingsTileResetLocalDataTitle,
                            titleColor: AccentColors.orange,
                            subtitle:
                                context.l10n.settingsTileResetLocalDataSubtitle,
                            onTap: () => _confirmResetLocalData(context, ref),
                          ),
                          _SettingsTile(
                            icon: Icons.delete_forever,
                            iconColor: AppTheme.errorRed,
                            title: context.l10n.settingsTileClearAllDataTitle,
                            titleColor: AppTheme.errorRed,
                            subtitle:
                                context.l10n.settingsTileClearAllDataSubtitle,
                            onTap: () => _confirmClearData(context, ref),
                          ),

                          const SizedBox(height: AppTheme.spacing16),

                          // Remote Admin Selector
                          _buildRemoteAdminSelector(context, ref),

                          // Device Section
                          _SectionHeader(
                            title: context.l10n.settingsSectionDevice,
                          ),
                          _SettingsTile(
                            icon: Icons.sync,
                            title: context.l10n.settingsTileForceSyncTitle,
                            subtitle:
                                context.l10n.settingsTileForceSyncSubtitle,
                            onTap: () => _forceSync(context, ref),
                          ),
                          _SettingsTile(
                            icon:
                                regionAsync.whenOrNull(
                                      data: (r) =>
                                          r ==
                                          config_pbenum
                                              .Config_LoRaConfig_RegionCode
                                              .UNSET,
                                    ) ==
                                    true
                                ? Icons.warning_amber_rounded
                                : Icons.language,
                            iconColor:
                                regionAsync.whenOrNull(
                                      data: (r) =>
                                          r ==
                                          config_pbenum
                                              .Config_LoRaConfig_RegionCode
                                              .UNSET,
                                    ) ==
                                    true
                                ? AccentColors.orange
                                : null,
                            title: context.l10n.settingsTileRegionTitle,
                            subtitle: regionSubtitle,
                            subtitleColor:
                                regionAsync.whenOrNull(
                                      data: (r) =>
                                          r ==
                                          config_pbenum
                                              .Config_LoRaConfig_RegionCode
                                              .UNSET,
                                    ) ==
                                    true
                                ? AccentColors.orange
                                : null,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegionSelectionScreen(
                                  isInitialSetup: false,
                                ),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.settings,
                            title: context.l10n.settingsTileDeviceRoleTitle,
                            subtitle:
                                context.l10n.settingsTileDeviceRoleSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DeviceConfigScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.radio,
                            title: context.l10n.settingsTileRadioConfigTitle,
                            subtitle:
                                context.l10n.settingsTileRadioConfigSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RadioConfigScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.gps_fixed,
                            title: context.l10n.settingsTilePositionTitle,
                            subtitle: context.l10n.settingsTilePositionSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PositionConfigScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.display_settings,
                            title:
                                context.l10n.settingsTileDisplaySettingsTitle,
                            subtitle: context
                                .l10n
                                .settingsTileDisplaySettingsSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DisplayConfigScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.bluetooth,
                            title: context.l10n.settingsTileBluetoothTitle,
                            subtitle:
                                context.l10n.settingsTileBluetoothSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BluetoothConfigScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.wifi,
                            title: context.l10n.settingsTileNetworkTitle,
                            subtitle: context.l10n.settingsTileNetworkSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NetworkConfigScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.battery_full,
                            title:
                                context.l10n.settingsTilePowerManagementTitle,
                            subtitle: context
                                .l10n
                                .settingsTilePowerManagementSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PowerConfigScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.security,
                            title: context.l10n.settingsTileSecurityTitle,
                            subtitle: context.l10n.settingsTileSecuritySubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SecurityConfigScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.power_settings_new,
                            title:
                                context.l10n.settingsTileDeviceManagementTitle,
                            subtitle: context
                                .l10n
                                .settingsTileDeviceManagementSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DeviceManagementScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.info_outline,
                            title: context.l10n.settingsTileDeviceInfoTitle,
                            subtitle:
                                context.l10n.settingsTileDeviceInfoSubtitle,
                            onTap: () => _showDeviceInfo(context, ref),
                          ),
                          _SettingsTile(
                            icon: Icons.qr_code_scanner,
                            title: context.l10n.settingsTileScanQrCodeTitle,
                            subtitle:
                                context.l10n.settingsTileScanQrCodeSubtitle,
                            onTap: () =>
                                Navigator.pushNamed(context, '/qr-scanner'),
                          ),

                          const SizedBox(height: AppTheme.spacing16),

                          // Modules Section
                          _SectionHeader(
                            title: context.l10n.settingsSectionModules,
                          ),
                          _SettingsTile(
                            icon: Icons.cloud,
                            title: context.l10n.settingsTileMqttTitle,
                            subtitle: context.l10n.settingsTileMqttSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MqttConfigScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.radar,
                            title: context.l10n.settingsTileRangeTestTitle,
                            subtitle:
                                context.l10n.settingsTileRangeTestSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RangeTestScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.storage,
                            title: context.l10n.settingsTileStoreForwardTitle,
                            subtitle:
                                context.l10n.settingsTileStoreForwardSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const StoreForwardConfigScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.sensors,
                            title:
                                context.l10n.settingsTileDetectionSensorTitle,
                            subtitle: context
                                .l10n
                                .settingsTileDetectionSensorSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const DetectionSensorConfigScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.notifications_active,
                            title: context
                                .l10n
                                .settingsTileExternalNotificationTitle,
                            subtitle: context
                                .l10n
                                .settingsTileExternalNotificationSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const ExternalNotificationConfigScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.lightbulb_outline,
                            title:
                                context.l10n.settingsTileAmbientLightingTitle,
                            subtitle: context
                                .l10n
                                .settingsTileAmbientLightingSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const AmbientLightingConfigScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.people_outline,
                            title: context.l10n.settingsTilePaxCounterTitle,
                            subtitle:
                                context.l10n.settingsTilePaxCounterSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PaxCounterConfigScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.analytics_outlined,
                            title: context
                                .l10n
                                .settingsTileTelemetryIntervalsTitle,
                            subtitle: context
                                .l10n
                                .settingsTileTelemetryIntervalsSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TelemetryConfigScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.usb_rounded,
                            title: context.l10n.settingsTileSerialTitle,
                            subtitle: context.l10n.settingsTileSerialSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SerialConfigScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.traffic,
                            title:
                                context.l10n.settingsTileTrafficManagementTitle,
                            subtitle: context
                                .l10n
                                .settingsTileTrafficManagementSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const TrafficManagementConfigScreen(),
                              ),
                            ),
                          ),

                          const SizedBox(height: AppTheme.spacing16),

                          // Telemetry Section
                          _SectionHeader(
                            title: context.l10n.settingsSectionTelemetryLogs,
                          ),
                          _SettingsTile(
                            icon: Icons.battery_charging_full,
                            title: context.l10n.settingsTileDeviceMetricsTitle,
                            subtitle:
                                context.l10n.settingsTileDeviceMetricsSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DeviceMetricsLogScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.thermostat,
                            title: context
                                .l10n
                                .settingsTileEnvironmentMetricsTitle,
                            subtitle: context
                                .l10n
                                .settingsTileEnvironmentMetricsSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const EnvironmentMetricsLogScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.air,
                            title: context.l10n.settingsTileAirQualityTitle,
                            subtitle:
                                context.l10n.settingsTileAirQualitySubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AirQualityLogScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.location_on_outlined,
                            title:
                                context.l10n.settingsTilePositionHistoryTitle,
                            subtitle: context
                                .l10n
                                .settingsTilePositionHistorySubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PositionLogScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.timeline,
                            title:
                                context.l10n.settingsTileTracerouteHistoryTitle,
                            subtitle: context
                                .l10n
                                .settingsTileTracerouteHistorySubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TraceRouteLogScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.people_alt_outlined,
                            title: context.l10n.settingsTilePaxCounterLogsTitle,
                            subtitle:
                                context.l10n.settingsTilePaxCounterLogsSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PaxCounterLogScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.sensors,
                            title: context
                                .l10n
                                .settingsTileDetectionSensorLogsTitle,
                            subtitle: context
                                .l10n
                                .settingsTileDetectionSensorLogsSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const DetectionSensorLogScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.route,
                            title: context.l10n.settingsTileRoutesTitle,
                            subtitle: context.l10n.settingsTileRoutesSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RoutesScreen(),
                              ),
                            ),
                          ),

                          const SizedBox(height: AppTheme.spacing16),

                          // Tools Section
                          _SectionHeader(
                            title: context.l10n.settingsSectionTools,
                          ),
                          _SettingsTile(
                            icon: Icons.gps_fixed,
                            title: context.l10n.settingsTileGpsStatusTitle,
                            subtitle:
                                context.l10n.settingsTileGpsStatusSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const GpsStatusScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.system_update,
                            title: context.l10n.settingsTileFirmwareUpdateTitle,
                            subtitle:
                                context.l10n.settingsTileFirmwareUpdateSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FirmwareUpdateScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.ios_share,
                            title: context.l10n.settingsTileExportDataTitle,
                            subtitle:
                                context.l10n.settingsTileExportDataSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DataExportScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.article_outlined,
                            title: context.l10n.settingsTileAppLogTitle,
                            subtitle: context.l10n.settingsTileAppLogSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AppLogScreen(),
                              ),
                            ),
                          ),
                          // Glyph Matrix Test - only show on Nothing Phone 3
                          Consumer(
                            builder: (context, ref, child) {
                              final glyphService = ref.watch(
                                glyphServiceProvider,
                              );
                              // Only show on Nothing Phone 3
                              if (!glyphService.deviceModel.contains(
                                'Phone (3)', // lint-allow: hardcoded-string
                              )) {
                                return const SizedBox.shrink();
                              }
                              return _SettingsTile(
                                icon: Icons.lightbulb,
                                title: context.l10n.settingsGlyphMatrixTest,
                                subtitle: context
                                    .l10n
                                    .settingsGlyphMatrixTestSubtitle,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const GlyphTestScreen(),
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: AppTheme.spacing16),

                          // About Section
                          _SectionHeader(
                            title: context.l10n.settingsSectionAbout,
                          ),
                          Consumer(
                            builder: (context, ref, child) {
                              final appVersion = ref.watch(appVersionProvider);
                              final versionString = appVersion.maybeWhen(
                                data: (v) =>
                                    context.l10n.settingsVersionString(v),
                                orElse: () => null,
                              );
                              return _SettingsTile(
                                icon: Icons.info,
                                title: context.l10n.settingsTileSocialmeshTitle,
                                subtitle: versionString,
                              );
                            },
                          ),
                          _SettingsTile(
                            icon: Icons.help,
                            title: context.l10n.settingsTileHelpCenterTitle,
                            subtitle:
                                context.l10n.settingsTileHelpCenterSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HelpCenterScreen(),
                              ),
                            ),
                          ),
                          _SettingsTile(
                            icon: Icons.help_outline,
                            title: context.l10n.settingsTileHelpSupportTitle,
                            subtitle:
                                context.l10n.settingsTileHelpSupportSubtitle,
                            onTap: () =>
                                LegalDocumentSheet.showSupport(context),
                          ),
                          _SettingsTile(
                            icon: Icons.description_outlined,
                            title: context.l10n.settingsTileTermsOfServiceTitle,
                            onTap: () => LegalDocumentSheet.showTerms(context),
                          ),
                          _SettingsTile(
                            icon: Icons.privacy_tip_outlined,
                            title: context.l10n.settingsTilePrivacyPolicyTitle,
                            onTap: () =>
                                LegalDocumentSheet.showPrivacy(context),
                          ),
                          _SettingsTile(
                            icon: Icons.source_outlined,
                            title: context.l10n.settingsTileOpenSourceTitle,
                            subtitle:
                                context.l10n.settingsTileOpenSourceSubtitle,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const _OpenSourceLicensesScreen(),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing24),

                          // Meshtastic Powered footer
                          _MeshtasticPoweredFooter(),

                          const SizedBox(height: AppTheme.spacing32),
                        ]),
                      ),
                    ),
                  ];
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showHapticIntensityPicker(
    BuildContext context,
    WidgetRef ref,
    SettingsService settingsService,
  ) {
    final currentIntensity = HapticIntensity.fromValue(
      settingsService.hapticIntensity,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(AppTheme.spacing16),
              child: Text(
                context.l10n.settingsHapticIntensityTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
            ),
            ...HapticIntensity.values.map((intensity) {
              final isSelected = intensity == currentIntensity;
              return ListTile(
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelected
                      ? context.accentColor
                      : context.textTertiary,
                ),
                title: Text(
                  intensity.label,
                  style: TextStyle(
                    color: isSelected
                        ? context.textPrimary
                        : context.textSecondary,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  _hapticIntensityDescription(intensity),
                  style: TextStyle(color: context.textTertiary, fontSize: 12),
                ),
                onTap: () async {
                  await settingsService.setHapticIntensity(intensity.value);
                  ref
                      .read(userProfileProvider.notifier)
                      .updatePreferences(
                        UserPreferences(hapticIntensity: intensity.value),
                      );
                  ref.haptics.toggle();
                  safeSetState(() {});
                  if (context.mounted) Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: AppTheme.spacing16),
          ],
        ),
      ),
    );
  }

  String _hapticIntensityDescription(HapticIntensity intensity) {
    switch (intensity) {
      case HapticIntensity.light:
        return context.l10n.settingsHapticSubtleDescription;
      case HapticIntensity.medium:
        return context.l10n.settingsHapticMediumDescription;
      case HapticIntensity.heavy:
        return context.l10n.settingsHapticStrongDescription;
    }
  }

  void _showHistoryLimitDialog(
    BuildContext context,
    SettingsService settingsService,
  ) {
    final limits = [50, 100, 200, 500, 1000];

    AppBottomSheet.showPicker<int>(
      context: context,
      title: context.l10n.settingsHistoryLimitTitle,
      items: limits,
      selectedItem: settingsService.messageHistoryLimit,
      itemBuilder: (limit, isSelected) => ListTile(
        leading: Icon(
          isSelected
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
          color: isSelected ? context.accentColor : context.textTertiary,
        ),
        title: Text(
          context.l10n.settingsHistoryLimitOption(limit),
          style: TextStyle(
            color: context.textPrimary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
      ),
    ).then((selectedLimit) {
      if (selectedLimit != null) {
        settingsService.setMessageHistoryLimit(selectedLimit);
      }
    });
  }

  Future<void> _confirmClearMessages(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // Capture provider ref before await
    final messagesNotifier = ref.read(messagesProvider.notifier);
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.settingsClearMessagesTitle,
      message: context.l10n.settingsClearMessagesMessage,
      confirmLabel: context.l10n.settingsClearMessagesLabel,
      isDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      messagesNotifier.clearMessages();
      showSuccessSnackBar(context, context.l10n.settingsClearMessagesSuccess);
    }
  }

  Future<void> _confirmResetLocalData(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // Capture provider refs before await
    final messagesNotifier = ref.read(messagesProvider.notifier);
    final nodesNotifier = ref.read(nodesProvider.notifier);
    final channelsNotifier = ref.read(channelsProvider.notifier);
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.settingsResetLocalDataTitle,
      message: context.l10n.settingsResetLocalDataMessage,
      confirmLabel: context.l10n.settingsResetLocalDataLabel,
      isDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      // Clear messages
      messagesNotifier.clearMessages();

      // Clear nodes
      nodesNotifier.clearNodes();

      // Clear channels (will be re-synced from device)
      channelsNotifier.clearChannels();

      // Clear message storage
      final messageStorage = await ref.read(messageStorageProvider.future);
      await messageStorage.clearMessages();

      // Clear node storage
      final nodeStorage = await ref.read(nodeStorageProvider.future);
      await nodeStorage.clearNodes();

      if (context.mounted) {
        showSuccessSnackBar(
          context,
          context.l10n.settingsResetLocalDataSuccess,
        );
      }
    }
  }

  Future<void> _forceSync(BuildContext context, WidgetRef ref) async {
    // Capture provider refs before awaits
    final protocol = ref.read(protocolServiceProvider);
    final transport = ref.read(transportProvider);
    final messagesNotifier = ref.read(messagesProvider.notifier);
    final nodesNotifier = ref.read(nodesProvider.notifier);
    final channelsNotifier = ref.read(channelsProvider.notifier);
    final connectedDevice = ref.read(connectedDeviceProvider);

    if (transport.state != DeviceConnectionState.connected) {
      showErrorSnackBar(context, context.l10n.settingsForceSyncNotConnected);
      return;
    }

    // Show confirmation dialog
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.settingsForceSyncTitle,
      message: context.l10n.settingsForceSyncMessage,
      confirmLabel: context.l10n.settingsForceSyncLabel,
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    // Show loading indicator
    AppBottomSheet.show(
      context: context,
      isDismissible: false,
      child: Row(
        children: [
          LoadingIndicator(size: 40),
          const SizedBox(width: AppTheme.spacing20),
          Text(
            context.l10n.settingsForceSyncingStatus,
            style: TextStyle(color: context.textPrimary),
          ),
        ],
      ),
    );

    try {
      // Clear local state first
      messagesNotifier.clearMessages();
      nodesNotifier.clearNodes();
      channelsNotifier.clearChannels();

      // Get device info for hardware model inference
      if (connectedDevice != null) {
        protocol.setDeviceName(connectedDevice.name);
        protocol.setBleModelNumber(transport.bleModelNumber);
        protocol.setBleManufacturerName(transport.bleManufacturerName);
      }

      // Restart protocol to re-request config from device
      await protocol.start();

      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss loading
        showSuccessSnackBar(context, context.l10n.settingsForceSyncSuccess);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss loading
        showErrorSnackBar(
          context,
          context.l10n.settingsForceSyncFailed(e.toString()),
        );
      }
    }
  }

  Future<void> _confirmClearData(BuildContext context, WidgetRef ref) async {
    // Capture provider refs before await
    final secureStorage = ref.read(secureStorageProvider);
    final settingsServiceAsync = ref.read(settingsServiceProvider);
    final messagesNotifier = ref.read(messagesProvider.notifier);
    final nodesNotifier = ref.read(nodesProvider.notifier);
    final channelsNotifier = ref.read(channelsProvider.notifier);
    final hiddenSignalsNotifier = ref.read(hiddenSignalsProvider.notifier);
    final automationsNotifier = ref.read(automationsProvider.notifier);
    final automations = ref.read(automationsProvider).value ?? [];
    final signalService = ref.read(signalServiceProvider);
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.settingsClearAllDataTitle,
      message: context.l10n.settingsClearAllDataMessage,
      confirmLabel: context.l10n.settingsClearAllDataLabel,
      isDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      try {
        // Secure storage (channel keys, device info)
        await secureStorage.clearAll();

        // Settings service
        settingsServiceAsync.whenData((settingsService) {
          settingsService.clearAll();
        });

        // Messages, nodes, channels
        messagesNotifier.clearMessages();
        nodesNotifier.clearNodes();
        channelsNotifier.clearChannels();

        // Hidden signals (local only)
        await hiddenSignalsNotifier.clearAll();

        // Automations - delete all one by one
        try {
          for (final automation in automations) {
            await automationsNotifier.deleteAutomation(automation.id);
          }
        } catch (e) {
          AppLogging.app('Failed to clear automations: $e');
        }

        // SharedPreferences (all other cached data including hidden signals, bookmarks)
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        // Signal database - close and delete
        try {
          await signalService.close();
          // Database will be recreated on next use
        } catch (e) {
          AppLogging.app('Failed to close signal database: $e');
        }

        if (context.mounted) {
          showSuccessSnackBar(
            context,
            context.l10n.settingsClearAllDataSuccess,
          );
        }
      } catch (e) {
        AppLogging.app('Error clearing data: $e');
        if (context.mounted) {
          showErrorSnackBar(
            context,
            context.l10n.settingsClearAllDataFailed(e.toString()),
          );
        }
      }
    }
  }

  void _showDeviceInfo(BuildContext context, WidgetRef ref) {
    final connectedDevice = ref.read(connectedDeviceProvider);
    final myNodeNum = ref.read(myNodeNumProvider);
    final nodes = ref.read(nodesProvider);
    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;

    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.settingsDeviceInfoTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),
          InfoTable(
            rows: [
              InfoTableRow(
                label: context.l10n.settingsDeviceInfoDeviceName,
                value:
                    connectedDevice?.name ??
                    context.l10n.settingsDeviceInfoNotConnected,
                icon: Icons.bluetooth,
              ),
              InfoTableRow(
                label: context.l10n.settingsDeviceInfoConnection,
                value:
                    connectedDevice?.type.name.toUpperCase() ??
                    context.l10n.settingsDeviceInfoNone,
                icon: Icons.wifi,
              ),
              InfoTableRow(
                label: context.l10n.settingsDeviceInfoNodeNumber,
                value:
                    myNodeNum?.toString() ??
                    context.l10n.settingsDeviceInfoUnknown,
                icon: Icons.tag,
              ),
              InfoTableRow(
                label: context.l10n.settingsDeviceInfoLongName,
                value:
                    myNode?.longName ?? context.l10n.settingsDeviceInfoUnknown,
                icon: Icons.badge_outlined,
              ),
              InfoTableRow(
                label: context.l10n.settingsDeviceInfoShortName,
                value:
                    myNode?.shortName ?? context.l10n.settingsDeviceInfoUnknown,
                icon: Icons.short_text,
              ),
              InfoTableRow(
                label: context.l10n.settingsDeviceInfoHardware,
                value:
                    myNode?.hardwareModel ??
                    context.l10n.settingsDeviceInfoUnknown,
                icon: Icons.memory_outlined,
              ),
              InfoTableRow(
                label: context.l10n.settingsDeviceInfoUserId,
                value: myNode?.userId ?? context.l10n.settingsDeviceInfoUnknown,
                icon: Icons.fingerprint,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing16),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: context.textTertiary,

          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final Color? subtitleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    this.iconColor,
    required this.title,
    this.titleColor,
    this.subtitle,
    this.subtitleColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: iconColor ?? context.textSecondary),
                const SizedBox(width: AppTheme.spacing16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: titleColor ?? context.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppTheme.spacing2),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: subtitleColor ?? context.textTertiary,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (onTap != null)
                  Icon(Icons.chevron_right, color: context.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Premium feature tile with owned/locked badge
class _PremiumFeatureTile extends ConsumerWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final PremiumFeature feature;
  final VoidCallback? onTap;

  const _PremiumFeatureTile({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.feature,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchaseState = ref.watch(purchaseStateProvider);
    final hasFeature = purchaseState.hasFeature(feature);
    // Use per-feature gate instead of global upsellEnabled
    final upsellEnabled = ref.watch(premiumFeatureGateProvider(feature.name));
    final accentColor = context.accentColor;
    final purchase = OneTimePurchases.getByFeature(feature);

    // Use live store price (localized) when available, fall back to hardcoded
    final storeProductsAsync = ref.watch(storeProductsProvider);
    final storeProducts = storeProductsAsync.when(
      data: (data) => data,
      loading: () => <String, StoreProductInfo>{},
      error: (e, s) => <String, StoreProductInfo>{},
    );
    final storeProduct = purchase != null
        ? storeProducts[purchase.productId]
        : null;
    final priceLabel =
        storeProduct?.priceString ??
        (purchase != null
            ? '\$${purchase.price.toStringAsFixed(2)}'
            : null); // lint-allow: hardcoded-string

    // When upsell is enabled, non-owned features should look explorable (not locked)
    final isExplorable = hasFeature || upsellEnabled;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isExplorable
                      ? (iconColor ?? accentColor)
                      : context.textTertiary,
                ),
                SizedBox(width: AppTheme.spacing16),
                Expanded(
                  child: Text(
                    title,
                    style: context.bodySecondaryStyle!.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isExplorable
                          ? context.textPrimary
                          : context.textSecondary,
                    ),
                  ),
                ),
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: hasFeature
                        ? accentColor.withValues(alpha: 0.2)
                        : upsellEnabled
                        ? AppTheme.warningYellow.withValues(alpha: 0.2)
                        : context.textTertiary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!hasFeature && !upsellEnabled) ...[
                        // Show locked badge when upsell is disabled (not owned)
                        Icon(Icons.lock, size: 12, color: context.textTertiary),
                        SizedBox(width: AppTheme.spacing4),
                        Text(
                          priceLabel ?? context.l10n.settingsPremiumBadgeLocked,
                          style: context.captionStyle!.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.textTertiary,
                          ),
                        ),
                      ] else if (!hasFeature && upsellEnabled) ...[
                        // Show "TRY IT" badge when upsell is enabled but not owned
                        Icon(
                          Icons.star,
                          size: 12,
                          color: AppTheme.warningYellow,
                        ),
                        SizedBox(width: AppTheme.spacing4),
                        Text(
                          context.l10n.settingsPremiumBadgeTry,
                          style: context.captionStyle!.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.warningYellow,
                          ),
                        ),
                      ] else ...[
                        // Show OWNED badge when user has the feature
                        Text(
                          context.l10n.settingsPremiumBadgeOwned,
                          style: context.captionStyle!.copyWith(
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: AppTheme.spacing8),
                Icon(
                  Icons.chevron_right,
                  color: isExplorable ? accentColor : context.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Profile tile showing user profile info
class _ProfileTile extends ConsumerWidget {
  final VoidCallback? onTap;

  const _ProfileTile({this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final authState = ref.watch(authStateProvider);
    final isSignedIn = authState.value != null;
    final accentColor = context.accentColor;

    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return _SettingsTile(
            icon: Icons.person_outline,
            title: context.l10n.settingsProfileTitle,
            subtitle: context.l10n.settingsProfileSubtitle,
            onTap: onTap,
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            border: Border.all(color: context.border.withValues(alpha: 0.3)),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing12),
                child: Row(
                  children: [
                    // Avatar
                    UserAvatar(
                      imageUrl: profile.avatarUrl,
                      initials: profile.initials,
                      size: 48,
                      borderWidth: 2,
                      borderColor: accentColor.withValues(alpha: 0.5),
                      foregroundColor: accentColor,
                      backgroundColor: context.surface,
                    ),
                    SizedBox(width: AppTheme.spacing12),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  profile.displayName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: context.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (profile.callsign != null) ...[
                                const SizedBox(width: AppTheme.spacing8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radius8,
                                    ),
                                  ),
                                  child: Text(
                                    profile.callsign!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: accentColor,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacing4),
                          Row(
                            children: [
                              Icon(
                                isSignedIn ? Icons.cloud_done : Icons.cloud_off,
                                size: 12,
                                color: isSignedIn
                                    ? AccentColors.green
                                    : context.textTertiary,
                              ),
                              SizedBox(width: AppTheme.spacing4),
                              Text(
                                isSignedIn
                                    ? context.l10n.settingsProfileSynced
                                    : context.l10n.settingsProfileLocalOnly,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textSecondary,
                                ),
                              ),
                              if (profile.bio != null &&
                                  profile.bio!.isNotEmpty) ...[
                                Text(
                                  ' • ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.textTertiary,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    profile.bio!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.textTertiary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: context.textTertiary),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => _SettingsTile(
        icon: Icons.person_outline,
        title: context.l10n.settingsProfileTitle,
        subtitle: context.l10n.settingsLoadingStatus,
        onTap: onTap,
      ),
      error: (error, stackTrace) => _SettingsTile(
        icon: Icons.person_outline,
        title: context.l10n.settingsProfileTitle,
        subtitle: context.l10n.settingsProfileSubtitle,
        onTap: onTap,
      ),
    );
  }
}

/// Meshtastic Powered footer with link to meshtastic.org
class _MeshtasticPoweredFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: InkWell(
          onTap: () => _openMeshtasticWebsite(context),
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Opacity(
              opacity: 0.7,
              child: Image.asset(
                'assets/meshtastic_powered_landscape.png',
                width: 180,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openMeshtasticWebsite(BuildContext context) {
    HapticFeedback.lightImpact();
    MeshtasticWebViewScreen.show(context);
  }
}

/// Tappable Meshtastic Powered logo that opens meshtastic.org
class _TappableMeshtasticLogo extends StatelessWidget {
  final double width;

  const _TappableMeshtasticLogo({this.width = 140});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        MeshtasticWebViewScreen.show(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Image.asset(
          'assets/meshtastic_powered_landscape.png',
          width: width,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// In-app webview for meshtastic.org
class MeshtasticWebViewScreen extends StatefulWidget {
  const MeshtasticWebViewScreen._();

  /// Show the Meshtastic website in an in-app browser
  static void show(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MeshtasticWebViewScreen._()),
    );
  }

  @override
  State<MeshtasticWebViewScreen> createState() =>
      _MeshtasticWebViewScreenState();
}

class _MeshtasticWebViewScreenState extends State<MeshtasticWebViewScreen>
    with StatefulLifecycleSafeMixin<MeshtasticWebViewScreen> {
  double _progress = 0;
  String _title = '';
  InAppWebViewController? _webViewController;
  bool _canGoBack = false;
  bool _hasLoadError = false;
  String _errorDescription = '';

  static const _initialUrl = 'https://meshtastic.org';

  void _retry() {
    safeSetState(() {
      _hasLoadError = false;
      _errorDescription = '';
      _progress = 0;
    });
    _webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(_initialUrl)),
    );
  }

  Widget _buildOfflinePlaceholder(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 48,
              color: accentColor.withValues(alpha: 0.7),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              context.l10n.settingsMeshtasticUnableToLoad,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              context.l10n.settingsMeshtasticOfflineMessage,
              style: TextStyle(color: context.textTertiary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (_errorDescription.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacing8),
              Text(
                _errorDescription,
                style: TextStyle(color: context.textTertiary, fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppTheme.spacing24),
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(context.l10n.commonRetry),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        title: Text(
          _title.isEmpty ? context.l10n.settingsMeshtasticWebViewTitle : _title,
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_canGoBack)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _webViewController?.goBack(),
              tooltip: context.l10n.settingsMeshtasticGoBack,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _hasLoadError
                ? _retry
                : () => _webViewController?.reload(),
            tooltip: context.l10n.settingsMeshtasticRefresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator (only when loading and no error)
          if (_progress < 1.0 && !_hasLoadError)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: context.card,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              minHeight: 2,
            ),
          // Content: either the WebView or the offline placeholder
          Expanded(
            child: _hasLoadError
                ? _buildOfflinePlaceholder(context)
                : InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(_initialUrl)),
                    initialSettings: InAppWebViewSettings(
                      transparentBackground: true,
                      javaScriptEnabled: true,
                      useShouldOverrideUrlLoading: false,
                      mediaPlaybackRequiresUserGesture: false,
                      allowsInlineMediaPlayback: true,
                      iframeAllowFullscreen: true,
                    ),
                    onWebViewCreated: (controller) {
                      _webViewController = controller;
                    },
                    onLoadStart: (controller, url) {
                      if (mounted) {
                        safeSetState(() {
                          _progress = 0;
                          _hasLoadError = false;
                          _errorDescription = '';
                        });
                      }
                    },
                    onProgressChanged: (controller, progress) {
                      safeSetState(() => _progress = progress / 100);
                    },
                    onLoadStop: (controller, url) async {
                      safeSetState(() => _progress = 1.0);
                      final canGoBack = await controller.canGoBack();
                      safeSetState(() => _canGoBack = canGoBack);
                    },
                    onTitleChanged: (controller, title) {
                      if (title != null && title.isNotEmpty) {
                        safeSetState(() => _title = title);
                      }
                    },
                    onReceivedError: (controller, request, error) {
                      AppLogging.settings(
                        'MeshtasticWebView error: type=${error.type}, '
                        'description=${error.description}, '
                        'url=${request.url}',
                      );

                      final isMainFrame = request.url.toString() == _initialUrl;

                      final isConnectivityError =
                          error.type == WebResourceErrorType.HOST_LOOKUP ||
                          error.type ==
                              WebResourceErrorType.CANNOT_CONNECT_TO_HOST ||
                          error.type ==
                              WebResourceErrorType.NOT_CONNECTED_TO_INTERNET ||
                          error.type == WebResourceErrorType.TIMEOUT ||
                          error.type ==
                              WebResourceErrorType.NETWORK_CONNECTION_LOST;

                      if (isMainFrame || isConnectivityError) {
                        if (mounted) {
                          safeSetState(() {
                            _hasLoadError = true;
                            _errorDescription = error.description;
                          });
                        }
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Custom themed Open Source Licenses screen
class _OpenSourceLicensesScreen extends ConsumerWidget {
  const _OpenSourceLicensesScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accentColor = Theme.of(context).colorScheme.primary;
    final appVersion = ref.watch(appVersionProvider);
    final versionString = appVersion.when(
      data: (v) => v,
      loading: () => '',
      error: (_, _) => '',
    );

    return Theme(
      // Apply dark theme to the license page
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: context.background,
        appBarTheme: AppBarTheme(
          backgroundColor: context.background,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardColor: context.card,
        listTileTheme: ListTileThemeData(
          textColor: Colors.white,
          iconColor: accentColor,
        ),
      ),
      child: LicensePage(
        applicationName: context.l10n.settingsOpenSourceAppName,
        applicationVersion: versionString,
        applicationIcon: const _TappableMeshtasticLogo(width: 140),
        applicationLegalese: context.l10n.settingsOpenSourceLegalese,
      ),
    );
  }
}

/// Social notifications settings section (for signed-in users only)
class _SocialNotificationsSection extends ConsumerStatefulWidget {
  const _SocialNotificationsSection();

  @override
  ConsumerState<_SocialNotificationsSection> createState() =>
      _SocialNotificationsSectionState();
}

class _SocialNotificationsSectionState
    extends ConsumerState<_SocialNotificationsSection>
    with LifecycleSafeMixin<_SocialNotificationsSection> {
  bool _isLoading = true;
  bool _followsEnabled = true;
  bool _likesEnabled = true;
  bool _commentsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await PushNotificationService()
          .getNotificationSettings();
      if (!mounted) return;
      safeSetState(() {
        _followsEnabled = settings['follows'] ?? true;
        _likesEnabled = settings['likes'] ?? true;
        _commentsEnabled = settings['comments'] ?? true;
        _isLoading = false;
      });
    } catch (e) {
      safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String type, bool value) async {
    HapticFeedback.selectionClick();

    safeSetState(() {
      switch (type) {
        case 'follows':
          _followsEnabled = value;
          break;
        case 'likes':
          _likesEnabled = value;
          break;
        case 'comments':
          _commentsEnabled = value;
          break;
      }
    });

    await PushNotificationService().updateNotificationSettings(
      followNotifications: type == 'follows' ? value : null,
      likeNotifications: type == 'likes' ? value : null,
      commentNotifications: type == 'comments' ? value : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    // Only show for signed-in users
    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppTheme.spacing16),
          _SectionHeader(
            title: context.l10n.settingsSectionSocialNotifications,
          ),
          _SettingsTile(
            icon: Icons.notifications_active_outlined,
            title: context.l10n.settingsSocialNotificationsLoading,
            subtitle: context.l10n.settingsSocialNotificationsLoadingSubtitle,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppTheme.spacing16),
        _SectionHeader(title: context.l10n.settingsSectionSocialNotifications),
        _SettingsTile(
          icon: Icons.person_add_outlined,
          title: context.l10n.settingsSocialNewFollowersTitle,
          subtitle: context.l10n.settingsSocialNewFollowersSubtitle,
          trailing: ThemedSwitch(
            value: _followsEnabled,
            onChanged: (value) => _updateSetting('follows', value),
          ),
        ),
        _SettingsTile(
          icon: Icons.favorite_outline,
          title: context.l10n.settingsSocialLikesTitle,
          subtitle: context.l10n.settingsSocialLikesSubtitle,
          trailing: ThemedSwitch(
            value: _likesEnabled,
            onChanged: (value) => _updateSetting('likes', value),
          ),
        ),
        _SettingsTile(
          icon: Icons.chat_bubble_outline,
          title: context.l10n.settingsSocialCommentsTitle,
          subtitle: context.l10n.settingsSocialCommentsSubtitle,
          trailing: ThemedSwitch(
            value: _commentsEnabled,
            onChanged: (value) => _updateSetting('comments', value),
          ),
        ),
      ],
    );
  }
}

class _AgeGroupTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref.watch(ageSafetyPolicyProvider);
    final subtitle = switch (policy.ageGroup) {
      AgeGroup.under13 => context.l10n.settingsAgeGroupSubtitleUnder13,
      AgeGroup.teen => context.l10n.settingsAgeGroupSubtitleTeen,
      AgeGroup.adult => context.l10n.settingsAgeGroupSubtitleAdult,
      AgeGroup.unknown => context.l10n.settingsAgeGroupSubtitleUnknown,
    };

    return _SettingsTile(
      icon: Icons.cake_outlined,
      title: context.l10n.settingsAgeGroupTitle,
      subtitle: subtitle,
      trailing: Icon(Icons.chevron_right, color: context.textTertiary),
      onTap: () {
        final notifier = ref.read(ageEligibilityProvider.notifier);
        AppBottomSheet.showPicker<AgeGroup>(
          context: context,
          title: context.l10n.settingsAgeGroupTitle,
          items: const [AgeGroup.teen, AgeGroup.adult],
          selectedItem:
              policy.ageGroup == AgeGroup.unknown ||
                  policy.ageGroup == AgeGroup.under13
              ? null
              : policy.ageGroup,
          itemBuilder: (group, isSelected) {
            final label = switch (group) {
              AgeGroup.teen => context.l10n.legalEligibilityOptionTeen,
              AgeGroup.adult => context.l10n.legalEligibilityOptionAdult,
              AgeGroup.under13 || AgeGroup.unknown => '',
            };
            final groupSubtitle = switch (group) {
              AgeGroup.teen => context.l10n.legalEligibilityOptionTeenSubtitle,
              AgeGroup.adult || AgeGroup.under13 || AgeGroup.unknown => '',
            };
            return ListTile(
              leading: Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected ? context.accentColor : context.textTertiary,
              ),
              title: Text(
                label,
                style: TextStyle(
                  color: context.textPrimary,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              subtitle: groupSubtitle.isNotEmpty
                  ? Text(
                      groupSubtitle,
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 12,
                      ),
                    )
                  : null,
            );
          },
        ).then((selected) {
          if (selected != null) {
            notifier.confirm(ageGroup: selected);
          }
        });
      },
    );
  }
}

/// Model for searchable settings item
class _SearchableSettingItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<String> keywords;
  final String section;
  final VoidCallback? onTap;
  final bool hasSwitch;
  final Widget Function(BuildContext, WidgetRef, SettingsService)?
  switchBuilder;

  const _SearchableSettingItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.keywords = const [],
    required this.section,
    this.onTap,
    this.hasSwitch = false,
    this.switchBuilder,
  });
}

class _PremiumBadge extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;

  const _PremiumBadge({
    required this.text,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radius6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
