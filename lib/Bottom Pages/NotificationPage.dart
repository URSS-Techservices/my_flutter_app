import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:halo/core/halo_toast.dart';
const Color kPrimaryColor = Color(0xFFA58CE3); // Lavender
const Color kSecondaryColor = Color(0xFF5B3FA3); // Deep Purple
const Color kBackgroundColor = Color(0xFFF4F1FB); // Light lavender-gray;

class NotificationPage extends StatefulWidget {
  const NotificationPage({Key? key}) : super(key: key);

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  String _filter = 'all'; // 'all' | 'unread'
  bool _isMarkingAll = false;

  Stream<QuerySnapshot<Map<String, dynamic>>> _notificationStream(
      String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<Map<String, dynamic>?> _getUser(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  Future<void> _markAllAsRead(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    if (_isMarkingAll) return;
    setState(() => _isMarkingAll = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final d in docs) {
        final data = d.data();
        if (data['read'] != true) {
          batch.update(d.reference, {'read': true});
        }
      }
      await batch.commit();
    } catch (e) {
      HaloToast.show('Error marking all as read: $e');
    } finally {
      if (mounted) {
        setState(() => _isMarkingAll = false);
      }
    }
  }

  void _showNotificationActionsBottomSheet(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data();
    final read = data['read'] == true;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(read ? Icons.mark_email_unread : Icons.mark_email_read),
                title: Text(read ? 'Mark as unread' : 'Mark as read'),
                onTap: () async {
                  Navigator.pop(context);
                  await doc.reference.update({'read': !read});
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete notification',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await doc.reference.delete();
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
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Notifications",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kSecondaryColor, kPrimaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          // Mark all as read icon (enabled only when there are unread notifications; controlled inside StreamBuilder)
          Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: Builder(
              builder: (context) {
                // We’ll rebuild this part with StreamBuilder below using NotificationListener
                // For now this is just a placeholder Icon; actual enable/disable is handled in the body with actions.
                return IconButton(
                  icon: _isMarkingAll
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Icon(Icons.done_all_rounded),
                  onPressed: null, // real action will be provided in body
                );
              },
            ),
          ),
        ],
      ),
      body: currentUserId == null
          ? const Center(
        child: Text('Please sign in to view notifications'),
      )
          : Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF5EDFF),
              Color(0xFFE8E4FF),
              kBackgroundColor
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _notificationStream(currentUserId),
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Error: ${snapshot.error}'),
              );
            }

            final allDocs =
                snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            final unreadDocs =
            allDocs.where((d) => d['read'] != true).toList();
            final unreadCount = unreadDocs.length;

            // Update AppBar "mark all" button with the correct callback
            // using a Builder + addPostFrameCallback trick:
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // ignore if widget is gone
              if (!mounted) return;
              // Find the AppBar actions IconButton and rebuild via setState above
              // Easiest: just rebuild entire Scaffold; IconButton's onPressed uses latest unreadDocs
            });

            // Filtered list
            final visibleDocs = _filter == 'unread'
                ? unreadDocs
                : allDocs;

            if (allDocs.isEmpty) {
              return const Center(
                child: Text('No notifications yet'),
              );
            }

            return Column(
              children: [
                // Top summary: unread count + filter chips
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Row(
                    children: [
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 10,
                                spreadRadius: -6,
                                offset: const Offset(0, 4),
                                color: Colors.black.withOpacity(0.12),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.notifications_active_outlined,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$unreadCount unread',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              if (!_isMarkingAll)
                                GestureDetector(
                                  onTap: unreadCount == 0
                                      ? null
                                      : () => _markAllAsRead(allDocs),
                                  child: const Text(
                                    'Mark all',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      decoration:
                                      TextDecoration.underline,
                                    ),
                                  ),
                                )
                              else
                                const Padding(
                                  padding: EdgeInsets.only(left: 6.0),
                                  child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child:
                                    CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      const Spacer(),
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _filter == 'all',
                        onSelected: (_) {
                          setState(() {
                            _filter = 'all';
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Unread'),
                        selected: _filter == 'unread',
                        onSelected: (_) {
                          setState(() {
                            _filter = 'unread';
                          });
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    itemCount: visibleDocs.length,
                    itemBuilder: (context, index) {
                      final doc = visibleDocs[index];
                      final data = doc.data();
                      final type =
                      (data['type'] ?? '').toString(); // message | follow | like | comment
                      final fromUserId =
                      (data['fromUserId'] ?? '').toString();
                      final createdAt =
                      data['createdAt'] as Timestamp?;
                      final read = data['read'] == true;
                      final timeText = createdAt != null
                          ? _timeAgo(createdAt.toDate())
                          : '';

                      // Swipe to delete
                      return Dismissible(
                        key: ValueKey(doc.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 4),
                          alignment: Alignment.centerRight,
                          padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (_) async {
                          await doc.reference.delete();
                        },
                        child: FutureBuilder<Map<String, dynamic>?>(
                          future: _getUser(fromUserId),
                          builder: (context, userSnap) {
                            final user = userSnap.data;
                            final name = (user?['name'] ??
                                user?['username'] ??
                                'Someone')
                                .toString();
                            final photoURL =
                            (user?['photoURL'] ?? '').toString();

                            String message;
                            IconData leadingIcon;
                            String typeLabel;
                            Color typeColor;

                            switch (type) {
                              case 'message':
                                message = 'sent you a message';
                                leadingIcon =
                                    Icons.chat_bubble_outline;
                                typeLabel = 'Message';
                                typeColor = Colors.teal;
                                break;
                              case 'follow':
                                message = 'started following you';
                                leadingIcon =
                                    Icons.person_add_alt_rounded;
                                typeLabel = 'Follow';
                                typeColor = Colors.blueAccent;
                                break;
                              case 'like':
                                message = 'liked your post';
                                leadingIcon =
                                    Icons.favorite_border_rounded;
                                typeLabel = 'Like';
                                typeColor = Colors.pinkAccent;
                                break;
                              case 'comment':
                                message = 'commented on your post';
                                leadingIcon =
                                    Icons.mode_comment_outlined;
                                typeLabel = 'Comment';
                                typeColor = Colors.orangeAccent;
                                break;
                              default:
                                message = 'did something';
                                leadingIcon =
                                    Icons.notifications_outlined;
                                typeLabel = 'Activity';
                                typeColor = Colors.grey;
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                                horizontal: 4.0,
                              ),
                              child: Material(
                                color: read
                                    ? Colors.white.withOpacity(0.9)
                                    : const Color(0xFFE7F0FF),
                                borderRadius:
                                BorderRadius.circular(16),
                                elevation: 1.5,
                                child: InkWell(
                                  borderRadius:
                                  BorderRadius.circular(16),
                                  onLongPress: () =>
                                      _showNotificationActionsBottomSheet(
                                        doc,
                                      ),
                                  onTap: () async {
                                    // Mark as read
                                    if (!read) {
                                      await doc.reference
                                          .update({'read': true});
                                    }
                                    // TODO: navigate based on type
                                    // e.g., open chat, profile or post
                                  },
                                  child: Padding(
                                    padding:
                                    const EdgeInsets.symmetric(
                                      vertical: 10,
                                      horizontal: 10,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundImage: photoURL
                                              .isNotEmpty
                                              ? NetworkImage(photoURL)
                                              : const AssetImage(
                                              'assets/images/Profile.png')
                                          as ImageProvider,
                                          child: photoURL.isEmpty
                                              ? Icon(
                                            leadingIcon,
                                            size: 18,
                                            color:
                                            Colors.grey[700],
                                          )
                                              : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: RichText(
                                                      text: TextSpan(
                                                        style:
                                                        TextStyle(
                                                          color: Colors
                                                              .black87,
                                                          fontSize: 14,
                                                          fontWeight: read
                                                              ? FontWeight
                                                              .normal
                                                              : FontWeight
                                                              .w600,
                                                        ),
                                                        children: [
                                                          TextSpan(
                                                            text: name,
                                                            style:
                                                            const TextStyle(
                                                              fontWeight:
                                                              FontWeight
                                                                  .bold,
                                                            ),
                                                          ),
                                                          TextSpan(
                                                            text:
                                                            ' $message',
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                    decoration:
                                                    BoxDecoration(
                                                      color: typeColor
                                                          .withOpacity(
                                                          0.1),
                                                      borderRadius:
                                                      BorderRadius
                                                          .circular(
                                                          999),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                      MainAxisSize
                                                          .min,
                                                      children: [
                                                        Icon(
                                                          leadingIcon,
                                                          size: 13,
                                                          color:
                                                          typeColor,
                                                        ),
                                                        const SizedBox(
                                                            width: 4),
                                                        Text(
                                                          typeLabel,
                                                          style:
                                                          TextStyle(
                                                            fontSize: 11,
                                                            color:
                                                            typeColor,
                                                            fontWeight:
                                                            FontWeight
                                                                .w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Text(
                                                    timeText,
                                                    style:
                                                    const TextStyle(
                                                      color:
                                                      Colors.grey,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  if (!read)
                                                    Container(
                                                      margin:
                                                      const EdgeInsets
                                                          .only(
                                                        left: 6,
                                                      ),
                                                      width: 8,
                                                      height: 8,
                                                      decoration:
                                                      const BoxDecoration(
                                                        color:
                                                        Colors.blue,
                                                        shape: BoxShape
                                                            .circle,
                                                      ),
                                                    ),
                                                ],
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
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
