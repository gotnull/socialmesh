import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/node_avatar.dart';
import '../../models/social.dart';
import '../../utils/snackbar.dart';

/// Admin screen to manage all follow requests across all users.
/// This bypasses normal auth checks for testing purposes.
class AdminFollowRequestsScreen extends ConsumerStatefulWidget {
  const AdminFollowRequestsScreen({super.key});

  @override
  ConsumerState<AdminFollowRequestsScreen> createState() =>
      _AdminFollowRequestsScreenState();
}

class _AdminFollowRequestsScreenState
    extends ConsumerState<AdminFollowRequestsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        title: Text(
          'Admin: Follow Requests',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add, color: context.textPrimary),
            onPressed: _showSeedUsersDialog,
            tooltip: 'Seed dummy users',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('follow_requests')
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppTheme.errorRed,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading requests',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final requests = snapshot.data?.docs ?? [];

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: context.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pending requests',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _showSeedUsersDialog,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Seed Dummy Users'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final doc = requests[index];
              final request = FollowRequest.fromFirestore(doc);
              return _FollowRequestCard(
                request: request,
                onAccept: () => _acceptRequest(request),
                onDecline: () => _declineRequest(request),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _acceptRequest(FollowRequest request) async {
    try {
      final batch = _firestore.batch();

      // Create the follow relationship
      final followId = '${request.requesterId}_${request.targetId}';
      final follow = Follow(
        id: followId,
        followerId: request.requesterId,
        followeeId: request.targetId,
        createdAt: DateTime.now(),
      );
      batch.set(
        _firestore.collection('follows').doc(followId),
        follow.toFirestore(),
      );

      // Delete the follow request
      batch.delete(
        _firestore.collection('follow_requests').doc(request.documentId),
      );

      await batch.commit();

      if (mounted) {
        showSuccessSnackBar(context, 'Request approved');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to approve: $e');
      }
    }
  }

  Future<void> _declineRequest(FollowRequest request) async {
    try {
      await _firestore
          .collection('follow_requests')
          .doc(request.documentId)
          .delete();

      if (mounted) {
        showSuccessSnackBar(context, 'Request declined');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to decline: $e');
      }
    }
  }

  void _showSeedUsersDialog() {
    showDialog(
      context: context,
      builder: (context) => _SeedUsersDialog(firestore: _firestore),
    );
  }
}

class _FollowRequestCard extends StatelessWidget {
  const _FollowRequestCard({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  final FollowRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PublicProfile?>>(
      future: Future.wait([
        _getProfile(request.requesterId),
        _getProfile(request.targetId),
      ]),
      builder: (context, snapshot) {
        final requesterProfile = snapshot.data?[0];
        final targetProfile = snapshot.data?[1];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // From -> To
              Row(
                children: [
                  // Requester
                  _ProfileBadge(
                    profile: requesterProfile,
                    userId: request.requesterId,
                    label: 'FROM',
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward,
                    color: context.textTertiary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  // Target
                  _ProfileBadge(
                    profile: targetProfile,
                    userId: request.targetId,
                    label: 'TO',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Time
              Text(
                'Requested ${_formatTime(request.createdAt)}',
                style: TextStyle(color: context.textTertiary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDecline,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorRed,
                        side: BorderSide(
                          color: AppTheme.errorRed.withAlpha(100),
                        ),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: onAccept,
                      style: FilledButton.styleFrom(
                        backgroundColor: AccentColors.green,
                      ),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<PublicProfile?> _getProfile(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('profiles')
          .doc(userId)
          .get();
      if (doc.exists) {
        return PublicProfile.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
    return null;
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}/${time.year}';
  }
}

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({
    required this.profile,
    required this.userId,
    required this.label,
  });

  final PublicProfile? profile;
  final String userId;
  final String label;

  @override
  Widget build(BuildContext context) {
    final displayName =
        profile?.displayName ?? 'User ${userId.substring(0, 6)}...';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: context.textTertiary,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                NodeAvatar(
                  text: initial,
                  color: _getColorForUserId(userId),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayName,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (profile?.isPrivate ?? false)
                  Icon(Icons.lock, size: 12, color: context.textTertiary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForUserId(String id) {
    final colors = AccentColors.all;
    return colors[id.hashCode.abs() % colors.length];
  }
}

class _SeedUsersDialog extends StatefulWidget {
  const _SeedUsersDialog({required this.firestore});

  final FirebaseFirestore firestore;

  @override
  State<_SeedUsersDialog> createState() => _SeedUsersDialogState();
}

class _SeedUsersDialogState extends State<_SeedUsersDialog> {
  bool _isSeeding = false;
  String _status = '';
  final List<String> _log = [];

  // Dummy user data
  static const _dummyUsers = [
    {
      'id': 'dummy_user_alice',
      'displayName': 'Alice Anderson',
      'bio': 'Mesh networking enthusiast. Off-grid living advocate.',
      'callsign': 'AA1',
      'isPrivate': false,
      'isVerified': true,
    },
    {
      'id': 'dummy_user_bob',
      'displayName': 'Bob Builder',
      'bio': 'Building mesh networks one node at a time.',
      'callsign': 'BB2',
      'isPrivate': true,
      'isVerified': false,
    },
    {
      'id': 'dummy_user_carol',
      'displayName': 'Carol Chen',
      'bio': 'Radio amateur since 2015. KD7ABC.',
      'callsign': 'CC3',
      'isPrivate': true,
      'isVerified': false,
    },
    {
      'id': 'dummy_user_dave',
      'displayName': 'Dave Davidson',
      'bio': 'Emergency preparedness instructor.',
      'callsign': 'DD4',
      'isPrivate': false,
      'isVerified': false,
    },
    {
      'id': 'dummy_user_eve',
      'displayName': 'Eve Edwards',
      'bio': 'Privacy advocate. Decentralization maximalist.',
      'callsign': 'EE5',
      'isPrivate': true,
      'isVerified': true,
    },
    {
      'id': 'dummy_user_frank',
      'displayName': 'Frank Fisher',
      'bio': 'Mountain rescue volunteer. SAR team member.',
      'callsign': 'FF6',
      'isPrivate': false,
      'isVerified': false,
    },
    {
      'id': 'dummy_user_grace',
      'displayName': 'Grace Garcia',
      'bio': 'Solar powered mesh node operator.',
      'callsign': 'GG7',
      'isPrivate': true,
      'isVerified': false,
    },
    {
      'id': 'dummy_user_henry',
      'displayName': 'Henry Huang',
      'bio': 'Electronics hobbyist. DIY antenna builder.',
      'callsign': 'HH8',
      'isPrivate': false,
      'isVerified': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.card,
      title: Text(
        'Seed Dummy Users',
        style: TextStyle(color: context.textPrimary),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will create ${_dummyUsers.length} dummy profiles for testing:',
              style: TextStyle(color: context.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            // User list preview
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: context.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _dummyUsers.length,
                itemBuilder: (context, index) {
                  final user = _dummyUsers[index];
                  final isPrivate = user['isPrivate'] as bool;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          isPrivate ? Icons.lock : Icons.public,
                          size: 14,
                          color: isPrivate
                              ? context.textTertiary
                              : AccentColors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          user['displayName'] as String,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                        if (user['isVerified'] == true) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified,
                            size: 12,
                            color: context.accentColor,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            if (_isSeeding) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                backgroundColor: context.border,
                valueColor: AlwaysStoppedAnimation(context.accentColor),
              ),
              const SizedBox(height: 8),
              Text(
                _status,
                style: TextStyle(color: context.textTertiary, fontSize: 12),
              ),
            ],
            if (_log.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                height: 100,
                decoration: BoxDecoration(
                  color: context.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _log.length,
                  itemBuilder: (context, index) => Text(
                    _log[index],
                    style: TextStyle(
                      color: context.textTertiary,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSeeding ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSeeding ? null : _seedUsers,
          child: _isSeeding
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Seed Users'),
        ),
      ],
    );
  }

  Future<void> _seedUsers() async {
    setState(() {
      _isSeeding = true;
      _log.clear();
    });

    try {
      final batch = widget.firestore.batch();

      for (final user in _dummyUsers) {
        final userId = user['id'] as String;
        final displayName = user['displayName'] as String;
        final callsign = user['callsign'] as String;
        setState(() => _status = 'Creating $displayName...');
        _log.add('+ $displayName');

        // Create profile document
        final profileRef = widget.firestore.collection('profiles').doc(userId);
        batch.set(profileRef, {
          'displayName': displayName,
          'displayNameLower': displayName.toLowerCase(),
          'bio': user['bio'],
          'callsign': callsign,
          'callsignLower': callsign.toLowerCase(),
          'isPrivate': user['isPrivate'],
          'isVerified': user['isVerified'],
          'followerCount': 0,
          'followingCount': 0,
          'postCount': 0,
          'linkedNodeIds': <int>[],
          'createdAt': FieldValue.serverTimestamp(),
        });

        await Future.delayed(const Duration(milliseconds: 100));
      }

      setState(() => _status = 'Committing batch...');
      await batch.commit();

      _log.add('');
      _log.add('✓ All users created successfully!');
      setState(() {
        _isSeeding = false;
        _status = 'Done!';
      });

      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.pop(context);
        showSuccessSnackBar(
          context,
          'Seeded ${_dummyUsers.length} dummy users',
        );
      }
    } catch (e) {
      _log.add('');
      _log.add('✗ Error: $e');
      setState(() {
        _isSeeding = false;
        _status = 'Error: $e';
      });
    }
  }
}
