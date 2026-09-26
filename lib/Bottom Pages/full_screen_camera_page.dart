import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

/// Full-screen capture UI. Camera permission and [availableCameras()] are
/// resolved by the caller (`MediaPickerService`) before this page is pushed —
/// this page only owns the single [CameraController] for its own lifetime,
/// created on push and disposed on pop. No camera resource exists while the
/// Create Post composer is otherwise just showing text fields.
class FullScreenCameraPage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const FullScreenCameraPage({super.key, required this.cameras});

  @override
  State<FullScreenCameraPage> createState() => _FullScreenCameraPageState();
}

class _FullScreenCameraPageState extends State<FullScreenCameraPage> with WidgetsBindingObserver {
  CameraController? _controller;
  int _cameraIndex = 0;
  bool _isRecording = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera(widget.cameras[_cameraIndex]);
  }

  Future<void> _initCamera(CameraDescription description) async {
    final previous = _controller;
    _controller = null;
    await previous?.dispose();

    final controller = CameraController(description, ResolutionPreset.high, enableAudio: true);
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _initError = 'Could not start the camera. Please try again.');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      controller.dispose();
      _controller = null;
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      _initCamera(widget.cameras[_cameraIndex]);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final photo = await controller.takePicture();
      if (!mounted) return;
      Navigator.pop(context, photo);
    } catch (_) {
      if (mounted) setState(() => _initError = 'Could not capture the photo. Please try again.');
    }
  }

  Future<void> _toggleVideo() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      if (_isRecording) {
        final video = await controller.stopVideoRecording();
        if (!mounted) return;
        Navigator.pop(context, video);
      } else {
        await controller.startVideoRecording();
        setState(() => _isRecording = true);
      }
    } catch (_) {
      if (mounted) setState(() => _initError = 'Could not record video. Please try again.');
    }
  }

  Future<void> _switchCamera() async {
    if (widget.cameras.length < 2 || _isRecording) return;
    _cameraIndex = (_cameraIndex + 1) % widget.cameras.length;
    setState(() => _controller = null);
    await _initCamera(widget.cameras[_cameraIndex]);
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_rounded, color: Colors.white, size: 40),
              const SizedBox(height: 12),
              Text(_initError!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close', style: TextStyle(color: Colors.white70)),
                  ),
                  TextButton(
                    onPressed: () => _initCamera(widget.cameras[_cameraIndex]),
                    child: const Text('Retry', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(controller)),

          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          if (widget.cameras.length > 1)
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 28),
                onPressed: _isRecording ? null : _switchCamera,
              ),
            ),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: _isRecording ? null : _takePhoto,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.white38 : Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _toggleVideo,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.red : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.videocam,
                      color: _isRecording ? Colors.white : Colors.black,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
