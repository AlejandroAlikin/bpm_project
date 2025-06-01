import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../design/colors.dart';
import '../logic/photo_processing.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Stream<QuerySnapshot> _measurementsStream;

  String _selectedPeriod = 'Неделя';
  final List<String> _periods = ['Неделя', 'Месяц', 'Год'];
  List<Measurement> _measurements = [];

  @override
  void initState() {
    super.initState();
    _measurementsStream = _firestore
        .collection('users')
        .doc(_auth.currentUser?.uid)
        .collection('measurements')
        .orderBy('date', descending: false)
        .snapshots();
  }

  List<Measurement> _getFilteredMeasurements() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'Неделя':
        final weekAgo = now.subtract(const Duration(days: 7));
        return _measurements.where((m) => m.date.isAfter(weekAgo)).toList();
      case 'Месяц':
        final monthAgo = now.subtract(const Duration(days: 30));
        return _measurements.where((m) => m.date.isAfter(monthAgo)).toList();
      case 'Год':
        final yearAgo = now.subtract(const Duration(days: 365));
        return _measurements.where((m) => m.date.isAfter(yearAgo)).toList();
      default:
        return _measurements;
    }
  }

  Map<String, dynamic> _calculateStats(List<Measurement> measurements) {
    if (measurements.isEmpty) {
      return {
        'avgPressure': '--/--',
        'avgPulse': '--',
        'maxPressure': '--/--',
        'minPressure': '--/--',
      };
    }

    final avgSystolic = measurements
        .map((m) => int.tryParse(m.systolic) ?? 0)
        .reduce((a, b) => a + b) ~/ measurements.length;

    final avgDiastolic = measurements
        .map((m) => int.tryParse(m.diastolic) ?? 0)
        .reduce((a, b) => a + b) ~/ measurements.length;

    final avgPulse = measurements
        .map((m) => int.tryParse(m.pulse) ?? 0)
        .reduce((a, b) => a + b) ~/ measurements.length;

    final maxSystolic = measurements
        .map((m) => int.tryParse(m.systolic) ?? 0)
        .reduce((a, b) => a > b ? a : b);

    final maxDiastolicMeasurement = measurements.reduce((a, b) =>
    (int.tryParse(a.diastolic) ?? 0) > (int.tryParse(b.diastolic) ?? 0) ? a : b);

    final minSystolic = measurements
        .map((m) => int.tryParse(m.systolic) ?? 0)
        .reduce((a, b) => a < b ? a : b);

    final minDiastolicMeasurement = measurements.reduce((a, b) =>
    (int.tryParse(a.diastolic) ?? 0) < (int.tryParse(b.diastolic) ?? 0) ? a : b);

    return {
      'avgPressure': '$avgSystolic/$avgDiastolic',
      'avgPulse': avgPulse.toString(),
      'maxPressure': '$maxSystolic/${maxDiastolicMeasurement.diastolic}',
      'minPressure': '$minSystolic/${minDiastolicMeasurement.diastolic}',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Анализ динамики',
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
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _measurementsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Ошибка загрузки данных',
                style: GoogleFonts.manrope(fontSize: 16, color: Colors.grey),
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
                    Icons.analytics_outlined,
                    size: 60,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Нет данных для анализа',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          _measurements = snapshot.data!.docs
              .map((doc) => Measurement.fromFirestore(doc))
              .toList();

          final filteredMeasurements = _getFilteredMeasurements();
          final stats = _calculateStats(filteredMeasurements);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                _buildPeriodSelector(),
                const SizedBox(height: 24),
                _buildChartCard(
                  title: 'Артериальное давление',
                  chart: _buildBloodPressureChart(filteredMeasurements),
                ),
                const SizedBox(height: 16),
                _buildChartCard(
                  title: 'Пульс',
                  chart: _buildPulseChart(filteredMeasurements),
                ),
                const SizedBox(height: 16),
                _buildStatsGrid(stats),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _periods.map((period) {
          final isSelected = period == _selectedPeriod;
          return Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Material(
                color: isSelected ? primaryBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _selectedPeriod = period),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      period,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChartCard({required String title, required Widget chart}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(height: 200, child: chart),
        ],
      ),
    );
  }

  Widget _buildBloodPressureChart(List<Measurement> measurements) {
    // Group measurements by day for the chart
    final Map<String, List<Measurement>> groupedMeasurements = {};

    for (final measurement in measurements) {
      final dateKey = DateFormat('dd.MM').format(measurement.date);
      groupedMeasurements.putIfAbsent(dateKey, () => []).add(measurement);
    }

    // Calculate average values for each day
    final chartData = groupedMeasurements.entries.map((entry) {
      final avgSystolic = entry.value
          .map((m) => int.tryParse(m.systolic) ?? 0)
          .reduce((a, b) => a + b) ~/ entry.value.length;

      final avgDiastolic = entry.value
          .map((m) => int.tryParse(m.diastolic) ?? 0)
          .reduce((a, b) => a + b) ~/ entry.value.length;

      return ChartData(entry.key, avgSystolic.toDouble(), avgDiastolic.toDouble());
    }).toList();

    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      primaryXAxis: CategoryAxis(
        isVisible: true,
        labelStyle: GoogleFonts.manrope(fontSize: 12),
        majorGridLines: const MajorGridLines(width: 0),
      ),
      primaryYAxis: NumericAxis(
        minimum: 60,
        maximum: 180,
        interval: 20,
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        labelStyle: GoogleFonts.manrope(fontSize: 12),
      ),
      series: <CartesianSeries>[
        LineSeries<ChartData, String>(
          dataSource: chartData,
          xValueMapper: (ChartData data, _) => data.x,
          yValueMapper: (ChartData data, _) => data.y1,
          name: 'Систолическое',
          color: const Color(0xFFE53935),
          width: 2,
          markerSettings: const MarkerSettings(
            isVisible: true,
            shape: DataMarkerType.circle,
            borderWidth: 2,
            borderColor: Color(0xFFE53935),
            color: Colors.white,
          ),
        ),
        LineSeries<ChartData, String>(
          dataSource: chartData,
          xValueMapper: (ChartData data, _) => data.x,
          yValueMapper: (ChartData data, _) => data.y2,
          name: 'Диастолическое',
          color: const Color(0xFFFB8C00),
          width: 2,
          markerSettings: const MarkerSettings(
            isVisible: true,
            shape: DataMarkerType.circle,
            borderWidth: 2,
            borderColor: Color(0xFFFB8C00),
            color: Colors.white,
          ),
        ),
      ],
      tooltipBehavior: TooltipBehavior(
        enable: true,
        header: '',
        format: 'point.x\npoint.y мм рт.ст.',
      ),
      legend: Legend(
        isVisible: true,
        position: LegendPosition.bottom,
        textStyle: GoogleFonts.manrope(fontSize: 12),
      ),
    );
  }

  Widget _buildPulseChart(List<Measurement> measurements) {
    final Map<String, List<Measurement>> groupedMeasurements = {};

    for (final measurement in measurements) {
      final dateKey = DateFormat('dd.MM').format(measurement.date);
      groupedMeasurements.putIfAbsent(dateKey, () => []).add(measurement);
    }

    final chartData = groupedMeasurements.entries.map((entry) {
      final avgPulse = entry.value
          .map((m) => int.tryParse(m.pulse) ?? 0)
          .reduce((a, b) => a + b) ~/ entry.value.length;

      return ChartData(entry.key, 0, 0, avgPulse.toDouble());
    }).toList();

    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      primaryXAxis: CategoryAxis(
        isVisible: true,
        labelStyle: GoogleFonts.manrope(fontSize: 12),
        majorGridLines: const MajorGridLines(width: 0),
      ),
      primaryYAxis: NumericAxis(
        minimum: 50,
        maximum: 100,
        interval: 10,
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        labelStyle: GoogleFonts.manrope(fontSize: 12),
      ),
      series: <CartesianSeries>[
        LineSeries<ChartData, String>(
          dataSource: chartData,
          xValueMapper: (ChartData data, _) => data.x,
          yValueMapper: (ChartData data, _) => data.y3,
          name: 'Пульс',
          color: const Color(0xFF43A047),
          width: 2,
          markerSettings: const MarkerSettings(
            isVisible: true,
            shape: DataMarkerType.circle,
            borderWidth: 2,
            borderColor: Color(0xFF43A047),
            color: Colors.white,
          ),
        ),
      ],
      tooltipBehavior: TooltipBehavior(
        enable: true,
        header: '',
        format: 'point.x\npoint.y уд/мин',
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildStatCard(
          title: 'Среднее давление',
          value: stats['avgPressure'],
          unit: 'мм рт.ст.',
          color: primaryBlue,
        ),
        _buildStatCard(
          title: 'Средний пульс',
          value: stats['avgPulse'],
          unit: 'уд/мин',
          color: const Color(0xFF43A047),
        ),
        _buildStatCard(
          title: 'Максимальное',
          value: stats['maxPressure'],
          unit: 'мм рт.ст.',
          color: const Color(0xFFE53935),
        ),
        _buildStatCard(
          title: 'Минимальное',
          value: stats['minPressure'],
          unit: 'мм рт.ст.',
          color: const Color(0xFFFB8C00),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            unit,
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class ChartData {
  final String x;
  final double y1;
  final double y2;
  final double y3;

  ChartData(this.x, this.y1, this.y2, [this.y3 = 0]);
}