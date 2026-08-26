import 'dart:io';
import 'package:halo/newpostpage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../postdetailspage.dart';
import '../../newpostpage.dart';
import '../../main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Userprofile extends StatefulWidget {
  final String userId;
  const Userprofile({required this.userId});

  @override
  _UserProfileState createState() => _UserProfileState();
}

class _UserProfileState extends State<Userprofile> {
  Map<String, dynamic>? userData;
  bool isFollowing = false;
  String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    loadUserData();
    checkIfFollowing();
  }

  Future<void> loadUserData() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
    if (doc.exists) {
      setState(() {
        userData = doc.data();
      });
    }
  }

  Future<void> checkIfFollowing() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
    final followingList = doc.data()?['followingList'] ?? [];
    setState(() {
      isFollowing = followingList.contains(widget.userId);
    });
  }

  void followUser() async {
    await FirebaseFirestore.instance.collection('users').doc(currentUserId).update({
      'followingList': FieldValue.arrayUnion([widget.userId])
    });
    await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
      'followersList': FieldValue.arrayUnion([currentUserId])
    });
    setState(() {
      isFollowing = true;
    });
  }

  void unfollowUser() async {
    await FirebaseFirestore.instance.collection('users').doc(currentUserId).update({
      'followingList': FieldValue.arrayRemove([widget.userId])
    });
    await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
      'followersList': FieldValue.arrayRemove([currentUserId])
    });
    setState(() {
      isFollowing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (userData == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Profile')),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final profilePic = userData!.containsKey('profilePic') ? userData!['profilePic'] : null;
    final name = userData!['name'] ?? '';
    final username = userData!['username'] ?? '';
    final bio = userData!['bio'] ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundImage: profilePic != null ? NetworkImage(profilePic) : null,
              child: profilePic == null ? Icon(Icons.person, size: 48) : null,
            ),
            SizedBox(height: 16),
            Text(name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('@$username', style: TextStyle(fontSize: 16, color: Colors.grey)),
            SizedBox(height: 12),
            Text(bio, style: TextStyle(fontSize: 16)),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: isFollowing ? unfollowUser : followUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: isFollowing ? Colors.grey : Colors.blue,
              ),
              child: Text(isFollowing ? 'Following' : 'Follow'),
            ),
          ],
        ),
      ),
    );
  }
}