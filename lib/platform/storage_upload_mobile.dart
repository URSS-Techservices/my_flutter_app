import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:halo/platform/picked_media.dart';
import 'package:halo/platform/xfile_media.dart';
import 'package:image_picker/image_picker.dart';

/// Mobile Firebase Storage upload — [putFile] preserved.
Future<UploadTask> uploadReferenceFile(
  Reference ref,
  File file, {
  SettableMetadata? metadata,
}) async {
  return ref.putFile(file, metadata);
}

Future<UploadTask> uploadReferenceXFile(
  Reference ref,
  XFile file, {
  SettableMetadata? metadata,
}) async {
  return ref.putFile(File(file.path), metadata);
}

Future<UploadTask> uploadReferencePicked(
  Reference ref,
  PickedMedia media, {
  SettableMetadata? metadata,
}) async {
  return ref.putFile(File(media.path), metadata);
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
