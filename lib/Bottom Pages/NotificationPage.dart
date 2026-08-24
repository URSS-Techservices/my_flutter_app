import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/utils/shell_back.dart';

const Color kPrimaryColor = Color(0xFFA58CE3);
const Color kSecondaryColor = Color(0xFF5B3FA3);
const Color kBackgroundColor = Color(0xFFF4F1FB);

class NotificationPage extends StatefulWidget {
  final VoidCallback? onBackToHome;

  const NotificationPage({Key? key, this.onBackToHome}) : super(key: key);

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  String _filter = 'all';
  bool _isMarkingAll = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _notificationStream(
    String userId,
  ) {
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
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
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
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking all as read: $e')),
      );
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
                leading: Icon(
                  read ? Icons.mark_email_unread : Icons.mark_email_read,
                ),
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

  String _notificationTypeLabel(String type) {
    switch (type) {
      case 'message':
        return 'message';
      case 'follow':
        return 'follow';
      case 'like':
        return 'like';
      case 'comment':
        return 'comment';
      default:
        return 'activity';
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final filtered = _filter == 'unread'
        ? docs.where((d) => d['read'] != true).toList()
        : docs;

    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return filtered;

    return filtered.where((d) {
      final type = (d['type'] ?? '').toString().toLowerCase();
      return type.contains(query) ||
          _notificationTypeLabel(type).contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        top: false,
        child: currentUserId == null
            ? Column(
                children: [
                  _NotificationTopSection(
                    controller: _searchController,
                    onChanged: (value) =>
                        setState(() => _searchQuery = value),
                    onClear: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    onBackToHome: widget.onBackToHome,
                  ),
                  const Expanded(
                    child: Center(
                      child: Text('Please sign in to view notifications'),
                    ),
                  ),
                ],
              )
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _notificationStream(currentUserId),
                builder: (context, snapshot) {
                  final allDocs = snapshot.data?.docs ??
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                  final unreadCount =
                      allDocs.where((d) => d['read'] != true).length;
                  final visibleDocs = _filterDocs(allDocs);

                  Widget body;
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    body = const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    body = Center(child: Text('Error: ${snapshot.error}'));
                  } else if (allDocs.isEmpty) {
                    body = const Center(child: Text('No notifications yet'));
                  } else if (visibleDocs.isEmpty) {
                    body =
                        const Center(child: Text('No matching notifications'));
                  } else {
                    body = ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      itemCount: visibleDocs.length,
                      itemBuilder: (context, index) {
                        return _buildNotificationTile(visibleDocs[index]);
                      },
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _NotificationTopSection(
                        controller: _searchController,
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                        onClear: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        onBackToHome: widget.onBackToHome,
                        onMarkAllRead: unreadCount > 0 && !_isMarkingAll
                            ? () => _markAllAsRead(allDocs)
                            : null,
                        isMarkingAll: _isMarkingAll,
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            if (unreadCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                      color:
                                          Colors.black.withValues(alpha: 0.04),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '$unreadCount unread',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: kSecondaryColor,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            _NotificationFilterChip(
                              label: 'All',
                              selected: _filter == 'all',
                              onTap: () => setState(() => _filter = 'all'),
                            ),
                            const SizedBox(width: 8),
                            _NotificationFilterChip(
                              label: 'Unread',
                              selected: _filter == 'unread',
                              onTap: () => setState(() => _filter = 'unread'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(child: body),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildNotificationTile(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final type = (data['type'] ?? '').toString();
    final fromUserId = (data['fromUserId'] ?? '').toString();
    final createdAt = data['createdAt'] as Timestamp?;
    final read = data['read'] == true;
    final timeText = createdAt != null ? _timeAgo(createdAt.toDate()) : '';

    return Dismissible(
      key: ValueKey(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) async {
        await doc.reference.delete();
      },
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _getUser(fromUserId),
        builder: (context, userSnap) {
          final user = userSnap.data;
          final name =
              (user?['name'] ?? user?['username'] ?? 'Someone').toString();
          final photoURL = (user?['photoURL'] ?? '').toString();

          String message;
          IconData leadingIcon;
          String typeLabel;
          Color typeColor;

          switch (type) {
            case 'message':
              message = 'sent you a message';
              leadingIcon = Icons.chat_bubble_outline;
              typeLabel = 'Message';
              typeColor = Colors.teal;
              break;
            case 'follow':
              message = 'started following you';
              leadingIcon = Icons.person_add_alt_rounded;
              typeLabel = 'Follow';
              typeColor = Colors.blueAccent;
              break;
            case 'like':
              message = 'liked your post';
              leadingIcon = Icons.favorite_border_rounded;
              typeLabel = 'Like';
              typeColor = Colors.pinkAccent;
              break;
            case 'comment':
              message = 'commented on your post';
              leadingIcon = Icons.mode_comment_outlined;
              typeLabel = 'Comment';
              typeColor = Colors.orangeAccent;
              break;
            default:
              message = 'did something';
              leadingIcon = Icons.notifications_outlined;
              typeLabel = 'Activity';
              typeColor = Colors.grey;
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Material(
              color: read
                  ? Colors.white.withValues(alpha: 0.9)
                  : const Color(0xFFE7F0FF),
              borderRadius: BorderRadius.circular(16),
              elevation: 1.5,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onLongPress: () => _showNotificationActionsBottomSheet(doc),
                onTap: () async {
                  if (!read) {
                    await doc.reference.update({'read': true});
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 10,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundImage: photoURL.isNotEmpty
                            ? NetworkImage(photoURL)
                            : const AssetImage('assets/images/Profile.png')
                                as ImageProvider,
                        child: photoURL.isEmpty
                            ? Icon(
                                leadingIcon,
                                size: 18,
                                color: Colors.grey[700],
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                  fontWeight:
                                      read ? FontWeight.normal : FontWeight.w600,
                                ),
                                children: [
                                  TextSpan(
                                    text: name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(text: ' $message'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: typeColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        leadingIcon,
                                        size: 13,
                                        color: typeColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        typeLabel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: typeColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  timeText,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                if (!read)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
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
  }
}

// ─── Notification header (matches Explore / Search) ───────────────────────────

class _NotificationTopSection extends StatelessWidget {
  const _NotificationTopSection({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.onBackToHome,
    this.onMarkAllRead,
    this.isMarkingAll = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback? onBackToHome;
  final VoidCallback? onMarkAllRead;
  final bool isMarkingAll;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: kSecondaryColor.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFF4A3488),
                Color(0xFF5B3FA3),
                Color(0xFF7A5FC8),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _NotificationHeaderWavePainter(),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _NotificationGlassIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () => popOrGoHome(
                            context,
                            onBackToHome: onBackToHome,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Notifications',
                            style: GoogleFonts.poppins(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.4,
                              height: 1,
                            ),
                          ),
                        ),
                        if (onMarkAllRead != null || isMarkingAll)
                          _NotificationGlassIconButton(
                            icon: Icons.done_all_rounded,
                            onTap: isMarkingAll ? null : onMarkAllRead,
                            child: isMarkingAll
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _NotificationGlassSearchField(
                      controller: controller,
                      onChanged: onChanged,
                      onClear: onClear,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationHeaderWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final wavePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    final wave = Path()
      ..moveTo(size.width * 0.55, 0)
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.35,
        size.width,
        size.height * 0.2,
      )
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(wave, wavePaint);

    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14);
    const cols = 3;
    const rows = 4;
    const spacing = 7.0;
    final gridLeft = size.width - 28;
    const gridTop = 14.0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        canvas.drawCircle(
          Offset(gridLeft + c * spacing, gridTop + r * spacing),
          1.4,
          dotPaint,
        );
      }
    }

    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.55),
      size.width * 0.22,
      Paint()..color = Colors.white.withValues(alpha: 0.04),
    );

    _drawSparkle(canvas, Offset(18, size.height * 0.22), 0.35);
    _drawSparkle(canvas, Offset(42, size.height * 0.38), 0.25);
    _drawSparkle(canvas, Offset(size.width - 36, size.height * 0.18), 0.3);
  }

  void _drawSparkle(Canvas canvas, Offset center, double scale) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final arm = 4.0 * scale;
    canvas.drawLine(
      Offset(center.dx - arm, center.dy),
      Offset(center.dx + arm, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - arm),
      Offset(center.dx, center.dy + arm),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NotificationGlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? child;

  const _NotificationGlassIconButton({
    required this.icon,
    this.onTap,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.32),
                ),
              ),
              child: Center(
                child: child ?? Icon(icon, color: Colors.white, size: 17),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationGlassSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _NotificationGlassSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textAlignVertical: TextAlignVertical.center,
          keyboardAppearance: Brightness.dark,
          textInputAction: TextInputAction.search,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14.5,
            fontWeight: FontWeight.w400,
          ),
          cursorColor: Colors.white,
          decoration: InputDecoration(
            hintText: 'Search notifications…',
            hintStyle: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: Colors.white.withValues(alpha: 0.9),
              size: 22,
            ),
            suffixIcon: ListenableBuilder(
              listenable: controller,
              builder: (_, __) {
                if (controller.text.isNotEmpty) {
                  return IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.85),
                      size: 20,
                    ),
                    onPressed: onClear,
                  );
                }
                return Icon(
                  Icons.tune_rounded,
                  color: Colors.white.withValues(alpha: 0.85),
                  size: 22,
                );
              },
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.14),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.32),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.55),
                width: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NotificationFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF6E52B8), kSecondaryColor],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0xFFE8E4F0),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: kSecondaryColor.withValues(alpha: 0.24),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.035),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: selected ? Colors.white : kSecondaryColor,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
