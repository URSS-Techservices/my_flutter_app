import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Full photo editor shown right after a photo is picked or captured:
/// crop / rotate / flip, filters, tune (brightness, contrast, saturation,
/// exposure, …), blur, freehand paint (incl. pixelate/blur brush), text and
/// emoji.
///
/// Pops with the edited [File], or `null` when the user closes the editor
/// without pressing Done.
class PostImageEditorPage extends StatefulWidget {
  final File file;

  const PostImageEditorPage({super.key, required this.file});

  @override
  State<PostImageEditorPage> createState() => _PostImageEditorPageState();
}

class _PostImageEditorPageState extends State<PostImageEditorPage> {
  Uint8List? _editedBytes;

  Future<void> _onEditingComplete(Uint8List bytes) async {
    _editedBytes = bytes;
  }

  Future<void> _onCloseEditor(EditorMode editorMode) async {
    if (editorMode != EditorMode.main) {
      Navigator.pop(context);
      return;
    }
    final bytes = _editedBytes;
    File? output;
    if (bytes != null) {
      final dir = await getTemporaryDirectory();
      output = File('${dir.path}/halo_edit_${DateTime.now().microsecondsSinceEpoch}.jpg');
      await output.writeAsBytes(bytes, flush: true);
    }
    if (!mounted) return;
    Navigator.pop(context, output);
  }

  @override
  Widget build(BuildContext context) {
    return ProImageEditor.file(
      widget.file,
      configs: const ProImageEditorConfigs(
        imageGeneration: ImageGenerationConfigs(
          outputFormat: OutputFormat.jpg,
          jpegQuality: 95,
          // Always re-encode so HEIC/PNG sources come out as a real JPEG.
          enableUseOriginalBytes: false,
          maxOutputSize: Size(4096, 4096),
        ),
      ),
      callbacks: ProImageEditorCallbacks(
        onImageEditingComplete: _onEditingComplete,
        onCloseEditor: _onCloseEditor,
      ),
    );
  }
}
