import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import 'chat_service.dart';
import 'chat_screen.dart';
import 'user_list_page.dart';
import 'package:halo/Bottom%20Pages/HomePage.dart';

// THEME COLORS (reuse Halo theme where possible)
const Color kPrimaryColor = Color(0xFFA58CE3); // Lavender
const Color kSecondaryColor = Color(0xFF5B3FA3); // Deep Purple
const Color kBackgroundColor = Color(0xFFF4F1FB); // Light lavender-gray

class ChatListPage extends StatefulWidget {
  final String currentUserId; // logged-in userId

  const ChatListPage({Key? key, required this.currentUserId}) : super(key: key);

  @override
  _ChatListPageState createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final ChatService _chatService = ChatService();
  final Map<String, Map<String, dynamic>?> _userCache = {};
  final Map<String, int> _unreadCountCache = {};
  String _lastChatSnapshotKey = '';

  Future<void> _syncChatRowData(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> chats) async {
    final userIds = <String>{};
    final chatIds = <String>[];

    for (final chatDoc in chats) {
      final chat = chatDoc.data();
      final members = List<String>.from(chat['members'] ?? const []);
      final otherUserId = members.firstWhere(
        (id) => id != widget.currentUserId,
        orElse: () => '',
      );
      if (otherUserId.isNotEmpty) userIds.add(otherUserId);
      chatIds.add(chatDoc.id);
    }

    try {
      final missingUserIds =
          userIds.where((id) => !_userCache.containsKey(id)).toList();
      if (missingUserIds.isNotEmpty) {
        final loadedUsers = await Future.wait(
          missingUserIds.map((id) async {
            final doc =
                await FirebaseFirestore.instance.collection('users').doc(id).get();
            return MapEntry<String, Map<String, dynamic>?>(
              id,
              doc.exists ? doc.data() : null,
            );
          }),
        );
        for (final entry in loadedUsers) {
          _userCache[entry.key] = entry.value;
        }
      }

      final unreadResults = await Future.wait(
        chatIds.map((chatId) async {
          final snap = await FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .where('receiverId', isEqualTo: widget.currentUserId)
              .where('seen', isEqualTo: false)
              .count()
              .get();
          return MapEntry(chatId, snap.count ?? 0);
        }),
      );
      for (final entry in unreadResults) {
        _unreadCountCache[entry.key] = entry.value;
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("❌ Error syncing chat list data: $e");
    }
  }

  /// 🔹 Format time like WhatsApp-ish (e.g., "09:30" / "Yesterday" / "12 Jan")
  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate().toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) {
      // just time
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    } else if (today.difference(date).inDays == 1) {
      return 'Yesterday';
    } else {
      // dd/MM
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      return '$dd/$mm';
    }
  }

  /// 🔹 Delete chat + its messages subcollection
  Future<void> _deleteChatWithMessages(String chatId) async {
    try {
      final messagesRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages');

      final messagesSnap = await messagesRef.get();
      final batch = FirebaseFirestore.instance.batch();

      for (var doc in messagesSnap.docs) {
        batch.delete(doc.reference);
      }

      batch.delete(
          FirebaseFirestore.instance.collection('chats').doc(chatId));

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting chat: $e')),
      );
    }
  }

  void _showChatActionsBottomSheet(String chatId, Map<String, dynamic>? otherUser) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(
                  otherUser?['name'] ??
                      otherUser?['username'] ??
                      'Open profile',
                ),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: open profile page if you want
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_off_outlined),
                title: const Text('Mute (coming soon)'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Mute feature coming soon!')),
                  );
                },
              ),
              ListTile(
                leading:
                const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete chat',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete chat?'),
                      content: const Text(
                          'This will delete all messages in this chat.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _deleteChatWithMessages(chatId);
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme(
      Theme.of(context).textTheme,
    );

    return Theme(
      data: Theme.of(context).copyWith(textTheme: textTheme),
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => HomePage()),
              );
            },
          ),
          title: Text(
            "Halo Chats",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () {
                // TODO: optional chat search
              },
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                // TODO: menu for settings
              },
            ),
          ],
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
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF5EDFF),
                Color(0xFFE8E4FF),
                kBackgroundColor,
              ],
            ),
          ),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _chatService.getUserChats(widget.currentUserId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    "No chats yet.\nTap the button to start a new chat.",
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                );
              }

              // Sort client-side by updatedAt desc, with nulls last
              final chats = [...snapshot.data!.docs];
              chats.sort((a, b) {
                final aTs = (a.data()['updatedAt'] as Timestamp?);
                final bTs = (b.data()['updatedAt'] as Timestamp?);
                final aMs = aTs?.millisecondsSinceEpoch ?? 0;
                final bMs = bTs?.millisecondsSinceEpoch ?? 0;
                return bMs.compareTo(aMs);
              });
              final snapshotKey = chats
                  .map((d) =>
                      '${d.id}:${(d.data()['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0}')
                  .join('|');
              if (_lastChatSnapshotKey != snapshotKey) {
                _lastChatSnapshotKey = snapshotKey;
                _syncChatRowData(chats);
              }

              return ListView.builder(
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  final chatDoc = chats[index];
                  final chat = chatDoc.data();
                  final chatId = chatDoc.id;
                  final members = List<String>.from(chat['members']);

                  // find the other user
                  final otherUserId = members.firstWhere(
                        (id) => id != widget.currentUserId,
                    orElse: () => "Unknown",
                  );
                  final otherUser = _userCache[otherUserId];
                  final isOnline = (otherUser?['isOnline'] as bool?) ?? false;
                  final lastMessage = (chat['lastMessage'] ?? '').toString();
                  final isTyping = (chat['typingUserId'] ?? '') == otherUserId;
                  final unreadCount = _unreadCountCache[chatId] ?? 0;
                  final hasUnread = unreadCount > 0;
                  final updatedAt = chat['updatedAt'] as Timestamp?;
                  final timeLabel = _formatTime(updatedAt);

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
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                chatId: chatId,
                                currentUserId: widget.currentUserId,
                                otherUserId: otherUserId,
                              ),
                            ),
                          );
                        },
                        onLongPress: () =>
                            _showChatActionsBottomSheet(chatId, otherUser),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10.0, vertical: 8.0),
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundImage: otherUser?['photoURL'] != null &&
                                            (otherUser!['photoURL'] as String).isNotEmpty
                                        ? NetworkImage(otherUser['photoURL'])
                                        : const AssetImage('assets/images/Profile.png')
                                            as ImageProvider,
                                    child: (otherUser?['photoURL'] == null ||
                                            (otherUser!['photoURL'] as String).isEmpty)
                                        ? const Icon(Icons.person)
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            otherUser?['name'] ??
                                                otherUser?['username'] ??
                                                'Unknown User',
                                            overflow: TextOverflow.ellipsis,
                                            style: textTheme.bodyLarge?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    if (isTyping)
                                      Text(
                                        'typing…',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: Colors.green[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      )
                                    else
                                      Text(
                                        lastMessage,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.bodySmall?.copyWith(
                                          fontWeight: hasUnread
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: hasUnread
                                              ? Colors.black
                                              : Colors.grey[700],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (timeLabel.isNotEmpty)
                                    Text(
                                      timeLabel,
                                      style: textTheme.labelSmall?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  const SizedBox(height: 6),
                                  if (hasUnread)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.teal,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        "$unreadCount",
                                        style: textTheme.labelSmall?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
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

        // 👇 Floating button to go to UserListPage
        floatingActionButton: FloatingActionButton(
          backgroundColor: kSecondaryColor,
          child: const Icon(Icons.chat_bubble_outline_rounded),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    UserListPage(currentUserId: widget.currentUserId),
              ),
            );
          },
        ),
      ),
    );
  }
}
