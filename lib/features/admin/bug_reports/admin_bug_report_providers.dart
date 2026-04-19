// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../features/feedback/bug_report_repository.dart';

/// Admin-scoped bug report with extra fields visible to admins.
class AdminBugReport {
  final String id;
  final String description;
  final String? screenshotUrl;
  final String? uid;
  final String? email;
  final String? appVersion;
  final String? buildNumber;
  final String? platform;
  final String? platformVersion;
  final String? deviceModel;
  final String? osVersion;
  final BugReportStatus status;
  final DateTime createdAt;
  final DateTime? lastResponseAt;
  final List<BugReportResponse> responses;
  final bool responsesLoaded;
  final bool hasUnreadUserReplies;
  final int unreadUserReplyCount;

  const AdminBugReport({
    required this.id,
    required this.description,
    this.screenshotUrl,
    this.uid,
    this.email,
    this.appVersion,
    this.buildNumber,
    this.platform,
    this.platformVersion,
    this.deviceModel,
    this.osVersion,
    this.status = BugReportStatus.open,
    required this.createdAt,
    this.lastResponseAt,
    this.responses = const [],
    this.responsesLoaded = true,
    this.hasUnreadUserReplies = false,
    this.unreadUserReplyCount = 0,
  });

  bool get isAnonymous => uid == null || uid!.isEmpty;

  AdminBugReport copyWith({
    List<BugReportResponse>? responses,
    bool? responsesLoaded,
    bool? hasUnreadUserReplies,
    int? unreadUserReplyCount,
  }) {
    return AdminBugReport(
      id: id,
      description: description,
      screenshotUrl: screenshotUrl,
      uid: uid,
      email: email,
      appVersion: appVersion,
      buildNumber: buildNumber,
      platform: platform,
      platformVersion: platformVersion,
      deviceModel: deviceModel,
      osVersion: osVersion,
      status: status,
      createdAt: createdAt,
      lastResponseAt: lastResponseAt,
      responses: responses ?? this.responses,
      responsesLoaded: responsesLoaded ?? this.responsesLoaded,
      hasUnreadUserReplies: hasUnreadUserReplies ?? this.hasUnreadUserReplies,
      unreadUserReplyCount: unreadUserReplyCount ?? this.unreadUserReplyCount,
    );
  }

  factory AdminBugReport.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    List<BugReportResponse> responses = const [],
    List<bool> readByAdminFlags = const [],
    bool responsesLoaded = true,
  }) {
    final data = doc.data()!;

    final unreadCount = countUnreadUserRepliesForAdmin(
      responses: responses,
      readByAdminFlags: readByAdminFlags,
    );

    return AdminBugReport(
      id: doc.id,
      description: data['description'] as String? ?? '',
      screenshotUrl: data['screenshotUrl'] as String?,
      uid: data['uid'] as String?,
      email: data['email'] as String?,
      appVersion: data['appVersion'] as String?,
      buildNumber: data['buildNumber'] as String?,
      platform: data['platform'] as String?,
      platformVersion: data['platformVersion'] as String?,
      deviceModel: data['deviceModel'] as String?,
      osVersion: data['osVersion'] as String?,
      status: BugReportStatus.fromString(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastResponseAt: (data['lastResponseAt'] as Timestamp?)?.toDate(),
      responses: responses,
      responsesLoaded: responsesLoaded,
      hasUnreadUserReplies: unreadCount > 0,
      unreadUserReplyCount: unreadCount,
    );
  }
}

class AdminBugReportThreadData {
  const AdminBugReportThreadData({
    required this.responses,
    required this.readByAdminFlags,
  });

  final List<BugReportResponse> responses;
  final List<bool> readByAdminFlags;
}

int countUnreadUserRepliesForAdmin({
  required List<BugReportResponse> responses,
  required List<bool> readByAdminFlags,
}) {
  var unreadCount = 0;
  for (var index = 0; index < responses.length; index++) {
    if (!responses[index].isFromUser) {
      continue;
    }

    final isRead = index < readByAdminFlags.length
        ? readByAdminFlags[index]
        : true;
    if (!isRead) {
      unreadCount++;
    }
  }
  return unreadCount;
}

List<AdminBugReport> hydrateAdminBugReports({
  required List<AdminBugReport> reports,
  required Map<String, AdminBugReportThreadData> threadDataByReportId,
}) {
  return reports.map((report) {
    final threadData = threadDataByReportId[report.id];
    final responses = threadData?.responses ?? const <BugReportResponse>[];
    final readByAdminFlags = threadData?.readByAdminFlags ?? const <bool>[];
    final unreadCount = countUnreadUserRepliesForAdmin(
      responses: responses,
      readByAdminFlags: readByAdminFlags,
    );

    return report.copyWith(
      responses: responses,
      responsesLoaded: true,
      hasUnreadUserReplies: unreadCount > 0,
      unreadUserReplyCount: unreadCount,
    );
  }).toList();
}

/// Repository for admin-scoped bug report operations.
class AdminBugReportRepository {
  AdminBugReportRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<AdminBugReportThreadData> _fetchResponsesForReport(
    DocumentReference<Map<String, dynamic>> reportRef,
  ) async {
    try {
      final responsesSnapshot = await reportRef
          .collection('responses')
          .orderBy('createdAt', descending: false)
          .get();

      return AdminBugReportThreadData(
        responses: responsesSnapshot.docs
            .map(BugReportResponse.fromFirestore)
            .toList(),
        readByAdminFlags: responsesSnapshot.docs
            .map((doc) => doc.data()['readByAdmin'] as bool? ?? false)
            .toList(),
      );
    } catch (e) {
      AppLogging.bugReport(
        'Admin: failed to fetch responses for ${reportRef.id}: $e',
      );
      return const AdminBugReportThreadData(
        responses: <BugReportResponse>[],
        readByAdminFlags: <bool>[],
      );
    }
  }

  List<AdminBugReport> _buildReportShells(
    Iterable<DocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .map((doc) => AdminBugReport.fromFirestore(doc, responsesLoaded: false))
        .toList();
  }

  Future<List<AdminBugReport>> _hydrateReports(
    Iterable<DocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final shellReports = _buildReportShells(docs);
    final responseEntries = await Future.wait(
      docs.map((doc) async {
        final responseData = await _fetchResponsesForReport(doc.reference);
        return MapEntry(doc.id, responseData);
      }),
    );

    return hydrateAdminBugReports(
      reports: shellReports,
      threadDataByReportId: Map<String, AdminBugReportThreadData>.fromEntries(
        responseEntries,
      ),
    );
  }

  /// Stream all bug reports (admin view) ordered by most recent.
  Stream<List<AdminBugReport>> watchAllReports() {
    return _firestore
        .collection('bugReports')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncExpand((snapshot) async* {
          final shellReports = _buildReportShells(snapshot.docs);
          AppLogging.bugReport(
            'Admin: streamed ${shellReports.length} bug report shells',
          );
          yield shellReports;

          if (snapshot.docs.isEmpty) {
            return;
          }

          final hydratedReports = await _hydrateReports(snapshot.docs);
          AppLogging.bugReport(
            'Admin: hydrated ${hydratedReports.length} bug reports',
          );
          yield hydratedReports;
        })
        .handleError((Object e) {
          AppLogging.bugReport('Admin bug reports stream error: $e');
        });
  }

  /// Send an admin response to a bug report via Cloud Function.
  Future<void> respondToReport({
    required String reportId,
    required String message,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'respondToBugReport',
    );
    await callable.call<dynamic>({'reportId': reportId, 'message': message});
    AppLogging.bugReport('Admin: responded to report $reportId');
  }

  /// Update a report's status directly.
  Future<void> updateReportStatus({
    required String reportId,
    required String status,
  }) async {
    await _firestore.collection('bugReports').doc(reportId).update({
      'status': status,
      'lastResponseAt': FieldValue.serverTimestamp(),
    });
    AppLogging.bugReport('Admin: updated report $reportId status to $status');
  }

  /// Mark all user responses on a report as read by admin.
  Future<void> markUserResponsesAsRead(String reportId) async {
    final responsesSnapshot = await _firestore
        .collection('bugReports')
        .doc(reportId)
        .collection('responses')
        .where('from', isEqualTo: 'user')
        .where('readByAdmin', isEqualTo: false)
        .get();

    if (responsesSnapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in responsesSnapshot.docs) {
      batch.update(doc.reference, {'readByAdmin': true});
    }
    await batch.commit();

    AppLogging.bugReport(
      'Admin: marked ${responsesSnapshot.docs.length} responses as read '
      'on report $reportId',
    );
  }
}

/// Provider for the admin bug report repository.
final adminBugReportRepositoryProvider = Provider<AdminBugReportRepository>((
  ref,
) {
  return AdminBugReportRepository();
});

/// Provider streaming all bug reports for admin view.
final adminBugReportsProvider = StreamProvider<List<AdminBugReport>>((ref) {
  final repository = ref.watch(adminBugReportRepositoryProvider);
  return repository.watchAllReports();
});

/// Provider for open bug report count (for badge on admin screen).
final adminOpenBugReportCountProvider = Provider<int>((ref) {
  final reports = ref.watch(adminBugReportsProvider);
  return reports.when(
    data: (list) => list.where((r) => r.status == BugReportStatus.open).length,
    loading: () => 0,
    error: (_, _) => 0,
  );
});
