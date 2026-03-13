// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:ffi';
import 'dart:io';

/// Raw dart:ffi bindings for the Codec2 C library (v1.2.0, LGPL-2.1).
///
/// Opens the correct native library per platform:
/// - Android: libcodec2.so (dynamic, loaded by the linker from jniLibs/)
/// - iOS:     DynamicLibrary.process() (statically linked into the Runner)
/// - macOS:   macos/codec2/libcodec2.dylib (test runner only)
///
/// Do not use this class directly. Use [Codec2Encoder] / [Codec2Decoder]
/// from codec2_ffi.dart instead.
final class Codec2Bindings {
  Codec2Bindings._();

  static DynamicLibrary? _lib;
  static bool? _available;

  /// Returns true if the Codec2 native library is loaded and contains the
  /// expected symbols. Safe to call at any time — never throws.
  static bool get isAvailable {
    if (_available != null) return _available!;
    try {
      final lib = library;
      lib.lookup<NativeFunction<Void Function()>>('codec2_create');
      _available = true;
    } catch (_) {
      _available = false;
    }
    return _available!;
  }

  static DynamicLibrary get library {
    if (_lib != null) return _lib!;
    if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libcodec2.so');
    } else if (Platform.isIOS) {
      _lib = DynamicLibrary.process();
    } else if (Platform.isMacOS) {
      // Test runner only — not shipped in any release build.
      // Resolve relative to the test binary's working directory.
      final candidates = [
        'macos/codec2/libcodec2.dylib',
        '../macos/codec2/libcodec2.dylib',
      ];
      for (final path in candidates) {
        if (File(path).existsSync()) {
          _lib = DynamicLibrary.open(path);
          return _lib!;
        }
      }
      throw UnsupportedError('Cannot find libcodec2.dylib for macOS tests');
    } else {
      throw UnsupportedError(
        'Codec2 native library is not available on ${Platform.operatingSystem}. '
        'Voice messages are supported on iOS and Android only.',
      );
    }
    return _lib!;
  }

  // ---------------------------------------------------------------------------
  // Private cached function pointers
  // ---------------------------------------------------------------------------

  static _Codec2CreateDart? _codec2Create;
  static _Codec2SamplesPerFrameDart? _codec2SamplesPerFrame;
  static _Codec2EncodeDart? _codec2Encode;
  static _Codec2DecodeDart? _codec2Decode;
  static _Codec2DestroyDart? _codec2Destroy;

  // ---------------------------------------------------------------------------
  // Public static API
  // ---------------------------------------------------------------------------

  /// Calls `codec2_create(mode)` — returns an opaque CODEC2 context pointer.
  static Pointer<Void> codec2Create(int mode) {
    _codec2Create ??= library
        .lookupFunction<_Codec2CreateNative, _Codec2CreateDart>(
          'codec2_create',
        );
    return _codec2Create!(mode);
  }

  /// Calls `codec2_samples_per_frame(c2)`.
  static int codec2SamplesPerFrame(Pointer<Void> c2) {
    _codec2SamplesPerFrame ??= library
        .lookupFunction<
          _Codec2SamplesPerFrameNative,
          _Codec2SamplesPerFrameDart
        >('codec2_samples_per_frame');
    return _codec2SamplesPerFrame!(c2);
  }

  /// Calls `codec2_encode(c2, bits, speechIn)`.
  static void codec2Encode(
    Pointer<Void> c2,
    Pointer<Uint8> bits,
    Pointer<Int16> speechIn,
  ) {
    _codec2Encode ??= library
        .lookupFunction<_Codec2EncodeNative, _Codec2EncodeDart>(
          'codec2_encode',
        );
    _codec2Encode!(c2, bits, speechIn);
  }

  /// Calls `codec2_decode(c2, speechOut, bits)`.
  static void codec2Decode(
    Pointer<Void> c2,
    Pointer<Int16> speechOut,
    Pointer<Uint8> bits,
  ) {
    _codec2Decode ??= library
        .lookupFunction<_Codec2DecodeNative, _Codec2DecodeDart>(
          'codec2_decode',
        );
    _codec2Decode!(c2, speechOut, bits);
  }

  /// Calls `codec2_destroy(c2)`.
  static void codec2Destroy(Pointer<Void> c2) {
    _codec2Destroy ??= library
        .lookupFunction<_Codec2DestroyNative, _Codec2DestroyDart>(
          'codec2_destroy',
        );
    _codec2Destroy!(c2);
  }

  /// Resets all cached function pointers and the library handle (for tests).
  static void reset() {
    _lib = null;
    _codec2Create = null;
    _codec2SamplesPerFrame = null;
    _codec2Encode = null;
    _codec2Decode = null;
    _codec2Destroy = null;
  }
}

// ---------------------------------------------------------------------------
// Native typedef declarations
// ---------------------------------------------------------------------------

typedef _Codec2CreateNative = Pointer<Void> Function(Int32 mode);
typedef _Codec2CreateDart = Pointer<Void> Function(int mode);

typedef _Codec2SamplesPerFrameNative = Int32 Function(Pointer<Void> c2);
typedef _Codec2SamplesPerFrameDart = int Function(Pointer<Void> c2);

typedef _Codec2EncodeNative =
    Void Function(
      Pointer<Void> c2,
      Pointer<Uint8> bits,
      Pointer<Int16> speechIn,
    );
typedef _Codec2EncodeDart =
    void Function(
      Pointer<Void> c2,
      Pointer<Uint8> bits,
      Pointer<Int16> speechIn,
    );

typedef _Codec2DecodeNative =
    Void Function(
      Pointer<Void> c2,
      Pointer<Int16> speechOut,
      Pointer<Uint8> bits,
    );
typedef _Codec2DecodeDart =
    void Function(
      Pointer<Void> c2,
      Pointer<Int16> speechOut,
      Pointer<Uint8> bits,
    );

typedef _Codec2DestroyNative = Void Function(Pointer<Void> c2);
typedef _Codec2DestroyDart = void Function(Pointer<Void> c2);
