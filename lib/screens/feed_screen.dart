import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'post_screen.dart';
import 'login_screen.dart';
import 'admin_stats_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  bool _isAdmin = false;

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

            return TabBarView(
              children: [
                // Tab 0: All posts
                _buildPostList(
                  context,
                  allPosts,
                  'No posts yet',
                  'Be the first to create a post!',
                ),
                // Tab 1: Announcements only
                _buildPostList(
                  context,
                  allPosts
                      .where(
                        (doc) =>
                            (doc.data() as Map<String, dynamic>)['type'] ==
                            'announcement',
                      )
                      .toList(),
                  'No announcements yet',
                  'Check back later for updates',
                ),
                // Tab 2: Lost & Found only
                _buildPostList(
                  context,
                  allPosts
                      .where(
                        (doc) =>
                            (doc.data() as Map<String, dynamic>)['type'] ==
                            'lost_found',
                      )
                      .toList(),
                  'No lost or found items yet',
                  'Report a lost or found item to get started',
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.post_add, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              emptyTitle,
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(emptySubtitle, style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Center(
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
            final postedByName = post['postedByName'] as String? ?? 'Anonymous';
            final postedBy = post['postedBy'] as String? ?? '';
            final resolved = post['resolved'] as bool? ?? false;
            final currentUserId = FirebaseAuth.instance.currentUser?.uid;
            final isCurrentUserPoster = postedBy == currentUserId;
            final isLostFound = type == 'lost_found';

            // Determine opacity: resolved posts get 0.6, unresolved get 1.0
            final cardOpacity = resolved ? 0.6 : 1.0;

            return Opacity(
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
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Post deleted successfully',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
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
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: ${e.toString()}'),
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
            );
          },
        ),
      ),
    );
  }
}
