import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halo/utils/search_utils.dart';
import 'package:halo/screens/profile/core/profile_field_utils.dart';

class EditProfilePage extends StatefulWidget {
  final String initialUsername;
  final String initialName;
  final String initialBio;
  final String initialGender;
  final String initialprofessiontype;

  const EditProfilePage({
    Key? key,
    required this.initialUsername,
    required this.initialName,
    required this.initialBio,
    required this.initialGender,
    required this.initialprofessiontype,
  }) : super(key: key);

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _genderController;
  late TextEditingController _professionTypeController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.initialUsername);
    _nameController = TextEditingController(text: widget.initialName);
    _bioController = TextEditingController(text: widget.initialBio);
    _genderController = TextEditingController(text: widget.initialGender);
    _professionTypeController = TextEditingController(text: widget.initialprofessiontype);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    _genderController.dispose();
    _professionTypeController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        Fluttertoast.showToast(msg: 'No user logged in');
        return;
      }

      final updatedData = {
        'username': _usernameController.text.trim(),
        ...ProfileFieldUtils.nameUpdateFields(_nameController.text),
        'bio': _bioController.text.trim(),
        'gender': _genderController.text.trim(),
        'professiontype': _professionTypeController.text.trim(),
      };
      updatedData['searchTerms'] = buildSearchTerms(
        name: updatedData['name']?.toString(),
        username: updatedData['username']?.toString(),
      );

      await _firestore.collection('users').doc(user.uid).update(updatedData);
      Fluttertoast.showToast(msg: 'Profile updated successfully');
      Navigator.pop(context, updatedData); // Return updated data to ProfilePage
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error updating profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: GoogleFonts.rubik(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _isLoading ? null : _saveProfile,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Username',
                style: GoogleFonts.rubik(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter your username',
                  hintStyle: const TextStyle(color: Colors.black54),
                  labelStyle: const TextStyle(color: Colors.black87),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Username is required';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              Text(
                'Name',
                style: GoogleFonts.rubik(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter your name',
                  hintStyle: const TextStyle(color: Colors.black54),
                  labelStyle: const TextStyle(color: Colors.black87),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              Text(
                'Bio',
                style: GoogleFonts.rubik(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _bioController,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter your bio',
                  hintStyle: const TextStyle(color: Colors.black54),
                  labelStyle: const TextStyle(color: Colors.black87),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bio is required';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              Text(
                'Gender',
                style: GoogleFonts.rubik(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _genderController,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter your gender',
                  hintStyle: const TextStyle(color: Colors.black54),
                  labelStyle: const TextStyle(color: Colors.black87),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Gender is required';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              Text(
                'Profession Type',
                style: GoogleFonts.rubik(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _professionTypeController,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter your profession type',
                  hintStyle: const TextStyle(color: Colors.black54),
                  labelStyle: const TextStyle(color: Colors.black87),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Profession type is required';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  backgroundColor: Colors.blue.shade50,
                ),
                child: Text(
                  'Save Changes',
                  style: GoogleFonts.rubik(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

