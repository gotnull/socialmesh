import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Offline-first correctness audit tests
///
/// Verifies that network-dependent code follows offline-first patterns:
/// - Image.network always has errorBuilder
/// - HTTP calls have timeouts
/// - Cloud-dependent operations check connectivity
/// - Error states in .when() are never silently hidden
void main() {
  final libDir = Directory('lib');

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

  group('Offline-First: Image Safety', () {
    test('all Image.network calls have errorBuilder', () {
      final files = getAllDartFiles(libDir);
      final violations = <String>[];

      for (final file in files) {
        final content = readFile(file);
        final lines = content.split('\n');

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();

          // Find Image.network( calls
          if (!line.contains('Image.network(') &&
              !line.contains('Image.network (')) {
            continue;
          }

          // Skip comments and SafeImage.network
          if (line.startsWith('//') || line.contains('SafeImage.network')) {
            continue;
          }

          // Look ahead up to 20 lines to find errorBuilder in the same
          // constructor call. Track parentheses to find the call boundary.
          bool hasErrorBuilder = false;
          int parenDepth = 0;
          bool started = false;

          for (int j = i; j < lines.length && j < i + 30; j++) {
            final checkLine = lines[j];
            for (int c = 0; c < checkLine.length; c++) {
              if (checkLine[c] == '(') {
                parenDepth++;
                started = true;
              } else if (checkLine[c] == ')') {
                parenDepth--;
              }
            }
            if (checkLine.contains('errorBuilder')) {
              hasErrorBuilder = true;
              break;
            }
            // If we've closed all parens, the constructor call is complete
            if (started && parenDepth <= 0) break;
          }

          if (!hasErrorBuilder) {
            violations.add('${file.path}:${i + 1}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Image.network without errorBuilder: ${violations.join(', ')}',
      );
    });
  });

  group('Offline-First: HTTP Timeouts', () {
    test('HTTP client.get calls have timeout', () {
      final files = getAllDartFiles(libDir);
      final violations = <String>[];

      for (final file in files) {
        final content = readFile(file);
        final lines = content.split('\n');

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();

          // Find _client.get( or http.get( patterns (actual HTTP calls)
          if (!line.contains('_client.get(') &&
              !line.contains('http.get(') &&
              !line.contains('_client.post(') &&
              !line.contains('http.post(')) {
            continue;
          }

          // Skip comments
          if (line.startsWith('//')) continue;

          // Check this line and next for .timeout(
          final nextLine = i + 1 < lines.length ? lines[i + 1].trim() : '';
          if (!line.contains('.timeout(') && !nextLine.contains('.timeout(')) {
            violations.add('${file.path}:${i + 1}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'HTTP calls without timeout: ${violations.join(', ')}',
      );
    });
  });

  group('Offline-First: Error State Visibility', () {
    test('no silent SizedBox.shrink in device shop main screen', () {
      // Focus on device_shop_screen.dart which depends on external LILYGO
      // HTTP API. Other shop screens using Firestore (review_moderation,
      // search_products, partners) benefit from Firestore persistence cache
      // and SizedBox.shrink is acceptable for those.
      final file = File(
        'lib/features/device_shop/screens/device_shop_screen.dart',
      );
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      final lines = content.split('\n');
      final violations = <String>[];

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.contains('error:') && line.contains('SizedBox.shrink')) {
          // Allow SizedBox.shrink for Firestore-cached sections (Partners)
          // which benefit from Firestore offline persistence.
          // Check surrounding lines for Firestore provider context.
          final context5 = lines
              .sublist((i - 5).clamp(0, lines.length), i)
              .join(' ');
          if (context5.contains('officialPartnersProvider')) continue;

          violations.add('device_shop_screen.dart:${i + 1}');
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Silent error handlers in device shop main screen: '
            '${violations.join(', ')}',
      );
    });
  });

  group('Offline-First: Connectivity Guards', () {
    test('Firebase Storage upload methods check connectivity', () {
      final files = getAllDartFiles(libDir);
      final violations = <String>[];

      // Services that directly upload to Firebase Storage and are
      // user-initiated (not background sync) should have connectivity
      // checks. Background sync services (profile_cloud_sync_service,
      // signal_service) are gated at the provider/entitlement level.
      const directUploadServices = {'bug_report_service.dart'};

      for (final file in files) {
        final content = readFile(file);
        final fileName = file.path.split('/').last;

        // Only check direct user-initiated upload services
        if (!directUploadServices.contains(fileName)) continue;

        // Files that use Firebase Storage uploads
        if (!content.contains('.putData(') && !content.contains('.putFile(')) {
          continue;
        }

        // Must also reference connectivity check
        if (!content.contains('isOnlineProvider') &&
            !content.contains('canUseCloudFeaturesProvider') &&
            !content.contains('isOnline')) {
          violations.add(file.path);
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Storage uploads without connectivity check: '
            '${violations.join(', ')}',
      );
    });

    test('Story creation checks connectivity at provider level', () {
      // story_service.dart itself has Cloud Functions calls but the
      // connectivity gate is in story_providers.dart (CreateStoryNotifier)
      final providerFile = File('lib/providers/story_providers.dart');
      expect(providerFile.existsSync(), isTrue);
      final content = providerFile.readAsStringSync();
      expect(
        content.contains('isOnlineProvider'),
        isTrue,
        reason:
            'story_providers.dart must check isOnlineProvider '
            'before calling createStory',
      );
    });

    test('Bug report service checks connectivity before submission', () {
      final serviceFile = File('lib/services/bug_report_service.dart');
      expect(serviceFile.existsSync(), isTrue);
      final content = serviceFile.readAsStringSync();
      expect(
        content.contains('isOnlineProvider'),
        isTrue,
        reason:
            'bug_report_service.dart must check isOnlineProvider '
            'before uploading to Storage/Functions',
      );
    });
  });
}
