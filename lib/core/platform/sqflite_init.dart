// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Conditional-import facade for the desktop sqflite FFI initialiser.
//
// sqflite_common_ffi transitively pulls dart:ffi, which fails to compile
// on the web. Routing the boot-time init through this factory pins the
// web/io split to a single conditional import: the web build resolves
// the stub (no-op), native builds resolve the real implementation.

export 'sqflite_init_stub.dart'
    if (dart.library.io) 'sqflite_init_io.dart'
    show initDesktopSqflite;
