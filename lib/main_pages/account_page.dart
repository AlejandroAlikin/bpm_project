import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../design/colors.dart';
import '../design/elderly_styles.dart';
import '../services/theme_service.dart';
import '../services/tts_service.dart';
import '../services/tts_settings_service.dart';
import '../sec_place_pages/analytics_page.dart';
import '../sec_place_pages/edit_profile_page.dart';
import '../sec_place_pages/notifications_page.dart';
import '../sec_place_pages/ai_analysis_page.dart';  // <-- ДОБАВЬТЕ ЭТУ СТРОКУ

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TTSService _tts = TTSService();
  final TTSSettingsService _ttsSettings = TTSSettingsService();
  File? _profileImage;
  bool _isLoadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    _tts.init();
    _ttsSettings.addListener(_onTtsSettingsChanged);
  }

  @override
  void dispose() {
    _ttsSettings.removeListener(_onTtsSettingsChanged);
    _tts.dispose();
    super.dispose();
  }

  void _onTtsSettingsChanged(bool value) {
    setState(() {});
  }

  void _speakIfElderlyAndEnabled(String text, bool isElderly) {
    if (isElderly && _ttsSettings.isEnabled) {
      _tts.speak(text);
    }
  }

  Future<void> _loadProfileImage() async {
    setState(() => _isLoadingImage = true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final image = await ProfileService.getProfileImage(user.uid);
        if (mounted) {
          setState(() => _profileImage = image);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingImage = false);
      }
    }
  }

  Future<void> _pickAndUploadImage(bool isElderly) async {
    _speakIfElderlyAndEnabled('Выберите изображение из галереи', isElderly);

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _speakIfElderlyAndEnabled('Загрузка фото профиля', isElderly);
      setState(() => _isLoadingImage = true);
      try {
        final user = _auth.currentUser;
        if (user == null) return;

        final ref = _storage.ref().child('profile_images/${user.uid}');
        await ref.putFile(File(pickedFile.path));
        await _loadProfileImage();

        if (!mounted) return;
        _speakIfElderlyAndEnabled('Фото профиля обновлено', isElderly);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Фото профиля обновлено'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        _speakIfElderlyAndEnabled('Ошибка при загрузке изображения', isElderly);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при загрузке изображения'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoadingImage = false);
        }
      }
    }
  }

  Future<void> _showLogoutDialog(BuildContext context, bool isElderly) async {
    _speakIfElderlyAndEnabled('Вы хотите выйти из аккаунта?', isElderly);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: EdgeInsets.only(top: isElderly ? 16 : 10, bottom: isElderly ? 24 : 20),
          decoration: BoxDecoration(
            color: isElderly ? ElderlyStyles.surfaceColor : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, isElderly ? 28 : 24, 16, isElderly ? 12 : 8),
                child: Text(
                  "Выйти из аккаунта?",
                  style: isElderly
                      ? ElderlyStyles.headlineMedium
                      : GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "Вы сможете снова войти в любой момент",
                  style: isElderly
                      ? ElderlyStyles.bodyMedium
                      : GoogleFonts.manrope(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildDialogButton(
                        text: "Отмена",
                        color: isElderly ? ElderlyStyles.surfaceColor : Colors.grey.shade50,
                        textColor: isElderly ? ElderlyStyles.hintColor : Colors.grey.shade700,
                        onPressed: () {
                          _speakIfElderlyAndEnabled('Отмена', isElderly);
                          Navigator.pop(context);
                        },
                        isElderly: isElderly,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDialogButton(
                        text: "Выйти",
                        color: isElderly ? ElderlyStyles.errorColor.withOpacity(0.1) : Colors.red.shade50,
                        textColor: isElderly ? ElderlyStyles.errorColor : Colors.red.shade400,
                        onPressed: () async {
                          _speakIfElderlyAndEnabled('Вы вышли из аккаунта', isElderly);
                          await FirebaseAuth.instance.signOut();
                          if (mounted) Navigator.pop(context);
                        },
                        isElderly: isElderly,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDialogButton({
    required String text,
    required Color color,
    required Color textColor,
    required VoidCallback onPressed,
    required bool isElderly,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: isElderly ? 56 : 48,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(isElderly ? 14 : 12),
          border: Border.all(
            color: color == Colors.red.shade50
                ? Colors.red.shade100
                : Colors.grey.shade200,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: isElderly
                ? GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)
                : GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTtsSwitchTile(bool isElderly) {
    if (!isElderly) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: isElderly ? 14 : 12),
      child: Container(
        padding: EdgeInsets.all(isElderly ? 16 : 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isElderly ? 14 : 12),
          border: Border.all(
            color: isElderly
                ? const Color(0xFF4CAF50).withOpacity(0.5)
                : Colors.grey.shade200,
          ),
          color: isElderly
              ? const Color(0xFF4CAF50).withOpacity(0.1)
              : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              width: isElderly ? 52 : 40,
              height: isElderly ? 52 : 40,
              decoration: BoxDecoration(
                color: isElderly
                    ? const Color(0xFF4CAF50).withOpacity(0.2)
                    : primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _ttsSettings.isEnabled ? Icons.volume_up : Icons.volume_off,
                color: const Color(0xFF4CAF50),
                size: isElderly ? 28 : 20,
              ),
            ),
            SizedBox(width: isElderly ? 14 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Голосовое сопровождение',
                    style: isElderly
                        ? ElderlyStyles.titleLarge
                        : GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: isElderly ? 6 : 4),
                  Text(
                    _ttsSettings.isEnabled
                        ? 'Элементы интерфейса озвучиваются'
                        : 'Озвучка отключена',
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
            Switch(
              value: _ttsSettings.isEnabled,
              onChanged: (bool value) async {
                await _ttsSettings.setEnabled(value);
                if (value && isElderly) {
                  _tts.speak('Голосовое сопровождение включено');
                } else if (isElderly) {
                  _tts.speak('Голосовое сопровождение выключено');
                }
              },
              activeColor: const Color(0xFF4CAF50),
              activeTrackColor: const Color(0xFF4CAF50).withOpacity(0.5),
              inactiveThumbColor: Colors.grey,
              inactiveTrackColor: Colors.grey.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSwitchTile(ThemeService themeService, bool isElderly) {
    return Padding(
      padding: EdgeInsets.only(bottom: isElderly ? 14 : 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(isElderly ? 14 : 12),
          onTap: () {
            final newMode = !isElderly;
            if (newMode) {
              _speakIfElderlyAndEnabled('Включен режим для пожилых людей. Шрифты увеличены.', isElderly);
            } else {
              _speakIfElderlyAndEnabled('Включен обычный режим.', isElderly);
            }
            themeService.toggleMode();
          },
          child: Container(
            padding: EdgeInsets.all(isElderly ? 16 : 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isElderly ? 14 : 12),
              border: Border.all(
                color: isElderly
                    ? const Color(0xFFFFA726).withOpacity(0.5)
                    : Colors.grey.shade200,
              ),
              color: isElderly
                  ? const Color(0xFFFFA726).withOpacity(0.1)
                  : Colors.white,
            ),
            child: Row(
              children: [
                Container(
                  width: isElderly ? 52 : 40,
                  height: isElderly ? 52 : 40,
                  decoration: BoxDecoration(
                    color: isElderly
                        ? const Color(0xFFFFA726).withOpacity(0.2)
                        : primaryBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isElderly ? Icons.elderly : Icons.face,
                    color: isElderly ? const Color(0xFFFFA726) : primaryBlue,
                    size: isElderly ? 28 : 20,
                  ),
                ),
                SizedBox(width: isElderly ? 14 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Режим интерфейса',
                        style: isElderly
                            ? ElderlyStyles.titleLarge
                            : GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: isElderly ? 6 : 4),
                      Text(
                        isElderly
                            ? 'Увеличенные шрифты'
                            : 'Стандартный интерфейс',
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
                Switch(
                  value: isElderly,
                  onChanged: (bool value) {
                    if (value) {
                      _speakIfElderlyAndEnabled('Включен режим для пожилых людей. Шрифты увеличены.', isElderly);
                    } else {
                      _speakIfElderlyAndEnabled('Включен обычный режим.', isElderly);
                    }
                    themeService.toggleMode();
                  },
                  activeColor: const Color(0xFFFFA726),
                  activeTrackColor: const Color(0xFFFFA726).withOpacity(0.5),
                  inactiveThumbColor: primaryBlue,
                  inactiveTrackColor: primaryBlue.withOpacity(0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final themeService = Provider.of<ThemeService>(context);
    final isElderly = themeService.isElderlyMode;

    Future.delayed(const Duration(milliseconds: 500), () {
      if (isElderly && _ttsSettings.isEnabled && mounted) {
        _tts.speak('Страница аккаунта');
      }
    });

    return Scaffold(
      backgroundColor: isElderly ? ElderlyStyles.backgroundColor : Colors.white,
      appBar: AppBar(
        title: Text(
          'Аккаунт',
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
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isElderly ? 20 : 24,
          vertical: isElderly ? 20 : 16,
        ),
        child: Column(
          children: [
            _buildProfileCard(user, isElderly),
            SizedBox(height: isElderly ? 28 : 24),
            _buildSectionTitle('Сервис', isElderly),
            _buildAccountOption(
              icon: Icons.analytics_outlined,
              title: 'Анализ динамики',
              subtitle: 'Графики и статистика измерений',
              onTap: () {
                _speakIfElderlyAndEnabled('Открытие анализа динамики', isElderly);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AnalyticsPage()),
                );
              },
              isElderly: isElderly,
              color: null,
            ),
            // НОВАЯ КНОПКА - ИИ АНАЛИЗ ДАННЫХ
            _buildAccountOption(
              icon: Icons.psychology_outlined,
              title: 'ИИ анализ данных',
              subtitle: 'Персональные рекомендации на основе ваших измерений',
              onTap: () {
                _speakIfElderlyAndEnabled('Открытие ИИ анализа данных', isElderly);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiAnalysisPage()),
                );
              },
              isElderly: isElderly,
              color: const Color(0xFF9C27B0), // Фиолетовый цвет для ИИ
            ),
            _buildModeSwitchTile(themeService, isElderly),
            _buildTtsSwitchTile(isElderly),
            _buildAccountOption(
              icon: Icons.notifications_active_outlined,
              title: 'Напоминания',
              subtitle: 'Управление уведомлениями',
              onTap: () {
                _speakIfElderlyAndEnabled('Открытие напоминаний', isElderly);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                );
              },
              isElderly: isElderly,
              color: null,
            ),
            SizedBox(height: isElderly ? 24 : 20),
            _buildSectionTitle('Аккаунт', isElderly),
            _buildAccountOption(
              icon: Icons.exit_to_app,
              title: 'Выйти из аккаунта',
              subtitle: 'Завершить текущую сессию',
              color: isElderly ? ElderlyStyles.errorColor : Colors.red.shade400,
              onTap: () => _showLogoutDialog(context, isElderly),
              isElderly: isElderly,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(User? user, bool isElderly) {
    return Container(
      padding: EdgeInsets.all(isElderly ? 18 : 16),
      decoration: BoxDecoration(
        color: isElderly ? ElderlyStyles.surfaceColor : Colors.white,
        borderRadius: BorderRadius.circular(isElderly ? 20 : 16),
        boxShadow: [
          BoxShadow(
            color: isElderly
                ? Colors.grey.withOpacity(0.15)
                : Colors.blue.shade50,
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
        border: isElderly ? Border.all(color: Colors.grey.shade200) : null,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _isLoadingImage ? null : () => _pickAndUploadImage(isElderly),
            child: Stack(
              children: [
                Container(
                  width: isElderly ? 72 : 64,
                  height: isElderly ? 72 : 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryBlue.withOpacity(0.1),
                  ),
                  child: _isLoadingImage
                      ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: isElderly ? 3 : 2,
                      color: primaryBlue,
                    ),
                  )
                      : _profileImage != null
                      ? ClipOval(
                    child: Image.file(
                      _profileImage!,
                      fit: BoxFit.cover,
                      width: isElderly ? 72 : 64,
                      height: isElderly ? 72 : 64,
                    ),
                  )
                      : Icon(
                    Icons.account_circle,
                    size: isElderly ? 48 : 40,
                    color: primaryBlue,
                  ),
                ),
                if (!_isLoadingImage)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(isElderly ? 7 : 6),
                      decoration: BoxDecoration(
                        color: primaryBlue,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: isElderly ? 2.5 : 2,
                        ),
                      ),
                      child: Icon(
                        Icons.edit,
                        size: isElderly ? 16 : 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: isElderly ? 16 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.email ?? 'Пользователь',
                  style: isElderly
                      ? ElderlyStyles.titleLarge
                      : GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: isElderly ? 6 : 4),
                Text(
                  'Премиум статус: не активен',
                  style: isElderly
                      ? ElderlyStyles.bodyMedium.copyWith(color: Colors.grey.shade700)
                      : GoogleFonts.manrope(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              _speakIfElderlyAndEnabled('Редактирование профиля', isElderly);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfilePage()),
              );
            },
            icon: Icon(
              Icons.edit,
              color: isElderly ? ElderlyStyles.primaryColor : Colors.grey.shade500,
              size: isElderly ? 28 : 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isElderly) {
    return Padding(
      padding: EdgeInsets.only(bottom: isElderly ? 10 : 8, top: isElderly ? 10 : 8),
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
    Color? color,
    required VoidCallback onTap,
    required bool isElderly,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isElderly ? 14 : 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(isElderly ? 14 : 12),
          onTap: () {
            _speakIfElderlyAndEnabled(title, isElderly);
            onTap();
          },
          child: Container(
            padding: EdgeInsets.all(isElderly ? 16 : 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isElderly ? 14 : 12),
              border: Border.all(color: Colors.grey.shade200),
              color: isElderly ? ElderlyStyles.surfaceColor : null,
            ),
            child: Row(
              children: [
                Container(
                  width: isElderly ? 52 : 40,
                  height: isElderly ? 52 : 40,
                  decoration: BoxDecoration(
                    color: (color ?? primaryBlue).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color ?? primaryBlue,
                    size: isElderly ? 28 : 20,
                  ),
                ),
                SizedBox(width: isElderly ? 14 : 12),
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
                      SizedBox(height: isElderly ? 6 : 4),
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
                  size: isElderly ? 28 : 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileService {
  static Future<File?> getProfileImage(String userId) async {
    return null;
  }
}