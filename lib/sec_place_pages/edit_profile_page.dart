import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../design/colors.dart';
import '../design/elderly_styles.dart';
import '../services/theme_service.dart';
import '../services/tts_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TTSService _tts = TTSService();

  File? _profileImage;
  bool _isLoading = false;
  bool _showPasswordFields = false;
  bool _obscurePassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
    }
    _loadProfileImage();
    _tts.init();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _tts.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
      await _uploadImage();
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _loadProfileImage() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final image = await ProfileService.getProfileImage(user.uid);
        if (mounted) {
          setState(() => _profileImage = image);
        }
      }
    } catch (e) {
      // Обработка ошибки
    }
  }

  Future<void> _uploadImage() async {
    if (_profileImage == null) return;

    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final ref = _storage.ref().child('profile_images/${user.uid}');

      await ref.putFile(
        _profileImage!,
        SettableMetadata(cacheControl: "no-cache, max-age=0"),
      );

      final newUrl = await ref.getDownloadURL();

      if (mounted) {
        final imageCache = PaintingBinding.instance.imageCache;
        imageCache.clear();
        imageCache.clearLiveImages();
      }

      final tempDir = await getTemporaryDirectory();
      final newFile = File('${tempDir.path}/profile_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await newFile.writeAsBytes(await _profileImage!.readAsBytes());

      setState(() => _profileImage = newFile);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Фото профиля обновлено!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateEmail() async {
    if (_emailController.text.trim() == _auth.currentUser?.email) return;

    setState(() => _isLoading = true);
    try {
      await _auth.currentUser?.verifyBeforeUpdateEmail(_emailController.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Письмо с подтверждением отправлено на ${_emailController.text.trim()}'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: ${_getErrorMessage(e.code)}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updatePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Пароли не совпадают'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final credential = EmailAuthProvider.credential(
        email: _auth.currentUser!.email!,
        password: _passwordController.text,
      );

      await _auth.currentUser!.reauthenticateWithCredential(credential);
      await _auth.currentUser!.updatePassword(_newPasswordController.text);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Пароль успешно изменен'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      setState(() {
        _showPasswordFields = false;
        _passwordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: ${_getErrorMessage(e.code)}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'wrong-password':
        return 'Неверный текущий пароль';
      case 'weak-password':
        return 'Пароль слишком слабый';
      case 'requires-recent-login':
        return 'Требуется повторный вход';
      case 'email-already-in-use':
        return 'Email уже используется';
      case 'invalid-email':
        return 'Некорректный email';
      default:
        return 'Произошла ошибка';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isElderly = themeService.isElderlyMode;

    return Scaffold(
      backgroundColor: isElderly ? ElderlyStyles.backgroundColor : Colors.white,
      appBar: AppBar(
        title: Text(
          'Редактирование профиля',
          style: isElderly
              ? ElderlyStyles.headlineMedium
              : GoogleFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: isElderly ? ElderlyStyles.backgroundColor : Colors.white,
        elevation: isElderly ? 1 : 0,
        iconTheme: const IconThemeData(color: Colors.black),
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isElderly ? 20 : 18,
          vertical: isElderly ? 20 : 16,
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  Container(
                    width: isElderly ? 140 : 120,
                    height: isElderly ? 140 : 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade100,
                      border: Border.all(
                        color: primaryBlue.withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                    child: _profileImage != null
                        ? ClipOval(
                      child: Image.file(
                        _profileImage!,
                        fit: BoxFit.cover,
                      ),
                    )
                        : Icon(
                      Icons.account_circle,
                      size: isElderly ? 140 : 120,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(isElderly ? 10 : 8),
                      decoration: BoxDecoration(
                        color: primaryBlue,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.edit,
                        size: isElderly ? 20 : 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('Основная информация', isElderly),
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              isElderly: isElderly,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  padding: EdgeInsets.symmetric(vertical: isElderly ? 18 : 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isElderly ? 16 : 14),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : Text(
                  'Обновить email',
                  style: GoogleFonts.manrope(
                    fontSize: isElderly ? 18 : 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Безопасность', isElderly),
            if (!_showPasswordFields)
              _buildAccountOption(
                icon: Icons.lock_outline,
                title: 'Изменить пароль',
                subtitle: 'Обновите ваш пароль',
                onTap: () => setState(() => _showPasswordFields = true),
                isElderly: isElderly,
              ),
            if (_showPasswordFields) ...[
              _buildTextField(
                controller: _passwordController,
                label: 'Текущий пароль',
                icon: Icons.lock_outlined,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey.shade500,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                isElderly: isElderly,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _newPasswordController,
                label: 'Новый пароль',
                icon: Icons.lock_reset_outlined,
                obscureText: _obscureNewPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey.shade500,
                  ),
                  onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                ),
                isElderly: isElderly,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _confirmPasswordController,
                label: 'Подтвердите пароль',
                icon: Icons.lock_reset_outlined,
                obscureText: _obscureConfirmPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey.shade500,
                  ),
                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
                isElderly: isElderly,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _showPasswordFields = false),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: isElderly ? 18 : 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(isElderly ? 16 : 14),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        'Отмена',
                        style: GoogleFonts.manrope(
                          fontSize: isElderly ? 18 : 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updatePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        padding: EdgeInsets.symmetric(vertical: isElderly ? 18 : 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(isElderly ? 16 : 14),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : Text(
                        'Сохранить',
                        style: GoogleFonts.manrope(
                          fontSize: isElderly ? 18 : 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isElderly) {
    return Padding(
      padding: EdgeInsets.only(bottom: isElderly ? 12 : 8, top: isElderly ? 12 : 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: isElderly
              ? ElderlyStyles.labelLarge.copyWith(color: ElderlyStyles.hintColor)
              : GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildAccountOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isElderly,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isElderly ? 16 : 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(isElderly ? 16 : 12),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(isElderly ? 18 : 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isElderly ? 16 : 12),
              border: Border.all(color: Colors.grey.shade200),
              color: isElderly ? ElderlyStyles.surfaceColor : null,
            ),
            child: Row(
              children: [
                Container(
                  width: isElderly ? 56 : 40,
                  height: isElderly ? 56 : 40,
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: primaryBlue, size: isElderly ? 28 : 20),
                ),
                SizedBox(width: isElderly ? 16 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: isElderly
                            ? ElderlyStyles.titleLarge
                            : GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: isElderly ? 8 : 4),
                      Text(
                        subtitle,
                        style: isElderly
                            ? ElderlyStyles.bodyMedium.copyWith(color: ElderlyStyles.hintColor)
                            : GoogleFonts.manrope(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                  size: isElderly ? 32 : 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    required bool isElderly,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey.shade600, size: isElderly ? 22 : 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isElderly ? ElderlyStyles.surfaceColor : Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isElderly ? 14 : 12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isElderly ? 14 : 12),
          borderSide: BorderSide(color: primaryBlue, width: 2),
        ),
        labelStyle: GoogleFonts.manrope(
          fontSize: isElderly ? 16 : 14,
          color: Colors.grey.shade600,
        ),
      ),
      style: GoogleFonts.manrope(
        fontSize: isElderly ? 18 : 16,
        color: Colors.black,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class ProfileService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static File? _cachedProfileImage;

  static Future<File?> getProfileImage(String userId, {bool forceRefresh = false}) async {
    if (_cachedProfileImage != null && !forceRefresh) {
      return _cachedProfileImage;
    }

    try {
      final ref = _storage.ref().child('profile_images/$userId');
      final url = await ref.getDownloadURL();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/profile_image_$userId.jpg');

      final response = await HttpClient().getUrl(Uri.parse(url));
      await (await response.close()).pipe(file.openWrite());

      _cachedProfileImage = file;
      return file;
    } catch (e) {
      return null;
    }
  }

  static Future<void> clearCache() {
    _cachedProfileImage = null;
    return Future.value();
  }
}