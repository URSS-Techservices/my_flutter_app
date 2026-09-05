import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/features/feed/domain/post_data.dart';
import 'package:halo/features/feed/presentation/app_bar.dart';
import 'package:halo/features/feed/presentation/feed_data.dart';
import 'package:halo/features/feed/presentation/home_layout.dart';
import 'package:halo/features/feed/presentation/loading_ui.dart';
import 'package:halo/features/feed/presentation/post_detail.dart';
import 'package:halo/features/feed/presentation/story_ui.dart';

class HomePage extends ConsumerStatefulWidget {
  final VoidCallback onMenu;
  final VoidCallback onBell;
  final VoidCallback onChat;
  final VoidCallback onPhoto;

  const HomePage({
    super.key,
    required this.onMenu,
    required this.onBell,
    required this.onChat,
    required this.onPhoto,
  });

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 700) {
      ref.read(feedControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ids = ref.watch(feedPostIdsProvider);
    final loading = ref.watch(feedControllerProvider.select((s) => s.loading));
    final error = ref.watch(feedControllerProvider.select((s) => s.error));
    final loadingMore = ref.watch(feedControllerProvider.select((s) => s.loadingMore));
    final moreError = ref.watch(feedControllerProvider.select((s) => s.moreError));
    final hasMore = ref.watch(feedControllerProvider.select((s) => s.hasMore));
    final config = ref.watch(homeConfigProvider).valueOrNull ?? HomeConfig.defaults;

    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          AppBarUi(
            onMenu: widget.onMenu,
            onBell: widget.onBell,
            onChat: widget.onChat,
            onPhoto: widget.onPhoto,
          ),
          Expanded(
            child: RefreshIndicator(
              color: config.accent,
              onRefresh: () => ref.read(feedControllerProvider.notifier).refresh(),
              child: HomeLayout.constrain(
                context,
                CustomScrollView(
                  controller: _scroll,
                  cacheExtent: 1400,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    const SliverToBoxAdapter(child: StoryUi()),
                    if (loading && ids.isEmpty)
                      const SliverToBoxAdapter(child: LoadingUi())
                    else if (error != null && ids.isEmpty)
                      SliverToBoxAdapter(
                        child: FeedErrorUi(
                          message: error,
                          onRetry: () => ref.read(feedControllerProvider.notifier).retry(),
                        ),
                      )
                    else if (ids.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            config.emptyMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF8E8E8E), fontSize: 14),
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            return _FeedPost(
                              postId: ids[i],
                              accent: config.accent,
                            );
                          },
                          childCount: ids.length,
                          addAutomaticKeepAlives: false,
                          addRepaintBoundaries: true,
                        ),
                      ),
                    if (loadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF6B4EFF),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (moreError != null)
                      SliverToBoxAdapter(
                        child: TextButton(
                          onPressed: () =>
                              ref.read(feedControllerProvider.notifier).loadMore(),
                          child: Text(moreError),
                        ),
                      ),
                    if (!hasMore && ids.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            "You're all caught up!",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedPost extends ConsumerWidget {
  final String postId;
  final Color accent;

  const _FeedPost({
    required this.postId,
    required this.accent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = ref.watch(feedPostProvider(postId));
    if (post == null) return const SizedBox.shrink();
    return PostDetail(
      post: post,
      accent: accent,
    );
  }
}
