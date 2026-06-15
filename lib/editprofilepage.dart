import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

import 'package:halo/platform/storage_upload.dart';
import 'package:halo/utils/search_utils.dart';

void saveProfileData({
  required String uid,
  required String name,
  required String username,
  required String bio,
}) {
  FirebaseFirestore.instance.collection('users').doc(uid).set({
    'name': name,
    'username': username,
    'bio': bio,
    'searchTerms': buildSearchTerms(name: name, username: username),
    'createdAt': FieldValue.serverTimestamp(),
  });
}

class EditProfilePage extends StatefulWidget {
  final String initialUsername; // Add the parameter
  final String initialName;
  final String initialBio; // Add this parameter
  final String initialGender;
  final String initialprofessiontype;

  EditProfilePage({required this.initialUsername, required this.initialName, required this.initialBio, required this.initialGender, required this.initialprofessiontype}); // Named constructor

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _linkController = TextEditingController();
  final _musicController = TextEditingController();

  String _gender = 'Male';
  File? _imageFile;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final uid = _auth.currentUser!.uid;
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      _nameController.text = data['name'] ?? '';
      _usernameController.text = data['username'] ?? '';
      _bioController.text = data['bio'] ?? '';
      _linkController.text = data['link'] ?? '';
      _musicController.text = data['music'] ?? '';
      _gender = data['gender'] ?? 'Male';
      _imageUrl = data['profilePic'];
      setState(() {});
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<String?> _uploadImage(File file) async {
    final uid = _auth.currentUser!.uid;
    final ref = FirebaseStorage.instance.ref().child('profile_pics/$uid.jpg');
    return uploadReferenceXFileAndGetUrl(
      ref,
      XFile(file.path),
      metadata: SettableMetadata(contentType: 'image/jpeg'),
    );
  }

  Future<void> _saveProfile() async {
    final uid = _auth.currentUser!.uid;
    String? imageUrl = _imageUrl;

    if (_imageFile != null) {
      imageUrl = await _uploadImage(_imageFile!);
    }

    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    await _firestore.collection('users').doc(uid).set({
      'name': name,
      'username': username,
      'bio': _bioController.text,
      'link': _linkController.text,
      'gender': _gender,
      'music': _musicController.text,
      'profilePic': imageUrl,
      'searchTerms': buildSearchTerms(name: name, username: username),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Profile updated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _imageFile != null
                    ? FileImage(_imageFile!)
                    : (_imageUrl != null ? NetworkImage(_imageUrl!) : null) as ImageProvider?,
                child: _imageFile == null && _imageUrl == null
                    ? Icon(Icons.camera_alt, size: 40)
                    : null,
              ),
            ),
            SizedBox(height: 16),
            _buildTextField('Name', _nameController),
            _buildTextField('Username', _usernameController),
            _buildTextField('Bio', _bioController),
            _buildTextField('Link', _linkController),
            _buildDropdown('Gender', ['Male', 'Female', 'Other']),
            _buildTextField('Favorite Music', _musicController),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                String uid = FirebaseAuth.instance.currentUser!.uid;

                saveProfileData(
                  uid: uid,
                  name: _nameController.text,
                  username: _usernameController.text,
                  bio: _bioController.text,
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Profile saved!')),
                );
              },
              child: Text('Save Changes'),
            ),


          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black87),
          hintStyle: const TextStyle(color: Colors.black54),
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        value: _gender,
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (val) => setState(() => _gender = val!),
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder()),
      ),
    );
  }
}
