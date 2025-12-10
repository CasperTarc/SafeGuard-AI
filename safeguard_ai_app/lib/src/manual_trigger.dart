// url=https://github.com/CasperTarc/SafeGuard-AI/blob/main/safeguard_ai_app/lib/src/manual_trigger.dart
// ManualTrigger — updated to avoid HapticFeedback when a confirmation/cooldown is active.
//
// This file listens to accelerometer and detects peaks; when requiredPeaks reached it
// calls onTriggered(). We avoid performing a haptic impulse inside this class if the
// global confirmation/cooldown gate is active (so shakes during dialog/cooldown are silent).

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart'; // for debugPrint
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'false_alarm.dart' show isConfirmationActive; // consult global gate

typedef ManualTriggerCallback = void Function();

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

  ManualTrigger({
    required this.onTriggered,
    this.threshold = 2.0,
    this.requiredPeaks = 5,
    this.window = const Duration(seconds: 3),
    this.baselineAlpha = 0.1,
  });

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
  void fireTrigger() {
    // If the global confirmation gate is active, don't trigger haptic/notifications here.
    if (isConfirmationActive()) {
      // Still call onTriggered so upper layer can handle (it will likely be ignored too).
      onTriggered();
      return;
    }

    // Provide a short haptic feedback to indicate the manual trigger fired (only when allowed).
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    onTriggered();
  }

  void _handleEvent(AccelerometerEvent ev) {
    // compute magnitude
    final mag = math.sqrt(ev.x * ev.x + ev.y * ev.y + ev.z * ev.z);

    // maintain recent samples for baseline/peak detection (simple approach)
    if (_recentMags.length > 50) _recentMags.removeAt(0);
    _recentMags.add(mag);

    // compute delta from a local baseline (simple low-pass)
    final baseline = _recentMags.reduce((a, b) => a + b) / _recentMags.length;
    final delta = (mag - baseline).abs();

    if (delta >= threshold) {
      final now = DateTime.now();
      _recentPeakTimestamps.add(now);
      // remove peaks outside window
      _recentPeakTimestamps.removeWhere((t) => now.difference(t) > window);

      debugPrint('ManualTrigger: peak detected (delta=${delta.toStringAsFixed(2)}), peaks=${_recentPeakTimestamps.length}');

      if (_recentPeakTimestamps.length >= requiredPeaks) {
        debugPrint('ManualTrigger: shake confirmed (peaks=${_recentPeakTimestamps.length}) -> triggering');

        // If the global gate is active, do not perform haptic here and allow upper layer to ignore.
        if (!isConfirmationActive()) {
          try { HapticFeedback.heavyImpact(); } catch (_) {}
        } else {
          debugPrint('ManualTrigger: HAPTIC suppressed due to confirmation/cooldown gate');
        }

        // Call callback
        try {
          onTriggered();
        } catch (e) {
          debugPrint('ManualTrigger: onTriggered callback error: $e');
        }

        // Clear peaks to avoid multiple immediate triggers
        _recentPeakTimestamps.clear();
      }
    }
  }
}