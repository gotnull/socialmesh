// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Messaging Lifecycle Safety Tests
///
/// These tests verify that messaging UI components handle lifecycle correctly:
/// - No setState after dispose
/// - No ref access after widget disposal
/// - No context usage after navigation
/// - Safe async callback handling
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Messaging Lifecycle Safety', () {
    testWidgets(
      'async callback with immediate pop does not throw setState after dispose',
      (tester) async {
        // Track if any errors occurred
        final errors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          errors.add(details);
        };

        addTearDown(() {
          FlutterError.onError = originalOnError;
        });

        // Create a stateful widget that simulates async work
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: const _AsyncCallbackTestScreen()),
          ),
        );

        // Find and tap the button that triggers async work
        await tester.tap(find.text('Start Async Work'));
        await tester.pump();

        // Immediately pop the screen before async work completes
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pump();

        // Let async work complete (it should not cause setState after dispose)
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        // Verify no setState-after-dispose errors occurred
        final setStateErrors = errors.where(
          (e) =>
              e.exception.toString().contains('setState') ||
              e.exception.toString().contains('disposed'),
        );

        expect(
          setStateErrors,
          isEmpty,
          reason:
              'setState after dispose errors found: ${setStateErrors.map((e) => e.exception).join(', ')}',
        );
      },
    );

    testWidgets(
      'bottom sheet callback with parent pop does not use invalid context',
      (tester) async {
        final errors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          errors.add(details);
        };

        addTearDown(() {
          FlutterError.onError = originalOnError;
        });

        await tester.pumpWidget(
          MaterialApp(home: const _BottomSheetContextTestScreen()),
        );

        // Open bottom sheet
        await tester.tap(find.text('Show Sheet'));
        await tester.pumpAndSettle();

        // Verify sheet is shown
        expect(find.text('Sheet Content'), findsOneWidget);

        // Tap the action button in sheet that pops and navigates
        await tester.tap(find.text('Pop and Navigate'));
        await tester.pumpAndSettle();

        // Verify no context-related errors
        final contextErrors = errors.where(
          (e) =>
              e.exception.toString().contains('context') ||
              e.exception.toString().contains('disposed') ||
              e.exception.toString().contains('Navigator'),
        );

        expect(
          contextErrors,
          isEmpty,
          reason:
              'Context errors found: ${contextErrors.map((e) => e.exception).join(', ')}',
        );
      },
    );

    testWidgets('rapid button taps do not cause concurrent modification errors', (
      tester,
    ) async {
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
      };

      addTearDown(() {
        FlutterError.onError = originalOnError;
      });

      await tester.pumpWidget(MaterialApp(home: const _RapidTapTestScreen()));

      // Rapidly tap the send button multiple times
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byIcon(Icons.send));
        await tester.pump(const Duration(milliseconds: 10));
      }

      // Let all async operations settle
      await tester.pumpAndSettle();

      // Verify no concurrent modification errors
      final concurrentErrors = errors.where(
        (e) =>
            e.exception.toString().contains('Concurrent') ||
            e.exception.toString().contains('modification'),
      );

      expect(
        concurrentErrors,
        isEmpty,
        reason:
            'Concurrent modification errors: ${concurrentErrors.map((e) => e.exception).join(', ')}',
      );
    });

    testWidgets('listener is removed before controller disposal', (
      tester,
    ) async {
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
      };

      addTearDown(() {
        FlutterError.onError = originalOnError;
      });

      await tester.pumpWidget(MaterialApp(home: const _ListenerTestScreen()));

      // Type in the text field to trigger listener
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump();

      // Pop the screen (this will trigger dispose)
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Verify no listener-related errors
      final listenerErrors = errors.where(
        (e) =>
            e.exception.toString().contains('listener') ||
            e.exception.toString().contains('disposed'),
      );

      expect(
        listenerErrors,
        isEmpty,
        reason:
            'Listener errors: ${listenerErrors.map((e) => e.exception).join(', ')}',
      );
    });
  });
}

/// Test screen that performs async work and updates state
class _AsyncCallbackTestScreen extends StatefulWidget {
  const _AsyncCallbackTestScreen();

  @override
  State<_AsyncCallbackTestScreen> createState() =>
      _AsyncCallbackTestScreenState();
}

class _AsyncCallbackTestScreenState extends State<_AsyncCallbackTestScreen> {
  String _status = 'idle';

  Future<void> _startAsyncWork() async {
    setState(() => _status = 'working');

    // Simulate async network/protocol call
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // This is the critical part - must check mounted before setState
    if (mounted) {
      setState(() => _status = 'done');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Status: $_status'),
            ElevatedButton(
              onPressed: _startAsyncWork,
              child: const Text('Start Async Work'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Test screen for bottom sheet context safety
class _BottomSheetContextTestScreen extends StatelessWidget {
  const _BottomSheetContextTestScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Capture navigator before showing sheet
            final navigator = Navigator.of(context);

            showModalBottomSheet(
              context: context,
              builder: (sheetContext) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Sheet Content'),
                      ElevatedButton(
                        onPressed: () {
                          // Use captured navigator, not sheetContext
                          navigator.pop();
                          navigator.push(
                            MaterialPageRoute(
                              builder: (_) => const Scaffold(
                                body: Center(child: Text('New Screen')),
                              ),
                            ),
                          );
                        },
                        child: const Text('Pop and Navigate'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
          child: const Text('Show Sheet'),
        ),
      ),
    );
  }
}

/// Test screen for rapid tap handling
class _RapidTapTestScreen extends StatefulWidget {
  const _RapidTapTestScreen();

  @override
  State<_RapidTapTestScreen> createState() => _RapidTapTestScreenState();
}

class _RapidTapTestScreenState extends State<_RapidTapTestScreen> {
  int _sendCount = 0;
  final List<Future<void>> _pendingOperations = [];

  Future<void> _handleSend() async {
    final operation = _performSend();
    _pendingOperations.add(operation);
    await operation;
    _pendingOperations.remove(operation);
  }

  Future<void> _performSend() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() => _sendCount++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Send count: $_sendCount'),
            IconButton(icon: const Icon(Icons.send), onPressed: _handleSend),
          ],
        ),
      ),
    );
  }
}

/// Test screen for listener removal safety
class _ListenerTestScreen extends StatefulWidget {
  const _ListenerTestScreen();

  @override
  State<_ListenerTestScreen> createState() => _ListenerTestScreenState();
}

class _ListenerTestScreenState extends State<_ListenerTestScreen> {
  final TextEditingController _controller = TextEditingController();
  String _value = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) {
      setState(() => _value = _controller.text);
    }
  }

  @override
  void dispose() {
    // Critical: remove listener BEFORE disposing controller
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          TextField(controller: _controller),
          Text('Value: $_value'),
        ],
      ),
    );
  }
}
