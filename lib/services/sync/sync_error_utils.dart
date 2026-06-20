// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Shared helpers for interpreting Cloud Sync errors.

import 'package:firebase_core/firebase_core.dart';

/// Whether [error] is a Firestore permission-denied failure.
///
/// Cloud Sync writes are gated server-side by the paid entitlement. When a
/// subscription lapses mid-cycle (or a stale client retries after the
/// entitlement is revoked), Firestore rejects the write with a
/// `permission-denied` [FirebaseException]. Outbox drains treat this as a
/// terminal, non-retryable outcome: stop the cycle, keep the queued upload,
/// and do not count it toward the retry cap, so the change still syncs once
/// the user is entitled again.
bool isCloudSyncPermissionDenied(Object error) {
  return error is FirebaseException && error.code == 'permission-denied';
}
