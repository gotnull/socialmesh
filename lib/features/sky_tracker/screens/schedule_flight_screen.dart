import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../providers/auth_providers.dart';
import '../providers/sky_tracker_providers.dart';

/// Screen to schedule a new sky node flight
class ScheduleFlightScreen extends ConsumerStatefulWidget {
  const ScheduleFlightScreen({super.key});

  @override
  ConsumerState<ScheduleFlightScreen> createState() =>
      _ScheduleFlightScreenState();
}

class _ScheduleFlightScreenState extends ConsumerState<ScheduleFlightScreen> {
  final _formKey = GlobalKey<FormState>();
  final _flightNumberController = TextEditingController();
  final _nodeIdController = TextEditingController();
  final _nodeNameController = TextEditingController();
  final _departureController = TextEditingController();
  final _arrivalController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _departureDate;
  TimeOfDay? _departureTime;
  DateTime? _arrivalDate;
  TimeOfDay? _arrivalTime;
  bool _isSaving = false;

  @override
  void dispose() {
    _flightNumberController.dispose();
    _nodeIdController.dispose();
    _nodeNameController.dispose();
    _departureController.dispose();
    _arrivalController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDepartureDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _departureDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: context.accentColor,
            surface: context.card,
          ),
        ),
        child: child!,
      ),
    );

    if (date != null) {
      setState(() => _departureDate = date);
      if (_departureTime == null) {
        _selectDepartureTime();
      }
    }
  }

  Future<void> _selectDepartureTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _departureTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: context.accentColor,
            surface: context.card,
          ),
        ),
        child: child!,
      ),
    );

    if (time != null) {
      setState(() => _departureTime = time);
    }
  }

  Future<void> _selectArrivalDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _arrivalDate ?? _departureDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: context.accentColor,
            surface: context.card,
          ),
        ),
        child: child!,
      ),
    );

    if (date != null) {
      setState(() => _arrivalDate = date);
      if (_arrivalTime == null) {
        _selectArrivalTime();
      }
    }
  }

  Future<void> _selectArrivalTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _arrivalTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: context.accentColor,
            surface: context.card,
          ),
        ),
        child: child!,
      ),
    );

    if (time != null) {
      setState(() => _arrivalTime = time);
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final departureDateTime = _buildDepartureDateTime();
    if (departureDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select departure date and time')),
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to schedule a flight')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final service = ref.read(skyTrackerServiceProvider);
      await service.createSkyNode(
        nodeId: _nodeIdController.text.trim(),
        nodeName: _nodeNameController.text.trim().isEmpty
            ? null
            : _nodeNameController.text.trim(),
        flightNumber: _flightNumberController.text.trim(),
        departure: _departureController.text.trim(),
        arrival: _arrivalController.text.trim(),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Flight scheduled! ✈️'),
            backgroundColor: context.accentColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        title: Text(
          'Schedule Flight',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
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
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.accentColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.flight, color: context.accentColor),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Share your flight so others can try to receive your Meshtastic signal!',
                      style: TextStyle(
                        color: context.accentColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // Flight Info Section
            _buildSectionHeader('Flight Information'),
            const SizedBox(height: 12),

            // Flight Number
            _buildTextField(
              controller: _flightNumberController,
              label: 'Flight Number',
              hint: 'e.g., UA123, DL456',
              icon: Icons.confirmation_number,
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
                    maxLength: 4,
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _arrivalController,
                    label: 'To',
                    hint: 'JFK',
                    icon: Icons.flight_land,
                    maxLength: 4,
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
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

            // Node Info Section
            _buildSectionHeader('Meshtastic Node'),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _nodeIdController,
              label: 'Node ID',
              hint: '!abcd1234',
              icon: Icons.memory,
              validator: (v) => v?.isEmpty == true ? 'Enter node ID' : null,
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _nodeNameController,
              label: 'Node Name (Optional)',
              hint: 'My Travel Node',
              icon: Icons.label,
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
            ),
            const SizedBox(height: 32),

            // Tips
            Container(
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
                          color: Colors.white,
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
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

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
      style: TextStyle(color: Colors.white),
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
        counterText: '',
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
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: context.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: value == 'Select'
                          ? context.textTertiary
                          : Colors.white,
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
