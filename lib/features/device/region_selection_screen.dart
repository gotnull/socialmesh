// SPDX-License-Identifier: GPL-3.0-or-later
import '../../core/safety/lifecycle_mixin.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../services/storage/storage_service.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../providers/app_providers.dart';
import '../../providers/connection_providers.dart' as conn;
import '../../generated/meshtastic/config.pbenum.dart';
import '../../utils/permissions.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/status_banner.dart';

/// Typedef for shorter reference to the enum
typedef RegionCode = Config_LoRaConfig_RegionCode;

/// Region data with display info
class RegionInfo {
  final RegionCode code;
  final String name;
  final String frequency;
  final String description;

  const RegionInfo({
    required this.code,
    required this.name,
    required this.frequency,
    required this.description,
  });
}

/// Available regions with their frequency bands
const List<RegionInfo> availableRegions = [
  RegionInfo(
    code: RegionCode.US,
    name: 'United States',
    frequency: '915 MHz',
    description: 'US, Canada, Mexico',
  ),
  RegionInfo(
    code: RegionCode.EU_868,
    name: 'Europe 868',
    frequency: '868 MHz',
    description: 'EU, UK, and most of Europe',
  ),
  RegionInfo(
    code: RegionCode.EU_433,
    name: 'Europe 433',
    frequency: '433 MHz',
    description: 'EU alternate frequency',
  ),
  RegionInfo(
    code: RegionCode.ANZ,
    name: 'Australia/NZ',
    frequency: '915 MHz',
    description: 'Australia and New Zealand',
  ),
  RegionInfo(
    code: RegionCode.CN,
    name: 'China',
    frequency: '470 MHz',
    description: 'China',
  ),
  RegionInfo(
    code: RegionCode.JP,
    name: 'Japan',
    frequency: '920 MHz',
    description: 'Japan',
  ),
  RegionInfo(
    code: RegionCode.KR,
    name: 'Korea',
    frequency: '920 MHz',
    description: 'South Korea',
  ),
  RegionInfo(
    code: RegionCode.TW,
    name: 'Taiwan',
    frequency: '923 MHz',
    description: 'Taiwan',
  ),
  RegionInfo(
    code: RegionCode.RU,
    name: 'Russia',
    frequency: '868 MHz',
    description: 'Russia',
  ),
  RegionInfo(
    code: RegionCode.IN,
    name: 'India',
    frequency: '865 MHz',
    description: 'India',
  ),
  RegionInfo(
    code: RegionCode.NZ_865,
    name: 'New Zealand 865',
    frequency: '865 MHz',
    description: 'New Zealand alternate',
  ),
  RegionInfo(
    code: RegionCode.TH,
    name: 'Thailand',
    frequency: '920 MHz',
    description: 'Thailand',
  ),
  RegionInfo(
    code: RegionCode.UA_433,
    name: 'Ukraine 433',
    frequency: '433 MHz',
    description: 'Ukraine',
  ),
  RegionInfo(
    code: RegionCode.UA_868,
    name: 'Ukraine 868',
    frequency: '868 MHz',
    description: 'Ukraine',
  ),
  RegionInfo(
    code: RegionCode.MY_433,
    name: 'Malaysia 433',
    frequency: '433 MHz',
    description: 'Malaysia',
  ),
  RegionInfo(
    code: RegionCode.MY_919,
    name: 'Malaysia 919',
    frequency: '919 MHz',
    description: 'Malaysia',
  ),
  RegionInfo(
    code: RegionCode.SG_923,
    name: 'Singapore',
    frequency: '923 MHz',
    description: 'Singapore',
  ),
  RegionInfo(
    code: RegionCode.LORA_24,
    name: '2.4 GHz',
    frequency: '2.4 GHz',
    description: 'Worldwide 2.4GHz band',
  ),
];

const regionSelectionApplyButtonKey = Key('region_selection_apply_button');

class RegionSelectionScreen extends ConsumerStatefulWidget {
  final bool isInitialSetup;

  const RegionSelectionScreen({super.key, this.isInitialSetup = false});

  @override
  ConsumerState<RegionSelectionScreen> createState() =>
      _RegionSelectionScreenState();
}

class _RegionSelectionScreenState extends ConsumerState<RegionSelectionScreen>
    with LifecycleSafeMixin<RegionSelectionScreen> {
  RegionCode? _selectedRegion;
  RegionCode? _currentRegion;
  String? _errorMessage;
  String _searchQuery = '';
  bool _initialized = false;
  bool _showPairingInvalidationHint = false;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    // Load current region after build
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrentRegion());
  }

  void _loadCurrentRegion() {
    if (_initialized) return;
    if (!mounted) return;
    final protocol = ref.read(protocolServiceProvider);
    final region = protocol.currentRegion;
    if (region != null && region != RegionCode.UNSET) {
      setState(() {
        _currentRegion = region;
        // Pre-select current region when editing (not initial setup)
        if (!widget.isInitialSetup) {
          _selectedRegion = region;
        }
        _initialized = true;
      });
    }
  }

  List<RegionInfo> get _filteredRegions {
    if (_searchQuery.isEmpty) return availableRegions;
    final query = _searchQuery.toLowerCase();
    return availableRegions.where((r) {
      return r.name.toLowerCase().contains(query) ||
          r.description.toLowerCase().contains(query) ||
          r.frequency.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _saveRegion() async {
    if (_selectedRegion == null) return;
    final regionState = ref.read(regionConfigProvider);
    if (regionState.applyStatus == RegionApplyStatus.applying) return;
    final isInitialSetup = widget.isInitialSetup;

    // Capture ALL references BEFORE any async work to avoid accessing
    // ref/context after disposal
    final settingsAsync = ref.read(settingsServiceProvider);
    if (!settingsAsync.hasValue) return; // Settings not ready
    final settings = settingsAsync.requireValue;
    final navigator = Navigator.of(context);
    final regionNotifier = ref.read(regionConfigProvider.notifier);
    final settingsRefresh = ref.read(settingsRefreshProvider.notifier);

    // Show confirmation dialog explaining the device will reboot
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        title: const Text('Apply Region'),
        content: Text(
          isInitialSetup
              ? 'Your device will reboot to apply the region settings. '
                    'This may take up to 30 seconds.\n\n'
                    'The app will automatically reconnect when ready.'
              : 'Changing the region will cause your device to reboot. '
                    'This may take up to 30 seconds.\n\n'
                    'You will be briefly disconnected while the device restarts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: context.accentColor),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    // Check if device is still connected before attempting to apply region
    final connectionState = ref.read(conn.deviceConnectionProvider);
    if (!connectionState.isConnected) {
      safeSetState(() {
        _errorMessage = 'Device disconnected. Please reconnect and try again.';
      });
      return;
    }

    safeSetState(() {
      _errorMessage = null;
      _showPairingInvalidationHint = false;
    });

    safeSetState(() => _applying = true);

    if (isInitialSetup) {
      // ── ONBOARDING / INITIAL SETUP FLOW ──
      // Stay on screen so the user sees progress during the device reboot.
      // After apply completes, persist regionConfigured, refresh the
      // settings provider, then POP back to the caller (onboarding).
      // The caller (_connectDevice) handles setOnboardingComplete +
      // initialize() which advances through terms → MainShell.
      await _applyAndPop(
        settings: settings,
        settingsRefresh: settingsRefresh,
        regionNotifier: regionNotifier,
        navigator: navigator,
      );
    } else {
      // ── NON-INITIAL FLOW (MainShell inline OR Settings push) ──
      // Persist regionConfigured FIRST so MainShell's inline guard
      // (needsRegionSetup && !regionConfigured) stops re-showing this
      // screen. Then pop if this was a pushed route (Settings), or do
      // nothing if inline (MainShell will rebuild). Fire applyRegion
      // in the background — the notifier manages the full reboot cycle.
      await _persistAndDismiss(
        settings: settings,
        settingsRefresh: settingsRefresh,
        regionNotifier: regionNotifier,
        navigator: navigator,
      );
    }
  }

  /// Hard ceiling for the entire apply-and-pop cycle. If the device
  /// reboots but the reconnect never completes (BLE hiccup, background
  /// connection race, etc.), we optimistically persist regionConfigured
  /// and pop after this duration. The setRegion command was already sent
  /// and the device accepted it (it rebooted), so the region IS applied
  /// even if we can't confirm it via reconnect.
  static const _applyHardTimeout = Duration(minutes: 1);

  /// Initial-setup path: stay on screen during apply, then pop.
  Future<void> _applyAndPop({
    required SettingsService settings,
    required SettingsRefreshNotifier settingsRefresh,
    required RegionConfigNotifier regionNotifier,
    required NavigatorState navigator,
  }) async {
    try {
      final protocol = ref.read(protocolServiceProvider);
      final currentDeviceRegion = protocol.currentRegion;
      final alreadyApplied =
          ref.read(regionConfigProvider).applyStatus ==
              RegionApplyStatus.applied &&
          ref.read(regionConfigProvider).regionChoice == _selectedRegion;
      final regionAlreadySet = currentDeviceRegion == _selectedRegion;

      // During initial setup, always call applyRegion() even if the
      // region already matches. This ensures the loading overlay shows
      // consistently and we properly handle the device reboot cycle.
      if (!alreadyApplied && !regionAlreadySet) {
        // Wrap in a hard timeout so the screen never stays stuck at
        // "Applying..." forever. The inner applyRegion has its own 90s
        // timeout on the reconnect confirmation, but if that completer
        // deadlocks (e.g. background connection race disrupts the
        // reconnect listener) the outer timeout guarantees we pop.
        await regionNotifier
            .applyRegion(_selectedRegion!, reason: 'initial_setup')
            .timeout(
              _applyHardTimeout,
              onTimeout: () {
                AppLogging.connection(
                  '⏱️ Region apply hard timeout (${_applyHardTimeout.inSeconds}s) — '
                  'optimistically marking region as configured and falling through to pop',
                );
                // Don't throw — fall through to the persist-and-pop below
              },
            );
      }

      // Persist region configured (settings object was captured before
      // async, safe to call even if widget is disposing)
      await settings.setRegionConfigured(true);

      if (!mounted) return;
      settingsRefresh.refresh();

      // Pop back to caller (onboarding _checkAndHandleRegion await)
      AppLogging.connection(
        '✅ Region apply complete — popping RegionSelectionScreen '
        '(region=$_selectedRegion, isInitialSetup=${widget.isInitialSetup})',
      );
      navigator.pop();
    } on Exception catch (e) {
      if (!mounted) return;

      // Check if the region was actually applied despite the error
      final postErrorState = ref.read(regionConfigProvider);
      final protocol = ref.read(protocolServiceProvider);
      final regionConfirmed =
          (postErrorState.applyStatus == RegionApplyStatus.applied &&
              postErrorState.regionChoice == _selectedRegion) ||
          protocol.currentRegion == _selectedRegion;

      if (regionConfirmed) {
        AppLogging.connection(
          '✅ Region confirmed despite error — persisting and popping '
          '(region=$_selectedRegion)',
        );
        await settings.setRegionConfigured(true);
        if (!mounted) return;
        settingsRefresh.refresh();
        navigator.pop();
        return;
      }

      // Timeout during initial setup = optimistic success.
      // The setRegion command was sent, the device accepted it and
      // rebooted (user can hear the reset), but the BLE reconnect
      // never completed within the timeout window. The region IS
      // applied — just persist and move on instead of stranding the
      // user on an "Applying..." screen forever.
      if (e is TimeoutException && widget.isInitialSetup) {
        AppLogging.connection(
          '⏱️ Region apply reconnect timed out during initial setup — '
          'optimistically marking region as configured and popping '
          '(region=$_selectedRegion)',
        );
        await settings.setRegionConfigured(true);
        if (!mounted) return;
        settingsRefresh.refresh();
        AppLogging.connection(
          '✅ Optimistic timeout pop — dismissing RegionSelectionScreen now',
        );
        navigator.pop();
        return;
      }

      // Unlock the UI so the user can retry
      safeSetState(() => _applying = false);

      final connState = ref.read(conn.deviceConnectionProvider);
      final pairingInvalidation = conn.isPairingInvalidationError(e);
      if (connState.isTerminalInvalidated || pairingInvalidation) {
        if (mounted) {
          navigator.pushNamed('/scanner');
        }
        return;
      }

      final message = e is TimeoutException
          ? 'Reconnect timed out. Please try again.'
          : pairingInvalidation
          ? 'Your phone removed the stored pairing info for this device.\n'
                'Go to Settings > Bluetooth, forget the Meshtastic device, '
                'and try again.'
          : 'Failed to set region: $e';

      safeSetState(() {
        _errorMessage = message;
        _showPairingInvalidationHint = pairingInvalidation;
      });
      showErrorSnackBar(context, message);
    }
  }

  /// Non-initial path: persist setting, dismiss, fire apply in background.
  Future<void> _persistAndDismiss({
    required SettingsService settings,
    required SettingsRefreshNotifier settingsRefresh,
    required RegionConfigNotifier regionNotifier,
    required NavigatorState navigator,
  }) async {
    try {
      final protocol = ref.read(protocolServiceProvider);
      final currentDeviceRegion = protocol.currentRegion;
      final regionState = ref.read(regionConfigProvider);
      final alreadyApplied =
          regionState.applyStatus == RegionApplyStatus.applied &&
          regionState.regionChoice == _selectedRegion;
      final regionAlreadySet = currentDeviceRegion == _selectedRegion;
      final shouldSkipApply = alreadyApplied || regionAlreadySet;

      // Persist regionConfigured BEFORE apply so MainShell's inline
      // guard clears immediately on rebuild
      await settings.setRegionConfigured(true);
      settingsRefresh.refresh();

      // Dismiss this screen: pop if pushed (Settings), otherwise let
      // MainShell rebuild (inline case — regionConfigured is now true)
      if (navigator.canPop()) {
        navigator.pop();
      }

      // Fire applyRegion in background. The notifier is a Riverpod-
      // managed object; its ref stays valid regardless of widget
      // lifecycle. Errors surface via connection state banners.
      if (!shouldSkipApply) {
        // ignore: unawaited_futures
        regionNotifier
            .applyRegion(_selectedRegion!, reason: 'settings_change')
            .catchError((Object e) {
              AppLogging.app('⚠️ Background region apply failed: $e');
            });
      }
    } on Exception catch (e) {
      // Unlock the UI so the user can retry
      safeSetState(() => _applying = false);
      if (!mounted) return;
      final message = 'Failed to set region: $e';
      safeSetState(() {
        _errorMessage = message;
      });
      showErrorSnackBar(context, message);
    }
  }

  Future<void> _openBluetoothSettings() async {
    final opened = await PermissionHelper().openBluetoothSettings();
    if (!mounted) return;
    if (!opened) {
      showErrorSnackBar(
        context,
        'Could not open Bluetooth Settings. Please open Settings > Bluetooth manually.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final regionState = ref.watch(regionConfigProvider);
    final isApplying =
        _applying || regionState.applyStatus == RegionApplyStatus.applying;
    final statusText = regionState.applyStatus == RegionApplyStatus.failed
        ? _errorMessage
        : null;

    return HelpTourController(
      topicId: 'region_selection',
      stepKeys: const {},
      child: GlassScaffold(
        title: widget.isInitialSetup ? 'Select Your Region' : 'Change Region',
        leading: widget.isInitialSetup ? const SizedBox.shrink() : null,
        automaticallyImplyLeading: !widget.isInitialSetup,
        actions: [
          if (!isApplying)
            IcoHelpAppBarButton(
              topicId: 'region_selection',
              autoTrigger: widget.isInitialSetup,
            ),
        ],
        slivers: [
          if (widget.isInitialSetup)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: StatusBanner.accent(
                  title: 'Important: Select Your Region',
                  subtitle:
                      'Choose the correct frequency for your location to comply with local regulations.',
                ),
              ),
            ),

          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.border),
                ),
                child: TextField(
                  enabled: !isApplying,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search regions...',
                    hintStyle: TextStyle(color: context.textTertiary),
                    prefixIcon: Icon(Icons.search, color: context.textTertiary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
            ),
          ),

          const SliverPadding(padding: EdgeInsets.only(top: 16)),

          // Region list
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final region = _filteredRegions[index];
              final isSelected = _selectedRegion == region.code;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildRegionTile(region, isSelected, isApplying),
              );
            }, childCount: _filteredRegions.length),
          ),

          // Bottom padding so the last region tile isn't hidden
          // behind the fixed bottom bar
          const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
        ],
        bottomNavigationBar: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error message
              if (statusText != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: StatusBanner.error(title: statusText),
                ),

              // Pairing invalidation hint
              if (_showPairingInvalidationHint) ...[_buildPairingHint()],

              // Save / Continue button
              Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: regionSelectionApplyButtonKey,
                      onPressed: _selectedRegion != null && !isApplying
                          ? _saveRegion
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.accentColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: context.card,
                        disabledForegroundColor: context.textTertiary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isApplying
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Applying...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              widget.isInitialSetup ? 'Continue' : 'Save',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegionTile(RegionInfo region, bool isSelected, bool isApplying) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? context.accentColor.withValues(alpha: 0.15)
            : context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? context.accentColor : context.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isApplying
              ? null
              : () => setState(() => _selectedRegion = region.code),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.accentColor.withValues(alpha: 0.2)
                        : context.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.cell_tower,
                      color: isSelected
                          ? context.accentColor
                          : context.textTertiary,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        region.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : context.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        region.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.accentColor
                        : context.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    region.frequency,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : context.textTertiary,
                    ),
                  ),
                ),
                if (_currentRegion == region.code && !isSelected) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'CURRENT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: context.accentColor,
                      ),
                    ),
                  ),
                ],
                if (isSelected) ...[
                  const SizedBox(width: 12),
                  Icon(
                    Icons.check_circle,
                    color: context.accentColor,
                    size: 24,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPairingHint() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.accentColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bluetooth pairing was removed. Forget "Meshtastic_XXXX" in Settings > Bluetooth and reconnect to continue.',
              style: context.bodySmallStyle?.copyWith(
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _openBluetoothSettings,
                  icon: Icon(
                    Icons.bluetooth_rounded,
                    size: 16,
                    color: context.textPrimary,
                  ),
                  label: Text(
                    'Bluetooth Settings',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 10,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pushNamed('/scanner'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 10,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'View Scanner',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
