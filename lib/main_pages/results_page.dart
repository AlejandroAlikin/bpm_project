import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../design/colors.dart';
import '../design/elderly_styles.dart';
import '../services/theme_service.dart';
import '../services/tts_service.dart';

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TTSService _tts = TTSService();
  late Stream<QuerySnapshot> _measurementsStream;

  @override
  void initState() {
    super.initState();
    _measurementsStream = _firestore
        .collection('users')
        .doc(_auth.currentUser?.uid)
        .collection('measurements')
        .orderBy('date', descending: true)
        .snapshots();
    _tts.init();
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  Color _getCardColor(Measurement measurement) {
    final systolic = int.tryParse(measurement.systolic) ?? 0;
    final diastolic = int.tryParse(measurement.diastolic) ?? 0;

    if (systolic >= 140 || diastolic >= 90) {
      return const Color(0xFFFFEBEE);
    } else if (systolic <= 100 || diastolic <= 60) {
      return const Color(0xFFE3F2FD);
    } else {
      return const Color(0xFFE8F5E9);
    }
  }

  Color _getTextColor(Measurement measurement) {
    final systolic = int.tryParse(measurement.systolic) ?? 0;
    final diastolic = int.tryParse(measurement.diastolic) ?? 0;

    if (systolic >= 140 || diastolic >= 90) {
      return const Color(0xFFE53935);
    } else if (systolic <= 100 || diastolic <= 60) {
      return const Color(0xFF1E88E5);
    } else {
      return const Color(0xFF43A047);
    }
  }

  Future<void> _deleteMeasurement(String docId) async {
    try {
      await _firestore
          .collection('users')
          .doc(_auth.currentUser?.uid)
          .collection('measurements')
          .doc(docId)
          .delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка удаления: $e'),
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
    final themeService = Provider.of<ThemeService>(context);
    final isElderly = themeService.isElderlyMode;

    return Scaffold(
      backgroundColor: isElderly ? ElderlyStyles.backgroundColor : Colors.white,
      appBar: AppBar(
        title: Text(
          'История измерений',
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
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: isElderly ? 20 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              'Все ваши измерения',
              style: isElderly
                  ? ElderlyStyles.bodyMedium.copyWith(color: ElderlyStyles.hintColor)
                  : GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            _buildIconsHeader(isElderly),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _measurementsStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Ошибка загрузки данных',
                        style: isElderly
                            ? ElderlyStyles.bodyMedium
                            : GoogleFonts.manrope(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: primaryBlue),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: isElderly ? 80 : 60,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Нет данных измерений',
                            style: isElderly
                                ? ElderlyStyles.titleLarge
                                : GoogleFonts.manrope(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Отсканируйте показания тонометра',
                            style: isElderly
                                ? ElderlyStyles.bodyMedium.copyWith(color: Colors.grey.shade500)
                                : GoogleFonts.manrope(fontSize: 14, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    );
                  }

                  final measurements = snapshot.data!.docs
                      .map((doc) => Measurement.fromFirestore(doc))
                      .toList();

                  final today = DateTime.now();
                  final yesterday = today.subtract(const Duration(days: 1));
                  final weekStart = today.subtract(const Duration(days: 7));

                  final todayMeasurements = measurements
                      .where((m) =>
                  m.date.year == today.year &&
                      m.date.month == today.month &&
                      m.date.day == today.day)
                      .toList();

                  final yesterdayMeasurements = measurements
                      .where((m) =>
                  m.date.year == yesterday.year &&
                      m.date.month == yesterday.month &&
                      m.date.day == yesterday.day)
                      .toList();

                  final thisWeekMeasurements = measurements
                      .where((m) =>
                  m.date.isAfter(weekStart) &&
                      !(m.date.year == today.year &&
                          m.date.month == today.month &&
                          m.date.day == today.day) &&
                      !(m.date.year == yesterday.year &&
                          m.date.month == yesterday.month &&
                          m.date.day == yesterday.day))
                      .toList();

                  final olderMeasurements =
                  measurements.where((m) => m.date.isBefore(weekStart)).toList();

                  return ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      if (todayMeasurements.isNotEmpty)
                        _buildSection('Сегодня', todayMeasurements, snapshot.data!.docs, isElderly),
                      if (yesterdayMeasurements.isNotEmpty)
                        _buildSection('Вчера', yesterdayMeasurements, snapshot.data!.docs, isElderly),
                      if (thisWeekMeasurements.isNotEmpty)
                        _buildSection('На этой неделе', thisWeekMeasurements, snapshot.data!.docs, isElderly),
                      if (olderMeasurements.isNotEmpty)
                        _buildSection('Ранее', olderMeasurements, snapshot.data!.docs, isElderly),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconsHeader(bool isElderly) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: isElderly ? 12 : 8, horizontal: isElderly ? 20 : 16),
      decoration: BoxDecoration(
        color: isElderly ? ElderlyStyles.surfaceColor : Colors.white,
        borderRadius: BorderRadius.circular(isElderly ? 16 : 12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade50,
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildIconHeaderItem(
            icon: Icons.arrow_circle_up,
            label: 'SYS',
            color: const Color(0xFFE53935),
            isElderly: isElderly,
          ),
          _buildIconHeaderItem(
            icon: Icons.arrow_circle_down,
            label: 'DIA',
            color: const Color(0xFFFB8C00),
            isElderly: isElderly,
          ),
          _buildIconHeaderItem(
            icon: Icons.favorite_outline_rounded,
            label: 'PULSE',
            color: const Color(0xFF43A047),
            isElderly: isElderly,
          ),
        ],
      ),
    );
  }

  Widget _buildIconHeaderItem({
    required IconData icon,
    required String label,
    required Color color,
    required bool isElderly,
  }) {
    return Column(
      children: [
        Icon(icon, size: isElderly ? 40 : 32, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: isElderly
              ? ElderlyStyles.bodyMedium.copyWith(color: Colors.grey.shade600)
              : GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildSection(
      String title,
      List<Measurement> measurements,
      List<QueryDocumentSnapshot> docs,
      bool isElderly,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: isElderly ? 20 : 16, bottom: isElderly ? 12 : 8),
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
        ...measurements.map((measurement) {
          final doc = docs.firstWhere(
                (d) =>
            (d['date'] as Timestamp).toDate() == measurement.date &&
                d['systolic'] == measurement.systolic &&
                d['diastolic'] == measurement.diastolic &&
                d['pulse'] == measurement.pulse,
          );
          return _buildMeasurementCard(measurement, doc.id, isElderly);
        }),
      ],
    );
  }

  Widget _buildMeasurementCard(Measurement measurement, String docId, bool isElderly) {
    final cardColor = _getCardColor(measurement);
    final textColor = _getTextColor(measurement);

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: EdgeInsets.only(bottom: isElderly ? 12 : 8),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(isElderly ? 16 : 12),
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: isElderly ? 24 : 16),
        child: Icon(Icons.delete, color: Colors.red.shade400, size: isElderly ? 32 : 24),
      ),
      confirmDismiss: (direction) async {
        if (isElderly) await _tts.speak('Вы хотите удалить запись?');
        return await _showDeleteConfirmation(docId, isElderly);
      },
      onDismissed: (direction) => _deleteMeasurement(docId),
      child: Container(
        margin: EdgeInsets.only(bottom: isElderly ? 12 : 8),
        padding: EdgeInsets.all(isElderly ? 16 : 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(isElderly ? 16 : 12),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('HH:mm').format(measurement.date),
                  style: isElderly
                      ? GoogleFonts.spaceMono(fontSize: 14, color: Colors.grey.shade600)
                      : GoogleFonts.spaceMono(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  DateFormat('dd.MM.yyyy').format(measurement.date),
                  style: isElderly
                      ? GoogleFonts.spaceMono(fontSize: 14, color: Colors.grey.shade600)
                      : GoogleFonts.spaceMono(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            SizedBox(height: isElderly ? 12 : 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMeasurementValue(
                  value: measurement.systolic,
                  color: const Color(0xFFE53935),
                  isElderly: isElderly,
                ),
                _buildMeasurementValue(
                  value: measurement.diastolic,
                  color: const Color(0xFFFB8C00),
                  isElderly: isElderly,
                ),
                _buildMeasurementValue(
                  value: measurement.pulse,
                  color: const Color(0xFF43A047),
                  isElderly: isElderly,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementValue({
    required String value,
    required Color color,
    required bool isElderly,
  }) {
    return Text(
      value,
      style: GoogleFonts.manrope(
        fontSize: isElderly ? 26 : 20,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(String docId, bool isElderly) async {
    return await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                  "Удалить запись?",
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
                  "Это действие нельзя отменить",
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
                        onPressed: () => Navigator.pop(context, false),
                        isElderly: isElderly,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDialogButton(
                        text: "Удалить",
                        color: isElderly ? ElderlyStyles.errorColor.withOpacity(0.1) : Colors.red.shade50,
                        textColor: isElderly ? ElderlyStyles.errorColor : Colors.red.shade400,
                        onPressed: () {
                          if (isElderly) _tts.speak('Запись удалена');
                          Navigator.pop(context, true);
                        },
                        isElderly: isElderly,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ) ?? false;
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
}

class Measurement {
  final String systolic;
  final String diastolic;
  final String pulse;
  final DateTime date;

  Measurement({
    required this.systolic,
    required this.diastolic,
    required this.pulse,
    required this.date,
  });

  factory Measurement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Measurement(
      systolic: data['systolic'] ?? '',
      diastolic: data['diastolic'] ?? '',
      pulse: data['pulse'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'systolic': systolic,
      'diastolic': diastolic,
      'pulse': pulse,
      'date': Timestamp.fromDate(date),
    };
  }
}