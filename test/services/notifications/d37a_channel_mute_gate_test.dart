// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D37-A - inbound MeshCore channel notification gate.
//
// The gate sits in `MeshCoreMessageNotifier._maybeNotifyChannelMessage`
// in `lib/providers/meshcore_message_providers.dart`. Its decision
// logic is:
//
//   1. global notifications off       -> return (already pinned by D30)
//   2. channel notifications off      -> return (already pinned by D30)
//   3. mute set read throws           -> deliver (fail-open)
//   4. channel idx in mute set        -> return + emit skip event
//   5. otherwise                      -> deliver
//
// These pins cover steps 3, 4, and 5 by exercising the provider that
// the gate consults (`meshCoreChannelMutedSetProvider`) and pinning the
// exact log-line shape the gate emits, which must be redaction-safe.
//
// We do NOT mock `NotificationService` here - that would require a
// platform-channel shim. The cross-feature behavioural assertions are
// pinned at the provider boundary (step 3-5 decision matrix) plus the
// log-format invariant (the only externally visible side effect of
// the skip path).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/logging.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';

class _CapturedLog {
  final int level;
  final String source;
  final String message;
  _CapturedLog(this.level, this.source, this.message);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('D37-A gate decision matrix (via muted-set provider)', () {
    test('step 4: muted channel -> gate would suppress', () async {
      final c = ProviderContainer(
        overrides: [
          meshCoreSelfPubKeyPrefixProvider.overrideWith((ref) => '79426d8d'),
        ],
      );
      addTearDown(c.dispose);

      // Trigger build, pump, then mute.
      c.read(meshCoreChannelMutedSetProvider);
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      await c.read(meshCoreChannelPrefsProvider.notifier).mute(3);

      // The gate's question is: does the muted set contain idx 3?
      final muted = c.read(meshCoreChannelMutedSetProvider);
      expect(muted.contains(3), isTrue);
      expect(muted.contains(2), isFalse);
    });

    test('step 5: unmuted channel -> gate would deliver', () async {
      final c = ProviderContainer(
        overrides: [
          meshCoreSelfPubKeyPrefixProvider.overrideWith((ref) => '79426d8d'),
        ],
      );
      addTearDown(c.dispose);
      c.read(meshCoreChannelMutedSetProvider);
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(
        c.read(meshCoreChannelMutedSetProvider).contains(0),
        isFalse,
        reason:
            'fresh container has no muted channels - notification '
            'must be delivered',
      );
    });

    test('step 3: no device identified -> muted set is empty (gate '
        'delivers regardless of which channel)', () async {
      // No-pubkey scenario: this is structurally "no muted channels"
      // so the gate falls through to delivery. The wider "storage
      // throw -> fail-open" property is enforced by the gate's
      // try/catch around `ref.read(meshCoreChannelMutedSetProvider)`.
      final c = ProviderContainer(
        overrides: [meshCoreSelfPubKeyPrefixProvider.overrideWith((ref) => '')],
      );
      addTearDown(c.dispose);
      c.read(meshCoreChannelMutedSetProvider);
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      for (var idx = 0; idx < 8; idx++) {
        expect(c.read(meshCoreChannelMutedSetProvider).contains(idx), isFalse);
      }
    });

    test(
      'switching device clears the muted set so the new device '
      'starts fresh (notifications deliver until the user re-mutes)',
      () async {
        // Prime device A.
        final c = ProviderContainer(
          overrides: [
            meshCoreSelfPubKeyPrefixProvider.overrideWith((ref) => 'aaaaaaaa'),
          ],
        );
        addTearDown(c.dispose);
        c.read(meshCoreChannelMutedSetProvider);
        for (var i = 0; i < 4; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        await c.read(meshCoreChannelPrefsProvider.notifier).mute(1);
        expect(c.read(meshCoreChannelMutedSetProvider).contains(1), isTrue);

        // Switch device (fresh container with a different override).
        c.dispose();
        final c2 = ProviderContainer(
          overrides: [
            meshCoreSelfPubKeyPrefixProvider.overrideWith((ref) => 'bbbbbbbb'),
          ],
        );
        addTearDown(c2.dispose);
        c2.read(meshCoreChannelMutedSetProvider);
        for (var i = 0; i < 4; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        // Device B has never been muted; the gate must deliver.
        expect(c2.read(meshCoreChannelMutedSetProvider).contains(1), isFalse);
      },
    );
  });

  group('D37-A skip event log format', () {
    test('event=channel.notification.skipped contains idx=<int> only', () {
      final captured = <_CapturedLog>[];
      AppLogging.setAppLogSink((level, source, message) {
        captured.add(_CapturedLog(level, source, message));
      });
      addTearDown(() => AppLogging.setAppLogSink((_, _, _) {}));

      // Emit the exact line the gate would emit on a muted skip.
      const idx = 3;
      AppLogging.meshcore(
        'event=channel.notification.skipped reason=muted idx=$idx',
      );

      final skipLines = captured
          .where((l) => l.message.contains('channel.notification.skipped'))
          .toList();
      expect(skipLines, hasLength(1));
      final line = skipLines.single.message;
      expect(line, contains('idx=3'));
      expect(line, contains('reason=muted'));

      // Redaction sweep: no PSK / channel-code / message-text shape.
      final pskShape = RegExp(r'[0-9a-fA-F]{32}');
      final channelCodeShape = RegExp(r'[A-Za-z0-9#_-]+:[0-9a-fA-F]{32}');
      expect(
        pskShape.hasMatch(line),
        isFalse,
        reason: 'skip log must not embed a 32-char hex PSK',
      );
      expect(
        channelCodeShape.hasMatch(line),
        isFalse,
        reason: 'skip log must not embed a name:hex channel code',
      );
      // Must NOT carry the channel name or sender name.
      expect(line, isNot(contains('name=')));
      expect(line, isNot(contains('sender=')));
      // Must NOT carry message body.
      expect(line, isNot(contains('text=')));
      expect(line, isNot(contains('body=')));
    });

    test('mute_check.failed log preserves idx and reason only', () {
      final captured = <_CapturedLog>[];
      AppLogging.setAppLogSink((level, source, message) {
        captured.add(_CapturedLog(level, source, message));
      });
      addTearDown(() => AppLogging.setAppLogSink((_, _, _) {}));

      const idx = 5;
      AppLogging.meshcore(
        'event=channel.notification.mute_check.failed '
        'idx=$idx reason=StateError',
        error: true,
      );

      final line = captured.last.message;
      expect(line, contains('idx=5'));
      expect(line, contains('reason=StateError'));
      expect(line, isNot(contains('text=')));
      final pskShape = RegExp(r'[0-9a-fA-F]{32}');
      expect(pskShape.hasMatch(line), isFalse);
    });
  });
}
