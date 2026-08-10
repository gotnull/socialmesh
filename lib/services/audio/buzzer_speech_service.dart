// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_tts/flutter_tts.dart';

import 'buzzer_speech_codec.dart';

/// Speaks text through a connected node's buzzer.
///
/// Renders on the phone and sends conditioned audio to the node, because
/// synthesis on the node was measured and rejected: it was not intelligible
/// through that transducer at any drive level or voice setting, while recorded
/// speech through the identical path is clear.
///
/// Only firmware built to speak exposes the characteristic this needs. Check
/// [BleTransport.supportsSpeech] before calling, and expect [speak] to return
/// false rather than throw when the node cannot.
class BuzzerSpeechService {
  BuzzerSpeechService({
    FlutterTts? tts,
    this.rate = BuzzerSpeechCodec.defaultRate,
  }) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  /// 8 kHz keeps an utterance inside the node's buffer and halves the BLE
  /// transfer. The passband tops out at 2.9 kHz, so nothing is lost.
  final int rate;

  bool _configured = false;

  /// Longest utterance the node's buffer holds, at [rate].
  Duration get maxUtterance => Duration(
    milliseconds: (BuzzerSpeechCodec.maxUtteranceBytes * 1000) ~/ rate,
  );

  Future<void> _configure() async {
    if (_configured) return;
    await _tts.setSpeechRate(0.45); // slower reads far better through a buzzer
    await _tts.setVolume(1);
    await _tts.setPitch(1);
    _configured = true;
  }

  /// Renders [text], conditions it for the transducer and hands the framed
  /// bytes to [send]. Returns false when there was nothing to say or the
  /// platform produced no audio.
  ///
  /// [send] is injected rather than taking a transport, so this stays testable
  /// and free of any dependency on the BLE layer. Pass `transport.sendSpeech`.
  Future<bool> speak(
    String text,
    Future<void> Function(List<int> framed) send,
  ) async {
    final framed = await render(text);
    if (framed == null) return false;
    await send(framed);
    return true;
  }

  /// Renders and frames without sending, so callers can size or cache the
  /// result. Returns null when there is nothing speakable.
  Future<Uint8List?> render(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return null;

    final timing = BuzzerSpeechCodec.timingFor(rate);
    if (timing == null) return null;

    await _configure();

    final dir = await Directory.systemTemp.createTemp('buzzer_speech');
    final path = '${dir.path}/utterance.wav';
    try {
      // The full path with isFullPath is required: given a bare filename,
      // iOS writes into the app's Documents directory and Android into the
      // public Music directory, and neither is where this temp dir lives.
      // awaitSynthCompletion makes the call resolve once the file is actually
      // on disk rather than when synthesis merely started.
      await _tts.awaitSynthCompletion(true);
      await _tts.synthesizeToFile(clean, path, true);

      final file = File(path);
      if (!await file.exists()) return null;

      final wav = await file.readAsBytes();
      final decoded = decodeWav(wav);
      if (decoded == null) return null;

      final pcm = BuzzerSpeechCodec.condition(
        decoded.samples,
        decoded.sampleRate,
        timing,
      );
      if (pcm.isEmpty) return null;

      // An utterance past the node's buffer is rejected outright by the
      // firmware, so trim here and lose the tail rather than all of it.
      final capped = pcm.length > BuzzerSpeechCodec.maxUtteranceBytes
          ? Uint8List.sublistView(pcm, 0, BuzzerSpeechCodec.maxUtteranceBytes)
          : pcm;

      return BuzzerSpeechCodec.frame(capped, timing);
    } finally {
      try {
        await dir.delete(recursive: true);
      } catch (_) {
        // A leftover temp file is not worth failing an utterance over.
      }
    }
  }
}
