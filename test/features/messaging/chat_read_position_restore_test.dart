// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/features/messaging/conversation_timeline.dart';
import 'package:socialmesh/features/messaging/messaging_screen.dart';
import 'package:socialmesh/features/messaging/widgets/chat_composer.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/translation_providers.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/storage/conversation_read_position.dart';
import 'package:socialmesh/services/storage/message_database.dart';

class _FakeTransport extends DeviceTransport {
  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

  @override
  bool get requiresWakeSequence => false;

  @override
  TransportReconnectMode get reconnectMode => TransportReconnectMode.scanBased;

  @override
  DeviceConnectionState get state => DeviceConnectionState.disconnected;

  final StreamController<DeviceConnectionState> _stateCtrl =
      StreamController<DeviceConnectionState>.broadcast();

  @override
  Stream<DeviceConnectionState> get stateStream => _stateCtrl.stream;

  @override
  Stream<List<int>> get dataStream => const Stream.empty();

  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream.empty();

  @override
  Future<void> connect(DeviceInfo device) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> enableNotifications() async {}

  @override
  Future<void> pollOnce() async {}

  @override
  Future<void> send(List<int> data) async {}

  @override
  Future<int?> readRssi() async => null;

  @override
  Future<void> dispose() async {
    await _stateCtrl.close();
  }
}

class _TestProtocolService extends ProtocolService {
  _TestProtocolService() : super(_FakeTransport());

  @override
  Stream<Message> get messageStream => const Stream.empty();
}

class _StubMessageTranslationsNotifier extends MessageTranslationsNotifier {
  @override
  Map<String, MessageTranslationState> build() => {};

  @override
  Future<void> restoreFromCache({
    required String messageId,
    required String text,
  }) async {}
}

class _StaticNodesNotifier extends NodesNotifier {
  _StaticNodesNotifier(this._nodes);

  final Map<int, MeshNode> _nodes;

  @override
  Map<int, MeshNode> build() => _nodes;
}

class _FixedConversationTimelineController
    extends ConversationTimelineController {
  _FixedConversationTimelineController(this._timelines);

  final Map<ConversationTimelineQuery, AsyncValue<ConversationTimelineState>>
  _timelines;

  @override
  Map<ConversationTimelineQuery, AsyncValue<ConversationTimelineState>>
  build() => _timelines;

  @override
  Future<void> ensureInitialized(ConversationTimelineQuery query) async {}

  @override
  Future<int> loadOlder(ConversationTimelineQuery query) async => 0;

  @override
  Future<void> saveReadPosition(
    ConversationTimelineQuery query,
    ConversationReadPosition position,
  ) async {}

  @override
  Future<ConversationRestoreTarget> resolveInitialRestoreTarget(
    ConversationTimelineQuery query,
  ) async => const ConversationRestoreTarget.latest();
}

class _InMemoryMessageDatabase extends MessageDatabase {
  _InMemoryMessageDatabase() : super(testDbPath: ':memory:');

  final List<Message> _messages = [];
  final Map<String, ConversationReadPosition> _readPositions = {};

  @override
  Future<void> init() async {}

  @override
  Future<void> saveMessage(Message message) async {
    _upsertMessage(message);
    _trimConversation(MessageDatabase.conversationKey(message));
  }

  @override
  Future<void> saveMessages(List<Message> messages) async {
    final conversations = <String>{};
    for (final message in messages) {
      _upsertMessage(message);
      conversations.add(MessageDatabase.conversationKey(message));
    }
    for (final conversationKey in conversations) {
      _trimConversation(conversationKey);
    }
  }

  @override
  Future<List<Message>> loadMessages() async {
    final messages = [..._messages]..sort(_compareMessages);
    return messages;
  }

  @override
  Future<List<Message>> loadConversation(String convKey, {int? limit}) async {
    final messages = _conversationMessages(convKey);
    if (limit == null || limit >= messages.length) {
      return messages;
    }
    return messages.take(limit).toList(growable: false);
  }

  @override
  Future<int> countConversationMessages(String convKey) async {
    return _conversationMessages(convKey).length;
  }

  @override
  Future<List<Message>> loadConversationNewestWindow(
    String convKey, {
    required int limit,
  }) async {
    if (limit <= 0) return const [];
    final messages = _conversationMessages(convKey);
    if (messages.length <= limit) {
      return messages;
    }
    return messages.sublist(messages.length - limit);
  }

  @override
  Future<List<Message>> loadConversationOlderPage(
    String convKey, {
    required DateTime beforeTimestamp,
    required String beforeMessageId,
    required int limit,
  }) async {
    if (limit <= 0) return const [];
    final older = _conversationMessages(convKey)
        .where((message) {
          final timestampComparison = message.timestamp.compareTo(
            beforeTimestamp,
          );
          if (timestampComparison != 0) {
            return timestampComparison < 0;
          }
          return message.id.compareTo(beforeMessageId) < 0;
        })
        .toList(growable: false);
    if (older.length <= limit) {
      return older;
    }
    return older.sublist(older.length - limit);
  }

  @override
  Future<List<Message>> loadConversationFromBoundary(
    String convKey, {
    required DateTime fromTimestamp,
    required String fromMessageId,
  }) async {
    return _conversationMessages(convKey)
        .where((message) {
          final timestampComparison = message.timestamp.compareTo(
            fromTimestamp,
          );
          if (timestampComparison != 0) {
            return timestampComparison > 0;
          }
          return message.id.compareTo(fromMessageId) >= 0;
        })
        .toList(growable: false);
  }

  @override
  Future<List<Message>> loadMessagesForNode(
    int nodeNum, {
    int? sinceMillis,
  }) async {
    return _messages
        .where((message) {
          final matchesNode = message.from == nodeNum || message.to == nodeNum;
          if (!matchesNode) {
            return false;
          }
          if (sinceMillis == null) {
            return true;
          }
          return message.timestamp.millisecondsSinceEpoch >= sinceMillis;
        })
        .toList(growable: false)
      ..sort(_compareMessages);
  }

  @override
  Future<void> saveConversationReadPosition(
    ConversationReadPosition position,
  ) async {
    _readPositions[position.conversationKey] = position;
  }

  @override
  Future<ConversationReadPosition?> loadConversationReadPosition(
    String convKey,
  ) async {
    return _readPositions[convKey];
  }

  void _upsertMessage(Message message) {
    _messages.removeWhere((existing) => existing.id == message.id);
    _messages.add(message);
    _messages.sort(_compareMessages);
  }

  List<Message> _conversationMessages(String convKey) {
    return _messages
        .where((message) => MessageDatabase.conversationKey(message) == convKey)
        .toList(growable: false)
      ..sort(_compareMessages);
  }

  void _trimConversation(String convKey) {
    final messages = _conversationMessages(convKey);
    if (messages.length <= MessageDatabase.maxMessagesPerConversation) {
      return;
    }
    final excess = messages.length - MessageDatabase.maxMessagesPerConversation;
    final removeIds = messages
        .take(excess)
        .map((message) => message.id)
        .toSet();
    _messages.removeWhere((message) => removeIds.contains(message.id));
  }

  int _compareMessages(Message a, Message b) {
    final timestampComparison = a.timestamp.compareTo(b.timestamp);
    if (timestampComparison != 0) {
      return timestampComparison;
    }
    return a.id.compareTo(b.id);
  }
}

Future<void> _seedDmConversation(
  MessageDatabase storage, {
  required int startIndex,
  required int count,
  int myNodeNum = 10,
  int peerNodeNum = 20,
  String Function(int index)? textBuilder,
}) async {
  final base = DateTime(2026, 4, 12, 8, 0).add(Duration(minutes: startIndex));
  final messages = <Message>[];
  for (var offset = 0; offset < count; offset++) {
    final index = startIndex + offset;
    final label = 'message-${index.toString().padLeft(3, '0')}';
    messages.add(
      Message(
        id: label,
        from: peerNodeNum,
        to: myNodeNum,
        text: textBuilder?.call(index) ?? label,
        timestamp: base.add(Duration(minutes: offset)),
        packetId: 2000 + index,
        received: true,
        senderLongName: 'Peer Node',
        senderShortName: 'PEER',
        senderAvatarColor: 0xFF3366FF,
      ),
    );
  }
  await storage.saveMessages(messages);
}

Future<ProviderContainer> _createContainer(
  MessageDatabase storage, {
  List<dynamic> overrides = const [],
}) async {
  final container = ProviderContainer(
    overrides: [
      messageStorageProvider.overrideWithValue(AsyncValue.data(storage)),
      protocolServiceProvider.overrideWithValue(_TestProtocolService()),
      messageTranslationsProvider.overrideWith(
        _StubMessageTranslationsNotifier.new,
      ),
      nodesProvider.overrideWith(
        () => _StaticNodesNotifier({
          20: MeshNode(
            nodeNum: 20,
            longName: 'Peer Node',
            shortName: 'PEER',
            avatarColor: 0xFF3366FF,
          ),
        }),
      ),
      ...overrides,
    ],
  );

  container.read(myNodeNumProvider.notifier).state = 10;
  await container.read(messagesProvider.notifier).storageReady;
  return container;
}

Future<void> _pumpChat(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ChatScreen(
          type: ConversationType.directMessage,
          nodeNum: 20,
          title: 'Peer Node',
          avatarColor: 0xFF3366FF,
        ),
      ),
    ),
  );
}

Future<void> _pumpFor(
  WidgetTester tester,
  Duration duration, {
  int steps = 10,
}) async {
  final stepMicros = duration.inMicroseconds ~/ steps;
  for (var index = 0; index < steps; index++) {
    await tester.pump(Duration(microseconds: stepMicros));
  }
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 100),
  int maxPumps = 40,
}) async {
  for (var index = 0; index < maxPumps; index++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(step);
  }
}

ConversationReadPosition _savedReadPositionForIndex(
  int index, {
  double alignment = 0.88,
  bool wasNearLatest = false,
}) {
  return ConversationReadPosition(
    conversationKey: MessageDatabase.conversationKeyFromParams(
      nodeA: 10,
      nodeB: 20,
    ),
    anchorMessageId: 'message-${index.toString().padLeft(3, '0')}',
    anchorTimestamp: DateTime(2026, 4, 12, 8, 0).add(Duration(minutes: index)),
    anchorAlignment: alignment,
    wasNearLatest: wasNearLatest,
    updatedAt: DateTime(2026, 4, 12, 10, 0),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'chat saves a read anchor, restores into history after restart, and jumps to latest',
    (tester) async {
      final storage = _InMemoryMessageDatabase();
      await storage.init();
      await _seedDmConversation(storage, startIndex: 0, count: 60);

      final firstContainer = await _createContainer(storage);
      ProviderContainer? secondContainer;

      try {
        await _pumpChat(tester, firstContainer);
        await _pumpFor(tester, const Duration(milliseconds: 600));

        final listFinder = find.byType(ScrollablePositionedList);
        expect(listFinder, findsOneWidget);

        await tester.drag(listFinder, const Offset(0, 900));
        await _pumpFor(tester, const Duration(milliseconds: 600));
        await _pumpUntilFound(tester, find.text('Jump to latest'));
        expect(find.text('Jump to latest'), findsOneWidget);

        await _pumpFor(tester, const Duration(milliseconds: 700));

        await tester.pumpWidget(const SizedBox.shrink());
        await _pumpFor(tester, const Duration(milliseconds: 300));
        firstContainer.dispose();

        final savedPosition = await storage.loadConversationReadPosition(
          MessageDatabase.conversationKeyFromParams(nodeA: 10, nodeB: 20),
        );
        expect(savedPosition, isNotNull);
        expect(savedPosition!.wasNearLatest, isFalse);

        await _seedDmConversation(
          storage,
          startIndex: 60,
          count: 5,
          textBuilder: (index) {
            if (index != 64) {
              return 'message-${index.toString().padLeft(3, '0')}';
            }
            return 'message-064\nA deliberately tall final bubble\nthat must fully clear the composer';
          },
        );

        secondContainer = await _createContainer(storage);

        await _pumpChat(tester, secondContainer);
        await _pumpFor(tester, const Duration(milliseconds: 700));
        await _pumpUntilFound(tester, find.text(savedPosition.anchorMessageId));

        expect(find.text(savedPosition.anchorMessageId), findsOneWidget);
        expect(find.text('Jump to latest'), findsOneWidget);

        await tester.tap(find.text('Jump to latest'));
        await _pumpFor(tester, const Duration(milliseconds: 500));
        await _pumpUntilFound(
          tester,
          find.byKey(const ValueKey('message-064')),
        );

        expect(find.byKey(const ValueKey('message-064')), findsOneWidget);

        final latestBubbleRect = tester.getRect(
          find.byKey(const ValueKey('message-064')),
        );
        final composerRect = tester.getRect(find.byType(ChatComposer));
        expect(
          latestBubbleRect.bottom,
          lessThanOrEqualTo(composerRect.top + 0.5),
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        secondContainer?.dispose();
        firstContainer.dispose();
      }
    },
  );

  testWidgets('chat restores a tall anchor bubble fully above the composer', (
    tester,
  ) async {
    final storage = _InMemoryMessageDatabase();
    await storage.init();
    await _seedDmConversation(
      storage,
      startIndex: 0,
      count: 70,
      textBuilder: (index) {
        if (index != 42) {
          return 'message-${index.toString().padLeft(3, '0')}';
        }
        return 'message-042\nA deliberately tall restored bubble\nthat must fully clear the composer';
      },
    );
    await storage.saveConversationReadPosition(_savedReadPositionForIndex(42));

    final container = await _createContainer(storage);

    try {
      await _pumpChat(tester, container);
      await _pumpFor(tester, const Duration(milliseconds: 700));
      await _pumpUntilFound(tester, find.byKey(const ValueKey('message-042')));

      expect(find.byKey(const ValueKey('message-042')), findsOneWidget);
      expect(find.text('Jump to latest'), findsOneWidget);

      final anchorBubbleRect = tester.getRect(
        find.byKey(const ValueKey('message-042')),
      );
      final composerRect = tester.getRect(find.byType(ChatComposer));
      expect(
        anchorBubbleRect.bottom,
        lessThanOrEqualTo(composerRect.top + 0.5),
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
    }
  });

  testWidgets(
    'chat falls back to in-memory messages when timeline state is empty',
    (tester) async {
      final storage = _InMemoryMessageDatabase();
      await storage.init();
      await _seedDmConversation(storage, startIndex: 0, count: 3);

      const query = ConversationTimelineQuery.direct(
        peerNodeNum: 20,
        myNodeNum: 10,
      );
      final container = await _createContainer(
        storage,
        overrides: [
          conversationTimelineControllerProvider.overrideWith(
            () => _FixedConversationTimelineController({
              query: const AsyncValue.data(
                ConversationTimelineState(
                  rawMessages: [],
                  rows: [],
                  totalMessageCount: 0,
                  hasMoreOlder: false,
                  isLoadingOlder: false,
                ),
              ),
            }),
          ),
        ],
      );

      try {
        await _pumpChat(tester, container);
        await _pumpFor(tester, const Duration(milliseconds: 400));

        expect(find.text('message-000'), findsOneWidget);
        expect(find.text('message-001'), findsOneWidget);
        expect(find.text('message-002'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        container.dispose();
      }
    },
  );

  testWidgets(
    'sending a new message while scrolled up jumps back to the latest row',
    (tester) async {
      final storage = _InMemoryMessageDatabase();
      await storage.init();
      await _seedDmConversation(storage, startIndex: 0, count: 60);

      final container = await _createContainer(storage);

      try {
        await _pumpChat(tester, container);
        await _pumpFor(tester, const Duration(milliseconds: 600));

        final listFinder = find.byType(ScrollablePositionedList);
        expect(listFinder, findsOneWidget);

        await tester.drag(listFinder, const Offset(0, 900));
        await _pumpFor(tester, const Duration(milliseconds: 600));
        await _pumpUntilFound(tester, find.text('Jump to latest'));

        final visibleJump = tester.widget<AnimatedOpacity>(
          find.ancestor(
            of: find.text('Jump to latest'),
            matching: find.byType(AnimatedOpacity),
          ),
        );
        expect(visibleJump.opacity, 1);

        const sentText = 'fresh outbound message';
        final composerField = find.descendant(
          of: find.byType(ChatComposer),
          matching: find.byType(TextField),
        );
        await tester.enterText(composerField, sentText);
        await tester.pump();
        await tester.tap(find.byIcon(Icons.send));
        await _pumpFor(tester, const Duration(milliseconds: 700));
        await _pumpUntilFound(tester, find.text(sentText));

        final hiddenJump = tester.widget<AnimatedOpacity>(
          find.ancestor(
            of: find.text('Jump to latest'),
            matching: find.byType(AnimatedOpacity),
          ),
        );
        expect(hiddenJump.opacity, 0);

        final sentTextRect = tester.getRect(find.text(sentText));
        final composerRect = tester.getRect(find.byType(ChatComposer));
        expect(sentTextRect.bottom, lessThanOrEqualTo(composerRect.top + 0.5));
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        container.dispose();
      }
    },
  );
}
