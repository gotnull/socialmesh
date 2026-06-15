// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../utils/snackbar.dart';

/// Coordinates entered by the user for a fixed-position assignment.
class FixedPositionInput {
  const FixedPositionInput({
    required this.latitude,
    required this.longitude,
    required this.altitude,
  });

  final double latitude;
  final double longitude;
  final int altitude;
}

/// Minimal coordinate-entry sheet for assigning a fixed GPS position to a
/// remote node (e.g. an installed tower node). Manual entry is the primary,
/// safe path; a node's reported position pre-fills the fields when available,
/// and a GPS-less node simply opens blank for manual entry.
///
/// "Use my phone's location" fills the fields from the **phone's** GPS — never
/// the remote node's — so an installer is not misled into stamping their own
/// coordinates onto a tower by accident.
class FixedPositionSheet extends ConsumerStatefulWidget {
  const FixedPositionSheet({
    super.key,
    required this.nodeName,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAltitude,
  });

  final String nodeName;
  final double? initialLatitude;
  final double? initialLongitude;
  final int? initialAltitude;

  /// Presents the sheet and resolves to the entered coordinates, or null if
  /// the user dismisses it.
  static Future<FixedPositionInput?> show(
    BuildContext context, {
    required String nodeName,
    double? initialLatitude,
    double? initialLongitude,
    int? initialAltitude,
  }) {
    return AppBottomSheet.show<FixedPositionInput>(
      context: context,
      child: FixedPositionSheet(
        nodeName: nodeName,
        initialLatitude: initialLatitude,
        initialLongitude: initialLongitude,
        initialAltitude: initialAltitude,
      ),
    );
  }

  @override
  ConsumerState<FixedPositionSheet> createState() => _FixedPositionSheetState();
}

class _FixedPositionSheetState extends ConsumerState<FixedPositionSheet>
    with LifecycleSafeMixin<FixedPositionSheet> {
  late final TextEditingController _latController;
  late final TextEditingController _lonController;
  late final TextEditingController _altController;
  bool _gettingLocation = false;

  @override
  void initState() {
    super.initState();
    _latController = TextEditingController(
      text: widget.initialLatitude?.toStringAsFixed(6) ?? '',
    );
    _lonController = TextEditingController(
      text: widget.initialLongitude?.toStringAsFixed(6) ?? '',
    );
    _altController = TextEditingController(
      text: (widget.initialAltitude ?? 0).toString(),
    );
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    _altController.dispose();
    super.dispose();
  }

  Future<void> _usePhoneLocation() async {
    final l10n = context.l10n;
    safeSetState(() => _gettingLocation = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          showActionSnackBar(
            context,
            l10n.positionConfigPermissionDenied,
            actionLabel: l10n.positionConfigOpenSettings,
            onAction: () => Geolocator.openAppSettings(),
            type: SnackBarType.warning,
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      );

      safeSetState(() {
        _latController.text = position.latitude.toStringAsFixed(6);
        _lonController.text = position.longitude.toStringAsFixed(6);
        _altController.text = position.altitude.toInt().toString();
      });
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          l10n.positionConfigLocationFailed(e.toString()),
        );
      }
    } finally {
      safeSetState(() => _gettingLocation = false);
    }
  }

  void _submit() {
    final lat = double.tryParse(_latController.text.trim());
    final lon = double.tryParse(_lonController.text.trim());
    final alt = int.tryParse(_altController.text.trim()) ?? 0;

    final valid =
        lat != null &&
        lon != null &&
        lat.isFinite &&
        lon.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lon >= -180 &&
        lon <= 180;

    if (!valid) {
      showErrorSnackBar(context, context.l10n.fixedPositionSheetInvalid);
      return;
    }

    safeNavigatorPop(
      FixedPositionInput(latitude: lat, longitude: lon, altitude: alt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GestureDetector(
      // lint-allow: haptic-feedback — GestureDetector is for keyboard
      // dismissal, not user interaction
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.fixedPositionSheetTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          SizedBox(height: AppTheme.spacing8),
          Text(
            l10n.fixedPositionSheetDescription(widget.nodeName),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.textTertiary),
          ),
          SizedBox(height: AppTheme.spacing16),
          _coordField(
            controller: _latController,
            label: l10n.positionConfigLatitude,
            hint: l10n.positionConfigLatitudeHint,
            icon: Icons.arrow_upward,
            action: TextInputAction.next,
          ),
          SizedBox(height: AppTheme.spacing16),
          _coordField(
            controller: _lonController,
            label: l10n.positionConfigLongitude,
            hint: l10n.positionConfigLongitudeHint,
            icon: Icons.arrow_forward,
            action: TextInputAction.next,
          ),
          SizedBox(height: AppTheme.spacing16),
          _coordField(
            controller: _altController,
            label: l10n.positionConfigAltitude,
            hint: l10n.positionConfigAltitudeHint,
            icon: Icons.height,
            action: TextInputAction.done,
            integer: true,
          ),
          SizedBox(height: AppTheme.spacing12),
          OutlinedButton.icon(
            onPressed: _gettingLocation ? null : _usePhoneLocation,
            icon: _gettingLocation
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.accentColor,
                    ),
                  )
                : Icon(Icons.my_location, color: context.accentColor),
            label: Text(
              _gettingLocation
                  ? l10n.fixedPositionSheetGettingPhoneLocation
                  : l10n.fixedPositionSheetUsePhoneLocation,
              style: TextStyle(
                color: context.accentColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: context.accentColor),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          SizedBox(height: AppTheme.spacing20),
          PrimaryGradientButton(
            label: l10n.fixedPositionSheetSubmit,
            icon: Icons.location_on,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Widget _coordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required TextInputAction action,
    bool integer = false,
  }) {
    return TextField(
      controller: controller,
      maxLength: 100,
      style: TextStyle(color: context.textPrimary),
      keyboardType: integer
          ? const TextInputType.numberWithOptions(signed: true)
          : const TextInputType.numberWithOptions(decimal: true, signed: true),
      textInputAction: action,
      onSubmitted: action == TextInputAction.done
          ? (_) => FocusScope.of(context).unfocus()
          : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.textSecondary),
        hintText: hint,
        hintStyle: TextStyle(color: SemanticColors.muted),
        filled: true,
        fillColor: context.background,
        counterText: '',
        prefixIcon: Icon(icon, color: context.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          borderSide: BorderSide(color: context.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          borderSide: BorderSide(color: context.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          borderSide: BorderSide(color: context.accentColor),
        ),
      ),
    );
  }
}
