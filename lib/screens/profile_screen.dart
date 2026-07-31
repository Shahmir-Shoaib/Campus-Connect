import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _userData;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No user is signed in.';
        _isLoading = false;
      });
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!mounted) return;
      setState(() {
        _userId = currentUser.uid;
        _userData = userDoc.data() ?? {};
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load profile.';
        _isLoading = false;
      });
    }
  }

  Future<void> _editName() async {
    if (_userData == null || _userId == null) return;

    final controller = TextEditingController(
      text: (_userData!['name'] as String?) ?? '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Name'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Enter your name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved != true) return;

    final newName = controller.text.trim();
    if (newName.isEmpty) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(_userId).update({
        'name': newName,
      });
      if (!mounted) return;
      setState(() {
        _userData!['name'] = newName;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Name updated. This does not update your past posts postedByName.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save name: ${e.toString()}')),
      );
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
    if (category.isEmpty) return '';
    return category.replaceFirst(category[0], category[0].toUpperCase());
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
    }
    return postTime.toString().split(' ')[0];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : _buildProfileContent(),
    );
  }

  Widget _buildProfileContent() {
    if (_userData == null || _userId == null) {
      return const Center(child: Text('Unable to load profile.'));
    }

    final email = FirebaseAuth.instance.currentUser?.email ?? 'No email';
    final name = (_userData!['name'] as String?) ?? 'No name';
    final rollNumber = (_userData!['rollNumber'] as String?) ?? 'Not provided';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    email,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Roll number: $rollNumber',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _editName,
                    child: const Text('Edit Name'),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .where('postedBy', isEqualTo: _userId)
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading posts: ${snapshot.error}'),
                );
              }

              final documents = snapshot.data?.docs ?? [];
              if (documents.isEmpty) {
                return const Center(
                  child: Text('You haven\'t posted anything yet'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: documents.length,
                itemBuilder: (context, index) {
                  return _buildUserPostCard(documents[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserPostCard(QueryDocumentSnapshot doc) {
    final post = doc.data() as Map<String, dynamic>;
    final title = post['title'] as String? ?? '';
    final description = post['description'] as String? ?? '';
    final type = post['type'] as String? ?? 'unknown';
    final category = post['category'] as String? ?? 'general';
    final resolved = post['resolved'] as bool? ?? false;
    final timestamp = post['timestamp'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(
                    type == 'announcement' ? 'Announcement' : 'Lost & Found',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: type == 'announcement'
                      ? Colors.orange
                      : Colors.deepOrange,
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    _getCategoryLabel(category),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: _getCategoryColor(category),
                ),
                if (type == 'lost_found' && resolved)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Chip(
                      label: const Text(
                        'Resolved',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      backgroundColor: Colors.grey[600],
                    ),
                  ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete this post permanently?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed != true) return;
                    try {
                      await doc.reference.delete();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Post deleted successfully'),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to delete post: ${e.toString()}',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            Text(
              _getRelativeTime(timestamp),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
