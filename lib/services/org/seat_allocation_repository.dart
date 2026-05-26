// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Data layer for group / community licensing seat allocations.
//
// Streams the set of `(orgId, productId)` pairs the given uid
// currently holds an active seat for. Fail-closed everywhere:
// malformed rows, status != active, and Firestore errors all degrade
// to "no seat" rather than throw into the provider stream.
//
// See docs/engineering/GROUP_LICENSING_FOUNDATION.md.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/logging.dart';
import '../../models/seat_allocation.dart';

/// Streams the set of active seats held by [uid]. Implementations MUST
/// fail closed: any error path must emit an empty set rather than
/// rethrow.
abstract class SeatAllocationRepository {
  /// Emits the current seat set on subscribe, then re-emits on every
  /// underlying change. Empty set on empty uid.
  Stream<Set<SeatAllocationRef>> watchCurrentUserSeats(String uid);
}

/// Firestore-backed implementation.
///
/// Queries `org_seat_allocations.where(uid == uid, status == 'active')`
/// at the top-level collection (allocations are NOT a subcollection of
/// the org so collection-group queries are avoided).
class FirestoreSeatAllocationRepository implements SeatAllocationRepository {
  final FirebaseFirestore _firestore;

  FirestoreSeatAllocationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<Set<SeatAllocationRef>> watchCurrentUserSeats(String uid) {
    if (uid.isEmpty) return Stream.value(const <SeatAllocationRef>{});

    final controller = StreamController<Set<SeatAllocationRef>>();
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;

    controller.onListen = () {
      sub = _firestore
          .collection('org_seat_allocations')
          .where('uid', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .snapshots()
          .listen(
            (snap) {
              final result = <SeatAllocationRef>{};
              for (final doc in snap.docs) {
                final allocation = SeatAllocation.fromFirestore(doc);
                if (allocation == null) continue;
                if (!allocation.isAccessActive) continue;
                result.add(allocation.toRef());
              }
              if (controller.isClosed) return;
              controller.add(result);
            },
            onError: (Object e) {
              AppLogging.groupLicensing(
                '[SeatAllocationRepo] stream error - failing closed '
                '(error class: ${e.runtimeType})',
              );
              if (controller.isClosed) return;
              controller.add(const <SeatAllocationRef>{});
            },
          );

      // Emit an initial empty set so subscribers do not block waiting
      // for the first Firestore snapshot.
      if (!controller.isClosed) {
        controller.add(const <SeatAllocationRef>{});
      }
    };

    controller.onCancel = () async {
      await sub?.cancel();
      sub = null;
    };

    return controller.stream;
  }
}
