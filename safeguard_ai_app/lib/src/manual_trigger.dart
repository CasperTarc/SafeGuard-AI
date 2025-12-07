// Manual Trigger
// Core:
// Panic Button (Long Press): 5s
// Shake Detection: z
//
// Updated: stronger haptic pattern in _doFeedback() to make feedback more noticeable.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

typedef ManualTriggerCallback = void Function();

class ManualTrigger {
  final ManualTriggerCallback onTriggered;

  // Shake detection parameters
  final double threshold; // threshold from baseline to count a peak (m/s^2)
  final int requiredPeaks; // peaks required in window to confirm shake
  final Duration window; // time window for peaks
  final double baselineAlpha; // smoothing factor for baseline (0..1)

  // Whether the class should play a small haptic feedback when the trigger fires.
  // Default true. You can pass false if you don't want built-in feedback.
  final bool enableFeedback;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _baseline = 9.8; // initial guess for gravity
  bool _aboveThreshold = false;
  final List<DateTime> _peakTimes = [];

  ManualTrigger({
    required this.onTriggered,
    this.threshold = 2.0,
    this.requiredPeaks = 5,
    this.window = const Duration(seconds: 3),
    this.baselineAlpha = 0.1,
    this.enableFeedback = true,
  });

  /// Start listening to accelerometer events for shake detection.
  void startListening() {
    if (_accelSub != null) return;
    _accelSub = accelerometerEventStream().listen(_handleEvent, onError: (e) {
      debugPrint('ManualTrigger acc stream error: $e');
    });
    debugPrint('ManualTrigger: started listening');
  }

  /// Stop listening.
  void stopListening() {
    _accelSub?.cancel();
    _accelSub = null;
    _peakTimes.clear();
    _aboveThreshold = false;
    debugPrint('ManualTrigger: stopped listening');
  }

  /// Call this if you want to manually fire the trigger (e.g., from long-press logic).
  void fireTrigger() {
    debugPrint('ManualTrigger: manual trigger fired');
    _doFeedback();
    onTriggered();
  }

  void _handleEvent(AccelerometerEvent e) {
    final mag = _smv(e.x, e.y, e.z);

    // Update baseline using exponential smoothing (simple low-pass)
    _baseline = (1 - baselineAlpha) * _baseline + baselineAlpha * mag;

    final delta = (mag - _baseline).abs();

    // Peak detection: rising edge of exceeding threshold
    if (delta > threshold) {
      if (!_aboveThreshold) {
        // rising edge -> record a peak time
        _peakTimes.add(DateTime.now());
        _aboveThreshold = true;
        _pruneOldPeaks();
        debugPrint('ManualTrigger: peak detected (delta=${delta.toStringAsFixed(2)}), peaks=${_peakTimes.length}');
        if (_peakTimes.length >= requiredPeaks) {
          // Confirmed shake gesture
          debugPrint('ManualTrigger: shake confirmed (peaks=${_peakTimes.length}) -> triggering');
          _peakTimes.clear();
          _doFeedback();
          onTriggered();
        }
      }
    } else {
      // below threshold
      _aboveThreshold = false;
    }
  }

  void _pruneOldPeaks() {
    final now = DateTime.now();
    _peakTimes.removeWhere((t) => now.difference(t) > window);
  }

  double _smv(double x, double y, double z) => math.sqrt(x * x + y * y + z * z);

  // Stronger haptic sequence to make feedback more obvious:
  // heavyImpact -> short pause -> vibrate -> short pause -> mediumImpact
  void _doFeedback() {
    if (!enableFeedback) return;
    // Run asynchronously so we don't block the caller
    () async {
      try {
        // Heavy impact (most pronounced on many devices)
        await HapticFeedback.heavyImpact();
        // short pause
        await Future.delayed(const Duration(milliseconds: 60));
        // Generic vibrate (may use device default vibration)
        HapticFeedback.vibrate();
        // short pause
        await Future.delayed(const Duration(milliseconds: 50));
        // Finish with medium impact
        await HapticFeedback.mediumImpact();
      } catch (e) {
        // Some platforms may not support these calls; ignore errors
        debugPrint('ManualTrigger feedback error: $e');
      }
    }();
  }

  /// Dispose internal subscription if any.
  void dispose() {
    stopListening();
  }
}