import 'dart:io';
import 'package:flutter/material.dart';
import 'package:halo/core/halo_toast.dart';
/*
class PostDetailPage extends StatefulWidget {
  final String username;
  final File? imageFile;
  final String? videoPath;
  final String caption;
  final bool isLiked; // Track whether the post/reel is liked
  final ValueChanged<bool> onLikeChanged; // Callback to update like status

  const PostDetailPage({
    Key? key,
    required this.username,
    this.imageFile,
    this.videoPath,
    required this.caption,
    required this.isLiked,
    required this.onLikeChanged,
  }) : super(key: key);

  @override
  _PostDetailPageState createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late bool isLiked; // Local state for the like status

  @override
  void initState() {
    super.initState();
    isLiked = widget.isLiked; // Initialize with the passed `isLiked` value
  }

  void toggleLike() {
    setState(() {
      isLiked = !isLiked; // Toggle like status locally
    });
    widget.onLikeChanged(isLiked); // Notify parent about the like status
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.username),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(
              child: widget.imageFile != null
                  ? Image.file(widget.imageFile!)
                  : widget.videoPath != null
                  ? Icon(Icons.videocam, size: 150, color: Colors.grey) // Placeholder for video
                  : Container(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              widget.caption,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border_outlined,
                  color: isLiked ? Colors.pink : Colors.black87,
                ),
                onPressed: toggleLike,
              ),
              IconButton(
                icon: Icon(Icons.comment_outlined),
                onPressed: () {
                  HaloToast.show('Comments not implemented yet!');
                },
              ),
              IconButton(
                icon: Icon(Icons.share_outlined),
                onPressed: () {
                  HaloToast.show('Sharing not implemented yet!');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}*/

class PostDetailPage extends StatefulWidget {
  final String username;
  final List<Map<String, dynamic>> items; // List of posts/reels
  final int initialIndex; // Index of the starting post/reel
  final bool isVideo; // True for reels, false for posts
  final ValueChanged<List<Map<String, dynamic>>> onItemsUpdated; // Callback to update items

  const PostDetailPage({
    Key? key,
    required this.username,
    required this.items,
    required this.initialIndex,
    required this.isVideo,
    required this.onItemsUpdated,
  }) : super(key: key);

  @override
  _PostDetailPageState createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late PageController _pageController;
  late List<Map<String, dynamic>> items;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    items = List.from(widget.items); // Clone the list locally
  }

  void toggleLike(int index) {
    setState(() {
      items[index]['isLiked'] = !(items[index]['isLiked'] ?? false); // Toggle like
    });
    widget.onItemsUpdated(items); // Notify parent about updated items
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.username),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            widget.onItemsUpdated(items); // Pass updated items back on exit
            Navigator.pop(context);
          },
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final isLiked = item['isLiked'] ?? false;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: widget.isVideo
                      ? Icon(Icons.videocam, size: 150, color: Colors.grey) // Placeholder for video
                      : Image.file(File(item['image'].path), fit: BoxFit.cover), // Image
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  item['caption'] ?? 'No Caption',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border_outlined,
                      color: isLiked ? Colors.pink : Colors.black87,
                    ),
                    onPressed: () => toggleLike(index),
                  ),
                  IconButton(
                    icon: Icon(Icons.comment_outlined),
                    onPressed: () {
                      HaloToast.show('Comments not implemented yet!');
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.share_outlined),
                    onPressed: () {
                      HaloToast.show('Sharing not implemented yet!');
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
