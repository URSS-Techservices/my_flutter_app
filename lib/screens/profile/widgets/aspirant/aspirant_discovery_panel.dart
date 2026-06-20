import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_router_screen.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/screens/profile/widgets/common/profile_empty_state.dart';
import 'package:halo/screens/profile/widgets/common/profile_empty_state_rich.dart';
import 'package:halo/screens/profile/widgets/common/profile_inline_tab_chip.dart';
import 'package:halo/screens/profile/widgets/common/profile_section_card.dart';
import 'package:halo/services/follow_service.dart';

/// Discovery tab panel for aspirant profiles: similar users, coaches, wellness, community.
class AspirantDiscoveryPanel extends StatefulWidget {
  final String profileUserId;
  final String? currentUserId;
  final List<String> interests;
  final String? primaryCategory;
  final bool isOwnProfile;
  final List<Map<String, dynamic>> eventsChallenges;
  final Map<String, String> socialLinks;
  final VoidCallback onEditEvents;
  final VoidCallback onEditSocialLinks;
  final void Function(String interest) onOpenInterestExplore;
  final void Function(String platform, String url) onOpenSocialLink;

  const AspirantDiscoveryPanel({
    super.key,
    required this.profileUserId,
    required this.currentUserId,
    required this.interests,
    required this.primaryCategory,
    required this.isOwnProfile,
    required this.eventsChallenges,
    required this.socialLinks,
    required this.onEditEvents,
    required this.onEditSocialLinks,
    required this.onOpenInterestExplore,
    required this.onOpenSocialLink,
  });

  @override
  State<AspirantDiscoveryPanel> createState() => _AspirantDiscoveryPanelState();
}

class _AspirantDiscoveryPanelState extends State<AspirantDiscoveryPanel> {
  static const _tabs = ['Aspirant', 'Coaches', 'Wellness', 'Community'];

  final _firestore = FirebaseFirestore.instance;
  final _followService = FollowService();

  int _selectedTab = 0;
  final Map<String, bool> _followLoading = {};

  List<String> _toLowerTrimmedList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString().trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
  }

  String _commonMatchText(Map<String, dynamic> data) {
    final mine = widget.interests.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet();
    final theirs = <String>{
      ..._toLowerTrimmedList(data['interests']),
      ..._toLowerTrimmedList(data['specialties']),
      ..._toLowerTrimmedList(data['services']),
      data['primaryCategory']?.toString().trim().toLowerCase() ?? '',
      data['category']?.toString().trim().toLowerCase() ?? '',
      data['wellness_category']?.toString().trim().toLowerCase() ?? '',
    }..removeWhere((e) => e.isEmpty);

    final common = mine.intersection(theirs).toList();
    if (common.isNotEmpty) {
      final first = common.first;
      return '${first[0].toUpperCase()}${first.substring(1)} in common';
    }

    final fallback = (data['primaryCategory'] ?? data['category'] ?? data['wellness_category'] ?? '').toString().trim();
    return fallback.isNotEmpty ? fallback : 'Suggested for you';
  }

  void _openProfile(String userId) {
    if (userId.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileRouterScreen(profileUserId: userId)));
  }

  Future<void> _toggleFollow({required String profileUserId, required bool isFollowing}) async {
    final currentUid = widget.currentUserId;
    if (currentUid == null || profileUserId.isEmpty || profileUserId == currentUid) return;

    setState(() => _followLoading[profileUserId] = true);
    try {
      await _followService.setFollowState(
        currentUserId: currentUid,
        profileUserId: profileUserId,
        shouldFollow: !isFollowing,
      );
    } catch (_) {
      Fluttertoast.showToast(msg: 'Could not update follow right now');
    } finally {
      if (mounted) setState(() => _followLoading[profileUserId] = false);
    }
  }

  Widget _followButton(String targetUserId) {
    final currentUid = widget.currentUserId;
    if (currentUid == null || currentUid == targetUserId) return const SizedBox.shrink();

    final loading = _followLoading[targetUserId] == true;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('users').doc(targetUserId).collection('followers').doc(currentUid).snapshots(),
      builder: (context, snapshot) {
        final isFollowing = snapshot.data?.exists ?? false;
        return SizedBox(
          height: 26,
          child: OutlinedButton(
            onPressed: loading ? null : () => _toggleFollow(profileUserId: targetUserId, isFollowing: isFollowing),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              side: BorderSide(color: isFollowing ? Colors.grey.shade400 : ProfileLayout.deepLavender),
              backgroundColor: isFollowing ? Colors.white : ProfileLayout.deepLavender,
            ),
            child: loading
                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(
                    isFollowing ? 'Following' : 'Follow',
                    style: GoogleFonts.poppins(fontSize: 9, color: isFollowing ? Colors.black87 : Colors.white),
                  ),
          ),
        );
      },
    );
  }

  Widget _tabsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: List.generate(_tabs.length, (index) {
          return ProfileInlineTabChip(
            label: _tabs[index],
            selected: _selectedTab == index,
            onTap: () {
              if (_selectedTab != index) setState(() => _selectedTab = index);
            },
          );
        }),
      ),
    );
  }

  Widget _hobbiesSection() {
    if (widget.interests.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hobbies & Mood', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.interests
                .map(
                  (i) => ActionChip(
                    label: Text(i, style: GoogleFonts.poppins(fontSize: 12)),
                    backgroundColor: ProfileLayout.chipBg,
                    side: BorderSide.none,
                    onPressed: () => widget.onOpenInterestExplore(i),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _eventsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [ProfileLayout.deepLavender, ProfileLayout.lavender]),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Events & Challenges', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                if (widget.isOwnProfile)
                  TextButton.icon(
                    onPressed: widget.onEditEvents,
                    icon: const Icon(Icons.edit, size: 18, color: Colors.white),
                    label: const Text('Edit', style: TextStyle(color: Colors.white)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (widget.eventsChallenges.isEmpty && widget.isOwnProfile)
              const ProfileEmptyStateRich(
                text: 'No events yet. Add your first tournament, show or meetup!',
                textColor: Colors.white70,
              )
            else if (widget.eventsChallenges.isEmpty)
              const SizedBox.shrink()
            else
              ...widget.eventsChallenges.map(
                (e) => Text(
                  '${e['type'] ?? ''}: ${e['name'] ?? ''}  (${e['status'] ?? ''})',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _socialLinksSection() {
    return ProfileSectionCard(
      title: 'Social Links',
      trailing: widget.isOwnProfile
          ? TextButton.icon(
              onPressed: widget.onEditSocialLinks,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Edit'),
            )
          : null,
      child: widget.socialLinks.isEmpty
          ? (widget.isOwnProfile
              ? const ProfileEmptyState(text: 'No social links yet. Add your links!', card: true)
              : const SizedBox.shrink())
          : Row(
              children: [
                if (widget.socialLinks['instagram'] != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => widget.onOpenSocialLink('instagram', widget.socialLinks['instagram']!),
                      child: const Text('Instagram'),
                    ),
                  ),
                if (widget.socialLinks['spotify'] != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => widget.onOpenSocialLink('spotify', widget.socialLinks['spotify']!),
                      child: const Text('Spotify'),
                    ),
                  ),
                ],
                if (widget.socialLinks['telegram'] != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => widget.onOpenSocialLink('telegram', widget.socialLinks['telegram']!),
                      child: const Text('Telegram'),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _similarAspirants() {
    Query<Map<String, dynamic>> query = _firestore.collection('users').where('accountType', isEqualTo: 'aspirant');
    if (widget.primaryCategory != null && widget.primaryCategory!.isNotEmpty) {
      query = query.where('primaryCategory', isEqualTo: widget.primaryCategory);
    }

    return _horizontalUserList(
      title: 'People Like You',
      height: 90,
      query: query,
      cardWidth: 110,
      excludeSelf: true,
      emptyText: 'We will suggest other aspirants here.',
    );
  }

  Widget _suggestedGurus() {
    Query<Map<String, dynamic>> query = _firestore.collection('users').where('accountType', isEqualTo: 'guru');
    if (widget.interests.isNotEmpty) {
      final top = widget.interests.length > 5 ? widget.interests.sublist(0, 5) : widget.interests;
      query = query.where('interests', arrayContainsAny: top);
    }

    return _horizontalUserList(
      title: 'Suggested Gurus (Coaches)',
      subtitle: widget.primaryCategory,
      height: 110,
      query: query,
      cardWidth: 110,
      emptyText: 'No gurus found yet for your interests.',
    );
  }

  Widget _suggestedWellness() {
    Query<Map<String, dynamic>> query = _firestore.collection('users').where('accountType', isEqualTo: 'wellness');
    if (widget.interests.isNotEmpty) {
      final top = widget.interests.length > 5 ? widget.interests.sublist(0, 5) : widget.interests;
      query = query.where('interests', arrayContainsAny: top);
    }

    return _horizontalUserList(
      title: 'Explore Wellness (Shops / Places)',
      height: 110,
      query: query,
      cardWidth: 150,
      horizontalLayout: true,
      emptyText: 'No wellness profiles yet. They will appear here.',
    );
  }

  Widget _horizontalUserList({
    required String title,
    String? subtitle,
    required double height,
    required Query<Map<String, dynamic>> query,
    required double cardWidth,
    required String emptyText,
    bool excludeSelf = false,
    bool horizontalLayout = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16))),
              if (subtitle != null && subtitle.isNotEmpty)
                Flexible(child: Text(subtitle, style: GoogleFonts.poppins(fontSize: 12), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: height,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.limit(15).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator()));
                }
                var docs = snapshot.data?.docs ?? [];
                if (excludeSelf) docs = docs.where((d) => d.id != widget.profileUserId).toList();
                if (docs.isEmpty) {
                  return subtitle == null && !excludeSelf
                      ? ProfileEmptyState(text: emptyText)
                      : Text(emptyText, style: GoogleFonts.poppins(fontSize: 12));
                }
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => _userCard(docs[index], cardWidth, horizontalLayout),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _userCard(DocumentSnapshot<Map<String, dynamic>> doc, double width, bool horizontalLayout) {
    final data = doc.data() ?? {};
    final name = (data['name'] ?? 'User').toString();
    final photo = data['profilePhoto'] as String?;
    final matchText = _commonMatchText(data);
    final category = (data['primaryCategory'] ?? '').toString();

    final avatar = CircleAvatar(
      radius: horizontalLayout ? 20 : 22,
      backgroundImage: photo != null
          ? NetworkImage(photo)
          : const AssetImage('assets/images/Profile.png') as ImageProvider,
    );

    final content = horizontalLayout
        ? Row(
            children: [
              avatar,
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                    Text(category.isNotEmpty ? category : matchText, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 10, color: Colors.black54)),
                    _followButton(doc.id),
                  ],
                ),
              ),
            ],
          )
        : Column(
            children: [
              avatar,
              const SizedBox(height: 6),
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
              Text(category.isNotEmpty ? category : matchText, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 10, color: Colors.black54)),
              const SizedBox(height: 4),
              _followButton(doc.id),
            ],
          );

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openProfile(doc.id),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 3))],
        ),
        child: content,
      ),
    );
  }

  Widget _tabContent() {
    switch (_selectedTab) {
      case 0:
        return Column(children: [_similarAspirants(), _hobbiesSection()]);
      case 1:
        return _suggestedGurus();
      case 2:
        return _suggestedWellness();
      case 3:
        return Column(children: [_eventsSection(), _socialLinksSection()]);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tabsRow(),
        _tabContent(),
      ],
    );
  }
}
