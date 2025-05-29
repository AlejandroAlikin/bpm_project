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
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _measurementsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'Нет данных измерений',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            );
          }

          final measurements = snapshot.data!.docs.map((doc) {
            return Measurement.fromFirestore(doc);
          }).toList();

          final today = DateTime.now();
          final yesterday = today.subtract(const Duration(days: 1));
          final weekStart = today.subtract(const Duration(days: 7));

          final todayMeasurements = measurements.where((m) =>
          m.date.year == today.year &&
              m.date.month == today.month &&
              m.date.day == today.day).toList();

          final yesterdayMeasurements = measurements.where((m) =>
          m.date.year == yesterday.year &&
              m.date.month == yesterday.month &&
              m.date.day == yesterday.day).toList();

          final thisWeekMeasurements = measurements.where((m) =>
          m.date.isAfter(weekStart) &&
              !(m.date.year == today.year &&
                  m.date.month == today.month &&
                  m.date.day == today.day) &&
              !(m.date.year == yesterday.year &&
                  m.date.month == yesterday.month &&
                  m.date.day == yesterday.day)).toList();

          final olderMeasurements = measurements.where((m) =>
              m.date.isBefore(weekStart)).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (todayMeasurements.isNotEmpty)
                  _buildSection('Сегодня', todayMeasurements),
                if (yesterdayMeasurements.isNotEmpty)
                  _buildSection('Вчера', yesterdayMeasurements),
                if (thisWeekMeasurements.isNotEmpty)
                  _buildSection('На этой неделе', thisWeekMeasurements),
                if (olderMeasurements.isNotEmpty)
                  _buildSection('Ранее', olderMeasurements),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection(String title, List<Measurement> measurements) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          ...measurements.map((measurement) => _buildMeasurementCard(measurement)),
        ],
      ),
    );
  }

  Widget _buildMeasurementCard(Measurement measurement) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('HH:mm').format(measurement.date),
              style: GoogleFonts.spaceMono(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMeasurementValue(
                  icon: Icons.arrow_circle_up,
                  value: measurement.systolic,
                  unit: 'мм рт.ст.',
                  color: const Color(0xFFB71C1C),
                ),
                _buildMeasurementValue(
                  icon: Icons.arrow_circle_down,
                  value: measurement.diastolic,
                  unit: 'мм рт.ст.',
                  color: const Color(0xFFF57F17),
                ),
                _buildMeasurementValue(
                  icon: Icons.favorite_outline_rounded,
                  value: measurement.pulse,
                  unit: 'уд/мин',
                  color: const Color(0xFF2E7D32),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementValue({
    required IconData icon,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.spaceMono(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        Text(
          unit,
          style: GoogleFonts.spaceMono(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
      ],
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
