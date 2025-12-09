import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/models/tapback.dart';
import 'package:socialmesh/services/storage/tapback_storage_service.dart';

void main() {
  late SharedPreferences prefs;
  late TapbackStorageService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    service = TapbackStorageService(prefs);
  });

  group('TapbackStorageService', () {
    test('getTapbacksForMessage returns empty list when none exist', () async {
      final tapbacks = await service.getTapbacksForMessage('message1');
      expect(tapbacks, isEmpty);
    });

    test('addTapback saves tapback', () async {
      final tapback = MessageTapback(
        messageId: 'message1',
        fromNodeNum: 12345,
        type: TapbackType.like,
      );

      await service.addTapback(tapback);
      final tapbacks = await service.getTapbacksForMessage('message1');

      expect(tapbacks.length, 1);
      expect(tapbacks.first.messageId, 'message1');
      expect(tapbacks.first.fromNodeNum, 12345);
      expect(tapbacks.first.type, TapbackType.like);
    });

    test('addTapback replaces existing tapback from same user', () async {
      final tapback1 = MessageTapback(
        messageId: 'message1',
        fromNodeNum: 12345,
        type: TapbackType.like,
      );

      final tapback2 = MessageTapback(
        messageId: 'message1',
        fromNodeNum: 12345,
        type: TapbackType.heart,
      );

      await service.addTapback(tapback1);
      await service.addTapback(tapback2);

      final tapbacks = await service.getTapbacksForMessage('message1');

      expect(tapbacks.length, 1);
      expect(tapbacks.first.type, TapbackType.heart);
    });

    test('addTapback allows different users to tapback same message', () async {
      final tapback1 = MessageTapback(
        messageId: 'message1',
        fromNodeNum: 12345,
        type: TapbackType.like,
      );

      final tapback2 = MessageTapback(
        messageId: 'message1',
        fromNodeNum: 67890,
        type: TapbackType.heart,
      );

      await service.addTapback(tapback1);
      await service.addTapback(tapback2);

      final tapbacks = await service.getTapbacksForMessage('message1');
      expect(tapbacks.length, 2);
    });

    test('removeTapback removes specific tapback', () async {
      final tapback = MessageTapback(
        messageId: 'message1',
        fromNodeNum: 12345,
        type: TapbackType.like,
      );

      await service.addTapback(tapback);
      await service.removeTapback('message1', 12345);

      final tapbacks = await service.getTapbacksForMessage('message1');
      expect(tapbacks, isEmpty);
    });

    test('removeTapback does not affect other tapbacks', () async {
      final tapback1 = MessageTapback(
        messageId: 'message1',
        fromNodeNum: 12345,
        type: TapbackType.like,
      );

      final tapback2 = MessageTapback(
        messageId: 'message1',
        fromNodeNum: 67890,
        type: TapbackType.heart,
      );

      await service.addTapback(tapback1);
      await service.addTapback(tapback2);
      await service.removeTapback('message1', 12345);

      final tapbacks = await service.getTapbacksForMessage('message1');
      expect(tapbacks.length, 1);
      expect(tapbacks.first.fromNodeNum, 67890);
    });

    test('getGroupedTapbacks groups by type', () async {
      await service.addTapback(
        MessageTapback(
          messageId: 'message1',
          fromNodeNum: 111,
          type: TapbackType.like,
        ),
      );
      await service.addTapback(
        MessageTapback(
          messageId: 'message1',
          fromNodeNum: 222,
          type: TapbackType.like,
        ),
      );
      await service.addTapback(
        MessageTapback(
          messageId: 'message1',
          fromNodeNum: 333,
          type: TapbackType.heart,
        ),
      );

      final grouped = await service.getGroupedTapbacks('message1');

      expect(grouped[TapbackType.like], containsAll([111, 222]));
      expect(grouped[TapbackType.heart], [333]);
      expect(grouped[TapbackType.laugh], isNull);
    });

    test('getGroupedTapbacks returns empty map for no tapbacks', () async {
      final grouped = await service.getGroupedTapbacks('nonexistent');
      expect(grouped, isEmpty);
    });

    test('cleanupOldTapbacks removes tapbacks older than 30 days', () async {
      // Note: This test is limited because we can't easily mock timestamps
      // in the current implementation. It primarily verifies the method
      // doesn't throw.
      await service.addTapback(
        MessageTapback(
          messageId: 'message1',
          fromNodeNum: 12345,
          type: TapbackType.like,
        ),
      );

      // Should not throw
      await service.cleanupOldTapbacks();

      // Recent tapback should still exist
      final tapbacks = await service.getTapbacksForMessage('message1');
      expect(tapbacks.length, 1);
    });

    test('tapbacks are isolated by message', () async {
      await service.addTapback(
        MessageTapback(
          messageId: 'message1',
          fromNodeNum: 12345,
          type: TapbackType.like,
        ),
      );
      await service.addTapback(
        MessageTapback(
          messageId: 'message2',
          fromNodeNum: 12345,
          type: TapbackType.heart,
        ),
      );

      final tapbacks1 = await service.getTapbacksForMessage('message1');
      final tapbacks2 = await service.getTapbacksForMessage('message2');

      expect(tapbacks1.length, 1);
      expect(tapbacks1.first.type, TapbackType.like);
      expect(tapbacks2.length, 1);
      expect(tapbacks2.first.type, TapbackType.heart);
    });
  });
}
