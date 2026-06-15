import 'package:firebase_storage/firebase_storage.dart';
import 'package:halo/platform/picked_media.dart';
import 'package:halo/platform/xfile_media.dart';
import 'package:image_picker/image_picker.dart';

/// Web Firebase Storage upload — [putData] with bytes from [XFile]/[PickedMedia].
Future<UploadTask> uploadReferenceXFile(
  Reference ref,
  XFile file, {
  SettableMetadata? metadata,
}) async {
  final bytes = await file.readAsBytes();
  final meta = metadata ??
      SettableMetadata(
        contentType: file.mimeType,
      );
  return ref.putData(bytes, meta);
}

Future<UploadTask> uploadReferencePicked(
  Reference ref,
  PickedMedia media, {
  SettableMetadata? metadata,
}) async {
  final meta = metadata ??
      SettableMetadata(
        contentType: media.mimeType,
      );
  return ref.putData(media.bytes, meta);
}

Future<String> uploadReferenceXFileAndGetUrl(
  Reference ref,
  XFile file, {
  SettableMetadata? metadata,
}) async {
  final task = await uploadReferenceXFile(ref, file, metadata: metadata);
  await task;
  return ref.getDownloadURL();
}

Future<String> uploadReferencePickedAndGetUrl(
  Reference ref,
  PickedMedia media, {
  SettableMetadata? metadata,
}) async {
  final task = await uploadReferencePicked(ref, media, metadata: metadata);
  await task;
  return ref.getDownloadURL();
}
