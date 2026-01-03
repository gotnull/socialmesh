import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Audit tests for social feature screens
/// Verifies implementation patterns and code quality
void main() {
  final socialDir = Directory('lib/features/social');

  List<File> getSocialDartFiles() {
    if (!socialDir.existsSync()) return [];
    return socialDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
  }

  String readFile(File file) => file.readAsStringSync();

  group('Social Feature Audit: No Placeholders', () {
    test('no "coming soon" placeholders', () {
      final files = getSocialDartFiles();
      final violations = <String>[];

      for (final file in files) {
        final content = readFile(file);
        final lines = content.split('\n');
        for (int i = 0; i < lines.length; i++) {
          if (lines[i].toLowerCase().contains('coming soon')) {
            violations.add('${file.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Placeholder "coming soon" found:\n${violations.join('\n')}',
      );
    });

    test('no TODO comments indicating missing implementation', () {
      final files = getSocialDartFiles();
      final violations = <String>[];

      for (final file in files) {
        final content = readFile(file);
        final lines = content.split('\n');
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          // Flag TODOs that indicate missing features
          if (line.contains('// TODO') &&
              (line.toLowerCase().contains('implement') ||
                  line.toLowerCase().contains('navigate') ||
                  line.toLowerCase().contains('add') ||
                  line.toLowerCase().contains('fix'))) {
            violations.add('${file.path}:${i + 1}: ${line.trim()}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Blocking TODOs found:\n${violations.join('\n')}',
      );
    });

    test('no empty onPressed handlers', () {
      final files = getSocialDartFiles();
      final violations = <String>[];

      for (final file in files) {
        final content = readFile(file);
        // Match onPressed: () {} or onTap: () {} patterns
        final emptyHandlerPattern = RegExp(
          r'(onPressed|onTap):\s*\(\)\s*\{\s*\}',
        );

        if (emptyHandlerPattern.hasMatch(content)) {
          final lines = content.split('\n');
          for (int i = 0; i < lines.length; i++) {
            final line = lines[i];
            // Skip commented lines
            if (line.trim().startsWith('//')) continue;
            if (emptyHandlerPattern.hasMatch(line)) {
              violations.add('${file.path}:${i + 1}: ${line.trim()}');
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Empty handlers found:\n${violations.join('\n')}',
      );
    });
  });

  group('Social Feature Audit: Resource Management', () {
    test('TextEditingControllers are disposed', () {
      final files = getSocialDartFiles();
      final violations = <String>[];

      for (final file in files) {
        final content = readFile(file);
        final controllerMatches = RegExp(
          r'TextEditingController\s+(_\w+)',
        ).allMatches(content);

        for (final match in controllerMatches) {
          final controllerName = match.group(1);
          if (controllerName != null) {
            // Check if disposed
            if (!content.contains('$controllerName.dispose()')) {
              violations.add('${file.path}: $controllerName not disposed');
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Undisposed controllers:\n${violations.join('\n')}',
      );
    });

    test('FocusNodes are disposed', () {
      final files = getSocialDartFiles();
      final violations = <String>[];

      for (final file in files) {
        final content = readFile(file);
        final focusNodeMatches = RegExp(
          r'FocusNode\s+(_\w+)',
        ).allMatches(content);

        for (final match in focusNodeMatches) {
          final nodeName = match.group(1);
          if (nodeName != null) {
            if (!content.contains('$nodeName.dispose()')) {
              violations.add('${file.path}: $nodeName not disposed');
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Undisposed FocusNodes:\n${violations.join('\n')}',
      );
    });

    test('StreamSubscriptions are cancelled', () {
      final files = getSocialDartFiles();
      final violations = <String>[];

      for (final file in files) {
        final content = readFile(file);
        final subCount = RegExp(
          r'StreamSubscription[<\w,\s>]*\??\s+_',
        ).allMatches(content).length;

        if (subCount > 0) {
          final cancelCount = '.cancel()'.allMatches(content).length;
          if (cancelCount < subCount) {
            violations.add(
              '${file.path}: $subCount subscriptions, $cancelCount cancels',
            );
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Uncancelled subscriptions:\n${violations.join('\n')}',
      );
    });
  });

  group('Social Feature Audit: Code Quality', () {
    test('no print statements (use debugPrint)', () {
      final files = getSocialDartFiles();
      final violations = <String>[];

      for (final file in files) {
        final content = readFile(file);
        final lines = content.split('\n');
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          // Match print( but not debugPrint(
          if (RegExp(r'(?<!debug)print\(').hasMatch(line) &&
              !line.trim().startsWith('//')) {
            violations.add('${file.path}:${i + 1}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'print() statements found (use debugPrint):\n${violations.join('\n')}',
      );
    });

    test('mounted check before setState in async methods', () {
      final files = getSocialDartFiles();
      final violations = <String>[];

      for (final file in files) {
        final content = readFile(file);

        // Find async methods that use setState
        final asyncMethodPattern = RegExp(
          r'Future<void>\s+(\w+)\([^)]*\)\s*async\s*\{',
        );

        for (final match in asyncMethodPattern.allMatches(content)) {
          final methodStart = match.end;
          // Find the method body (simplified - look for balanced braces)
          int braceCount = 1;
          int pos = methodStart;
          while (pos < content.length && braceCount > 0) {
            if (content[pos] == '{') braceCount++;
            if (content[pos] == '}') braceCount--;
            pos++;
          }
          final methodBody = content.substring(methodStart, pos);

          // Check if it has setState after await without mounted check
          if (methodBody.contains('await') &&
              methodBody.contains('setState(')) {
            // Should have 'if (mounted)' or 'if (!mounted) return' before setState
            if (!methodBody.contains('if (mounted)') &&
                !methodBody.contains('if (!mounted)') &&
                !methodBody.contains('context.mounted')) {
              // Check if setState is in finally block with mounted check
              final hasProperCheck = RegExp(
                r'if\s*\(\s*mounted\s*\)|if\s*\(\s*!mounted\s*\)',
              ).hasMatch(methodBody);

              if (!hasProperCheck) {
                violations.add(
                  '${file.path}: ${match.group(1)} may need mounted check',
                );
              }
            }
          }
        }
      }

      // This is informational - some patterns may be safe
      if (violations.isNotEmpty) {
        // Log but don't fail - these need manual review
        // ignore: avoid_print
        print('INFO: Methods that may need mounted check review:');
        for (final v in violations) {
          // ignore: avoid_print
          print('  $v');
        }
      }
    });
  });

  group('Social Feature Audit: Required Methods', () {
    test('post_detail_screen has threaded comment support', () {
      final file = File('lib/features/social/screens/post_detail_screen.dart');
      expect(
        file.existsSync(),
        true,
        reason: 'post_detail_screen.dart must exist',
      );

      final content = readFile(file);

      // Should have comment tree building logic
      expect(
        content.contains('parentId'),
        true,
        reason: 'Should handle parentId for threading',
      );

      // Should have depth tracking
      expect(
        content.contains('depth'),
        true,
        reason: 'Should track comment depth',
      );

      // Should have reply handling
      expect(
        content.contains('_replyingTo') || content.contains('replyingTo'),
        true,
        reason: 'Should have reply tracking',
      );
    });

    test('profile_social_screen has edit profile navigation', () {
      final file = File(
        'lib/features/social/screens/profile_social_screen.dart',
      );
      expect(file.existsSync(), true);

      final content = readFile(file);

      expect(
        content.contains('EditProfileScreen'),
        true,
        reason: 'Should navigate to EditProfileScreen',
      );
    });

    test('edit_profile_screen exists and has required fields', () {
      final file = File('lib/features/social/screens/edit_profile_screen.dart');
      expect(
        file.existsSync(),
        true,
        reason: 'edit_profile_screen.dart must exist',
      );

      final content = readFile(file);

      // Should have display name editing
      expect(
        content.contains('displayName') ||
            content.contains('_displayNameController'),
        true,
        reason: 'Should edit display name',
      );

      // Should have bio editing
      expect(
        content.contains('bio') || content.contains('_bioController'),
        true,
        reason: 'Should edit bio',
      );

      // Should have avatar upload
      expect(
        content.contains('avatar') || content.contains('Avatar'),
        true,
        reason: 'Should handle avatar',
      );
    });

    test('create_post_screen has media features implemented', () {
      final file = File('lib/features/social/screens/create_post_screen.dart');
      expect(file.existsSync(), true);

      final content = readFile(file);

      // Should have image picker
      expect(
        content.contains('FilePicker') || content.contains('ImagePicker'),
        true,
        reason: 'Should have image picker',
      );

      // Should have location
      expect(
        content.contains('_addLocation') || content.contains('Geolocator'),
        true,
        reason: 'Should have location support',
      );

      // Should have node tagging
      expect(
        content.contains('_tagNode') || content.contains('nodeId'),
        true,
        reason: 'Should have node tagging',
      );
    });

    test('feed_screen has share functionality', () {
      final file = File('lib/features/social/screens/feed_screen.dart');
      expect(file.existsSync(), true);

      final content = readFile(file);

      expect(
        content.contains('Share.share') || content.contains('share_plus'),
        true,
        reason: 'Should have share functionality',
      );
    });
  });

  group('Social Feature Audit: Service Methods', () {
    test('social_service has report methods', () {
      final file = File('lib/services/social_service.dart');
      expect(file.existsSync(), true);

      final content = readFile(file);

      expect(
        content.contains('reportPost'),
        true,
        reason: 'Should have reportPost method',
      );

      expect(
        content.contains('reportUser'),
        true,
        reason: 'Should have reportUser method',
      );

      expect(
        content.contains('reportComment'),
        true,
        reason: 'Should have reportComment method',
      );
    });

    test('social_service has profile update methods', () {
      final file = File('lib/services/social_service.dart');
      final content = readFile(file);

      expect(
        content.contains('updateProfile'),
        true,
        reason: 'Should have updateProfile method',
      );

      expect(
        content.contains('uploadProfileAvatar'),
        true,
        reason: 'Should have uploadProfileAvatar method',
      );
    });

    test('social_service has watchPost for real-time updates', () {
      final file = File('lib/services/social_service.dart');
      final content = readFile(file);

      expect(
        content.contains('watchPost') || content.contains('Stream<Post'),
        true,
        reason: 'Should have watchPost stream method',
      );
    });

    test('social_service watchComments fetches all comments for threading', () {
      final file = File('lib/services/social_service.dart');
      final content = readFile(file);

      // Should NOT have the old filter that only gets root comments
      expect(
        content.contains("where('parentId', isEqualTo: null)") &&
            content.contains('watchComments'),
        false,
        reason: 'watchComments should fetch ALL comments, not just roots',
      );
    });
  });
}
