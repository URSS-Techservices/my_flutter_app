import 'package:halo/platform/picked_media.dart';
import 'package:image_picker/image_picker.dart';

/// Reads gallery/camera picks into a cross-platform [PickedMedia] payload.
Future<PickedMedia> pickedMediaFromXFile(XFile file) async {
  final bytes = await file.readAsBytes();
  return PickedMedia(
    bytes: bytes,
    name: file.name,
    path: file.path,
    mimeType: file.mimeType,
  );
}
