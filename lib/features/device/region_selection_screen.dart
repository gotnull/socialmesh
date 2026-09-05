// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../../core/safety/lifecycle_mixin.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/meshtastic/region_metadata.dart';
import '../../core/theme.dart';
import '../../services/storage/storage_service.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/bottom_action_bar.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../providers/app_providers.dart';
import '../../generated/meshtastic/config.pbenum.dart';
import '../onboarding/meshtastic_onboarding_flow.dart';
import '../onboarding/meshtastic_onboarding_state.dart';
import '../../utils/permissions.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/status_banner.dart';
import '../../providers/countdown_providers.dart';

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

/// Available regions with their frequency bands.
/// Requires [BuildContext] because names, frequencies, and descriptions
/// are localised. Sourced from the centralized [kRegionMetadata]; UNSET
/// is filtered out (only meaningful in the Radio Configuration picker
/// as a "not yet configured" placeholder, not in the onboarding flow).
List<RegionInfo> getAvailableRegions(BuildContext context) {
  final l = context.l10n;
  return [
    for (final r in kRegionMetadata)
      if (r.code != RegionCode.UNSET)
        RegionInfo(
          code: r.code,
          name: r.regionSelectionName(l),
          frequency: r.regionSelectionFrequency(l),
          description: r.regionSelectionDescription(l),
        ),
  ];
}

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
  void _dismissKeyboard() {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
  }

  RegionCode? _selectedRegion;
  RegionCode? _currentRegion;
  String? _errorMessage;
  String _searchQuery = '';
  bool _initialized = false;
  bool _showPairingInvalidationHint = false;
  bool _applying = false;

  /// Listener that closes the screen when the onboarding-flow
  /// coordinator reaches a terminal state. Required for the
  /// OnboardingScreen path: that flow pushes RegionSelectionScreen
  /// via `Navigator.push` and awaits the pop to continue. When the
  /// coordinator owns the flow, RegionSelection stops self-popping
  /// inside `_saveRegion` (the coordinator is the only owner of
  /// completion); without this listener the pushed route would
  /// strand on screen forever after the coordinator reaches
  /// `OnboardingReady` / `OnboardingFailed` / etc.
  ///
  /// When RegionSelectionScreen is rendered inline by
  /// `_AppRouter`/`appShellProvider` (no Navigator.push above it),
  /// `Navigator.canPop()` is false and the listener is a no-op —
  /// the router unmount path handles the screen swap.
  ProviderSubscription<MeshtasticOnboardingState>? _onboardingFlowTerminalSub;

  @override
  void initState() {
    super.initState();
    AppLogging.connection(
      '🌍 RegionSelection: initState — isInitialSetup=${widget.isInitialSetup}',
    );

    // Pop-on-terminal listener. listenManual is correct in initState
    // (no state mutation until the listener fires).
    if (widget.isInitialSetup) {
      _onboardingFlowTerminalSub = ref.listenManual<MeshtasticOnboardingState>(
        meshtasticOnboardingFlowProvider,
        (previous, next) {
          if (!mounted) return;
          if (!next.isTerminal) return;
          if (previous != null && previous.isTerminal) return;
          if (!Navigator.canPop(context)) {
            AppLogging.connection(
              '🌍 RegionSelection: terminal '
              'phase=${next.phase.name} '
              'no-op — rendered inline (cannot pop)',
            );
            return;
          }
          AppLogging.connection(
            '🌍 RegionSelection: terminal phase=${next.phase.name} — '
            'popping pushed route',
          );
          Navigator.of(context).pop();
        },
      );
    }

    // Load current region after build
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrentRegion());
  }

  @override
  void dispose() {
    _onboardingFlowTerminalSub?.close();
    super.dispose();
  }

  void _loadCurrentRegion() {
    if (_initialized) return;
    if (!mounted) return;
    final protocol = ref.read(protocolServiceProvider);
    final region = protocol.currentRegion;
    AppLogging.connection(
      '🌍 RegionSelection: _loadCurrentRegion — deviceRegion=${region?.name ?? "null"}',
    );
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
    final regions = getAvailableRegions(context);
    if (_searchQuery.isEmpty) return regions;
    final query = _searchQuery.toLowerCase();
    return regions.where((r) {
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
    AppLogging.connection(
      '🌍 RegionSelection: _saveRegion called — '
      'selected=$_selectedRegion, isInitialSetup=$isInitialSetup, '
      'currentApplyStatus=${regionState.applyStatus}',
    );

    // Capture ALL references BEFORE any async work to avoid accessing
    // ref/context after disposal
    final settingsAsync = ref.read(settingsServiceProvider);
    if (!settingsAsync.hasValue) return; // Settings not ready
    final settings = settingsAsync.requireValue;
    final navigator = Navigator.of(context);
    final regionNotifier = ref.read(regionConfigProvider.notifier);
    final settingsRefresh = ref.read(settingsRefreshProvider.notifier);

    // Show confirmation dialog explaining the device will reboot
    final l10n = context.l10n;
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.regionSelectionApplyDialogTitle,
      message: isInitialSetup
          ? l10n.regionSelectionApplyDialogMessageInitial
          : l10n.regionSelectionApplyDialogMessageChange,
      confirmLabel: l10n.regionSelectionApplyDialogConfirm,
    );

    if (confirmed != true) {
      AppLogging.connection(
        '🌍 RegionSelection: Apply dialog cancelled by user',
      );
      return;
    }
    if (!mounted) return;

    AppLogging.connection(
      '🌍 RegionSelection: Apply confirmed — checking device connection',
    );

    // Check if the BLE link is still up before attempting to apply
    // region. The button is also gated on `isLinkConnectedProvider` in
    // build(), but this guard catches the race where BLE dropped
    // between the tap and the confirmation dialog returning. We
    // surface a snackbar here on top of the inline error message
    // because the inline message sits at the top of the form - users
    // on a long picker often miss it. Match the build-time gate's
    // provider so the two checks agree.
    final isLinkUp = ref.read(isLinkConnectedProvider);
    if (!isLinkUp) {
      AppLogging.connection(
        '🌍 RegionSelection: BLOCKED — device disconnected before apply',
      );
      final blockedMessage = context.l10n.regionSelectionDeviceDisconnected;
      safeSetState(() {
        _errorMessage = blockedMessage;
      });
      showErrorSnackBar(context, blockedMessage);
      return;
    }

    safeSetState(() {
      _errorMessage = null;
      _showPairingInvalidationHint = false;
    });

    safeSetState(() => _applying = true);
    AppLogging.connection(
      '🌍 RegionSelection: "Applying..." overlay shown — '
      'region=$_selectedRegion, isInitialSetup=$isInitialSetup',
    );

    if (isInitialSetup) {
      // The coordinator owns this flow: region writes / reboot /
      // reconnect / readiness all happen via state-machine listeners.
      // The screen stays mounted while the coordinator transitions
      // through writingRegion / awaitingReboot / awaitingReconnect /
      // awaitingReadiness, and is unmounted by `_AppRouter` when the
      // coordinator reaches OnboardingReady. No self-pop, no inline
      // applyRegion, no settings refresh dance.
      AppLogging.connection(
        '🌍 RegionSelection: dispatching '
        'selectRegion(${_selectedRegion!.name}) to coordinator',
      );
      ref
          .read(meshtasticOnboardingFlowProvider.notifier)
          .selectRegion(_selectedRegion!);
      // Stay on screen — appShellProvider will route us out when
      // the coordinator reaches OnboardingReady. _applying remains
      // true so the overlay keeps showing.
      return;
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

  /// Non-initial path: persist setting, fire apply, STAY MOUNTED with
  /// the Applying overlay until the apply actually completes, then
  /// dismiss. Previously this path popped synchronously and fired
  /// applyRegion in the background, which caused the screen to vanish
  /// the instant the user tapped Save - giving zero feedback that the
  /// region was actually being written + the device was rebooting.
  /// The initial-setup path (driven by the onboarding coordinator)
  /// already stays mounted through the writingRegion / awaitingReboot /
  /// awaitingReconnect / awaitingReadiness phases; this brings the
  /// non-initial path in line.
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

      AppLogging.connection(
        '🌍 RegionSelection: _persistAndDismiss — '
        'shouldSkipApply=$shouldSkipApply, alreadyApplied=$alreadyApplied, '
        'regionAlreadySet=$regionAlreadySet, selected=$_selectedRegion',
      );

      if (shouldSkipApply) {
        // Region already set on device or already applied this session;
        // nothing to wait for. Persist `regionConfigured` then dismiss.
        await settings.setRegionConfigured(true);
        settingsRefresh.refresh();
        if (!mounted) return;
        AppLogging.connection('✅ _persistAndDismiss: skip apply, dismissing');
        _popOrSetReady(navigator);
        return;
      }

      // Start global reboot countdown — banner persists across
      // navigation and auto-cancels when the device reconnects.
      ref
          .read(countdownProvider.notifier)
          .startDeviceRebootCountdown(reason: 'region changed');

      // AWAIT the apply BEFORE flipping `regionConfigured`. Setting
      // `regionConfigured=true` early would immediately fail MainShell's
      // inline guard (`needsRegionSetup && !regionConfigured`) and
      // unmount the picker before the apply even starts - the exact
      // symptom that made the user see the screen dismiss itself with
      // no progress feedback. `applyRegion` drives the full write ->
      // reboot -> reconnect cycle and only completes when the device
      // is back online with the new region (or the apply has failed).
      // While we await, `_applying = true` keeps the Applying...
      // overlay visible.
      AppLogging.connection(
        '🌍 RegionSelection: awaiting applyRegion(${_selectedRegion!.name})',
      );
      try {
        await regionNotifier.applyRegion(
          _selectedRegion!,
          reason: 'settings_change',
        );
      } catch (e) {
        AppLogging.app('⚠️ Foreground region apply failed: $e');
        if (!mounted) return;
        safeSetState(() {
          _applying = false;
          _errorMessage = context.l10n.regionSelectionSetRegionError(
            e.toString(),
          );
        });
        showErrorSnackBar(context, _errorMessage!);
        return;
      }

      // Apply succeeded - now safe to flip `regionConfigured`. MainShell
      // will rebuild without the inline picker on its next pass and the
      // user lands back on the nodes view (or wherever they came from).
      await settings.setRegionConfigured(true);
      settingsRefresh.refresh();

      AppLogging.connection(
        '✅ _persistAndDismiss: applyRegion completed, dismissing',
      );
      if (!mounted) return;
      // Firmware 2.8+ applies the region live without rebooting, so the
      // reboot banner started above would otherwise keep counting down
      // on a radio that never went away. A radio that did reboot has
      // already cancelled it on reconnect, so this is a no-op there.
      ref
          .read(countdownProvider.notifier)
          .cancelCountdown(CountdownNotifier.deviceRebootId);
      _popOrSetReady(navigator);
    } on Exception catch (e) {
      // Unlock the UI so the user can retry
      safeSetState(() => _applying = false);
      if (!mounted) return;
      final message = context.l10n.regionSelectionSetRegionError(e.toString());
      safeSetState(() {
        _errorMessage = message;
      });
      showErrorSnackBar(context, message);
    }
  }

  /// Pop the picker if it was pushed (Settings entry), otherwise mark
  /// appInit ready so the router shows MainShell. Mirrors the legacy
  /// dismiss path from `_persistAndDismiss`.
  void _popOrSetReady(NavigatorState navigator) {
    if (navigator.canPop()) {
      AppLogging.connection(
        '✅ _persistAndDismiss: popping RegionSelectionScreen',
      );
      navigator.pop();
    } else {
      AppLogging.connection(
        '✅ _persistAndDismiss: cannot pop (root route) — '
        'setting appInit to ready so router shows MainShell',
      );
      ref.read(appInitProvider.notifier).setReady();
    }
  }

  Future<void> _openBluetoothSettings() async {
    final opened = await PermissionHelper().openBluetoothSettings();
    if (!mounted) return;
    if (!opened) {
      showErrorSnackBar(
        context,
        context.l10n.regionSelectionOpenBluetoothSettingsError,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final regionState = ref.watch(regionConfigProvider);
    // Watch the transport-level link state so the Apply button stays
    // disabled while BLE is reconnecting / restoring, but stays enabled
    // in steady-state operation. We deliberately use
    // `isLinkConnectedProvider` (transport-level) rather than
    // `deviceConnectionProvider.isConnected` (DevicePairingState):
    // the pairing state machine transitions configuring -> connected
    // only via `markAsPaired`, which doesn't re-fire on every reconnect
    // path. Gating on that strict value left the button stuck disabled
    // whenever the most recent reconnect landed in `configuring` and
    // never advanced - even though the link was fully usable for
    // messages, nodes, and admin commands.
    final isDeviceConnected = ref.watch(isLinkConnectedProvider);
    final isApplying =
        _applying || regionState.applyStatus == RegionApplyStatus.applying;
    final statusText = regionState.applyStatus == RegionApplyStatus.failed
        ? _errorMessage
        : null;

    // During initial setup, block both system-back and the iOS edge
    // swipe-back gesture. Region must be picked before the user
    // proceeds — letting them slide back to the splash/connecting
    // screen leaves the app in a stale state with no way forward
    // (the device is connected but unconfigured). Also block while
    // an apply is in flight so the user can't bail mid-write.
    final blockPop = widget.isInitialSetup || isApplying;

    return PopScope(
      canPop: !blockPop,
      child: GestureDetector(
        onTap: _dismissKeyboard,
        child: HelpTourController(
          topicId: 'region_selection',
          stepKeys: const {},
          child: GlassScaffold(
            resizeToAvoidBottomInset: false,
            title: widget.isInitialSetup
                ? context.l10n.regionSelectionTitleInitial
                : context.l10n.regionSelectionTitleChange,
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
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spacing16,
                      8,
                      16,
                      16,
                    ),
                    child: StatusBanner.accent(
                      title: context.l10n.regionSelectionBannerTitle,
                      subtitle: context.l10n.regionSelectionBannerSubtitle,
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
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                      border: Border.all(color: context.border),
                    ),
                    child: TextField(
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      maxLength: 100,
                      enabled: !isApplying,
                      style: TextStyle(color: context.textPrimary),
                      decoration: InputDecoration(
                        hintText: context.l10n.regionSelectionSearchHint,
                        hintStyle: TextStyle(color: context.textTertiary),
                        counterText: '',
                        prefixIcon: Icon(
                          Icons.search,
                          color: context.textTertiary,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
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
            bottomNavigationBar: BottomActionBar(
              horizontalPadding: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Error message
                  if (statusText != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spacing16,
                        8,
                        16,
                        0,
                      ),
                      child: StatusBanner.error(title: statusText),
                    ),

                  // Pairing invalidation hint
                  if (_showPairingInvalidationHint) ...[_buildPairingHint()],

                  // Save / Continue button
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing16,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          key: regionSelectionApplyButtonKey,
                          onPressed:
                              _selectedRegion != null &&
                                  !isApplying &&
                                  isDeviceConnected
                              ? _saveRegion
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.accentColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: context.card,
                            disabledForegroundColor: context.textTertiary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius12,
                              ),
                            ),
                          ),
                          child: isApplying
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: AppTheme.spacing10),
                                    Text(
                                      context.l10n.regionSelectionApplying,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  widget.isInitialSetup
                                      ? context.l10n.regionSelectionContinue
                                      : context.l10n.regionSelectionSave,
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
        borderRadius: BorderRadius.circular(AppTheme.radius12),
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
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.accentColor.withValues(alpha: 0.2)
                        : context.background,
                    borderRadius: BorderRadius.circular(AppTheme.radius10),
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
                const SizedBox(width: AppTheme.spacing16),
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
                              ? context.accentColor
                              : context.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing2),
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
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
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
                  const SizedBox(width: AppTheme.spacing8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radius6),
                    ),
                    child: Text(
                      context.l10n.regionSelectionCurrentBadge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: context.accentColor,
                      ),
                    ),
                  ),
                ],
                // No check_circle trailing icon: the selected state is
                // already conveyed by the row's accent-colored border
                // and the highlighted frequency badge - a third visual
                // selection cue was redundant.
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
        padding: const EdgeInsets.all(AppTheme.spacing12),
        decoration: BoxDecoration(
          color: context.accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(color: context.accentColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.regionSelectionPairingHintMessage,
              style: context.bodySmallStyle?.copyWith(
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
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
                    context.l10n.regionSelectionBluetoothSettings,
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
                const SizedBox(width: AppTheme.spacing8),
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
                    context.l10n.regionSelectionViewScanner,
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
