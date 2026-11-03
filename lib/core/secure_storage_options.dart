// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Android options every [FlutterSecureStorage] in the app MUST pass.
///
/// All instances share one Android store, and the plugin's default
/// `resetOnError: true` answers any failure in any call by wiping that whole
/// store. The store holds the SQLCipher passphrase, so one failed read of an
/// unrelated key leaves every encrypted database on disk unreadable. With
/// reset off, a failure surfaces as a `PlatformException` to its caller and
/// the other keys survive.
///
/// Lint: `secure-storage-android-options`.
const kSecureStorageAndroidOptions = AndroidOptions(resetOnError: false);
