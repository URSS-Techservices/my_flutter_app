import 'dart:io';
import 'package:flutter/material.dart';

class Newpostpage extends StatelessWidget {
  final String imagePath;
  final Function(String caption) onPostSubmit;

  const Newpostpage({super.key, required this.imagePath, required this.onPostSubmit});

  @override
  Widget build(BuildContext context) {
    TextEditingController captionController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: Text('New Post')),
      body: Column(
        children: [
          Image.file(File(imagePath), height: 300, width: double.infinity, fit: BoxFit.cover),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: captionController,
              decoration: InputDecoration(
                hintText: 'Write a caption...',
                border: OutlineInputBorder(),
              ),
              maxLines: null,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              onPostSubmit(captionController.text);
              Navigator.pop(context);
            },
            child: Text('Submit'),
          ),
        ],
      ),
    );
  }
}
