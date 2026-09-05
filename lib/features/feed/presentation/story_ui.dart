// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:halo/features/feed/domain/post_data.dart';
// import 'package:halo/features/feed/presentation/feed_data.dart';
// import 'package:halo/features/feed/presentation/home_layout.dart';
// import 'package:halo/story/story_upload_sheet.dart';
// import 'package:halo/story/story_viewer_page.dart';
//
// class StoryUi extends ConsumerWidget {
//   const StoryUi({super.key});
//
//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final config = ref.watch(homeConfigProvider).valueOrNull ?? HomeConfig.defaults;
//     if (!config.showStories) return const SizedBox.shrink();
//
//     final async = ref.watch(storiesProvider);
//     final size = HomeLayout.storySize(context);
//     final height = HomeLayout.storyStripHeight(context);
//
//     return MediaQuery(
//       data: MediaQuery.of(context).copyWith(
//         textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.25),
//       ),
//       child: async.when(
//       loading: () => SizedBox(
//         height: height,
//         child: const Center(
//           child: SizedBox(
//             width: 22,
//             height: 22,
//             child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6B4EFF)),
//           ),
//         ),
//       ),
//       error: (_, __) => SizedBox(
//         height: height,
//         child: ListView(
//           scrollDirection: Axis.horizontal,
//           padding: HomeLayout.pagePad(context),
//           children: [
//             _Ring(
//               ring: const StoryRing(
//                 userId: '',
//                 username: 'Your story',
//                 photoUrl: '',
//                 isMe: true,
//                 hasUnseen: false,
//                 hasStories: false,
//               ),
//               size: size,
//               photoOverride: ref.watch(myPhotoProvider).valueOrNull ?? '',
//               onTap: () => _addStory(context),
//             ),
//           ],
//         ),
//       ),
//       data: (stories) {
//         final myPhoto = ref.watch(myPhotoProvider).valueOrNull ?? '';
//         final rings = stories.rings.isEmpty
//             ? [
//                 StoryRing(
//                   userId: '',
//                   username: 'Your story',
//                   photoUrl: myPhoto,
//                   isMe: true,
//                   hasUnseen: false,
//                   hasStories: false,
//                 ),
//               ]
//             : stories.rings;
//         return SizedBox(
//           height: height,
//           child: ListView.builder(
//             scrollDirection: Axis.horizontal,
//             padding: HomeLayout.pagePad(context).copyWith(top: 4, bottom: 8),
//             itemCount: rings.length,
//             itemBuilder: (_, i) {
//               final ring = rings[i];
//               return _Ring(
//                 ring: ring,
//                 size: size,
//                 photoOverride: ring.isMe ? myPhoto : ring.photoUrl,
//                 onTap: () {
//                   if (ring.isMe && !ring.hasStories) {
//                     _addStory(context);
//                     return;
//                   }
//                   final list = stories.byUser[ring.userId] ?? const [];
//                   if (list.isEmpty) {
//                     if (ring.isMe) _addStory(context);
//                     return;
//                   }
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(builder: (_) => StoryViewerPage(stories: list)),
//                   );
//                 },
//               );
//             },
//           ),
//         );
//       },
//     ),
//     );
//   }
//
//   void _addStory(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: Colors.transparent,
//       isScrollControlled: true,
//       builder: (_) => const StoryUploadSheet(),
//     );
//   }
// }
//
// class _Ring extends StatelessWidget {
//   final StoryRing ring;
//   final double size;
//   final String photoOverride;
//   final VoidCallback onTap;
//
//   const _Ring({
//     required this.ring,
//     required this.size,
//     required this.photoOverride,
//     required this.onTap,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final photo = photoOverride.isNotEmpty ? photoOverride : ring.photoUrl;
//     final ringOn = ring.hasStories && ring.hasUnseen;
//     final seen = ring.hasStories && !ring.hasUnseen;
//
//     return GestureDetector(
//       onTap: onTap,
//       child: Padding(
//         padding: const EdgeInsets.only(right: 12),
//         child: SizedBox(
//           width: size + 8,
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Stack(
//                 clipBehavior: Clip.none,
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.all(2.4),
//                     decoration: BoxDecoration(
//                       shape: BoxShape.circle,
//                       gradient: ringOn
//                           ? const LinearGradient(
//                               colors: [
//                                 Color(0xFFF56040),
//                                 Color(0xFFD62976),
//                                 Color(0xFF6B4EFF),
//                               ],
//                               begin: Alignment.topLeft,
//                               end: Alignment.bottomRight,
//                             )
//                           : null,
//                       color: seen ? Colors.grey.shade400 : const Color(0xFFE8E6F0),
//                     ),
//                     child: Container(
//                       padding: const EdgeInsets.all(2),
//                       decoration: const BoxDecoration(
//                         shape: BoxShape.circle,
//                         color: Colors.white,
//                       ),
//                       child: FeedAvatar(url: photo, radius: size / 2 - 4),
//                     ),
//                   ),
//                   if (ring.isMe)
//                     Positioned(
//                       bottom: 0,
//                       right: 0,
//                       child: Container(
//                         width: 20,
//                         height: 20,
//                         decoration: BoxDecoration(
//                           color: const Color(0xFF2F80ED),
//                           shape: BoxShape.circle,
//                           border: Border.all(color: Colors.white, width: 2),
//                         ),
//                         child: const Icon(Icons.add, size: 12, color: Colors.white),
//                       ),
//                     ),
//                 ],
//               ),
//               const SizedBox(height: 6),
//               Text(
//                 ring.username,
//                 maxLines: 1,
//                 overflow: TextOverflow.ellipsis,
//                 textAlign: TextAlign.center,
//                 style: const TextStyle(fontSize: 11, color: Color(0xFF2D2D2D), height: 1.1),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/features/feed/domain/post_data.dart';
import 'package:halo/features/feed/presentation/feed_data.dart';
import 'package:halo/features/feed/presentation/home_layout.dart';
import 'package:halo/story/story_upload_sheet.dart';
import 'package:halo/story/story_viewer_page.dart';

class StoryUi extends ConsumerWidget {
  const StoryUi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config =
        ref.watch(homeConfigProvider).valueOrNull ?? HomeConfig.defaults;

    if (!config.showStories) {
      return const SizedBox.shrink();
    }

    final async = ref.watch(storiesProvider);

    // Responsive size based on available screen width.
    final screenWidth = MediaQuery.sizeOf(context).width;

    final storySize = (screenWidth * 0.17).clamp(
      58.0,
      72.0,
    );

    // Enough room for:
    // circle + add badge + username + vertical spacing.
    final storyHeight = storySize + 34;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQuery.textScalerOf(context).clamp(
          maxScaleFactor: 1.25,
        ),
      ),
      child: async.when(
        loading: () => SizedBox(
          height: storyHeight,
          child: const Center(
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

        error: (_, __) => SizedBox(
          height: storyHeight,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(
              left: 12,
              right: 12,
              top: 4,
              bottom: 6,
            ),
            children: [
              _Ring(
                ring: const StoryRing(
                  userId: '',
                  username: 'Your story',
                  photoUrl: '',
                  isMe: true,
                  hasUnseen: false,
                  hasStories: false,
                ),
                size: storySize,
                photoOverride:
                ref.watch(myPhotoProvider).valueOrNull ?? '',
                onTap: () => _addStory(context),
              ),
            ],
          ),
        ),

        data: (stories) {
          final myPhoto =
              ref.watch(myPhotoProvider).valueOrNull ?? '';

          final rings = stories.rings.isEmpty
              ? [
            StoryRing(
              userId: '',
              username: 'Your story',
              photoUrl: myPhoto,
              isMe: true,
              hasUnseen: false,
              hasStories: false,
            ),
          ]
              : stories.rings;

          return SizedBox(
            height: storyHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(
                left: 12,
                right: 12,
                top: 4,
                bottom: 6,
              ),
              physics: const BouncingScrollPhysics(),
              itemCount: rings.length,
              itemBuilder: (_, i) {
                final ring = rings[i];

                return _Ring(
                  ring: ring,
                  size: storySize,
                  photoOverride:
                  ring.isMe ? myPhoto : ring.photoUrl,
                  onTap: () {
                    if (ring.isMe && !ring.hasStories) {
                      _addStory(context);
                      return;
                    }

                    final list =
                        stories.byUser[ring.userId] ?? const [];

                    if (list.isEmpty) {
                      if (ring.isMe) {
                        _addStory(context);
                      }
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            StoryViewerPage(stories: list),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _addStory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const StoryUploadSheet(),
    );
  }
}

class _Ring extends StatelessWidget {
  final StoryRing ring;
  final double size;
  final String photoOverride;
  final VoidCallback onTap;

  const _Ring({
    required this.ring,
    required this.size,
    required this.photoOverride,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final photo =
    photoOverride.isNotEmpty ? photoOverride : ring.photoUrl;

    final ringOn = ring.hasStories && ring.hasUnseen;
    final seen = ring.hasStories && !ring.hasUnseen;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size + 16,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: size + 2,
                height: size + 2,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2.4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: ringOn
                            ? const LinearGradient(
                          colors: [
                            Color(0xFFF56040),
                            Color(0xFFD62976),
                            Color(0xFF6B4EFF),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                            : null,
                        color: seen
                            ? Colors.grey.shade400
                            : const Color(0xFFE8E6F0),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: FeedAvatar(
                          url: photo,
                          radius: (size / 2) - 4,
                        ),
                      ),
                    ),

                    if (ring.isMe)
                      Positioned(
                        bottom: -1,
                        right: -1,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2F80ED),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 5),

              SizedBox(
                width: size + 8,
                child: Text(
                  ring.username.isEmpty
                      ? 'User'
                      : ring.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF2D2D2D),
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}