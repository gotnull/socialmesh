import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../providers/app_providers.dart';
import '../../providers/connection_providers.dart' as conn;
import '../../generated/meshtastic/config.pbenum.dart';
import '../../utils/snackbar.dart';

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

enum RegionApplyState { idle, applying, waitingForReconnect, success, error }

const regionSelectionApplyButtonKey = Key('region_selection_apply_button');

class RegionSelectionScreen extends ConsumerStatefulWidget {
  final bool isInitialSetup;

  const RegionSelectionScreen({super.key, this.isInitialSetup = false});

  @override
  ConsumerState<RegionSelectionScreen> createState() =>
      _RegionSelectionScreenState();
}

class _RegionSelectionScreenState extends ConsumerState<RegionSelectionScreen> {
  RegionCode? _selectedRegion;
  RegionCode? _currentRegion;
  RegionApplyState _state = RegionApplyState.idle;
  String? _errorMessage;
  String _searchQuery = '';
  bool _initialized = false;
  bool _showPairingInvalidationHint = false;

  bool get _isBusy =>
      _state == RegionApplyState.applying ||
      _state == RegionApplyState.waitingForReconnect;

  String? get _statusText =>
      _state == RegionApplyState.error ? _errorMessage : null;

  @override
  void initState() {
    super.initState();
    // Load current region after build
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrentRegion());
  }

  void _loadCurrentRegion() {
    if (_initialized) return;
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
    if (_selectedRegion == null || _isBusy) return;
    final isInitialSetup = widget.isInitialSetup;

    setState(() {
      _state = RegionApplyState.applying;
      _errorMessage = null;
      _showPairingInvalidationHint = false;
    });

    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.setRegion(_selectedRegion!);

      if (!mounted) return;

      setState(() => _state = RegionApplyState.waitingForReconnect);

      await _waitForReconnect();

      if (!mounted) return;

      final settings = await ref.read(settingsServiceProvider.future);
      await settings.setRegionConfigured(true);
      if (!mounted) return;
      setState(() => _state = RegionApplyState.success);

      if (isInitialSetup) {
        ref.read(appInitProvider.notifier).setInitialized();
      } else {
        Navigator.of(context).pop(true);
      }
    } on _PairingInvalidatedDuringRegionSetup {
      if (!mounted) return;
      Navigator.of(context).pushNamed('/scanner');
      return;
    } catch (e) {
      final pairingInvalidation = conn.isPairingInvalidationError(e);
      final message = e is TimeoutException
          ? 'Reconnect timed out. Please try again.'
          : pairingInvalidation
          ? 'Your phone removed the stored pairing info for this device.\nGo to Settings > Bluetooth, forget the Meshtastic device, and try again.'
          : 'Failed to set region: $e';
      if (!mounted) return;
      setState(() {
        _state = RegionApplyState.error;
        _errorMessage = message;
        _showPairingInvalidationHint = pairingInvalidation;
      });
      showErrorSnackBar(context, message);
    }
  }

  Future<void> _waitForReconnect() async {
    bool sawDisconnect = !ref.read(conn.deviceConnectionProvider).isConnected;
    final completer = Completer<void>();
    final subscription = ref.listenManual<conn.DeviceConnectionState2>(
      conn.deviceConnectionProvider,
      (previous, next) {
        if (next.isTerminalInvalidated) {
          if (!completer.isCompleted) {
            completer.completeError(_PairingInvalidatedDuringRegionSetup());
          }
          return;
        }
        if (next.state != conn.DevicePairingState.connected) {
          sawDisconnect = true;
          return;
        }
        if (sawDisconnect) {
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
      },
    );
    try {
      await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () =>
            throw TimeoutException('Timed out waiting for device to reconnect'),
      );
    } finally {
      subscription.close();
    }
  }

  Future<void> _openAppSettings() async {
    final opened = await openAppSettings();
    if (!mounted) return;
    if (!opened) {
      showErrorSnackBar(
        context,
        'Could not open Settings. Please open Bluetooth settings manually.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return HelpTourController(
      topicId: 'region_selection',
      stepKeys: const {},
      child: Scaffold(
        backgroundColor: context.background,
        appBar: AppBar(
          backgroundColor: context.background,
          leading: widget.isInitialSetup
              ? null
              : IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: _isBusy ? context.textTertiary : context.textPrimary,
                  ),
                  onPressed: _isBusy ? null : () => Navigator.of(context).pop(),
                ),
          title: Text(
            widget.isInitialSetup ? 'Select Your Region' : 'Change Region',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          actions: [
            IcoHelpAppBarButton(
              topicId: 'region_selection',
              autoTrigger: widget.isInitialSetup,
            ),
          ],
        ),
        body: Column(
          children: [
            if (widget.isInitialSetup)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.accentColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: context.accentColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Important: Select Your Region',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Choose the correct frequency for your location to comply with local regulations.',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.border),
                ),
                child: TextField(
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

            const SizedBox(height: 16),

            // Region list
            Expanded(
              child: AbsorbPointer(
                absorbing: _isBusy,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredRegions.length,
                  itemBuilder: (context, index) {
                    final region = _filteredRegions[index];
                    final isSelected = _selectedRegion == region.code;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.accentColor.withValues(alpha: 0.15)
                            : context.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? context.accentColor
                              : context.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () =>
                              setState(() => _selectedRegion = region.code),
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
                                        ? context.accentColor.withValues(
                                            alpha: 0.2,
                                          )
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      color: isSelected
                                          ? Colors.white
                                          : context.textTertiary,
                                    ),
                                  ),
                                ),
                                if (_currentRegion == region.code &&
                                    !isSelected) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.accentColor.withValues(
                                        alpha: 0.2,
                                      ),
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
                  },
                ),
              ),
            ),

            // Save button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    key: regionSelectionApplyButtonKey,
                    onPressed: _selectedRegion != null && !_isBusy
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
                    child: _isBusy
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _state == RegionApplyState.waitingForReconnect
                                    ? 'Reconnecting…'
                                    : 'Applying region…',
                                style: const TextStyle(
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
            if (_statusText != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _statusText!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _state == RegionApplyState.error
                        ? AppTheme.errorRed
                        : context.textSecondary,
                  ),
                ),
              ),
            ],
            if (_showPairingInvalidationHint) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.accentColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bluetooth pairing was removed. Forget “Meshtastic” in Settings > Bluetooth and reconnect to continue.',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: _openAppSettings,
                            icon: Icon(
                              Icons.settings_rounded,
                              size: 16,
                              color: context.textPrimary,
                            ),
                            label: Text(
                              'Open Settings',
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
                            onPressed: () =>
                                Navigator.of(context).pushNamed('/scanner'),
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
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PairingInvalidatedDuringRegionSetup implements Exception {}
