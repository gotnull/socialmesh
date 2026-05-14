// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Web-build stub for Codec2 native bindings.
///
/// The real bindings (`codec2_bindings_io.dart`) require dart:ffi, which
/// cannot compile to wasm/dart2js. The stub keeps just enough public
/// surface for callers (`waveform_analysis.dart`, the codec2 ffi facade)
/// to compile; runtime safety comes from the `isAvailable` gate every
/// consumer checks before calling other methods.
final class Codec2Bindings {
  Codec2Bindings._();

  static bool get isAvailable => false;
}
