import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../design/colors.dart';

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'История измерений',
          style: GoogleFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              'Все ваши измерения',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            _buildIconsHeader(),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _measurementsStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Ошибка загрузки данных',
                        style: GoogleFonts.manrope(
                            fontSize: 16,
                            color: Colors.grey
                        ),
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
                            size: 60,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Нет данных измерений',
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Отсканируйте показания тонометра',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
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
                        _buildSection('Сегодня', todayMeasurements, snapshot.data!.docs),
                      if (yesterdayMeasurements.isNotEmpty)
                        _buildSection('Вчера', yesterdayMeasurements, snapshot.data!.docs),
                      if (thisWeekMeasurements.isNotEmpty)
                        _buildSection(
                            'На этой неделе', thisWeekMeasurements, snapshot.data!.docs),
                      if (olderMeasurements.isNotEmpty)
                        _buildSection('Ранее', olderMeasurements, snapshot.data!.docs),
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

  Widget _buildIconsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          ),
          _buildIconHeaderItem(
            icon: Icons.arrow_circle_down,
            label: 'DIA',
            color: const Color(0xFFFB8C00),
          ),
          _buildIconHeaderItem(
            icon: Icons.favorite_outline_rounded,
            label: 'PULSE',
            color: const Color(0xFF43A047),
          ),
        ],
      ),
    );
  }

  Widget _buildIconHeaderItem({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.manrope(
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
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            title,
            style: GoogleFonts.manrope(
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

          return _buildMeasurementCard(measurement, doc.id);
        }),
      ],
    );
  }

  Widget _buildMeasurementCard(Measurement measurement, String docId) {
    final cardColor = _getCardColor(measurement);
    final textColor = _getTextColor(measurement);

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(Icons.delete, color: Colors.red.shade400, size: 24),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmation(docId);
      },
      onDismissed: (direction) => _deleteMeasurement(docId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
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
                  style: GoogleFonts.spaceMono(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  DateFormat('dd.MM.yyyy').format(measurement.date),
                  style: GoogleFonts.spaceMono(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMeasurementValue(
                  value: measurement.systolic,
                  color: const Color(0xFFE53935),
                ),
                _buildMeasurementValue(
                  value: measurement.diastolic,
                  color: const Color(0xFFFB8C00),
                ),
                _buildMeasurementValue(
                  value: measurement.pulse,
                  color: const Color(0xFF43A047),
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
  }) {
    return Text(
      value,
      style: GoogleFonts.manrope(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(String docId) async {
    return await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.only(top: 10, bottom: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
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
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Text(
                  "Удалить запись?",
                  style: GoogleFonts.manrope(
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
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildDialogButton(
                        text: "Отмена",
                        color: Colors.grey.shade50,
                        textColor: Colors.grey.shade700,
                        onPressed: () => Navigator.pop(context, false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDialogButton(
                        text: "Удалить",
                        color: Colors.red.shade50,
                        textColor: Colors.red.shade400,
                        onPressed: () => Navigator.pop(context, true),
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
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color == Colors.red.shade50
                ? Colors.red.shade100
                : Colors.grey.shade200,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.manrope(
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