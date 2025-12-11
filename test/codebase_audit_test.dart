import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Systematic codebase audit tests
/// These tests verify code quality patterns across the entire codebase
void main() {
  final libDir = Directory('lib');
  final featuresDir = Directory('lib/features');
  final servicesDir = Directory('lib/services');

  List<File> getAllDartFiles(Directory dir, {bool excludeGenerated = true}) {
    if (!dir.existsSync()) return [];
    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !excludeGenerated || !f.path.contains('/generated/'))
        .toList();
  }

  String readFile(File file) => file.readAsStringSync();

  group('Audit 1: Empty Stubs and Placeholders', () {
    test('no unimplemented error throws in production code', () {
      final files = getAllDartFiles(libDir);
      final violations = <String>[];

      for (final file in files) {
        final content = readFile(file);
        if (content.contains('throw UnimplementedError') ||
            content.contains('throw NotImplementedException')) {
          violations.add(file.path);
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Files with unimplemented errors: ${violations.join(', ')}',
      );
    });

    test('no TODO comments blocking functionality', () {
      final files = getAllDartFiles(libDir);
      final violations = <String>[];

      for (final file in files) {
        final content = readFile(file);
        final lines = content.split('\n');
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          // Only flag TODOs that indicate blocking issues
          if (line.contains('// TODO:') &&
              (line.toLowerCase().contains('implement') ||
                  line.toLowerCase().contains('fix') ||
                  line.toLowerCase().contains('broken'))) {
            violations.add('${file.path}:${i + 1}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Blocking TODOs found: ${violations.join(', ')}',
      );
    });

    test('no FIXME comments', () {
      final files = getAllDartFiles(libDir);
      final violations = <String>[];

      for (final file in files) {
        final content = readFile(file);
        if (content.contains('// FIXME')) {
          final lines = content.split('\n');
          for (int i = 0; i < lines.length; i++) {
            if (lines[i].contains('// FIXME')) {
              violations.add('${file.path}:${i + 1}');
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'FIXME comments found: ${violations.join(', ')}',
      );
    });
  });

  group('Audit 2: Config Screens Implementation', () {
    test('all config screens have _loadCurrentConfig implemented', () {
      final files = getAllDartFiles(featuresDir);
      final violations = <String>[];

      for (final file in files) {
        final content = readFile(file);
        if (content.contains('_loadCurrentConfig')) {
          // Check for empty stub patterns
          if (content.contains('// Config would be') ||
              content.contains('// For now, start with defaults')) {
            // Verify it's actually in the _loadCurrentConfig method
            final methodMatch = RegExp(
              r'Future<void>\s+_loadCurrentConfig\s*\(\s*\)\s*async\s*\{([^}]*)\}',
              multiLine: true,
            ).firstMatch(content);
            if (methodMatch != null) {
              final methodBody = methodMatch.group(1) ?? '';
              if (methodBody.contains('// Config would be') ||
                  methodBody.contains('// For now, start')) {
                violations.add(file.path);
              }
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Config screens with empty _loadCurrentConfig: ${violations.join(', ')}',
      );
    });

    test('all async config screens have loading state', () {
      final files = getAllDartFiles(featuresDir);
      final violations = <String>[];

      for (final file in files) {
        if (!file.path.contains('config_screen')) continue;
        final content = readFile(file);

        // If it has async _loadCurrentConfig, it should have loading state
        if (content.contains('Future<void> _loadCurrentConfig') &&
            content.contains('async')) {
          // Check for a loading state variable
          if (!content.contains('_isLoading') &&
              !content.contains('_loading')) {
            // Exception: sync loading from local providers (check for ref.read pattern without await)
            final methodMatch = RegExp(
              r'void\s+_loadCurrentConfig\s*\(\s*\)\s*\{',
            ).hasMatch(content);
            if (!methodMatch) {
              violations.add(file.path);
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Config screens without loading state: ${violations.join(', ')}',
      );
    });
  });

  group('Audit 3: Resource Management', () {
    test('StreamSubscriptions are cancelled in dispose', () {
      final files = getAllDartFiles(libDir);
      final violations = <String>[];

      for (final file in files) {
        final content = readFile(file);
        final subscriptionCount = RegExp(
          r'StreamSubscription[<\w,\s>]*\??\s+_',
        ).allMatches(content).length;

        if (subscriptionCount > 0) {
          final cancelCount = RegExp(
            r'\.cancel\(\)',
          ).allMatches(content).length;
          // Should have at least as many cancels as subscriptions
          // (may have more due to null-safe ?. calls)
          if (cancelCount < subscriptionCount) {
            violations.add(
              '${file.path} ($subscriptionCount subs, $cancelCount cancels)',
            );
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Files with uncancelled subscriptions: ${violations.join(', ')}',
      );
    });

    test('TextEditingControllers are disposed', () {
      final files = getAllDartFiles(featuresDir);
      final violations = <String>[];

      for (final file in files) {
        final content = readFile(file);

        // Count class-level TextEditingController declarations
        final controllerDeclarations = RegExp(
          r'(late\s+)?TextEditingController\s+_\w+',
        ).allMatches(content).length;

        if (controllerDeclarations > 0) {
          // Allow for some flexibility (local controllers in methods don't need dispose)
          // But class-level controllers should be disposed
          if (content.contains('late TextEditingController') ||
              content.contains('TextEditingController _')) {
            final hasDisposeMethod = content.contains('void dispose()');
            if (!hasDisposeMethod && controllerDeclarations > 0) {
              violations.add(file.path);
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Files without dispose for controllers: ${violations.join(', ')}',
      );
    });
  });

  group('Audit 4: Service Implementation', () {
    test('no services have empty method bodies', () {
      final files = getAllDartFiles(servicesDir);
      final violations = <String>[];

      for (final file in files) {
        final content = readFile(file);
        final lines = content.split('\n');

        for (int i = 0; i < lines.length - 1; i++) {
          final line = lines[i];
          final nextLine = i + 1 < lines.length ? lines[i + 1] : '';

          // Pattern: method declaration ending with { followed by just }
          if (line.contains('async {') && nextLine.trim() == '}') {
            violations.add('${file.path}:${i + 1}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Services with empty methods: ${violations.join(', ')}',
      );
    });
  });

  group('Audit 5: Code Quality', () {
    test('no debug print statements left in production code', () {
      final files = getAllDartFiles(libDir);
      final violations = <String>[];

      for (final file in files) {
        // Skip test files
        if (file.path.contains('/test/')) continue;

        final content = readFile(file);
        // Match print( but not debugPrint( or _logger
        final printMatches = RegExp(r'(?<!debug)print\(')
            .allMatches(content)
            .where((m) {
              // Check it's not in a comment
              final lineStart = content.lastIndexOf('\n', m.start) + 1;
              final beforeMatch = content.substring(lineStart, m.start);
              return !beforeMatch.contains('//');
            });

        if (printMatches.isNotEmpty) {
          violations.add('${file.path} (${printMatches.length} occurrences)');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Files with print() statements: ${violations.join(', ')}',
      );
    });

    test('no empty catch blocks', () {
      final files = getAllDartFiles(libDir);
      final violations = <String>[];

      for (final file in files) {
        final content = readFile(file);

        // Pattern: catch(...) { } or catch(...) {\n} - but allow if in nested try for cleanup
        final emptyCatchPattern = RegExp(
          r'catch\s*\([^)]*\)\s*\{\s*\}',
          multiLine: true,
        );

        final matches = emptyCatchPattern.allMatches(content);
        for (final match in matches) {
          // Find line number
          final lineNum = content.substring(0, match.start).split('\n').length;

          // Check if this is an intentional cleanup catch by looking at context
          // A nested try inside a catch block is typically for cleanup that can fail
          final contextStart = (match.start - 200).clamp(0, content.length);
          final context = content.substring(contextStart, match.start);

          // If we see "} catch" followed by another "try {" in the context,
          // this is likely a nested cleanup try that's allowed to fail silently
          final isNestedCleanupTry =
              context.contains('} catch') &&
              context.contains('try {') &&
              context.split('try {').length > context.split('} catch').length;

          // Also allow if it's a simple rethrow-prevention pattern with _
          final catchParam = RegExp(
            r'catch\s*\((_)\)',
          ).hasMatch(content.substring(match.start, match.end + 10));

          if (isNestedCleanupTry || catchParam) {
            continue;
          }

          violations.add('${file.path}:$lineNum');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Files with empty catch blocks: ${violations.join(', ')}',
      );
    });

    test('no hardcoded localhost or IP addresses', () {
      final files = getAllDartFiles(libDir);
      final violations = <String>[];

      for (final file in files) {
        final content = readFile(file);

        if (content.contains('127.0.0.1') ||
            content.contains('localhost:') ||
            content.contains("'localhost'") ||
            content.contains('"localhost"')) {
          // Check it's not in a comment or kDebugMode block
          final lines = content.split('\n');
          bool inDebugBlock = false;
          for (int i = 0; i < lines.length; i++) {
            final line = lines[i];
            // Track if we're in a kDebugMode block
            if (line.contains('if (kDebugMode)')) {
              inDebugBlock = true;
            }
            if (inDebugBlock && line.contains('}')) {
              // Count braces to detect end of block (simplified)
              if (!line.contains('{')) {
                inDebugBlock = false;
              }
            }
            if ((line.contains('127.0.0.1') || line.contains('localhost')) &&
                !line.trimLeft().startsWith('//') &&
                !inDebugBlock) {
              violations.add('${file.path}:${i + 1}');
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Files with hardcoded addresses: ${violations.join(', ')}',
      );
    });
  });

  group('Audit 6: Flutter Patterns', () {
    test('StatefulWidgets have corresponding State class', () {
      final files = getAllDartFiles(featuresDir);
      final violations = <String>[];

      for (final file in files) {
        final content = readFile(file);

        // Find all StatefulWidget, ConsumerStatefulWidget declarations
        final widgetMatches = RegExp(
          r'class\s+(\w+)\s+extends\s+(?:Consumer)?(?:Hook)?(?:Consumer)?StatefulWidget',
        ).allMatches(content);

        for (final match in widgetMatches) {
          final widgetName = match.group(1);
          if (widgetName != null) {
            // Should have a corresponding State class - matches State<X>, ConsumerState<X>, etc.
            // Common patterns:
            // 1. Private: _Widget -> _WidgetState
            // 2. Public: Widget -> _WidgetState or WidgetState
            final baseName = widgetName.startsWith('_')
                ? widgetName.substring(1)
                : widgetName;

            // Check for any of: _WidgetState, WidgetState
            final hasState = RegExp(
              'class\\s+_?${RegExp.escape(baseName)}State\\s+extends\\s+\\w*State',
            ).hasMatch(content);

            if (!hasState) {
              violations.add('${file.path}: $widgetName missing State class');
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Widgets without State class: ${violations.join(', ')}',
      );
    });

    test('build methods return Widget', () {
      final files = getAllDartFiles(featuresDir);
      final violations = <String>[];

      for (final file in files) {
        final content = readFile(file);

        // Check for build methods that don't return Widget
        final buildMethodPattern = RegExp(
          r'Widget\s+build\s*\(\s*BuildContext',
        );

        // If file has State class, it should have proper build method
        if (content.contains('extends State<') ||
            content.contains('extends ConsumerState<')) {
          if (!buildMethodPattern.hasMatch(content)) {
            violations.add(file.path);
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'State classes without build method: ${violations.join(', ')}',
      );
    });
  });

  group('Audit 7: Navigation', () {
    test('all navigated screens exist as classes', () {
      final files = getAllDartFiles(libDir);
      final allContent = files.map((f) => readFile(f)).join('\n');

      final violations = <String>[];

      // Find all screen class names referenced in navigation
      final navigationPattern = RegExp(
        r'MaterialPageRoute.*?builder.*?(\w+Screen)\(',
      );

      final matches = navigationPattern.allMatches(allContent);
      for (final match in matches) {
        final screenName = match.group(1);
        if (screenName != null && screenName != 'MaterialPageRoute') {
          // Check if class exists
          final classPattern = RegExp('class\\s+$screenName\\s+extends');
          if (!classPattern.hasMatch(allContent)) {
            violations.add(screenName);
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Missing screen classes: ${violations.join(', ')}',
      );
    });
  });

  group('Audit 8: Provider Implementation', () {
    test('no providers with uninitialized state', () {
      final providersDir = Directory('lib/providers');
      if (!providersDir.existsSync()) return;

      final files = getAllDartFiles(providersDir);
      final violations = <String>[];

      for (final file in files) {
        final content = readFile(file);

        // Check for StateNotifier or ChangeNotifier with null initial state
        if (content.contains('StateNotifier<') ||
            content.contains('ChangeNotifier')) {
          // Pattern: state that starts as null without initialization
          if (content.contains('state = null') &&
              !content.contains('state = null;') &&
              !content.contains('// Initially null')) {
            violations.add(file.path);
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Providers with uninitialized state: ${violations.join(', ')}',
      );
    });
  });
}
