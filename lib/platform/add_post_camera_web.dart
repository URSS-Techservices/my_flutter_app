import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

Future<XFile?> openAddPostCamera(
  BuildContext context, {
  List? cameras,
}) async {
  final picker = ImagePicker();
  return picker.pickImage(
    source: ImageSource.camera,
    imageQuality: 72,
    maxWidth: 1280,
    maxHeight: 1280,
  );
}
