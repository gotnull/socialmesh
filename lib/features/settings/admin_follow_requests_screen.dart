import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../core/constants.dart';
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
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    showDialog(
      context: context,
      builder: (context) =>
          _SeedUsersDialog(firestore: _firestore, currentUserId: currentUserId),
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
  const _SeedUsersDialog({required this.firestore, this.currentUserId});

  final FirebaseFirestore firestore;
  final String? currentUserId;

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

  // Sample posts for each user
  static const _samplePosts = [
    {
      'authorId': 'dummy_user_alice',
      'content':
          'Just set up my first solar-powered mesh node on the mountain! 🏔️ Getting great coverage over the valley. #offgrid #meshtastic',
    },
    {
      'authorId': 'dummy_user_alice',
      'content':
          'Pro tip: Elevate your antennas! Even 3 meters higher can double your range in hilly terrain.',
    },
    {
      'authorId': 'dummy_user_bob',
      'content':
          'Finished my DIY weatherproof enclosure for the T-Beam. 3D printed with PETG and sealed with silicone. Works great!',
    },
    {
      'authorId': 'dummy_user_bob',
      'content':
          'Anyone else testing the new firmware update? Seeing improved battery life on my RAK nodes.',
    },
    {
      'authorId': 'dummy_user_carol',
      'content':
          'Had an amazing QSO today - mesh message relayed through 5 nodes over 47km! The power of community networks. 📡',
    },
    {
      'authorId': 'dummy_user_dave',
      'content':
          'Teaching emergency communication at the community center this weekend. Mesh networks are perfect for disaster preparedness!',
    },
    {
      'authorId': 'dummy_user_dave',
      'content':
          'Remember: In an emergency, your mesh network might be the only way to communicate. Keep those nodes charged! 🔋',
    },
    {
      'authorId': 'dummy_user_eve',
      'content':
          'Love that mesh networks work without any central infrastructure. True peer-to-peer communication. Privacy by design. 🔐',
    },
    {
      'authorId': 'dummy_user_frank',
      'content':
          'Used the mesh network on today\'s SAR mission. Invaluable for team coordination in areas with no cell coverage. 🚁',
    },
    {
      'authorId': 'dummy_user_frank',
      'content':
          'Setting up permanent nodes at all our mountain huts. This will revolutionize backcountry communication.',
    },
    {
      'authorId': 'dummy_user_grace',
      'content':
          'My solar node has been running for 6 months straight now! 100W panel + 50Ah battery = unlimited mesh. ☀️',
    },
    {
      'authorId': 'dummy_user_grace',
      'content':
          'New project: Building a mesh-connected weather station. Will share temperature, humidity, and barometric pressure.',
    },
    {
      'authorId': 'dummy_user_henry',
      'content':
          'Just completed my DIY Yagi antenna build. 12dBi gain! Range increased significantly. Build guide coming soon.',
    },
    {
      'authorId': 'dummy_user_henry',
      'content':
          'Prototyping a mesh-enabled sensor network for my greenhouse. Soil moisture + temp readings over LoRa. 🌱',
    },
  ];

  // Sample comments
  static const _sampleComments = [
    {
      'content': 'Awesome setup! What panel are you using?',
      'authorId': 'dummy_user_bob',
    },
    {
      'content': 'This is inspiring! Might try something similar.',
      'authorId': 'dummy_user_carol',
    },
    {
      'content': 'Great work! The community needs more nodes like this.',
      'authorId': 'dummy_user_dave',
    },
    {'content': '🔥 Love it!', 'authorId': 'dummy_user_eve'},
    {
      'content': 'What\'s the battery life like?',
      'authorId': 'dummy_user_frank',
    },
    {
      'content': 'Impressive range! What antenna are you using?',
      'authorId': 'dummy_user_grace',
    },
    {
      'content': 'Nice! Can you share more details on the build?',
      'authorId': 'dummy_user_henry',
    },
    {
      'content': 'Thanks for sharing! Very helpful.',
      'authorId': 'dummy_user_alice',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.card,
      title: Text(
        'Seed Test Data',
        style: TextStyle(color: context.textPrimary),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will create test data for the social features:',
              style: TextStyle(color: context.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              '• ${_dummyUsers.length} dummy profiles\n'
              '• ${_samplePosts.length} posts with content\n'
              '• ~${_sampleComments.length * 2} comments',
              style: TextStyle(color: context.textSecondary, fontSize: 13),
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
                      fontFamily: AppTheme.fontFamily,
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
        OutlinedButton(
          onPressed: _isSeeding ? null : _resetAndSeed,
          child: _isSeeding
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Reset & Seed'),
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
              : const Text('Seed Data'),
        ),
      ],
    );
  }

  Future<void> _resetAndSeed() async {
    setState(() {
      _isSeeding = true;
      _log.clear();
    });

    try {
      // Step 1: Delete all dummy user data
      _log.add('🗑️ Cleaning up existing dummy data...');
      setState(() => _status = 'Deleting dummy data...');

      // Get all dummy user IDs
      final dummyUserIds = _dummyUsers.map((u) => u['id'] as String).toList();

      // Delete comments by dummy users
      _log.add('  Deleting comments...');
      final commentsQuery = await widget.firestore
          .collection('comments')
          .where('authorId', whereIn: dummyUserIds)
          .get();
      for (final doc in commentsQuery.docs) {
        await doc.reference.delete();
      }
      _log.add('  ✓ Deleted ${commentsQuery.docs.length} comments');

      // Delete posts by dummy users
      _log.add('  Deleting posts...');
      final postsQuery = await widget.firestore
          .collection('posts')
          .where('authorId', whereIn: dummyUserIds)
          .get();
      for (final doc in postsQuery.docs) {
        await doc.reference.delete();
      }
      _log.add('  ✓ Deleted ${postsQuery.docs.length} posts');

      // Delete follow requests involving dummy users (as requester)
      _log.add('  Deleting follow requests...');
      final followRequestsQuery = await widget.firestore
          .collection('follow_requests')
          .where('requesterId', whereIn: dummyUserIds)
          .get();
      for (final doc in followRequestsQuery.docs) {
        await doc.reference.delete();
      }
      // Also delete requests targeting dummy users
      final followRequestsTargetQuery = await widget.firestore
          .collection('follow_requests')
          .where('targetId', whereIn: dummyUserIds)
          .get();
      for (final doc in followRequestsTargetQuery.docs) {
        await doc.reference.delete();
      }
      _log.add(
        '  ✓ Deleted ${followRequestsQuery.docs.length + followRequestsTargetQuery.docs.length} follow requests',
      );

      // Delete follows involving dummy users
      _log.add('  Deleting follows...');
      final followsQuery = await widget.firestore
          .collection('follows')
          .where('followerId', whereIn: dummyUserIds)
          .get();
      for (final doc in followsQuery.docs) {
        await doc.reference.delete();
      }
      final followsTargetQuery = await widget.firestore
          .collection('follows')
          .where('followingId', whereIn: dummyUserIds)
          .get();
      for (final doc in followsTargetQuery.docs) {
        await doc.reference.delete();
      }
      _log.add(
        '  ✓ Deleted ${followsQuery.docs.length + followsTargetQuery.docs.length} follows',
      );

      // Reset current user's follow counts and delete their follows
      if (widget.currentUserId != null) {
        _log.add('  Resetting your follow data...');

        // Delete all follows where current user is follower
        final myFollowsQuery = await widget.firestore
            .collection('follows')
            .where('followerId', isEqualTo: widget.currentUserId)
            .get();
        for (final doc in myFollowsQuery.docs) {
          await doc.reference.delete();
        }

        // Delete all follows where current user is being followed
        final myFollowersQuery = await widget.firestore
            .collection('follows')
            .where('followingId', isEqualTo: widget.currentUserId)
            .get();
        for (final doc in myFollowersQuery.docs) {
          await doc.reference.delete();
        }

        // Reset counts on current user's profile
        await widget.firestore
            .collection('profiles')
            .doc(widget.currentUserId)
            .update({'followerCount': 0, 'followingCount': 0});

        _log.add(
          '  ✓ Deleted ${myFollowsQuery.docs.length + myFollowersQuery.docs.length} of your follows, reset counts',
        );
      }

      // Delete dummy user profiles
      _log.add('  Deleting profiles...');
      for (final userId in dummyUserIds) {
        final profileRef = widget.firestore.collection('profiles').doc(userId);
        final profileDoc = await profileRef.get();
        if (profileDoc.exists) {
          await profileRef.delete();
        }
      }
      _log.add('  ✓ Deleted ${dummyUserIds.length} profiles');

      _log.add('');
      _log.add('✓ Cleanup complete!');
      _log.add('');

      // Step 2: Now seed fresh data
      await _doSeed();
    } catch (e) {
      _log.add('');
      _log.add('✗ Error: $e');
      setState(() {
        _isSeeding = false;
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _seedUsers() async {
    setState(() {
      _isSeeding = true;
      _log.clear();
    });

    await _doSeed();
  }

  Future<void> _doSeed() async {
    try {
      // Step 1: Create users
      final userBatch = widget.firestore.batch();

      for (final user in _dummyUsers) {
        final userId = user['id'] as String;
        final displayName = user['displayName'] as String;
        final callsign = user['callsign'] as String;
        setState(() => _status = 'Creating $displayName...');
        _log.add('+ $displayName');

        // Create profile document
        // Note: postCount starts at 0 - Cloud Functions will increment when posts are created
        final profileRef = widget.firestore.collection('profiles').doc(userId);
        userBatch.set(profileRef, {
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

        await Future.delayed(const Duration(milliseconds: 50));
      }

      setState(() => _status = 'Committing users...');
      await userBatch.commit();
      _log.add('');
      _log.add('✓ ${_dummyUsers.length} users created');

      // Step 2: Create posts
      setState(() => _status = 'Creating posts...');
      _log.add('');
      _log.add('Creating posts...');
      final postIds = <String>[];

      for (var i = 0; i < _samplePosts.length; i++) {
        final post = _samplePosts[i];
        final authorId = post['authorId'] as String;
        final content = post['content'] as String;

        // Get author snapshot
        final author = _dummyUsers.firstWhere((u) => u['id'] == authorId);

        final postRef = widget.firestore.collection('posts').doc();
        postIds.add(postRef.id);

        // Don't set fake counts - Cloud Functions will calculate from actual data
        // We'll call recalculateAllCounts at the end

        try {
          await postRef.set({
            'authorId': authorId,
            'content': content,
            'mediaUrls': <String>[],
            'createdAt': Timestamp.fromDate(
              DateTime.now().subtract(Duration(hours: _samplePosts.length - i)),
            ),
            'commentCount': 0, // Will be recalculated
            'likeCount': 0, // Will be recalculated
            'authorSnapshot': {
              'displayName': author['displayName'],
              'callsign': author['callsign'],
              'avatarUrl': null,
              'isVerified': author['isVerified'],
            },
          });
          _log.add(
            '+ Post ${i + 1}: ${content.substring(0, content.length.clamp(0, 30))}...',
          );
        } catch (e) {
          _log.add('✗ Post ${i + 1} failed: $e');
        }

        setState(
          () => _status = 'Creating post ${i + 1}/${_samplePosts.length}...',
        );
        await Future.delayed(const Duration(milliseconds: 50));
      }

      _log.add('✓ ${_samplePosts.length} posts created');

      // Step 3: Create comments on posts
      setState(() => _status = 'Creating comments...');
      _log.add('');
      _log.add('Creating comments...');
      var commentCount = 0;

      for (var postIndex = 0; postIndex < postIds.length; postIndex++) {
        final postId = postIds[postIndex];

        // Add 2 comments per post
        const commentsToAdd = 2;

        for (
          var c = 0;
          c < commentsToAdd && commentCount < _sampleComments.length * 2;
          c++
        ) {
          final commentTemplate =
              _sampleComments[commentCount % _sampleComments.length];

          // Don't let user comment on their own post
          final postAuthorId = _samplePosts[postIndex]['authorId'];
          var commentAuthorId = commentTemplate['authorId'] as String;
          if (commentAuthorId == postAuthorId) {
            // Pick a different commenter
            final otherCommenters = _dummyUsers
                .where((u) => u['id'] != postAuthorId)
                .toList();
            commentAuthorId =
                otherCommenters[commentCount % otherCommenters.length]['id']
                    as String;
          }

          final commentRef = widget.firestore.collection('comments').doc();
          try {
            await commentRef.set({
              'postId': postId,
              'authorId': commentAuthorId,
              'parentId': null, // Root comment
              'content': commentTemplate['content'],
              'createdAt': Timestamp.fromDate(
                DateTime.now().subtract(
                  Duration(hours: _samplePosts.length - postIndex - 1),
                ),
              ),
              'replyCount': 0,
              'likeCount': commentCount % 5,
            });
          } catch (e) {
            _log.add('✗ Comment failed: $e');
          }

          commentCount++;
          await Future.delayed(const Duration(milliseconds: 30));
        }
      }

      _log.add('✓ $commentCount comments created');
      _log.add('');

      // Step 4: Recalculate all counts from actual data
      setState(() => _status = 'Recalculating counts...');
      _log.add('Recalculating counts from actual data...');
      try {
        final user = FirebaseAuth.instance.currentUser;
        final token = await user?.getIdToken();

        final response = await http.post(
          Uri.parse('${AppUrls.cloudFunctionsUrl}/recalculateAllCounts'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'data': {}}),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final result = data['result'] as Map<String, dynamic>?;
          if (result != null) {
            _log.add(
              '  ✓ Fixed ${result['postsFixed']} posts, ${result['profilesFixed']} profiles',
            );
          } else {
            _log.add('  ✓ Counts recalculated');
          }
        } else {
          _log.add('  ⚠ Server returned ${response.statusCode}');
        }
      } catch (e) {
        _log.add('  ⚠ Could not recalculate counts: $e');
        _log.add('  (Deploy functions and try again)');
      }

      _log.add('');
      _log.add('✓ All data seeded successfully!');

      setState(() {
        _isSeeding = false;
        _status = 'Done!';
      });

      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.pop(context);
        showSuccessSnackBar(
          context,
          'Seeded ${_dummyUsers.length} users, ${_samplePosts.length} posts, $commentCount comments',
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
