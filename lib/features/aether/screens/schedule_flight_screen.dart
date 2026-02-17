// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/legal/legal_constants.dart';
import '../../../core/logging.dart';
import '../models/aether_flight.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_gradient_background.dart';
import '../../../core/widgets/datetime_picker_sheet.dart';
import '../../../core/widgets/glass_app_bar.dart';
import '../../../core/widgets/legal_document_sheet.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../models/mesh_models.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../../utils/snackbar.dart';
import '../data/airports.dart';
import '../providers/aether_providers.dart';
import '../services/opensky_service.dart';
import '../widgets/airport_picker_sheet.dart';
import '../widgets/flight_search_sheet.dart';

// =============================================================================
// Constants
// =============================================================================

/// Maximum length for flight number / ICAO callsign (e.g., "EXS49MY" = 7 chars)
const int _maxFlightNumberLength = 10;

/// Regex pattern for valid flight numbers and ICAO callsigns.
///
/// Accepts:
///   IATA style  — UA123, BA2490, DL1, 9W4567, AA100A
///   ICAO style  — UAL123, BAW2490, EXS49MY, T7MYC, RYR1862
///   General     — 2-10 alphanumeric chars starting with a letter or digit+letter
///
/// OpenSky returns ICAO callsigns which can have multi-character suffixes
/// (e.g., EXS49MY, FMY8050) so the pattern must be permissive.
final _flightNumberPattern = RegExp(r'^[A-Z0-9]{2,10}$');

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
  final _departureFocusNode = FocusNode();
  final _arrivalFocusNode = FocusNode();

  // Resolved airport objects for display feedback
  Airport? _resolvedDeparture;
  Airport? _resolvedArrival;

  DateTime? _departureDate;
  TimeOfDay? _departureTime;
  DateTime? _arrivalDate;
  TimeOfDay? _arrivalTime;
  bool _isSaving = false;

  // Flight validation state
  FlightValidationResult? _validationResult;
  bool _isValidating = false;

  // Route data completeness tracking
  bool _showIncompleteDataNotice = false;
  List<String> _missingFields = [];

  @override
  void initState() {
    super.initState();
    _departureController.addListener(_onDepartureChanged);
    _arrivalController.addListener(_onArrivalChanged);
  }

  @override
  void dispose() {
    _departureController.removeListener(_onDepartureChanged);
    _arrivalController.removeListener(_onArrivalChanged);
    _flightNumberController.dispose();
    _departureController.dispose();
    _arrivalController.dispose();
    _notesController.dispose();
    _departureFocusNode.dispose();
    _arrivalFocusNode.dispose();
    super.dispose();
  }

  void _onDepartureChanged() {
    final resolved = lookupAirport(_departureController.text);
    if (resolved != _resolvedDeparture) {
      safeSetState(() => _resolvedDeparture = resolved);
    }
  }

  void _onArrivalChanged() {
    final resolved = lookupAirport(_arrivalController.text);
    if (resolved != _resolvedArrival) {
      safeSetState(() => _resolvedArrival = resolved);
    }
  }

  void _swapAirports() {
    HapticFeedback.selectionClick();
    final depText = _departureController.text;
    final arrText = _arrivalController.text;
    _departureController.text = arrText;
    _arrivalController.text = depText;
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
    AppLogging.aether('Schedule: selecting departure date');
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
    AppLogging.aether('Schedule: selecting departure time');
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
    AppLogging.aether('Schedule: selecting arrival date');
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
    AppLogging.aether('Schedule: selecting arrival time');
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
      return 'Invalid format (e.g., UA123, EXS49MY)';
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

    if (lookupAirport(cleaned) == null) {
      return 'Unknown airport';
    }

    return null;
  }

  void _clearDepartureDate() {
    safeSetState(() {
      _departureDate = null;
    });
  }

  void _clearDepartureTime() {
    safeSetState(() {
      _departureTime = null;
    });
  }

  void _clearArrivalDate() {
    safeSetState(() {
      _arrivalDate = null;
    });
  }

  void _clearArrivalTime() {
    safeSetState(() {
      _arrivalTime = null;
    });
  }

  // ===========================================================================
  // Flight Validation (OpenSky Network)
  // ===========================================================================

  Future<void> _validateFlight() async {
    FocusScope.of(context).unfocus();
    final flightNumber = _flightNumberController.text.trim().toUpperCase();
    final departure = _departureController.text.trim().toUpperCase();

    AppLogging.aether(
      'Schedule: _validateFlight() — flight=$flightNumber dep=$departure',
    );

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

            _populateFromValidation(result);
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

        _populateFromValidation(result);
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

  /// Auto-populate form fields from validation result.
  void _populateFromValidation(FlightValidationResult result) {
    if (!result.isValid) return;

    // OpenSky's lastSeen is the most recent tracking ping — for active
    // flights this is essentially "right now", NOT the actual arrival time.
    // Only populate arrival time for completed / verified flights.
    final isActive = result.status == FlightValidationStatus.active;
    final bool arrivalIsRecentTracking;
    if (result.arrivalTime != null) {
      final elapsed = DateTime.now().difference(result.arrivalTime!).abs();
      arrivalIsRecentTracking = elapsed < const Duration(minutes: 10);
    } else {
      arrivalIsRecentTracking = false;
    }
    final hasValidArrival =
        result.arrivalTime != null && !isActive && !arrivalIsRecentTracking;

    safeSetState(() {
      // Populate departure airport if empty
      if (_departureController.text.isEmpty &&
          result.departureAirport != null) {
        _departureController.text = result.departureAirport!;
      }

      // Populate arrival airport if empty
      if (_arrivalController.text.isEmpty && result.arrivalAirport != null) {
        _arrivalController.text = result.arrivalAirport!;
      }

      // Populate departure date/time if we have it
      if (result.departureTime != null) {
        _departureDate = result.departureTime;
        _departureTime = TimeOfDay.fromDateTime(result.departureTime!);
      }

      // Populate arrival date/time ONLY for completed flights.
      // For active flights, arrivalTime is derived from lastSeen which is
      // just the latest tracking ping (≈ now), not the real arrival.
      if (hasValidArrival) {
        _arrivalDate = result.arrivalTime;
        _arrivalTime = TimeOfDay.fromDateTime(result.arrivalTime!);
      }
    });
  }

  void _showValidationFeedback(FlightValidationResult result) {
    AppLogging.aether(
      'Schedule: validation feedback — ${result.status.name}: ${result.message}',
    );
    HapticFeedback.mediumImpact();

    switch (result.status) {
      case FlightValidationStatus.active:
        final altFmt = result.position?.altitudeFeet != null
            ? NumberFormat(
                '#,##0',
              ).format(result.position!.altitudeFeet!.round())
            : '';
        showSuccessSnackBar(
          context,
          'Flight is currently active!${altFmt.isNotEmpty ? ' $altFmt ft' : ''}',
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

    // Cross-field route validation
    final depAirport = _resolvedDeparture;
    final arrAirport = _resolvedArrival;
    if (depAirport != null && arrAirport != null) {
      if (depAirport.iata == arrAirport.iata) {
        showWarningSnackBar(
          context,
          'Departure and arrival cannot be the same airport',
        );
        return;
      }
      final distKm = depAirport.distanceToKm(arrAirport);
      if (distKm < kMinRoutDistanceKm) {
        showWarningSnackBar(
          context,
          '${depAirport.iata} and ${arrAirport.iata} are only '
          '${distKm.round()} km apart — no commercial routes exist',
        );
        return;
      }
      if (distKm > kMaxRouteDistanceKm) {
        showWarningSnackBar(
          context,
          '${depAirport.iata} to ${arrAirport.iata} is '
          '${_formatDistance(distKm)} — exceeds maximum aircraft range',
        );
        return;
      }
    }

    AppLogging.aether('Schedule: _save() — saving flight');

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

    // --- Time validations ---
    final now = DateTime.now();

    // Departure must not be in the past (allow 5 min grace for form filling)
    const departureGrace = Duration(minutes: 5);
    if (departureDateTime.isBefore(now.subtract(departureGrace))) {
      showWarningSnackBar(context, 'Departure time is in the past');
      return;
    }

    // Departure must not be more than 365 days in the future
    if (departureDateTime.isAfter(now.add(const Duration(days: 365)))) {
      showWarningSnackBar(
        context,
        'Departure cannot be more than a year from now',
      );
      return;
    }

    final arrivalDateTime = _buildArrivalDateTime();

    if (arrivalDateTime != null) {
      // Arrival must be after departure
      if (!arrivalDateTime.isAfter(departureDateTime)) {
        showWarningSnackBar(context, 'Arrival must be after departure');
        return;
      }

      // Flight duration must be reasonable (max 24 hours)
      final flightDuration = arrivalDateTime.difference(departureDateTime);
      if (flightDuration > const Duration(hours: 24)) {
        showWarningSnackBar(
          context,
          'Flight duration exceeds 24 hours '
          '(${flightDuration.inHours}h ${flightDuration.inMinutes % 60}m)',
        );
        return;
      }

      // Flight must be at least 5 minutes
      if (flightDuration < const Duration(minutes: 5)) {
        showWarningSnackBar(
          context,
          'Flight duration must be at least 5 minutes',
        );
        return;
      }
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      showSignInRequiredSnackBar(context, 'Sign in to schedule a flight');
      return;
    }

    safeSetState(() => _isSaving = true);

    try {
      final service = ref.read(aetherServiceProvider);
      final flight = await service.createFlight(
        nodeId: myNode.userId ?? '!${myNode.nodeNum.toRadixString(16)}',
        nodeName: myNode.displayName,
        flightNumber: _flightNumberController.text.trim().toUpperCase(),
        departure: _departureController.text.trim().toUpperCase(),
        arrival: _arrivalController.text.trim().toUpperCase(),
        scheduledDeparture: departureDateTime,
        scheduledArrival: arrivalDateTime,
        userId: user.uid,
        userName: user.displayName,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (!mounted) return;

      // If OpenSky confirmed this flight is currently airborne,
      // activate it immediately instead of waiting for the periodic check.
      var activeFlight = flight;
      if (_validationResult?.isActive ?? false) {
        await service.updateFlightStatus(flight.id, isActive: true);
        activeFlight = flight.copyWith(isActive: true);
        AppLogging.aether(
          'Flight ${flight.flightNumber} auto-activated: '
          'OpenSky confirmed currently airborne',
        );
      }

      if (!mounted) return;

      HapticFeedback.mediumImpact();

      AppLogging.aether(
        'Schedule: flight saved — ${activeFlight.flightNumber} '
        '(active=${activeFlight.isActive})',
      );

      // Share to Aether API in background (non-blocking)
      _shareFlightInBackground(activeFlight);

      final messenger = ScaffoldMessenger.of(context);
      final status = activeFlight.isActive ? 'in flight!' : 'scheduled!';
      Navigator.of(context).pop(true);
      messenger.showSnackBar(SnackBar(content: Text('Flight $status')));
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

  /// Share the flight to aether.socialmesh.app in the background.
  ///
  /// This is fire-and-forget: if the share fails, the flight is still
  /// saved to Firestore. The user can always share later from the detail
  /// screen.
  void _shareFlightInBackground(AetherFlight flight) {
    AppLogging.aether('_shareFlightInBackground() called');
    AppLogging.aether('Flight: ${flight.flightNumber}');
    final shareService = ref.read(aetherShareServiceProvider);
    shareService
        .shareFlight(flight)
        .then((result) {
          AppLogging.aether('Background share succeeded: ${result.url}');
        })
        .catchError((Object e) {
          AppLogging.aether('Background share failed (non-fatal): $e');
        });
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final myNode = _getMyNode();
    final gradientColors = AccentColors.gradientFor(context.accentColor);

    return Scaffold(
      backgroundColor: context.background,
      bottomNavigationBar: _buildBottomBar(myNode, gradientColors),
      appBar: GlassAppBar(
        title: Text(
          'Schedule Flight',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.security_rounded,
              color: context.textSecondary,
              size: 20,
            ),
            tooltip: 'Your Responsibility',
            onPressed: () => LegalDocumentSheet.showTermsSection(
              context,
              LegalConstants.anchorAcceptableUse,
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: _dismissKeyboard,
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info card
                StatusBanner.accent(
                  title:
                      'Schedule your flight and share it on aether.socialmesh.app so the community can try to receive your signal!',
                  icon: Icons.flight,
                  margin: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),

                // Tips — right below the intro card
                _buildTipsCard(),
                const SizedBox(height: 16),

                // Incomplete route data notice (if applicable)
                if (_showIncompleteDataNotice) ...[
                  _buildIncompleteDataNotice(),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 8),

                // Flight Info Section
                _buildSectionHeader('Flight Information'),
                const SizedBox(height: 12),

                // Flight Number with Validation
                _buildFlightNumberField(),
                const SizedBox(height: 16),

                // Airports row with swap button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildAirportAutocomplete(
                        controller: _departureController,
                        focusNode: _departureFocusNode,
                        label: 'From',
                        hint: 'LAX',
                        icon: Icons.flight_takeoff,
                        pickerTitle: 'Departure Airport',
                        resolvedAirport: _resolvedDeparture,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 12,
                        left: 5,
                        right: 5,
                      ),
                      child: IconButton(
                        onPressed: _swapAirports,
                        icon: Icon(
                          Icons.swap_horiz,
                          color: context.accentColor,
                          size: 22,
                        ),
                        tooltip: 'Swap airports',
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    Expanded(
                      child: _buildAirportAutocomplete(
                        controller: _arrivalController,
                        focusNode: _arrivalFocusNode,
                        label: 'To',
                        hint: 'JFK',
                        icon: Icons.flight_land,
                        pickerTitle: 'Arrival Airport',
                        resolvedAirport: _resolvedArrival,
                      ),
                    ),
                  ],
                ),

                // Route info / warnings
                _buildRouteInfo(),
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
                        onClear: _departureDate != null
                            ? _clearDepartureDate
                            : null,
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
                        onClear: _departureTime != null
                            ? _clearDepartureTime
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Arrival Time Section (optional)
                _buildSectionHeader('Arrival Time (Optional)'),
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
                        onClear: _arrivalDate != null
                            ? _clearArrivalDate
                            : null,
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
                        onClear: _arrivalTime != null
                            ? _clearArrivalTime
                            : null,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Bottom Bar (node info + save button)
  // ===========================================================================

  Widget _buildBottomBar(MeshNode? myNode, List<Color> gradientColors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildMyNodeBar(myNode),
        Container(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            12 + MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: context.background,
            border: Border(
              top: BorderSide(color: context.border.withValues(alpha: 0.2)),
            ),
          ),
          child: GestureDetector(
            onTap: !_isSaving && myNode != null ? _save : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: !_isSaving && myNode != null
                    ? LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [gradientColors[0], gradientColors[1]],
                      )
                    : null,
                color: !_isSaving && myNode != null
                    ? null
                    : context.border.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                boxShadow: !_isSaving && myNode != null
                    ? [
                        BoxShadow(
                          color: gradientColors[0].withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: _isSaving
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.flight,
                          size: 22,
                          color: myNode != null
                              ? Colors.white
                              : context.textTertiary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Schedule Flight',
                          style: TextStyle(
                            color: myNode != null
                                ? Colors.white
                                : context.textTertiary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  /// Fixed bar showing the selected Meshtastic node.
  Widget _buildMyNodeBar(MeshNode? myNode) {
    final isConnected = myNode != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: context.card,
        border: Border(
          top: BorderSide(color: context.border.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color:
                  (isConnected ? context.accentColor : AppTheme.warningYellow)
                      .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isConnected ? Icons.memory : Icons.bluetooth_disabled,
              color: isConnected ? context.accentColor : AppTheme.warningYellow,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? myNode.displayName : 'No Device Connected',
                  style: TextStyle(
                    color: isConnected
                        ? context.textPrimary
                        : AppTheme.warningYellow,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  isConnected
                      ? (myNode.userId ??
                            '!${myNode.nodeNum.toRadixString(16)}')
                      : 'Connect to schedule a flight',
                  style: TextStyle(color: context.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (isConnected)
            Icon(Icons.check_circle, color: context.accentColor, size: 22),
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

  /// Builds an airport field with inline autocomplete suggestions.
  ///
  /// As the user types (2+ chars), matching airports appear in a dropdown.
  /// A resolved airport name is shown below the field as helper text.
  /// The browse button opens the full scrollable picker sheet.
  Widget _buildAirportAutocomplete({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    required String pickerTitle,
    Airport? resolvedAirport,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return RawAutocomplete<Airport>(
              textEditingController: controller,
              focusNode: focusNode,
              displayStringForOption: (airport) => airport.iata,
              optionsBuilder: (textEditingValue) {
                final query = textEditingValue.text.trim();
                if (query.length < 2) return const Iterable<Airport>.empty();
                return kAirports.where((a) => a.matches(query)).take(5);
              },
              optionsViewBuilder: (ctx, onSelected, options) {
                return _AirportOptionsOverlay(
                  options: options.toList(),
                  onSelected: onSelected,
                  fieldWidth: constraints.maxWidth,
                );
              },
              fieldViewBuilder:
                  (ctx, textController, fieldFocusNode, onFieldSubmitted) {
                    return TextFormField(
                      controller: textController,
                      focusNode: fieldFocusNode,
                      maxLength: _maxAirportCodeLength,
                      textCapitalization: TextCapitalization.characters,
                      style: TextStyle(color: this.context.textPrimary),
                      validator: (v) =>
                          _validateAirportCode(v, label.toLowerCase()),
                      onFieldSubmitted: (_) => onFieldSubmitted(),
                      decoration: InputDecoration(
                        labelText: label,
                        hintText: hint,
                        labelStyle: TextStyle(
                          color: this.context.textSecondary,
                        ),
                        hintStyle: TextStyle(color: this.context.textTertiary),
                        prefixIcon: Icon(
                          icon,
                          color: this.context.textTertiary,
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              _openAirportPicker(controller, pickerTitle),
                          icon: Icon(
                            Icons.list_alt,
                            color: this.context.textTertiary,
                            size: 20,
                          ),
                          tooltip: 'Browse airports',
                        ),
                        filled: true,
                        fillColor: this.context.card,
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: this.context.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: this.context.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: this.context.accentColor,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.errorRed),
                        ),
                      ),
                    );
                  },
            );
          },
        ),
        // Resolved airport name feedback
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topLeft,
          child: resolvedAirport != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 12,
                        color: context.accentColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          resolvedAirport.city,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.accentColor,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  /// Formats distance in km, or thousands of km for large values.
  static String _formatDistance(double km) {
    if (km >= 1000) {
      return '${(km / 1000).toStringAsFixed(1)}k km';
    }
    return '${km.round()} km';
  }

  /// Estimates flight time from great-circle distance.
  /// Uses 850 km/h cruise speed + 30 min for taxi/climb/descent.
  static String _estimateFlightTime(double km) {
    const cruiseSpeedKmh = 850.0;
    const overheadMinutes = 30;
    final totalMinutes = (km / cruiseSpeedKmh * 60).round() + overheadMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) return '${minutes}min';
    return '${hours}h ${minutes}min';
  }

  /// Builds route info feedback shown below the airport fields.
  Widget _buildRouteInfo() {
    final dep = _resolvedDeparture;
    final arr = _resolvedArrival;
    if (dep == null || arr == null) return const SizedBox.shrink();
    if (dep.iata == arr.iata) {
      return _buildRouteChip(
        icon: Icons.error_outline,
        color: AppTheme.errorRed,
        text: 'Same airport',
      );
    }

    final distKm = dep.distanceToKm(arr);

    if (distKm < kMinRoutDistanceKm) {
      return _buildRouteChip(
        icon: Icons.error_outline,
        color: AppTheme.errorRed,
        text:
            '${dep.iata} and ${arr.iata} are ${distKm.round()} km apart — '
            'too close for a commercial flight',
      );
    }

    if (distKm > kMaxRouteDistanceKm) {
      return _buildRouteChip(
        icon: Icons.error_outline,
        color: AppTheme.errorRed,
        text: '${_formatDistance(distKm)} — exceeds maximum aircraft range',
      );
    }

    // Valid route — show distance + estimated flight time
    return _buildRouteChip(
      icon: Icons.route,
      color: context.accentColor,
      text: '${_formatDistance(distKm)} · ~${_estimateFlightTime(distKm)}',
    );
  }

  Widget _buildRouteChip({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAirportPicker(
    TextEditingController controller,
    String title,
  ) async {
    // Capture context before async gap
    final ctx = context;
    final airport = await AirportPickerSheet.show(
      ctx,
      title: title,
      initialCode: controller.text,
    );
    if (!mounted) return;
    if (airport != null) {
      controller.text = airport.iata;
    }
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
    VoidCallback? onClear,
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
            if (onClear != null)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onClear();
                },
                child: Icon(Icons.close, color: context.textTertiary, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _searchFlights() async {
    AppLogging.aether('Schedule: opening flight search sheet');
    final result = await FlightSearchSheet.show(context);
    if (result != null && mounted) {
      AppLogging.aether(
        'Schedule: flight selected from search — ${result.callsign}',
      );
      safeSetState(() {
        _flightNumberController.text = result.callsign;

        // Convert ActiveFlightInfo to FlightValidationResult to avoid
        // redundant API call. User already selected an active flight.
        _validationResult = FlightValidationResult(
          status: FlightValidationStatus.active,
          message: 'Active flight selected from search',
          position: FlightPositionData(
            callsign: result.callsign,
            icao24: result.icao24,
            originCountry: result.originCountry,
            latitude: result.latitude,
            longitude: result.longitude,
            altitude: result.altitude,
            onGround: result.onGround,
            velocity: result.velocity,
            lastContact: DateTime.now(),
          ),
          icao24: result.icao24,
          originCountry: result.originCountry,
        );
      });

      // Show feedback with the selected flight's altitude
      if (result.altitudeFeet != null && !result.onGround) {
        final altFmt = NumberFormat(
          '#,##0',
        ).format(result.altitudeFeet!.round());
        showSuccessSnackBar(context, 'Flight selected! $altFmt ft');
        HapticFeedback.mediumImpact();
      } else if (result.onGround) {
        showInfoSnackBar(context, 'Flight is currently on the ground');
        HapticFeedback.lightImpact();
      }

      // Look up route data (airports + times) in the background.
      // The search sheet only provides callsign + position; the route
      // endpoint gives us departure/arrival airports and times.
      if (result.icao24 != null) {
        _lookupRouteForSearchResult(result.icao24!);
      }
    }
  }

  /// Fetches route info (airports + times) for a flight selected from search.
  /// Runs in background so the UI doesn't block — fields populate when ready.
  Future<void> _lookupRouteForSearchResult(String icao24) async {
    AppLogging.aether('Schedule: looking up route for icao24=$icao24');
    try {
      final routeInfo = await OpenSkyService().lookupAircraftRoute(icao24);
      if (routeInfo == null || !mounted) {
        AppLogging.aether('Schedule: route lookup returned null');
        return;
      }

      // OpenSky's firstSeen/lastSeen are TRACKING timestamps, not scheduled
      // airline times. For an active (in-progress) flight:
      //   firstSeen  = when the transponder was first detected  (≈ takeoff)
      //   lastSeen   = the most recent tracking data point      (≈ NOW)
      // So lastSeen is only a meaningful "arrival time" for COMPLETED flights
      // where the aircraft has landed and tracking stopped.
      final isActive =
          _validationResult?.status == FlightValidationStatus.active;

      // Determine whether lastSeen is a real arrival or just "now".
      // If lastSeen is within 10 minutes of the current time, the flight is
      // still being tracked — lastSeen is NOT an arrival time.
      final bool lastSeenIsRecentTracking;
      if (routeInfo.lastSeen != null) {
        final lastSeenDt = DateTime.fromMillisecondsSinceEpoch(
          routeInfo.lastSeen! * 1000,
        );
        final elapsed = DateTime.now().difference(lastSeenDt).abs();
        lastSeenIsRecentTracking = elapsed < const Duration(minutes: 10);
      } else {
        lastSeenIsRecentTracking = false;
      }

      // Only treat lastSeen as a valid arrival time when the flight is NOT
      // active and lastSeen is NOT just the current tracking timestamp.
      final bool hasValidArrivalTime =
          routeInfo.arrivalTime != null &&
          !isActive &&
          !lastSeenIsRecentTracking;

      AppLogging.aether(
        'Schedule: processing route data — '
        'dep=${routeInfo.estDepartureAirport} '
        'arr=${routeInfo.estArrivalAirport} '
        'depTime=${routeInfo.departureTime} '
        'arrTime=${routeInfo.arrivalTime} '
        'isActive=$isActive lastSeenIsRecentTracking=$lastSeenIsRecentTracking '
        'hasValidArrivalTime=$hasValidArrivalTime',
      );

      safeSetState(() {
        // Populate departure airport if empty (defensive: check for null AND empty string)
        if (_departureController.text.isEmpty &&
            routeInfo.estDepartureAirport != null &&
            routeInfo.estDepartureAirport!.trim().isNotEmpty) {
          _departureController.text = routeInfo.estDepartureAirport!;
          AppLogging.aether('Schedule: populated departure airport');
        }

        // Populate arrival airport if empty (defensive: check for null AND empty string)
        if (_arrivalController.text.isEmpty &&
            routeInfo.estArrivalAirport != null &&
            routeInfo.estArrivalAirport!.trim().isNotEmpty) {
          _arrivalController.text = routeInfo.estArrivalAirport!;
          AppLogging.aether('Schedule: populated arrival airport');
        }

        // Populate departure date/time from firstSeen (≈ takeoff time).
        // This is generally reliable for both active and completed flights.
        if (routeInfo.departureTime != null) {
          _departureDate = routeInfo.departureTime;
          _departureTime = TimeOfDay.fromDateTime(routeInfo.departureTime!);
          AppLogging.aether(
            'Schedule: populated departure time: ${routeInfo.departureTime}',
          );
        } else {
          AppLogging.aether('Schedule: no departure time available');
        }

        // Populate arrival date/time ONLY for completed flights.
        // For active flights, lastSeen is just the latest tracking ping
        // (basically "right now"), NOT the actual arrival time.
        if (hasValidArrivalTime) {
          _arrivalDate = routeInfo.arrivalTime;
          _arrivalTime = TimeOfDay.fromDateTime(routeInfo.arrivalTime!);
          AppLogging.aether(
            'Schedule: populated arrival time: ${routeInfo.arrivalTime}',
          );
        } else {
          AppLogging.aether(
            'Schedule: skipping arrival time — flight is '
            '${isActive ? "active (lastSeen is just current tracking)" : "missing arrival data"}',
          );
        }

        // Update validation result with route data
        if (_validationResult != null) {
          _validationResult = FlightValidationResult(
            status: _validationResult!.status,
            message: _validationResult!.message,
            position: _validationResult!.position,
            icao24: _validationResult!.icao24,
            originCountry: _validationResult!.originCountry,
            departureAirport:
                routeInfo.estDepartureAirport ??
                _validationResult!.departureAirport,
            arrivalAirport:
                routeInfo.estArrivalAirport ??
                _validationResult!.arrivalAirport,
            departureTime:
                routeInfo.departureTime ?? _validationResult!.departureTime,
            // Only propagate arrival time if it's a real arrival, not a
            // tracking timestamp masquerading as one.
            arrivalTime: hasValidArrivalTime
                ? routeInfo.arrivalTime
                : _validationResult!.arrivalTime,
          );
        }
      });

      if (mounted) {
        final parts = <String>[];
        if (routeInfo.estDepartureAirport != null) {
          parts.add(routeInfo.estDepartureAirport!);
        }
        if (routeInfo.estArrivalAirport != null) {
          parts.add(routeInfo.estArrivalAirport!);
        }
        if (parts.isNotEmpty) {
          showSuccessSnackBar(context, 'Route found: ${parts.join(" → ")}');
        }
      }
    } catch (e) {
      AppLogging.aether('Route lookup after search failed: $e');
      // Show notice that route lookup failed
      if (mounted) {
        safeSetState(() {
          _missingFields = ['departure airport', 'arrival airport', 'times'];
          _showIncompleteDataNotice = true;
        });
      }
    }

    // Check which fields are still missing after route lookup
    if (mounted) {
      final missing = <String>[];
      if (_departureController.text.trim().isEmpty) {
        missing.add('departure airport');
      }
      if (_arrivalController.text.trim().isEmpty) {
        missing.add('arrival airport');
      }
      if (_departureDate == null || _departureTime == null) {
        missing.add('departure time');
      }
      if (_arrivalDate == null || _arrivalTime == null) {
        missing.add('arrival time');
      }

      if (missing.isNotEmpty) {
        safeSetState(() {
          _missingFields = missing;
          _showIncompleteDataNotice = true;
        });
      }
    }
  }

  Widget _buildFlightNumberField() {
    final hasFlightNumber = _flightNumberController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Full-width flight number field with inline actions
        TextFormField(
          controller: _flightNumberController,
          maxLength: _maxFlightNumberLength,
          textCapitalization: TextCapitalization.characters,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
          validator: _validateFlightNumber,
          onChanged: (_) {
            _clearValidation();
            setState(() {});
          },
          decoration: InputDecoration(
            labelText: 'Flight Number',
            hintText: 'UA123',
            labelStyle: TextStyle(color: context.textSecondary),
            hintStyle: TextStyle(
              color: context.textTertiary,
              fontSize: 18,
              fontWeight: FontWeight.w400,
              letterSpacing: 1.2,
            ),
            prefixIcon: Icon(
              Icons.flight,
              color: context.textTertiary,
              size: 22,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Validate button — only visible when there's text
                if (hasFlightNumber)
                  _buildInlineAction(
                    icon: Icons.verified_outlined,
                    isLoading: _isValidating,
                    onTap:
                        (_isValidating || (_validationResult?.isValid ?? false))
                        ? null
                        : _validateFlight,
                    tooltip: _validationResult?.isValid ?? false
                        ? 'Already validated'
                        : 'Validate flight',
                  ),
                // Search button — gradient pill, always visible
                _buildSearchPill(),
                const SizedBox(width: 8),
              ],
            ),
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
        ),
        if (_validationResult != null) ...[
          const SizedBox(height: 8),
          _buildValidationStatus(),
        ],
      ],
    );
  }

  /// Compact inline icon action for use inside input field suffixes.
  Widget _buildInlineAction({
    required IconData icon,
    required VoidCallback? onTap,
    bool isLoading = false,
    String? tooltip,
  }) {
    final child = GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.textSecondary,
                ),
              )
            : Icon(icon, color: context.accentColor, size: 22),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: child);
    }
    return child;
  }

  /// Gradient pill button for flight search — eye-catching and tappable.
  Widget _buildSearchPill() {
    final gradientColors = AccentColors.gradientFor(context.accentColor);
    final gradient = LinearGradient(
      colors: [gradientColors[0], gradientColors[1]],
    );

    return Tooltip(
      message: 'Search flights',
      child: GestureDetector(
        onTap: _searchFlights,
        child: AnimatedGradientBackground(
          gradient: gradient,
          animate: true,
          enabled: true,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search, size: 16, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'Search',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
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
              '${result.position!.altitudeFeet != null ? NumberFormat('#,##0').format(result.position!.altitudeFeet!.round()) : '--'} ft',
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

  Widget _buildIncompleteDataNotice() {
    final missingText = _missingFields.length == 1
        ? _missingFields.first
        : _missingFields.length == 2
        ? '${_missingFields[0]} and ${_missingFields[1]}'
        : '${_missingFields.sublist(0, _missingFields.length - 1).join(', ')}, and ${_missingFields.last}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningYellow.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.warningYellow.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppTheme.warningYellow, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Incomplete Flight Data',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Could not auto-fill $missingText from OpenSky Network. Please enter these details manually below.',
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              safeSetState(() => _showIncompleteDataNotice = false);
            },
            child: Icon(Icons.close, color: context.textTertiary, size: 18),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Airport Autocomplete Overlay
// =============================================================================

/// Dropdown overlay for airport autocomplete suggestions.
///
/// Positioned directly below the text field. Shows up to 5 matching airports
/// with IATA badge, city name, and full airport name.
class _AirportOptionsOverlay extends StatelessWidget {
  final List<Airport> options;
  final ValueChanged<Airport> onSelected;
  final double fieldWidth;

  const _AirportOptionsOverlay({
    required this.options,
    required this.onSelected,
    required this.fieldWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: context.card,
          child: Container(
            width: fieldWidth,
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: context.border),
                itemBuilder: (context, index) {
                  final airport = options[index];
                  return InkWell(
                    onTap: () => onSelected(airport),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          // IATA badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: context.accentColor.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              airport.iata,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFamily: AppTheme.fontFamily,
                                color: context.accentColor,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // City + airport name
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  airport.city,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: context.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  airport.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.textTertiary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
