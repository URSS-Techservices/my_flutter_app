import 'package:cached_network_image/cached_network_image.dart';
import 'package:halo/features/search/presentation/search_responsive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/Profile%20Pages/aspirant_profile_page.dart'
    show PostDetailsPage;
import 'package:halo/core/halo_toast.dart';
import 'package:halo/features/search/data/search_remote.dart';
import 'package:halo/features/search/domain/search_models.dart';
import 'package:halo/features/search/presentation/search_providers.dart';
import 'package:halo/screens/profile/profile_router_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH RESULTS PANEL
// Shown when query has 2+ characters. Contains tabbed People + Posts views.
// ─────────────────────────────────────────────────────────────────────────────

class SearchResults extends ConsumerStatefulWidget {
  const SearchResults({super.key});

  @override
  ConsumerState<SearchResults> createState() => _SearchResultsState();
}

class _SearchResultsState extends ConsumerState<SearchResults>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchNotifierProvider);
    final query = state.query.trim();

    // Don't show anything if no query
    if (query.isEmpty) return const SizedBox.shrink();

    // Minimum length hint
    if (query.length < 2) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.s(8)),
        child: Text(
          'Type at least 2 characters to search',
          style: GoogleFonts.poppins(
              color: Colors.grey.shade500, fontSize: context.sp(13)),
        ),
      );
    }

    // Loading
    if (state.loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.s(32)),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(kSearchSecondary),
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    // Error
    if (state.error != null) {
      return _SearchErrorCard(
        onRetry: () => ref.read(searchNotifierProvider.notifier).retrySearch(),
      );
    }

    // Empty results
    if (!state.hasResults) {
      return Container(
        padding: EdgeInsets.all(context.s(24)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(context.s(20)),
        ),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded,
                size: context.s(42), color: Colors.grey.shade300),
            SizedBox(height: context.s(10)),
            Text(
              'No results for "${state.debouncedQuery}"',
              style: GoogleFonts.poppins(
                  color: Colors.grey.shade500, fontSize: context.sp(14)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Results
    return LayoutBuilder(builder: (context, constraints) {
      final tabHeight =
          (MediaQuery.of(context).size.height * 0.5).clamp(280.0, 560.0);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Results',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: context.sp(15),
                  color: const Color(0xFF1F1033),
                ),
              ),
              if (state.usedFallback) ...[
                SizedBox(width: context.s(6)),
                Expanded(
                  child: Text(
                    '· Partial match',
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade500,
                      fontSize: context.sp(12),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              IconButton(
                icon: Icon(Icons.refresh_rounded,
                    size: context.s(20), color: kSearchSecondary),
                onPressed: () =>
                    ref.read(searchNotifierProvider.notifier).retrySearch(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          SizedBox(height: context.s(8)),

          // Tabbed results
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(context.s(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  labelColor: kSearchSecondary,
                  unselectedLabelColor: Colors.grey.shade500,
                  indicatorColor: kSearchSecondary,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: context.sp(13)),
                  tabs: [
                    Tab(text: 'People (${state.userResults.length})'),
                    Tab(text: 'Posts (${state.postResults.length})'),
                  ],
                ),
                SizedBox(
                  height: tabHeight,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // People tab
                      state.userResults.isEmpty
                          ? Center(
                              child: Text('No people found',
                                  style: GoogleFonts.poppins(
                                      color: Colors.grey.shade500)))
                          : ListView.builder(
                              padding:
                                  EdgeInsets.symmetric(vertical: context.s(8)),
                              itemCount: state.userResults.length,
                              itemBuilder: (context, i) => UserResultCard(
                                user: state.userResults[i],
                              ),
                            ),

                      // Posts tab
                      PostResultGrid(
                        posts: state.postResults,
                        onTapPost: (postId) => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PostDetailsPage(postId: postId)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR CARD
// ─────────────────────────────────────────────────────────────────────────────

class _SearchErrorCard extends StatelessWidget {
  final VoidCallback onRetry;
  const _SearchErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.s(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(context.s(16)),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded,
              color: Colors.grey.shade400, size: context.s(22)),
          SizedBox(width: context.s(10)),
          Expanded(
            child: Text('Search unavailable. Please try again.',
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade600, fontSize: context.sp(13))),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text('Retry',
                style: GoogleFonts.poppins(
                    color: kSearchSecondary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USER RESULT CARD
// ─────────────────────────────────────────────────────────────────────────────

class UserResultCard extends StatefulWidget {
  final UserResult user;
  const UserResultCard({super.key, required this.user});

  @override
  State<UserResultCard> createState() => _UserResultCardState();
}

class _UserResultCardState extends State<UserResultCard> {
  bool _isFollowing = false;
  bool _followLoading = false;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final SearchRemote _remote = SearchRemote();

  @override
  void initState() {
    super.initState();
    final relation = widget.user.relation;
    if (relation == FollowRelation.unknown) {
      _checkFollow();
    } else {
      // The category feed already loaded the follow graph — no extra read.
      _isFollowing = relation == FollowRelation.following ||
          relation == FollowRelation.mutual;
    }
  }

  Future<void> _checkFollow() async {
    final uid = _currentUserId;
    if (uid == null || uid == widget.user.userId) return;
    final following = await _remote.checkFollowing(uid, widget.user.userId);
    if (mounted) setState(() => _isFollowing = following);
  }

  Future<void> _toggleFollow() async {
    final uid = _currentUserId;
    if (uid == null || uid == widget.user.userId) return;
    setState(() => _followLoading = true);
    try {
      await _remote.toggleFollow(
        currentUserId: uid,
        targetUserId: widget.user.userId,
        isCurrentlyFollowing: _isFollowing,
      );
      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
          _followLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _followLoading = false);
        HaloToast.show('Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelf = _currentUserId == widget.user.userId;

    return Semantics(
      button: true,
      label: 'Open profile of ${widget.user.name}',
      child: Container(
        margin: EdgeInsets.symmetric(
            horizontal: context.s(12), vertical: context.s(5)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(context.s(16)),
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              spreadRadius: -2,
              offset: const Offset(0, 2),
              color: Colors.black.withValues(alpha: 0.06),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(context.s(16)),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ProfileRouterScreen(profileUserId: widget.user.userId),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: context.s(14), vertical: context.s(12)),
              child: Row(
                children: [
                  // Avatar
                  _UserAvatar(
                    photoUrl: widget.user.profilePhoto,
                    name: widget.user.name,
                    radius: context.s(24),
                  ),
                  SizedBox(width: context.s(12)),

                  // Name + username
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.user.name,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: context.sp(14),
                                  color: const Color(0xFF1F1033),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: context.s(6)),
                            _AccountBadge(widget.user.accountType),
                          ],
                        ),
                        if (widget.user.username.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '@${widget.user.username}',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade500,
                              fontSize: context.sp(12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Follow button
                  if (!isSelf)
                    _followLoading
                        ? SizedBox(
                            width: context.s(20),
                            height: context.s(20),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: kSearchSecondary))
                        : GestureDetector(
                            onTap: _toggleFollow,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: EdgeInsets.symmetric(
                                  horizontal: context.s(14),
                                  vertical: context.s(7)),
                              decoration: BoxDecoration(
                                color: _isFollowing
                                    ? Colors.white
                                    : kSearchSecondary,
                                borderRadius:
                                    BorderRadius.circular(context.s(20)),
                                border: Border.all(
                                  color: _isFollowing
                                      ? Colors.grey.shade300
                                      : kSearchSecondary,
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                _isFollowing ? 'Following' : 'Follow',
                                style: GoogleFonts.poppins(
                                  fontSize: context.sp(12),
                                  fontWeight: FontWeight.w600,
                                  color: _isFollowing
                                      ? Colors.grey.shade700
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Avatar helper ────────────────────────────────────────────────────────────

class _UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;

  const _UserAvatar({
    required this.photoUrl,
    required this.name,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final initials =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';
    return CircleAvatar(
      radius: radius,
      backgroundColor: kSearchPrimary.withValues(alpha: 0.1),
      child: ClipOval(
        child: photoUrl != null && photoUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: photoUrl!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    _InitialsCircle(initials: initials, radius: radius),
                errorWidget: (_, __, ___) =>
                    _InitialsCircle(initials: initials, radius: radius),
              )
            : _InitialsCircle(initials: initials, radius: radius),
      ),
    );
  }
}

class _InitialsCircle extends StatelessWidget {
  final String initials;
  final double radius;

  const _InitialsCircle({required this.initials, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      color: kSearchPrimary.withValues(alpha: 0.08),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: kSearchSecondary,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.7,
          ),
        ),
      ),
    );
  }
}

// ── Account type badge helper ─────────────────────────────────────────────────

class _AccountBadge extends StatelessWidget {
  final String accountType;
  const _AccountBadge(this.accountType);

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (accountType.toLowerCase()) {
      case 'guru':
        bg = const Color(0xFFEDE4FF);
        fg = kSearchSecondary;
        label = 'Guru';
        break;
      case 'wellness':
        bg = const Color(0xFFE0F7F0);
        fg = const Color(0xFF0F6E56);
        label = 'Wellness';
        break;
      default:
        bg = const Color(0xFFF1F1F1);
        fg = const Color(0xFF555555);
        label = 'Aspirant';
    }

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: context.s(8), vertical: context.s(3)),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(context.s(20))),
      child: Text(
        label,
        style: TextStyle(
            color: fg,
            fontSize: context.sp(10),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST RESULT GRID
// ─────────────────────────────────────────────────────────────────────────────

class PostResultGrid extends StatelessWidget {
  final List<PostResult> posts;
  final void Function(String postId) onTapPost;

  const PostResultGrid(
      {super.key, required this.posts, required this.onTapPost});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return Center(
        child: Text(
          'No posts match your search.',
          style: GoogleFonts.poppins(
              color: Colors.grey.shade500, fontSize: context.sp(14)),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(context.s(8)),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
        childAspectRatio: 1,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return GestureDetector(
          onTap: () => onTapPost(post.postId),
          child: Container(
            color: Colors.grey.shade200,
            child: post.imageUrl != null && post.imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: post.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                            child:
                                CircularProgressIndicator(strokeWidth: 1.5))),
                    errorWidget: (_, __, ___) => const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey),
                  )
                : const Center(child: Icon(Icons.image, color: Colors.grey)),
          ),
        );
      },
    );
  }
}
