// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging.dart';

/// Status of a bug report.
enum BugReportStatus {
  open,
  responded,
  userReplied,
  resolved;

  static BugReportStatus fromString(String? value) {
    switch (value) {
      case 'responded':
        return BugReportStatus.responded;
      case 'user_replied':
        return BugReportStatus.userReplied;
      case 'resolved':
        return BugReportStatus.resolved;
      default:
        return BugReportStatus.open;
    }
  }

  String get label {
    switch (this) {
      case BugReportStatus.open:
        return 'Open';
      case BugReportStatus.responded:
        return 'Responded';
      case BugReportStatus.userReplied:
        return 'Awaiting Response'; // lint-allow: hardcoded-string
      case BugReportStatus.resolved:
        return 'Resolved';
    }
  }
}

/// A single response in a bug report thread.
class BugReportResponse {
  final String id;
  final String from;
  final String message;
  final DateTime createdAt;
  final bool readByUser;

  const BugReportResponse({
    required this.id,
    required this.from,
    required this.message,
    required this.createdAt,
    this.readByUser = false,
  });

  bool get isFromFounder => from == 'founder';
  bool get isFromUser => from == 'user';

  factory BugReportResponse.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return BugReportResponse(
      id: doc.id,
      from: data['from'] as String? ?? 'founder',
      message: data['message'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readByUser: data['readByUser'] as bool? ?? false,
    );
  }
}

/// A bug report submitted by the user.
class BugReport {
  final String id;
  final String description;
  final String? screenshotUrl;
  final String? appVersion;
  final String? platform;
  final BugReportStatus status;
  final DateTime createdAt;
  final DateTime? lastResponseAt;
  final List<BugReportResponse> responses;
  final bool responsesLoaded;

  const BugReport({
    required this.id,
    required this.description,
    this.screenshotUrl,
    this.appVersion,
    this.platform,
    this.status = BugReportStatus.open,
    required this.createdAt,
    this.lastResponseAt,
    this.responses = const [],
    this.responsesLoaded = true,
  });

  BugReport copyWith({
    List<BugReportResponse>? responses,
    bool? responsesLoaded,
  }) {
    return BugReport(
      id: id,
      description: description,
      screenshotUrl: screenshotUrl,
      appVersion: appVersion,
      platform: platform,
      status: status,
      createdAt: createdAt,
      lastResponseAt: lastResponseAt,
      responses: responses ?? this.responses,
      responsesLoaded: responsesLoaded ?? this.responsesLoaded,
    );
  }

  /// Whether this report has unread founder responses.
  bool get hasUnreadResponses =>
      responses.any((r) => r.isFromFounder && !r.readByUser);

  /// Number of unread founder responses.
  int get unreadCount =>
      responses.where((r) => r.isFromFounder && !r.readByUser).length;

  factory BugReport.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    List<BugReportResponse> responses = const [],
    bool responsesLoaded = true,
  }) {
    final data = doc.data()!;
    return BugReport(
      id: doc.id,
      description: data['description'] as String? ?? '',
      screenshotUrl: data['screenshotUrl'] as String?,
      appVersion: data['appVersion'] as String?,
      platform: data['platform'] as String?,
      status: BugReportStatus.fromString(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastResponseAt: (data['lastResponseAt'] as Timestamp?)?.toDate(),
      responses: responses,
      responsesLoaded: responsesLoaded,
    );
  }
}

List<BugReport> hydrateBugReports({
  required List<BugReport> reports,
  required Map<String, List<BugReportResponse>> responsesByReportId,
}) {
  return reports
      .map(
        (report) => report.copyWith(
          responses: responsesByReportId[report.id] ?? const [],
          responsesLoaded: true,
        ),
      )
      .toList();
}

/// Repository for accessing bug reports and their responses from Firestore.
class BugReportRepository {
  BugReportRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<List<BugReportResponse>> _fetchResponsesForReport(
    DocumentReference<Map<String, dynamic>> reportRef,
  ) async {
    try {
      final responsesSnapshot = await reportRef
          .collection('responses')
          .orderBy('createdAt', descending: false)
          .get();

      return responsesSnapshot.docs
          .map(BugReportResponse.fromFirestore)
          .toList();
    } catch (e) {
      AppLogging.bugReport('Failed to fetch responses for ${reportRef.id}: $e');
      return const [];
    }
  }

  List<BugReport> _buildReportShells(
    Iterable<DocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .map((doc) => BugReport.fromFirestore(doc, responsesLoaded: false))
        .toList();
  }

  Future<List<BugReport>> _hydrateReports(
    Iterable<DocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final shellReports = _buildReportShells(docs);
    final responseEntries = await Future.wait(
      docs.map((doc) async {
        final responses = await _fetchResponsesForReport(doc.reference);
        return MapEntry(doc.id, responses);
      }),
    );

    return hydrateBugReports(
      reports: shellReports,
      responsesByReportId: Map<String, List<BugReportResponse>>.fromEntries(
        responseEntries,
      ),
    );
  }

  /// Fetch all bug reports for the current user, including responses.
  Future<List<BugReport>> fetchMyReports() async {
    final user = _auth.currentUser;
    if (user == null) {
      AppLogging.bugReport('Cannot fetch reports: no user signed in');
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection('bugReports')
          .where('uid', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      final reports = await _hydrateReports(snapshot.docs);

      AppLogging.bugReport(
        'Fetched ${reports.length} bug reports for user ${user.uid}',
      );
      return reports;
    } catch (e) {
      AppLogging.bugReport('Failed to fetch bug reports: $e');
      return [];
    }
  }

  /// Watch all bug reports for the current user with live Firestore updates.
  ///
  /// Streams the parent collection and re-fetches responses on each change.
  /// Admin responses update the parent doc (status/lastResponseAt), which
  /// triggers the stream and pulls fresh response subcollections.
  Stream<List<BugReport>> watchMyReports() {
    final user = _auth.currentUser;
    if (user == null) {
      AppLogging.bugReport('Cannot watch reports: no user signed in');
      return Stream.value([]);
    }

    return _firestore
        .collection('bugReports')
        .where('uid', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncExpand((snapshot) async* {
          final shellReports = _buildReportShells(snapshot.docs);
          AppLogging.bugReport(
            'Streamed ${shellReports.length} bug report shells for user ${user.uid}',
          );
          yield shellReports;

          if (snapshot.docs.isEmpty) {
            return;
          }

          final hydratedReports = await _hydrateReports(snapshot.docs);
          AppLogging.bugReport(
            'Hydrated ${hydratedReports.length} bug reports for user ${user.uid}',
          );
          yield hydratedReports;
        })
        .handleError((Object e) {
          AppLogging.bugReport('Bug reports stream error: $e');
        });
  }

  /// Fetch a single bug report by ID, including responses.
  Future<BugReport?> fetchReport(String reportId) async {
    try {
      final doc = await _firestore.collection('bugReports').doc(reportId).get();

      if (!doc.exists) return null;

      final responses = await _fetchResponsesForReport(doc.reference);

      return BugReport.fromFirestore(
        doc,
        responses: responses,
        responsesLoaded: true,
      );
    } catch (e) {
      AppLogging.bugReport('Failed to fetch report $reportId: $e');
      return null;
    }
  }

  /// Mark all founder responses on a report as read by the user.
  Future<void> markResponsesAsRead(String reportId) async {
    try {
      final responsesSnapshot = await _firestore
          .collection('bugReports')
          .doc(reportId)
          .collection('responses')
          .where('from', isEqualTo: 'founder')
          .where('readByUser', isEqualTo: false)
          .get();

      if (responsesSnapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in responsesSnapshot.docs) {
        batch.update(doc.reference, {'readByUser': true});
      }
      await batch.commit();

      AppLogging.bugReport(
        'Marked ${responsesSnapshot.docs.length} responses as read '
        'on report $reportId',
      );
    } catch (e) {
      AppLogging.bugReport('Failed to mark responses as read: $e');
    }
  }

  /// Reply to a bug report (user → founder).
  Future<void> replyToReport({
    required String reportId,
    required String message,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to reply');
    }

    final reportRef = _firestore.collection('bugReports').doc(reportId);

    // Write the reply to the responses subcollection
    await reportRef.collection('responses').add({
      'from': 'user',
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
      'responderId': user.uid,
    });

    // Update report status
    await reportRef.update({
      'status': 'user_replied',
      'lastResponseAt': FieldValue.serverTimestamp(),
    });

    AppLogging.bugReport('Reply sent to report $reportId');
  }

  /// Total unread response count across all reports.
  Future<int> fetchTotalUnreadCount() async {
    final reports = await fetchMyReports();
    return reports.fold<int>(0, (total, report) => total + report.unreadCount);
  }
}

/// Provider for the bug report repository.
final bugReportRepositoryProvider = Provider<BugReportRepository>((ref) {
  return BugReportRepository();
});

/// Provider for the user's bug reports list.
/// Uses Firestore snapshots for live updates when admin responds.
/// Invalidate this provider to restart the stream.
final myBugReportsProvider = StreamProvider<List<BugReport>>((ref) {
  final repository = ref.watch(bugReportRepositoryProvider);
  return repository.watchMyReports();
});

/// Provider for total unread bug report response count.
final bugReportUnreadCountProvider = FutureProvider<int>((ref) async {
  final reports = ref.watch(myBugReportsProvider);
  return reports.when(
    data: (list) =>
        list.fold<int>(0, (total, report) => total + report.unreadCount),
    loading: () => 0,
    error: (_, _) => 0,
  );
});
