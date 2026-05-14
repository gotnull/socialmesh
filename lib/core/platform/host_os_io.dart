// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:io' show Platform;

/// Native host-OS lookup. Returns the lowercase OS identifier exactly as
/// `Platform.operatingSystem` would (`ios`, `android`, `macos`, `windows`,
/// `linux`, `fuchsia`). Only callable on platforms with `dart:io`; the web
/// build resolves the stub variant instead.
String hostOperatingSystem() => Platform.operatingSystem;
