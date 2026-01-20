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
          packetId: 101,
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
          packetId: 102,
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
        packetId: 201,
        ttlMinutes: 15,
      );
      expect(first, isNotNull);

      final second = await service.createSignalFromMesh(
        content: 'Second',
        senderNodeId: 11,
        signalId: 'sig-2',
        packetId: 202,
        ttlMinutes: 15,
      );
      expect(second, isNotNull);

      // Ensure both present in DB
      final all = await service.getActiveSignals();
      final ids = all.map((s) => s.id).toSet();
      expect(ids.contains('sig-1'), isTrue);
      expect(ids.contains('sig-2'), isTrue);
    });

    test(
      'two mesh packets with same content create two distinct signals',
      () async {
        final service = SignalService();

        final first = await service.createSignalFromMesh(
          content: 'Same content',
          senderNodeId: 10,
          signalId: 'sig-a',
          packetId: 501,
          ttlMinutes: 15,
        );
        expect(first, isNotNull);

        final second = await service.createSignalFromMesh(
          content: 'Same content',
          senderNodeId: 10,
          signalId: 'sig-b',
          packetId: 502,
          ttlMinutes: 15,
        );
        expect(second, isNotNull);

        final all = await service.getActiveSignals();
        final ids = all.map((s) => s.id).toSet();
        expect(ids.contains('sig-a'), isTrue);
        expect(ids.contains('sig-b'), isTrue);
      },
    );

    test('cloud comment injection hydrates getComments and emits updates', () async {
      final service = SignalService();

      await service.createSignalFromMesh(
        content: 'Signal for comments',
        senderNodeId: 10,
        signalId: 'sig-comments',
        packetId: 301,
        ttlMinutes: 15,
      );

      final now = DateTime.now();
      final comment = SignalResponse(
        id: 'comment-1',
        signalId: 'sig-comments',
        content: 'Hello from cloud',
        authorId: 'user-2',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
        isLocal: false,
      );

      final updateFuture =
          expectLater(service.onCommentUpdate, emits('sig-comments'));
      service.injectCloudCommentsForTest('sig-comments', [comment]);
      await updateFuture;

      final comments = await service.getComments('sig-comments');
      expect(comments.any((c) => c.id == 'comment-1'), isTrue);
    });

    test('mesh signals without signalId are ignored', () async {
      final service = SignalService();

      final before = await service.getActiveSignals();

      final result = await service.createSignalFromMesh(
        content: 'Missing id',
        senderNodeId: 42,
        signalId: null,
        packetId: 401,
        ttlMinutes: 15,
      );

      expect(result, isNull);
      final after = await service.getActiveSignals();
      expect(after.length, equals(before.length));
    });

    test('mesh-only broadcast uses short timeout', () async {
      final service = SignalService();

      // Simulate a slow onBroadcastSignal (5s) to ensure createSignal returns quickly
      service.onBroadcastSignal =
          (
            String id,
            String content,
            int ttlMinutes,
            double? lat,
            double? lon,
          ) async {
            await Future.delayed(const Duration(seconds: 5));
            return 1;
          };

      final sw = Stopwatch()..start();
      final signal = await service.createSignal(
        content: 'fast-send-test',
        useCloud: false,
      );
      sw.stop();

      expect(signal, isNotNull);
      // Ensure it returned quickly (timeout set to ~1500ms in implementation)
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });
  });
}
