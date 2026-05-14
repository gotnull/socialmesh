// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Conditional-import facade for the Codec2 FFI public surface.
// Web resolves the stub (no dart:ffi); native builds resolve the real
// implementation in codec2_ffi_io.dart. Consumers (voice_encoder.dart,
// voice_decoder.dart) import this facade and never the io / stub files
// directly. Codec2Encoder and Codec2Decoder are only referenced inside
// the codec2 package, so they are intentionally NOT re-exported from the
// stub.

export 'codec2_ffi_stub.dart'
    if (dart.library.io) 'codec2_ffi_io.dart'
    show
        codec2Mode1200,
        codec2BytesPerFrame1200,
        codec2SamplesPerFrame1200,
        codec2BytesPerFrame,
        encodeCodec2Frames,
        decodeCodec2Frames;
