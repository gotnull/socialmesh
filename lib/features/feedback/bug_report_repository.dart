// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
        return 'Awaiting Response';
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
  });

  /// Whether this report has unread founder responses.
  bool get hasUnreadResponses =>
      responses.any((r) => r.isFromFounder && !r.readByUser);

  /// Number of unread founder responses.
  int get unreadCount =>
      responses.where((r) => r.isFromFounder && !r.readByUser).length;

  factory BugReport.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    List<BugReportResponse> responses = const [],
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
    );
  }
}

/// Repository for accessing bug reports and their responses from Firestore.
class BugReportRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Fetch all bug reports for the current user, including responses.
  Future<List<BugReport>> fetchMyReports() async {
    final user = FirebaseAuth.instance.currentUser;
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

      final reports = <BugReport>[];

      for (final doc in snapshot.docs) {
        // Fetch responses subcollection for each report
        final responsesSnapshot = await doc.reference
            .collection('responses')
            .orderBy('createdAt', descending: false)
            .get();

        final responses = responsesSnapshot.docs
            .map(BugReportResponse.fromFirestore)
            .toList();

        reports.add(BugReport.fromFirestore(doc, responses: responses));
      }

      AppLogging.bugReport(
        'Fetched ${reports.length} bug reports for user ${user.uid}',
      );
      return reports;
    } catch (e) {
      AppLogging.bugReport('Failed to fetch bug reports: $e');
      return [];
    }
  }

  /// Fetch a single bug report by ID, including responses.
  Future<BugReport?> fetchReport(String reportId) async {
    try {
      final doc = await _firestore.collection('bugReports').doc(reportId).get();

      if (!doc.exists) return null;

      final responsesSnapshot = await doc.reference
          .collection('responses')
          .orderBy('createdAt', descending: false)
          .get();

      final responses = responsesSnapshot.docs
          .map(BugReportResponse.fromFirestore)
          .toList();

      return BugReport.fromFirestore(doc, responses: responses);
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
    final callable = _functions.httpsCallable('replyToBugReport');
    final result = await callable.call({
      'reportId': reportId,
      'message': message,
    });

    final data = result.data as Map<String, dynamic>?;
    if (data == null || data['success'] != true) {
      throw Exception(data?['error'] ?? 'Failed to send reply');
    }

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
/// Invalidate this provider to refresh the list.
final myBugReportsProvider = FutureProvider<List<BugReport>>((ref) async {
  final repository = ref.watch(bugReportRepositoryProvider);
  return repository.fetchMyReports();
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
