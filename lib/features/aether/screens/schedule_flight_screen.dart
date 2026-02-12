// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/datetime_picker_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../models/mesh_models.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../../utils/snackbar.dart';
import '../providers/aether_providers.dart';
import '../services/opensky_service.dart';

// =============================================================================
// Constants
// =============================================================================

/// Maximum length for flight number (e.g., "UAL1234A" = 8 chars max)
const int _maxFlightNumberLength = 8;

/// Regex pattern for valid flight numbers.
/// Format: 2-char airline (AA, B6, 9W) OR 3-letter airline (UAL, BAW)
///         + 1-4 digit flight number + optional suffix letter
/// Examples: UA123, BA2490, DL1, 9W4567, AA100A, UAL123
final _flightNumberPattern = RegExp(
  r'^(?:'
  r'(?:[A-Z]{2}|[A-Z][0-9]|[0-9][A-Z])[0-9]{1,4}|' // 2-char airline + 1-4 digits
  r'[A-Z]{3}[0-9]{1,4}' // 3-letter airline + 1-4 digits
  r')[A-Z]?$',
);

/// Maximum length for airport codes (ICAO is 4, IATA is 3)
const int _maxAirportCodeLength = 4;

/// Regex pattern for valid airport codes.
/// IATA: 3 uppercase letters (e.g., LAX, JFK, LHR)
/// ICAO: 4 uppercase letters (e.g., KLAX, KJFK, EGLL)
final _airportCodePattern = RegExp(r'^[A-Z]{3,4}$');

/// Maximum length for notes field
const int _maxNotesLength = 500;

// =============================================================================
// Screen
// =============================================================================

/// Screen to schedule a new Aether flight
class ScheduleFlightScreen extends ConsumerStatefulWidget {
  const ScheduleFlightScreen({super.key});

  @override
  ConsumerState<ScheduleFlightScreen> createState() =>
      _ScheduleFlightScreenState();
}

class _ScheduleFlightScreenState extends ConsumerState<ScheduleFlightScreen>
    with LifecycleSafeMixin<ScheduleFlightScreen> {
  final _formKey = GlobalKey<FormState>();
  final _flightNumberController = TextEditingController();
  final _departureController = TextEditingController();
  final _arrivalController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _departureDate;
  TimeOfDay? _departureTime;
  DateTime? _arrivalDate;
  TimeOfDay? _arrivalTime;
  bool _isSaving = false;

  // Flight validation state
  FlightValidationResult? _validationResult;
  bool _isValidating = false;

  @override
  void dispose() {
    _flightNumberController.dispose();
    _departureController.dispose();
    _arrivalController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // My Node Helper
  // ===========================================================================

  MeshNode? _getMyNode() {
    final myNodeNum = ref.read(myNodeNumProvider);
    if (myNodeNum == null) return null;
    final nodes = ref.read(nodesProvider);
    return nodes[myNodeNum];
  }

  // ===========================================================================
  // Date/Time Selection
  // ===========================================================================

  Future<void> _selectDepartureDate() async {
    final now = DateTime.now();
    final date = await DatePickerSheet.show(
      context,
      initialDate: _departureDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      title: 'Departure Date',
    );

    if (date != null && mounted) {
      safeSetState(() => _departureDate = date);
      if (_departureTime == null) {
        _selectDepartureTime();
      }
    }
  }

  Future<void> _selectDepartureTime() async {
    final time = await TimePickerSheet.show(
      context,
      initialTime: _departureTime ?? TimeOfDay.now(),
      title: 'Departure Time',
    );

    if (time != null && mounted) {
      safeSetState(() => _departureTime = time);
    }
  }

  Future<void> _selectArrivalDate() async {
    final now = DateTime.now();
    final date = await DatePickerSheet.show(
      context,
      initialDate: _arrivalDate ?? _departureDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      title: 'Arrival Date',
    );

    if (date != null && mounted) {
      safeSetState(() => _arrivalDate = date);
      if (_arrivalTime == null) {
        _selectArrivalTime();
      }
    }
  }

  Future<void> _selectArrivalTime() async {
    final time = await TimePickerSheet.show(
      context,
      initialTime: _arrivalTime ?? TimeOfDay.now(),
      title: 'Arrival Time',
    );

    if (time != null && mounted) {
      safeSetState(() => _arrivalTime = time);
    }
  }

  // ===========================================================================
  // Validation
  // ===========================================================================

  String? _validateFlightNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Enter flight number';
    }

    final cleaned = value.toUpperCase().trim();
    if (!_flightNumberPattern.hasMatch(cleaned)) {
      return 'Invalid format (e.g., UA123, BA2490)';
    }

    return null;
  }

  String? _validateAirportCode(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return 'Required';
    }

    final cleaned = value.toUpperCase().trim();
    if (!_airportCodePattern.hasMatch(cleaned)) {
      return 'Use 3-4 letter code';
    }

    return null;
  }

  void _clearArrivalDateTime() {
    safeSetState(() {
      _arrivalDate = null;
      _arrivalTime = null;
    });
  }

  // ===========================================================================
  // Flight Validation (OpenSky Network)
  // ===========================================================================

  Future<void> _validateFlight() async {
    final flightNumber = _flightNumberController.text.trim().toUpperCase();
    final departure = _departureController.text.trim().toUpperCase();

    if (flightNumber.isEmpty) {
      showErrorSnackBar(context, 'Enter a flight number first');
      return;
    }

    if (!_flightNumberPattern.hasMatch(flightNumber)) {
      showErrorSnackBar(context, 'Invalid flight number format');
      return;
    }

    safeSetState(() {
      _isValidating = true;
      _validationResult = null;
    });

    HapticFeedback.lightImpact();

    try {
      final openSky = OpenSkyService();

      // If we have departure info and date, use scheduled validation
      if (departure.isNotEmpty && _departureDate != null) {
        final scheduledDeparture = _buildDepartureDateTime();
        if (scheduledDeparture != null) {
          final result = await openSky.validateScheduledFlight(
            flightNumber: flightNumber,
            departureAirport: departure,
            scheduledDeparture: scheduledDeparture,
          );

          if (mounted) {
            safeSetState(() {
              _validationResult = result;
              _isValidating = false;
            });

            _showValidationFeedback(result);
          }
          return;
        }
      }

      // Otherwise, just check if the callsign is currently active
      final result = await openSky.validateFlightByCallsign(flightNumber);

      if (mounted) {
        safeSetState(() {
          _validationResult = result;
          _isValidating = false;
        });

        _showValidationFeedback(result);
      }
    } catch (e) {
      if (mounted) {
        safeSetState(() {
          _validationResult = FlightValidationResult(
            status: FlightValidationStatus.error,
            message: 'Validation failed: $e',
          );
          _isValidating = false;
        });
        showErrorSnackBar(context, 'Failed to validate flight');
      }
    }
  }

  void _showValidationFeedback(FlightValidationResult result) {
    HapticFeedback.mediumImpact();

    switch (result.status) {
      case FlightValidationStatus.active:
        showSuccessSnackBar(
          context,
          'Flight is currently active! ${result.position?.altitudeFeet?.toStringAsFixed(0) ?? ''} ft',
        );
      case FlightValidationStatus.verified:
        showSuccessSnackBar(context, 'Flight verified in OpenSky records');
      case FlightValidationStatus.pending:
        showInfoSnackBar(context, result.message);
      case FlightValidationStatus.notFound:
        showWarningSnackBar(context, result.message);
      case FlightValidationStatus.rateLimited:
        showErrorSnackBar(context, 'Rate limited. Try again in a few minutes.');
      case FlightValidationStatus.error:
        showErrorSnackBar(context, result.message);
    }
  }

  void _clearValidation() {
    safeSetState(() {
      _validationResult = null;
    });
  }

  DateTime? _buildDepartureDateTime() {
    if (_departureDate == null || _departureTime == null) return null;
    return DateTime(
      _departureDate!.year,
      _departureDate!.month,
      _departureDate!.day,
      _departureTime!.hour,
      _departureTime!.minute,
    );
  }

  DateTime? _buildArrivalDateTime() {
    if (_arrivalDate == null || _arrivalTime == null) return null;
    return DateTime(
      _arrivalDate!.year,
      _arrivalDate!.month,
      _arrivalDate!.day,
      _arrivalTime!.hour,
      _arrivalTime!.minute,
    );
  }

  // ===========================================================================
  // Save
  // ===========================================================================

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final myNode = _getMyNode();
    if (myNode == null) {
      showWarningSnackBar(context, 'Connect your Meshtastic device first');
      return;
    }

    final departureDateTime = _buildDepartureDateTime();
    if (departureDateTime == null) {
      showWarningSnackBar(context, 'Please select departure date and time');
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      showSignInRequiredSnackBar(context, 'Sign in to schedule a flight');
      return;
    }

    safeSetState(() => _isSaving = true);

    try {
      final service = ref.read(aetherServiceProvider);
      await service.createFlight(
        nodeId: myNode.userId ?? '!${myNode.nodeNum.toRadixString(16)}',
        nodeName: myNode.displayName,
        flightNumber: _flightNumberController.text.trim().toUpperCase(),
        departure: _departureController.text.trim().toUpperCase(),
        arrival: _arrivalController.text.trim().toUpperCase(),
        scheduledDeparture: departureDateTime,
        scheduledArrival: _buildArrivalDateTime(),
        userId: user.uid,
        userName: user.displayName,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context, true);
        showSuccessSnackBar(context, 'Flight scheduled!');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Error: $e');
      }
    } finally {
      safeSetState(() => _isSaving = false);
    }
  }

  // ===========================================================================
  // Build
  // ===========================================================================

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final myNode = _getMyNode();

    return GestureDetector(
      onTap: _dismissKeyboard,
      behavior: HitTestBehavior.opaque,
      child: GlassScaffold(
        title: 'Schedule Flight',
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.accentColor,
                    ),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      color: context.accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Info card
                    StatusBanner.accent(
                      title:
                          'Share your flight so others can try to receive your Meshtastic signal!',
                      icon: Icons.flight,
                      margin: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 24),

                    // My Node Section
                    _buildSectionHeader('Your Meshtastic Node'),
                    const SizedBox(height: 12),
                    _buildMyNodeCard(myNode),
                    const SizedBox(height: 24),

                    // Flight Info Section
                    _buildSectionHeader('Flight Information'),
                    const SizedBox(height: 12),

                    // Flight Number with Validation
                    _buildFlightNumberField(),
                    const SizedBox(height: 16),

                    // Airports row
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _departureController,
                            label: 'From',
                            hint: 'LAX',
                            icon: Icons.flight_takeoff,
                            maxLength: _maxAirportCodeLength,
                            textCapitalization: TextCapitalization.characters,
                            validator: (v) =>
                                _validateAirportCode(v, 'departure'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _arrivalController,
                            label: 'To',
                            hint: 'JFK',
                            icon: Icons.flight_land,
                            maxLength: _maxAirportCodeLength,
                            textCapitalization: TextCapitalization.characters,
                            validator: (v) =>
                                _validateAirportCode(v, 'arrival'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Departure Time Section
                    _buildSectionHeader('Departure Time'),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _buildDateButton(
                            label: 'Date',
                            value: _departureDate != null
                                ? dateFormat.format(_departureDate!)
                                : 'Select',
                            icon: Icons.calendar_today,
                            onTap: _selectDepartureDate,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDateButton(
                            label: 'Time',
                            value: _departureTime != null
                                ? timeFormat.format(
                                    DateTime(
                                      2000,
                                      1,
                                      1,
                                      _departureTime!.hour,
                                      _departureTime!.minute,
                                    ),
                                  )
                                : 'Select',
                            icon: Icons.access_time,
                            onTap: _selectDepartureTime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Arrival Time Section (optional)
                    _buildSectionHeaderWithClear(
                      'Arrival Time (Optional)',
                      showClear: _arrivalDate != null || _arrivalTime != null,
                      onClear: _clearArrivalDateTime,
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _buildDateButton(
                            label: 'Date',
                            value: _arrivalDate != null
                                ? dateFormat.format(_arrivalDate!)
                                : 'Select',
                            icon: Icons.calendar_today,
                            onTap: _selectArrivalDate,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDateButton(
                            label: 'Time',
                            value: _arrivalTime != null
                                ? timeFormat.format(
                                    DateTime(
                                      2000,
                                      1,
                                      1,
                                      _arrivalTime!.hour,
                                      _arrivalTime!.minute,
                                    ),
                                  )
                                : 'Select',
                            icon: Icons.access_time,
                            onTap: _selectArrivalTime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Notes Section
                    _buildSectionHeader('Additional Notes (Optional)'),
                    const SizedBox(height: 12),

                    _buildTextField(
                      controller: _notesController,
                      label: 'Notes',
                      hint: 'Window seat, left side. Running at 20dBm.',
                      icon: Icons.notes,
                      maxLines: 3,
                      maxLength: _maxNotesLength,
                    ),
                    const SizedBox(height: 32),

                    // Tips
                    _buildTipsCard(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // UI Components
  // ===========================================================================

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: context.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSectionHeaderWithClear(
    String title, {
    required bool showClear,
    required VoidCallback onClear,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (showClear)
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onClear();
            },
            child: Text(
              'Clear',
              style: TextStyle(
                color: context.primary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMyNodeCard(MeshNode? myNode) {
    final isConnected = myNode != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected ? context.accentColor : AppTheme.warningYellow,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color:
                  (isConnected ? context.accentColor : AppTheme.warningYellow)
                      .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isConnected ? Icons.memory : Icons.bluetooth_disabled,
              color: isConnected ? context.accentColor : AppTheme.warningYellow,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? myNode.displayName : 'No Device Connected',
                  style: TextStyle(
                    color: isConnected
                        ? context.textPrimary
                        : AppTheme.warningYellow,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  isConnected
                      ? (myNode.userId ??
                            '!${myNode.nodeNum.toRadixString(16)}')
                      : 'Connect your device to schedule a flight',
                  style: TextStyle(color: context.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (isConnected)
            Icon(Icons.check_circle, color: context.accentColor, size: 24),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    int maxLines = 1,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      onChanged: onChanged,
      textCapitalization: textCapitalization,
      style: TextStyle(color: context.textPrimary),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: context.textSecondary),
        hintStyle: TextStyle(color: context.textTertiary),
        prefixIcon: icon != null
            ? Icon(icon, color: context.textTertiary, size: 20)
            : null,
        filled: true,
        fillColor: context.card,
        counterStyle: TextStyle(color: context.textTertiary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.accentColor),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.errorRed),
        ),
      ),
    );
  }

  Widget _buildDateButton({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: context.textTertiary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: context.textTertiary, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: value == 'Select'
                          ? context.textTertiary
                          : context.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlightNumberField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTextField(
                controller: _flightNumberController,
                label: 'Flight Number',
                hint: 'e.g., UA123, DL456',
                icon: Icons.confirmation_number,
                maxLength: _maxFlightNumberLength,
                textCapitalization: TextCapitalization.characters,
                validator: _validateFlightNumber,
                onChanged: (_) => _clearValidation(),
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _buildValidateButton(),
            ),
          ],
        ),
        if (_validationResult != null) ...[
          const SizedBox(height: 8),
          _buildValidationStatus(),
        ],
      ],
    );
  }

  Widget _buildValidateButton() {
    return GestureDetector(
      onTap: _isValidating ? null : _validateFlight,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _isValidating
              ? context.border.withValues(alpha: 0.3)
              : context.accentColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isValidating
                ? context.border
                : context.accentColor.withValues(alpha: 0.3),
          ),
        ),
        child: _isValidating
            ? Padding(
                padding: const EdgeInsets.all(14),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.textSecondary,
                ),
              )
            : Icon(
                Icons.verified_outlined,
                color: context.accentColor,
                size: 24,
              ),
      ),
    );
  }

  Widget _buildValidationStatus() {
    final result = _validationResult!;
    final Color color;
    final IconData icon;

    switch (result.status) {
      case FlightValidationStatus.active:
        color = Colors.green;
        icon = Icons.flight_takeoff;
      case FlightValidationStatus.verified:
        color = Colors.green;
        icon = Icons.verified;
      case FlightValidationStatus.pending:
        color = Colors.blue;
        icon = Icons.schedule;
      case FlightValidationStatus.notFound:
        color = Colors.orange;
        icon = Icons.help_outline;
      case FlightValidationStatus.rateLimited:
        color = Colors.red;
        icon = Icons.timer_off;
      case FlightValidationStatus.error:
        color = Colors.red;
        icon = Icons.error_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              result.message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (result.isActive && result.position?.hasPosition == true) ...[
            const SizedBox(width: 8),
            Text(
              '${result.position!.altitudeFeet?.toStringAsFixed(0) ?? '--'} ft',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tips_and_updates,
                color: AppTheme.warningYellow,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Tips for best reception',
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTip('Get a window seat if possible'),
          _buildTip('Keep node near the window during flight'),
          _buildTip('Higher TX power = longer range'),
          _buildTip('Let others know your frequency/region'),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: context.textSecondary)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: context.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
