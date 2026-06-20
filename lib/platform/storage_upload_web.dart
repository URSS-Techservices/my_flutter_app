import 'package:firebase_storage/firebase_storage.dart';
import 'package:halo/platform/picked_media.dart';
import 'package:halo/platform/xfile_media.dart';
import 'package:image_picker/image_picker.dart';

/// Web Firebase Storage upload — [putData] with bytes from [XFile]/[PickedMedia].
Future<void> uploadReferenceXFile(
  Reference ref,
  XFile file, {
  SettableMetadata? metadata,
}) async {
  final bytes = await file.readAsBytes();
  final meta = metadata ??
      SettableMetadata(
        contentType: file.mimeType,
      );
  final task = ref.putData(bytes, meta);
  await task;
}

Future<void> uploadReferencePicked(
  Reference ref,
  PickedMedia media, {
  SettableMetadata? metadata,
}) async {
  final meta = metadata ??
      SettableMetadata(
        contentType: media.mimeType,
      );
  final task = ref.putData(media.bytes, meta);
  await task;
}

Future<String> uploadReferenceXFileAndGetUrl(
  Reference ref,
  XFile file, {
  SettableMetadata? metadata,
}) async {
  await uploadReferenceXFile(ref, file, metadata: metadata);
  return ref.getDownloadURL();
}

Future<String> uploadReferencePickedAndGetUrl(
  Reference ref,
  PickedMedia media, {
  SettableMetadata? metadata,
}) async {
  await uploadReferencePicked(ref, media, metadata: metadata);
  return ref.getDownloadURL();
}
