import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'post_screen.dart';
import 'post_detail_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'admin_stats_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  bool _isAdmin = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortOrder = 'newest';

  @override
  void initState() {
    super.initState();
    _checkIsAdmin();
  }

  Future<void> _checkIsAdmin() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!mounted) return;
      final role = userDoc.data()?['role'] as String?;
      setState(() {
        _isAdmin = role == 'admin';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAdmin = false;
      });
    }
  }

  bool _matchesSearch(Map<String, dynamic> post) {
    if (_searchQuery.isEmpty) return true;
    final title = (post['title'] as String?)?.toLowerCase() ?? '';
    final description = (post['description'] as String?)?.toLowerCase() ?? '';
    return title.contains(_searchQuery) || description.contains(_searchQuery);
  }

  List<QueryDocumentSnapshot> _filterPosts(
    List<QueryDocumentSnapshot> posts, {
    String? type,
  }) {
    return posts.where((doc) {
      final post = doc.data() as Map<String, dynamic>;
      final matchesType = type == null || post['type'] == type;
      return matchesType && _matchesSearch(post);
    }).toList();
  }

  List<QueryDocumentSnapshot> _sortPosts(List<QueryDocumentSnapshot> posts) {
    final sortedPosts = List<QueryDocumentSnapshot>.from(posts);
    sortedPosts.sort((a, b) {
      final aTimestamp =
          (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
      final bTimestamp =
          (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
      final aMillis = aTimestamp?.millisecondsSinceEpoch ?? 0;
      final bMillis = bTimestamp?.millisecondsSinceEpoch ?? 0;
      if (_sortOrder == 'newest') {
        return bMillis.compareTo(aMillis);
      }
      return aMillis.compareTo(bMillis);
    });
    return sortedPosts;
  }

  String _getRelativeTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';

    final now = DateTime.now();
    final postTime = timestamp.toDate();
    final difference = now.difference(postTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return postTime.toString().split(' ')[0];
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'academic':
        return Colors.blue;
      case 'event':
        return Colors.purple;
      case 'general':
        return Colors.grey;
      case 'lost':
        return Colors.red;
      case 'found':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  String _getCategoryLabel(String category) {
    return category.replaceFirst(category[0], category[0].toUpperCase());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Feed'),
          actions: [
            if (_isAdmin)
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminStatsScreen()),
                  );
                },
                icon: const Icon(Icons.bar_chart),
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              initialValue: _sortOrder,
              onSelected: (value) {
                setState(() {
                  _sortOrder = value;
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'newest',
                  child: Text('Newest first'),
                ),
                const PopupMenuItem(
                  value: 'oldest',
                  child: Text('Oldest first'),
                ),
              ],
            ),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              icon: const Icon(Icons.person),
            ),
            IconButton(
              onPressed: () => _handleLogout(context),
              icon: const Icon(Icons.logout),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Announcements'),
              Tab(text: 'Lost & Found'),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final allPosts = snapshot.data?.docs ?? [];
            final sortedPosts = _sortPosts(allPosts);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase().trim();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search posts',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Tab 0: All posts
                      _buildPostList(
                        context,
                        _filterPosts(sortedPosts),
                        'No posts yet',
                        'Be the first to create a post!',
                      ),
                      // Tab 1: Announcements only
                      _buildPostList(
                        context,
                        _filterPosts(sortedPosts, type: 'announcement'),
                        'No announcements yet',
                        'Check back later for updates',
                      ),
                      // Tab 2: Lost & Found only
                      _buildPostList(
                        context,
                        _filterPosts(sortedPosts, type: 'lost_found'),
                        'No lost or found items yet',
                        'Report a lost or found item to get started',
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PostScreen()),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildPostList(
    BuildContext context,
    List<QueryDocumentSnapshot> posts,
    String emptyTitle,
    String emptySubtitle,
  ) {
    if (posts.isEmpty) {
      final noResults = _searchQuery.isNotEmpty;
      return RefreshIndicator(
        onRefresh: () => Future.delayed(const Duration(milliseconds: 500)),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.post_add, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    noResults ? 'No results found' : emptyTitle,
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    noResults ? 'Try a different search term' : emptySubtitle,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => Future.delayed(const Duration(milliseconds: 500)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index].data() as Map<String, dynamic>;
              final timestamp = post['timestamp'] as Timestamp?;
              final type = post['type'] as String? ?? 'unknown';
              final category = post['category'] as String? ?? 'general';
              final title = post['title'] as String? ?? '';
              final description = post['description'] as String? ?? '';
              final postedByName =
                  post['postedByName'] as String? ?? 'Anonymous';
              final postedBy = post['postedBy'] as String? ?? '';
              final resolved = post['resolved'] as bool? ?? false;
              final currentUserId = FirebaseAuth.instance.currentUser?.uid;
              final isCurrentUserPoster = postedBy == currentUserId;
              final isLostFound = type == 'lost_found';
              final canReport =
                  currentUserId != null && !isCurrentUserPoster && !_isAdmin;

              // Determine opacity: resolved posts get 0.6, unresolved get 1.0
              final cardOpacity = resolved ? 0.6 : 1.0;

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PostDetailScreen(post: posts[index]),
                    ),
                  );
                },
                child: Opacity(
                  opacity: cardOpacity,
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Type and Category chips + Resolved badge
                          Row(
                            children: [
                              Chip(
                                label: Text(
                                  type == 'announcement'
                                      ? 'Announcement'
                                      : 'Lost & Found',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                                backgroundColor: type == 'announcement'
                                    ? Colors.orange
                                    : Colors.deepOrange,
                              ),
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(
                                  _getCategoryLabel(category),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                                backgroundColor: _getCategoryColor(category),
                              ),
                              if (isLostFound && resolved)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Chip(
                                    label: const Text(
                                      'Resolved',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                    backgroundColor: Colors.grey[600],
                                  ),
                                ),
                              if (canReport) ...[
                                const Spacer(),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (value) async {
                                    if (value != 'report') return;
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text(
                                          'Report this post as inappropriate?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Report'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmed != true) return;

                                    try {
                                      await posts[index].reference.update({
                                        'reported': true,
                                        'reportCount': FieldValue.increment(1),
                                      });
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Post reported. Moderators will review it.',
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Failed to report post: ${e.toString()}',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'report',
                                      child: Text('Report post'),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Title
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          // Description
                          Text(
                            description,
                            style: const TextStyle(fontSize: 14),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          // Footer with user and time
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                postedByName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _getRelativeTime(timestamp),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          // Admin delete button
                          if (_isAdmin)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text(
                                          'Delete this post permanently?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmed != true) return;

                                    try {
                                      await posts[index].reference.delete();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Post deleted successfully',
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error deleting post: ${e.toString()}',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                            ),
                          // "Mark as Resolved" button for lost_found posts
                          if (isLostFound && !resolved && isCurrentUserPoster)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () async {
                                    try {
                                      await posts[index].reference.update({
                                        'resolved': true,
                                      });
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error: ${e.toString()}',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: const Text('Mark as Resolved'),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
