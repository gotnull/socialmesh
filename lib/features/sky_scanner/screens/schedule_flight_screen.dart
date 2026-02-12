// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/datetime_picker_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/node_selector_sheet.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../models/mesh_models.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../../utils/snackbar.dart';
import '../providers/sky_scanner_providers.dart';

// =============================================================================
// Constants
// =============================================================================

/// Maximum length for flight number (e.g., "UA1234" = 6 chars, allow up to 10)
const int _maxFlightNumberLength = 10;

/// Maximum length for airport codes (ICAO is 4, IATA is 3)
const int _maxAirportCodeLength = 4;

/// Maximum length for node name override
const int _maxNodeNameLength = 39;

/// Maximum length for notes field
const int _maxNotesLength = 500;

// =============================================================================
// Screen
// =============================================================================

/// Screen to schedule a new sky node flight
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
  final _nodeNameController = TextEditingController();
  final _departureController = TextEditingController();
  final _arrivalController = TextEditingController();
  final _notesController = TextEditingController();

  /// Selected node from NodeSelectorSheet
  MeshNode? _selectedNode;

  DateTime? _departureDate;
  TimeOfDay? _departureTime;
  DateTime? _arrivalDate;
  TimeOfDay? _arrivalTime;
  bool _isSaving = false;

  @override
  void dispose() {
    _flightNumberController.dispose();
    _nodeNameController.dispose();
    _departureController.dispose();
    _arrivalController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // Node Selection
  // ===========================================================================

  Future<void> _showNodeSelector() async {
    final selection = await NodeSelectorSheet.show(
      context,
      title: 'Select Your Node',
      allowBroadcast: false,
      initialSelection: _selectedNode?.nodeNum,
    );

    if (selection != null && selection.nodeNum != null && mounted) {
      final nodes = ref.read(nodesProvider);
      final node = nodes[selection.nodeNum];
      if (node != null) {
        safeSetState(() {
          _selectedNode = node;
          // Pre-fill node name if empty
          if (_nodeNameController.text.isEmpty) {
            _nodeNameController.text = node.displayName;
          }
        });
      }
    }
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

    if (_selectedNode == null) {
      showWarningSnackBar(context, 'Please select your Meshtastic node');
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
      final service = ref.read(skyScannerServiceProvider);
      await service.createSkyNode(
        nodeId:
            _selectedNode!.userId ??
            '!${_selectedNode!.nodeNum.toRadixString(16)}',
        nodeName: _nodeNameController.text.trim().isEmpty
            ? _selectedNode!.displayName
            : _nodeNameController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return GlassScaffold(
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

                  // Node Selection Section
                  _buildSectionHeader('Meshtastic Node'),
                  const SizedBox(height: 12),
                  _buildNodeSelector(),
                  const SizedBox(height: 16),

                  // Optional node name override
                  _buildTextField(
                    controller: _nodeNameController,
                    label: 'Display Name (Optional)',
                    hint: 'Override node name for this flight',
                    icon: Icons.label,
                    maxLength: _maxNodeNameLength,
                  ),
                  const SizedBox(height: 24),

                  // Flight Info Section
                  _buildSectionHeader('Flight Information'),
                  const SizedBox(height: 12),

                  // Flight Number
                  _buildTextField(
                    controller: _flightNumberController,
                    label: 'Flight Number',
                    hint: 'e.g., UA123, DL456',
                    icon: Icons.confirmation_number,
                    maxLength: _maxFlightNumberLength,
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) =>
                        v?.isEmpty == true ? 'Enter flight number' : null,
                  ),
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
                              v?.isEmpty == true ? 'Required' : null,
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
                              v?.isEmpty == true ? 'Required' : null,
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
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildNodeSelector() {
    final hasNode = _selectedNode != null;

    return GestureDetector(
      onTap: _showNodeSelector,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasNode ? context.accentColor : context.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (hasNode ? context.accentColor : context.textTertiary)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.memory,
                color: hasNode ? context.accentColor : context.textTertiary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasNode ? _selectedNode!.displayName : 'Select Node',
                    style: TextStyle(
                      color: hasNode
                          ? context.textPrimary
                          : context.textTertiary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (hasNode)
                    Text(
                      _selectedNode!.userId ??
                          '!${_selectedNode!.nodeNum.toRadixString(16)}',
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 12,
                      ),
                    )
                  else
                    Text(
                      'Tap to choose from your known nodes',
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.textTertiary, size: 24),
          ],
        ),
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
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
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
