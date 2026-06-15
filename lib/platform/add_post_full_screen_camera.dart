import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

const Color _kPrimaryColor = Color(0xFFA58CE3);

/// Full-screen camera capture for Add Post (mobile only).
class AddPostFullScreenCamera extends StatefulWidget {
  final List<CameraDescription> cameras;
  const AddPostFullScreenCamera({super.key, required this.cameras});

  @override
  State<AddPostFullScreenCamera> createState() =>
      _AddPostFullScreenCameraState();
}

class _AddPostFullScreenCameraState extends State<AddPostFullScreenCamera> {
  late CameraController _ctrl;
  int _camIdx = 0;
  bool _ready = false;
  bool _recording = false;
  bool _isVideo = false;
  bool _isSwitching = false;

  @override
  void initState() {
    super.initState();
    _initCtrl(0);
  }

  Future<void> _initCtrl(int idx) async {
    setState(() {
      _ready = false;
      _isSwitching = true;
    });
    final ctrl = CameraController(
      widget.cameras[idx],
      ResolutionPreset.high,
      enableAudio: true,
    );
    await ctrl.initialize();
    if (!mounted) {
      ctrl.dispose();
      return;
    }
    _ctrl = ctrl;
    setState(() {
      _camIdx = idx;
      _ready = true;
      _isSwitching = false;
    });
  }

  Future<void> _flipCamera() async {
    if (_isSwitching) return;
    final next = (_camIdx + 1) % widget.cameras.length;
    final old = _ctrl;
    await _initCtrl(next);
    await old.dispose();
  }

  Future<void> _capture() async {
    if (!_ready || _isSwitching) return;
    if (_isVideo) {
      if (_recording) {
        final file = await _ctrl.stopVideoRecording();
        if (!mounted) return;
        Navigator.pop(context, file);
      } else {
        await _ctrl.startVideoRecording();
        setState(() => _recording = true);
      }
    } else {
      final photo = await _ctrl.takePicture();
      if (!mounted) return;
      Navigator.pop(context, photo);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (_ready) Positioned.fill(child: CameraPreview(_ctrl)),
            if (!_ready)
              const Center(
                child: CircularProgressIndicator(color: _kPrimaryColor),
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 28),
                    ),
                    const Spacer(),
                    if (widget.cameras.length > 1)
                      GestureDetector(
                        onTap: _isSwitching ? null : _flipCamera,
                        child: Icon(
                          Icons.flip_camera_ios_rounded,
                          color:
                              _isSwitching ? Colors.white38 : Colors.white,
                          size: 28,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(bottom: 32, top: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ModeButton(
                          label: 'Photo',
                          selected: !_isVideo,
                          onTap: () => setState(() => _isVideo = false),
                        ),
                        const SizedBox(width: 24),
                        _ModeButton(
                          label: 'Video',
                          selected: _isVideo,
                          onTap: () => setState(() => _isVideo = true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _isSwitching ? null : _capture,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          color: _isSwitching
                              ? Colors.grey.withOpacity(0.5)
                              : (_recording
                                  ? Colors.red
                                  : Colors.white.withOpacity(0.9)),
                        ),
                        child: _recording
                            ? const Icon(Icons.stop_rounded,
                                color: Colors.white, size: 32)
                            : Icon(
                                _isVideo
                                    ? Icons.videocam_rounded
                                    : Icons.camera_alt_rounded,
                                color: Colors.black87,
                                size: 32,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_recording)
              Positioned(
                top: 60,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'REC',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                color: selected ? Colors.white : Colors.white60,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: selected ? 24 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: _kPrimaryColor,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      );
}
