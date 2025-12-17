import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:safeguard_ai/src/sensor_service.dart';
import 'package:safeguard_ai/src/fall_detector.dart';

// ANSI color
String _color(String text, int code) => '\x1B[${code}m$text\x1B[0m';
String tagDebug(String t) => _color(t, 31); // red
String tagImpact(String t) => _color(t, 32); // green
String tagConfirmed(String t) => _color(t, 35); // purple
String tagInfo(String t) => _color(t, 36); // blue
String tagTime(String t) => _color(t, 33); // yellow (for elapsed/time)

// Format timestamp
String friendlyTimestampFromDateTime(DateTime dt) {
  final local = dt.toLocal();
  return DateFormat('yyyy-MM-dd EEE h:mma').format(local);
}

// Unit tests for SensorService for three behaviors:
// 1. Testing all magnitude successfully deliver to FallDetector (if sampleMs default to ~40ms).
//     - Expecting all samples sent when input events are spaced >= sampleMs.
// 2. Testing magnitude sent to FallDetector when the input events come faster than sampleMs.
//     - Expecting fewer magnitude samples successfully sent.
// 3. Verify low-pass smoothing (EMA) is implemented correctly.
//     - Successfully give smooth magnitude values.

class RecordingFallDetector extends FallDetector {
  final List<double> magnitudes = [];
  final List<DateTime> timestamps = [];

  RecordingFallDetector() : super();

  @override
  void addSample(double magnitude, DateTime timestamp) {
    magnitudes.add(magnitude);
    timestamps.add(timestamp);
    print(tagImpact('[RecordingFallDetector] addSample: '
        'mag=${magnitude.toStringAsFixed(4)} at ${friendlyTimestampFromDateTime(timestamp)}'));
    try {
      super.addSample(magnitude, timestamp);
    } catch (_) {
      // ignore super side-effects in tests
    }
  }
}

void main() {
  group('SensorService', () {
    late StreamController<AccelerometerEvent> controller;
    late RecordingFallDetector detector;
    late SensorService service;
    late List<double> sampleLog;

    setUp(() {
      controller = StreamController<AccelerometerEvent>.broadcast();
      detector = RecordingFallDetector();
      sampleLog = <double>[];
    });

    tearDown(() async {
      try {
        service.dispose();
      } catch (_) {}
      await controller.close();
    });

    test('Test 1', () async {
      print(tagInfo('=== 1. Testing all magnitude successfully deliver to FallDetector? (sampleMs default to ~40ms) ==='));

      service = SensorService(
        fallDetector: detector,
        sampleMs: 40,
        lowPassAlpha: 0.90,
        onSample: (mag, ts) {
          sampleLog.add(mag);
          print(tagDebug('[SensorService.onSample] mag=${mag.toStringAsFixed(4)} at ${friendlyTimestampFromDateTime(ts)}'));
        },
        accelerometerStreamFactory: () => controller.stream,
      );

      service.start();

      final baseline = 9.80665;
      // Deterministic DateTime timestamps for repeatability
      controller.add(AccelerometerEvent(
          0.0, 0.0, baseline + 1.0, DateTime.fromMillisecondsSinceEpoch(1000)));
      await Future.delayed(const Duration(milliseconds: 70));
      controller.add(AccelerometerEvent(
          0.0, 0.0, baseline + 1.0, DateTime.fromMillisecondsSinceEpoch(1100)));
      await Future.delayed(const Duration(milliseconds: 70));
      controller.add(AccelerometerEvent(
          0.0, 0.0, baseline + 1.0, DateTime.fromMillisecondsSinceEpoch(1200)));

      // give processor time
      await Future.delayed(const Duration(milliseconds: 120));
      service.stop();

      // Assertions remain the same
      expect(sampleLog.length, 3);
      for (final v in sampleLog) {
        expect(v, closeTo(1.0, 1e-6));
      }
      expect(detector.magnitudes.length, 3);

      // Summary
      print(tagConfirmed('\nSummary: SensorService forwarded=${sampleLog.length}, fallDetector received=${detector.magnitudes.length}'));
      print(tagConfirmed('Forwarded values: ${sampleLog.map((v) => v.toStringAsFixed(4)).toList()}'));
    });

    test('\nTest 2', () async {
      print(tagInfo('=== 2. Testing magnitude sent to FallDetector when the input events come faster than sampleMs. ==='));

      service = SensorService(
        fallDetector: detector,
        sampleMs: 50,
        lowPassAlpha: 0.90,
        onSample: (mag, ts) {
          sampleLog.add(mag);
          print(tagDebug('[SensorService.onSample] mag=${mag.toStringAsFixed(4)} at ${friendlyTimestampFromDateTime(ts)}'));
        },
        accelerometerStreamFactory: () => controller.stream,
      );

      service.start();
      final baseline = 9.80665;
      final baseTs = 2000;

      // emit 6 events every 10ms with DateTime timestamps
      for (int i = 0; i < 6; i++) {
        controller.add(AccelerometerEvent(
          0.0,
          0.0,
          baseline + 2.0,
          DateTime.fromMillisecondsSinceEpoch(baseTs + i * 10),
        ));
        await Future.delayed(const Duration(milliseconds: 10));
      }

      await Future.delayed(const Duration(milliseconds: 200));
      service.stop();

      // Basic assertions
      expect(sampleLog.length, lessThan(6));
      expect(sampleLog.length, greaterThanOrEqualTo(1));
      for (final v in sampleLog) {
        expect(v, closeTo(2.0, 1e-6));
      }

      // Summary and clear detector/sampleLog for next tests
      print(tagConfirmed('\nSummary: throttling -> input=6 forwarded=${sampleLog.length} values=${sampleLog.map((v) => v.toStringAsFixed(4)).toList()}'));

      // clear for safety
      sampleLog.clear();
      detector.magnitudes.clear();
      detector.timestamps.clear();
    });

    test('\nTest 3', () async {
      print(tagInfo('=== 3. Verify low-pass smoothing (EMA) is implemented correctly. ==='));

      service = SensorService(
        fallDetector: detector,
        sampleMs: 1,
        lowPassAlpha: 0.5, // simple alpha to verify EMA calculations
        onSample: (mag, ts) {
          sampleLog.add(mag);
          print(tagDebug('[SensorService.onSample] mag=${mag.toStringAsFixed(4)} at ${friendlyTimestampFromDateTime(ts)}'));
        },
        accelerometerStreamFactory: () => controller.stream,
      );

      service.start();

      final baseline = 9.80665;
      // feed three deterministic samples: after gravity: 1.0, 3.0, 5.0
      controller.add(AccelerometerEvent(
          0.0, 0.0, baseline + 1.0, DateTime.fromMillisecondsSinceEpoch(3000)));
      await Future.delayed(const Duration(milliseconds: 10));
      controller.add(AccelerometerEvent(
          0.0, 0.0, baseline + 3.0, DateTime.fromMillisecondsSinceEpoch(3100)));
      await Future.delayed(const Duration(milliseconds: 10));
      controller.add(AccelerometerEvent(
          0.0, 0.0, baseline + 5.0, DateTime.fromMillisecondsSinceEpoch(3200)));

      await Future.delayed(const Duration(milliseconds: 100));
      service.stop();

      // expected EMA sequence:
      // s0 = 1.0
      // s1 = 0.5*1.0 + 0.5*3.0 = 2.0
      // s2 = 0.5*2.0 + 0.5*5.0 = 3.5
      expect(sampleLog.length, greaterThanOrEqualTo(3));
      expect(sampleLog[0], closeTo(1.0, 1e-6));
      expect(sampleLog[1], closeTo(2.0, 1e-6));
      expect(sampleLog[2], closeTo(3.5, 1e-6));

      print(tagConfirmed('\nSummary: EMA sequence -> values=${sampleLog.sublist(0, 3).map((v) => v.toStringAsFixed(4)).toList()}'));
    });
  });
}