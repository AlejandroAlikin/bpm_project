import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../design/colors.dart';
import '../design/elderly_styles.dart';
import '../services/theme_service.dart';
import '../services/tts_service.dart';
import '../logic/photo_processing.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TTSService _tts = TTSService();
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
    _tts.init();
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
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
    final themeService = Provider.of<ThemeService>(context);
    final isElderly = themeService.isElderlyMode;

    return Scaffold(
      backgroundColor: isElderly ? ElderlyStyles.backgroundColor : Colors.white,
      appBar: AppBar(
        title: Text(
          'Анализ динамики',
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
      body: StreamBuilder<QuerySnapshot>(
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
                    Icons.analytics_outlined,
                    size: isElderly ? 80 : 60,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Нет данных для анализа',
                    style: isElderly
                        ? ElderlyStyles.titleLarge
                        : GoogleFonts.manrope(fontSize: 16, color: Colors.grey),
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
            padding: EdgeInsets.symmetric(
              horizontal: isElderly ? 20 : 24,
              vertical: isElderly ? 20 : 16,
            ),
            child: Column(
              children: [
                _buildPeriodSelector(isElderly),
                const SizedBox(height: 24),
                _buildChartCard(
                  title: 'Артериальное давление',
                  chart: _buildBloodPressureChart(filteredMeasurements, isElderly),
                  isElderly: isElderly,
                ),
                const SizedBox(height: 16),
                _buildChartCard(
                  title: 'Пульс',
                  chart: _buildPulseChart(filteredMeasurements, isElderly),
                  isElderly: isElderly,
                ),
                const SizedBox(height: 16),
                _buildStatsGrid(stats, isElderly),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPeriodSelector(bool isElderly) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isElderly ? ElderlyStyles.surfaceColor : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(isElderly ? 14 : 12),
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
                borderRadius: BorderRadius.circular(isElderly ? 10 : 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(isElderly ? 10 : 8),
                  onTap: () {
                    setState(() => _selectedPeriod = period);
                    if (isElderly) _tts.speak(period);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isElderly ? 20 : 16,
                      vertical: isElderly ? 12 : 8,
                    ),
                    child: Text(
                      period,
                      style: GoogleFonts.manrope(
                        fontSize: isElderly ? 16 : 14,
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

  Widget _buildChartCard({
    required String title,
    required Widget chart,
    required bool isElderly,
  }) {
    return Container(
      padding: EdgeInsets.all(isElderly ? 18 : 16),
      decoration: BoxDecoration(
        color: isElderly ? ElderlyStyles.surfaceColor : Colors.white,
        borderRadius: BorderRadius.circular(isElderly ? 18 : 16),
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
            style: isElderly
                ? ElderlyStyles.titleLarge
                : GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(height: isElderly ? 250 : 200, child: chart),
        ],
      ),
    );
  }

  Widget _buildBloodPressureChart(List<Measurement> measurements, bool isElderly) {
    final Map<String, List<Measurement>> groupedMeasurements = {};

    for (final measurement in measurements) {
      final dateKey = DateFormat('dd.MM').format(measurement.date);
      groupedMeasurements.putIfAbsent(dateKey, () => []).add(measurement);
    }

    final chartData = groupedMeasurements.entries.map((entry) {
      final avgSystolic = entry.value
          .map((m) => int.tryParse(m.systolic) ?? 0)
          .reduce((a, b) => a + b) ~/ entry.value.length;

      final avgDiastolic = entry.value
          .map((m) => int.tryParse(m.diastolic) ?? 0)
          .reduce((a, b) => a + b) ~/ entry.value.length;

      return ChartData(entry.key, avgSystolic.toDouble(), avgDiastolic.toDouble());
    }).toList();

    final labelFontSize = isElderly ? 14.0 : 12.0;

    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      primaryXAxis: CategoryAxis(
        isVisible: true,
        labelStyle: GoogleFonts.manrope(fontSize: labelFontSize),
        majorGridLines: const MajorGridLines(width: 0),
      ),
      primaryYAxis: NumericAxis(
        minimum: 60,
        maximum: 180,
        interval: 20,
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        labelStyle: GoogleFonts.manrope(fontSize: labelFontSize),
      ),
      series: <CartesianSeries>[
        LineSeries<ChartData, String>(
          dataSource: chartData,
          xValueMapper: (ChartData data, _) => data.x,
          yValueMapper: (ChartData data, _) => data.y1,
          name: 'Систолическое',
          color: const Color(0xFFE53935),
          width: 2,
          markerSettings: MarkerSettings(
            isVisible: true,
            shape: DataMarkerType.circle,
            borderWidth: 2,
            borderColor: const Color(0xFFE53935),
            color: Colors.white,
            height: isElderly ? 10 : 8,
            width: isElderly ? 10 : 8,
          ),
        ),
        LineSeries<ChartData, String>(
          dataSource: chartData,
          xValueMapper: (ChartData data, _) => data.x,
          yValueMapper: (ChartData data, _) => data.y2,
          name: 'Диастолическое',
          color: const Color(0xFFFB8C00),
          width: 2,
          markerSettings: MarkerSettings(
            isVisible: true,
            shape: DataMarkerType.circle,
            borderWidth: 2,
            borderColor: const Color(0xFFFB8C00),
            color: Colors.white,
            height: isElderly ? 10 : 8,
            width: isElderly ? 10 : 8,
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
        textStyle: GoogleFonts.manrope(fontSize: labelFontSize),
      ),
    );
  }

  Widget _buildPulseChart(List<Measurement> measurements, bool isElderly) {
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

    final labelFontSize = isElderly ? 14.0 : 12.0;

    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      primaryXAxis: CategoryAxis(
        isVisible: true,
        labelStyle: GoogleFonts.manrope(fontSize: labelFontSize),
        majorGridLines: const MajorGridLines(width: 0),
      ),
      primaryYAxis: NumericAxis(
        minimum: 50,
        maximum: 100,
        interval: 10,
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        labelStyle: GoogleFonts.manrope(fontSize: labelFontSize),
      ),
      series: <CartesianSeries>[
        LineSeries<ChartData, String>(
          dataSource: chartData,
          xValueMapper: (ChartData data, _) => data.x,
          yValueMapper: (ChartData data, _) => data.y3,
          name: 'Пульс',
          color: const Color(0xFF43A047),
          width: 2,
          markerSettings: MarkerSettings(
            isVisible: true,
            shape: DataMarkerType.circle,
            borderWidth: 2,
            borderColor: const Color(0xFF43A047),
            color: Colors.white,
            height: isElderly ? 10 : 8,
            width: isElderly ? 10 : 8,
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

  Widget _buildStatsGrid(Map<String, dynamic> stats, bool isElderly) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: isElderly ? 20 : 16,
      mainAxisSpacing: isElderly ? 20 : 16,
      children: [
        _buildStatCard(
          title: 'Среднее давление',
          value: stats['avgPressure'],
          unit: 'мм рт.ст.',
          color: primaryBlue,
          isElderly: isElderly,
        ),
        _buildStatCard(
          title: 'Средний пульс',
          value: stats['avgPulse'],
          unit: 'уд/мин',
          color: const Color(0xFF43A047),
          isElderly: isElderly,
        ),
        _buildStatCard(
          title: 'Максимальное',
          value: stats['maxPressure'],
          unit: 'мм рт.ст.',
          color: const Color(0xFFE53935),
          isElderly: isElderly,
        ),
        _buildStatCard(
          title: 'Минимальное',
          value: stats['minPressure'],
          unit: 'мм рт.ст.',
          color: const Color(0xFFFB8C00),
          isElderly: isElderly,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String unit,
    required Color color,
    required bool isElderly,
  }) {
    return Container(
      padding: EdgeInsets.all(isElderly ? 18 : 16),
      decoration: BoxDecoration(
        color: isElderly ? ElderlyStyles.surfaceColor : Colors.white,
        borderRadius: BorderRadius.circular(isElderly ? 18 : 16),
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
            style: isElderly
                ? ElderlyStyles.bodyMedium.copyWith(color: ElderlyStyles.hintColor)
                : GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: isElderly ? 28 : 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            unit,
            style: GoogleFonts.manrope(
              fontSize: isElderly ? 14 : 12,
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