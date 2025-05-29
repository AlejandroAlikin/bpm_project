import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class Measurement {
  final String systolic;
  final String diastolic;
  final String pulse;
  final DateTime date;

  Measurement({
    this.systolic = '',
    this.diastolic = '',
    this.pulse = '',
    DateTime? date,
  }) : date = date ?? DateTime.now();

  @override
  String toString() {
    return 'Measurement(systolic: $systolic, diastolic: $diastolic, pulse: $pulse, date: $date)';
  }
}

class Digit {
  final double x;
  final double y;
  final int digit;

  Digit(this.x, this.y, this.digit);

  @override
  String toString() {
    return 'Digit(x: $x, y: $y, digit: $digit)';
  }
}

class DigitsRecognition {
  static const String _apiKey = "qpHMxQlZcUaswWEyebBa";
  static const String _modelEndpoint = "ssd-detection-rydbl/1";

  Future<Measurement> recognize(File imageFile) async {
    try {
      // Base64 encode the image
      final bytes = await imageFile.readAsBytes();
      final encodedFile = base64Encode(bytes);

      // Make API request
      final result = await _makeApiRequest(encodedFile, imageFile.path);

      // Process the response
      final heights = <double>[];
      final digits = _parseResponse(result, heights);

      if (digits.isNotEmpty) {
        return _processDigits(digits, heights);
      }

      return Measurement();
    } catch (e) {
      debugPrint('Error in digit recognition: $e');
      return Measurement();
    }
  }

  Future<String> _makeApiRequest(String encodedImage, String fileName) async {
    final uploadURL =
        "https://detect.roboflow.com/$_modelEndpoint?api_key=$_apiKey&name=$fileName";

    try {
      final response = await http.post(
        Uri.parse(uploadURL),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Content-Length': encodedImage.length.toString(),
          'Content-Language': 'en-US',
        },
        body: encodedImage,
      );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw Exception('API request failed with status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to make API request: $e');
    }
  }

  List<Digit> _parseResponse(String response, List<double> heights) {
    try {
      final jsonResponse = json.decode(response);
      final predictions = jsonResponse['predictions'] as List;
      final digits = <Digit>[];
      heights.clear();

      for (final prediction in predictions) {
        final x = prediction['x'] as double;
        final y = prediction['y'] as double;
        final height = prediction['height'] as double;
        final classId = prediction['class_id'] as int;
        digits.add(Digit(x, y, classId));
        heights.add(height);
      }

      debugPrint('Parsed ${digits.length} digits');
      return digits;
    } catch (e) {
      debugPrint('Error parsing response: $e');
      return [];
    }
  }

  Measurement _processDigits(List<Digit> digits, List<double> heights) {
    if (digits.isEmpty || heights.isEmpty) return Measurement();

    // Calculate delta as average height / 1.5
    final avgHeight = heights.reduce((a, b) => a + b) / heights.length;
    final delta = avgHeight / 1.5;

    // Sort digits by y coordinate (vertical position)
    digits.sort((a, b) => a.y.compareTo(b.y));

    final sysData = <Digit>[];
    final diaData = <Digit>[];
    final pulseData = <Digit>[];

    // First row (systolic)
    double firstRowY = digits[0].y;
    for (var digit in digits) {
      if ((digit.y - firstRowY).abs() < delta) {
        sysData.add(digit);
      } else {
        break;
      }
    }

    // Second row (diastolic)
    if (sysData.length < digits.length) {
      double secondRowY = digits[sysData.length].y;
      for (var digit in digits.sublist(sysData.length)) {
        if ((digit.y - secondRowY).abs() < delta) {
          diaData.add(digit);
        } else {
          break;
        }
      }
    }

    // Third row (pulse)
    if (sysData.length + diaData.length < digits.length) {
      pulseData.addAll(digits.sublist(sysData.length + diaData.length));
    }

    // Sort each group by x coordinate (horizontal position)
    sysData.sort((a, b) => a.x.compareTo(b.x));
    diaData.sort((a, b) => a.x.compareTo(b.x));
    pulseData.sort((a, b) => a.x.compareTo(b.x));

    String sys = sysData.map((d) => d.digit.toString()).join();
    String dia = diaData.map((d) => d.digit.toString()).join();
    String pulse = pulseData.map((d) => d.digit.toString()).join();

    return Measurement(
      systolic: sys,
      diastolic: dia,
      pulse: pulse,
      date: DateTime.now(),
    );
  }
}