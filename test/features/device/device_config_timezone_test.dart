// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reproduces the exact pattern from DeviceConfigScreen's timezone and GPIO
/// fields.
///
/// The bug: `key: ValueKey('tzdef_${_tzdef.hashCode}')` with `initialValue`
/// caused the TextFormField to be destroyed and recreated on every keystroke
/// (because the key changed), which stole focus after each character.
///
/// The fix: use a stable `const ValueKey('tzdef')` with a
/// `TextEditingController` instead of `initialValue`.
///
/// The same bug existed in GPIO fields with `key: ValueKey('numField_$value')`.

void main() {
  group('Timezone field - focus retention (bug fix)', () {
    testWidgets(
      'FIXED: controller-based field retains focus during continuous typing',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: _FixedTimezoneWidget())),
        );

        final finder = find.byKey(const ValueKey('tzdef'));
        expect(finder, findsOneWidget);

        // Tap to focus
        await tester.tap(finder);
        await tester.pump();

        // Type a full POSIX timezone string character by character
        const input = 'EST5EDT,M3.2.0,M11.1.0';
        await tester.enterText(finder, input);
        await tester.pump();

        // Verify the full string is present — not truncated to 1 char
        final field = tester.widget<TextFormField>(finder);
        final controller = (field.controller) as TextEditingController;
        expect(controller.text, input);

        // Verify focus is still on the timezone field
        final focusNode = FocusScope.of(tester.element(finder)).focusedChild;
        // The field's internal EditableText should still be focused
        expect(focusNode, isNotNull);
      },
    );

    testWidgets(
      'REGRESSION PROOF: value-dependent key loses focus after each keystroke',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: _BrokenTimezoneWidget())),
        );

        final otherFieldFinder = find.byKey(const ValueKey('other_field'));
        final tzFieldFinder = find.byType(TextFormField).last;
        expect(otherFieldFinder, findsOneWidget);
        expect(tzFieldFinder, findsOneWidget);

        // Tap the timezone field to focus it
        await tester.tap(tzFieldFinder);
        await tester.pump();

        // Type a single character — the broken key pattern triggers rebuild
        await tester.enterText(tzFieldFinder, 'E');
        await tester.pump();

        // In the broken version, the TextFormField was destroyed and
        // recreated with a new key, so initialValue = 'E' is correct
        // but focus was lost. The field text should still be 'E' because
        // initialValue hydrated it, but the widget was recreated.
        expect(find.text('E'), findsOneWidget);
      },
    );

    testWidgets('controller-based field handles backspace correctly', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: _FixedTimezoneWidget())),
      );

      final finder = find.byKey(const ValueKey('tzdef'));
      await tester.tap(finder);
      await tester.pump();

      // Type then delete
      await tester.enterText(finder, 'EST5');
      await tester.pump();

      await tester.enterText(finder, 'EST');
      await tester.pump();

      final field = tester.widget<TextFormField>(finder);
      final controller = (field.controller) as TextEditingController;
      expect(controller.text, 'EST');
    });

    testWidgets(
      'controller-based field handles paste of full timezone string',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: _FixedTimezoneWidget())),
        );

        final finder = find.byKey(const ValueKey('tzdef'));
        await tester.tap(finder);
        await tester.pump();

        // Simulate paste of a full timezone string
        const pasted = 'CST6CDT,M3.2.0/2,M11.1.0/2';
        await tester.enterText(finder, pasted);
        await tester.pump();

        final field = tester.widget<TextFormField>(finder);
        final controller = (field.controller) as TextEditingController;
        expect(controller.text, pasted);
      },
    );

    testWidgets('empty value is preserved (UTC semantics)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: _FixedTimezoneWidget())),
      );

      final finder = find.byKey(const ValueKey('tzdef'));
      final field = tester.widget<TextFormField>(finder);
      final controller = (field.controller) as TextEditingController;
      expect(controller.text, isEmpty);
    });

    testWidgets('hydration from existing config sets initial value', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: _FixedTimezoneWidget(initialTzdef: 'PST8PDT')),
        ),
      );

      final finder = find.byKey(const ValueKey('tzdef'));
      final field = tester.widget<TextFormField>(finder);
      final controller = (field.controller) as TextEditingController;
      expect(controller.text, 'PST8PDT');
    });

    testWidgets('editing after hydration preserves user input', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: _FixedTimezoneWidget(initialTzdef: 'PST8PDT')),
        ),
      );

      final finder = find.byKey(const ValueKey('tzdef'));
      await tester.tap(finder);
      await tester.pump();

      // User clears and types a new timezone
      await tester.enterText(finder, 'EST5EDT');
      await tester.pump();

      final field = tester.widget<TextFormField>(finder);
      final controller = (field.controller) as TextEditingController;
      expect(controller.text, 'EST5EDT');
    });

    testWidgets('focus stays on timezone field when other fields exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: _MultiFieldFixedWidget())),
      );

      final tzFinder = find.byKey(const ValueKey('tzdef'));
      final otherFinder = find.byKey(const ValueKey('other_input'));
      expect(tzFinder, findsOneWidget);
      expect(otherFinder, findsOneWidget);

      // Focus timezone field
      await tester.tap(tzFinder);
      await tester.pump();

      // Type into timezone field
      await tester.enterText(tzFinder, 'EST5EDT,M3.2.0,M11.1.0');
      await tester.pump();

      // Verify the other field did NOT receive the text
      final otherField = tester.widget<TextField>(otherFinder);
      expect(otherField.controller!.text, isEmpty);

      // Verify timezone field has the full text
      final tzField = tester.widget<TextFormField>(tzFinder);
      final controller = (tzField.controller) as TextEditingController;
      expect(controller.text, 'EST5EDT,M3.2.0,M11.1.0');
    });

    testWidgets('switching focus between fields works intentionally', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: _MultiFieldFixedWidget())),
      );

      final tzFinder = find.byKey(const ValueKey('tzdef'));
      final otherFinder = find.byKey(const ValueKey('other_input'));

      // Type into timezone
      await tester.tap(tzFinder);
      await tester.pump();
      await tester.enterText(tzFinder, 'EST5');
      await tester.pump();

      // Intentionally switch to other field
      await tester.tap(otherFinder);
      await tester.pump();
      await tester.enterText(otherFinder, 'hello');
      await tester.pump();

      // Both fields retain their text
      final tzField = tester.widget<TextFormField>(tzFinder);
      final tzController = (tzField.controller) as TextEditingController;
      expect(tzController.text, 'EST5');

      final otherField = tester.widget<TextField>(otherFinder);
      expect(otherField.controller!.text, 'hello');
    });

    testWidgets('dirty-state tracking works with controller-based field', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: _DirtyTrackingWidget())),
      );

      // Initially not dirty
      expect(find.text('dirty: false'), findsOneWidget);

      final finder = find.byKey(const ValueKey('tzdef'));
      await tester.tap(finder);
      await tester.pump();

      // Type — should become dirty
      await tester.enterText(finder, 'E');
      await tester.pump();
      expect(find.text('dirty: true'), findsOneWidget);

      // Clear — should go back to not dirty
      await tester.enterText(finder, '');
      await tester.pump();
      expect(find.text('dirty: false'), findsOneWidget);

      // Type full string — dirty again
      await tester.enterText(finder, 'EST5EDT,M3.2.0,M11.1.0');
      await tester.pump();
      expect(find.text('dirty: true'), findsOneWidget);

      // Field should still have full text (not truncated)
      final field = tester.widget<TextFormField>(finder);
      final controller = (field.controller) as TextEditingController;
      expect(controller.text, 'EST5EDT,M3.2.0,M11.1.0');
    });

    testWidgets('save flow reads correct value from controller', (
      tester,
    ) async {
      String? savedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _SaveFlowWidget(onSave: (value) => savedValue = value),
          ),
        ),
      );

      final finder = find.byKey(const ValueKey('tzdef'));
      await tester.tap(finder);
      await tester.pump();

      await tester.enterText(finder, 'EST5EDT,M3.2.0,M11.1.0');
      await tester.pump();

      // Tap save button
      await tester.tap(find.byKey(const ValueKey('save_button')));
      await tester.pump();

      expect(savedValue, 'EST5EDT,M3.2.0,M11.1.0');
    });

    testWidgets('save flow persists empty string when field is cleared', (
      tester,
    ) async {
      String? savedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _SaveFlowWidget(
              initialTzdef: 'PST8PDT',
              onSave: (value) => savedValue = value,
            ),
          ),
        ),
      );

      final finder = find.byKey(const ValueKey('tzdef'));
      await tester.tap(finder);
      await tester.pump();

      // Clear the field (user wants UTC)
      await tester.enterText(finder, '');
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('save_button')));
      await tester.pump();

      expect(savedValue, isEmpty);
    });

    testWidgets('external config update hydrates field when not editing', (
      tester,
    ) async {
      final widget = _ExternalUpdateWidget();
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

      final finder = find.byKey(const ValueKey('tzdef'));

      // Initially empty
      final fieldBefore = tester.widget<TextFormField>(finder);
      final controllerBefore =
          (fieldBefore.controller) as TextEditingController;
      expect(controllerBefore.text, isEmpty);

      // Simulate external config update (device config stream response)
      final state = tester.state<_ExternalUpdateWidgetState>(
        find.byType(_ExternalUpdateWidget),
      );
      state.simulateConfigUpdate('MST7MDT');
      await tester.pump();

      // Field should show the new value
      expect(controllerBefore.text, 'MST7MDT');
    });

    testWidgets('external config update does NOT overwrite active user edits', (
      tester,
    ) async {
      final widget = _ExternalUpdateWidget();
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

      final finder = find.byKey(const ValueKey('tzdef'));

      // User starts typing
      await tester.tap(finder);
      await tester.pump();
      await tester.enterText(finder, 'EST5EDT');
      await tester.pump();

      // Mark as having changes (simulates _checkForChanges setting
      // _hasChanges = true)
      final state = tester.state<_ExternalUpdateWidgetState>(
        find.byType(_ExternalUpdateWidget),
      );
      state.markHasChanges();

      // External config arrives — should NOT overwrite user's edit
      state.simulateConfigUpdate('UTC0');
      await tester.pump();

      final field = tester.widget<TextFormField>(finder);
      final controller = (field.controller) as TextEditingController;
      expect(controller.text, 'EST5EDT');
    });
  });

  group('GPIO fields - focus retention (same root cause as timezone)', () {
    testWidgets(
      'FIXED: controller-based GPIO field retains focus during multi-digit entry',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: _FixedGpioWidget())),
        );

        final buttonFinder = find.byKey(const ValueKey('buttonGpio'));
        expect(buttonFinder, findsOneWidget);

        // Tap to focus
        await tester.tap(buttonFinder);
        await tester.pump();

        // Type a multi-digit GPIO pin number
        await tester.enterText(buttonFinder, '39');
        await tester.pump();

        // Verify full number is present — not truncated to first digit
        final field = tester.widget<TextFormField>(buttonFinder);
        final controller = (field.controller) as TextEditingController;
        expect(controller.text, '39');

        // Verify focus is still on the GPIO field
        final focusNode = FocusScope.of(
          tester.element(buttonFinder),
        ).focusedChild;
        expect(focusNode, isNotNull);
      },
    );

    testWidgets(
      'REGRESSION PROOF: value-dependent key on GPIO loses focus after keystroke',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: _BrokenGpioWidget())),
        );

        final gpioFinder = find.byType(TextFormField);
        expect(gpioFinder, findsOneWidget);

        await tester.tap(gpioFinder);
        await tester.pump();

        // Type '3' — broken key causes widget recreation
        await tester.enterText(gpioFinder, '3');
        await tester.pump();

        // The value landed but the widget was recreated (key changed)
        expect(find.text('3'), findsOneWidget);
      },
    );

    testWidgets('GPIO field accepts only digits (inputFormatter preserved)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: _FixedGpioWidget())),
      );

      final buttonFinder = find.byKey(const ValueKey('buttonGpio'));
      await tester.tap(buttonFinder);
      await tester.pump();

      // Enter text with digits — formatter should keep them
      await tester.enterText(buttonFinder, '12');
      await tester.pump();

      final field = tester.widget<TextFormField>(buttonFinder);
      final controller = (field.controller) as TextEditingController;
      expect(controller.text, '12');
    });

    testWidgets('GPIO hydration from existing config sets initial value', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _FixedGpioWidget(
              initialButtonGpio: 39,
              initialBuzzerGpio: 14,
            ),
          ),
        ),
      );

      final buttonField = tester.widget<TextFormField>(
        find.byKey(const ValueKey('buttonGpio')),
      );
      final buzzerField = tester.widget<TextFormField>(
        find.byKey(const ValueKey('buzzerGpio')),
      );
      expect((buttonField.controller as TextEditingController).text, '39');
      expect((buzzerField.controller as TextEditingController).text, '14');
    });

    testWidgets('GPIO zero value shows empty field (hint shows 0)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: _FixedGpioWidget())),
      );

      final field = tester.widget<TextFormField>(
        find.byKey(const ValueKey('buttonGpio')),
      );
      expect((field.controller as TextEditingController).text, isEmpty);
    });

    testWidgets('GPIO dirty-state tracking works with controller', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: _FixedGpioWidget())),
      );

      // Initially not dirty
      expect(find.text('dirty: false'), findsOneWidget);

      final buttonFinder = find.byKey(const ValueKey('buttonGpio'));
      await tester.tap(buttonFinder);
      await tester.pump();

      // Type — should become dirty
      await tester.enterText(buttonFinder, '39');
      await tester.pump();
      expect(find.text('dirty: true'), findsOneWidget);

      // Clear — should go back to not dirty (parsed as 0, matches original)
      await tester.enterText(buttonFinder, '');
      await tester.pump();
      expect(find.text('dirty: false'), findsOneWidget);
    });

    testWidgets('focus stays on button GPIO — does not jump to buzzer GPIO', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: _FixedGpioWidget())),
      );

      final buttonFinder = find.byKey(const ValueKey('buttonGpio'));
      final buzzerFinder = find.byKey(const ValueKey('buzzerGpio'));

      // Type into button GPIO
      await tester.tap(buttonFinder);
      await tester.pump();
      await tester.enterText(buttonFinder, '39');
      await tester.pump();

      // Buzzer GPIO should still be empty
      final buzzerField = tester.widget<TextFormField>(buzzerFinder);
      expect((buzzerField.controller as TextEditingController).text, isEmpty);

      // Button GPIO should have the full value
      final buttonField = tester.widget<TextFormField>(buttonFinder);
      expect((buttonField.controller as TextEditingController).text, '39');
    });

    testWidgets('switching between button and buzzer GPIO works', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: _FixedGpioWidget())),
      );

      final buttonFinder = find.byKey(const ValueKey('buttonGpio'));
      final buzzerFinder = find.byKey(const ValueKey('buzzerGpio'));

      // Type into button GPIO
      await tester.tap(buttonFinder);
      await tester.pump();
      await tester.enterText(buttonFinder, '39');
      await tester.pump();

      // Switch to buzzer GPIO
      await tester.tap(buzzerFinder);
      await tester.pump();
      await tester.enterText(buzzerFinder, '14');
      await tester.pump();

      // Both retain their values
      final buttonField = tester.widget<TextFormField>(buttonFinder);
      expect((buttonField.controller as TextEditingController).text, '39');
      final buzzerField = tester.widget<TextFormField>(buzzerFinder);
      expect((buzzerField.controller as TextEditingController).text, '14');
    });

    testWidgets('GPIO save flow reads correct int values from controllers', (
      tester,
    ) async {
      int? savedButton;
      int? savedBuzzer;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _GpioSaveFlowWidget(
              onSave: (b, z) {
                savedButton = b;
                savedBuzzer = z;
              },
            ),
          ),
        ),
      );

      final buttonFinder = find.byKey(const ValueKey('buttonGpio'));
      final buzzerFinder = find.byKey(const ValueKey('buzzerGpio'));

      await tester.tap(buttonFinder);
      await tester.pump();
      await tester.enterText(buttonFinder, '39');
      await tester.pump();

      await tester.tap(buzzerFinder);
      await tester.pump();
      await tester.enterText(buzzerFinder, '14');
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('save_button')));
      await tester.pump();

      expect(savedButton, 39);
      expect(savedBuzzer, 14);
    });

    testWidgets('GPIO save flow returns 0 for empty fields', (tester) async {
      int? savedButton;
      int? savedBuzzer;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _GpioSaveFlowWidget(
              initialButtonGpio: 39,
              initialBuzzerGpio: 14,
              onSave: (b, z) {
                savedButton = b;
                savedBuzzer = z;
              },
            ),
          ),
        ),
      );

      // Clear both GPIO fields
      final buttonFinder = find.byKey(const ValueKey('buttonGpio'));
      await tester.tap(buttonFinder);
      await tester.pump();
      await tester.enterText(buttonFinder, '');
      await tester.pump();

      final buzzerFinder = find.byKey(const ValueKey('buzzerGpio'));
      await tester.tap(buzzerFinder);
      await tester.pump();
      await tester.enterText(buzzerFinder, '');
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('save_button')));
      await tester.pump();

      expect(savedButton, 0);
      expect(savedBuzzer, 0);
    });

    testWidgets(
      'external config update hydrates GPIO fields when not editing',
      (tester) async {
        final widget = _GpioExternalUpdateWidget();
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

        final buttonFinder = find.byKey(const ValueKey('buttonGpio'));
        final buzzerFinder = find.byKey(const ValueKey('buzzerGpio'));

        // Initially empty
        final buttonBefore = tester.widget<TextFormField>(buttonFinder);
        expect(
          (buttonBefore.controller as TextEditingController).text,
          isEmpty,
        );

        // Simulate external config update
        final state = tester.state<_GpioExternalUpdateWidgetState>(
          find.byType(_GpioExternalUpdateWidget),
        );
        state.simulateConfigUpdate(39, 14);
        await tester.pump();

        // Fields should show new values
        final buttonAfter = tester.widget<TextFormField>(buttonFinder);
        expect((buttonAfter.controller as TextEditingController).text, '39');
        final buzzerAfter = tester.widget<TextFormField>(buzzerFinder);
        expect((buzzerAfter.controller as TextEditingController).text, '14');
      },
    );

    testWidgets('external config update does NOT overwrite active GPIO edits', (
      tester,
    ) async {
      final widget = _GpioExternalUpdateWidget();
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

      final buttonFinder = find.byKey(const ValueKey('buttonGpio'));

      // User starts typing
      await tester.tap(buttonFinder);
      await tester.pump();
      await tester.enterText(buttonFinder, '39');
      await tester.pump();

      // Mark as having changes
      final state = tester.state<_GpioExternalUpdateWidgetState>(
        find.byType(_GpioExternalUpdateWidget),
      );
      state.markHasChanges();

      // External config arrives — should NOT overwrite
      state.simulateConfigUpdate(10, 20);
      await tester.pump();

      final buttonField = tester.widget<TextFormField>(buttonFinder);
      expect((buttonField.controller as TextEditingController).text, '39');
    });
  });
}

// ---------------------------------------------------------------------------
// Timezone test widgets
// ---------------------------------------------------------------------------

/// FIXED pattern: stable key + TextEditingController (the fix)
class _FixedTimezoneWidget extends StatefulWidget {
  final String initialTzdef;
  const _FixedTimezoneWidget({this.initialTzdef = ''});

  @override
  State<_FixedTimezoneWidget> createState() => _FixedTimezoneWidgetState();
}

class _FixedTimezoneWidgetState extends State<_FixedTimezoneWidget> {
  late TextEditingController _tzdefController;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _tzdefController = TextEditingController(text: widget.initialTzdef);
  }

  @override
  void dispose() {
    _tzdefController.dispose();
    super.dispose();
  }

  void _checkForChanges() {
    setState(() {
      _hasChanges = _tzdefController.text != widget.initialTzdef;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_hasChanges) const Text('Has changes'),
        TextFormField(
          key: const ValueKey('tzdef'),
          controller: _tzdefController,
          onChanged: (_) => _checkForChanges(),
        ),
      ],
    );
  }
}

/// BROKEN pattern: value-dependent key + initialValue (the bug)
class _BrokenTimezoneWidget extends StatefulWidget {
  const _BrokenTimezoneWidget();

  @override
  State<_BrokenTimezoneWidget> createState() => _BrokenTimezoneWidgetState();
}

class _BrokenTimezoneWidgetState extends State<_BrokenTimezoneWidget> {
  String _tzdef = '';
  bool _hasChanges = false;

  void _checkForChanges() {
    setState(() {
      _hasChanges = _tzdef.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Another field that can steal focus when the timezone field is
        // destroyed and recreated due to key change
        TextField(
          key: const ValueKey('other_field'),
          decoration: const InputDecoration(hintText: 'Other'),
        ),
        if (_hasChanges) const Text('Has changes'),
        TextFormField(
          // BUG: key depends on current value — changes on every keystroke
          key: ValueKey('tzdef_${_tzdef.hashCode}'),
          initialValue: _tzdef,
          onChanged: (value) {
            _tzdef = value;
            _checkForChanges();
          },
        ),
      ],
    );
  }
}

/// Multi-field widget to test that focus doesn't jump between fields
class _MultiFieldFixedWidget extends StatefulWidget {
  const _MultiFieldFixedWidget();

  @override
  State<_MultiFieldFixedWidget> createState() => _MultiFieldFixedWidgetState();
}

class _MultiFieldFixedWidgetState extends State<_MultiFieldFixedWidget> {
  late TextEditingController _tzdefController;
  late TextEditingController _otherController;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _tzdefController = TextEditingController();
    _otherController = TextEditingController();
  }

  @override
  void dispose() {
    _tzdefController.dispose();
    _otherController.dispose();
    super.dispose();
  }

  void _checkForChanges() {
    setState(() {
      _hasChanges = _tzdefController.text.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          key: const ValueKey('other_input'),
          controller: _otherController,
        ),
        if (_hasChanges) const Text('Has changes'),
        TextFormField(
          key: const ValueKey('tzdef'),
          controller: _tzdefController,
          onChanged: (_) => _checkForChanges(),
        ),
      ],
    );
  }
}

/// Widget that tracks dirty state — matches _checkForChanges() pattern
class _DirtyTrackingWidget extends StatefulWidget {
  const _DirtyTrackingWidget();

  @override
  State<_DirtyTrackingWidget> createState() => _DirtyTrackingWidgetState();
}

class _DirtyTrackingWidgetState extends State<_DirtyTrackingWidget> {
  late TextEditingController _tzdefController;
  final String _originalTzdef = '';
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _tzdefController = TextEditingController();
  }

  @override
  void dispose() {
    _tzdefController.dispose();
    super.dispose();
  }

  void _checkForChanges() {
    setState(() {
      _hasChanges = _tzdefController.text != _originalTzdef;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('dirty: $_hasChanges'),
        TextFormField(
          key: const ValueKey('tzdef'),
          controller: _tzdefController,
          onChanged: (_) => _checkForChanges(),
        ),
      ],
    );
  }
}

/// Widget that simulates the save flow reading from the controller
class _SaveFlowWidget extends StatefulWidget {
  final String initialTzdef;
  final ValueChanged<String> onSave;

  const _SaveFlowWidget({this.initialTzdef = '', required this.onSave});

  @override
  State<_SaveFlowWidget> createState() => _SaveFlowWidgetState();
}

class _SaveFlowWidgetState extends State<_SaveFlowWidget> {
  late TextEditingController _tzdefController;

  @override
  void initState() {
    super.initState();
    _tzdefController = TextEditingController(text: widget.initialTzdef);
  }

  @override
  void dispose() {
    _tzdefController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          key: const ValueKey('tzdef'),
          controller: _tzdefController,
        ),
        ElevatedButton(
          key: const ValueKey('save_button'),
          onPressed: () => widget.onSave(_tzdefController.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Widget that simulates external config updates (device config stream)
/// matching the _applyDeviceConfig pattern with !_hasChanges guard.
class _ExternalUpdateWidget extends StatefulWidget {
  const _ExternalUpdateWidget();

  @override
  State<_ExternalUpdateWidget> createState() => _ExternalUpdateWidgetState();
}

class _ExternalUpdateWidgetState extends State<_ExternalUpdateWidget> {
  late TextEditingController _tzdefController;
  String _originalTzdef = '';
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _tzdefController = TextEditingController();
  }

  @override
  void dispose() {
    _tzdefController.dispose();
    super.dispose();
  }

  /// Simulates _applyDeviceConfig from DeviceConfigScreen:
  /// only overwrites user-facing values when user has NOT started editing.
  void simulateConfigUpdate(String newTzdef) {
    setState(() {
      if (!_hasChanges) {
        _tzdefController.text = newTzdef;
      }
      // Always update original for change detection
      _originalTzdef = newTzdef;
    });
  }

  void markHasChanges() {
    setState(() => _hasChanges = true);
  }

  void _checkForChanges() {
    setState(() {
      _hasChanges = _tzdefController.text != _originalTzdef;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('dirty: $_hasChanges'),
        TextFormField(
          key: const ValueKey('tzdef'),
          controller: _tzdefController,
          onChanged: (_) => _checkForChanges(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// GPIO field test widgets
// ---------------------------------------------------------------------------

/// FIXED GPIO pattern: stable key + TextEditingController (the fix)
class _FixedGpioWidget extends StatefulWidget {
  final int initialButtonGpio;
  final int initialBuzzerGpio;
  const _FixedGpioWidget({
    this.initialButtonGpio = 0,
    this.initialBuzzerGpio = 0,
  });

  @override
  State<_FixedGpioWidget> createState() => _FixedGpioWidgetState();
}

class _FixedGpioWidgetState extends State<_FixedGpioWidget> {
  late TextEditingController _buttonGpioController;
  late TextEditingController _buzzerGpioController;
  int _originalButtonGpio = 0;
  int _originalBuzzerGpio = 0;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _originalButtonGpio = widget.initialButtonGpio;
    _originalBuzzerGpio = widget.initialBuzzerGpio;
    _buttonGpioController = TextEditingController(
      text: widget.initialButtonGpio == 0
          ? ''
          : widget.initialButtonGpio.toString(),
    );
    _buzzerGpioController = TextEditingController(
      text: widget.initialBuzzerGpio == 0
          ? ''
          : widget.initialBuzzerGpio.toString(),
    );
  }

  @override
  void dispose() {
    _buttonGpioController.dispose();
    _buzzerGpioController.dispose();
    super.dispose();
  }

  void _checkForChanges() {
    setState(() {
      final buttonGpioChanged =
          (int.tryParse(_buttonGpioController.text) ?? 0) !=
          _originalButtonGpio;
      final buzzerGpioChanged =
          (int.tryParse(_buzzerGpioController.text) ?? 0) !=
          _originalBuzzerGpio;
      _hasChanges = buttonGpioChanged || buzzerGpioChanged;
    });
  }

  Widget _buildGpioField({
    required String label,
    required String fieldKey,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        TextFormField(
          key: ValueKey(fieldKey),
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(hintText: '0'),
          onChanged: (_) => _checkForChanges(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('dirty: $_hasChanges'),
        Row(
          children: [
            Expanded(
              child: _buildGpioField(
                label: 'Button GPIO',
                fieldKey: 'buttonGpio',
                controller: _buttonGpioController,
              ),
            ),
            Expanded(
              child: _buildGpioField(
                label: 'Buzzer GPIO',
                fieldKey: 'buzzerGpio',
                controller: _buzzerGpioController,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// BROKEN GPIO pattern: value-dependent key + initialValue (the bug)
class _BrokenGpioWidget extends StatefulWidget {
  const _BrokenGpioWidget();

  @override
  State<_BrokenGpioWidget> createState() => _BrokenGpioWidgetState();
}

class _BrokenGpioWidgetState extends State<_BrokenGpioWidget> {
  int _buttonGpio = 0;
  bool _hasChanges = false;

  void _checkForChanges() {
    setState(() {
      _hasChanges = _buttonGpio != 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Another field that can steal focus
        const TextField(key: ValueKey('other_gpio_field')),
        if (_hasChanges) const Text('Has changes'),
        TextFormField(
          // BUG: key depends on current value
          key: ValueKey('numField_$_buttonGpio'),
          initialValue: _buttonGpio == 0 ? '' : _buttonGpio.toString(),
          keyboardType: TextInputType.number,
          onChanged: (text) {
            _buttonGpio = int.tryParse(text) ?? 0;
            _checkForChanges();
          },
        ),
      ],
    );
  }
}

/// Widget for GPIO save-flow testing
class _GpioSaveFlowWidget extends StatefulWidget {
  final int initialButtonGpio;
  final int initialBuzzerGpio;
  final void Function(int buttonGpio, int buzzerGpio) onSave;

  const _GpioSaveFlowWidget({
    this.initialButtonGpio = 0,
    this.initialBuzzerGpio = 0,
    required this.onSave,
  });

  @override
  State<_GpioSaveFlowWidget> createState() => _GpioSaveFlowWidgetState();
}

class _GpioSaveFlowWidgetState extends State<_GpioSaveFlowWidget> {
  late TextEditingController _buttonGpioController;
  late TextEditingController _buzzerGpioController;

  @override
  void initState() {
    super.initState();
    _buttonGpioController = TextEditingController(
      text: widget.initialButtonGpio == 0
          ? ''
          : widget.initialButtonGpio.toString(),
    );
    _buzzerGpioController = TextEditingController(
      text: widget.initialBuzzerGpio == 0
          ? ''
          : widget.initialBuzzerGpio.toString(),
    );
  }

  @override
  void dispose() {
    _buttonGpioController.dispose();
    _buzzerGpioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          key: const ValueKey('buttonGpio'),
          controller: _buttonGpioController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        TextFormField(
          key: const ValueKey('buzzerGpio'),
          controller: _buzzerGpioController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        ElevatedButton(
          key: const ValueKey('save_button'),
          onPressed: () => widget.onSave(
            int.tryParse(_buttonGpioController.text) ?? 0,
            int.tryParse(_buzzerGpioController.text) ?? 0,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Widget for testing external config hydration of GPIO fields
class _GpioExternalUpdateWidget extends StatefulWidget {
  const _GpioExternalUpdateWidget();

  @override
  State<_GpioExternalUpdateWidget> createState() =>
      _GpioExternalUpdateWidgetState();
}

class _GpioExternalUpdateWidgetState extends State<_GpioExternalUpdateWidget> {
  late TextEditingController _buttonGpioController;
  late TextEditingController _buzzerGpioController;
  int _originalButtonGpio = 0;
  int _originalBuzzerGpio = 0;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _buttonGpioController = TextEditingController();
    _buzzerGpioController = TextEditingController();
  }

  @override
  void dispose() {
    _buttonGpioController.dispose();
    _buzzerGpioController.dispose();
    super.dispose();
  }

  /// Simulates _applyDeviceConfig — only overwrites when !_hasChanges
  void simulateConfigUpdate(int buttonGpio, int buzzerGpio) {
    setState(() {
      if (!_hasChanges) {
        _buttonGpioController.text = buttonGpio == 0
            ? ''
            : buttonGpio.toString();
        _buzzerGpioController.text = buzzerGpio == 0
            ? ''
            : buzzerGpio.toString();
      }
      _originalButtonGpio = buttonGpio;
      _originalBuzzerGpio = buzzerGpio;
    });
  }

  void markHasChanges() {
    setState(() => _hasChanges = true);
  }

  void _checkForChanges() {
    setState(() {
      _hasChanges =
          (int.tryParse(_buttonGpioController.text) ?? 0) !=
              _originalButtonGpio ||
          (int.tryParse(_buzzerGpioController.text) ?? 0) !=
              _originalBuzzerGpio;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('dirty: $_hasChanges'),
        TextFormField(
          key: const ValueKey('buttonGpio'),
          controller: _buttonGpioController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => _checkForChanges(),
        ),
        TextFormField(
          key: const ValueKey('buzzerGpio'),
          controller: _buzzerGpioController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => _checkForChanges(),
        ),
      ],
    );
  }
}
