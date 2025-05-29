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

class _ScanningPageState extends State<ScanningPage> with TickerProviderStateMixin {
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
    final size = animationType == 'loading'
        ? screenWidth / 2
        : screenWidth / 3;

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

  Future<void> _updateData(Measurement measurement) async {
    if (!mounted) return;

    final bool isFailed = measurement.systolic.isEmpty ||
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
          SnackBar(content: Text('Ошибка обработки изображения: $e')),
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
        return Padding(
          padding: EdgeInsets.zero,
          child: Container(
            height: MediaQuery.of(context).size.height / 3,
            margin: EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Text(
                    "Откуда загрузить данные?",
                    style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 60,
                        child: _buildOptionButton(
                          icon: Icons.camera_alt,
                          label: "Сделать фото",
                          onTap: () {
                            Navigator.pop(context);
                            _takePhoto();
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 60,
                        child: _buildOptionButton(
                          icon: Icons.photo_library,
                          label: "Выбрать из галереи",
                          onTap: () {
                            Navigator.pop(context);
                            _pickFromGallery();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: primaryBlue),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.spaceMono(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ],
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
          SnackBar(content: Text('Ошибка сохранения результата')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Spacer(),
            Image.asset(
              width: 100,
              height: 100,
              'assets/images/heart_logo.jpg',
            ),
            const Spacer(),
            Text(
              'Результат измерения',
              style: GoogleFonts.manrope(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 50),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.1,
              ),
              child: Column(
                children: [
                  DataDisplaySection(
                    icon: Icons.arrow_circle_up,
                    label: 'Верхнее давление',
                    value: systolic,
                    hasData: systolic != null && systolic!.isNotEmpty,
                  ),
                  const SizedBox(height: 10),
                  DataDisplaySection(
                    icon: Icons.arrow_circle_down,
                    label: 'Нижнее давление',
                    value: diastolic,
                    hasData: diastolic != null && diastolic!.isNotEmpty,
                  ),
                  const SizedBox(height: 10),
                  DataDisplaySection(
                    icon: Icons.favorite_outline_rounded,
                    label: 'Пульс',
                    value: pulse,
                    hasData: pulse != null && pulse!.isNotEmpty,
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _showScanDialog,
                icon: const Icon(
                  Icons.document_scanner,
                  size: 24,
                  color: Colors.white,
                ),
                label: Text(
                  _isLoading ? 'Обработка...' : 'Просканировать',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  backgroundColor: _isLoading ? Colors.grey : primaryBlue,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class DataDisplaySection extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final bool hasData;

  const DataDisplaySection({
    Key? key,
    required this.icon,
    required this.label,
    this.value,
    this.hasData = false,
  }) : super(key: key);

  Color _getValueColor() {
    if (value == null || value!.isEmpty) return Colors.grey.shade400;

    switch (label) {
      case 'Верхнее давление':
        return const Color(0xFFB71C1C);
      case 'Нижнее давление':
        return const Color(0xFFF57F17);
      case 'Пульс':
        return const Color(0xFF2E7D32);
      default:
        return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  icon,
                  color: hasData ? _getValueColor() : Colors.grey.shade400,
                  size: 28,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.spaceMono(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value ?? '--',
                      style: GoogleFonts.spaceMono(
                        fontSize: 20,
                        color: _getValueColor(),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          indent: 24,
          endIndent: 24,
          color: Colors.grey.shade200,
        ),
      ],
    );
  }
}