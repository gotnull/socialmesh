// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Native desktop initialiser for sqflite's FFI backend. Boot calls this
/// only when `caps.platformFamily == desktop`; mobile keeps the default
/// sqflite backend unchanged. Web resolves the stub, not this file.
Future<void> initDesktopSqflite() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}
