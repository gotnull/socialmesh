// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/providers/app_providers.dart'
    show ActiveProtocol, activeProtocolProvider;
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';
import 'package:socialmesh/services/watch_companion/_internal/watch_channels_facade.dart';
import 'package:socialmesh/services/watch_companion/_internal/watch_readiness_facade.dart';
import 'package:socialmesh/services/watch_companion/_internal/watch_send_facade.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_canned_messages.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_channel_preview.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_connection_state.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_intent.dart';
import 'package:socialmesh/services/watch_companion/watch_companion_feature_flags.dart';
import 'package:socialmesh/services/watch_companion/watch_companion_providers.dart';

class _MtSendRecorder {
  final List<({String text, int channelIndex})> calls = [];
  Future<int> Function({required String text, required int channelIndex})
  reply = ({required text, required channelIndex}) async => 42;

  Future<int> call({required String text, required int channelIndex}) async {
    calls.add((text: text, channelIndex: channelIndex));
    return reply(text: text, channelIndex: channelIndex);
  }
}

class _McSendRecorder {
  final List<({String text, int channelIndex})> calls = [];
  Future<MeshCoreTextSendResult> Function({
    required String text,
    required int channelIndex,
  })
  reply = ({required text, required channelIndex}) async =>
      MeshCoreTextSendResult.ok(
        response: MeshCoreFrame(command: 0, payload: Uint8List(0)),
      );

  Future<MeshCoreTextSendResult> call({
    required String text,
    required int channelIndex,
  }) async {
    calls.add((text: text, channelIndex: channelIndex));
    return reply(text: text, channelIndex: channelIndex);
  }
}

WatchCompanionIntent _intent({
  WatchCompanionIntentType type = WatchCompanionIntentType.quickMessage,
  String? cannedKey = WatchCompanionCannedMessageKeys.onMyWay,
  int? channelIndex = 0,
  String requestId = 'req-1',
}) {
  return WatchCompanionIntent(
    requestId: requestId,
    type: type,
    target: WatchCompanionIntentTarget(channelIndex: channelIndex),
    payload: WatchCompanionIntentPayload(cannedKey: cannedKey),
    createdAtMs: 1747700000000,
  );
}

ProviderContainer _container({
  bool enabled = true,
  WatchCompanionConnectionStatus readiness =
      WatchCompanionConnectionStatus.ready,
  ActiveProtocol protocol = ActiveProtocol.meshtastic,
  List<WatchCompanionChannelPreview>? channels,
  int defaultChannel = 0,
  _MtSendRecorder? mt,
  _McSendRecorder? mc,
}) {
  return ProviderContainer(
    overrides: [
      watchCompanionFeatureFlagsProvider.overrideWith(
        (ref) => WatchCompanionFeatureFlags(enabled: enabled),
      ),
      watchReadinessFacadeProvider.overrideWith(
        (ref) => WatchCompanionConnectionState(status: readiness),
      ),
      activeProtocolProvider.overrideWith((ref) => protocol),
      watchChannelsFacadeProvider.overrideWith(
        (ref) =>
            channels ??
            const <WatchCompanionChannelPreview>[
              WatchCompanionChannelPreview(
                index: 0,
                name: 'Primary',
                isDefault: true,
              ),
            ],
      ),
      watchDefaultChannelIndexProvider.overrideWith((ref) => defaultChannel),
      if (mt != null)
        meshtasticChannelSendProvider.overrideWith((ref) => mt.call),
      if (mc != null)
        meshCoreChannelSendProvider.overrideWith((ref) => mc.call),
    ],
  );
}

void main() {
  group('WatchSendFacade.dispatch', () {
    test(
      'feature_disabled short-circuits every intent and never calls send',
      () async {
        final mt = _MtSendRecorder();
        final mc = _McSendRecorder();
        final container = _container(enabled: false, mt: mt, mc: mc);
        addTearDown(container.dispose);

        final result = await container
            .read(watchSendFacadeProvider)
            .dispatch(_intent());

        expect(result.accepted, isFalse);
        expect(result.diagnosticReason, 'feature_disabled');
        expect(mt.calls, isEmpty);
        expect(mc.calls, isEmpty);
      },
    );

    test(
      'readiness_not_ready rejects send and does NOT invoke send fns',
      () async {
        final mt = _MtSendRecorder();
        final mc = _McSendRecorder();
        final container = _container(
          readiness: WatchCompanionConnectionStatus.connecting,
          mt: mt,
          mc: mc,
        );
        addTearDown(container.dispose);

        final result = await container
            .read(watchSendFacadeProvider)
            .dispatch(_intent());

        expect(result.accepted, isFalse);
        expect(result.diagnosticReason, 'readiness_not_ready');
        expect(mt.calls, isEmpty);
        expect(mc.calls, isEmpty);
      },
    );

    test(
      'every non-ready connection status produces readiness_not_ready',
      () async {
        for (final status in WatchCompanionConnectionStatus.values) {
          if (status == WatchCompanionConnectionStatus.ready) continue;
          final mt = _MtSendRecorder();
          final container = _container(readiness: status, mt: mt);
          addTearDown(container.dispose);

          final result = await container
              .read(watchSendFacadeProvider)
              .dispatch(_intent(requestId: 'r-${status.name}'));

          expect(
            result.diagnosticReason,
            'readiness_not_ready',
            reason: 'status=$status should reject as readiness_not_ready',
          );
          expect(mt.calls, isEmpty);
        }
      },
    );

    test('unknown cannedKey rejects with canned_key_unknown', () async {
      final mt = _MtSendRecorder();
      final container = _container(mt: mt);
      addTearDown(container.dispose);

      final result = await container
          .read(watchSendFacadeProvider)
          .dispatch(_intent(cannedKey: 'free_form_attempt'));

      expect(result.accepted, isFalse);
      expect(result.diagnosticReason, 'canned_key_unknown');
      expect(mt.calls, isEmpty);
    });

    test(
      'null cannedKey on a quickMessage rejects (no freeform path)',
      () async {
        // The Watch must NEVER be able to send arbitrary text. The intent
        // model has no freeform field; even a null cannedKey is rejected
        // so a malformed Watch payload cannot fall through to a send.
        final mt = _MtSendRecorder();
        final container = _container(mt: mt);
        addTearDown(container.dispose);

        final result = await container
            .read(watchSendFacadeProvider)
            .dispatch(_intent(cannedKey: null));

        expect(result.accepted, isFalse);
        expect(result.diagnosticReason, 'canned_key_unknown');
        expect(mt.calls, isEmpty);
      },
    );

    test(
      'channel_unavailable when the requested channel is not in the list',
      () async {
        final mt = _MtSendRecorder();
        final container = _container(
          channels: const <WatchCompanionChannelPreview>[
            WatchCompanionChannelPreview(
              index: 0,
              name: 'Primary',
              isDefault: true,
            ),
          ],
          mt: mt,
        );
        addTearDown(container.dispose);

        final result = await container
            .read(watchSendFacadeProvider)
            .dispatch(_intent(channelIndex: 7));

        expect(result.accepted, isFalse);
        expect(result.diagnosticReason, 'channel_unavailable');
        expect(mt.calls, isEmpty);
      },
    );

    test('channel_unavailable when no channels exist at all', () async {
      final mt = _MtSendRecorder();
      final container = _container(
        channels: const <WatchCompanionChannelPreview>[],
        mt: mt,
      );
      addTearDown(container.dispose);

      final result = await container
          .read(watchSendFacadeProvider)
          .dispatch(_intent());

      expect(result.diagnosticReason, 'channel_unavailable');
      expect(mt.calls, isEmpty);
    });

    test(
      'falls back to watchDefaultChannelIndex when intent target is null',
      () async {
        final mt = _MtSendRecorder();
        final container = _container(
          channels: const <WatchCompanionChannelPreview>[
            WatchCompanionChannelPreview(
              index: 3,
              name: 'admin',
              isDefault: true,
            ),
          ],
          defaultChannel: 3,
          mt: mt,
        );
        addTearDown(container.dispose);

        final result = await container
            .read(watchSendFacadeProvider)
            .dispatch(_intent(channelIndex: null));

        expect(result.accepted, isTrue);
        expect(mt.calls, hasLength(1));
        expect(mt.calls.single.channelIndex, 3);
      },
    );

    test('protocol_not_active rejects when active protocol is none', () async {
      final mt = _MtSendRecorder();
      final mc = _McSendRecorder();
      final container = _container(
        protocol: ActiveProtocol.none,
        mt: mt,
        mc: mc,
      );
      addTearDown(container.dispose);

      final result = await container
          .read(watchSendFacadeProvider)
          .dispatch(_intent());

      expect(result.accepted, isFalse);
      expect(result.diagnosticReason, 'protocol_not_active');
      expect(mt.calls, isEmpty);
      expect(mc.calls, isEmpty);
    });

    test('Meshtastic happy path: calls the send fn with text + channel '
        'and returns accepted', () async {
      final mt = _MtSendRecorder();
      final container = _container(mt: mt);
      addTearDown(container.dispose);

      final result = await container
          .read(watchSendFacadeProvider)
          .dispatch(
            _intent(cannedKey: WatchCompanionCannedMessageKeys.onMyWay),
          );

      expect(result.accepted, isTrue);
      expect(mt.calls, hasLength(1));
      expect(mt.calls.single.text, 'On my way');
      expect(mt.calls.single.channelIndex, 0);
    });

    test('Meshtastic send throw is captured as send_failed:<type>', () async {
      final mt = _MtSendRecorder()
        ..reply = ({required text, required channelIndex}) {
          throw StateError('readiness collapsed mid-flight');
        };
      final container = _container(mt: mt);
      addTearDown(container.dispose);

      final result = await container
          .read(watchSendFacadeProvider)
          .dispatch(_intent());

      expect(result.accepted, isFalse);
      expect(result.diagnosticReason, startsWith('send_failed:'));
    });

    test('MeshCore happy path: returns accepted on ok result', () async {
      final mc = _McSendRecorder();
      final container = _container(
        protocol: ActiveProtocol.meshcore,
        channels: const <WatchCompanionChannelPreview>[
          WatchCompanionChannelPreview(
            index: 0,
            name: 'Public',
            isDefault: true,
          ),
        ],
        mc: mc,
      );
      addTearDown(container.dispose);

      final result = await container
          .read(watchSendFacadeProvider)
          .dispatch(_intent());

      expect(result.accepted, isTrue);
      expect(mc.calls, hasLength(1));
      expect(mc.calls.single.text, 'On my way');
    });

    test(
      'MeshCore rate_limited maps to rate_limited diagnosticReason',
      () async {
        final mc = _McSendRecorder()
          ..reply = ({required text, required channelIndex}) async =>
              MeshCoreTextSendResult.rateLimited(
                nextSendIn: const Duration(seconds: 12),
                remainingBytes: 128,
              );
        final container = _container(
          protocol: ActiveProtocol.meshcore,
          channels: const <WatchCompanionChannelPreview>[
            WatchCompanionChannelPreview(
              index: 0,
              name: 'Public',
              isDefault: true,
            ),
          ],
          mc: mc,
        );
        addTearDown(container.dispose);

        final result = await container
            .read(watchSendFacadeProvider)
            .dispatch(_intent());

        expect(result.accepted, isFalse);
        expect(result.diagnosticReason, 'rate_limited');
      },
    );

    test('MeshCore firmware_timeout maps to firmware_timeout reason', () async {
      final mc = _McSendRecorder()
        ..reply = ({required text, required channelIndex}) async =>
            MeshCoreTextSendResult.firmwareTimeout();
      final container = _container(
        protocol: ActiveProtocol.meshcore,
        channels: const <WatchCompanionChannelPreview>[
          WatchCompanionChannelPreview(
            index: 0,
            name: 'Public',
            isDefault: true,
          ),
        ],
        mc: mc,
      );
      addTearDown(container.dispose);

      final result = await container
          .read(watchSendFacadeProvider)
          .dispatch(_intent());

      expect(result.accepted, isFalse);
      expect(result.diagnosticReason, 'firmware_timeout');
    });

    test('sendImOk normalizes to im_ok key + dispatches "I\'m OK"', () async {
      final mt = _MtSendRecorder();
      final container = _container(mt: mt);
      addTearDown(container.dispose);

      final result = await container
          .read(watchSendFacadeProvider)
          .dispatch(
            _intent(type: WatchCompanionIntentType.sendImOk, cannedKey: null),
          );

      expect(result.accepted, isTrue);
      expect(mt.calls, hasLength(1));
      expect(mt.calls.single.text, "I'm OK");
    });

    test('refreshSnapshot is acked without invoking any send fn', () async {
      final mt = _MtSendRecorder();
      final mc = _McSendRecorder();
      final container = _container(mt: mt, mc: mc);
      addTearDown(container.dispose);

      final result = await container
          .read(watchSendFacadeProvider)
          .dispatch(
            _intent(
              type: WatchCompanionIntentType.refreshSnapshot,
              cannedKey: null,
              channelIndex: null,
            ),
          );

      expect(result.accepted, isTrue);
      expect(mt.calls, isEmpty);
      expect(mc.calls, isEmpty);
    });

    test('intent type does not include any location-intent case', () {
      // Compile-time + runtime proof that v1 has no location-intent
      // enum case. If a future change introduces one without updating
      // the send facade, this test must be updated deliberately rather
      // than slipping in silently.
      expect(
        WatchCompanionIntentType.values,
        unorderedEquals(<WatchCompanionIntentType>[
          WatchCompanionIntentType.quickMessage,
          WatchCompanionIntentType.sendImOk,
          WatchCompanionIntentType.refreshSnapshot,
        ]),
      );
    });

    test('requestId echoes back unchanged in every result branch', () async {
      const id = 'req-echo-check';
      final mt = _MtSendRecorder();
      final mc = _McSendRecorder();

      // Each invocation creates its own container to avoid cross-contamination.
      Future<void> check(
        WatchCompanionIntent intent, {
        required bool enabled,
        required WatchCompanionConnectionStatus readiness,
        ActiveProtocol protocol = ActiveProtocol.meshtastic,
        List<WatchCompanionChannelPreview>? channels,
      }) async {
        final container = _container(
          enabled: enabled,
          readiness: readiness,
          protocol: protocol,
          channels: channels,
          mt: mt,
          mc: mc,
        );
        addTearDown(container.dispose);
        final result = await container
            .read(watchSendFacadeProvider)
            .dispatch(intent);
        expect(result.requestId, id);
      }

      await check(
        _intent(requestId: id),
        enabled: false,
        readiness: WatchCompanionConnectionStatus.ready,
      );
      await check(
        _intent(requestId: id),
        enabled: true,
        readiness: WatchCompanionConnectionStatus.disconnected,
      );
      await check(
        _intent(requestId: id, cannedKey: 'made_up'),
        enabled: true,
        readiness: WatchCompanionConnectionStatus.ready,
      );
      await check(
        _intent(requestId: id),
        enabled: true,
        readiness: WatchCompanionConnectionStatus.ready,
      );
    });
  });
}
