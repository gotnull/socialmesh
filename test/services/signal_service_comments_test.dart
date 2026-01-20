import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:socialmesh/services/signal_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SignalService comment hydration', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    late Directory tmpDir;
    final channel = const MethodChannel('plugins.flutter.io/path_provider');

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('signal_comments_test');
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

    test('merges local and cloud comments with myVote applied', () async {
      final service = SignalService();
      final now = DateTime.now();
      const signalId = 'sig-merge-1';

      final local = SignalResponse(
        id: 'local-1',
        signalId: signalId,
        content: 'Local comment',
        authorId: 'user-local',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
      );

      await service.insertLocalCommentForTesting(local);

      final cloud = SignalResponse(
        id: 'cloud-1',
        signalId: signalId,
        content: 'Cloud comment',
        authorId: 'user-cloud',
        createdAt: now.add(const Duration(minutes: 1)),
        expiresAt: now.add(const Duration(hours: 1)),
        isLocal: false,
      );

      service.setCloudCommentsForTesting(signalId, [cloud]);
      service.setMyVotesForTesting(signalId, {'cloud-1': 1});

      final comments = await service.getComments(signalId);
      expect(comments.length, 2);
      final cloudResult = comments.firstWhere((c) => c.id == 'cloud-1');
      expect(cloudResult.myVote, 1);
    });
  });
}
