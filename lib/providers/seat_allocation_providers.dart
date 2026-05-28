// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Riverpod wiring for group / community licensing seat allocations.
//
// Provider graph (read top-down):
//
//   seatAllocationRepositoryProvider     <- data layer (Firestore by default)
//        |
//        v
//   currentUserSeatAllocationsProvider   <- Set<SeatAllocationRef> the
//                                          current user holds, gated by
//                                          the GROUP_LICENSING_ENABLED
//                                          flag AND auth state.
//
// This provider IS now consumed by `externalEntitlementsProvider` to
// admit org-owned entitlement rows whose `(orgId, productId)` matches
// an active seat AND whose `orgId` matches an org the user currently
// belongs to. Removing either side (membership OR seat) flips the
// pack back to locked.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/logging.dart';
import '../models/seat_allocation.dart';
import '../services/org/seat_allocation_repository.dart';
import 'auth_providers.dart';

/// Injection point for [SeatAllocationRepository]. Tests override this
/// with a fake repo; production reads from Firestore.
final seatAllocationRepositoryProvider = Provider<SeatAllocationRepository>((
  ref,
) {
  return FirestoreSeatAllocationRepository();
});

/// Set of active seats held by the current user, projected as
/// `(orgId, productId)` refs.
///
/// Yields an empty set when any precondition fails:
///   - `AppFeatureFlags.isGroupLicensingEnabled` is false
///   - current user is null (signed out)
///   - current user is anonymous (guest)
///   - current user has an empty uid
///   - the underlying repository stream errors
final currentUserSeatAllocationsProvider =
    StreamProvider<Set<SeatAllocationRef>>((ref) async* {
      if (!AppFeatureFlags.isGroupLicensingEnabled) {
        AppLogging.groupLicensing(
          '[SeatAllocation] feature flag disabled - yielding empty',
        );
        yield const <SeatAllocationRef>{};
        return;
      }

      final user = ref.watch(currentUserProvider);
      if (user == null) {
        yield const <SeatAllocationRef>{};
        return;
      }
      if (user.isAnonymous) {
        AppLogging.groupLicensing(
          '[SeatAllocation] anonymous user - yielding empty '
          '(guest mode is seat-blind)',
        );
        yield const <SeatAllocationRef>{};
        return;
      }
      if (user.uid.isEmpty) {
        yield const <SeatAllocationRef>{};
        return;
      }

      final repo = ref.watch(seatAllocationRepositoryProvider);
      yield const <SeatAllocationRef>{};

      try {
        await for (final seats in repo.watchCurrentUserSeats(user.uid)) {
          yield seats;
        }
      } catch (e) {
        AppLogging.groupLicensing(
          '[SeatAllocation] repository stream threw - failing closed '
          '(error class: ${e.runtimeType})',
        );
        yield const <SeatAllocationRef>{};
      }
    });

/// Convenience checker: does the current user hold an active seat for
/// `(orgId, productId)`?
final hasSeatForProvider = Provider.family<bool, SeatAllocationRef>((
  ref,
  seatRef,
) {
  final async = ref.watch(currentUserSeatAllocationsProvider);
  return async.maybeWhen(
    data: (seats) => seats.contains(seatRef),
    orElse: () => false,
  );
});

/// Imperative refresh hook for diagnostics. Invalidates the stream
/// provider; the next subscriber re-evaluates flag + auth state and
/// re-subscribes to the repository.
void debugRefreshSeatAllocations(WidgetRef ref) {
  AppLogging.groupLicensing('[SeatAllocation] debugRefresh requested');
  ref.invalidate(currentUserSeatAllocationsProvider);
}

/// Count of active seat allocations for [orgId] across all users.
/// Owner-facing surfaces pair this with [LicenseOrg.seatCapacity] to
/// render "X of Y seats used". Yields 0 when the flag is off, the
/// orgId is empty, or the underlying stream errors.
final licenseOrgActiveSeatCountProvider = StreamProvider.family<int, String>((
  ref,
  orgId,
) async* {
  if (!AppFeatureFlags.isGroupLicensingEnabled) {
    yield 0;
    return;
  }
  if (orgId.isEmpty) {
    yield 0;
    return;
  }
  final repo = ref.watch(seatAllocationRepositoryProvider);
  yield 0;
  try {
    await for (final count in repo.watchOrgActiveSeatCount(orgId)) {
      yield count;
    }
  } catch (e) {
    AppLogging.groupLicensing(
      '[SeatAllocation] org-count stream threw - failing closed '
      '(error class: ${e.runtimeType})',
    );
    yield 0;
  }
});
