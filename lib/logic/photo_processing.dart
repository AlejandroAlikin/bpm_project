import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

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

  Map<String, dynamic> toFirestore() {
    return {
      'systolic': systolic,
      'diastolic': diastolic,
      'pulse': pulse,
      'date': Timestamp.fromDate(date),
    };
  }

  factory Measurement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Measurement(
      systolic: data['systolic'] ?? '',
      diastolic: data['diastolic'] ?? '',
      pulse: data['pulse'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
    );
  }

  @override
  String toString() {
    return 'Measurement('
        'systolic: $systolic, '
        'diastolic: $diastolic, '
        'pulse: $pulse'
        ')';
  }
}

class Digit {
  final double x;
  final double y;
  final double h;
  final int digit;
  final double confidence;

  Digit(
      this.x,
      this.y,
      this.h,
      this.digit,
      this.confidence,
      );

  @override
  String toString() {
    return 'Digit($digit x=$x y=$y h=$h conf=$confidence)';
  }
}

class DetectionResult {
  final double x;
  final double y;
  final double w;
  final double h;
  final int classId;
  final double confidence;

  DetectionResult({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.classId,
    required this.confidence,
  });
}

class DigitsRecognition {
  late Interpreter _interpreter;

  bool _isInitialized = false;

  static const int _inputSize = 640;

  static const double _confidenceThreshold = 0.30;
  static const double _nmsThreshold = 0.45;

  Future<void> _initModel() async {
    if (_isInitialized) return;

    print('========================================');
    print('LOADING TFLITE MODEL');
    print('========================================');

    final modelData =
    await rootBundle.load('assets/model/best_float32.tflite');

    final modelBytes = modelData.buffer.asUint8List();

    print('Model size: ${modelBytes.length} bytes');

    final options = InterpreterOptions();

    options.threads = 2;

    _interpreter = Interpreter.fromBuffer(
      modelBytes,
      options: options,
    );

    _isInitialized = true;

    final inputTensor = _interpreter.getInputTensor(0);
    final outputTensor = _interpreter.getOutputTensor(0);

    print('Input shape: ${inputTensor.shape}');
    print('Input type : ${inputTensor.type}');

    print('Output shape: ${outputTensor.shape}');
    print('Output type : ${outputTensor.type}');

    print('MODEL INITIALIZED');
  }

  Future<Measurement> recognize(File imageFile) async {
    print('========================================');
    print('START RECOGNITION');
    print('========================================');

    try {
      await _initModel();

      final bytes = await imageFile.readAsBytes();
      print('Image size: ${bytes.length} bytes');

      final inputTensor = await _preprocessImage(bytes);

      print('Input tensor size: ${inputTensor.length}');

      final outputShape = _interpreter.getOutputTensor(0).shape;
      print('Output shape: $outputShape');

      // [1, 14, 8400]
      final output = List.generate(
        outputShape[0],
            (_) => List.generate(
          outputShape[1],
              (_) => List.filled(outputShape[2], 0.0),
        ),
      );

      // ВАЖНО:
      // создаем вход как 4D List
      final input = List.generate(
        1,
            (_) => List.generate(
          _inputSize,
              (y) => List.generate(
            _inputSize,
                (x) {
              final index = (y * _inputSize + x) * 3;

              return [
                inputTensor[index],
                inputTensor[index + 1],
                inputTensor[index + 2],
              ];
            },
          ),
        ),
      );

      final stopwatch = Stopwatch()..start();

      _interpreter.run(input, output);

      stopwatch.stop();

      print('Inference time: ${stopwatch.elapsedMilliseconds} ms');

      // Конвертируем output -> Float32List
      final flattened = Float32List(
        outputShape[0] * outputShape[1] * outputShape[2],
      );

      int idx = 0;

      for (int b = 0; b < outputShape[0]; b++) {
        for (int c = 0; c < outputShape[1]; c++) {
          for (int i = 0; i < outputShape[2]; i++) {
            flattened[idx++] = output[b][c][i].toDouble();
          }
        }
      }

      final detections = _parseYoloOutput(flattened, outputShape);

      print('Detections found: ${detections.length}');

      if (detections.isEmpty) {
        return Measurement();
      }

      return _processDetections(detections);

    } catch (e, stack) {
      print('========================================');
      print('ERROR');
      print('========================================');
      print(e);
      print(stack);

      return Measurement();
    }
  }

  Future<Float32List> _preprocessImage(
      Uint8List imageBytes,
      ) async {
    final decoded = img.decodeImage(imageBytes);

    if (decoded == null) {
      throw Exception('Cannot decode image');
    }

    print(
      'Original image size: '
          '${decoded.width}x${decoded.height}',
    );

    final resized = img.copyResize(
      decoded,
      width: _inputSize,
      height: _inputSize,
      interpolation: img.Interpolation.linear,
    );

    final input = Float32List(
      1 * _inputSize * _inputSize * 3,
    );

    int index = 0;

    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        final pixel = resized.getPixel(x, y);

        input[index++] = pixel.r / 255.0;
        input[index++] = pixel.g / 255.0;
        input[index++] = pixel.b / 255.0;
      }
    }

    return input;
  }

  List<DetectionResult> _parseYoloOutput(
      Float32List output,
      List<int> shape,
      ) {
    print('========================================');
    print('PARSING YOLO OUTPUT');
    print('========================================');

    print('Shape: $shape');
    print('Length: ${output.length}');

    final detections = <DetectionResult>[];

    const int numAnchors = 8400;
    const int numClasses = 10;

    for (int anchor = 0; anchor < numAnchors; anchor++) {
      // YOLOv8 TFLite layout:
      //
      // [1, 14, 8400]
      //
      // channel-first:
      //
      // x[8400]
      // y[8400]
      // w[8400]
      // h[8400]
      // cls0[8400]
      // cls1[8400]
      // ...

      final x = output[anchor];
      final y = output[numAnchors + anchor];
      final w = output[numAnchors * 2 + anchor];
      final h = output[numAnchors * 3 + anchor];

      if (w <= 0 || h <= 0) {
        continue;
      }

      int bestClass = -1;
      double bestScore = 0;

      for (int c = 0; c < numClasses; c++) {
        final score =
        output[numAnchors * (4 + c) + anchor];

        if (score > bestScore) {
          bestScore = score;
          bestClass = c;
        }
      }

      if (bestScore > _confidenceThreshold) {
        detections.add(
          DetectionResult(
            x: x,
            y: y,
            w: w,
            h: h,
            classId: bestClass,
            confidence: bestScore,
          ),
        );
      }
    }

    print('Raw detections: ${detections.length}');

    final result = _nonMaximumSuppression(
      detections,
      _nmsThreshold,
    );

    print('After NMS: ${result.length}');

    return result;
  }

  List<DetectionResult> _nonMaximumSuppression(
      List<DetectionResult> detections,
      double iouThreshold,
      ) {
    if (detections.isEmpty) {
      return [];
    }

    final sorted = List<DetectionResult>.from(detections);

    sorted.sort(
          (a, b) => b.confidence.compareTo(a.confidence),
    );

    final keep = <DetectionResult>[];

    final removed = List<bool>.filled(
      sorted.length,
      false,
    );

    for (int i = 0; i < sorted.length; i++) {
      if (removed[i]) continue;

      keep.add(sorted[i]);

      for (int j = i + 1; j < sorted.length; j++) {
        if (removed[j]) continue;

        final iou = _calculateIoU(
          sorted[i],
          sorted[j],
        );

        if (iou > iouThreshold) {
          removed[j] = true;
        }
      }
    }

    return keep;
  }

  double _calculateIoU(
      DetectionResult a,
      DetectionResult b,
      ) {
    final ax1 = a.x - a.w / 2;
    final ay1 = a.y - a.h / 2;
    final ax2 = a.x + a.w / 2;
    final ay2 = a.y + a.h / 2;

    final bx1 = b.x - b.w / 2;
    final by1 = b.y - b.h / 2;
    final bx2 = b.x + b.w / 2;
    final by2 = b.y + b.h / 2;

    final interX1 = ax1 > bx1 ? ax1 : bx1;
    final interY1 = ay1 > by1 ? ay1 : by1;
    final interX2 = ax2 < bx2 ? ax2 : bx2;
    final interY2 = ay2 < by2 ? ay2 : by2;

    if (interX2 <= interX1 ||
        interY2 <= interY1) {
      return 0.0;
    }

    final interArea =
        (interX2 - interX1) *
            (interY2 - interY1);

    final areaA =
        (ax2 - ax1) *
            (ay2 - ay1);

    final areaB =
        (bx2 - bx1) *
            (by2 - by1);

    return interArea /
        (areaA + areaB - interArea);
  }

  Measurement _processDetections(List<DetectionResult> detections) {
    print('========================================');
    print('PROCESS DETECTIONS');
    print('========================================');

    if (detections.isEmpty) {
      return Measurement();
    }

    // -----------------------------------------
    // Detection -> Digit
    // -----------------------------------------

    final digits = detections.map((d) {
      return Digit(
        d.x,
        d.y,
        d.h,
        d.classId,
        d.confidence,
      );
    }).toList();

    // -----------------------------------------
    // REMOVE BAD DETECTIONS
    // -----------------------------------------

    final filtered = digits
        .where((d) => d.confidence > 0.45)
        .toList();

    if (filtered.isEmpty) {
      return Measurement();
    }

    // -----------------------------------------
    // REMOVE DUPLICATES
    // YOLO часто дает 2 бокса на одну цифру
    // -----------------------------------------

    final deduplicated = <Digit>[];

    for (final d in filtered) {
      bool duplicate = false;

      for (int i = 0; i < deduplicated.length; i++) {
        final existing = deduplicated[i];

        final dx = (d.x - existing.x).abs();
        final dy = (d.y - existing.y).abs();

        // если боксы почти в одном месте
        if (dx < d.h * 0.35 && dy < d.h * 0.35) {
          duplicate = true;

          // оставляем более confident
          if (d.confidence > existing.confidence) {
            deduplicated[i] = d;
          }

          break;
        }
      }

      if (!duplicate) {
        deduplicated.add(d);
      }
    }

    print('After duplicate removal: ${deduplicated.length}');

    // -----------------------------------------
    // SORT BY Y
    // -----------------------------------------

    deduplicated.sort((a, b) => a.y.compareTo(b.y));

    // -----------------------------------------
    // DYNAMIC ROW GROUPING
    // работает даже при наклоне фото
    // -----------------------------------------

    final avgHeight =
        deduplicated.map((d) => d.h).reduce((a, b) => a + b) /
            deduplicated.length;

    final rowThreshold = avgHeight * 0.8;

    print('avgHeight=$avgHeight');
    print('rowThreshold=$rowThreshold');

    final rows = <List<Digit>>[];

    for (final digit in deduplicated) {
      bool added = false;

      for (final row in rows) {
        final avgY =
            row.map((e) => e.y).reduce((a, b) => a + b) / row.length;

        // tolerant grouping
        if ((digit.y - avgY).abs() < rowThreshold) {
          row.add(digit);
          added = true;
          break;
        }
      }

      if (!added) {
        rows.add([digit]);
      }
    }

    // -----------------------------------------
    // SORT ROWS TOP -> BOTTOM
    // -----------------------------------------

    rows.sort((a, b) {
      final ay = a.map((e) => e.y).reduce((x, y) => x + y) / a.length;
      final by = b.map((e) => e.y).reduce((x, y) => x + y) / b.length;

      return ay.compareTo(by);
    });

    // -----------------------------------------
    // SORT INSIDE ROW LEFT -> RIGHT
    // -----------------------------------------

    for (final row in rows) {
      row.sort((a, b) => a.x.compareTo(b.x));
    }

    print('Rows count: ${rows.length}');

    for (int i = 0; i < rows.length; i++) {
      print(
        'Row $i: ${rows[i].map((d) => '${d.digit}(${d.confidence.toStringAsFixed(2)})').join(' ')}',
      );
    }

    // -----------------------------------------
    // CONVERT ROW -> STRING
    // -----------------------------------------

    String rowToNumber(List<Digit> row) {
      return row.map((d) => d.digit.toString()).join();
    }

    String sys = rows.length > 0
        ? rowToNumber(rows[0])
        : '';

    String dia = rows.length > 1
        ? rowToNumber(rows[1])
        : '';

    String pulse = rows.length > 2
        ? rowToNumber(rows[2])
        : '';

    // -----------------------------------------
    // VALIDATION
    // -----------------------------------------

    bool valid(String value, int min, int max) {
      final n = int.tryParse(value);
      if (n == null) return false;
      return n >= min && n <= max;
    }

    // systolic
    if (!valid(sys, 60, 250)) {
      print('Invalid SYS: $sys');
      sys = '';
    }

    // diastolic
    if (!valid(dia, 30, 180)) {
      print('Invalid DIA: $dia');
      dia = '';
    }

    // pulse
    if (!valid(pulse, 30, 220)) {
      print('Invalid PULSE: $pulse');
      pulse = '';
    }

    print('========================================');
    print('FINAL RESULT');
    print('SYS   : $sys');
    print('DIA   : $dia');
    print('PULSE : $pulse');
    print('========================================');

    return Measurement(
      systolic: sys,
      diastolic: dia,
      pulse: pulse,
      date: DateTime.now(),
    );
  }
}