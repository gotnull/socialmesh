// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Web stub for the host-OS lookup. On the web there is no real host OS
/// to read, so callers should pre-empt this with a `kIsWeb` check before
/// asking. Returning the sentinel `web` keeps the API total.
String hostOperatingSystem() => 'web';
