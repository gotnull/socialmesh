import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/widgets/edge_fade.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../models/social.dart';

class AdminPostsScreen extends StatefulWidget {
  const AdminPostsScreen({super.key});

  @override
  State<AdminPostsScreen> createState() => _AdminPostsScreenState();
}

class _AdminPostsScreenState extends State<AdminPostsScreen> {
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  bool _showSignalsOnly = false;
  bool _showExpiredOnly = false;
  bool _showWithLocation = false;
  bool _showWithMedia = false;
  String _searchQuery = '';
  int _lastTotalCount = 0;
  int _lastFilteredCount = 0;
  List<DocumentReference> _filteredDocRefs = [];

  @override
  Widget build(BuildContext context) {
    final postsStream = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return GlassScaffold(
      title: 'Signals',
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_sweep_outlined),
          tooltip: 'Delete all signals',
          onPressed: () => _confirmBulkDelete(context),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_outlined),
          tooltip: 'Refresh snapshot',
          onPressed: () => setState(() {}),
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Filter by content or author ID',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value.trim()),
            ),
          ),
        ),
        SliverFillRemaining(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: postsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Failed to load posts: ${snapshot.error}',
                    style: TextStyle(color: context.textTertiary),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final now = DateTime.now();
              final allEntries = snapshot.data!.docs
                  .map((doc) => _PostEntry.fromSnapshot(doc))
                  .toList();
              final totalCount = allEntries.length;
              final signalCount = allEntries
                  .where((entry) => entry.post.postMode == PostMode.signal)
                  .length;
              final expiredCount = allEntries.where((entry) {
                final expiresAt = entry.post.expiresAt;
                return expiresAt != null && expiresAt.isBefore(now);
              }).length;
              final locationCount = allEntries
                  .where((entry) => entry.post.location != null)
                  .length;
              final mediaCount = allEntries
                  .where((entry) => entry.post.mediaUrls.isNotEmpty)
                  .length;

              final entries = allEntries.where((entry) {
                if (_showSignalsOnly &&
                    entry.post.postMode != PostMode.signal) {
                  return false;
                }
                if (_showExpiredOnly) {
                  final expiresAt = entry.post.expiresAt;
                  if (expiresAt == null || expiresAt.isAfter(now)) {
                    return false;
                  }
                }
                if (_searchQuery.isNotEmpty) {
                  final lower = _searchQuery.toLowerCase();
                  final matchesContent = entry.post.content
                      .toLowerCase()
                      .contains(lower);
                  final matchesAuthor = entry.post.authorId
                      .toLowerCase()
                      .contains(lower);
                  if (!matchesContent && !matchesAuthor) {
                    return false;
                  }
                }
                if (_showWithLocation && entry.post.location == null) {
                  return false;
                }
                if (_showWithMedia && entry.post.mediaUrls.isEmpty) {
                  return false;
                }
                return true;
              }).toList();
              _lastTotalCount = totalCount;
              _lastFilteredCount = entries.length;
              _filteredDocRefs = entries.map((entry) => entry.docRef).toList();

              if (entries.isEmpty) {
                return Center(
                  child: Text(
                    'No posts matched',
                    style: TextStyle(color: context.textSecondary),
                  ),
                );
              }

              return Column(
                children: [
                  SizedBox(
                    height: 44,
                    child: Row(
                      children: [
                        Expanded(
                          child: EdgeFade.end(
                            fadeSize: 32,
                            fadeColor: context.background,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.only(left: 16),
                              children: [
                                _AdminFilterChip(
                                  label: 'All',
                                  count: totalCount,
                                  isSelected:
                                      !_showSignalsOnly &&
                                      !_showExpiredOnly &&
                                      !_showWithLocation &&
                                      !_showWithMedia,
                                  onTap: () => setState(() {
                                    _showSignalsOnly = false;
                                    _showExpiredOnly = false;
                                    _showWithLocation = false;
                                    _showWithMedia = false;
                                  }),
                                ),
                                const SizedBox(width: 8),
                                _AdminFilterChip(
                                  label: 'Signals',
                                  count: signalCount,
                                  isSelected: _showSignalsOnly,
                                  color: AccentColors.cyan,
                                  onTap: () => setState(() {
                                    _showSignalsOnly = true;
                                    _showExpiredOnly = false;
                                  }),
                                ),
                                const SizedBox(width: 8),
                                _AdminFilterChip(
                                  label: 'Expired',
                                  count: expiredCount,
                                  isSelected: _showExpiredOnly,
                                  color: AppTheme.warningYellow,
                                  onTap: () => setState(() {
                                    _showSignalsOnly = false;
                                    _showExpiredOnly = true;
                                  }),
                                ),
                                const SizedBox(width: 8),
                                _AdminFilterChip(
                                  label: 'Location',
                                  count: locationCount,
                                  isSelected: _showWithLocation,
                                  color: AccentColors.green,
                                  onTap: () => setState(() {
                                    _showWithLocation = !_showWithLocation;
                                  }),
                                ),
                                const SizedBox(width: 8),
                                _AdminFilterChip(
                                  label: 'Media',
                                  count: mediaCount,
                                  isSelected: _showWithMedia,
                                  color: AccentColors.orange,
                                  onTap: () => setState(() {
                                    _showWithMedia = !_showWithMedia;
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 32,
                      ),
                      itemCount: entries.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return _AdminPostCard(
                          entry: entry,
                          dateFormat: _dateFormat,
                          onDelete: () => _confirmDelete(context, entry.docRef),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    DocumentReference docRef,
  ) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete post?'),
            content: const Text(
              'Deleting a post removes it from Firebase immediately. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    await docRef.delete();
  }

  Future<void> _confirmBulkDelete(BuildContext context) async {
    final hasFilters = _hasActiveFilters;
    final filteredCount = _lastFilteredCount;
    final totalCount = _lastTotalCount;
    final filteredRefs = List<DocumentReference>.from(_filteredDocRefs);

    final result = await showDialog<_DeleteScope>(
      context: context,
      builder: (context) {
        String input = '';
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Delete signals?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasFilters
                      ? 'Delete filtered ($filteredCount) or all ($totalCount) signals.'
                      : 'Delete all $totalCount signals.',
                ),
                const SizedBox(height: 12),
                Text(
                  'This cannot be undone. Type DELETE to confirm.',
                  style: TextStyle(color: context.textSecondary),
                ),
                const SizedBox(height: 8),
                TextField(
                  onChanged: (value) => setState(() => input = value.trim()),
                  decoration: const InputDecoration(hintText: 'DELETE'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
              if (hasFilters)
                TextButton(
                  onPressed: input == 'DELETE'
                      ? () => Navigator.of(context).pop(_DeleteScope.filtered)
                      : null,
                  child: Text('Delete filtered ($filteredCount)'),
                ),
              TextButton(
                onPressed: input == 'DELETE'
                    ? () => Navigator.of(context).pop(_DeleteScope.all)
                    : null,
                child: Text('Delete all ($totalCount)'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return;

    if (result == _DeleteScope.filtered) {
      if (filteredRefs.isEmpty) return;
      await _deleteDocs(filteredRefs);
      return;
    }

    await _deleteAllDocs();
  }

  bool get _hasActiveFilters =>
      _showSignalsOnly ||
      _showExpiredOnly ||
      _showWithLocation ||
      _showWithMedia ||
      _searchQuery.isNotEmpty;

  Future<void> _deleteDocs(List<DocumentReference> refs) async {
    const batchSize = 400;
    for (var i = 0; i < refs.length; i += batchSize) {
      final batch = FirebaseFirestore.instance.batch();
      final end = (i + batchSize).clamp(0, refs.length);
      for (final ref in refs.sublist(i, end)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteAllDocs() async {
    const pageSize = 400;
    final collection = FirebaseFirestore.instance.collection('posts');
    QuerySnapshot<Map<String, dynamic>> snapshot;

    do {
      snapshot = await collection.limit(pageSize).get();
      if (snapshot.docs.isEmpty) {
        break;
      }
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } while (snapshot.docs.length == pageSize);
  }
}

enum _DeleteScope { filtered, all }

class _PostEntry {
  _PostEntry({required this.post, required this.docRef});

  final Post post;
  final DocumentReference docRef;

  factory _PostEntry.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return _PostEntry(
      post: Post.fromFirestore(snapshot),
      docRef: snapshot.reference,
    );
  }
}

class _AdminPostCard extends StatelessWidget {
  const _AdminPostCard({
    required this.entry,
    required this.dateFormat,
    required this.onDelete,
  });

  final _PostEntry entry;
  final DateFormat dateFormat;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final post = entry.post;
    final hasMedia = post.mediaUrls.isNotEmpty;
    final expiresAt = post.expiresAt;
    final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PostMediaPreview(imageUrl: hasMedia ? post.mediaUrls.first : null),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.content.isNotEmpty ? post.content : '(no text)',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Author ${post.authorId}',
                  style: TextStyle(color: context.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _MetaPill(
                      label: post.postMode.name.toUpperCase(),
                      color: AccentColors.cyan,
                    ),
                    _MetaPill(
                      label: post.origin.name.toUpperCase(),
                      color: context.textSecondary,
                    ),
                    _MetaPill(
                      label: 'Created ${dateFormat.format(post.createdAt)}',
                      color: context.accentColor,
                    ),
                    if (expiresAt != null)
                      _MetaPill(
                        label: isExpired
                            ? 'Expired'
                            : 'Expires ${dateFormat.format(expiresAt)}',
                        color: isExpired
                            ? AppTheme.warningYellow
                            : AccentColors.orange,
                      ),
                    _MetaPill(
                      label: hasMedia
                          ? '${post.mediaUrls.length} media'
                          : 'No media',
                      color: context.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Comments ${post.commentCount} · Likes ${post.likeCount}',
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Delete post',
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.redAccent,
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PostMediaPreview extends StatelessWidget {
  const _PostMediaPreview({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 72,
        height: 72,
        color: context.cardAlt,
        child: imageUrl == null
            ? Icon(Icons.image_not_supported, color: context.textTertiary)
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.broken_image, color: context.textTertiary),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.accentColor,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _AdminFilterChip extends StatelessWidget {
  const _AdminFilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? context.accentColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withValues(alpha: 0.15) : context.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? chipColor.withValues(alpha: 0.4)
                : context.border.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? chipColor : context.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? chipColor.withValues(alpha: 0.2)
                    : context.border.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: isSelected ? chipColor : context.textTertiary,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
