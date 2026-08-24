import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:halo/platform/picked_media.dart';
import 'package:halo/platform/xfile_media.dart';
import 'package:image_picker/image_picker.dart';

/// Mobile Firebase Storage upload — [putFile] preserved.
Future<void> uploadReferenceFile(
  Reference ref,
  File file, {
  SettableMetadata? metadata,
}) async {
  final task = ref.putFile(file, metadata);
  await task;
}

Future<void> uploadReferenceXFile(
  Reference ref,
  XFile file, {
  SettableMetadata? metadata,
}) async {
  final task = ref.putFile(File(file.path), metadata);
  await task;
}

Future<void> uploadReferencePicked(
  Reference ref,
  PickedMedia media, {
  SettableMetadata? metadata,
}) async {
  final task = ref.putFile(File(media.path), metadata);
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
