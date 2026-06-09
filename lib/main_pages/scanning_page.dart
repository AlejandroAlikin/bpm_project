import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../design/colors.dart';
import '../design/elderly_styles.dart';
import '../services/theme_service.dart';
import '../services/tts_service.dart';
import '../logic/photo_processing.dart';

class ScanningPage extends StatefulWidget {
  const ScanningPage({super.key});

  @override
  State<ScanningPage> createState() => _ScanningPageState();
}

class _ScanningPageState extends State<ScanningPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  String? _systolic;
  String? _diastolic;
  String? _pulse;
  bool _isLoading = false;
  bool _isSaved = false;
  bool _hasData = false;

  late AnimationController _successAnimationController;
  late AnimationController _failedAnimationController;
  late AnimationController _loadingAnimationController;
  final DigitsRecognition _digitsRecognition = DigitsRecognition();
  final TTSService _tts = TTSService();
  OverlayEntry? _overlayEntry;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TextEditingController _sysController;
  late TextEditingController _diaController;
  late TextEditingController _pulseController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _successAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _failedAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _loadingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _tts.init();

    _sysController = TextEditingController();
    _diaController = TextEditingController();
    _pulseController = TextEditingController();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeOverlay();
    _successAnimationController.dispose();
    _failedAnimationController.dispose();
    _loadingAnimationController.dispose();
    _tts.dispose();
    _sysController.dispose();
    _diaController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // При возвращении на страницу сохраняем состояние
    if (state == AppLifecycleState.resumed) {
      setState(() {});
    }
  }

  void _showOverlay(String animationType) {
    _removeOverlay();

    final screenWidth = MediaQuery.of(context).size.width;
    final size = animationType == 'loading' ? screenWidth / 2 : screenWidth / 3;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: Material(
          color: Colors.transparent,
          child: IgnorePointer(
            child: Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Lottie.asset(
                    'assets/animations/$animationType.json',
                    controller: animationType == 'success_load'
                        ? _successAnimationController
                        : animationType == 'failed'
                        ? _failedAnimationController
                        : _loadingAnimationController,
                    fit: BoxFit.contain,
                    repeat: animationType == 'loading',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _speakIfElderly(String text, bool isElderly) {
    if (isElderly) {
      _tts.speak(text);
    }
  }

  void _updateDisplayData(String systolic, String diastolic, String pulse) {
    _sysController.text = systolic;
    _diaController.text = diastolic;
    _pulseController.text = pulse;

    setState(() {
      _systolic = systolic;
      _diastolic = diastolic;
      _pulse = pulse;
      _isSaved = false;
      _hasData = true;
    });
  }

  Future<void> _saveToDatabase() async {
    if (_isSaved) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final measurement = Measurement(
      systolic: _sysController.text.trim(),
      diastolic: _diaController.text.trim(),
      pulse: _pulseController.text.trim(),
      date: DateTime.now(),
    );

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('measurements')
          .add(measurement.toFirestore());

      setState(() {
        _isSaved = true;
        _hasData = false;
        _systolic = _sysController.text.trim();
        _diastolic = _diaController.text.trim();
        _pulse = _pulseController.text.trim();
      });

      _speakIfElderly('Измерение сохранено',
          Provider.of<ThemeService>(context, listen: false).isElderlyMode);

      _showOverlay('success_load');
      _successAnimationController.reset();
      await _successAnimationController.forward();
      _removeOverlay();
    } catch (e) {
      print('Ошибка сохранения: $e');
      _speakIfElderly('Ошибка сохранения',
          Provider.of<ThemeService>(context, listen: false).isElderlyMode);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка сохранения результата'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _processRecognition(Measurement measurement, bool isElderly) async {
    _loadingAnimationController.stop();
    _removeOverlay();

    setState(() => _isLoading = false);

    final bool isFailed = measurement.systolic.isEmpty ||
        measurement.diastolic.isEmpty ||
        measurement.pulse.isEmpty;

    if (isFailed) {
      _speakIfElderly('Не удалось распознать показания', isElderly);
      _showOverlay('failed');
      _failedAnimationController.reset();
      await _failedAnimationController.forward();
      _removeOverlay();
      return;
    }

    _updateDisplayData(measurement.systolic, measurement.diastolic, measurement.pulse);
    _speakIfElderly('Данные распознаны. При необходимости отредактируйте и нажмите сохранить', isElderly);
  }

  Future<void> _processImage(XFile imageFile, bool isElderly) async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    _showOverlay('loading');
    _loadingAnimationController.repeat();

    try {
      final file = File(imageFile.path);
      final measurement = await _digitsRecognition.recognize(file);
      await _processRecognition(measurement, isElderly);
    } catch (e) {
      _loadingAnimationController.stop();
      _removeOverlay();

      if (mounted) {
        setState(() => _isLoading = false);
        _speakIfElderly('Ошибка обработки изображения', isElderly);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка обработки изображения: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showScanDialog(bool isElderly) {
    _speakIfElderly('Выберите источник изображения', isElderly);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
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
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Откуда загрузить данные?",
                style: isElderly
                    ? ElderlyStyles.headlineMedium
                    : GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _buildSourceOption(
                      icon: Icons.camera_alt_rounded,
                      label: "Сделать фото",
                      color: primaryBlue,
                      onTap: () {
                        Navigator.pop(context);
                        _takePhoto(isElderly);
                      },
                      isElderly: isElderly,
                    ),
                    const SizedBox(height: 16),
                    _buildSourceOption(
                      icon: Icons.photo_library_rounded,
                      label: "Выбрать из галереи",
                      color: primaryBlue,
                      onTap: () {
                        Navigator.pop(context);
                        _pickFromGallery(isElderly);
                      },
                      isElderly: isElderly,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isElderly,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(isElderly ? 16 : 14),
        child: Container(
          padding: EdgeInsets.all(isElderly ? 18 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isElderly ? 16 : 14),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: isElderly ? 56 : 48,
                height: isElderly ? 56 : 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: isElderly ? 28 : 24),
              ),
              SizedBox(width: isElderly ? 16 : 14),
              Text(
                label,
                style: isElderly
                    ? ElderlyStyles.titleLarge
                    : GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: isElderly ? 28 : 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _takePhoto(bool isElderly) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      await _processImage(image, isElderly);
    }
  }

  Future<void> _pickFromGallery(bool isElderly) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _processImage(image, isElderly);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final themeService = Provider.of<ThemeService>(context);
    final isElderly = themeService.isElderlyMode;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isElderly && mounted && _systolic == null && !_isLoading) {
        _tts.speak('Страница сканирования. Нажмите кнопку сканировать');
      }
    });

    return Scaffold(
      backgroundColor: isElderly ? ElderlyStyles.backgroundColor : Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isElderly ? 20 : 24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Мониторинг давления',
                  style: isElderly
                      ? ElderlyStyles.headlineLarge
                      : GoogleFonts.manrope(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Отслеживайте ваши показатели здоровья',
                  style: isElderly
                      ? ElderlyStyles.bodyMedium.copyWith(color: ElderlyStyles.hintColor)
                      : GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isElderly ? 20 : 24),
                  decoration: BoxDecoration(
                    color: isElderly ? ElderlyStyles.surfaceColor : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(isElderly ? 20 : 24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade50,
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_systolic == null || _diastolic == null || _pulse == null)
                        Column(
                          children: [
                            Lottie.asset(
                              'assets/animations/heart_pulse.json',
                              width: size.width * 0.7,
                              height: size.width * 0.7,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 32),
                            Text(
                              'Нет данных измерений',
                              style: isElderly
                                  ? ElderlyStyles.titleLarge
                                  : GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Отсканируйте показания тонометра',
                              style: isElderly
                                  ? ElderlyStyles.bodyMedium.copyWith(color: Colors.grey.shade500)
                                  : GoogleFonts.manrope(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            Text(
                              _isSaved ? 'Сохраненное измерение' : 'Последнее измерение',
                              style: isElderly
                                  ? ElderlyStyles.titleLarge
                                  : GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildEditableMeasurementCard(
                                  value: _systolic!,
                                  label: 'SYS',
                                  unit: 'мм рт.ст.',
                                  icon: Icons.arrow_upward_rounded,
                                  color: const Color(0xFFE53935),
                                  isElderly: isElderly,
                                  controller: _sysController,
                                  isEditable: !_isSaved,
                                ),
                                _buildEditableMeasurementCard(
                                  value: _diastolic!,
                                  label: 'DIA',
                                  unit: 'мм рт.ст.',
                                  icon: Icons.arrow_downward_rounded,
                                  color: const Color(0xFFFB8C00),
                                  isElderly: isElderly,
                                  controller: _diaController,
                                  isEditable: !_isSaved,
                                ),
                                _buildEditableMeasurementCard(
                                  value: _pulse!,
                                  label: 'Pulse',
                                  unit: 'уд/мин',
                                  icon: Icons.favorite_rounded,
                                  color: const Color(0xFF43A047),
                                  isElderly: isElderly,
                                  controller: _pulseController,
                                  isEditable: !_isSaved,
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Кнопка Сохранить (показывается когда есть данные и они не сохранены)
              if (_hasData && !_isSaved)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const ValueKey('save_button'),
                    onPressed: _isLoading ? null : _saveToDatabase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(vertical: isElderly ? 18 : 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isElderly ? 16 : 14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save, color: Colors.white, size: isElderly ? 28 : 24),
                        const SizedBox(width: 12),
                        Text(
                          'Сохранить',
                          style: GoogleFonts.manrope(
                            fontSize: isElderly ? 20 : 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Кнопка Сканировать (показывается когда нет данных ИЛИ данные уже сохранены)
              if (!_hasData || _isSaved)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const ValueKey('scan_button'),
                    onPressed: _isLoading ? null : () => _showScanDialog(isElderly),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      padding: EdgeInsets.symmetric(vertical: isElderly ? 18 : 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isElderly ? 16 : 14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isLoading ? Icons.hourglass_top : Icons.document_scanner,
                          color: Colors.white,
                          size: isElderly ? 28 : 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _isLoading ? 'Обработка...' : 'Сканировать',
                          style: GoogleFonts.manrope(
                            fontSize: isElderly ? 20 : 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditableMeasurementCard({
    required String value,
    required String label,
    required String unit,
    required IconData icon,
    required Color color,
    required bool isElderly,
    required TextEditingController controller,
    required bool isEditable,
  }) {
    return SizedBox(
      width: isElderly ? 110 : 90,
      child: Column(
        children: [
          Container(
            width: isElderly ? 70 : 60,
            height: isElderly ? 70 : 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: isElderly ? 32 : 28),
          ),
          const SizedBox(height: 12),
          isEditable
              ? TextField(
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: GoogleFonts.manrope(
              fontSize: isElderly ? 26 : 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            decoration: InputDecoration(
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: color.withOpacity(0.5)),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: color.withOpacity(0.3)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: color, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          )
              : Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: isElderly ? 26 : 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: isElderly
                ? GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade600)
                : GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            unit,
            textAlign: TextAlign.center,
            style: isElderly
                ? GoogleFonts.manrope(fontSize: 11, color: Colors.grey.shade500)
                : GoogleFonts.manrope(fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}