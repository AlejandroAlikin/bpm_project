import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  File? _localProfileImage;
  bool _isLoading = false;
  String? _profileImageUrl;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (doc.exists && doc.data()?['profileImageUrl'] != null) {
        final url = doc.data()?['profileImageUrl'] as String;
        setState(() => _profileImageUrl = url);
      }
    } catch (e) {
      print('Ошибка загрузки фото: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null && _auth.currentUser != null) {
      setState(() => _isLoading = true);

      try {
        final user = _auth.currentUser!;
        final file = File(pickedFile.path);

        final ref = _storage.ref('profile_images/${user.uid}');
        await ref.putFile(file);

        final url = await ref.getDownloadURL();

        await _firestore.collection('users').doc(user.uid).set({
          'profileImageUrl': url,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) {
          setState(() {
            _profileImageUrl = url;
            _localProfileImage = file;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка загрузки фото: $e')),
          );
        }
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      // Навигация на страницу входа
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка выхода: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade200,
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _profileImageUrl != null
                          ? FutureBuilder(
                        future: _getImageWidget(_profileImageUrl!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.done) {
                            return snapshot.data ?? _buildDefaultIcon();
                          }
                          return _buildDefaultIcon();
                        },
                      )
                          : _buildDefaultIcon(),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 20,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              _auth.currentUser?.email ?? 'Пользователь',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildAccountButton(
                      icon: Icons.exit_to_app,
                      label: 'Выйти из аккаунта',
                      onTap: _signOut,
                      color: const Color(0xFF8B0000),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultIcon() {
    return Icon(
      Icons.account_circle,
      size: 120,
      color: Colors.grey.shade400,
    );
  }

  Future<Widget> _getImageWidget(String imageUrl) async {
    try {
      return ClipOval(
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          width: 120,
          height: 120,
          errorBuilder: (context, error, stackTrace) => _buildDefaultIcon(),
        ),
      );
    } catch (e) {
      return _buildDefaultIcon();
    }
  }

  Widget _buildAccountButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Material(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 28, color: color),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: GoogleFonts.spaceMono(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right,
                  size: 24,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}