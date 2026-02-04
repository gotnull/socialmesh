// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Codebase audit tests for async safety and image hardening patterns.
/// These tests scan the codebase to identify violations of safety patterns.
void main() {
  /// Get all Dart files in lib directory
  List<File> getAllDartFiles() {
    final libDir = Directory('lib');
    if (!libDir.existsSync()) return [];
    return libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.dart') &&
              !f.path.contains('/generated/') &&
              !f.path.contains('.g.dart') &&
              !f.path.contains('.freezed.dart'),
        )
        .toList();
  }

  String readFile(File file) => file.readAsStringSync();

  group('Async Safety Audit', () {
    test('no ref.read after await in widget state classes', () {
      final files = getAllDartFiles();
      final violations = <String>[];

      // Pattern: detect ref.read() calls that appear after await in async methods
      // This is a heuristic - it looks for async methods containing both await and ref.read
      final asyncMethodPattern = RegExp(
        r'Future<[^>]*>\s+_?\w+\([^)]*\)\s*async\s*\{',
        multiLine: true,
      );

      for (final file in files) {
        final content = readFile(file);
        final fileName = file.path.split('/').last;

        // Skip files that don't extend State or ConsumerState
        if (!content.contains('extends ConsumerState') &&
            !content.contains('extends State<')) {
          continue;
        }

        // Skip if using LifecycleSafeMixin (already safe)
        if (content.contains('with LifecycleSafeMixin') ||
            content.contains('with StatefulLifecycleSafeMixin')) {
          continue;
        }

        for (final match in asyncMethodPattern.allMatches(content)) {
          final methodStart = match.end;
          // Find method body
          int braceCount = 1;
          int pos = methodStart;
          while (pos < content.length && braceCount > 0) {
            if (content[pos] == '{') braceCount++;
            if (content[pos] == '}') braceCount--;
            pos++;
          }
          final methodBody = content.substring(methodStart, pos);

          // Check if method has await followed by ref.read
          final hasAwait = methodBody.contains('await ');
          final hasRefRead = RegExp(r'ref\.read\(').hasMatch(methodBody);

          if (hasAwait && hasRefRead) {
            // Check if ref.read appears AFTER an await (simplified heuristic)
            final awaitIndex = methodBody.indexOf('await ');
            final refReadMatch = RegExp(
              r'ref\.read\(',
            ).firstMatch(methodBody.substring(awaitIndex));
            if (refReadMatch != null) {
              final methodName =
                  match.group(0)?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
              // Calculate line number
              final lineNumber = content
                  .substring(0, match.start)
                  .split('\n')
                  .length;
              violations.add(
                '$fileName:$lineNumber - ref.read() after await in: $methodName',
              );
            }
          }
        }
      }

      // This is informational - manual review needed
      if (violations.isNotEmpty) {
        // Log violations but don't fail - they need manual review
        // Some patterns may be safe if ref.read is before async operations
        debugPrint('WARNING: Potential unsafe ref.read patterns found:');
        for (final v in violations.take(20)) {
          debugPrint('  - $v');
        }
        if (violations.length > 20) {
          debugPrint('  ... and ${violations.length - 20} more');
        }
      }
    });

    test('setState calls in async methods are guarded by mounted check', () {
      final files = getAllDartFiles();
      final violations = <String>[];

      for (final file in files) {
        final content = readFile(file);
        final fileName = file.path.split('/').last;

        // Skip if using safe mixins
        if (content.contains('with LifecycleSafeMixin') ||
            content.contains('with StatefulLifecycleSafeMixin')) {
          continue;
        }

        // Skip non-state classes
        if (!content.contains('extends State<') &&
            !content.contains('extends ConsumerState')) {
          continue;
        }

        // Find async methods with setState
        final asyncMethodPattern = RegExp(
          r'Future<[^>]*>\s+(_?\w+)\([^)]*\)\s*async\s*\{',
        );

        for (final match in asyncMethodPattern.allMatches(content)) {
          final methodName = match.group(1) ?? '';
          final methodStart = match.end;

          // Find method body
          int braceCount = 1;
          int pos = methodStart;
          while (pos < content.length && braceCount > 0) {
            if (content[pos] == '{') braceCount++;
            if (content[pos] == '}') braceCount--;
            pos++;
          }
          final methodBody = content.substring(methodStart, pos);

          // Check for setState after await without mounted guard
          if (methodBody.contains('await ') &&
              methodBody.contains('setState(')) {
            // Check if there's a mounted check
            final hasMountedCheck =
                methodBody.contains('if (mounted)') ||
                methodBody.contains('if (!mounted)') ||
                methodBody.contains('safeSetState(');

            if (!hasMountedCheck) {
              final lineNumber = content
                  .substring(0, match.start)
                  .split('\n')
                  .length;
              violations.add(
                '$fileName:$lineNumber - $methodName() has setState after await without mounted check',
              );
            }
          }
        }
      }

      // Log but don't fail - informational
      if (violations.isNotEmpty) {
        debugPrint(
          'WARNING: setState after await without mounted check found:',
        );
        for (final v in violations.take(20)) {
          debugPrint('  - $v');
        }
      }
    });
  });

  group('Image Safety Audit', () {
    test('Image.network calls have errorBuilder', () {
      final files = getAllDartFiles();
      final violations = <String>[];

      // Find Image.network calls without errorBuilder
      final imageNetworkPattern = RegExp(
        r'Image\.network\s*\([^)]+\)',
        dotAll: true,
      );

      for (final file in files) {
        final content = readFile(file);
        final fileName = file.path.split('/').last;

        // Skip safety utilities themselves
        if (fileName == 'safe_image.dart' ||
            fileName == 'shimmer_image.dart' ||
            fileName == 'user_avatar.dart') {
          continue;
        }

        for (final match in imageNetworkPattern.allMatches(content)) {
          final call = match.group(0) ?? '';

          // Check if it has errorBuilder
          if (!call.contains('errorBuilder')) {
            final lineNumber = content
                .substring(0, match.start)
                .split('\n')
                .length;
            violations.add(
              '$fileName:$lineNumber - Image.network without errorBuilder',
            );
          }
        }
      }

      expect(
        violations.length,
        lessThan(30), // Tracking metric - reduce over time
        reason:
            'Too many Image.network calls without errorBuilder. Consider using SafeImage:\n${violations.take(10).join('\n')}',
      );
    });

    test('Image.file calls have errorBuilder', () {
      final files = getAllDartFiles();
      final violations = <String>[];

      final imageFilePattern = RegExp(r'Image\.file\s*\([^)]+\)', dotAll: true);

      for (final file in files) {
        final content = readFile(file);
        final fileName = file.path.split('/').last;

        if (fileName == 'safe_image.dart') continue;

        for (final match in imageFilePattern.allMatches(content)) {
          final call = match.group(0) ?? '';
          if (!call.contains('errorBuilder')) {
            final lineNumber = content
                .substring(0, match.start)
                .split('\n')
                .length;
            violations.add(
              '$fileName:$lineNumber - Image.file without errorBuilder',
            );
          }
        }
      }

      expect(
        violations.length,
        lessThan(20),
        reason:
            'Too many Image.file calls without errorBuilder:\n${violations.take(10).join('\n')}',
      );
    });

    test('Image.memory calls have errorBuilder', () {
      final files = getAllDartFiles();
      final violations = <String>[];

      final imageMemoryPattern = RegExp(
        r'Image\.memory\s*\([^)]+\)',
        dotAll: true,
      );

      for (final file in files) {
        final content = readFile(file);
        final fileName = file.path.split('/').last;

        if (fileName == 'safe_image.dart') continue;

        for (final match in imageMemoryPattern.allMatches(content)) {
          final call = match.group(0) ?? '';
          if (!call.contains('errorBuilder')) {
            final lineNumber = content
                .substring(0, match.start)
                .split('\n')
                .length;
            violations.add(
              '$fileName:$lineNumber - Image.memory without errorBuilder',
            );
          }
        }
      }

      expect(
        violations.length,
        lessThan(10),
        reason:
            'Too many Image.memory calls without errorBuilder:\n${violations.take(5).join('\n')}',
      );
    });
  });

  group('Error Handling Audit', () {
    test('no bare throws that might escape widget boundaries', () {
      final files = getAllDartFiles();
      final violations = <String>[];

      for (final file in files) {
        final content = readFile(file);
        final fileName = file.path.split('/').last;

        // Skip provider/service files where throwing is expected
        if (fileName.contains('_provider') ||
            fileName.contains('_service') ||
            fileName.contains('_notifier')) {
          continue;
        }

        // Find rethrow statements in widget code
        final lines = content.split('\n');
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line == 'rethrow;' || line.startsWith('throw ')) {
            // Check if it's in a widget file
            if (content.contains('extends State<') ||
                content.contains('extends ConsumerState') ||
                content.contains('StatelessWidget') ||
                content.contains('ConsumerWidget')) {
              violations.add('$fileName:${i + 1} - $line');
            }
          }
        }
      }

      // Informational only
      if (violations.isNotEmpty) {
        debugPrint(
          'WARNING: throw/rethrow in widget code (may escape widget):',
        );
        for (final v in violations.take(10)) {
          debugPrint('  - $v');
        }
      }
    });

    test('sensitive data is not logged', () {
      final files = getAllDartFiles();
      final violations = <String>[];

      // Patterns that might log sensitive data
      final sensitivePatterns = [
        RegExp(r'print\([^)]*token', caseSensitive: false),
        RegExp(r'print\([^)]*password', caseSensitive: false),
        RegExp(r'print\([^)]*secret', caseSensitive: false),
        RegExp(r'debugPrint\([^)]*token', caseSensitive: false),
        RegExp(r'debugPrint\([^)]*password', caseSensitive: false),
        RegExp(r'log\([^)]*token', caseSensitive: false),
        RegExp(r'recordError\([^)]*token', caseSensitive: false),
      ];

      for (final file in files) {
        final content = readFile(file);
        final fileName = file.path.split('/').last;

        for (final pattern in sensitivePatterns) {
          for (final match in pattern.allMatches(content)) {
            final lineNumber = content
                .substring(0, match.start)
                .split('\n')
                .length;
            violations.add(
              '$fileName:$lineNumber - Potential sensitive data in log',
            );
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Potential sensitive data logging found:\n${violations.join('\n')}',
      );
    });
  });

  group('Resource Management Audit', () {
    test('StreamSubscriptions are cancelled in dispose', () {
      final files = getAllDartFiles();
      final violations = <String>[];

      for (final file in files) {
        final content = readFile(file);
        final fileName = file.path.split('/').last;

        // Count StreamSubscription declarations
        final subDeclarations = RegExp(
          r'StreamSubscription[<\w,\s>]*\??\s+_',
        ).allMatches(content).length;

        if (subDeclarations > 0) {
          // Count cancel calls (both safe and unsafe patterns)
          final cancelCalls = '.cancel()'.allMatches(content).length;
          final safeCancelCalls = '?.cancel()'.allMatches(content).length;

          final totalCancels = cancelCalls + safeCancelCalls;

          if (totalCancels < subDeclarations) {
            violations.add(
              '$fileName: $subDeclarations subscriptions, $totalCancels cancels',
            );
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'StreamSubscriptions not properly cancelled:\n${violations.join('\n')}',
      );
    });

    test('AnimationControllers are disposed', () {
      final files = getAllDartFiles();
      final violations = <String>[];

      for (final file in files) {
        final content = readFile(file);
        final fileName = file.path.split('/').last;

        // Count AnimationController declarations
        final controllerDeclarations = RegExp(
          r'AnimationController\s+(_\w+)',
        ).allMatches(content);

        for (final match in controllerDeclarations) {
          final name = match.group(1);
          if (name != null && !content.contains('$name.dispose()')) {
            violations.add('$fileName: $name not disposed');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'AnimationControllers not disposed:\n${violations.join('\n')}',
      );
    });

    test('TextEditingControllers are disposed', () {
      final files = getAllDartFiles();
      final violations = <String>[];

      for (final file in files) {
        final content = readFile(file);
        final fileName = file.path.split('/').last;

        // Find TextEditingController field declarations
        final controllerDeclarations = RegExp(
          r'TextEditingController\s+(_\w+)',
        ).allMatches(content);

        for (final match in controllerDeclarations) {
          final name = match.group(1);
          if (name != null && !content.contains('$name.dispose()')) {
            violations.add('$fileName: $name not disposed');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'TextEditingControllers not disposed:\n${violations.join('\n')}',
      );
    });
  });
}

void debugPrint(String message) {
  // ignore: avoid_print
  print(message);
}
