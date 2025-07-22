import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io'; // Import the dart:io package for File

class ProfilePictureSelectorWidget extends StatefulWidget {
  @override
  _ProfilePictureSelectorWidgetState createState() => _ProfilePictureSelectorWidgetState();
}

class _ProfilePictureSelectorWidgetState extends State<ProfilePictureSelectorWidget> {
  final ImagePicker _picker = ImagePicker();
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadProfilePicture();
  }

  Future<void> _loadProfilePicture() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = userDoc.data() as Map<String, dynamic>?;
      setState(() {
        _profileImageUrl = data != null && data.containsKey('profileImageUrl') ? data['profileImageUrl'] : null;
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          Reference storageRef = FirebaseStorage.instance.ref().child('profile_pictures').child(user.uid);
          UploadTask uploadTask = storageRef.putFile(File(image.path));
          TaskSnapshot taskSnapshot = await uploadTask;
          String downloadUrl = await taskSnapshot.ref.getDownloadURL();

          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'profileImageUrl': downloadUrl,
          });

          setState(() {
            _profileImageUrl = downloadUrl;
          });
        } catch (e) {
          print('Error uploading profile picture: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: CircleAvatar(
            radius: 50,
            backgroundImage: _profileImageUrl != null
                ? NetworkImage(_profileImageUrl!)
                : null,
            child: _profileImageUrl == null
                ? Icon(Icons.add_a_photo, size: 50, color: Colors.white)
                : null,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Change Profile Picture',
          style: TextStyle(color: Colors.white),
        ),
      ],
    );
  }
}