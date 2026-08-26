import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'chat_service.dart';
import 'chat_screen.dart';

import 'package:halo/core/halo_toast.dart';
// Reuse Halo chat colors
const Color kPrimaryColor = Color(0xFFA58CE3); // Lavender
const Color kSecondaryColor = Color(0xFF5B3FA3); // Deep Purple
const Color kBackgroundColor = Color(0xFFF4F1FB); // Light lavender-gray;

class UserListPage extends StatefulWidget {
  final String currentUserId;

  const UserListPage({
    Key? key,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();

  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showComingSoon(String feature) {
    HaloToast.show('$feature coming soon!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "New chat",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kSecondaryColor, kPrimaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5EDFF), Color(0xFFE8E4FF), kBackgroundColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔍 Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 16,
                      spreadRadius: -8,
                      offset: const Offset(0, 8),
                      color: Colors.black.withOpacity(0.08),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search by name or username',
                    border: InputBorder.none,
                    contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),

            // 🔹 New group row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Material(
                color: Colors.white.withOpacity(0.96),
                borderRadius: BorderRadius.circular(18),
                elevation: 1.5,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    _showComingSoon('Group chats');
                    // Later: open a multi-select "New group" page.
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 10.0,
                    ),
                    child: Row(
                      children: const [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: kSecondaryColor,
                          child: Icon(
                            Icons.group_rounded,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'New group',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // 🔹 Invite friends row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Material(
                color: Colors.white.withOpacity(0.96),
                borderRadius: BorderRadius.circular(18),
                elevation: 1.5,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    _showComingSoon('Invite friends');
                    // Later: integrate share_plus to share app link.
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 10.0,
                    ),
                    child: Row(
                      children: const [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: kPrimaryColor,
                          child: Icon(
                            Icons.person_add_rounded,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Invite friends',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Section label: Contacts on Halo
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Contacts on Halo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ),
            const SizedBox(height: 4),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No users found'),
                    );
                  }

                  // Filter out current user & apply search
                  final allDocs = snapshot.data!.docs;
                  final filtered = allDocs.where((doc) {
                    if (doc.id == widget.currentUserId) return false;

                    final data = doc.data();
                    final username =
                    (data['username'] ?? '').toString().toLowerCase();
                    final name =
                    (data['name'] ?? '').toString().toLowerCase();
                    final email =
                    (data['email'] ?? '').toString().toLowerCase();

                    if (_query.isEmpty) return true;

                    return username.contains(_query) ||
                        name.contains(_query) ||
                        email.contains(_query);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('No matching users'),
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final doc = filtered[index];
                      final data = doc.data();
                      final userId = doc.id;

                      final username = (data['username'] ?? '').toString();
                      final displayName =
                      (data['name'] ?? username).toString();
                      final email = (data['email'] ?? '').toString();
                      final avatarUrl = (data['photoURL'] ?? '').toString();

                      DateTime? lastSeen;
                      if (data['lastSeen'] != null &&
                          data['lastSeen'] is Timestamp) {
                        lastSeen =
                            (data['lastSeen'] as Timestamp).toDate();
                      }
                      final isOnline =
                          (data['isOnline'] as bool?) ?? false;

                      final initials = (displayName.isNotEmpty
                          ? displayName[0]
                          : (username.isNotEmpty ? username[0] : 'U'))
                          .toUpperCase();

                      String statusText;
                      if (isOnline) {
                        statusText = 'Online';
                      } else if (lastSeen != null) {
                        statusText = 'Last seen ${_formatAgo(lastSeen)}';
                      } else if (email.isNotEmpty) {
                        statusText = email;
                      } else if (username.isNotEmpty) {
                        statusText = '@$username';
                      } else {
                        statusText = '';
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        child: Material(
                          color: Colors.white.withOpacity(0.96),
                          borderRadius: BorderRadius.circular(18),
                          elevation: 1.5,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () async {
                              final chatId =
                              await _chatService.getOrCreateChatId(
                                widget.currentUserId,
                                userId,
                              );

                              if (!context.mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    chatId: chatId,
                                    currentUserId: widget.currentUserId,
                                    otherUserId: userId,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0, vertical: 10.0),
                              child: Row(
                                children: [
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundImage: avatarUrl.isNotEmpty
                                            ? NetworkImage(avatarUrl)
                                            : null,
                                        backgroundColor: avatarUrl.isEmpty
                                            ? kSecondaryColor
                                            : null,
                                        child: avatarUrl.isEmpty
                                            ? Text(
                                          initials,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight:
                                            FontWeight.w600,
                                          ),
                                        )
                                            : null,
                                      ),
                                      if (isOnline)
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 11,
                                            height: 11,
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName.isNotEmpty
                                              ? displayName
                                              : (username.isNotEmpty
                                              ? '@$username'
                                              : 'Unknown User'),
                                          maxLines: 1,
                                          overflow:
                                          TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        if (statusText.isNotEmpty)
                                          Text(
                                            statusText,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
