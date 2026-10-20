// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Radio tuning values a v1.18+ MeshCore companion radio exposes only through
// its CLI (CMD_RUN_CLI_COMMAND): channel activity detection, the RSSI
// interference threshold, the AGC reset interval and the flood and direct
// rebroadcast delay factors. Command names and ranges follow
// src/helpers/CommonRadioPrefs.cpp at the pinned firmware commit. Every value
// applies live; the firmware persists it on the "set".

/// Runs one CLI line and returns the radio's reply, or null on timeout.
typedef MeshCoreCliRunner = Future<String?> Function(String command);

class MeshCoreRadioTuning {
  const MeshCoreRadioTuning({
    required this.cadEnabled,
    required this.interferenceThreshold,
    required this.agcResetIntervalSecs,
    required this.floodTxDelay,
    required this.directTxDelay,
  });

  final bool cadEnabled;

  /// dB above the noise floor that counts as a busy channel; 0 is off.
  final int interferenceThreshold;

  /// Seconds between AGC resets, stored by the firmware in steps of 4.
  final int agcResetIntervalSecs;

  /// Rebroadcast delay as a multiple of packet airtime, 0 to 2.
  final double floodTxDelay;
  final double directTxDelay;

  static const int maxInterferenceThreshold = 255;
  static const int maxAgcResetIntervalSecs = 1020;
  static const int agcStepSecs = 4;
  static const double maxTxDelay = 2;

  /// Reads every value. Returns null when any reply is missing or cannot
  /// be parsed, so the caller never shows a half-loaded form.
  static Future<MeshCoreRadioTuning?> read(MeshCoreCliRunner run) async {
    final cad = _value(await run('get cad'));
    final thresh = int.tryParse(_value(await run('get int.thresh')) ?? '');
    final agc = int.tryParse(_value(await run('get agc.reset.interval')) ?? '');
    final flood = double.tryParse(_value(await run('get txdelay')) ?? '');
    final direct = double.tryParse(
      _value(await run('get direct.txdelay')) ?? '',
    );
    if (cad == null ||
        thresh == null ||
        agc == null ||
        flood == null ||
        direct == null) {
      return null;
    }
    return MeshCoreRadioTuning(
      cadEnabled: cad == 'on',
      interferenceThreshold: thresh,
      agcResetIntervalSecs: agc,
      floodTxDelay: flood,
      directTxDelay: direct,
    );
  }

  /// "set" commands for every value that differs from [current]. Delay
  /// factors compare at two decimals: the firmware echoes 0.2 as
  /// 0.1999999, which is not a change.
  List<String> commandsToApply(MeshCoreRadioTuning current) => [
    if (cadEnabled != current.cadEnabled)
      'set cad ${cadEnabled ? 'on' : 'off'}',
    if (interferenceThreshold != current.interferenceThreshold)
      'set int.thresh $interferenceThreshold',
    if (agcResetIntervalSecs != current.agcResetIntervalSecs)
      'set agc.reset.interval $agcResetIntervalSecs',
    if (formatDelay(floodTxDelay) != formatDelay(current.floodTxDelay))
      'set txdelay ${formatDelay(floodTxDelay)}',
    if (formatDelay(directTxDelay) != formatDelay(current.directTxDelay))
      'set direct.txdelay ${formatDelay(directTxDelay)}',
  ];

  /// Two decimals at most, without trailing zeros: 0.2, 0.5, 1, 1.25.
  static String formatDelay(double value) {
    final fixed = value.toStringAsFixed(2);
    return fixed.contains('.')
        ? fixed
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '')
        : fixed;
  }

  /// Whether a "set" reply reports success ("OK", "OK - interval rounded
  /// to 8"). Failures start with "Error" or "ERROR".
  static bool isOk(String? reply) => reply != null && reply.startsWith('OK');

  // "get" replies are "> value".
  static String? _value(String? reply) {
    if (reply == null || !reply.startsWith('> ')) return null;
    return reply.substring(2).trim();
  }
}
