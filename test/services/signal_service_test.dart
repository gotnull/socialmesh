import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:socialmesh/services/signal_service.dart';
import 'package:socialmesh/models/social.dart';

// NOTE: Imports above use package name inferred; adjust if wrong.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SignalService offline-first receive', () {
    setUpAll(() {
      // Initialize ffi implementation for sqflite in tests
      // so that openDatabase works without a Flutter embedding.
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });
    late Directory tmpDir;
    final channel = const MethodChannel('plugins.flutter.io/path_provider');

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('signal_service_test');
      channel.setMockMethodCallHandler((call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return tmpDir.path;
        }
        return null;
      });
    });

    tearDown(() async {
      channel.setMockMethodCallHandler(null);
      try {
        await tmpDir.delete(recursive: true);
      } catch (_) {}
    });

    test(
      'receive mesh packet inserts local signal even if cloud lookup throws',
      () async {
        final service = SignalService(
          cloudLookupOverride: (String id) async {
            throw Exception('Simulated Firestore failure');
          },
        );

        final signal = await service.createSignalFromMesh(
          content: 'Hello from mesh',
          senderNodeId: 123,
          signalId: 'test-offline-1',
          ttlMinutes: 15,
        );

        expect(signal, isNotNull);
        final fetched = await service.getSignalById('test-offline-1');
        expect(fetched, isNotNull);
        expect(fetched!.content, 'Hello from mesh');
      },
    );

    test(
      'cloud enrichment patches existing local signal when mediaUrls arrive later',
      () async {
        final service = SignalService(
          cloudLookupOverride: (String id) async {
            return Post(
              id: id,
              authorId: 'mesh_123',
              content: 'Hello with image',
              mediaUrls: ['https://example.com/image.jpg'],
              location: null,
              nodeId: '7b',
              createdAt: DateTime.now(),
              postMode: PostMode.signal,
              origin: SignalOrigin.mesh,
              expiresAt: DateTime.now().add(Duration(hours: 1)),
              meshNodeId: 123,
              hopCount: 0,
            );
          },
        );

        final signal = await service.createSignalFromMesh(
          content: 'Hello with image',
          senderNodeId: 123,
          signalId: 'test-enrich-1',
          ttlMinutes: 15,
        );

        expect(signal, isNotNull);

        // Wait for background enrichment to apply (poll with timeout)
        var attempts = 0;
        Post? updated;
        while (attempts < 20) {
          updated = await service.getSignalById('test-enrich-1');
          if (updated != null && updated.mediaUrls.isNotEmpty) break;
          await Future.delayed(Duration(milliseconds: 100));
          attempts++;
        }

        expect(updated, isNotNull);
        expect(updated!.mediaUrls.isNotEmpty, isTrue);
        expect(updated.mediaUrls.first, 'https://example.com/image.jpg');
      },
    );

    test('second mesh signal does not remove first', () async {
      final service = SignalService();

      final first = await service.createSignalFromMesh(
        content: 'First',
        senderNodeId: 10,
        signalId: 'sig-1',
        ttlMinutes: 15,
      );
      expect(first, isNotNull);

      final second = await service.createSignalFromMesh(
        content: 'Second',
        senderNodeId: 11,
        signalId: 'sig-2',
        ttlMinutes: 15,
      );
      expect(second, isNotNull);

      // Ensure both present in DB
      final all = await service.getActiveSignals();
      final ids = all.map((s) => s.id).toSet();
      expect(ids.contains('sig-1'), isTrue);
      expect(ids.contains('sig-2'), isTrue);
    });


  });
}
