import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class VideoThumbnailPicker extends StatefulWidget {
  final String videoPath;

  const VideoThumbnailPicker({super.key, required this.videoPath});

  @override
  State<VideoThumbnailPicker> createState() => _VideoThumbnailPickerState();
}

class _VideoThumbnailPickerState extends State<VideoThumbnailPicker> {
  late VideoPlayerController _controller;

  double _currentPosition = 0;
  Uint8List? _selectedThumbnail;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(
      File(widget.videoPath),
    )..initialize().then((_) {
      setState(() {});
    });
  }

  Future<void> _generateThumbnail(double position) async {
    final bytes = await VideoThumbnail.thumbnailData(
      video: widget.videoPath,
      imageFormat: ImageFormat.JPEG,
      timeMs: (position * _controller.value.duration.inMilliseconds).toInt(),
      quality: 75,
    );

    setState(() {
      _selectedThumbnail = bytes;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Thumbnail"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, _selectedThumbnail);
            },
            child: const Text("Done", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),

          const SizedBox(height: 20),

          // Selected preview
          if (_selectedThumbnail != null)
            Container(
              height: 100,
              margin: const EdgeInsets.all(10),
              child: Image.memory(_selectedThumbnail!),
            ),

          Slider(
            value: _currentPosition,
            onChanged: (value) async {
              setState(() => _currentPosition = value);
              await _generateThumbnail(value);
            },
          ),
        ],
      ),
    );
  }
}