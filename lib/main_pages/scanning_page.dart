import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import '../design/colors.dart';
import '../logic/photo_processing.dart';

class ScanningPage extends StatefulWidget {
  const ScanningPage({super.key});

  @override
  State<ScanningPage> createState() => _ScanningPageState();
}

class _ScanningPageState extends State<ScanningPage>
    with TickerProviderStateMixin {
  String? systolic;
  String? diastolic;
  String? pulse;
  bool _isLoading = false;
  late AnimationController _successAnimationController;
  late AnimationController _failedAnimationController;
  late AnimationController _loadingAnimationController;
  final DigitsRecognition _digitsRecognition = DigitsRecognition();
  OverlayEntry? _overlayEntry;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _removeOverlay();
    _successAnimationController.dispose();
    _failedAnimationController.dispose();
    _loadingAnimationController.dispose();
    super.dispose();
  }

  void _showOverlay(String animationType) {
    _removeOverlay();

    final screenWidth = MediaQuery.of(context).size.width;
    final size = animationType == 'loading' ? screenWidth / 2 : screenWidth / 3;

    _overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned.fill(
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
                        controller:
                            animationType == 'success_load'
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

  Future<void> _updateData(Measurement measurement) async {
    if (!mounted) return;

    final bool isFailed =
        measurement.systolic.isEmpty ||
        measurement.diastolic.isEmpty ||
        measurement.pulse.isEmpty;

    setState(() {
      if (!isFailed) {
        systolic = measurement.systolic;
        diastolic = measurement.diastolic;
        pulse = measurement.pulse;
      }
      _isLoading = false;
    });

    if (!isFailed) {
      await _saveMeasurement(measurement);
    }

    _showOverlay(isFailed ? 'failed' : 'success_load');

    if (isFailed) {
      _failedAnimationController.reset();
      await _failedAnimationController.forward();
    } else {
      _successAnimationController.reset();
      await _successAnimationController.forward();
    }

    _removeOverlay();
  }

  Future<void> _processImage(XFile imageFile) async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    _showOverlay('loading');
    _loadingAnimationController.repeat();

    try {
      final file = File(imageFile.path);
      final measurement = await _digitsRecognition.recognize(file);
      await _updateData(measurement);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка обработки изображения: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      _loadingAnimationController.stop();
      _removeOverlay();
    }
  }

  void _showScanDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
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
                style: GoogleFonts.manrope(
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
                        _takePhoto();
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildSourceOption(
                      icon: Icons.photo_library_rounded,
                      label: "Выбрать из галереи",
                      color: primaryBlue,
                      onTap: () {
                        Navigator.pop(context);
                        _pickFromGallery();
                      },
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
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      await _processImage(image);
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _processImage(image);
    }
  }

  Future<void> _saveMeasurement(Measurement measurement) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('measurements')
          .add(measurement.toFirestore());
    } catch (e) {
      print('Ошибка сохранения измерения: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения результата'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Мониторинг давления',
                  style: GoogleFonts.manrope(
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
                  style: GoogleFonts.manrope(
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
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(24),
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
                      if (systolic == null ||
                          diastolic == null ||
                          pulse == null)
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
                              style: GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Отсканируйте показания тонометра',
                              style: GoogleFonts.manrope(
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
                              'Последнее измерение',
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildMeasurementCard(
                                  value: systolic!,
                                  label: 'SYS',
                                  unit: 'мм рт.ст.',
                                  icon: Icons.arrow_upward_rounded,
                                  color: const Color(0xFFE53935),
                                ),
                                _buildMeasurementCard(
                                  value: diastolic!,
                                  label: 'DIA',
                                  unit: 'мм рт.ст.',
                                  icon: Icons.arrow_downward_rounded,
                                  color: const Color(0xFFFB8C00),
                                ),
                                _buildMeasurementCard(
                                  value: pulse!,
                                  label: 'Pulse',
                                  unit: 'уд/мин',
                                  icon: Icons.favorite_rounded,
                                  color: const Color(0xFF43A047),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _showScanDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isLoading
                            ? Icons.hourglass_top
                            : Icons.document_scanner,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isLoading ? 'Обработка...' : 'Сканировать',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
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

  Widget _buildMeasurementCard({
    required String value,
    required String label,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 16),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          unit,
          style: GoogleFonts.manrope(fontSize: 10, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}
