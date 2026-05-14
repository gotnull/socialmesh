// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Conditional-import facade for Codec2's native FFI bindings. Web build
// resolves the stub (returns isAvailable=false); native builds resolve
// the real implementation. Callers always import this facade, never the
// io / stub files directly.

export 'codec2_bindings_stub.dart'
    if (dart.library.io) 'codec2_bindings_io.dart'
    show Codec2Bindings;
