// ManualTrigger — updated to allow runtime enabling/disabling of shake detection,
// and to call the callback with the method string ('shake' or 'long_press').

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart'; // for debugPrint
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'false_alarm.dart' show isConfirmationActive; // consult global gate

typedef ManualTriggerCallback = void Function(String method);

class ManualTrigger {
  final ManualTriggerCallback onTriggered;
  final double threshold;
  final int requiredPeaks;
  final Duration window;
  final double baselineAlpha;

  StreamSubscription<AccelerometerEvent>? _sub;
  List<double> _recentMags = [];
  List<DateTime> _recentPeakTimestamps = [];
  bool _listening = false;

  // When false, ignore accelerometer events (shake detection disabled).
  bool _shakeEnabled = true;

  ManualTrigger({
    required this.onTriggered,
    this.threshold = 2.0,
    this.requiredPeaks = 5,
    this.window = const Duration(seconds: 3),
    this.baselineAlpha = 0.1,
  });

  /// Enable/disable shake detection at runtime.
  void setShakeEnabled(bool enabled) {
    _shakeEnabled = enabled;
    debugPrint('ManualTrigger: shake detection ${enabled ? 'ENABLED' : 'DISABLED'}');
  }

  bool get isShakeEnabled => _shakeEnabled;

  void startListening() {
    if (_listening) return;
    _listening = true;
    _sub = accelerometerEvents.listen(_handleEvent);
  }

  void stopListening() {
    _sub?.cancel();
    _sub = null;
    _listening = false;
    _recentMags.clear();
    _recentPeakTimestamps.clear();
  }

  void dispose() {
    stopListening();
  }

  // Fire the trigger programmatically (used by long-press hold completion).
  // This now informs the caller that the method was 'long_press'.
  void fireTrigger() {
    // If the global confirmation gate is active, still notify the upper layer but don't do local haptics.
    if (isConfirmationActive()) {
      onTriggered('long_press');
      return;
    }

    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    onTriggered('long_press');
  }

  void _handleEvent(AccelerometerEvent ev) {
    // If shake detection is disabled (e.g. Auto Safety ON), ignore accelerometer input.
    if (!_shakeEnabled) return;

    // compute magnitude
    final mag = math.sqrt(ev.x * ev.x + ev.y * ev.y + ev.z * ev.z);

    // maintain recent samples for baseline/peak detection (simple approach)
    if (_recentMags.length > 50) _recentMags.removeAt(0);
    _recentMags.add(mag);

    // compute delta from a local baseline (simple low-pass)
    final baseline = _recentMags.isNotEmpty ? _recentMags.reduce((a, b) => a + b) / _recentMags.length : mag;
    final delta = (mag - baseline).abs();

    if (delta >= threshold) {
      final now = DateTime.now();
      _recentPeakTimestamps.add(now);
      // remove peaks outside window
      _recentPeakTimestamps.removeWhere((t) => now.difference(t) > window);

      debugPrint('ManualTrigger: peak detected (delta=${delta.toStringAsFixed(2)}), peaks=${_recentPeakTimestamps.length}');

      if (_recentPeakTimestamps.length >= requiredPeaks) {
        debugPrint('ManualTrigger: shake confirmed (peaks=${_recentPeakTimestamps.length}) -> triggering');

        // If the global gate is active, do not perform haptic here.
        if (!isConfirmationActive()) {
          try { HapticFeedback.heavyImpact(); } catch (_) {}
        } else {
          debugPrint('ManualTrigger: HAPTIC suppressed due to confirmation/cooldown gate');
        }

        // Inform caller: method = 'shake'
        try {
          onTriggered('shake');
        } catch (e) {
          debugPrint('ManualTrigger: onTriggered callback error: $e');
        }

        // Clear peaks to avoid multiple immediate triggers
        _recentPeakTimestamps.clear();
      }
    }
  }
}