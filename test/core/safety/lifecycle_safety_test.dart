// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:socialmesh/core/safety/lifecycle_mixin.dart';
import 'package:socialmesh/core/safety/safe_image.dart';

void main() {
  group('LifecycleSafeMixin Tests', () {
    testWidgets('safeSetState does not throw when widget is disposed', (
      tester,
    ) async {
      bool setStateCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: _TestLifecycleWidget(
              onTap: (state) async {
                // Start async operation
                await Future.delayed(const Duration(milliseconds: 100));

                // Try to call setState after widget might be disposed
                setStateCalled = state.safeSetState(() {});
              },
            ),
          ),
        ),
      );

      // Find and tap the button to start async operation
      await tester.tap(find.byType(ElevatedButton));

      // Immediately navigate away (dispose the widget)
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: Text('New Screen'))),
        ),
      );

      // Wait for async operation to complete
      await tester.pump(const Duration(milliseconds: 200));

      // safeSetState should return false because widget was disposed
      expect(setStateCalled, isFalse);
    });

    testWidgets('safeNavigatorPop does not throw when disposed', (
      tester,
    ) async {
      bool popCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: _TestLifecycleWidget(
              onTap: (state) async {
                await Future.delayed(const Duration(milliseconds: 100));
                popCalled = state.safeNavigatorPop(true);
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));

      // Navigate away before async completes
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: Text('New Screen'))),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      expect(popCalled, isFalse);
    });

    testWidgets('safeAsync catches errors and calls onError', (tester) async {
      Object? caughtError;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: _TestLifecycleWidget(
              onTap: (state) async {
                await state.safeAsync(
                  work: () async {
                    throw Exception('Test error');
                  },
                  onError: (e, st) {
                    caughtError = e;
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(caughtError, isA<Exception>());
    });

    testWidgets('safeAsync does not call onError if disposed', (tester) async {
      bool onErrorCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: _TestLifecycleWidget(
              onTap: (state) async {
                await state.safeAsync(
                  work: () async {
                    await Future.delayed(const Duration(milliseconds: 100));
                    throw Exception('Test error');
                  },
                  onError: (e, st) {
                    onErrorCalled = true;
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));

      // Navigate away before async completes
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: Text('New Screen'))),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      // onError should not be called because widget was disposed
      expect(onErrorCalled, isFalse);
    });
  });

  group('SafeAsyncResult Tests', () {
    test('SafeAsyncSuccess holds data correctly', () {
      const result = SafeAsyncSuccess<int>(42);

      expect(result.isSuccess, isTrue);
      expect(result.isError, isFalse);
      expect(result.dataOrNull, equals(42));
      expect(result.errorOrNull, isNull);
    });

    test('SafeAsyncError holds error correctly', () {
      final result = SafeAsyncError<int>(Exception('test'), StackTrace.current);

      expect(result.isSuccess, isFalse);
      expect(result.isError, isTrue);
      expect(result.dataOrNull, isNull);
      expect(result.errorOrNull, isA<Exception>());
    });

    test('when calls correct callback', () {
      const success = SafeAsyncSuccess<int>(42);
      final error = SafeAsyncError<int>(Exception('test'));

      final successResult = success.when(
        success: (data) => 'success: $data',
        error: (e, st) => 'error: $e',
      );

      final errorResult = error.when(
        success: (data) => 'success: $data',
        error: (e, st) => 'error',
      );

      expect(successResult, equals('success: 42'));
      expect(errorResult, equals('error'));
    });

    test('toResult extension catches errors', () async {
      final successFuture = Future.value(42);
      final errorFuture = Future<int>.error(Exception('test'));

      final successResult = await successFuture.toResult();
      final errorResult = await errorFuture.toResult();

      expect(successResult.isSuccess, isTrue);
      expect(errorResult.isError, isTrue);
    });
  });

  group('SafeImage Tests', () {
    testWidgets('SafeImage.network shows placeholder while loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeImage.network(
              'https://example.com/nonexistent.jpg',
              width: 100,
              height: 100,
              placeholder: const Text('Loading'),
            ),
          ),
        ),
      );

      // Should show placeholder initially
      expect(find.text('Loading'), findsOneWidget);
    });

    testWidgets('SafeImage.network shows error widget on failure', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeImage.network(
              'invalid://url',
              width: 100,
              height: 100,
              errorWidget: const Text('Error'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // After loading fails, should show error widget
      expect(find.text('Error'), findsOneWidget);
    });

    testWidgets('SafeImage.memory handles corrupt bytes without crashing', (
      tester,
    ) async {
      // Corrupt bytes that can't be decoded as an image
      final corruptBytes = Uint8List.fromList([0, 1, 2, 3, 4, 5]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeImage.memory(
              corruptBytes,
              width: 100,
              height: 100,
              errorWidget: const Text('Error'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show error widget, not crash
      expect(find.text('Error'), findsOneWidget);
    });

    testWidgets('SafeImage.file handles missing file without crashing', (
      tester,
    ) async {
      final missingFile = File('/nonexistent/path/image.jpg');

      // This test verifies that SafeImage doesn't throw a fatal exception
      // when loading a missing file. The error handling is async and
      // platform-specific, so we just verify it doesn't crash during build.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeImage.file(
              missingFile,
              width: 100,
              height: 100,
              errorWidget: const Text('Error'),
              placeholder: const Text('Loading'),
            ),
          ),
        ),
      );

      // The widget should build without throwing
      // Placeholder or error widget should be shown depending on timing
      await tester.pump();

      // Verify no fatal crash occurred - the test completing is the success
      expect(find.byType(SafeImage), findsOneWidget);
    });

    testWidgets('SafeImage applies borderRadius', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeImage.network(
              'https://example.com/image.jpg',
              width: 100,
              height: 100,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );

      expect(find.byType(ClipRRect), findsOneWidget);
    });

    testWidgets('SafeImage applies circle shape', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeImage.network(
              'https://example.com/image.jpg',
              width: 100,
              height: 100,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );

      expect(find.byType(ClipOval), findsOneWidget);
    });
  });

  group('Bottom Sheet Dismissal During Async', () {
    testWidgets(
      'dismissing bottom sheet during async operation does not crash',
      (tester) async {
        bool errorOccurred = false;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => _TestBottomSheet(
                          onError: () => errorOccurred = true,
                        ),
                      );
                    },
                    child: const Text('Open Sheet'),
                  ),
                ),
              ),
            ),
          ),
        );

        // Open the bottom sheet
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        // Start the async save operation
        await tester.tap(find.text('Save'));
        await tester.pump();

        // Immediately dismiss the sheet by tapping outside
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();

        // Wait for async operation to complete
        await tester.pump(const Duration(milliseconds: 500));

        // No error should have occurred
        expect(errorOccurred, isFalse);
      },
    );
  });
}

/// Test widget that uses LifecycleSafeMixin
class _TestLifecycleWidget extends ConsumerStatefulWidget {
  const _TestLifecycleWidget({required this.onTap});

  final Future<void> Function(_TestLifecycleWidgetState state) onTap;

  @override
  ConsumerState<_TestLifecycleWidget> createState() =>
      _TestLifecycleWidgetState();
}

class _TestLifecycleWidgetState extends ConsumerState<_TestLifecycleWidget>
    with LifecycleSafeMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ElevatedButton(
        onPressed: () => widget.onTap(this),
        child: const Text('Test'),
      ),
    );
  }
}

/// Test bottom sheet that simulates async save operation
class _TestBottomSheet extends StatefulWidget {
  const _TestBottomSheet({required this.onError});

  final VoidCallback onError;

  @override
  State<_TestBottomSheet> createState() => _TestBottomSheetState();
}

class _TestBottomSheetState extends State<_TestBottomSheet>
    with StatefulLifecycleSafeMixin {
  bool _loading = false;

  Future<void> _save() async {
    safeSetState(() => _loading = true);

    try {
      // Simulate async operation
      await Future.delayed(const Duration(milliseconds: 300));

      // Use safe methods - these won't throw if disposed
      safeSetState(() => _loading = false);
      safeNavigatorPop(true);
    } catch (e) {
      widget.onError();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : ElevatedButton(onPressed: _save, child: const Text('Save')),
      ),
    );
  }
}
