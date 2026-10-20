// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/meshcore_radio_tuning.dart';

// Replies are the ones a RAK4631 on v1.18.0 gave on 20th October 2026.
const _radioReplies = {
  'get cad': '> off',
  'get int.thresh': '> 0',
  'get agc.reset.interval': '> 0',
  'get txdelay': '> 0.5',
  'get direct.txdelay': '> 0.1999999',
};

MeshCoreCliRunner _runner(Map<String, String?> replies, List<String> sent) =>
    (command) async {
      sent.add(command);
      return replies[command];
    };

const _defaults = MeshCoreRadioTuning(
  cadEnabled: false,
  interferenceThreshold: 0,
  agcResetIntervalSecs: 0,
  floodTxDelay: 0.5,
  directTxDelay: 0.1999999,
);

void main() {
  test('reads every value from the radio replies', () async {
    final sent = <String>[];
    final tuning = await MeshCoreRadioTuning.read(_runner(_radioReplies, sent));
    expect(sent, _radioReplies.keys.toList());
    expect(tuning!.cadEnabled, isFalse);
    expect(tuning.interferenceThreshold, 0);
    expect(tuning.agcResetIntervalSecs, 0);
    expect(tuning.floodTxDelay, 0.5);
    expect(MeshCoreRadioTuning.formatDelay(tuning.directTxDelay), '0.2');
  });

  test('a missing or malformed reply loads nothing', () async {
    final timedOut = Map<String, String?>.from(_radioReplies)
      ..['get txdelay'] = null;
    expect(await MeshCoreRadioTuning.read(_runner(timedOut, [])), isNull);

    final garbled = Map<String, String?>.from(_radioReplies)
      ..['get int.thresh'] = 'Unknown command';
    expect(await MeshCoreRadioTuning.read(_runner(garbled, [])), isNull);
  });

  test('only changed values produce set commands', () {
    expect(_defaults.commandsToApply(_defaults), isEmpty);

    const edited = MeshCoreRadioTuning(
      cadEnabled: true,
      interferenceThreshold: 14,
      agcResetIntervalSecs: 8,
      floodTxDelay: 0.5,
      directTxDelay: 0.2,
    );
    expect(edited.commandsToApply(_defaults), [
      'set cad on',
      'set int.thresh 14',
      'set agc.reset.interval 8',
    ]);
  });

  test('delay factors are sent with at most two decimals', () {
    expect(MeshCoreRadioTuning.formatDelay(1), '1');
    expect(MeshCoreRadioTuning.formatDelay(1.25), '1.25');
    expect(MeshCoreRadioTuning.formatDelay(0.1999999), '0.2');

    const edited = MeshCoreRadioTuning(
      cadEnabled: false,
      interferenceThreshold: 0,
      agcResetIntervalSecs: 0,
      floodTxDelay: 1.5,
      directTxDelay: 0.25,
    );
    expect(edited.commandsToApply(_defaults), [
      'set txdelay 1.5',
      'set direct.txdelay 0.25',
    ]);
  });

  test('set replies: OK variants succeed, errors fail', () {
    expect(MeshCoreRadioTuning.isOk('OK'), isTrue);
    expect(MeshCoreRadioTuning.isOk('OK - interval rounded to 8'), isTrue);
    expect(MeshCoreRadioTuning.isOk('Error, must be 0-2'), isFalse);
    expect(MeshCoreRadioTuning.isOk(null), isFalse);
  });
}
