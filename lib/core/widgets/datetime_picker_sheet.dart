// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'app_bottom_sheet.dart';

// =============================================================================
// Date Picker Sheet
// =============================================================================

/// A glass-styled date picker bottom sheet.
///
/// Uses CupertinoPicker wheels for smooth scrolling and consistent
/// appearance with the app's aesthetic.
class DatePickerSheet extends StatefulWidget {
  final DateTime? initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String title;

  const DatePickerSheet({
    super.key,
    this.initialDate,
    this.firstDate,
    this.lastDate,
    this.title = 'Select Date',
  });

  /// Shows the date picker and returns the selected date.
  static Future<DateTime?> show(
    BuildContext context, {
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    String title = 'Select Date',
  }) {
    return AppBottomSheet.show<DateTime>(
      context: context,
      padding: EdgeInsets.zero,
      child: DatePickerSheet(
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        title: title,
      ),
    );
  }

  @override
  State<DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<DatePickerSheet> {
  late DateTime _selectedDate;
  late DateTime _firstDate;
  late DateTime _lastDate;

  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _dayController;
  late FixedExtentScrollController _yearController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _firstDate = widget.firstDate ?? DateTime(now.year - 10);
    _lastDate = widget.lastDate ?? DateTime(now.year + 10);
    _selectedDate = widget.initialDate ?? now;

    // Clamp to valid range
    if (_selectedDate.isBefore(_firstDate)) _selectedDate = _firstDate;
    if (_selectedDate.isAfter(_lastDate)) _selectedDate = _lastDate;

    _monthController = FixedExtentScrollController(
      initialItem: _selectedDate.month - 1,
    );
    _dayController = FixedExtentScrollController(
      initialItem: _selectedDate.day - 1,
    );
    _yearController = FixedExtentScrollController(
      initialItem: _selectedDate.year - _firstDate.year,
    );
  }

  @override
  void dispose() {
    _monthController.dispose();
    _dayController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  void _onDateChanged() {
    final year = _firstDate.year + _yearController.selectedItem;
    final month = _monthController.selectedItem + 1;
    final maxDay = _daysInMonth(year, month);
    var day = _dayController.selectedItem + 1;
    if (day > maxDay) day = maxDay;

    setState(() {
      _selectedDate = DateTime(year, month, day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final yearCount = _lastDate.year - _firstDate.year + 1;
    final daysInCurrentMonth = _daysInMonth(
      _selectedDate.year,
      _selectedDate.month,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        _PickerHeader(
          title: widget.title,
          onCancel: () => Navigator.pop(context),
          onConfirm: () {
            HapticFeedback.mediumImpact();
            Navigator.pop(context, _selectedDate);
          },
        ),

        // Picker wheels
        SizedBox(
          height: 200,
          child: Row(
            children: [
              // Month
              Expanded(
                flex: 3,
                child: _PickerWheel(
                  controller: _monthController,
                  itemCount: 12,
                  onSelectedItemChanged: (_) => _onDateChanged(),
                  itemBuilder: (index) => months[index],
                ),
              ),

              // Day
              Expanded(
                flex: 2,
                child: _PickerWheel(
                  controller: _dayController,
                  itemCount: daysInCurrentMonth,
                  onSelectedItemChanged: (_) => _onDateChanged(),
                  itemBuilder: (index) => '${index + 1}',
                ),
              ),

              // Year
              Expanded(
                flex: 2,
                child: _PickerWheel(
                  controller: _yearController,
                  itemCount: yearCount,
                  onSelectedItemChanged: (_) => _onDateChanged(),
                  itemBuilder: (index) => '${_firstDate.year + index}',
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
      ],
    );
  }
}

// =============================================================================
// Time Picker Sheet
// =============================================================================

/// A glass-styled time picker bottom sheet.
///
/// Uses CupertinoPicker wheels for smooth scrolling and consistent
/// appearance with the app's aesthetic.
class TimePickerSheet extends StatefulWidget {
  final TimeOfDay? initialTime;
  final String title;
  final bool use24HourFormat;

  const TimePickerSheet({
    super.key,
    this.initialTime,
    this.title = 'Select Time',
    this.use24HourFormat = false,
  });

  /// Shows the time picker and returns the selected time.
  static Future<TimeOfDay?> show(
    BuildContext context, {
    TimeOfDay? initialTime,
    String title = 'Select Time',
    bool use24HourFormat = false,
  }) {
    return AppBottomSheet.show<TimeOfDay>(
      context: context,
      padding: EdgeInsets.zero,
      child: TimePickerSheet(
        initialTime: initialTime,
        title: title,
        use24HourFormat: use24HourFormat,
      ),
    );
  }

  @override
  State<TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<TimePickerSheet> {
  late int _hour;
  late int _minute;
  late bool _isPM;

  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTime ?? TimeOfDay.now();

    if (widget.use24HourFormat) {
      _hour = initial.hour;
      _isPM = false;
    } else {
      _isPM = initial.hour >= 12;
      _hour = initial.hourOfPeriod;
      if (_hour == 0) _hour = 12;
    }
    _minute = initial.minute;

    _hourController = FixedExtentScrollController(
      initialItem: widget.use24HourFormat ? _hour : _hour - 1,
    );
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  TimeOfDay _buildTimeOfDay() {
    int hour;
    if (widget.use24HourFormat) {
      hour = _hour;
    } else {
      hour = _hour % 12;
      if (_isPM) hour += 12;
    }
    return TimeOfDay(hour: hour, minute: _minute);
  }

  @override
  Widget build(BuildContext context) {
    final hourCount = widget.use24HourFormat ? 24 : 12;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        _PickerHeader(
          title: widget.title,
          onCancel: () => Navigator.pop(context),
          onConfirm: () {
            HapticFeedback.mediumImpact();
            Navigator.pop(context, _buildTimeOfDay());
          },
        ),

        // Picker wheels
        SizedBox(
          height: 200,
          child: Row(
            children: [
              // Hour
              Expanded(
                flex: 2,
                child: _PickerWheel(
                  controller: _hourController,
                  itemCount: hourCount,
                  onSelectedItemChanged: (index) {
                    setState(() {
                      _hour = widget.use24HourFormat ? index : index + 1;
                    });
                  },
                  itemBuilder: (index) {
                    final h = widget.use24HourFormat ? index : index + 1;
                    return h.toString().padLeft(2, '0');
                  },
                ),
              ),

              // Colon separator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  ':',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ),

              // Minute
              Expanded(
                flex: 2,
                child: _PickerWheel(
                  controller: _minuteController,
                  itemCount: 60,
                  onSelectedItemChanged: (index) {
                    setState(() => _minute = index);
                  },
                  itemBuilder: (index) => index.toString().padLeft(2, '0'),
                ),
              ),

              // AM/PM selector (12-hour format only)
              if (!widget.use24HourFormat) ...[
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _AmPmSelector(
                    isPM: _isPM,
                    onChanged: (isPM) => setState(() => _isPM = isPM),
                  ),
                ),
              ],
            ],
          ),
        ),

        SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
      ],
    );
  }
}

// =============================================================================
// DateTime Picker Sheet (Combined)
// =============================================================================

/// A glass-styled combined date and time picker bottom sheet.
class DateTimePickerSheet extends StatefulWidget {
  final DateTime? initialDateTime;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String title;
  final bool use24HourFormat;

  const DateTimePickerSheet({
    super.key,
    this.initialDateTime,
    this.firstDate,
    this.lastDate,
    this.title = 'Select Date & Time',
    this.use24HourFormat = false,
  });

  /// Shows the datetime picker and returns the selected datetime.
  static Future<DateTime?> show(
    BuildContext context, {
    DateTime? initialDateTime,
    DateTime? firstDate,
    DateTime? lastDate,
    String title = 'Select Date & Time',
    bool use24HourFormat = false,
  }) {
    return AppBottomSheet.show<DateTime>(
      context: context,
      padding: EdgeInsets.zero,
      child: DateTimePickerSheet(
        initialDateTime: initialDateTime,
        firstDate: firstDate,
        lastDate: lastDate,
        title: title,
        use24HourFormat: use24HourFormat,
      ),
    );
  }

  @override
  State<DateTimePickerSheet> createState() => _DateTimePickerSheetState();
}

class _DateTimePickerSheetState extends State<DateTimePickerSheet> {
  late DateTime _selectedDate;
  late int _hour;
  late int _minute;
  late bool _isPM;

  late DateTime _firstDate;
  late DateTime _lastDate;

  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _dayController;
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _firstDate = widget.firstDate ?? DateTime(now.year - 10);
    _lastDate = widget.lastDate ?? DateTime(now.year + 10);

    final initial = widget.initialDateTime ?? now;
    _selectedDate = DateTime(initial.year, initial.month, initial.day);

    // Clamp to valid range
    if (_selectedDate.isBefore(_firstDate)) {
      _selectedDate = DateTime(
        _firstDate.year,
        _firstDate.month,
        _firstDate.day,
      );
    }
    if (_selectedDate.isAfter(_lastDate)) {
      _selectedDate = DateTime(_lastDate.year, _lastDate.month, _lastDate.day);
    }

    if (widget.use24HourFormat) {
      _hour = initial.hour;
      _isPM = false;
    } else {
      _isPM = initial.hour >= 12;
      _hour = initial.hour % 12;
      if (_hour == 0) _hour = 12;
    }
    _minute = initial.minute;

    _monthController = FixedExtentScrollController(
      initialItem: _selectedDate.month - 1,
    );
    _dayController = FixedExtentScrollController(
      initialItem: _selectedDate.day - 1,
    );
    _yearController = FixedExtentScrollController(
      initialItem: _selectedDate.year - _firstDate.year,
    );
    _hourController = FixedExtentScrollController(
      initialItem: widget.use24HourFormat ? _hour : _hour - 1,
    );
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _monthController.dispose();
    _dayController.dispose();
    _yearController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  void _onDateChanged() {
    final year = _firstDate.year + _yearController.selectedItem;
    final month = _monthController.selectedItem + 1;
    final maxDay = _daysInMonth(year, month);
    var day = _dayController.selectedItem + 1;
    if (day > maxDay) day = maxDay;

    setState(() {
      _selectedDate = DateTime(year, month, day);
    });
  }

  DateTime _buildDateTime() {
    int hour;
    if (widget.use24HourFormat) {
      hour = _hour;
    } else {
      hour = _hour % 12;
      if (_isPM) hour += 12;
    }
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      hour,
      _minute,
    );
  }

  @override
  Widget build(BuildContext context) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final yearCount = _lastDate.year - _firstDate.year + 1;
    final daysInCurrentMonth = _daysInMonth(
      _selectedDate.year,
      _selectedDate.month,
    );
    final hourCount = widget.use24HourFormat ? 24 : 12;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        _PickerHeader(
          title: widget.title,
          onCancel: () => Navigator.pop(context),
          onConfirm: () {
            HapticFeedback.mediumImpact();
            Navigator.pop(context, _buildDateTime());
          },
        ),

        // Date picker row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: context.textTertiary),
              const SizedBox(width: 8),
              Text(
                'Date',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 140,
          child: Row(
            children: [
              // Month
              Expanded(
                flex: 2,
                child: _PickerWheel(
                  controller: _monthController,
                  itemCount: 12,
                  onSelectedItemChanged: (_) => _onDateChanged(),
                  itemBuilder: (index) => months[index],
                ),
              ),
              // Day
              Expanded(
                child: _PickerWheel(
                  controller: _dayController,
                  itemCount: daysInCurrentMonth,
                  onSelectedItemChanged: (_) => _onDateChanged(),
                  itemBuilder: (index) => '${index + 1}',
                ),
              ),
              // Year
              Expanded(
                flex: 2,
                child: _PickerWheel(
                  controller: _yearController,
                  itemCount: yearCount,
                  onSelectedItemChanged: (_) => _onDateChanged(),
                  itemBuilder: (index) => '${_firstDate.year + index}',
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),
        Divider(height: 1, color: context.border),
        const SizedBox(height: 8),

        // Time picker row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.access_time, size: 16, color: context.textTertiary),
              const SizedBox(width: 8),
              Text(
                'Time',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 140,
          child: Row(
            children: [
              // Hour
              Expanded(
                flex: 2,
                child: _PickerWheel(
                  controller: _hourController,
                  itemCount: hourCount,
                  onSelectedItemChanged: (index) {
                    setState(() {
                      _hour = widget.use24HourFormat ? index : index + 1;
                    });
                  },
                  itemBuilder: (index) {
                    final h = widget.use24HourFormat ? index : index + 1;
                    return h.toString().padLeft(2, '0');
                  },
                ),
              ),
              // Colon
              Text(
                ':',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              // Minute
              Expanded(
                flex: 2,
                child: _PickerWheel(
                  controller: _minuteController,
                  itemCount: 60,
                  onSelectedItemChanged: (index) {
                    setState(() => _minute = index);
                  },
                  itemBuilder: (index) => index.toString().padLeft(2, '0'),
                ),
              ),
              // AM/PM
              if (!widget.use24HourFormat) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _AmPmSelector(
                    isPM: _isPM,
                    onChanged: (isPM) => setState(() => _isPM = isPM),
                  ),
                ),
              ],
            ],
          ),
        ),

        SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
      ],
    );
  }
}

// =============================================================================
// Shared Components
// =============================================================================

class _PickerHeader extends StatelessWidget {
  final String title;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _PickerHeader({
    required this.title,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        children: [
          TextButton(
            onPressed: onCancel,
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: context.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: onConfirm,
            child: Text(
              'Done',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: context.accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerWheel extends StatelessWidget {
  final FixedExtentScrollController controller;
  final int itemCount;
  final ValueChanged<int> onSelectedItemChanged;
  final String Function(int index) itemBuilder;

  const _PickerWheel({
    required this.controller,
    required this.itemCount,
    required this.onSelectedItemChanged,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPicker(
      scrollController: controller,
      itemExtent: 40,
      diameterRatio: 1.2,
      squeeze: 1.0,
      selectionOverlay: Container(
        decoration: BoxDecoration(
          border: Border.symmetric(
            horizontal: BorderSide(
              color: context.accentColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),
      ),
      onSelectedItemChanged: (index) {
        HapticFeedback.selectionClick();
        onSelectedItemChanged(index);
      },
      children: List.generate(itemCount, (index) {
        return Center(
          child: Text(
            itemBuilder(index),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: context.textPrimary,
            ),
          ),
        );
      }),
    );
  }
}

class _AmPmSelector extends StatelessWidget {
  final bool isPM;
  final ValueChanged<bool> onChanged;

  const _AmPmSelector({required this.isPM, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _AmPmButton(
          label: 'AM',
          isSelected: !isPM,
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(false);
          },
        ),
        const SizedBox(height: 8),
        _AmPmButton(
          label: 'PM',
          isSelected: isPM,
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(true);
          },
        ),
      ],
    );
  }
}

class _AmPmButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _AmPmButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? context.accentColor : context.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? context.accentColor : context.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : context.textSecondary,
          ),
        ),
      ),
    );
  }
}
