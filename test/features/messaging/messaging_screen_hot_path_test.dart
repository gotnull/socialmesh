// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/messaging/conversation_timeline.dart';
import 'package:socialmesh/features/messaging/messaging_screen.dart';
import 'package:socialmesh/models/mesh_models.dart';

Message _message({
  required String id,
  required String text,
  required DateTime timestamp,
  int packetId = 0,
}) {
  return Message(
    id: id,
    from: 20,
    to: 10,
    text: text,
    timestamp: timestamp,
    packetId: packetId,
    received: true,
  );
}

void main() {
  group('selectConversationDisplayRows', () {
    test(
      'does not build fallback rows when timeline rows already cover the conversation',
      () {
        final base = DateTime(2026, 4, 16, 12, 0);
        final fallbackMessages = [
          _message(
            id: 'message-001',
            text: 'First',
            timestamp: base,
            packetId: 1,
          ),
          _message(
            id: 'message-002',
            text: 'Second',
            timestamp: base.add(const Duration(minutes: 1)),
            packetId: 2,
          ),
        ];
        final timelineRows = buildConversationTimelineRows(fallbackMessages);
        var fallbackBuilds = 0;

        final selection = selectConversationDisplayRows(
          fallbackMessages: fallbackMessages,
          timelineState: ConversationTimelineState(
            rawMessages: fallbackMessages,
            rows: timelineRows,
            totalMessageCount: fallbackMessages.length,
            hasMoreOlder: false,
            isLoadingOlder: false,
          ),
          fallbackRowBuilder: (messages) {
            fallbackBuilds += 1;
            return buildConversationFallbackRows(messages);
          },
        );

        expect(selection.usedFallbackRows, isFalse);
        expect(selection.rows, same(timelineRows));
        expect(selection.visibleTimelineMessageCount, fallbackMessages.length);
        expect(fallbackBuilds, 0);
      },
    );

    test(
      'builds fallback rows when timeline data is missing visible messages',
      () {
        final base = DateTime(2026, 4, 16, 12, 0);
        final fallbackMessages = [
          _message(
            id: 'message-001',
            text: 'First',
            timestamp: base,
            packetId: 1,
          ),
          _message(
            id: 'message-002',
            text: 'Second',
            timestamp: base.add(const Duration(minutes: 1)),
            packetId: 2,
          ),
        ];
        final incompleteTimelineMessages = [fallbackMessages.first];
        var fallbackBuilds = 0;

        final selection = selectConversationDisplayRows(
          fallbackMessages: fallbackMessages,
          timelineState: ConversationTimelineState(
            rawMessages: incompleteTimelineMessages,
            rows: buildConversationTimelineRows(incompleteTimelineMessages),
            totalMessageCount: fallbackMessages.length,
            hasMoreOlder: false,
            isLoadingOlder: false,
          ),
          fallbackRowBuilder: (messages) {
            fallbackBuilds += 1;
            return buildConversationFallbackRows(messages);
          },
        );

        expect(selection.usedFallbackRows, isTrue);
        expect(selection.rows.map((row) => row.message?.id), [
          'message-001',
          'message-002',
        ]);
        expect(selection.visibleTimelineMessageCount, 1);
        expect(fallbackBuilds, 1);
      },
    );
  });
}
